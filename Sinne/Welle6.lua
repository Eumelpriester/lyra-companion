-- W6: Sinne/Welle6.lua — Feature-Welle 6 "Vertrauen, Barrierefreiheit, Andocken" (0.10.x).
--
-- Acht Bauteile, eine Datei. Reihenfolge = Priorität aus dem Auftrag.
--
--   1. Barrierefreiheits-Modus (Recherche 10, A3/A4/A5/A6). Ein Schalter, der bündelt, was
--      Lyra längst einzeln kann: Untertitel-Leiste immer, Sprechername vor dem Text, deckende
--      Blase, größere Schrift, TTS für Zeilen ohne Aufnahme, längere Standzeit. Dazu die
--      Warnstufe über die FORM (Gestalt/Blase.lua), ein vollwertiger Betrieb OHNE Figur und
--      die Regel, dass nie zwei Stimmen gleichzeitig reden.
--   2. GTFO als Stillhalte-Partner (Recherche 11, P1-1).
--   3. WeakAuras ScanEventsByID — liegt in Sinne/Welle4.lua, hier steht nur die Statuszeile.
--   4. Self-Found / Hardcore über C_GameRules — liegt in Core/Compat.lua, hier die Statuszeile.
--   5. /lyra status sagt, was Lyra an Speicher und Rechenzeit kostet (P1-5).
--   6. C_CombatAudioAlert.SpeakText — liegt in Gestalt/Stimme.lua, hier die Statuszeile.
--   7. ConsolePort: zwei Zeilen, damit Gespräch und Menü mit dem Gamepad bedienbar sind (P1-4).
--   8. Client-Weiche per Laufzeit-Test — liegt in Core/Compat.lua, hier die Statuszeile.
--
-- SCHALTER (Account; UI/Settings.lua, Abschnitt "Barrierefreiheit"):
--   barrierefrei      false  der Bündel-Schalter. Er SETZT andere Schlüssel und merkt sich,
--                            was vorher dastand (barrierefreiVorher) - Ausschalten stellt
--                            den alten Stand wieder her. Ein Preset, das Entscheidungen
--                            einfach überschreibt und nicht zurückgeben kann, ist eine Falle.
--   figur             true   false = "nur Stimme und Untertitel". Lyra bleibt VOLLWERTIG:
--                            dieselben Ereignisse, dieselbe Stimme, nur keine Figur.
--   sprecher          false  "Lyra: " vor jeder Zeile (Deaf/HoH-Standard: speaker tags)
--   warnSymbol        true   Warnstufe zusätzlich als Form (Punkt/Dreieck/Doppeldreieck)
--   ttsKoexistenz     true   nie zwei Stimmen gleichzeitig
--   oggZurueckhalten  false  auch Lyras EIGENE Aufnahme zurückhalten, wenn jemand anders redet.
--                            Standard AUS - eine vorgerenderte Zeile ist kein Vorleser, und die
--                            Produktentscheidung dazu ist offen (siehe docs/welle6-2026-09-20.md).
--
-- Die GTFO-Stillhalte hat bewusst KEINEN Schalter: sie kann Lyra nur leiser machen. Dieselbe
-- Begründung wie für DBM/BigWigs (Sinne/DBM.lua, Core/Init.lua).
--
-- Blizzard-API (nur lesend): GetTime, GetCVarBool, C_VoiceChat, C_CombatAudioAlert,
--   UpdateAddOnMemoryUsage/GetAddOnMemoryUsage (bzw. die C_AddOns-Zwillinge),
--   GetAddOnCPUUsage, C_AddOns.IsAddOnLoaded, hooksecurefunc.
-- Events: PLAYER_LOGIN, VOICE_CHAT_TTS_PLAYBACK_STARTED/FINISHED/FAILED.
--
-- Fremd-API, jede im installierten Client nachgelesen
-- (~/Spiele/World of Warcraft/_classic_era_/Interface/AddOns/):
--   GTFO_DisplayAura(alertTypeID)            GTFO/Classic/GTFO_Classic.lua:1561 (global),
--                                            gerufen aus GTFO/GTFO.lua:616 am Ende jedes Alarms.
--                                            Alarmtypen 1 High / 2 Low / 3 Fail / 4 FriendlyFire
--                                            laut GTFO/GTFO.lua:810 (GTFO.AlertText).
--   ConsolePort:AddInterfaceCursorFrame(f)   ConsolePort/API.lua:143 - nimmt Frame ODER globalen
--                                            Namen und wartet intern selbst auf sein Cursor-Modul
--                                            (EventUtil.ContinueOnAddOnLoaded, API.lua:146).
--                                            Artistic License 2.0 - wir rufen auf, wir kopieren nicht.
--
-- KONTRAKT: kein SendChatMessage, keine geschützte Funktion, keine Daten anderer Spieler, kein
--   Netzwerk, keine Animationsgruppe an der Gestalt. Jeder Fremdzugriff in pcall; schlägt er
--   fehl, ist es still. Nichts davon vergleicht einen Wert, der auf Retail secret ist.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Sinne.Welle6 = W
ns.Welle6 = W

