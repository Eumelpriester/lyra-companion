-- Gestalt/Stimme.lua — OGG-Wiedergabe mit Prioritaets-Queue. Sprachpakete Lyra_Gestalt_Stimme_<de|en>
-- (LoadOnDemand) liefern Interface\AddOns\Lyra_Gestalt_Stimme_xx\stimme\<name>.ogg und ein
-- Manifest LyraGestalt_StimmeManifest[xx][name]=true. Cues (hmm/oh/...) liegen im Kern unter laute\.
-- API: PlaySoundFile(path, channel) -> willPlay, handle; StopSound(handle). Nichts Fremdes.
--
-- PORT (0.9.0) — TEXT-TO-SPEECH als zweite, optionale Schicht. Siehe unten ab "Text-to-Speech".
--   Kurz: Zeilen MIT vorgerenderter OGG klingen wie Lyra und bleiben der Hauptweg. Zeilen mit
--   Platzhaltern ({zone}, {n}, {name}, {erinnerung}) kann man nicht vorrendern; die waren bisher
--   stumm. C_VoiceChat.SpeakText gibt ihnen eine Stimme — eine andere, robotische, aber eine.
--   Standard ist AUS. Grund: die Stimmen kommen vom Betriebssystem, und unter Linux/Wine ist die
--   Liste mit hoher Wahrscheinlichkeit leer. Ein Feature, das auf dem Entwicklungsrechner nicht
--   laeuft, darf nicht der Default sein.
local ADDON, ns = ...
local S = {}
ns.Stimme = S

S.handle, S.laeuftBis, S.klasse = nil, 0, nil
S.cueZuletzt = 0
S.geladen = {}
S.CUE_COOLDOWN = 120
S.SCHAETZ_SEK = 4      -- ohne Dauer-Info: konservative Belegung je Zeile

-- DESIGN-V3 B-14 / Barrierefreiheit 13 (17.09.2026): Stufe 3 (Alarm: HP20, ATEM10, STURZ) laeuft
-- IMMER auf "Master". Der Default-Kanal ist "Dialog"; wer den Dialog-Regler im Spiel auf 0 zieht -
-- und das tun viele, um Questgeber-Gebrabbel loszuwerden - hat damit bis 0.6.1 auch den einzigen
-- HOERBAREN Teil der Todeswarnung stummgeschaltet, ohne es zu merken. Fuer alles andere gilt
-- weiter die Einstellung. Der Spieler kann die Stimme komplett abschalten ("stimme" = false),
-- das ist eine bewusste Entscheidung; ein leiser Dialogkanal ist keine.
-- Ein Alarm hat zusaetzlich immer eine sichtbare Entsprechung (Blase, Ring, Glow) - Punkt 12.
S.ALARM_KANAL = "Master"
S.ALARM_STUFE = 3
local function kanal(stufe)
    if (tonumber(stufe) or 0) >= S.ALARM_STUFE then return S.ALARM_KANAL end
    return ns.Get("kanal") or "Dialog"
end
S.kanalFuer = kanal

function S.paketLaden(sprache)
    if S.geladen[sprache] ~= nil then return S.geladen[sprache] end
    local name = "Lyra_Gestalt_Stimme_" .. sprache
    local ok = false
    if ns.Compat.addonInstalliert(name) then
        local geladen = ns.Compat.ladeAddon(name)
        ok = geladen and true or false
    end
    S.geladen[sprache] = ok
    if not ok then ns.debug(ns.L["voicepack missing"] .. name) end
    return ok
end

local function pfad(sprache, name)
    return "Interface\\AddOns\\Lyra_Gestalt_Stimme_" .. sprache .. "\\stimme\\" .. name .. ".ogg"
end

local function vorhanden(sprache, name)
    local m = LyraGestalt_StimmeManifest and LyraGestalt_StimmeManifest[sprache]
    if not m then return true end   -- kein Manifest: einfach versuchen
    return m[name] and true or false
end

