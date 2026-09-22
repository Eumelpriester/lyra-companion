-- Sinne/Welle15c.lua — Welle 15c "Lyra ueber sich" (0.19.0, 22.09.2026).
--
-- Vier Dialog-AKTIONEN fuer den neuen Ast in ueber_dialog.lua (Muster: D.aktionen.befinden/ort/ziel
-- in UI/Dialog.lua — eine Aktion liest den Zustand und liefert eine Knoten-ID, nie einen Text
-- direkt). Diese Datei registriert sich NUR in die schon vorhandene, offene Tabelle
-- ns.Dialog.aktionen; UI/Dialog.lua selbst bleibt unberuehrt (kein Diff noetig — anders als die
-- eine Zeile in dialog.lua, die der Bericht als Textbaustein liefert).
--
--   ueber_herkunft        — Bindungsstufe -> herkunft_0/1/2a/3a (gestaffelter Kanon "verlorene Rune")
--   ueber_meinung_klasse   — UnitClass-Token -> mk_<klasse> (Spitze; "Und das Gute?" fuehrt zu
--                            mk_<klasse>_lob, beides steht als Daten in ueber_dialog.lua)
--   ueber_meinung_zone      — eigene Chronik-Zonen (besuche/beinahe) -> mz_beinahe/mz_erste/mz_oft
--   ueber_rat               — Lage (Kampf/Leben/Zone-Gefahr/Sitzung/Gruppe/Tageszeit/Rast) -> rat_*
--
-- WO DIESE DATEI IN DER TOC STEHT: GANZ ZULETZT, hinter Sinne/Welle16b.lua (Merge-Vorschlag).
--   * Sie liest ns.Bindung.stufe() (existenzgeprueft, Rueckfall ns.Stimmung.vertraut() — genau die
--     Regel aus den Zusaetzen 0.19 oben) und ns.Stimmung.zustand() (hp/sitzung/rast/zeit) — beide
--     Sinne sollen fertig geladen sein, auch wenn beide Zugriffe zur LAUFZEIT erst beim Klick
--     passieren und die Ladereihenfolge deshalb gleichgueltig waere (wie bei Sinne/Welle14a.lua).
--   * Sie registriert Aktionen in ns.Dialog.aktionen — UI/Dialog.lua muss also existieren
--     (das tut es seit Zeile 171 der TOC, lange vor jedem Sinn dieser Liste).
--
-- KONTRAKT: kein SendChatMessage, kein SendAddonMessage, kein C_ChatInfo, kein RunMacro, kein
-- CastSpell, kein ChatFrame-Print (diese Datei ruft weder ns.print noch den Chat direkt auf),
-- keine neue Globale, kein OnUpdate, kein Ticker, kein Ereignis, keine Regie-Meldung (die
-- "Ueber dich"-Zeilen laufen wie jeder Dialogtext NICHT durch die Regie — der Spieler hat aktiv
-- geklickt). Jeder Zugriff auf eine
-- Spiel-API oder ein fremdes Modul steht in pcall hinter einer Existenzpruefung; faellt einer aus,
-- landet die Aktion auf dem letzten, harmlosen Zweig (Stufe 0 / "sonst"), nie auf einem Lua-Fehler.
--
-- BEWUSST KEIN HAEKCHEN: die Regel "jeder Sinn hat ein eigenes Haekchen" gilt fuer AMBIENTE
-- Sinne, die von selbst reden (Regie-Ereignisse, OnUpdate/UNIT_AURA/BAG_UPDATE). Diese Datei tut
-- nichts, bis der Spieler im offenen Gespraechsfenster mit der Maus auf "Über dich" klickt — wie
-- rituale_dialog.lua/spiel_dialog.lua hat auch dieser Ast keinen eigenen Schalter, sondern haengt
-- am bestehenden Gespraech (Gespraechigkeit/Stummschaltung gelten unveraendert mit).
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Welle15c = W
ns.Sinne.Welle15c = W