-- ---------------------------------------------------------------------------------------------
-- Voreinstellungen. Core/Init.lua gehört in dieser Runde einem anderen Team (Version), darum
-- hängen die Schlüssel hier an ns.DEFAULTS_ACCOUNT. Das läuft auf DATEIEBENE, also lange vor
-- ADDON_LOADED - und genau dort ruft ns.initDB() defaults(). Reihenfolge stimmt.
-- ---------------------------------------------------------------------------------------------
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.barrierefrei == nil then D.barrierefrei = false end
    if D.barrierefreiVorher == nil then D.barrierefreiVorher = false end
    if D.figur == nil then D.figur = true end
    if D.sprecher == nil then D.sprecher = false end
    if D.warnSymbol == nil then D.warnSymbol = true end
    if D.ttsKoexistenz == nil then D.ttsKoexistenz = true end
    if D.oggZurueckhalten == nil then D.oggZurueckhalten = false end
end

local function jetzt() return GetTime() end
function W.an(key) return ns.Get(key) and true or false end
local an = W.an

local function setze(key, wert)
    if ns.Settings and ns.Settings.setze then ns.Settings.setze(key, wert) else ns.Set(key, wert) end
end

-- ---------------------------------------------------------------------------------------------
-- 1a. Barrierefreiheits-Modus — das Bündel
--
-- Was der Schalter setzt, steht in EINER Tabelle. Zwei Werte sind keine festen Zahlen, sondern
-- Untergrenzen (Schrift, Standzeit): wer schon 24 eingestellt hat, soll nicht auf 20
-- heruntergezogen werden. "Barrierefrei" heißt mehr, nie weniger.
-- ---------------------------------------------------------------------------------------------
W.BF_SCHRIFT_MIN = 20        -- UI-Einheiten; ns.Optik rechnet "auto" sonst auf 10-28
W.BF_DAUER_MIN = 10          -- s Standzeit der Blase (Voreinstellung 6)
W.BF_LEISTE_DAUER = 12       -- s Standzeit der Untertitel-Leiste (Voreinstellung 8)
W.BF_FESTE = {
    leiste = "immer",        -- Untertitel-Leiste dauerhaft sichtbar
    untertitel = true,       -- Text auch dann, wenn die Stimme gespielt hat
    sprecher = true,         -- "Lyra: " vor der Zeile
    warnSymbol = true,       -- Form zusätzlich zur Farbe
    ttsKoexistenz = true,    -- nie zwei Stimmen
}
W.BF_SCHLUESSEL = { "leiste", "untertitel", "sprecher", "warnSymbol", "ttsKoexistenz",
                    "schrift", "blaseDauer", "tts" }

-- Der TTS-Rückfall wird nur eingeschaltet, wenn der Client überhaupt eine Vorlese-Stimme hat.
-- Sonst stünde im Panel "an" und es passierte nichts - das ist die Sorte Zusage, die Vertrauen
-- kostet (unter Linux/Wine ist die Stimmenliste regelmäßig leer).
function W.ttsMoeglich()
    if not (ns.Compat and ns.Compat.F and ns.Compat.F.tts) then return false end
    local S = ns.Stimme
    if S and S.caaBereit then
        local ok, r = pcall(S.caaBereit)
        if ok and r then return true end
    end
    local liste = (ns.Compat.ttsStimmen and ns.Compat.ttsStimmen()) or {}
    return #liste > 0
end

local function zahlOderNil(v) return tonumber(v) end

function W.barrierefreiAnwenden(an_)
    local vorher = {}
    if an_ then
        -- Merken, was dasteht - aber nur beim EINschalten und nur einmal.
        if type(ns.Get("barrierefreiVorher")) ~= "table" then
            for _, k in ipairs(W.BF_SCHLUESSEL) do vorher[k] = ns.Get(k) end
            ns.Set("barrierefreiVorher", vorher)
        end
        for k, v in pairs(W.BF_FESTE) do
            if ns.Get(k) ~= v then setze(k, v) end
        end
        -- Schrift: Untergrenze. "auto" ist ein String -> tonumber fängt ihn ab und die Grenze greift.
        local s = zahlOderNil(ns.Get("schrift"))
        if not s or s < W.BF_SCHRIFT_MIN then setze("schrift", W.BF_SCHRIFT_MIN) end
        local d = zahlOderNil(ns.Get("blaseDauer")) or 6
        if d < W.BF_DAUER_MIN then setze("blaseDauer", W.BF_DAUER_MIN) end
        if W.ttsMoeglich() and ns.Get("tts") == "aus" then setze("tts", "fallback") end
        W.leisteDauer(W.BF_LEISTE_DAUER)
        W.leisteDeckend(true)
    else
        local alt = ns.Get("barrierefreiVorher")
        if type(alt) == "table" then
            for _, k in ipairs(W.BF_SCHLUESSEL) do
                if alt[k] ~= nil and ns.Get(k) ~= alt[k] then setze(k, alt[k]) end
            end
        end
        ns.Set("barrierefreiVorher", false)
        W.leisteDauer(nil)
        W.leisteDeckend(false)
    end
    if ns.Blase and ns.Blase.layout then pcall(ns.Blase.layout) end
    if ns.Streamer and ns.Streamer.anwenden then pcall(ns.Streamer.anwenden) end
    return true
end

-- Standzeit der Untertitel-Leiste. St.UNTERTITEL_DAUER wird in UI/Streamer.lua bei JEDEM Aufruf
-- gelesen - ein Feldwechsel genügt, die Datei bleibt unberührt.
W.leisteDauerOrig = nil
function W.leisteDauer(sek)
    local St = ns.Streamer
    if not St then return false end
    if W.leisteDauerOrig == nil then W.leisteDauerOrig = St.UNTERTITEL_DAUER end
    St.UNTERTITEL_DAUER = tonumber(sek) or W.leisteDauerOrig or 8
    return true
end