-- S.spiele("hp20-1", "warn", 3): warn unterbricht laufendes plauder; plauder wartet nicht, faellt weg.
-- "stufe" ist optional (Core/Regie.lua reicht sie durch) und entscheidet nur ueber den Tonkanal.
function S.spiele(name, klasse, stufe)
    -- W8 (A9): der Selbsttest hat die Ton-Ausgabe geprueft. Faellt sie durch (PlaySoundFile fehlt
    -- oder gibt nichts zurueck), bleibt die Aufnahme aus statt blind zu spielen - ohne Rueckgabe
    -- gibt es weder StopSound noch den Riegel, der den TTS-Rueckfall stumm haelt, und Lyra
    -- spraeche doppelt. Text und Blase kommen weiter, nur der Ton nicht: genau das meint
    -- "gedaempfter Betrieb". Ohne Selbsttest (alte Ladereihenfolge) ist die Abfrage ein
    -- toter Vergleich - ST.ok() antwortet fail-safe mit true.
    if ns.Selbsttest and not ns.Selbsttest.ok("ton") then return false end
    local sprache = ns.sprache()
    if not S.paketLaden(sprache) then return false end
    if not vorhanden(sprache, name) then ns.debug("Stimme fehlt: " .. name); return false end
    local t = GetTime()
    if t < S.laeuftBis then
        -- REVIEW: warn unterbricht ALLES Laufende (auch eine aeltere warn, z. B. HP35 -> HP20),
        -- sonst spielen zwei Zeilen uebereinander.
        if klasse == "warn" then
            if S.handle and StopSound then pcall(StopSound, S.handle) end
        else
            return false
        end
    end
    local will, h = PlaySoundFile(pfad(sprache, name), kanal(stufe))
    if will then
        S.handle, S.klasse = h, klasse
        local m = LyraGestalt_StimmeManifest and LyraGestalt_StimmeManifest[sprache]
        local dauer = (m and type(m[name]) == "number") and m[name] or S.SCHAETZ_SEK
        S.laeuftBis = t + dauer
        -- PORT: Zeitstempel fuer den TTS-Rueckfall. GetTime() ist innerhalb EINES Frames
        -- konstant, also ist "== jetzt" ein exakter Test auf "in dieser Ausgabe hat eine OGG
        -- gespielt" - genauer als jede Zeitfenster-Schaetzung.
        S.letzterErfolgT = t
    end
    return will
end

-- REVIEW7 (Dialog-Stimme): Eine laufende Zeile abbrechen. Der Parameter ist die Klasse, die
-- abgebrochen werden DARF - "plauder" bricht also nie eine Warnung ab. Damit behalten Warnungen
-- ihre Vorfahrt, auch wenn der Spieler im Gespraech schnell durch die Knoten klickt.
-- Ohne Parameter wird alles gestoppt (nur fuer den Ausschalter in UI/Settings.lua gedacht).
function S.stoppe(klasse)
    if klasse and S.klasse ~= klasse then return false end
    if S.handle and StopSound then pcall(StopSound, S.handle) end
    S.handle, S.laeuftBis, S.klasse = nil, 0, nil
    return true
end

function S.cue(name)
    local t = GetTime()
    if t - S.cueZuletzt < S.CUE_COOLDOWN then return end
    if math.random() < 0.5 then return end
    if t < S.laeuftBis then return end
    S.cueZuletzt = t
    PlaySoundFile(ns.PFAD .. "laute\\" .. name .. ".ogg", kanal())
end