-- Existenzpruefung wie ueberall im Projekt: kein Zugriff auf ein fremdes Modul ohne Typ-Check.
-- Faellt ns.Dialog aus (Ladefehler in UI/Dialog.lua), registriert diese Datei nichts und bleibt
-- sonst vollstaendig (W.status/W.bindungStufe funktionieren weiter, /lyra status sagt "keine
-- Aktion" ueber die leere Liste unten).
local D_DA = type(ns.Dialog) == "table" and type(ns.Dialog.aktionen) == "table"
if D_DA then ns.Dialog.aktionen = ns.Dialog.aktionen or {} end

-- ---------------------------------------------------------------------------------------------
-- Bindungsstufe (0..3). Regel aus dem Auftrag: ns.Bindung.stufe() mit Existenzpruefung, sonst
-- ns.Stimmung.vertraut() (die ihrerseits, falls vorhanden, auf ns.Bindung.stufe() zurueckfaellt —
-- diese Funktion hier verdoppelt die Kette trotzdem lesbar, statt sich blind auf S.vertraut() zu
-- verlassen: faellt IRGENDEIN Glied aus, bleibt am Ende Stufe 0, nie ein Fehler).
-- ---------------------------------------------------------------------------------------------
local function bindungStufe()
    if ns.Bindung and type(ns.Bindung.stufe) == "function" then
        local ok, s = pcall(ns.Bindung.stufe)
        if ok and type(s) == "number" then return s end
    end
    if ns.Stimmung and type(ns.Stimmung.vertraut) == "function" then
        local ok, s = pcall(ns.Stimmung.vertraut)
        if ok and type(s) == "number" then return s end
    end
    return 0
end
W.bindungStufe = bindungStufe

-- =================================================================================================
-- 1) HERKUNFT — Bindungsstufe entscheidet, wie viel Lyra von der "verlorenen Rune" erzaehlt.
--    Stufe 0 weicht aus, Stufe 1 deutet an, Stufe 2 erzaehlt den Kanon (zweiteilig: herkunft_2a
--    dann "Und weiter?" -> herkunft_2b), Stufe 3 haengt daran, was sie fuerchtet (herkunft_3a
--    -> "Sag's." -> herkunft_3b). Der Kanon bleibt konsistent mit dialog.lua (ueber_lyra:
--    "Runenweberin, zweite Lehre abgebrochen"; lore_2: Leylinien wie Adern; lore_6: brennender
--    Vorhang, sehr ruhiger Meister) — es ist dieselbe Geschichte, nur tiefer erzaehlt.
-- =================================================================================================
function W.ueber_herkunft()
    local stufe = bindungStufe()
    if stufe >= 3 then return "herkunft_3a" end
    if stufe >= 2 then return "herkunft_2a" end
    if stufe >= 1 then return "herkunft_1" end
    return "herkunft_0"
end
if D_DA then ns.Dialog.aktionen.ueber_herkunft = W.ueber_herkunft end

-- =================================================================================================
-- 2) MEINUNG ZUR KLASSE — UnitClass("player") liefert den Token (zweiter Rueckgabewert, siehe
--    Sinne/Persoenlichkeit.lua P.KLASSEN — dieselben neun Schluessel). Fehlt der Token (fremder
--    Client, Attrappe ohne Angabe), bleibt es beim neutralen Ausweichknoten mk_unbekannt.
-- =================================================================================================
local KLASSEN_BEKANNT = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
    SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true,
}
function W.ueber_meinung_klasse()
    local token
    if type(UnitClass) == "function" then
        local ok, _, t = pcall(UnitClass, "player")
        if ok and type(t) == "string" then token = t end
    end
    if token and KLASSEN_BEKANNT[token] then
        return "mk_" .. token:lower()
    end
    return "mk_unbekannt"
end
if D_DA then ns.Dialog.aktionen.ueber_meinung_klasse = W.ueber_meinung_klasse end

-- =================================================================================================
-- 3) MEINUNG ZUR ZONE — dieselbe lesende Struktur wie UI/Dialog.lua zoneInfo()/bestiariumZahl()
--    (LyraGestaltDB.chronik[charKey].zonen[zone] = { besuche, beinahe }), nur ohne Zahl im Text:
--    die Zahl steckt in der WAHL des Knotens (Regel aus Welle 15b/Recherche 20 §3.3), nicht im
--    Satz — so bleibt die Zeile platzhalterfrei und damit vertonbar.
--    Vorrang: kuerzlich/ort-bezogen knapp entkommen schlaegt alles andere; sonst erster Besuch;
--    sonst "oft hier".
-- =================================================================================================
local function chronikDB()
    local key = ns.charKey
    local db = LyraGestaltDB
    if not (type(db) == "table" and type(key) == "string") then return nil end
    local c = db.chronik and db.chronik[key]
    return type(c) == "table" and c or nil
