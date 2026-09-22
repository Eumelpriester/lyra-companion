-- Sinne/Welle18.lua — Welle 18 "Transparenz" (0.19.0, 22.09.2026).
--
-- Bauplan: docs/recherche/21-lernen-entwicklung-2026-09-21.md §3 "Welle 18" (Pflicht vor dem
-- 0.19-Zip). Zwei Befehle, ein gebuendeltes Haekchen, ein Vorbereitungs-Haekchen:
--
--   /lyra weisst   (weiss/weisst/know) — EIN Stueck: Chat-Ausgabe ueber ns.print (nie ein
--                  Chat-Kanal) UND ein Dialogknoten mit einer kurzen, gesprochenen Blase.
--   /lyra vergiss <bereich>|alles — loescht, aber erst nach einer Rueckfrage per Dialogknoten
--                  mit zwei Knoepfen (Maus). "alles" laesst das Erbe unangetastet — Harald:
--                  "Erbe bleibt immer" (docs/OFFEN-HARALD.md, Entscheidungen 21.09.).
--   Haekchen "Lyra lernt" (`lernen`, Standard an) — buendelt drei Quellen unter EINEM Schalter:
--       a) Bindung (Welle 16) hat SCHON ein eigenes Haekchen (`bindungWaechst`) — wir setzen es
--          NUR nach oben/unten mit, ueber eine Kaskade in ns.onSetting. Core/Init.lua und
--          Sinne/Welle16.lua bleiben unberuehrt.
--       b) "gesagt" (Welle 15, Core/Regie.lua R.gesagtSchreiben) hat KEIN eigenes Haekchen. Wir
--          legen einen WRAPPER um die vorhandene Funktion (Muster Sinne/Welle16b.lua, dort um
--          ns.Stimmung.abstandFaktor/mikroPool) — Core/Regie.lua bleibt Wort fuer Wort stehen.
--       c) Rueckfragen (Welle 17, ns.Person) haben SCHON ein eigenes Haekchen (`personFragen`,
--          Sinne/Welle17.lua: "Aus = das Angebot kommt nie mehr, UND das Gespraechsfenster
--          bietet keine offene Frage mehr an") — dieselbe Kaskade wie bei bindungWaechst setzt
--          es nur mit. KEIN Wrapper um ns.melde noetig (Stand bis zum W17-Merge war das anders,
--          siehe Git-Historie; Sinne/Welle17.lua liegt jetzt im Baum, docs/welle17-2026-09-22.md
--          §2 nennt personFragen als das verbindliche Haekchen).
--   Haekchen "Spielzeit-Fenster" (`spielzeitFenster`, Standard AUS) — Vorbereitung, keine
--       Zeilen: Sinne/Leben2.lua/Sinne/Chronik.lua speichern heute KEINE Wochentage/Stunden
--       (der wenn-Schluessel "zeit" wird live aus der aktuellen Uhr gerechnet, nie
--       gespeichert — geprueft, docs/recherche/21…: "Uhrzeit ist ueber zeit schon da"). Diese
--       Welle legt das Haekchen DAVOR und einen minimalen, eigenen Zaehler (ns.char.spielzeit-
--       Fenster) an, den eine kuenftige Welle fuer Tageszeit-Zeilen lesen kann. Ohne Haekchen
--       wird NICHTS geschrieben.
--
-- DATEI-EIGENTUM: diese Datei, tests/pruefstand/w18_attrappen.lua + w18_harness.lua,
-- docs/welle18-2026-09-22.md. UI/Slash.lua wird um genau zwei Befehle erweitert (Marke "-- W18:").
-- UI/Settings.lua, Core/Init.lua, Core/Locale.lua, Locales/*, dialog.lua, UI/Dialog.lua, alle
-- anderen Sinne bleiben UNBERUEHRT — Texte stehen darum vollstaendig in dieser Datei (Muster
-- Sinne/Chronik.lua TEXT, Sinne/Welle16.lua TEXT), und die zwei neuen Dialogknoten-Gruppen
-- haengen sich beim LADEN an LyraGestalt_Dialog an (Muster Sinne/Welle6.lua W.assistentErweitern).
--
-- KONTRAKT: kein SendChatMessage, kein SendAddonMessage, kein C_ChatInfo, kein RunMacro, kein
-- CastSpell, kein ChatFrame-Print ausser ns.print, keine neue Globale, kein OnUpdate, kein
-- 0-s-Ticker. Jeder Zugriff auf ein fremdes/optionales Modul steht in pcall hinter einer
-- Existenzpruefung; faellt eine Quelle aus, zeigt "weisst" die passende Leer-Zeile und "vergiss"
-- loescht dort schlicht nichts — Ausfall ist Schweigen, nie ein Lua-Fehler.
--
-- NIE EIN FREMDER NAME: "weisst" zeigt nur ZAEHLER (Anzahl Vorgaenger, Anzahl Strecken, ...),
-- nie einen einzelnen Namen aus der Erbe-Liste oder der Chronik. "Antworten" zeigt nur, was der
-- SPIELER selbst ueber SICH beantwortet hat (ns.Person) — das ist keine dritte Person.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Welle18 = W
ns.Sinne.Welle18 = W

-- =================================================================================================
-- 0  HAEKCHEN. Core/Init.lua bleibt unberuehrt (Muster Sinne/Welle13a.lua): beide Schluessel
--    haengen sich auf DATEIEBENE an ns.DEFAULTS_ACCOUNT, lange vor ns.initDB().
-- =================================================================================================
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.lernen == nil then D.lernen = true end               -- "Lyra lernt" — Standard AN
    if D.spielzeitFenster == nil then D.spielzeitFenster = false end   -- Standard AUS (heikle Daten)
end

local function an(key) return ns.Get(key) ~= false end

-- =================================================================================================
-- 1  DIE KETTE "lernen" -> bindungWaechst + personFragen (Kaskade), gesagtSchreiben (Wrapper).
-- =================================================================================================

-- 1a Kaskade: "lernen" setzt "bindungWaechst" (Welle 16) UND "personFragen" (Welle 17,
--    docs/welle17-2026-09-22.md §2: "Aus = das Angebot kommt nie mehr, UND das Gespraechsfenster
--    bietet keine offene Frage mehr an") mit. Core/Init.lua/Sinne/Welle16.lua/Sinne/Welle17.lua
--    bleiben unberuehrt — beide Haekchen existieren schon, diese Kaskade setzt sie nur zusammen
--    mit "lernen" um. Sinne/Welle16b.lua zeigt dasselbe Muster (dort um ns.Stimmung.*), hier um
--    ns.onSetting. Kein Wrapper um ns.melde noetig: personFragen ist die Quelle der Wahrheit, an
--    der Sinne/Welle17.lua selbst schon jede Frage (Angebot UND offene Rueckfrage) misst.
local function settingWrappen()
    if W.settingGewrappt then return end
    W.settingGewrappt = true
    local orig = ns.onSetting
    ns.onSetting = function(key, value, ...)
        if orig then orig(key, value, ...) end
        if key == "lernen" and ns.Set then
            local wert = value and true or false
            pcall(ns.Set, "bindungWaechst", wert)
            pcall(ns.Set, "personFragen", wert)
        end
    end
end
settingWrappen()

-- 1b Wrapper um Core/Regie.lua R.gesagtSchreiben — "gesagt" (Welle 15) hat kein eigenes
--    Haekchen; mit "lernen" aus wird schlicht nicht mehr geschrieben (die Auswahl selbst liest
--    weiter unveraendert, eine schon gemerkte Zeile bleibt gemerkt — "einfrieren", kein Wischen).
--    R.gesagtSchreiben wird laut Core/Regie.lua NUR bei einer ECHTEN Ausgabe gerufen (vars.test
--    ist dort schon herausgefiltert) — diese Datei muss Proben also nicht extra abfangen.
local function gesagtSchreibenWrappen()
    if W.gesagtGewrappt then return end
    if not (ns.Regie and type(ns.Regie.gesagtSchreiben) == "function") then return end
    W.gesagtGewrappt = true
    local orig = ns.Regie.gesagtSchreiben
    ns.Regie.gesagtSchreiben = function(z, t)
        if not an("lernen") then return end
        return orig(z, t)
    end
end
gesagtSchreibenWrappen()

-- =================================================================================================
-- 2  SPIELZEIT-FENSTER — Vorbereitung, kein Verbrauch. Nur wenn an, ein Zaehler
--    ns.char.spielzeitFenster["<Wochentag 0-6>:<Stunde 0-23>"] = Haeufigkeit, EINMAL je Login.
--    Lokale Uhr des Spielers (os.date/date, kein Server-Wert), wie Sinne/Leben2.lua stunde().
-- =================================================================================================
local function wochentagStunde()
    local ok1, wt = pcall(function() return tonumber(date("%w")) end)
    local ok2, hh = pcall(function() return tonumber(date("%H")) end)
    if not (ok1 and ok2 and wt ~= nil and hh ~= nil) then return nil end
    return wt, hh
end
W.wochentagStunde = wochentagStunde   -- fuer den Pruefstand

-- REVIEW (Merge-Selbstpruefung): PLAYER_LOGIN feuert auch bei einem /reload MITTEN in der
-- Sitzung (Sinne/Chronik.lua kennt das als "fortgesetzte Sitzung", SITZUNG_FORTSETZEN). Ohne
-- Wache zaehlte jeder /reload als eigene "Sitzung" und der Eimer waere kein Sitzungs-, sondern
-- ein Klick-Zaehler. Wache nach demselben Muster wie Sinne/Welle16b.lua W.sitzungsgrenze():
-- die Startzeit der LAUFENDEN Chronik-Sitzung (ns.Chronik.stand(), existenzgeprueft) ist die
-- Sitzungs-ID; erst eine ANDERE Startzeit zaehlt als neue Sitzung. Ohne Sinne/Chronik.lua (sehr
-- alter Stand) faellt die Wache aus, und es wird trotzdem hoechstens einmal je PLAYER_LOGIN
-- gezaehlt - das war schon vorher die Zusage.
local function spielzeitFensterMerken()
    if not an("spielzeitFenster") then return end
    if type(ns.char) ~= "table" then return end
    if ns.Chronik and type(ns.Chronik.stand) == "function" then
        local ok, _, sitzung = pcall(ns.Chronik.stand)
        if ok and type(sitzung) == "table" then
            local start = tonumber(sitzung.start)
            if start and ns.char.spielzeitFensterSitzung == start then return end
            if start then ns.char.spielzeitFensterSitzung = start end
        end
    end
    local wt, hh = wochentagStunde()
    if not wt then return end
    ns.char.spielzeitFenster = ns.char.spielzeitFenster or {}
    local schluessel = tostring(wt) .. ":" .. tostring(hh)
    local t = ns.char.spielzeitFenster
    t[schluessel] = (tonumber(t[schluessel]) or 0) + 1
end
W.spielzeitFensterMerken = spielzeitFensterMerken   -- fuer den Pruefstand
ns.on("PLAYER_LOGIN", spielzeitFensterMerken)

-- =================================================================================================
-- 3  TEXTE — Core/Locale.lua/Locales/* bleiben unberuehrt (Muster Sinne/Chronik.lua TEXT).
-- =================================================================================================
local TEXT = {
    de = {
        kopf = "Was ich ueber dich weiss (alles bleibt in deiner SavedVariables-Datei, nichts verlaesst den Rechner):",
        bindung = "  Bindung: Stufe %d von 3 (%d Punkte)",
        bindungAus = "  Bindung: Stufe %d von 3 (%d Punkte) - Haekchen 'Lyra lernt' ist aus, eingefroren",
        chronik = "  Chronik: %d Zonen, %d Beinahe-Tode, %d Bestiarium, %d Sitzungen, %.1f Spielstunden",
        chronikLeer = "  Chronik: noch leer",
        gedaechtnis = "  Gedaechtnis: %d gemerkte Zeile(n), davon %d einmalig und %d Kettenschritte",
        gedaechtnisLeer = "  Gedaechtnis: noch nichts gemerkt",
        antworten = "  Antworten: %s",
        antwortenMehr = " (+%d weitere)",
        antwortenKeine = "  Antworten: keine gespeichert",
        antwortenFehlt = "  Antworten: keine Antworten gespeichert",
        flug = "  Flugzeiten: %d Strecke(n) gemessen",
        -- MERGE20: Welle 14d (Stufentempo, ns.char.stufenTempo).
        tempo = "  Stufentempo: %d Stufe(n) gemerkt",
        flugKeine = "  Flugzeiten: noch keine Strecke gemessen",
        spiel = "  Quiz 'Weisst du noch?': beste Runde %d von 5, %d Runde(n) gespielt",
        spielKeine = "  Quiz 'Weisst du noch?': noch nicht gespielt",
        profil = "  Spielstil: %s",
        erbe = "  Erbe: %d Vorgaenger - bleibt immer",
        erbeKeine = "  Erbe: keiner (bleibt immer)",
        lernen = "  Lernen aus Ereignissen: an",
        lernenAus = "  Lernen aus Ereignissen: aus (Einstellungen -> Lyra lernt)",
        stilNamen = { vorsichtig = "vorsichtig", normal = "normal", draufgaenger = "Draufgaenger" },
        vergissHilfe = "/lyra vergiss <gesagt|bindung|antworten|chronik|flug|spiel|profil|vorraete|tempo|alles>",
        vergissUnbekannt = "Unbekannter Bereich: %s. " ..
            "/lyra vergiss <gesagt|bindung|antworten|chronik|flug|spiel|profil|vorraete|tempo|alles>",
        vergissKeinDialog = "Das Gespraechsfenster fehlt - keine Rueckfrage moeglich, nichts geloescht.",
        vergissErbe = "Das Erbe bleibt immer. Wer es wirklich loeschen will, macht das in der Datei - nicht im Affekt.",
        frageAlles = "Wirklich alles? Das ist nicht rueckgaengig zu machen - dein Erbe bleibt.",
        frageBereich = "Wirklich %s vergessen? Das ist nicht rueckgaengig zu machen.",
        bereichName = {
            gesagt = "das Gedaechtnis", bindung = "die Bindung", antworten = "die Antworten",
            chronik = "die Chronik", flug = "die Flugzeiten", spiel = "den Quiz-Rekord",
            profil = "das Spielstil-Profil",
            -- MERGE20: Welle 14c/14d.
            vorraete = "die Vorrats- und Buff-Merker", tempo = "das Stufen- und Ruftempo",
        },
        ehrlich = {
            gesagt    = "Weg. Was ich mir gemerkt hatte, ist wieder offen.",
            bindung   = "Auf null. Die Spielstunden zaehlen weiter, der Rest faengt neu an.",
            antworten = "Vergessen, was du mir erzaehlt hast. Sag's mir gern nochmal.",
            chronik   = "Die Karten sind leer. Ich fang neu an zu schauen.",
            flug      = "Weg. Der naechste Flug ist wieder eine Schaetzung wert null.",
            spiel     = "Rekord weg. Naechste Runde zaehlt wieder bei null.",
            profil    = "Ich hab vergessen, wie du kaempfst. Zeig's mir neu.",
            vorraete  = "Weg. Ich schau wieder frisch in deine Taschen.",
            tempo     = "Das Stufentempo ist weg. Ab jetzt zaehl ich neu.",
        },
        ehrlichAlles = "Gut. Ich fange neu an. Nicht ganz - die Gefallenen bleiben.",
        abgebrochen = "Gut. Bleibt, wie's ist.",
        statusLernenAn = "Lyra lernt: an",
        statusLernenAus = "Lyra lernt: aus",
        statusZeitenAn = "Spielzeit-Fenster: an (lokal)",
        statusZeitenAus = "Spielzeit-Fenster: aus",
        hilfe1 = "/lyra weisst - zeigt, was Lyra ueber dich weiss",
        hilfe2 = "/lyra vergiss <bereich>|alles - loescht davon etwas (mit Rueckfrage)",
    },
    en = {
        kopf = "What I know about you (all of it stays in your SavedVariables file, nothing leaves this computer):",
        bindung = "  Bond: tier %d of 3 (%d points)",
        bindungAus = "  Bond: tier %d of 3 (%d points) - 'Lyra learns' is off, frozen",
        chronik = "  Chronicle: %d zones, %d near-deaths, %d bestiary, %d sessions, %.1f hours played",
        chronikLeer = "  Chronicle: still empty",
        gedaechtnis = "  Memory: %d remembered line(s), %d one-off and %d chain steps",
        gedaechtnisLeer = "  Memory: nothing remembered yet",
        antworten = "  Answers: %s",
        antwortenMehr = " (+%d more)",
        antwortenKeine = "  Answers: none stored",
        antwortenFehlt = "  Answers: no answers stored",
        flug = "  Flight times: %d route(s) measured",
        -- MERGE20: wave 14d (level pace, ns.char.stufenTempo).
        tempo = "  Level pace: %d level(s) remembered",
        flugKeine = "  Flight times: no route measured yet",
        spiel = "  Quiz 'Remember?': best round %d of 5, %d round(s) played",
        spielKeine = "  Quiz 'Remember?': not played yet",
        profil = "  Play style: %s",
        erbe = "  Legacy: %d predecessor(s) - stays forever",
        erbeKeine = "  Legacy: none (stays forever)",
        lernen = "  Learning from events: on",
        lernenAus = "  Learning from events: off (Settings -> Lyra learns)",
        stilNamen = { vorsichtig = "careful", normal = "normal", draufgaenger = "daredevil" },
        vergissHilfe = "/lyra forget <gesagt|bindung|antworten|chronik|flug|spiel|profil|vorraete|tempo|alles>",
        vergissUnbekannt = "Unknown area: %s. " ..
            "/lyra forget <gesagt|bindung|antworten|chronik|flug|spiel|profil|vorraete|tempo|alles>",
        vergissKeinDialog = "The dialogue window is missing - no way to confirm, nothing deleted.",
        vergissErbe = "The legacy always stays. Anyone who truly wants to delete it does it in the file - not on impulse.",
        frageAlles = "Really all of it? This can't be undone - your legacy stays.",
        frageBereich = "Really forget %s? This can't be undone.",
        bereichName = {
            gesagt = "the memory", bindung = "the bond", antworten = "the answers",
            chronik = "the chronicle", flug = "the flight times", spiel = "the quiz record",
            profil = "the play-style profile",
            -- MERGE20: wave 14c/14d.
            vorraete = "the supply and buff markers", tempo = "the level and reputation pace",
        },
        ehrlich = {
            gesagt    = "Gone. What I remembered is open again.",
            bindung   = "Back to zero. The play hours keep counting, the rest starts fresh.",
            antworten = "Forgotten what you told me. Feel free to say it again.",
            chronik   = "The maps are blank. I'll start looking again.",
            flug      = "Gone. The next flight is worth an estimate of zero again.",
            spiel     = "Record gone. Next round starts at zero again.",
            profil    = "I forgot how you fight. Show me again.",
            vorraete  = "Gone. I'll look into your bags with fresh eyes.",
            tempo     = "The pace record is gone. I'm counting fresh from here.",
        },
        ehrlichAlles = "Alright. I'm starting over. Not quite - the fallen stay.",
        abgebrochen = "Alright. Stays as it is.",
        statusLernenAn = "Lyra learns: on",
        statusLernenAus = "Lyra learns: off",
        statusZeitenAn = "Playtime window: on (local)",
        statusZeitenAus = "Playtime window: off",
        hilfe1 = "/lyra weisst - shows what Lyra knows about you",
        hilfe2 = "/lyra vergiss <area>|alles - erases some of it (with confirmation)",
    },
}
local function T() return TEXT[ns.sprache and ns.sprache() or "de"] or TEXT.de end

-- =================================================================================================
-- 4  DATENQUELLEN — jede einzeln existenzgeprueft/pcall, jeder Ausfall eine Leer-Zeile.
-- =================================================================================================
local function bindungInfo()
    if not (ns.Bindung and type(ns.Bindung.stufe) == "function" and type(ns.Bindung.punkte) == "function") then
        return nil
    end
    local ok1, stufe = pcall(ns.Bindung.stufe)
    local ok2, punkte = pcall(ns.Bindung.punkte)
    if not (ok1 and ok2 and type(stufe) == "number" and type(punkte) == "number") then return nil end
    return { stufe = stufe, punkte = punkte }
end

local function chronikDB()
    local c = LyraGestaltDB and LyraGestaltDB.chronik and ns.charKey and LyraGestaltDB.chronik[ns.charKey]
    return type(c) == "table" and c or nil
end

local function chronikZahlen()
    local c = chronikDB()
    if not c then return nil end
    local zonen, beinahe, best, sitz, stunden = 0, 0, 0, 0, 0
    if type(c.zonen) == "table" then for _ in pairs(c.zonen) do zonen = zonen + 1 end end
    if type(c.beinahe) == "table" then beinahe = #c.beinahe end
    if type(c.bestiarium) == "table" then for _ in pairs(c.bestiarium) do best = best + 1 end end
    if type(c.sitzungen) == "table" then
        sitz = #c.sitzungen
        for _, s in ipairs(c.sitzungen) do
            if type(s) == "table" then
                local a2, e2 = tonumber(s.start), tonumber(s.ende)
                if a2 and e2 and e2 > a2 then stunden = stunden + (e2 - a2) end
            end
        end
    end
    if zonen == 0 and beinahe == 0 and best == 0 and sitz == 0 then return nil end
    return { zonen = zonen, beinahe = beinahe, bestiarium = best, sitzungen = sitz, stunden = stunden / 3600 }
end

-- Katalog-Index: k -> { einmal = true|false } (einmal ODER blosser Kettenschritt). Einmalig
-- gescannt und gecacht - der geladene Katalog aendert sich zur Laufzeit nicht.
local katalogIndexCache = nil
local function katalogIndex()
    if katalogIndexCache then return katalogIndexCache end
    local idx = {}
    local ereignisse = _G.LyraGestalt_Phrasen and _G.LyraGestalt_Phrasen.ereignisse
    if type(ereignisse) == "table" then
        for _, e in pairs(ereignisse) do
            if type(e) == "table" and type(e.texte) == "table" then
                for _, z in ipairs(e.texte) do
                    if type(z) == "table" and z.k then idx[z.k] = { einmal = z.einmal and true or false } end
                end
            end
        end
    end
    katalogIndexCache = idx
    return idx
end
W.katalogIndexLeeren = function() katalogIndexCache = nil end   -- fuer den Pruefstand

local function gesagtZahlen()
    local Rg = ns.Regie
    if not (Rg and type(Rg.gesagtTabelle) == "function") then return nil end
    local okC, tc = pcall(Rg.gesagtTabelle, "char")
    local okK, tk = pcall(Rg.gesagtTabelle, "konto")
    if not (okC or okK) then return nil end
    local idx = katalogIndex()
    local gesamt, einmal = 0, 0
    local function zaehlen(t)
        if type(t) ~= "table" then return end
        for k in pairs(t) do
            gesamt = gesamt + 1
            if idx[k] and idx[k].einmal then einmal = einmal + 1 end
        end
    end
    zaehlen(okC and tc or nil)
    zaehlen(okK and tk or nil)
    return gesamt, einmal
end

-- ns.Person.alle() (Welle 17, docs/welle17-2026-09-22.md §2): ohne Argument liefert es
-- { char = { schluessel = {wert,t,quelle,n,hoch}, ... }, konto = { ... } } — beide Ebenen fuer
-- "/lyra weisst" in EINEM Aufruf. Fehlt ns.Person, gibt es "keine Antworten gespeichert".
local ANTWORTEN_MAX = 8
local function antwortenListe()
    if not (ns.Person and type(ns.Person.alle) == "function") then return nil end
    local ok, alle = pcall(ns.Person.alle)
    if not (ok and type(alle) == "table") then return nil end
    local out, gesehen = {}, {}
    local function einsammeln(ebene)
        if type(ebene) ~= "table" then return end
        for k, v in pairs(ebene) do
            if type(k) == "string" and not gesehen[k] then
                gesehen[k] = true
                local wert = (type(v) == "table") and v.wert or v
                -- REVIEW19: beobachtete Werte (meistzone/klasse/...) werden mitgezeigt, aber als
                -- solche gekennzeichnet - "Antworten" hiess sonst auch, was nie gefragt wurde.
                local beobachtet = (type(v) == "table") and v.quelle == "beobachtet" or false
                out[#out + 1] = { schluessel = k, wert = wert, beobachtet = beobachtet }
            end
        end
    end
    if type(alle.char) == "table" or type(alle.konto) == "table" then
        einsammeln(alle.char)
        einsammeln(alle.konto)
    else
        -- Rueckfall: eine flache Tabelle schluessel -> wert|{wert=...} (z. B. wenn irgendwo
        -- ns.Person.alle("char") ohne Schachtelung durchgereicht wird).
        einsammeln(alle)
    end
    table.sort(out, function(a, b) return a.schluessel < b.schluessel end)
    return out
end

local function flugStrecken()
    local t = ns.db and ns.db.flugzeiten
    if type(t) ~= "table" or type(t.strecken) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(t.strecken) do n = n + 1 end
    return n
end

-- MERGE20 (Merge 0.20.0): Welle 14d merkt je Charakter die gespielten Sekunden je Stufe
-- (ns.char.stufenTempo) - das ist Wissen ueber den Spieler und gehoert darum in "/lyra weisst".
-- Welle 14c speichert nur Merker ("Stufe X schon gemeldet"), kein Wissen - dort reicht vergiss.
local function stufenTempoAnzahl()
    if not (ns.Welle14d and type(ns.Welle14d.stufenTempo) == "function") then return 0 end
    local ok, t = pcall(ns.Welle14d.stufenTempo)
    if not (ok and type(t) == "table") then return 0 end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function quizRekord()
    if not (ns.Welle14e and type(ns.Welle14e.rekord) == "function") then return nil end
    local ok, r = pcall(ns.Welle14e.rekord)
    if not (ok and type(r) == "table") then return nil end
    return r
end

local function profilStil()
    if not (ns.Profil and type(ns.Profil.stil) == "function") then return nil end
    local ok, s = pcall(ns.Profil.stil)
    return (ok and type(s) == "string") and s or nil
end

local function trauerErsteZeile()
    if not (ns.Welle16b and type(ns.Welle16b.status) == "function") then return nil end
    local ok, z = pcall(ns.Welle16b.status)
    if ok and type(z) == "table" and type(z[1]) == "string" then return z[1] end
    return nil
end

local function erbeAnzahl()
    if not (ns.Erbe and type(ns.Erbe.liste) == "function") then return nil end
    local ok, liste = pcall(ns.Erbe.liste)
    if not (ok and type(liste) == "table") then return nil end
    local eigen = ns.charKey or "?"
    local n = 0
    for _, e in ipairs(liste) do
        if type(e) == "table" and e.name and e.name ~= ""
           and (e.quelle == nil or e.quelle == "selbst")
           and (tostring(e.name) .. "-" .. tostring(e.realm or "?")) ~= eigen then
            n = n + 1
        end
    end
    return n
end

-- =================================================================================================
-- 5  /lyra weisst
-- =================================================================================================
function W.weisstZeilen()
    local Tx = T()
    local out = { Tx.kopf }

    local b = bindungInfo()
    if b then out[#out + 1] = (an("lernen") and Tx.bindung or Tx.bindungAus):format(b.stufe, b.punkte) end

    local c = chronikZahlen()
    if c then
        out[#out + 1] = Tx.chronik:format(c.zonen, c.beinahe, c.bestiarium, c.sitzungen, c.stunden)
    else
        out[#out + 1] = Tx.chronikLeer
    end

    local antworten = antwortenListe()
    if antworten == nil then
        out[#out + 1] = Tx.antwortenFehlt
    elseif #antworten == 0 then
        out[#out + 1] = Tx.antwortenKeine
    else
        local teile = {}
        for i = 1, math.min(ANTWORTEN_MAX, #antworten) do
            local e = antworten[i]
            teile[#teile + 1] = tostring(e.schluessel) .. ": " .. tostring(e.wert)
                .. (e.beobachtet and ((ns.sprache and ns.sprache() == "de") and " (beobachtet)" or " (observed)") or "")
        end
        local zeile = Tx.antworten:format(table.concat(teile, " * "))
        if #antworten > ANTWORTEN_MAX then zeile = zeile .. Tx.antwortenMehr:format(#antworten - ANTWORTEN_MAX) end
        out[#out + 1] = zeile
    end

    local gesamt, einmal = gesagtZahlen()
    if gesamt and gesamt > 0 then
        out[#out + 1] = Tx.gedaechtnis:format(gesamt, einmal, gesamt - einmal)
    else
        out[#out + 1] = Tx.gedaechtnisLeer
    end

    local flug = flugStrecken()
    out[#out + 1] = (flug > 0) and Tx.flug:format(flug) or Tx.flugKeine

    local tempoN = stufenTempoAnzahl()
    if tempoN > 0 then out[#out + 1] = Tx.tempo:format(tempoN) end

    local quiz = quizRekord()
    if quiz and (tonumber(quiz.runden) or 0) > 0 then
        out[#out + 1] = Tx.spiel:format(tonumber(quiz.beste) or 0, tonumber(quiz.runden) or 0)
    else
        out[#out + 1] = Tx.spielKeine
    end

    local stil = profilStil()
    if stil and stil ~= "unbekannt" then out[#out + 1] = Tx.profil:format(Tx.stilNamen[stil] or stil) end

    local trauer = trauerErsteZeile()
    if trauer then out[#out + 1] = "  " .. trauer end

    local erbe = erbeAnzahl()
    out[#out + 1] = (erbe and erbe > 0) and Tx.erbe:format(erbe) or Tx.erbeKeine

    out[#out + 1] = an("lernen") and Tx.lernen or Tx.lernenAus
    return out
end

-- Kurzfassung fuer die Blase/den Dialogknoten: ein Satz, nicht der ganze Bericht.
function W.weisstKurz()
    local d = (ns.sprache and ns.sprache() or "de") == "de"
    local b = bindungInfo()
    local gesamt = gesagtZahlen() or 0
    if d then
        if b then
            return ("Ich weiss, wo wir stehen: Stufe %d Bindung, %d gemerkte Momente. Alles bleibt bei dir - die Zahlen stehen im Chat.")
                :format(b.stufe, gesamt)
        end
        return "Noch nicht viel, aber ich sammle. Alles bleibt bei dir - die Zahlen stehen im Chat."
    end
    if b then
        return ("I know where we stand: bond tier %d, %d remembered moments. It all stays with you - the numbers are in the chat.")
            :format(b.stufe, gesamt)
    end
    return "Not much yet, but I'm gathering. It all stays with you - the numbers are in the chat."
end

function W.weisstBefehl()
    for _, z in ipairs(W.weisstZeilen()) do ns.print(z) end
    if ns.Dialog and type(ns.Dialog.zeigeKnoten) == "function" then
        pcall(ns.Dialog.zeigeKnoten, "w18_weisst", { kurz = W.weisstKurz() })
    end
end

-- =================================================================================================
-- 6  /lyra vergiss <bereich>|alles
-- =================================================================================================
-- MERGE20 (Merge 0.20.0): zwei Bereiche dazu - "vorraete" (Welle 14c: Selbstbuff-Drossel,
-- Wohlgenaehrt-Sitzung, ns.char.vorratStufen) und "tempo" (Welle 14d: ns.char.stufenTempo/
-- stufenTempoStart, Ruf-Sitzung). Beide loeschen ueber das W.vergiss() ihres Moduls, weil jedes
-- mehr als einen Speicherort hat (Muster: "antworten" -> ns.Person.vergiss).
local BEREICHE = { gesagt = true, bindung = true, antworten = true, chronik = true,
                   flug = true, spiel = true, profil = true, vorraete = true, tempo = true }
local ALLE_BEREICHE = { "gesagt", "bindung", "antworten", "chronik", "flug", "spiel", "profil",
                        "vorraete", "tempo" }
W.BEREICHE, W.ALLE_BEREICHE = BEREICHE, ALLE_BEREICHE

-- Tatsaechliches Loeschen EINES Bereichs. Nur ueber die Schnittstelle des Moduls, wo es sie gibt
-- (ns.Regie.gesagtTabelle, ns.Person.vergiss); sonst gezielt die bekannten Schluessel in
-- LyraGestaltDB/ns.char - niemals LyraGestaltDB = {} oder eine ganze Fremdtabelle wegwerfen.
local function vergissEins(bereich)
    if bereich == "gesagt" then
        local Rg = ns.Regie
        if Rg and type(Rg.gesagtTabelle) == "function" then
            local okC, tc = pcall(Rg.gesagtTabelle, "char")
            local okK, tk = pcall(Rg.gesagtTabelle, "konto")
            if okC and type(tc) == "table" then for k in pairs(tc) do tc[k] = nil end end
            if okK and type(tk) == "table" then for k in pairs(tk) do tk[k] = nil end end
        end
        return true
    elseif bereich == "bindung" then
        if type(LyraGestaltDB) == "table" and type(LyraGestaltDB.bindung) == "table" then
            local b2 = LyraGestaltDB.bindung
            b2.beinahe, b2.tage, b2.letzterTag = 0, 0, ""
            b2.meilensteine, b2.antworten = 0, 0
            b2.stufeAngewandt, b2.stufeGesagt = 0, 0
            b2.grundlinie = false
            b2.verlauf = {}
        end
        return true
    elseif bereich == "antworten" then
        -- Primaer ueber die Schnittstelle des Moduls (docs/welle17-2026-09-22.md §2):
        -- ns.Person.vergiss() OHNE Argumente loescht ALLE Schluessel auf BEIDEN Ebenen - exakt
        -- das, was dieser Bereich braucht. Nur wenn ns.Person fehlt (sehr alter Stand), gezielt
        -- die bekannten Schluessel direkt leeren - als LEERE Tabelle, nicht {v=1}: das echte
        -- Schema (Sinne/Welle17.lua speicher()) traegt keine eigene Versionsmarke auf diesen
        -- beiden Tabellen, nur schluessel -> {wert,t,quelle,n,hoch}.
        if ns.Person and type(ns.Person.vergiss) == "function" then
            pcall(ns.Person.vergiss)
        elseif type(LyraGestaltDB) == "table" then
            if ns.charKey and type(LyraGestaltDB.chronik) == "table"
               and type(LyraGestaltDB.chronik[ns.charKey]) == "table" then
                LyraGestaltDB.chronik[ns.charKey].person = {}
            end
            if type(LyraGestaltDB.account) == "table" then
                LyraGestaltDB.account.person = {}
            end
        end
        return true
    elseif bereich == "chronik" then
        local c = chronikDB()
        if c then
            c.zonen, c.beinahe, c.bestiarium, c.sitzungen = {}, {}, {}, {}
        end
        -- W18: der Spielzeit-Fenster-Zaehler liegt zwar in ns.char, gehoert inhaltlich aber zur
        -- Chronik (je-Sitzung-Beobachtung) und wird hier bewusst mitgeloescht. Die Sitzungs-
        -- Wache (spielzeitFensterMerken) muss ebenfalls weg, sonst zaehlt die LAUFENDE Sitzung
        -- nach einem "/lyra vergiss chronik" nicht neu, weil ihre Startzeit schon "gesehen" war.
        if type(ns.char) == "table" then
            ns.char.spielzeitFenster = nil
            ns.char.spielzeitFensterSitzung = nil
        end
        return true
    elseif bereich == "flug" then
        if ns.db then ns.db.flugzeiten = nil end
        return true
    elseif bereich == "spiel" then
        if type(ns.char) == "table" then ns.char.spiel = nil end
        return true
    elseif bereich == "profil" then
        local c = chronikDB()
        if c then
            c.profil = { v = 1, kaempfe = 0, dauerSumme = 0, unter50 = 0, unter35 = 0, unter20 = 0,
                         rast = 0, fehlalarm = 0, hp35 = 0 }
        end
        return true
    elseif bereich == "vorraete" then
        if ns.Welle14c and type(ns.Welle14c.vergiss) == "function" then pcall(ns.Welle14c.vergiss) end
        return true
    elseif bereich == "tempo" then
        if ns.Welle14d and type(ns.Welle14d.vergiss) == "function" then pcall(ns.Welle14d.vergiss) end
        return true
    end
    return false
end
W.vergissEins = vergissEins   -- fuer den Pruefstand direkt aufrufbar

W.vergissAusstehend = nil   -- Bereich (oder "alles"), auf den die Rueckfrage gerade wartet

function W.vergissBefehl(bereichRoh)
    local Tx = T()
    local b = tostring(bereichRoh or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if b == "" then ns.print(Tx.vergissHilfe); return end
    if b == "erbe" or b == "legacy" then ns.print(Tx.vergissErbe); return end
    if b ~= "alles" and not BEREICHE[b] then ns.print(Tx.vergissUnbekannt:format(b)); return end
    if not (ns.Dialog and type(ns.Dialog.zeigeKnoten) == "function") then
        ns.print(Tx.vergissKeinDialog); return
    end
    W.vergissAusstehend = b
    local frage = (b == "alles") and Tx.frageAlles or Tx.frageBereich:format(Tx.bereichName[b] or b)
    pcall(ns.Dialog.zeigeKnoten, "w18_vergiss_frage", { frage = frage })
end

local function vergissJa()
    local b = W.vergissAusstehend
    W.vergissAusstehend = nil
    if not b then return "w18_vergiss_abgebrochen" end
    local Tx = T()
    local zeile
    if b == "alles" then
        for _, teil in ipairs(ALLE_BEREICHE) do pcall(vergissEins, teil) end
        zeile = Tx.ehrlichAlles
    else
        pcall(vergissEins, b)
        zeile = Tx.ehrlich[b] or Tx.ehrlichAlles
    end
    return "w18_vergiss_fertig", { zeile = zeile }
end

local function vergissNein()
    W.vergissAusstehend = nil
    return "w18_vergiss_abgebrochen"
end

local function aktionenRegistrieren()
    if not (ns.Dialog and type(ns.Dialog.aktionen) == "table") then return false end
    ns.Dialog.aktionen.w18_vergiss_ja = vergissJa
    ns.Dialog.aktionen.w18_vergiss_nein = vergissNein
    return true
end
W.aktionenRegistrieren = aktionenRegistrieren
ns.on("PLAYER_LOGIN", aktionenRegistrieren)

-- =================================================================================================
-- 7  DIALOGKNOTEN — beim LADEN angehaengt (Muster Sinne/Welle6.lua W.assistentErweitern).
--    dialog.lua und UI/Dialog.lua bleiben unberuehrt; ohne LyraGestalt_Dialog passiert nichts.
-- =================================================================================================
local function knotenAnhaengen()
    local D = _G.LyraGestalt_Dialog
    if type(D) ~= "table" or type(D.knoten) ~= "table" then return false end
    for _, k in ipairs(D.knoten) do
        if k.id == "w18_weisst" then return true end   -- schon angehaengt (zweiter Ladeversuch)
    end
    local K = D.knoten
    K[#K + 1] = {
        id = "w18_weisst", miene = "thinking",
        text = { de = "{kurz}", en = "{kurz}" },
        antworten = { { text = { de = "Gut zu wissen.", en = "Good to know." } } },
    }
    K[#K + 1] = {
        id = "w18_vergiss_frage", miene = "concerned",
        text = { de = "{frage}", en = "{frage}" },
        antworten = {
            { text = { de = "Ja, wirklich.", en = "Yes, really." }, aktion = "w18_vergiss_ja" },
            { text = { de = "Nein, doch nicht.", en = "No, never mind." }, aktion = "w18_vergiss_nein" },
        },
    }
    K[#K + 1] = {
        id = "w18_vergiss_fertig", miene = "touched", ende = true,
        text = { de = "{zeile}", en = "{zeile}" },
    }
    K[#K + 1] = {
        id = "w18_vergiss_abgebrochen", miene = "neutral", ende = true,
        text = { de = "Gut. Bleibt, wie's ist.", en = "Alright. Stays as it is." },
    }
    return true
end
W.knotenAnhaengen = knotenAnhaengen   -- fuer den Pruefstand erneut aufrufbar (idempotent)
pcall(knotenAnhaengen)

-- =================================================================================================
-- 8  /lyra status, /lyra hilfe (UI/Slash.lua ruft hierher, Marke "-- W18:")
-- =================================================================================================
function W.status()
    local Tx = T()
    return {
        an("lernen") and Tx.statusLernenAn or Tx.statusLernenAus,
        an("spielzeitFenster") and Tx.statusZeitenAn or Tx.statusZeitenAus,
    }
end

function W.hilfe()
    local Tx = T()
    return { Tx.hilfe1, Tx.hilfe2 }
end