-- =============================================================================================
-- Text-to-Speech (PORT 0.9.0)
-- =============================================================================================
-- BELEGT, gegen Blizzards eigene API-Doku (Gethe/wow-ui-source, 18.09.2026): die Signatur
--   C_VoiceChat.SpeakText(voiceID, text, rate, volume [, overlap])
-- steht IDENTISCH in VoiceChatDocumentation.lua der Branches classic_era (1.15.9),
-- classic_anniversary (2.5.6), classic (5.5.4), live (12.1.0) UND forever (1.60.1). Auf
-- live/forever sind voiceID/rate/volume/overlap als "NeverSecret" und text als
-- "ConditionalSecret" markiert, die Funktion selbst als SecretArguments = "AllowedWhenTainted"
-- - der Aufruf ist also auch unter Secret Values und aus Addon-Code erlaubt.
--
-- DIE REGEL (docs/companion-v3.md B.3), und sie ist wichtiger als die API:
--   Zeile hat eine OGG           -> OGG. Das ist Lyras Stimme, dabei bleibt es.
--   Zeile hat keine (gespielte)  -> TTS, aber nur wenn der Spieler ohnehin Gespraech will
--   OGG und TTS steht an            und NICHT, wenn Blizzard schon selbst spricht.
--   sonst                        -> Blase/Untertitel, still (Verhalten bis 0.8.0)
--
-- "keine GESPIELTE OGG" fasst absichtlich vier Faelle zusammen: Platzhalter-Zeile ohne
-- Audio, Datei fehlt im Manifest, Sprachpaket gar nicht installiert, Anrede "keine" bei einer
-- Token-Zeile. In allen vier Faellen war Lyra bisher stumm, und in allen vier ist eine
-- Roboterstimme besser als nichts - wenn man sie will.
--
-- W6 (Recherche 11 §0 Punkt 4): HIER STAND, C_CombatAudioAlert.SpeakText sei "auf
-- Retail/Forever" der bessere Weg. Das war zu eng gefasst. Die generierte Blizzard-Doku
-- CombatAudioAlertDocumentation.lua liegt auf ALLEN FUENF Branches - live, forever,
-- classic_era, classic_anniversary und classic -, 16 Funktionen, Environment = "All" (also
-- aus Addon-Code aufrufbar). Der Unterschied ist nur der Rueckgabewert:
--     Retail/Forever   utteranceID = SpeakText(text, category [, allowOverlap])
--     Classic-Clients  dieselben Argumente, OHNE Rueckgabewert
-- Darum haengt hier keine einzige Entscheidung am Rueckgabewert - nur daran, ob der Aufruf
-- geworfen hat. Wer auf eine utteranceID baut, baut auf Era ins Leere.
--
-- WARUM ueberhaupt: CAA fuegt sich in Blizzards Audio-Assist ein und respektiert dessen
-- Lautstaerke, Drossel UND Reihenfolge. Laeuft der Audio-Assist, ist CAA der einzige Weg, auf
-- dem Lyra sprechen kann, ohne dass zwei Stimmen uebereinander liegen (Recherche 10, A4).
-- Deshalb die Regel: Audio-Assist an und CAA da -> CAA. Sonst C_VoiceChat wie bisher.
-- Ob CAA auf Era auch tatsaechlich SPRICHT, beantwortet erst der Client; wirft der Aufruf,
-- schaltet S.caaKaputt ihn fuer die Sitzung ab und C_VoiceChat uebernimmt im selben Satz.

S.TTS_MODI = { aus = true, fallback = true, immer = true }
S.TTS_MAX = 3               -- Queue-Kappe: mehr als drei wartende Saetze sind Geschwaetz
S.TTS_ZEICHEN = 240         -- laengere Saetze werden gekappt (an der letzten Wortgrenze)
S.TTS_RATE = 0              -- Wertebereich nicht dokumentiert; 0 = Vorgabe des Systems
S.TTS_VOL = 100             -- 0-100
S.TTS_ZEICHEN_PRO_SEK = 14  -- fuer die Not-Bremse, wenn kein FINISHED-Ereignis kommt

S.ttsQueue = {}
S.ttsLaeuft = false
S.ttsKaputt = false         -- SpeakText hat geworfen: nicht wieder versuchen
S.ttsGesprochen = 0         -- Zaehler fuer /lyra status und den Pruefstand
S.ttsVerworfen = 0
S.ttsGrund = nil            -- letzter Ablehnungsgrund (Fehlersuche)

-- Core/Init.lua gehoert in dieser Runde einem anderen Team - die beiden Schluessel legen wir
-- deshalb selbst in DEFAULTS_ACCOUNT an. Das laeuft auf DATEIEBENE, also lange vor ns.initDB():
-- defaults() fuellt sie damit in jede Datenbank, und ns.Get() hat auch vorher schon einen Wert.
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    if ns.DEFAULTS_ACCOUNT.tts == nil then ns.DEFAULTS_ACCOUNT.tts = "aus" end
    if ns.DEFAULTS_ACCOUNT.ttsStimme == nil then ns.DEFAULTS_ACCOUNT.ttsStimme = "auto" end
    -- W9: "auch persoenliche Zeilen vorlesen". Standard AUS - siehe den Block "Persoenliche
    -- Zeilen" weiter unten am ns.nachAusgabe-Hook.
    if ns.DEFAULTS_ACCOUNT.ttsPersoenlich == nil then ns.DEFAULTS_ACCOUNT.ttsPersoenlich = false end
end

local function modus()
    local m = ns.Get("tts")
    if S.TTS_MODI[m] then return m end
    return "aus"
end
S.ttsModus = modus