end

local function hierZonenEintrag()
    local zone
    if type(GetRealZoneText) == "function" then
        local ok, z = pcall(GetRealZoneText)
        if ok and type(z) == "string" and z ~= "" then zone = z end
    end
    if not zone then return nil end
    local c = chronikDB()
    local e = c and type(c.zonen) == "table" and c.zonen[zone]
    return (type(e) == "table") and e or nil
end

function W.ueber_meinung_zone()
    local e = hierZonenEintrag()
    local beinahe = (e and tonumber(e.beinahe)) or 0
    local besuche = (e and tonumber(e.besuche)) or 0
    if beinahe > 0 then return "mz_beinahe" end
    if besuche <= 1 then return "mz_erste" end
    return "mz_oft"
end
if D_DA then ns.Dialog.aktionen.ueber_meinung_zone = W.ueber_meinung_zone end

-- =================================================================================================
-- 4) "WAS WUERDEST DU TUN?" — acht Lagen aus fuenf Achsen (Leben, Kampf, Zone-Gefahr, Tageszeit,
--    Gruppe), Prioritaet von dringend nach beilaeufig — dasselbe Baumuster wie D.aktionen.befinden
--    (kampf > beinahe > rast > normal). Grenze aus dem Auftrag: Lyra BENENNT die Lage, sie schlaegt
--    nie eine Route, Skillung oder Questreihenfolge vor — keine dieser acht Zeilen nennt eine Zone,
--    einen Ort oder eine Handlung ausser "weitermachen"/"aufpassen".
--    Quelle: ns.Regie.imKampf (Kampf-Flag, Core/Regie.lua), ns.Stimmung.zustand() (hp/sitzung/
--    rast/zeit — dieselbe kanonische Quelle wie Sinne/Leben2.lua fuer jeden anderen Sinn),
--    IsInGroup/IsInRaid (Blizzard-API, direkt — dasselbe Muster wie Sinne/Bedrohung.lua/Alltag.lua).
-- =================================================================================================
local LANGE_SITZUNG_H = 3   -- Stunden am Stueck, ab wann "lange Sitzung" greift

local function zustand()
    if not (ns.Stimmung and type(ns.Stimmung.zustand) == "function") then return nil end
    local ok, z = pcall(ns.Stimmung.zustand)
    return (ok and type(z) == "table") and z or nil
end

local function inGruppe()
    local ok1, g = pcall(function() return IsInGroup and IsInGroup() end)
    if ok1 and g then return true end
    local ok2, r = pcall(function() return IsInRaid and IsInRaid() end)
    return (ok2 and r) and true or false
end

function W.ueber_rat()
    local imKampf = (ns.Regie and ns.Regie.imKampf) and true or false
    if imKampf then return "rat_kampf" end
    local z = zustand()
    if z and type(z.hp) == "number" and z.hp < 35 then return "rat_niedrig" end
    if z and z.nachwirkung then return "rat_zone" end
    if z and type(z.sitzung) == "number" and z.sitzung >= LANGE_SITZUNG_H then return "rat_lang" end
    if inGruppe() then return "rat_gruppe" end
    if z and (z.zeit == "nacht" or z.zeit == "spaet") then return "rat_nacht" end
    if z and z.rast then return "rat_rast" end
    return "rat_sonst"
end
if D_DA then ns.Dialog.aktionen.ueber_rat = W.ueber_rat end

-- ---------------------------------------------------------------------------------------------
-- /lyra status
-- ---------------------------------------------------------------------------------------------
function W.status()
    local stufe = bindungStufe()
    return {
        ("Welle 15c 'Ueber dich': Bindungsstufe %d, %d Aktionen registriert (Herkunft/Klasse/Zone/Rat)")
            :format(stufe, 4),
    }
end