-- Deckender Balken hinter der Untertitel-Leiste. UI/Streamer.lua gehört in dieser Runde keinem
-- Team, der Balken ist dort eine lokale Textur - also über die Regionen des Frames, vollständig
-- guarded und mit einer harten Bedingung: nur die BACKGROUND-Textur, nie die FontString.
-- Klappt es nicht, bleibt es bei 0,85 (laut docs/fix3 15,9:1 - schon gut, nur nicht deckend).
function W.leisteDeckend(deckend)
    local St = ns.Streamer
    local l = St and St.leiste
    if not (l and l.GetRegions) then return false end
    local a = deckend and 1 or (St.BALKEN_ALPHA or 0.85)
    local ok = pcall(function()
        for _, r in ipairs({ l:GetRegions() }) do
            if type(r) == "table" and r.GetObjectType and r:GetObjectType() == "Texture"
                and r.GetDrawLayer and r:GetDrawLayer() == "BACKGROUND" and r.SetColorTexture then
                r:SetColorTexture(0, 0, 0, a)
                W.leisteDeckendOk = true
                return
            end
        end
    end)
    return ok and W.leisteDeckendOk or false
end

-- ---------------------------------------------------------------------------------------------
-- 1b. Sprechername vor der Zeile
--
-- "Speaker tags must be present for both cutscenes and in-game dialogue" (Can I Play That?,
-- Deaf/HoH-Standard, zitiert in Recherche 10 Q.4). Der Wrapper liegt AUSSEN um den von
-- UI/Streamer.lua - dessen wrappen() läuft bei PLAYER_LOGIN, unser Handler ist später
-- angemeldet (Sinne/Welle6.lua steht in der TOC hinter UI/Streamer.lua). Damit bekommen Blase
-- UND Leiste denselben Text, und es gibt nur eine Stelle, die ihn baut.
-- ---------------------------------------------------------------------------------------------
W.NAME = "Lyra"
function W.sprecherPraefix() return W.NAME .. ": " end
function W.sprecherAn() return an("sprecher") end