-- ---------------------------------------------------------------- Stimmenwahl
-- Die Stimmen kommen vom BETRIEBSSYSTEM (Windows SAPI, macOS). Es kann NULL geben - unter
-- Wine ist das der erwartete Fall. Dann ist TTS einfach aus, ohne Meldung und ohne Fehler.
local STIMM_MUSTER = {
    de = { "german", "deutsch", "de%-de", "de_de", "hedda", "katja", "stefan", "conrad" },
    en = { "english", "en%-us", "en%-gb", "zira", "david", "hazel", "mark", "aria", "guy" },
}

local stimmenCache, stimmenCacheT = nil, -1
function S.ttsStimmen()
    local t = GetTime()
    if stimmenCache and (t - stimmenCacheT) < 30 then return stimmenCache end
    stimmenCache = ns.Compat.ttsStimmen()
    stimmenCacheT = t
    return stimmenCache
end
function S.ttsStimmenVergessen()
    stimmenCache, stimmenCacheT = nil, -1
    S.ttsStimmeId = nil
end

-- Aufgeloeste voiceID oder nil.
-- Der Cache haengt an einem SCHLUESSEL aus Sprache und Einstellung, nicht an einem Hook.
-- ns.onSetting waere der offensichtliche Weg gewesen - aber an dieser Kette haengen schon
-- Gestalt/Gestalt.lua und UI/Streamer.lua, und ein weiteres Glied darin ist Risiko ohne
-- Gegenwert. Zwei String-Vergleiche pro Satz sind billiger als eine kaputte Kette.
function S.ttsStimmeAktiv()
    local schluessel = tostring(ns.sprache()) .. "/" .. tostring(ns.Get("ttsStimme"))
    if S.ttsStimmeId and S.ttsStimmeSchluessel == schluessel then return S.ttsStimmeId end
    S.ttsStimmeSchluessel = schluessel
    S.ttsStimmeId = nil
    local liste = S.ttsStimmen()
    if #liste == 0 then return nil end
    local wahl = tonumber(ns.Get("ttsStimme"))
    if wahl then
        for i = 1, #liste do
            if tonumber(liste[i].voiceID) == wahl then S.ttsStimmeId = wahl; return wahl end
        end
    end
    -- "auto": eine Stimme, deren NAME zur aktiven Sprache passt. Namen sind nicht genormt,
    -- deshalb Muster statt Gleichheit - und am Ende einfach die erste, die es gibt.
    local muster = STIMM_MUSTER[ns.sprache()] or STIMM_MUSTER.en
    for i = 1, #liste do
        local n = tostring(liste[i].name or ""):lower()
        for j = 1, #muster do
            if n:find(muster[j]) then S.ttsStimmeId = tonumber(liste[i].voiceID); return S.ttsStimmeId end
        end
    end
    local vorgabe = ns.Compat.ttsStimmeVorgabe()
    if vorgabe then
        for i = 1, #liste do
            if tonumber(liste[i].voiceID) == vorgabe then S.ttsStimmeId = vorgabe; return vorgabe end
        end
    end
    S.ttsStimmeId = tonumber(liste[1].voiceID)
    return S.ttsStimmeId
end

-- ---------------------------------------------------------------- C_CombatAudioAlert (W6)
S.caaKaputt = false
S.CAA_UEBERLAPPEN = false      -- nie ueberlappen lassen: das ist der ganze Punkt

-- Die Kategorie ist ein Enum, dessen Mitglieder nicht belegt sind. Gefragt wird das Enum,
-- geraten wird nichts.
--
-- W8 (Welle-7-Rest, welle6 §5 Punkt 6): hier stand bis 0.11.0 "return E.Generic or ... or 0".
-- Zwei Dinge waren daran falsch:
--   1. Der ZUGRIFF selbst war ungeschuetzt. Blizzards Enum-Tabellen sind auf Retail teilweise
--      mit einer Metatabelle versehen, die bei einem unbekannten Mitglied WIRFT statt nil zu
--      geben. E.General auf einem Enum, das nur Generic kennt, waere dann ein Fehler in Lyras
--      Sprachpfad - und zwar einer, der erst auf dem Client auftritt, auf dem wir nicht testen.
--      Jetzt steht der ganze Block in pcall.
--   2. Der Rueckfall 0 war GERATEN. "0" ist auf den meisten Blizzard-Enums der erste Wert, aber
--      belegt ist das fuer CombatAudioAlertCategory nirgends - und eine ungueltige Enum-Zahl ist
--      schlimmer als gar keine: der Aufruf wirft, und Lyra faellt fuer die ganze Sitzung auf
--      C_VoiceChat zurueck (S.caaKaputt). Fehlt das Enum, gibt diese Funktion jetzt nil, und
--      S.caaSprich ruft SpeakText OHNE Kategorie auf - der Client setzt dann seine eigene
--      Vorgabe, was genau die richtige Antwort auf "wir wissen es nicht" ist.
-- Rueckgabe: Zahl (Kategorie bekannt) oder nil (unbekannt -> ohne Kategorie sprechen).
function S.caaKategorie()
    local ok, wert = pcall(function()
        local E = _G.Enum and _G.Enum.CombatAudioAlertCategory
        if type(E) ~= "table" then return nil end
        return E.Generic or E.General or E.Gameplay
    end)
    if not ok then return nil end
    return tonumber(wert)
end

function S.caaVorhanden()
    return (C_CombatAudioAlert and type(C_CombatAudioAlert.SpeakText) == "function") and true or false
end

-- Bereit = vorhanden, nicht kaputt UND eingeschaltet. Der letzte Teil ist Absicht: ist der
-- Audio-Assist aus, hoert der Spieler ueber CAA nichts - dann waere CAA ein stummer Kanal.
function S.caaBereit()
    if S.ttsCaaAus then return false end
    if S.caaKaputt or not S.caaVorhanden() then return false end
    if C_CombatAudioAlert.IsEnabled then
        local ok, an = pcall(C_CombatAudioAlert.IsEnabled)
        if ok then return an and true or false end
    end
    return false
end

-- Rueckgabe true = der Aufruf ist durchgegangen. NICHT: "es wurde gesprochen" - das sagt auf
-- den Classic-Clients niemand, weil es dort keinen Rueckgabewert gibt.
function S.caaSprich(text)
    if not S.caaVorhanden() then return false end
    local kat = S.caaKategorie()
    local ok
    if kat then
        ok = pcall(C_CombatAudioAlert.SpeakText, text, kat, S.CAA_UEBERLAPPEN)
        if not ok then
            -- Zweiter Versuch ohne das dritte Argument: auf den Classic-Clients ist allowOverlap
            -- in der Doku nicht durchgaengig gelistet.
            ok = pcall(C_CombatAudioAlert.SpeakText, text, kat)
        end
    end
    -- W8: dritter Weg - GANZ OHNE Kategorie. Das ist der Rueckfall fuer den Fall, dass
    -- Enum.CombatAudioAlertCategory fehlt (kat == nil) oder dass der Client die uebergebene
    -- Zahl nicht annimmt. Besser der Client waehlt die Kategorie als wir raten sie.
    if not ok then
        ok = pcall(C_CombatAudioAlert.SpeakText, text)
    end
    if not ok then
        S.caaKaputt = true
        ns.debug("TTS: C_CombatAudioAlert.SpeakText wirft, Weg fuer diese Sitzung aus")
    end
    return ok
end

-- Welcher Weg wuerde JETZT genommen? Nur fuer /lyra status und den Pruefstand.
function S.ttsWeg()
    if S.caaBereit() then return "caa" end
    if ns.Compat.F.tts then return "voicechat" end
    return "-"
end

-- ---------------------------------------------------------------- Wann darf sie?
-- Blizzard spricht selbst: Combat Audio Alerts (C_CombatAudioAlert, seit 12.0) und
-- Bildschirm-Narration (CVar accessibilityScreenNarrationEnabled, seit 12.1). Drei Stimmen
-- gleichzeitig sind nicht dreimal so hilfreich, sondern gar nicht.
--
-- W6: Die Frage lautet seit dieser Welle "redet gerade jemand anderes", nicht "ist Blizzards
-- TTS eingeschaltet". Der Unterschied ist gross: eingeschaltet war bis 0.10.0 ein DAUERHAFTES
-- Schweigen, obwohl der Audio-Assist die meiste Zeit gar nichts sagt - und wenn Lyra ohnehin
-- durch CAA spricht (S.caaBereit), kann es per Bauart keine zwei Stimmen geben.
-- Sinne/Welle6.lua beantwortet die Frage (laufendes fremdes Stueck, Screenreader, CVar).
-- Fehlt die Datei, gilt hier unveraendert das Verhalten von 0.9.0/0.10.0.
function S.blizzardSpricht()
    local W6 = ns.Welle6
    if W6 and type(W6.fremdeStimme) == "function" then
        local ok, r = pcall(W6.fremdeStimme)
        if ok then return r and true or false end
    end
    if C_CombatAudioAlert and C_CombatAudioAlert.IsEnabled then
        local ok, an = pcall(C_CombatAudioAlert.IsEnabled)
        if ok and an then return true end
    end
    if GetCVarBool then
        local ok, an = pcall(GetCVarBool, "accessibilityScreenNarrationEnabled")
        if ok and an then return true end
    end
    return false