W.gewrappt = false
local function blaseWrappen()
    if W.gewrappt then return end
    if not (ns.Blase and type(ns.Blase.zeige) == "function") then return end
    W.gewrappt = true
    local orig = ns.Blase.zeige
    ns.Blase.zeige = function(str, dauer, klasse, stufe, ...)
        if type(str) == "string" and str ~= "" and W.sprecherAn() then
            local p = W.sprecherPraefix()
            if str:sub(1, #p) ~= p then str = p .. str end
        end
        return orig(str, dauer, klasse, stufe, ...)
    end
end

-- ---------------------------------------------------------------------------------------------
-- 1b-2. W7: dasselbe Formsymbol auch in der Untertitel-Leiste
--
-- Offener Punkt 4 aus docs/welle6-2026-09-20.md: die Blase trägt seit Welle 6 `o` / `^` / `^^`,
-- die Leiste blieb beim alten „! ". UI/Streamer.lua rief sein Präfix in einer LOKALEN Funktion
-- und war damit von außen nicht erreichbar; seit W7 geht der Aufruf über `St.untertitelPraefix`,
-- und das hier ist der Ersatz. Die Zeichen kommen aus ns.Blase.SYMBOL — EINE Tabelle für beide
-- Kanäle, sonst laufen sie beim nächsten Umbenennen auseinander.
--
-- Warum nicht einfach „! " lassen: ein Zuschauer im Stream sieht nur, was im Bild steht, und
-- „!" ist bei Stufe 1, 2 und 3 dasselbe Zeichen. Die Form trägt die Stufe (Recherche 10, A5) —
-- und OBS liest keine Texturen, die Leiste hat also nur diesen einen Weg.
-- Der Schalter ist derselbe wie an der Blase: `warnSymbol`. Ist er aus, gilt wieder „! ".
-- ---------------------------------------------------------------------------------------------
W.LEISTE_SYMBOL_ALT = { [1] = "o ", [2] = "^ ", [3] = "^^ " }   -- Rückfall, falls ns.Blase fehlt
function W.leistePraefix(stufe, klasse)
    local s = tonumber(stufe)
    if not s then s = (klasse == "warn") and 2 or 0 end
    if s < 1 then return "" end
    if s > 3 then s = 3 end
    if not an("warnSymbol") then return "! " end
    local B = ns.Blase
    local z = (B and B.SYMBOL and B.SYMBOL[s]) or nil
    if type(z) ~= "string" or z == "" then return W.LEISTE_SYMBOL_ALT[s] or "! " end
    return z .. " "
end

W.leisteSymbolAn = false
function W.leisteSymbolBinden()
    local St = ns.Streamer
    if not St then return false end
    -- Nur binden, wenn UI/Streamer.lua die Brücke wirklich hat (W7). Auf einer älteren Datei
    -- würde das Feld gesetzt und nie gelesen — dann lieber ehrlich false melden.
    if type(St.untertitelPraefix) ~= "function" then return false end
    W.leisteSymbolOrig = W.leisteSymbolOrig or St.untertitelPraefix
    St.untertitelPraefix = W.leistePraefix
    W.leisteSymbolAn = true
    return true
end

-- ---------------------------------------------------------------------------------------------
-- 1c. "Keine Figur" — Lyra ohne Portrait, aber vollwertig
--
-- Recherche 10 §0.10: sichtbare Figuren in WoW haben 47-228 Downloads, Sprachausgabe sechs-
-- stellige. Lyra KANN das längst (/lyra verstecken + Untertitel-Leiste), es war nur weder
-- Default-Pfad noch beworben - und die Blase blieb dabei weg.
--
-- Umgesetzt über den vorhandenen, getesteten Weg: "figur = false" setzt zusätzlich "versteckt",
-- damit Gestalt/Gestalt.lua die Figur so ausblendet wie immer. NEU ist nur, was daraus folgt:
-- Gestalt/Blase.lua lässt die Blase stehen und verankert sie am Bildschirmrand, sobald die
-- Untertitel-Leiste die Zeile nicht ohnehin trägt. Die Regie, die Stimme, die Ereignisse und
-- das Gedächtnis merken von alldem nichts.
--
-- "figur" liegt im ACCOUNT, "versteckt" im Charakter. Das ist Absicht: "ich will keine Figur"
-- ist eine Entscheidung über Lyra, nicht über einen Charakter.
-- ---------------------------------------------------------------------------------------------
function W.figurAus() return ns.Get("figur") == false end

function W.figurAnwenden(zeigen)
    if zeigen then
        if ns.Get("figur") ~= true then ns.Set("figur", true) end
        if ns.Get("versteckt") then setze("versteckt", false) end
    else
        if ns.Get("figur") ~= false then ns.Set("figur", false) end
        if not ns.Get("versteckt") then setze("versteckt", true) end
    end
    if ns.Streamer and ns.Streamer.anwenden then pcall(ns.Streamer.anwenden) end
    if ns.Blase and ns.Blase.layout then pcall(ns.Blase.layout) end
    return true
end

-- ---------------------------------------------------------------------------------------------
-- 1d. TTS-Koexistenz — nie zwei Stimmen gleichzeitig
--
-- Seit Patch 12.0.0 darf Blizzards TTS ÜBERLAPPEN (Recherche 10 Q.4). Für jemanden, der einen
-- Screenreader benutzt, sind zwei parallele Stimmen kein Komfortproblem, sondern das Ende der
-- Benutzbarkeit. Bis 0.10.0 fragte Gestalt/Stimme.lua nur "ist C_CombatAudioAlert
-- EINGESCHALTET" - das ist die falsche Frage: eingeschaltet heißt nicht, dass gerade jemand
-- redet, und es hat Lyras TTS dauerhaft abgeschaltet, statt sie kurz warten zu lassen.
--
-- Die richtige Frage ist "redet gerade jemand anderes", und sie wird aus drei Quellen beantwortet:
--   1. Ein LAUFENDES fremdes TTS-Stück. C_VoiceChat meldet Start und Ende als Ereignis;
--      Gestalt/Stimme.lua setzt vor dem eigenen Aufruf S.ttsEigenT. Kommt das STARTED-Ereignis
--      ohne diese Marke, war es jemand anders - dann wird bis zum FINISHED (und höchstens
--      FREMD_MAX Sekunden) zurückgestellt.
--   2. Bildschirm-Narration (CVar accessibilityScreenNarrationEnabled, seit 12.1).
--   3. Ein geladener Screenreader (Sku ist der De-facto-Standard, dazu BlindAssist).
--
-- Zurückgestellt wird die eigene TTS-Schicht. Lyras vorgerenderte OGG läuft weiter - sie ist
-- kurz, sie ist ihre Stimme, und sie ist nicht das, was einen Vorleser übertönt. Wer es anders
-- will, schaltet "oggZurueckhalten" ein.
-- ---------------------------------------------------------------------------------------------
W.FREMD_MAX = 20            -- s: Not-Ende, falls kein FINISHED kommt
W.SCREENREADER = { "Sku", "SkuCore", "BlindAssist" }
W.fremdBis = 0
W.fremdZaehler = 0

local function eigenesStueck()
    local S = ns.Stimme
    local t = S and tonumber(S.ttsEigenT)
    if not t then return false end
    return (jetzt() - t) < 0.5
end

function W.screenreaderModus()
    if GetCVarBool then
        local ok, r = pcall(GetCVarBool, "accessibilityScreenNarrationEnabled")
        if ok and r then return "cvar" end
    end
    local geladen = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    if geladen then
        for i = 1, #W.SCREENREADER do
            local ok, r = pcall(geladen, W.SCREENREADER[i])
            if ok and r then return W.SCREENREADER[i] end
        end
    end
    return nil
end

-- Die Antwort für Gestalt/Stimme.lua (S.blizzardSpricht). true = Lyra stellt zurück.
function W.fremdeStimme()
    if not an("ttsKoexistenz") then return false end
    if jetzt() < (W.fremdBis or 0) then return true end
    if W.screenreaderModus() then return true end
    -- Blizzards Kampf-Audiohinweise laufen, und Lyra kann NICHT durch denselben Kanal sprechen
    -- (kein SpeakText oder es hat geworfen): dann gilt weiter die alte, strengere Regel.
    local S = ns.Stimme
    if C_CombatAudioAlert and C_CombatAudioAlert.IsEnabled then
        local ok, e = pcall(C_CombatAudioAlert.IsEnabled)
        if ok and e then
            local bereit = S and S.caaBereit and select(2, pcall(S.caaBereit))
            if not bereit then return true end
        end
    end
    return false
end

ns.on("VOICE_CHAT_TTS_PLAYBACK_STARTED", function(_, _, dauerMS)
    if eigenesStueck() then return end
    local sek = (tonumber(dauerMS) or 0) / 1000
    if sek <= 0 or sek > W.FREMD_MAX then sek = W.FREMD_MAX end
    W.fremdBis = jetzt() + sek
    W.fremdZaehler = W.fremdZaehler + 1
    ns.debug("W6: fremde Stimme, " .. tostring(math.floor(sek + 0.5)) .. " s Ruhe")
end)
local function fremdEnde()
    if eigenesStueck() then return end
    W.fremdBis = 0
end
ns.on("VOICE_CHAT_TTS_PLAYBACK_FINISHED", fremdEnde)
ns.on("VOICE_CHAT_TTS_PLAYBACK_FAILED", fremdEnde)

-- Der Schalter "auch OGG zurückhalten". Wrapper um ns.Stimme.spiele; die Blase kommt weiter
-- (Core/Regie.lua zeigt sie, wenn die Stimme nicht gespielt hat) - es geht nichts verloren,
-- es wird nur nichts übereinander gelegt.
W.oggGewrappt = false
local function oggWrappen()
    if W.oggGewrappt then return end
    if not (ns.Stimme and type(ns.Stimme.spiele) == "function") then return end
    W.oggGewrappt = true
    local orig = ns.Stimme.spiele
    ns.Stimme.spiele = function(name, klasse, stufe, ...)
        if an("oggZurueckhalten") and W.fremdeStimme() then
            W.oggZurueck = (W.oggZurueck or 0) + 1
            return false
        end
        return orig(name, klasse, stufe, ...)
    end
end

-- ---------------------------------------------------------------------------------------------
-- 2. GTFO als Stillhalte-Partner (Recherche 11, P1-1)
--
-- GTFO ist mit 99,1 Mio. Downloads das meistverbreitete Warn-Addon überhaupt und feuert bei
-- jedem Bodeneffekt. Ohne diese Regel redet Lyra regelmäßig genau in die Sekunde, in der der
-- Spieler weglaufen soll - die schlechteste, die sie sich aussuchen kann.
--
-- Dieselbe Mechanik wie bei DBM/BigWigs (Sinne/DBM.lua): EIN Hebel, ns.Regie.plauderRuheBis,
-- nur angehoben, nie gesenkt. Warnungen laufen in R.melde VOR dem Riegel - eine HP20-Zeile im
-- Bodeneffekt wird also NICHT verschluckt. Genau deshalb ist es dieser Hebel und kein anderer.
-- ---------------------------------------------------------------------------------------------
W.GTFO_RUHE = 3             -- s: Low / Fail / Friendly Fire
W.GTFO_RUHE_HOCH = 6        -- s: High (Alarmtyp 1) - der dauert länger und ist der gefährliche
W.gtfoAlarme = 0
W.gtfoWeg = nil

-- Ruhe anheben. Wenn Sinne/DBM.lua da ist, über dessen B.ruhe - eine Funktion, eine Bedeutung,
-- eine Statistik. Sonst derselbe Dreizeiler hier.
function W.ruhe(sek, grund)
    local B = ns.BossBruecke
    if B and type(B.ruhe) == "function" then
        local ok, r = pcall(B.ruhe, sek, grund)
        if ok then return r and true or false end
    end
    local R = ns.Regie
    sek = tonumber(sek)
    if not (R and sek and sek > 0) then return false end
    if sek > 60 then sek = 60 end
    local bis = jetzt() + sek
    if bis <= (tonumber(R.plauderRuheBis) or 0) then return false end
    R.plauderRuheBis = bis
    ns.debug("W6: Ruhe " .. tostring(math.floor(sek + 0.5)) .. " s (" .. tostring(grund or "?") .. ")")
    return true
end

function W.gtfoBinden()
    if W.gtfoWeg then return true end
    if type(_G.GTFO_DisplayAura) ~= "function" then W.gtfoWeg = nil; return false end
    if type(_G.hooksecurefunc) ~= "function" then return false end
    local ok = pcall(_G.hooksecurefunc, "GTFO_DisplayAura", function(alertTypeID)
        -- 1 = High, 2 = Low, 3 = Fail, 4 = Friendly Fire  (GTFO/GTFO.lua:810)
        W.gtfoAlarme = W.gtfoAlarme + 1
        W.ruhe((tonumber(alertTypeID) == 1) and W.GTFO_RUHE_HOCH or W.GTFO_RUHE, "gtfo")
    end)
    if not ok then return false end
    W.gtfoWeg = "GTFO_DisplayAura"
    return true
end

-- ---------------------------------------------------------------------------------------------
-- 7. ConsolePort (Recherche 11, P1-4)
--
-- Zwei Zeilen, weil die Vorarbeit schon geleistet ist: beide bedienbaren Fenster haben längst
-- globale Namen (LyraGestaltDialog aus UI/Dialog.lua:299, LyraGestaltMenue aus UI/Menue.lua:33).
-- AddInterfaceCursorFrame nimmt einen Frame ODER einen Namen und wartet intern selbst darauf,
-- dass sein Cursor-Modul geladen ist (ConsolePort/API.lua:143-146) - wir brauchen also keinen
-- eigenen Ladezeitpunkt und keine Abhängigkeit.
-- ---------------------------------------------------------------------------------------------
W.FENSTER = { "LyraGestaltDialog", "LyraGestaltMenue" }
W.consolePort = nil

function W.consolePortBinden()
    -- Einmal reicht. ConsolePort haelt seinen Stack selbst, ein zweiter Eintrag desselben
    -- Fensters waere zwar harmlos, aber eine Zahl in /lyra status, die nichts mehr bedeutet.
    if W.consolePort and W.consolePort > 0 then return true end
    local CP = _G.ConsolePort
    if not (type(CP) == "table" and type(CP.AddInterfaceCursorFrame) == "function") then
        W.consolePort = nil
        return false
    end
    local n = 0
    for i = 1, #W.FENSTER do
        local name = W.FENSTER[i]
        if rawget(_G, name) then
            local ok, r = pcall(CP.AddInterfaceCursorFrame, CP, name)
            if ok and r ~= false then n = n + 1 end
        end
    end
    W.consolePort = n
    return n > 0
end

-- ---------------------------------------------------------------------------------------------
-- 5. Was Lyra kostet (Recherche 11, P1-5)
--
-- Für ein Addon, dessen Verkaufsargument "sie nervt nicht" lautet, war es eine seltsame Lücke,
-- über den eigenen Verbrauch nichts sagen zu können - zumal Blizzards Addon-Policy "negative
-- Performance-Wirkung" als Verstoßgrund führt. Die Zahlen sind roh und ungeschönt: gemessen
-- wird, was der Client meldet, und wenn er nichts meldet, steht das da.
--
-- Rechenzeit braucht die CVar scriptProfile und einen Neustart des Clients. Ohne sie gibt
-- GetAddOnCPUUsage 0 zurück - eine 0, die "nicht gemessen" heißt, wäre Schönfärberei. Also
-- steht dort der Weg zur Messung statt einer Zahl.
-- ---------------------------------------------------------------------------------------------
W.PAKETE = {
    { "Lyra_Gestalt", "Kern" },
    { "Lyra_Gestalt_Daten", "Gefahrenkarte" },
    { "Lyra_Gestalt_Persoenlich", "Persönlich" },
    { "Lyra_Gestalt_Stimme_de", "Stimme de" },
    { "Lyra_Gestalt_Stimme_en", "Stimme en" },
}

local function api(neu, alt)
    if C_AddOns and type(C_AddOns[neu]) == "function" then return C_AddOns[neu] end
    if type(_G[alt]) == "function" then return _G[alt] end
    return nil
end

local function kib(kb)
    kb = tonumber(kb) or 0
    if kb >= 1024 then return ("%.1f MiB"):format(kb / 1024) end
    return ("%d KiB"):format(math.floor(kb + 0.5))
end

-- { { name, label, kb }, ... }, gesamt in KiB. Nur geladene Pakete zählen mit.
function W.speicher()
    local upd = api("UpdateAddOnMemoryUsage", "UpdateAddOnMemoryUsage")
    local get = api("GetAddOnMemoryUsage", "GetAddOnMemoryUsage")
    if not (upd and get) then return nil end
    if not pcall(upd) then return nil end
    local liste, gesamt = {}, 0
    for i = 1, #W.PAKETE do
        local name, label = W.PAKETE[i][1], W.PAKETE[i][2]
        local ok, kb = pcall(get, name)
        kb = ok and tonumber(kb) or nil
        if kb and kb > 0 then
            liste[#liste + 1] = { name = name, label = label, kb = kb }
            gesamt = gesamt + kb
        end
    end
    return liste, gesamt
end

function W.cpuAn()
    if not GetCVarBool then return false end
    local ok, r = pcall(GetCVarBool, "scriptProfile")
    return (ok and r) and true or false
end

function W.cpu()
    if not W.cpuAn() then return nil end
    local upd = api("UpdateAddOnCPUUsage", "UpdateAddOnCPUUsage")
    local get = api("GetAddOnCPUUsage", "GetAddOnCPUUsage")
    if not (upd and get) then return nil end
    if not pcall(upd) then return nil end
    local ok, ms = pcall(get, "Lyra_Gestalt")
    return ok and tonumber(ms) or nil
end

-- ---------------------------------------------------------------------------------------------
-- 1e. Vierte Option im Erst-Start-Assistenten (Recherche 10, A6)
--
-- dialog.lua ist reine Datei-Daten und gehört keinem Team dieser Welle. Der Knoten wird darum
-- beim LADEN an LyraGestalt_Dialog angehängt - das ist vor jedem möglichen Öffnen des Fensters
-- (UI/Dialog.lua baut seinen Index erst beim ersten knoten()-Aufruf) und lässt die Datendatei
-- unberührt. Findet der Patch seine Anker nicht, passiert nichts und /lyra status sagt es.
--
-- Der Knoten hängt ANS ENDE der drei Fragen, nicht davor: die Figur ist die letzte Entscheidung,
-- und "keine Figur" soll eine bewusste Antwort sein, keine Hürde vor dem ersten Satz.
-- ---------------------------------------------------------------------------------------------
W.assistentPatch = false
function W.assistentErweitern()
    local D = _G.LyraGestalt_Dialog
    if type(D) ~= "table" or type(D.knoten) ~= "table" then return false end
    local reden
    for _, k in ipairs(D.knoten) do
        if k.id == "setup_figur" then W.assistentPatch = true; return true end
        if k.id == "setup_reden" then reden = k end
    end
    if not (reden and type(reden.antworten) == "table") then return false end
    D.knoten[#D.knoten + 1] = {
        id = "setup_figur", miene = "thinking",
        text = {
            de = "Und noch etwas, weil es nicht jeder will: Soll ich zu sehen sein? Ich kann auch nur Stimme und Untertitel sein - ich verpasse davon nichts.",
            en = "One more thing, because not everyone wants it: should I be visible? I can also be just voice and subtitles - I don't miss a thing either way.",
        },
        antworten = {
            { text = { de = "Zeig dich.", en = "Show yourself." },
              setzt = { figur = true }, aktion = "setupFertig" },
            { text = { de = "Nur Stimme und Untertitel.", en = "Just voice and subtitles." },
              setzt = { figur = false }, aktion = "setupFertig" },
        },
    }
    local umgehaengt = 0
    for _, a in ipairs(reden.antworten) do
        if a.aktion == "setupFertig" and a.weiter == nil then
            a.aktion = nil
            a.weiter = "setup_figur"
            umgehaengt = umgehaengt + 1
        end
    end
    W.assistentPatch = (umgehaengt > 0)
    return W.assistentPatch
end
pcall(W.assistentErweitern)

-- ---------------------------------------------------------------------------------------------
-- Einstellungen: auf Änderungen reagieren.
-- Wie UI/Streamer.lua: das Original wird gemerkt und zuerst gerufen. Unser Wrapper liegt außen,
-- weil dieser Handler später angemeldet ist.
-- ---------------------------------------------------------------------------------------------
W.settingGewrappt = false
local function settingWrappen()
    if W.settingGewrappt then return end
    W.settingGewrappt = true
    local orig = ns.onSetting
    ns.onSetting = function(key, value, ...)
        if orig then orig(key, value, ...) end
        if key == "barrierefrei" then
            pcall(W.barrierefreiAnwenden, value and true or false)
        elseif key == "figur" then
            -- "figur" direkt im Panel umgelegt: den Rest nachziehen, ohne uns selbst zu rufen
            -- (figurAnwenden schreibt "figur" nur, wenn es abweicht - hier tut es das nicht).
            pcall(W.figurAnwenden, value and true or false)
        elseif key == "sprecher" or key == "warnSymbol" then
            if ns.Blase and ns.Blase.layout then pcall(ns.Blase.layout) end
        end
    end
end

-- ---------------------------------------------------------------------------------------------
-- Befehle (UI/Slash.lua ruft hierher)
-- ---------------------------------------------------------------------------------------------
local AN_AUS = { an = true, on = true, ein = true, ja = true, yes = true, immer = true,
                 aus = false, off = false, nein = false, no = false, keine = false, none = false }

function W.barrierefreiBefehl(arg)
    local v = AN_AUS[tostring(arg or ""):lower()]
    if v == nil then v = not an("barrierefrei") end
    setze("barrierefrei", v)
    ns.print(ns.L["Accessibility mode"] .. ": " .. (v and ns.L["yes"] or ns.L["no"]))
    for _, z in ipairs(W.barrierefreiZeilen()) do ns.print(z) end
    -- Eine Zeile von Lyra selbst. "direkt" ist richtig: der Spieler hat gerade gefragt.
    if ns.melde then ns.melde(v and "BARRIEREFREI_AN" or "BARRIEREFREI_AUS", { direkt = true }) end
    return v
end

function W.figurBefehl(arg)
    local v = AN_AUS[tostring(arg or ""):lower()]
    if v == nil then v = W.figurAus() end       -- ohne Argument umschalten
    W.figurAnwenden(v)
    ns.print(ns.L["Figure visible"] .. ": " .. (v and ns.L["yes"] or ns.L["no"]))
    if not v then ns.print(ns.L["Figure off hint"]) end
    return v
end

function W.barrierefreiZeilen()
    local z = {}
    z[#z + 1] = "  " .. ns.L["Subtitle bar"] .. ": " .. tostring(ns.Get("leiste"))
        .. " / " .. ns.L["Speaker name"] .. ": " .. (W.sprecherAn() and ns.L["yes"] or ns.L["no"])
    z[#z + 1] = "  " .. ns.L["Font size"] .. ": " .. tostring(ns.Get("schrift"))
        .. " / " .. ns.L["Bubble duration"] .. ": " .. tostring(ns.Get("blaseDauer")) .. " s"
    z[#z + 1] = "  " .. ns.L["TTS mode"] .. ": " .. tostring(ns.Get("tts"))
        .. (W.ttsMoeglich() and "" or (" (" .. ns.L["TTS no voices short"] .. ")"))
    z[#z + 1] = "  " .. ns.L["Warning symbol"] .. ": " .. (an("warnSymbol") and "o / ^ / ^^" or ns.L["no"])
    return z
end

-- ---------------------------------------------------------------------------------------------
-- /lyra status — Welle 6. UI/Slash.lua nimmt das Modul in seine Schleife auf.
-- ---------------------------------------------------------------------------------------------
local function jaNein(b) return b and ns.L["yes"] or ns.L["no"] end

function W.status()
    local z = {}
    local C = ns.Compat

    -- Barrierefreiheit
    z[#z + 1] = ns.L["Accessibility mode"] .. ": " .. jaNein(an("barrierefrei"))
        .. " - " .. ns.L["Figure visible"] .. ": " .. jaNein(not W.figurAus())
        .. " - " .. ns.L["Speaker name"] .. ": " .. jaNein(W.sprecherAn())

    -- Stimmen-Koexistenz
    local S = ns.Stimme
    local weg = (S and S.ttsWeg and select(2, pcall(S.ttsWeg))) or "-"
    local sr = W.screenreaderModus()
    z[#z + 1] = "TTS: " .. tostring(ns.Get("tts")) .. " (" .. tostring(weg) .. ")"
        .. " - " .. ns.L["Coexistence"] .. ": " .. jaNein(an("ttsKoexistenz"))
        .. (sr and (" - Screenreader: " .. tostring(sr)) or "")
        .. " - " .. ns.L["Foreign voice"] .. ": " .. tostring(W.fremdZaehler)

    -- GTFO
    z[#z + 1] = "GTFO: " .. (W.gtfoWeg and (W.gtfoWeg .. " (" .. tostring(W.gtfoAlarme) .. ")")
        or ns.L["not installed"])

    -- ConsolePort
    z[#z + 1] = "ConsolePort: " .. (W.consolePort and (tostring(W.consolePort) .. " " .. ns.L["frames"])
        or ns.L["not installed"])

    -- WeakAuras-Signal (Welle 4 misst, hier steht es, weil es die Welle-6-Änderung ist)
    local W4 = ns.Welle4
    z[#z + 1] = "WeakAuras: " .. tostring((W4 and W4.waWeg) or "-")

    -- Client-Weiche und Spielregeln (Core/Compat.lua)
    if C then
        z[#z + 1] = ns.L["Client"] .. ": " .. tostring(C.profil) .. " (" .. tostring(C.version)
            .. ", " .. ns.L["Switch"] .. ": " .. tostring(C.weiche or "?") .. ")"
        -- W12A (Roadmap 10-6, offener Punkt aus Welle 10b): WELCHE TOC der Client geladen hat
        -- und ob sie zu ihm passt. Das ist die Zeile, die einen Forever-Bugreport in zehn
        -- Sekunden erklaert: steht hier 11509 statt 16001, ist die suffixlose Basis-TOC
        -- gelandet - die Flavor-Zeile fehlt oder der Packager hat sie nicht erzeugt, und der
        -- Client markiert Lyra als "veraltet". "?" heisst "der Client sagt es nicht"; geraten
        -- wird nichts (C.tocInterface und C.tocPasst() geben dann beide nil).
        local okToc, tocPasst = pcall(C.tocPasst)
        z[#z + 1] = ns.L["Loaded TOC"] .. ": " .. (C.tocInterface and tostring(C.tocInterface) or "?")
            .. " (" .. ns.L["fits"] .. ": "
            .. ((okToc and tocPasst ~= nil) and jaNein(tocPasst) or "?") .. ")"
        local hc = C.istHardcore and C.istHardcore()
        local ssf = C.istSelbstgefunden and C.istSelbstgefunden()
        -- Ehrlich getrennt: was der SCHALTER sagt, und was der REALM sagt. Die beiden sind
        -- nicht dasselbe (IsSelfFoundAllowed heisst "auf diesem Realm erlaubt"), und Lyra
        -- setzt den Schalter nicht selbst - sie fragt. Darum stehen hier beide Zahlen.
        z[#z + 1] = "Hardcore: " .. jaNein(hc) .. " (" .. tostring(C.hcQuelle or "-") .. ")"
            .. " - Self-Found: " .. ns.L["Manual switch"] .. " " .. jaNein(an("ssf"))
            .. ", " .. ns.L["Realm"] .. " " .. (ssf == nil and "?" or jaNein(ssf))
            .. " (" .. tostring(C.ssfQuelle or "-") .. ")"
    end

    -- Speicher und Rechenzeit
    local liste, gesamt = W.speicher()
    if liste then
        local teile = {}
        for i = 1, #liste do teile[#teile + 1] = liste[i].label .. " " .. kib(liste[i].kb) end
        z[#z + 1] = ns.L["Memory"] .. ": " .. kib(gesamt)
            .. (#teile > 0 and ("  (" .. table.concat(teile, ", ") .. ")") or "")
    else
        z[#z + 1] = ns.L["Memory"] .. ": " .. ns.L["not measurable"]
    end
    local ms = W.cpu()
    if ms then
        z[#z + 1] = ns.L["CPU"] .. ": " .. ("%.1f ms"):format(ms) .. " " .. ns.L["since login"]
    else
        z[#z + 1] = ns.L["CPU"] .. ": " .. ns.L["CPU hint"]
    end
    return z
end

-- ---------------------------------------------------------------------------------------------
-- Login: Wrapper legen, andocken, Selbsttest.
-- Still bei Fehlschlag - der Selbsttest schreibt ins Debug-Log, nicht in den Chat.
-- ---------------------------------------------------------------------------------------------
ns.on("PLAYER_LOGIN", function()
    blaseWrappen()
    oggWrappen()
    settingWrappen()
    W.leisteSymbolBinden()   -- W7: Formsymbol auch in der Untertitel-Leiste
    pcall(W.assistentErweitern)
    -- Der gespeicherte Stand gilt ab dem Login. barrierefreiAnwenden() setzt beim EINschalten
    -- nur, was abweicht - ein zweiter Lauf ist damit folgenlos.
    if an("barrierefrei") then pcall(W.barrierefreiAnwenden, true) end
    if W.figurAus() then pcall(W.figurAnwenden, false) end
    -- GTFO und ConsolePort erst kurz nach dem Login: beide sind eigene Addons und laden
    -- eventuell nach uns (LoadOnDemand, Ladereihenfolge nach Alphabet ist keine Zusage).
    ns.Compat.After(2, function()
        pcall(W.gtfoBinden)
        pcall(W.consolePortBinden)
        ns.debug("W6: GTFO " .. tostring(W.gtfoWeg or "-")
            .. ", ConsolePort " .. tostring(W.consolePort or "-")
            .. ", Assistent " .. tostring(W.assistentPatch)
            .. ", Leiste deckend " .. tostring(W.leisteDeckendOk or false)
            .. ", Leisten-Symbol " .. tostring(W.leisteSymbolAn))   -- W7
    end)
end)

return W