end

function S.ttsErlaubt()
    if S.ttsKaputt then return false, "api-fehler" end
    if not ns.Compat.F.tts then return false, "keine api" end
    local m = modus()
    if m == "aus" then return false, "aus" end
    if not ns.Get("stimme") then return false, "stimme aus" end
    local g = ns.Get("gespraechig")
    if g == "still" then return false, "still" end
    -- "fallback" haelt sich an die Gespraechigkeit; "immer" ueberstimmt sie (aber nie "still").
    if m == "fallback" and not (g == "normal" or g == "viel") then return false, "gespraechig" end
    if S.blizzardSpricht() then return false, "blizzard spricht" end
    -- W6: Ueber C_CombatAudioAlert braucht es KEINE voiceID - der Client waehlt die Stimme
    -- selbst. Die Stimmenliste ist damit nur noch fuer den C_VoiceChat-Weg eine Bedingung.
    if not S.ttsStimmeAktiv() and not S.caaBereit() then return false, "keine stimmen" end
    return true
end

-- ---------------------------------------------------------------- Text aufbereiten
-- Aus der Sprechblase kommt WoW-Markup (Farbcodes, Symbole, Links). Vorlesen soll sie den Satz,
-- nicht die Auszeichnung.
function S.ttsText(roh)
    local t = tostring(roh or "")
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|C%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|R", "")
    t = t:gsub("|T.-|t", " "):gsub("|A.-|a", " ")
    t = t:gsub("|H.-|h(.-)|h", "%1")
    t = t:gsub("|n", " "):gsub("\n", " ")
    t = t:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if t == "" then return nil end
    -- W9 (A8): das Aussprache-Lexikon. DIE EINZIGE Stelle, an der es angewendet wird - der
    -- Untertitel laeuft ueber Core/Regie.lua ausgebenKern() und kommt hier nie vorbei. Es steht
    -- VOR der Laengenkappe, damit gekappt wird, was wirklich gesprochen wird; eine Sprechform
    -- ist oft laenger als das Wort ("Onyxia" -> "Oh-nik-see-uh"). Fehlt Gestalt/Aussprache.lua,
    -- ist dieser Block ein toter Vergleich und der Text geht unveraendert weiter.
    if ns.Aussprache and ns.Aussprache.anwenden then
        local ok, neu = pcall(ns.Aussprache.anwenden, t, ns.sprache())
        if ok and type(neu) == "string" and neu ~= "" then t = neu end
    end
    if #t > S.TTS_ZEICHEN then
        -- An der letzten Wortgrenze schneiden. Ein Schnitt mitten in ein UTF-8-Zeichen waere
        -- ein kaputtes Byte im Text, und was SAPI daraus macht, will niemand hoeren.
        local kurz = t:sub(1, S.TTS_ZEICHEN)
        local raum = kurz:match("^(.*)%s")
        t = (raum and #raum > 40) and raum or kurz:gsub("[\128-\191]*$", "")
    end
    return t
end

-- ---------------------------------------------------------------- Queue
-- Blizzard-Doku und WeakAuras-Praxis: fast gleichzeitige SpeakText-Aufrufe spielen in
-- UNDEFINIERTER Reihenfolge. Also eine eigene Queue, und den naechsten Satz erst bei
-- VOICE_CHAT_TTS_PLAYBACK_FINISHED.
local function schaetzSek(text)
    return math.max(2, #text / S.TTS_ZEICHEN_PRO_SEK)
end

function S.ttsStop()
    S.ttsQueue = {}
    S.ttsLaeuft = false
    if C_VoiceChat and C_VoiceChat.StopSpeakingText then pcall(C_VoiceChat.StopSpeakingText) end
end

function S.ttsNaechste()
    local e = table.remove(S.ttsQueue, 1)
    if not e then S.ttsLaeuft = false; return false end
    local voice = S.ttsStimmeAktiv()
    local caa = S.caaBereit()
    if not (voice or caa) then S.ttsLaeuft = false; S.ttsQueue = {}; return false end
    S.ttsLaeuft = true
    -- W6: Marke fuer die Koexistenz-Wache in Sinne/Welle6.lua. Sie muss VOR dem Aufruf stehen:
    -- VOICE_CHAT_TTS_PLAYBACK_STARTED kommt sonst, bevor wir uns als Urheber eingetragen
    -- haetten - und Lyra haette sich fuer eine fremde Stimme gehalten.
    S.ttsEigenT = GetTime()
    local ok = false
    if caa then
        ok = S.caaSprich(e.text)
        S.ttsWegZuletzt = ok and "caa" or nil
    end
    if not ok and voice then
        ok = pcall(C_VoiceChat.SpeakText, voice, e.text, S.TTS_RATE, S.TTS_VOL, false)
        if not ok then
            -- Alte Signatur (voiceID, text, destination, rate, volume) - vor 12.0.0 und auf sehr
            -- alten Classic-Builds. EIN Versuch, dann ist Ruhe: S.ttsKaputt schaltet TTS fuer die
            -- Sitzung ab, damit nicht bei jeder Zeile zwei pcalls ins Leere laufen.
            ok = pcall(C_VoiceChat.SpeakText, voice, e.text, 0, S.TTS_RATE, S.TTS_VOL)
        end
        if ok then S.ttsWegZuletzt = "voicechat" end
    end
    if not ok then
        S.ttsKaputt = true
        S.ttsLaeuft = false
        S.ttsQueue = {}
        ns.debug("TTS: SpeakText wirft, TTS fuer diese Sitzung aus")
        return false
    end
    S.ttsGesprochen = S.ttsGesprochen + 1
    S.ttsZuletzt = e.text
    -- Not-Bremse: bleibt das FINISHED-Ereignis aus (Stimme haengt, Ereignis existiert nicht),
    -- waere die Queue fuer immer blockiert.
    local marke = S.ttsGesprochen
    ns.Compat.After(schaetzSek(e.text) + 1.5, function()
        if S.ttsLaeuft and S.ttsGesprochen == marke then
            S.ttsLaeuft = false
            S.ttsNaechste()
        end
    end)
    return true
end

-- Oeffentlich: einen Satz sprechen. Rueckgabe true, wenn er in die Queue ging.
function S.ttsSprich(roh, klasse, stufe)
    local ok, grund = S.ttsErlaubt()
    S.ttsGrund = grund
    if not ok then S.ttsVerworfen = S.ttsVerworfen + 1; return false end
    local text = S.ttsText(roh)
    if not text then S.ttsVerworfen = S.ttsVerworfen + 1; return false end
    if klasse == "warn" or (tonumber(stufe) or 0) >= S.ALARM_STUFE then
        -- Eine Warnung draengt sich vor. Genau wie bei den OGGs: Geplauder hat keine Vorfahrt,
        -- wenn es um Leben geht.
        S.ttsStop()
        S.ttsQueue = { { text = text, klasse = klasse, stufe = stufe } }
    else
        if #S.ttsQueue >= S.TTS_MAX then S.ttsVerworfen = S.ttsVerworfen + 1; return false end
        S.ttsQueue[#S.ttsQueue + 1] = { text = text, klasse = klasse, stufe = stufe }
    end
    if not S.ttsLaeuft then S.ttsNaechste() end
    return true
end

-- ---------------------------------------------------------------- Anschluss an die Regie
-- Core/Regie.lua gehoert in dieser Runde einem anderen Team, deshalb haengt TTS am vorhandenen
-- Hook ns.nachAusgabe(id, e, vars, zeile) statt in ausgebenKern() zu stehen. Der Hook laeuft
-- unmittelbar nach der Ausgabe, im GLEICHEN Frame - darum ist der Test
-- "S.letzterErfolgT == GetTime()" ein exakter Test auf "eine OGG hat gerade gespielt".
-- W9: PERSOENLICHE ZEILEN WERDEN NICHT VORGELESEN.
-- /lyra persoenlich sagt seit 0.7.0 zu: "Persoenliche Zeilen kommen nur als Text in der
-- Sprechblase." Seit 0.9.0 haengt diese Vorlese-Schicht an ns.nachAusgabe und las jede Zeile
-- ohne Aufnahme vor - und eine persoenliche Zeile hat bewusst KEIN stimme-Feld, ist also genau
-- der Fall, fuer den die Schicht gebaut wurde. Der KI-Audit vom 20.09. hat das als L2 notiert
-- und die Entscheidung offengelassen: Satz aendern oder Schicht aendern.
-- ENTSCHIEDEN: die Schicht. Die Zusage ist aelter, sie steht in der Oberflaeche, und sie ist der
-- Grund, warum persoenliche Zeilen ueberhaupt so frei sein duerfen, wie sie sind.
--
-- ERKANNT WIRD SIE AM AUSGABE-WEG, NICHT AM TEXT. Sinne/Persoenlich.lua legt an jede Zeile aus
-- dem Datenpaket persoenlich = true (P.laden, "table.insert(zeilen[id][k], ...)"), und
-- Core/Regie.lua reicht GENAU DIESE Tabelle als vierten Hook-Parameter durch (ausgeben ->
-- hooksAusgabe). Ein Textvergleich waere hier falsch: dieselbe Zeile koennte auch im Katalog
-- stehen, und Text, der durch ns.fuelle und ns.Anrede gelaufen ist, vergleicht sich nicht mehr
-- zuverlaessig gegen seine Vorlage.
--
-- DER SCHALTER hebt es auf: ttsPersoenlich = true liest sie doch vor. Standard aus. Wer ihn
-- umlegt, hat in der Feineinstellung gelesen, was er tut - und dass eine KI-Kennzeichnung
-- (Quelle "modell") in der Stimme nicht mitlaeuft.
ns.nachAusgabe(function(id, e, vars, zeile)
    if type(e) ~= "table" or type(zeile) ~= "table" then return end
    if e.klasse == "still" then return end                    -- stille Ereignisse bleiben still
    if zeile.persoenlich and not ns.Get("ttsPersoenlich") then return end
    if modus() == "aus" then return end
    if S.letzterErfolgT and S.letzterErfolgT == GetTime() then return end   -- OGG hat gesprochen
    if GetTime() < S.laeuftBis then return end                -- eine aeltere OGG laeuft noch
    local sprache = ns.sprache()
    local roh = zeile[sprache] or zeile.en
    if not roh then return end
    local lauf = roh
    if ns.Anrede then lauf = ns.Anrede(lauf) end
    if ns.fuelle then lauf = ns.fuelle(lauf, vars) end
    local stufe = tonumber(e.stufe) or ((e.klasse == "warn") and 2 or 0)
    S.ttsSprich(lauf, e.klasse, stufe)
end)

ns.on("VOICE_CHAT_TTS_PLAYBACK_FINISHED", function()
    S.ttsLaeuft = false
    S.ttsNaechste()
end)
ns.on("VOICE_CHAT_TTS_PLAYBACK_FAILED", function()
    S.ttsLaeuft = false
    S.ttsNaechste()
end)
ns.on("VOICE_CHAT_TTS_VOICES_UPDATE", S.ttsStimmenVergessen)

-- Stand fuer /lyra status und den Pruefstand.
function S.ttsStand()
    local liste = S.ttsStimmen()
    local ok, grund = S.ttsErlaubt()
    return {
        modus = modus(),
        api = ns.Compat.F.tts and true or false,
        stimmen = #liste,
        stimmeId = S.ttsStimmeAktiv(),
        erlaubt = ok,
        grund = grund or S.ttsGrund,
        gesprochen = S.ttsGesprochen,
        verworfen = S.ttsVerworfen,
        wartend = #S.ttsQueue,
        kaputt = S.ttsKaputt,
        -- W6: welcher Weg gilt, welcher zuletzt gegriffen hat, und ob CAA ueberhaupt da ist.
        weg = S.ttsWeg(),
        wegZuletzt = S.ttsWegZuletzt,
        caa = S.caaVorhanden(),
        caaBereit = S.caaBereit(),
        caaKaputt = S.caaKaputt,
        -- W9
        persoenlich = ns.Get("ttsPersoenlich") and true or false,
        aussprache  = (ns.Aussprache ~= nil),
    }
end
