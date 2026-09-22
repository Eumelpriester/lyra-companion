-- UI/Dialog.lua — Gespraechsbaum v0 (Daten: dialog.lua) und Intent-Parser fuer /lyra <freitext>.
-- Dialog-Texte laufen NICHT durch die Regie (der Spieler hat aktiv gefragt), nur die Miene ueber ns.Gestalt.miene.
-- Fenster ueber der Gestalt ersetzt die Blase; bis zu 4 Antwortknoepfe; Ziffern 1-4 nur bei offenem Dialog
-- und nur ausserhalb des Kampfes (SetPropagateKeyboardInput ist im Kampf gesperrt); ESC ueber UISpecialFrames.
-- FIX3 (17.09.2026, Lesbarkeit): Das Fenster hatte noch die helle Blasen-Optik von 0.2.x -
-- ChatBubble-Grund zu 92 % deckend, dunkler Text, dazu OUTLINE. Der schwarze Umriss um fast
-- schwarze Schrift schliesst bei 13-14 px die Innenflaechen der Buchstaben (dieselbe Lehre, die
-- Gestalt/Blase.lua in 0.3.0 schon gezogen hat - das Dialogfenster war dabei vergessen worden),
-- und durch die fehlenden 8 % Deckung bewegt sich das Spielbild unter der Schrift.
-- Jetzt: dunkle Optik wie UI/Menue.lua, heller Text ohne Umriss eine Stufe groesser, Antworten auf
-- eigenem, VOLL deckendem Grund, Ziffer in Gold. Kontrasttabelle: docs/fix3-2026-09-17.md.
-- API (nur lesend): UnitExists/UnitIsPlayer/UnitName/UnitClassification("target"), UnitHealth,
--   GetRealZoneText/GetSubZoneText, IsResting, InCombatLockdown, GetTime, time, date. Nichts Fremdes.
--   REVIEW9: Stufen NUR ueber ns.Compat.unitLevelLesbar() — auf Retail/FOREVER ist die Stufe einer
--   fremden Einheit im Kampf ein Secret Value, und "Gespraech im Kampf" ist ausdruecklich erlaubt.
local ADDON, ns = ...
local D = {}
ns.Dialog = D

-- MAX_ANTWORTEN bleibt 4 (Tasten 1-4, siehe Hilfetext in Locales). FIX2: Knoten duerfen mehr
-- Eintraege haben, solange sich Bedingungen ausschliessen; ein Abschneiden meldet jetzt ns.debug.
local BREITE, RAND, KNOPF_H, MAX_ANTWORTEN = 380, 14, 22, 4   -- design-v3: Questdialog-Muster, 380 breit
local PORTRAIT, NAME_H = 64, 22
local KNOPF_ABSTAND = 3       -- FIX3: Luft zwischen den Antwortflaechen, damit sie als Knoepfe lesbar sind
local ZIFFER_B = 18           -- px Platz fuer das Ziffern-Praefix "1." (waechst bei grosser Schrift)
local FUSS = 18               -- B-4: Hoehe der Kuerzel-Zeile am Fuss

-- DESIGN-V3 B-2 / e.2 (17.09.2026): Hier stand bis 0.6.1 eine ZWEITE Farbtafel neben der in
-- UI/Optik.lua - unvollstaendig (ohne titel, linie, warn; im Normalsatz ohne zifferH) und zur
-- Laufzeit ohnehin nie benutzt, weil ns.Optik Vorrang hatte. Zwei Tafeln fuer dieselben Farben
-- sind Doppelpflege und ein Fehler, der auf jemanden wartet: wer eine Farbe in Optik.lua aendert,
-- hat die Kopie hier still liegen gelassen. Sie ist geloescht. UI/Optik.lua steht in der TOC
-- VOR dieser Datei; fehlt sie, ist das Addon ohnehin kaputt.
local function farben() return ns.Optik.farben() end
local function groesse() return ns.Optik.schriftgroesse() end
local ENDE_DAUER = 4          -- s, bis ein Ende-Knoten das Fenster schliesst
local BEINAHE_FENSTER = 600   -- s, "beinahe gestorben" gilt als kuerzlich
local NOTIZEN_MAX = 50

D.beinaheZeit = 0
D.loreIndex = 0
D.loreLauf = 0            -- FIX2: Lore-Zeilen im laufenden Gespraech (max LORE_PRO_LAUF)
D.LORE_PRO_LAUF = 3
D.intentIndex = {}
D.aktuell = nil
local ticker

local function daten() return LyraGestalt_Dialog end
local function L(k) return ns.L[k] end
local function sprache() return ns.sprache() end
local function txt(t, vars)
    if not t then return "" end
    local s = t[sprache()] or t.en or ""
    return ns.fuelle(ns.Anrede(s), vars)
end
local function fragment(gruppe, key)
    local d = daten()
    local g = d and d.fragmente and d.fragmente[gruppe]
    local t = g and (g[key] or g.unbekannt)
    return t and (t[sprache()] or t.en) or ""
end

-- ---------------------------------------------------------------------------------------------
-- REVIEW7 (17.09.2026) — Dialog-Stimme
-- Die Dialog-Texte laufen nicht durch die Regie, hatten also bis 0.6.2 keine Stimme: Lyra sprach
-- jede Warnung, aber kein einziges Wort im Gespraech, das der Spieler selbst geoeffnet hat.
--
-- NAMENSREGEL (Katalog: docs/dialog-stimme.json, Renderer: tools/phrasen_common.py jobs()):
--   Datei     = <ID>:lower() .. "-" .. <Nummer der Zeile im Eintrag>    (hier immer "-1")
--   Anrede    = zusaetzlich "-m"/"-f", wenn der Text der AKTIVEN Sprache ein Anrede-Token traegt
--   Knoten    DIALOG_K_<KNOTENID>       -> dialog_k_<knotenid>-1[-m|-f]
--   Intent    DIALOG_I_<INTENT>_<n>     -> dialog_i_<intent>_<n>-1[-m|-f]
--   Freitext  DIALOG_UNBEKANNT_<n>      -> dialog_unbekannt_<n>-1[-m|-f]
--
-- Die Anrede-Entscheidung faellt ueber die AKTIVE Sprache, nicht fest ueber das Deutsche: jobs()
-- bildet die Dateinamen je Sprache aus t[lang], und neun englische Zeilen tragen kein Token, wo
-- das Deutsche eines hat ("hero" statt "{Held|Heldin}"). Eine feste de-Pruefung wuerde im
-- englischen Paket nach "...-m.ogg" suchen, das es dort gar nicht gibt - neun stumme Zeilen.
-- Das ist exakt die Regel aus Core/Regie.lua (ns.hatToken(zeile[sprache]) + ns.geschlecht()).
--
-- Gesprochen wird NUR, was ohne Platzhalter auskommt: "{zone}", "{name}", "{liste}" stehen im
-- Renderskript nicht zur Verfuegung, solche Zeilen sind gar nicht erst gerendert. Fehlt eine
-- Datei im Manifest, ist es still - Stimme.lua prueft das selbst (vorhanden()).
-- ---------------------------------------------------------------------------------------------
local STIMME_KLASSE = "plauder"   -- Warnungen behalten Vorfahrt (Gestalt/Stimme.lua)

-- "{wort}" = Platzhalter (ns.fuelle). "{Held|Heldin}" ist KEINER - da steht ein | drin, und
-- %a+ gefolgt von } trifft nicht zu.
local function hatPlatzhalter(s) return s ~= nil and s:find("{%a+}") ~= nil end

-- basis = "dialog_k_start" | "dialog_i_hilfe_2" | "dialog_unbekannt_3"; t = die Textzeile
-- ({ de = ..., en = ... }). Rueckgabe: Dateiname ohne ".ogg", oder nil (dann schweigt sie).
local function stimmeName(basis, t)
    if not (basis and type(t) == "table") then return nil end
    local s = t[sprache()] or t.en
    if not s or s == "" or hatPlatzhalter(s) then return nil end
    local name = basis .. "-1"
    if ns.hatToken(s) then
        local g = ns.geschlecht()
        if g == "keine" then return nil end   -- die Zeile existiert nur als -m/-f
        name = name .. "-" .. g
    end
    return name
end
D.stimmeName = stimmeName

-- Laufende Dialogzeile abbrechen. Warnungen werden NICHT abgebrochen (S.stoppe prueft die Klasse).
local function stimmeStopp()
    if ns.Stimme and ns.Stimme.stoppe then pcall(ns.Stimme.stoppe, STIMME_KLASSE) end
end

-- Eine Dialogzeile sprechen. Reihenfolge: erst die alte Zeile stoppen (sonst reden die Antwort und
-- der naechste Knoten uebereinander), dann die neue anstossen.
local function sprich(name)
    stimmeStopp()
    if not name then return false end
    if not (ns.Get("stimme") and ns.Stimme and ns.Stimme.spiele) then return false end
    local ok, gespielt = pcall(ns.Stimme.spiele, name, STIMME_KLASSE, 0)
    return (ok and gespielt) and true or false
end
D.sprich = sprich

-- Knoten-Index (einmalig aus der Liste)
local index
local function knoten(id)
    local d = daten()
    if not d then return nil end
    if not index then
        index = {}
        for _, k in ipairs(d.knoten or {}) do index[k.id] = k end
    end
    return index[id]
end

-- ---------------------------------------------------------------------------------------------
-- Zustand lesen (fuer Aktionen). Grenze B: UnitIsPlayer-Sperre steht als Erstes.
-- ---------------------------------------------------------------------------------------------
local function imKampf() return (ns.Regie and ns.Regie.imKampf) or (InCombatLockdown and InCombatLockdown()) or false end
local function beinaheKuerzlich()
    local t = math.max(D.beinaheZeit or 0, tonumber(ns.beinaheZuletzt) or 0)
    return t > 0 and (GetTime() - t) < BEINAHE_FENSTER
end
local function ortText()
    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "?"
    local sub = (GetSubZoneText and GetSubZoneText()) or ""
    if sub ~= "" and sub ~= zone then return sub .. ", " .. zone, zone end
    return zone, zone
end
-- Optionale Chronik-Hooks (Modul kann fehlen): ns.Chronik.zoneInfo(zone) -> string|nil,
-- ns.Chronik.bestiarium(name) -> Zahl|nil. Alles per pcall, nie vorausgesetzt.
local function chronikRuf(fn, ...)
    local C = ns.Chronik
    if not (C and type(C[fn]) == "function") then return nil end
    local ok, v = pcall(C[fn], ...)
    if ok then return v end
    return nil
end
-- Lesender Fallback direkt auf LyraGestaltDB.chronik[charKey] (Struktur aus Sinne/Chronik.lua v1):
-- zonen[z] = { besuche, beinahe }, bestiarium[npcId] = { name, beinahe, tode }. Nur lesen, nie anlegen.
local function chronikDB()
    local c = LyraGestaltDB and LyraGestaltDB.chronik and ns.charKey and LyraGestaltDB.chronik[ns.charKey]
    return type(c) == "table" and c or nil
end
local function zoneInfo(zone)
    local v = chronikRuf("zoneInfo", zone)
    if type(v) == "string" and v ~= "" then return v end
    local c = chronikDB()
    local e = c and type(c.zonen) == "table" and c.zonen[zone]
    if type(e) ~= "table" then return nil end
    if (e.beinahe or 0) > 0 then return ns.fuelle(ns.Anrede(fragment("zone", "beinahe")), { n = e.beinahe }) end
    if (e.besuche or 0) > 1 then return ns.fuelle(fragment("zone", "besuche"), { n = e.besuche }) end
    return nil
end
local function bestiariumZahl(name)
    local v = tonumber(chronikRuf("bestiarium", name))
    if v then return v end
    local c = chronikDB()
    if not (c and type(c.bestiarium) == "table" and UnitGUID) then return nil end
    local guid = UnitGUID("target")
    local id = type(guid) == "string" and guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    local e = id and c.bestiarium[id]
    if type(e) ~= "table" then return nil end
    return (tonumber(e.beinahe) or 0) + (tonumber(e.tode) or 0)
end

-- Beinahe-Ereignisse merken (HP20 / ATEM10 sind die "fast gestorben"-Warnungen)
if ns.nachAusgabe then
    ns.nachAusgabe(function(id)
        if id == "HP20" or id == "ATEM10" then D.beinaheZeit = GetTime() end
    end)
end

-- ---------------------------------------------------------------------------------------------
-- Bedingungen und Aktionen (per Name aus dialog.lua). Aktion: -> knotenId|nil, vars|nil
-- ---------------------------------------------------------------------------------------------
D.bedingungen = {
    hatZiel = function() return UnitExists and UnitExists("target") or false end,
    keinZiel = function() return not (UnitExists and UnitExists("target")) end,
    imKampf = imKampf,
    nichtImKampf = function() return not imKampf() end,
}

D.aktionen = {}
function D.aktionen.befinden()
    if imKampf() then return "befinden_kampf" end
    if beinaheKuerzlich() then return "befinden_beinahe" end
    if IsResting and IsResting() then return "befinden_rast" end
    return "befinden_normal"
end
function D.aktionen.ort()
    local ort, zone = ortText()
    local info = zoneInfo(zone)
    if info then return "ort_chronik", { ort = ort, zone = zone, info = info } end
    return "ort", { ort = ort, zone = zone }
end
function D.aktionen.ziel()
    if not (UnitExists and UnitExists("target")) then return "ziel_keins" end
    if UnitIsPlayer and UnitIsPlayer("target") then return "ziel_spieler" end   -- Grenze B, als Erstes
    local name = UnitName("target") or "?"
    -- REVIEW9: hier stand "... or 0". Damit kam der unlesbare Fall (Secret Value auf
    -- Retail/FOREVER: unitLevelLesbar gibt nil) als Stufe 0 an, und 0 <= eigen - 3 ist ab
    -- Stufe 3 wahr — Lyra haette jeden Gegner im Kampf als "leicht" eingestuft, also genau
    -- die gefaehrlichste Falschaussage. nil muss nil bleiben; der Zweig "unbekannt" unten
    -- ist dafuer schon da und war nur unerreichbar.
    local lvl = ns.Compat.unitLevelLesbar and ns.Compat.unitLevelLesbar("target") or nil
    local klasse = UnitClassification and UnitClassification("target") or "normal"
    -- Die EIGENE Stufe ist nirgends secret, aber der Helfer pcallt und prueft den Typ.
    local eigen = ns.Compat.unitLevelLesbar and ns.Compat.unitLevelLesbar("player") or 0
    -- WELLE 14a (21.09.2026, Spieltest-Befund Harald): Bis hierher rechnete diese Aktion Stufe
    -- gegen Stufe, OHNE zu fragen, ob man das Ziel ueberhaupt angreifen kann. Ein
    -- Orgrimmar-Waechter (65, Elite, freundlich) bekam damit "Zu stark, {Held|Heldin}" — eine
    -- Kampfeinschaetzung fuer einen Kampf, den es nicht geben kann. UnitCanAttack steht jetzt
    -- VOR dem Bestiarium (ein nicht angreifbarer NPC hat den Spieler nie getoetet) und fuehrt
    -- zu einer Auskunft statt eines Urteils: Beruf und Quest, geliefert von Sinne/Welle14a.lua.
    -- Fehlt der Sinn oder weiss er nichts, bleibt die trockene Zeile "verbuendet.sonst" —
    -- niemals wieder ein Staerkevergleich. Alles andere unterhalb ist unveraendert.
    local angreifbar = true
    if UnitCanAttack then
        local okA, darf = pcall(UnitCanAttack, "player", "target")
        if okA then angreifbar = darf and true or false end
    end
    if not angreifbar then
        local info
        local V = ns.Welle14a
        if V and type(V.verbuendet) == "function" then
            local okV, t = pcall(V.verbuendet, "target")
            if okV and type(t) == "table" then info = t end
        end
        info = info or {}
        local rolle = info.rolle and fragment("verbuendet", "rolle_" .. tostring(info.rolle)) or nil
        if rolle == "" then rolle = nil end
        local quest = (info.quest == "gibt" or info.quest == "nimmt") and info.quest or nil
        local schluessel
        if rolle and quest then schluessel = "rolle_" .. quest
        elseif rolle then schluessel = "rolle_nur"
        elseif quest then schluessel = quest
        else schluessel = "sonst" end
        -- {rolle} wird HIER gefuellt: ns.fuelle laeuft in einem Durchgang und ersetzt nichts,
        -- was es selbst eingesetzt hat (Core/Anrede.lua:41-44).
        local satz = ns.fuelle(ns.Anrede(fragment("verbuendet", schluessel)), { name = name, rolle = rolle })
        return "ziel_info", {
            name = name,
            level = (lvl and lvl > 0) and tostring(lvl) or "??",
            art = fragment("art", klasse),
            vergleich = satz,
        }
    end
    local n = bestiariumZahl(name)
    if n and n > 0 then return "ziel_bekannt", { name = name, n = n } end
    local vergleich
    if not lvl or lvl < 0 then vergleich = "unbekannt"
    elseif lvl >= eigen + 3 then vergleich = "schwer"
    elseif lvl <= eigen - 3 then vergleich = "leicht"
    else vergleich = "gleich" end
    return "ziel_info", {
        name = name,
        level = (lvl and lvl > 0) and tostring(lvl) or "??",
        art = fragment("art", klasse),
        vergleich = ns.Anrede(fragment("vergleich", vergleich)),
    }
end
-- FIX2: Lore-Rotation.
-- Vorher: D.loreIndex startete bei jedem /reload wieder bei 0 (immer dieselbe erste Zeile) und die
-- Zahl 3 stand fest im Code; "Noch eine" lief endlos im Kreis lore_1..lore_3.
-- Jetzt: Zaehler in LyraGestaltDB.chronik[charKey].loreIdx (ueberlebt /reload), Anzahl der Zeilen
-- aus den Daten gezaehlt, hoechstens LORE_PRO_LAUF Zeilen je Gespraech, danach lore_ende.
local function loreAnzahl()
    if D.loreN then return D.loreN end
    local n = 0
    while knoten("lore_" .. (n + 1)) do n = n + 1 end
    D.loreN = n
    return n
end
local function loreIdxLesen()
    local c = chronikDB()
    local v = c and tonumber(c.loreIdx)
    return v or D.loreIndex or 0
end
local function loreIdxSchreiben(i)
    if not (LyraGestaltDB and ns.charKey) then return end
    LyraGestaltDB.chronik = LyraGestaltDB.chronik or {}
    local c = LyraGestaltDB.chronik[ns.charKey]
    if type(c) ~= "table" then c = {}; LyraGestaltDB.chronik[ns.charKey] = c end
    c.loreIdx = i   -- nur dieses Feld: zonen/bestiarium/notizen bleiben unangetastet
end
function D.aktionen.lore()
    local n = loreAnzahl()
    if n == 0 then return nil end
    -- Im offenen Gespraech ist nach LORE_PRO_LAUF Zeilen Schluss (der Freitext-Weg /lyra erzaehl nicht).
    if D.offen() and (D.loreLauf or 0) >= D.LORE_PRO_LAUF and knoten("lore_ende") then
        D.loreLauf = 0
        return "lore_ende"
    end
    local i = (loreIdxLesen() % n) + 1
    D.loreIndex = i
    loreIdxSchreiben(i)
    D.loreLauf = (D.loreLauf or 0) + 1
    return "lore_" .. i
end
function D.aktionen.still()
    if ns.stillSetzen then ns.stillSetzen(true) else ns.stillModus = true end
    return "still_ok"
end

-- Erst-Start-Assistent (dialog.lua setup_*): Flag setzen, Minimap-Knopf einmal pulsen lassen und
-- den LOGIN-Gruss nachholen, der beim ersten Start fuer den Assistenten unterdrueckt wurde.
--
-- W6 (Recherche 10, A6): Seit Welle 6 gibt es eine VIERTE Frage - "soll ich zu sehen sein?".
-- Der Knoten heisst "setup_figur" und steht NICHT in dialog.lua: Sinne/Welle6.lua haengt ihn
-- beim Laden an LyraGestalt_Dialog.knoten an und legt die vier Antworten von "setup_reden" auf
-- ihn um (deren aktion "setupFertig" wandert damit hierher zurueck, nur eine Frage spaeter).
-- Warum nicht in der Datendatei: dialog.lua gehoert keinem Team dieser Welle, und ein Knoten,
-- der mit seinem Feature kommt und geht, gehoert zu diesem Feature. Findet der Patch seine
-- Anker nicht, bleibt der Assistent exakt der dreifragige von 0.10.0 - /lyra status sagt es.
function D.aktionen.setupFertig()
    local neu = not ns.Get("eingerichtet")
    D.setze("eingerichtet", true)
    if neu and ns.assistentFertig then pcall(ns.assistentFertig) end
    return "setup_ende"
end

-- ---------------------------------------------------------------------------------------------
-- Fenster
-- ---------------------------------------------------------------------------------------------
-- REVIEW: Frame-Name noetig fuer UISpecialFrames (ESC schliesst, auch im Kampf).
local f = CreateFrame("Frame", "LyraGestaltDialog", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
f:SetFrameStrata("MEDIUM")
f:SetFrameLevel(30)   -- ueber der Blase (20)
f:SetSize(BREITE, 100)
f:SetClampedToScreen(true)
f:EnableMouse(true)
-- DESIGN-V3 B-2 / P1-7: Hier stand eine ZWEITE Backdrop-Tabelle neben ns.Optik.O.BACKDROP -
-- derselbe Fehlertyp wie die doppelte Farbtafel. layoutFarben() ruft ohnehin ns.Optik.panel(f),
-- das die Kachel setzt; diese Kopie war nur der Zustand VOR dem ersten Oeffnen. Jetzt eine Tabelle
-- fuer Blase, Menue und Dialog: ein Rand, drei Fenster.
if f.SetBackdrop and ns.Optik then pcall(f.SetBackdrop, f, ns.Optik.BACKDROP) end
f:Hide()
tinsert(UISpecialFrames, "LyraGestaltDialog")
D.frame = f

-- design-v3 E: Portrait links oben (rund, Miene des Knotens), Name in Lyras Violett, Text rechts daneben,
-- Trennlinie, dann die Antworten. Das Muster, das jeder WoW-Spieler aus Questdialogen kennt.
local portrait = ns.Optik and ns.Optik.portrait(f, PORTRAIT) or nil
if portrait then portrait.frame:SetPoint("TOPLEFT", RAND, -RAND) end
local name = f:CreateFontString(nil, "OVERLAY")
name:SetPoint("TOPLEFT", RAND + PORTRAIT + 10, -RAND - 2)
name:SetJustifyH("LEFT")
local untertitel = f:CreateFontString(nil, "OVERLAY")
untertitel:SetPoint("LEFT", name, "RIGHT", 8, 0)
untertitel:SetJustifyH("LEFT")
-- FIX5: Schrift sofort, nicht erst in layoutFarben. Eine FontString ohne Schrift wirft bei SetText
-- einen harten Lua-Fehler ("Font not set") - genau daran ist in 0.6.0 das Menue gestorben.
name:SetFont(STANDARD_TEXT_FONT, 15, "")
untertitel:SetFont(STANDARD_TEXT_FONT, 11, "")
local linie = ns.Optik and ns.Optik.trennlinie(f) or f:CreateTexture(nil, "ARTWORK")
-- B-4: die Zeile, die sagt, dass es die Ziffern gibt. Im Kampf ausgegraut (dort greifen sie nicht).
local fuss = f:CreateFontString(nil, "OVERLAY")
fuss:SetPoint("BOTTOMLEFT", RAND, 6)
fuss:SetPoint("BOTTOMRIGHT", -RAND, 6)
fuss:SetJustifyH("CENTER")
fuss:SetFont(STANDARD_TEXT_FONT, 11, "")   -- FIX5-Regel: Schrift IMMER vor dem ersten SetText
D.fuss = fuss
D.portrait = portrait
local text = f:CreateFontString(nil, "OVERLAY")
text:SetPoint("TOPLEFT", RAND + PORTRAIT + 10, -RAND - NAME_H)
text:SetPoint("TOPRIGHT", -RAND, -RAND - NAME_H)
text:SetJustifyH("LEFT")
text:SetWordWrap(true)
text:SetFont(STANDARD_TEXT_FONT, 15, "")   -- FIX3: kein OUTLINE, eine Stufe groesser als die Antworten
D.text = text

local function flaeche(tex, c)
    if not tex then return end
    if tex.SetColorTexture then tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    else pcall(tex.SetTexture, tex, c[1], c[2], c[3], c[4] or 1) end
end

-- FIX3: Hover faerbt Grund UND Schrift um (nicht nur eine ADD-Textur darueber) - so bleibt der
-- Kontrast in beiden Zustaenden gerechnet und der Knopf sieht auch im Kontrast-Modus nach Knopf aus.
function D.knopfFarbe(b, drauf)
    if not b or not b.bg then return end
    local c = farben()
    flaeche(b.bg, drauf and c.knopfH or c.knopf)
    if b.balken then if drauf then b.balken:Show() else b.balken:Hide() end end
    local t = drauf and c.antwortH or c.antwort
    b.text:SetTextColor(t[1], t[2], t[3])
    local z = (drauf and c.zifferH) or c.ziffer
    b.nr:SetTextColor(z[1], z[2], z[3])
end

local knoepfe = {}
local knopfH = KNOPF_H   -- FIX3: waechst mit der Schriftgroesse (layoutFarben)
for i = 1, MAX_ANTWORTEN do
    local b = CreateFrame("Button", nil, f)
    b:SetHeight(knopfH)
    b:SetPoint("LEFT", RAND, 0)
    b:SetPoint("RIGHT", -RAND, 0)
    -- Eigener, voll deckender Grund: die Antwort steht nie auf dem durchscheinenden Spielbild.
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    b.bg = bg
    local balken = b:CreateTexture(nil, "ARTWORK")   -- design-v3: 3 px violetter Balken links bei Hover
    balken:SetPoint("TOPLEFT", 0, 0); balken:SetPoint("BOTTOMLEFT", 0, 0); balken:SetWidth(3)
    if ns.Optik then ns.Optik.flaeche(balken, ns.Optik.LILA) end
    balken:Hide()
    b.balken = balken
    local nr = b:CreateFontString(nil, "OVERLAY")   -- Ziffern-Praefix "1." in Gold
    nr:SetPoint("LEFT", 6, 0)
    nr:SetWidth(ZIFFER_B)
    nr:SetJustifyH("LEFT")
    nr:SetFont(STANDARD_TEXT_FONT, 14, "")
    b.nr = nr
    local t = b:CreateFontString(nil, "OVERLAY")
    t:SetPoint("LEFT", 6 + ZIFFER_B, 0)
    t:SetPoint("RIGHT", -6, 0)
    t:SetJustifyH("LEFT")
    t:SetFont(STANDARD_TEXT_FONT, 14, "")
    b.text = t
    b:SetScript("OnClick", function(self) D.antwort(self.antwort) end)
    b:SetScript("OnEnter", function(self) D.knopfFarbe(self, true) end)
    b:SetScript("OnLeave", function(self) D.knopfFarbe(self, false) end)
    b:Hide()
    knoepfe[i] = b
end

local function layoutFarben()
    -- B-1: eine Stelle fuer die Groesse. Sie kennt "auto" (folgt UIParent:GetEffectiveScale()).
    local size = groesse()
    local c = farben()
    -- Lyras Text: schrift+1, ohne Umriss, mit weichem Schatten (schliesst keine Buchstaben zu)
    text:SetFont(STANDARD_TEXT_FONT, size + 1, "")
    if text.SetShadowOffset then
        pcall(text.SetShadowOffset, text, 1, -1)
        if text.SetShadowColor then pcall(text.SetShadowColor, text, 0, 0, 0, 0.6) end
    end
    if text.SetSpacing then pcall(text.SetSpacing, text, math.floor((size + 1) * 0.3)) end
    text:SetTextColor(c.text[1], c.text[2], c.text[3])
    if ns.Optik then
        ns.Optik.panel(f)
        if linie.SetColorTexture then ns.Optik.flaeche(linie, c.linie or { 0.706, 0.549, 1, 0.35 }) end
    else
        if f.SetBackdropColor then f:SetBackdropColor(c.panel[1], c.panel[2], c.panel[3], c.panel[4]) end
        if f.SetBackdropBorderColor then f:SetBackdropBorderColor(c.rand[1], c.rand[2], c.rand[3], c.rand[4]) end
    end
    -- FIX5: ueber ns.Optik.setzeText (erst Schrift, dann Text) - eine Stelle fuer alle Fenster.
    if ns.Optik and ns.Optik.setzeText then
        ns.Optik.setzeText(name, "Lyra", size + 1, c.titel or c.text)
        ns.Optik.setzeText(untertitel, ns.L["Arcane mage"], math.max(10, size - 4), { 0.6, 0.55, 0.7 })
    else
        name:SetText("Lyra"); untertitel:SetText(ns.L["Arcane mage"])
    end
    -- B-4: "1-4 · Esc schliesst". Alpha 0,4 im Kampf - dort ist die Tastatur gesperrt.
    if ns.Optik and ns.Optik.setzeText then
        ns.Optik.setzeText(fuss, (ns.L["Keys hint"] or "1-%d"):format(MAX_ANTWORTEN),
            math.max(9, size - 3), c.linie or ns.Optik.LILA)
        pcall(fuss.SetAlpha, fuss, (InCombatLockdown and InCombatLockdown()) and 0.4 or 1)
    end
    -- Breite waechst mit der Schrift (bei 18+ Punkt sonst zu schmale Zeilen), max 40 % Bildschirm.
    -- design-v3 c: von 24 auf 28 je Punkt - dieselbe Zahl wie die Blasenbreite, sonst ist das
    -- Gespraech schmaler als die Sprechblase daneben.
    local breite = math.max(BREITE, math.min(size * 28, (UIParent:GetWidth() or 1920) * 0.4))
    f:SetWidth(breite)
    -- Der Knopf muss mitwachsen, sonst schneidet er bei "Schrift 20" die Unterlaengen ab.
    knopfH = math.max(KNOPF_H, size + 8)
    -- design-v3 c: ab 20 Punkt klebt die Ziffer sonst am Text - Innenabstaende 6/24 -> 8/28.
    local links = (size >= 20) and 8 or 6
    local zifferB = (size >= 20) and 20 or ZIFFER_B
    for i = 1, MAX_ANTWORTEN do
        local b = knoepfe[i]
        b.text:SetFont(STANDARD_TEXT_FONT, size, "")
        b.nr:SetFont(STANDARD_TEXT_FONT, size, "")
        b.nr:ClearAllPoints(); b.nr:SetPoint("LEFT", links, 0); b.nr:SetWidth(zifferB)
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", links + zifferB, 0)
        b.text:SetPoint("RIGHT", -links, 0)
        b:SetHeight(knopfH)
        D.knopfFarbe(b, false)
    end
end

local function anker()
    f:ClearAllPoints()
    local g = ns.Gestalt and ns.Gestalt.frame
    if g and not ns.Get("versteckt") then
        -- B-7: freieSeite() kennt jetzt die Hindernisse (Questie-Tracker, Minimap, Chat, Details).
        -- Damit die Pruefung etwas zu pruefen hat, bekommt sie das Mass DIESES Fensters.
        local seite = ns.Optik and ns.Optik.freieSeite(f:GetWidth(), f:GetHeight()) or "RIGHT"
        if seite == "RIGHT" then f:SetPoint("BOTTOMLEFT", g, "BOTTOMRIGHT", 8, 0) else f:SetPoint("BOTTOMRIGHT", g, "BOTTOMLEFT", -8, 0) end
    else f:SetPoint("CENTER", UIParent, "CENTER", 0, 120) end
end

-- REVIEW2: EnableKeyboard koennte im Kampf gesperrt sein (Era-Stand unklar; OnHide via ESC laeuft ohne pcall) -> nie ein sichtbarer Fehler
local function kb(an) pcall(f.EnableKeyboard, f, an) end
-- Tastatur: nur ausserhalb des Kampfes. Propagate wird je Taste gesetzt (Ziffern 1-4 schlucken, Rest durchreichen).
local function tastaturAn()
    if InCombatLockdown and InCombatLockdown() then kb(false); return end
    pcall(f.SetPropagateKeyboardInput, f, true)
    kb(true)
end
f:SetScript("OnKeyDown", function(self, key)
    local durch = true
    -- W14E (Merge 0.17.0): waehrend eines laufenden Spiels ("Weisst du noch?", Sinne/Welle14e.lua)
    -- greifen die Ziffern NUR auf dem Taxi. Ein Gespraech dauert Sekunden, ein Spiel Minuten - und
    -- in diesen Minuten gehoert die "2" auf den Zauber und nicht auf Knopf 2. Auf dem Greifen ist
    -- die Aktionsleiste ohnehin gesperrt, dort kostet das Abfangen nichts.
    -- Der Riegel steht hier und nicht als Mantel um ns.Dialog.zeigeKnoten: der Mantel hat die
    -- Tastatur des ganzen Fensters abgeschaltet (also auch ESC-Weiterreichung und jede spaetere
    -- Nutzung), dieser hier laesst nur die vier Ziffern durchfallen. Die Abfrage steht vor
    -- tonumber, damit sie auch dann greift, wenn eine spaetere Welle die Ziffernlogik aendert.
    -- REVIEW17: Beide Fragen in pcall. Diese Funktion laeuft bei JEDEM Tastendruck, und wenn sie
    -- vor der letzten Zeile abbricht, wird SetPropagateKeyboardInput NICHT mehr gerufen - dann
    -- bleibt der Wert des vorigen Drucks stehen. War das ein geschluckter Antwort-Knopf (false),
    -- frisst das Fenster ab da JEDE Taste, auch WASD. Weder ns.Welle14e noch UnitOnTaxi gehoeren
    -- uns; ein Fremd-Addon darf beide zur Laufzeit ersetzen. Im Zweifel ist die Ziffer GESPERRT
    -- (zifferOk = false), also faellt sie ans Spiel durch - das ist die sichere Seite.
    local spiel = false
    local W14 = ns.Welle14e
    if W14 and type(W14.laeuft) == "function" then
        local okS, laeuft = pcall(W14.laeuft)
        spiel = (okS and laeuft) and true or false
    end
    local zifferOk = true
    if spiel then
        zifferOk = false
        if type(UnitOnTaxi) == "function" then
            local okT, aufTaxi = pcall(UnitOnTaxi, "player")
            zifferOk = (okT and aufTaxi) and true or false
        end
    end
    local n = tonumber(key) or tonumber((key or ""):match("^NUMPAD(%d)$"))
    if zifferOk and n and n >= 1 and n <= MAX_ANTWORTEN and knoepfe[n]:IsShown() then
        durch = false
        D.antwort(knoepfe[n].antwort)
    end
    if not (InCombatLockdown and InCombatLockdown()) then pcall(self.SetPropagateKeyboardInput, self, durch) end
end)
ns.on("PLAYER_REGEN_DISABLED", function() kb(false) end)
ns.on("PLAYER_REGEN_ENABLED", function() if f:IsShown() then tastaturAn() end end)

function D.offen() return f:IsShown() end

-- B-1: Wechselt die UI-Groesse, waehrend das Gespraech offen steht, wird der Knoten neu bemessen.
if ns.Optik and ns.Optik.beiSchrift then
    ns.Optik.beiSchrift(function()
        if not f:IsShown() then return end
        local k = D.aktuell
        if k and k.id then D.zeigeKnoten(k.id, D.aktuellVars) end
    end)
end

-- W9b: das Eingabefeld haengt unter diesem Fenster und muss mit ihm verschwinden - und zwar
-- MIT Fokusabwurf. Ein sichtbares Gespraech, das zugeht, waehrend der Cursor noch im Feld
-- steht, waere genau der Zustand, in dem WASD nicht mehr ankommt.
local function freitextZu()
    if ns.Freitext and ns.Freitext.verstecke then pcall(ns.Freitext.fokusWeg) end
    if ns.Freitext and ns.Freitext.frame then pcall(ns.Freitext.frame.Hide, ns.Freitext.frame) end
end

-- REVIEW17 (Welle 14e): WER DAS FENSTER SCHLIESST, BEENDET AUCH DAS MINISPIEL.
-- Sinne/Welle14e.lua raeumt W.lauf nur in seinem eigenen W.zu() weg. Das Fenster geht aber auch
-- an W.zu VORBEI zu - ESC ueber UISpecialFrames, der Rechtsklick auf die Gestalt (D.oeffne
-- weiter unten), UI/Menue.lua M.oeffne und ns.Freitext.verstecke rufen alle D.schliesse bzw.
-- Hide. Blieb W.lauf dabei stehen, war ns.Welle14e.laeuft() fuer den Rest der Sitzung wahr: die
-- Ziffern 1-4 waren in jedem spaeteren Gespraech tot (OnKeyDown oben), und der Landungs-Riegel
-- haette spaeter "Wir sind da. Spiel aus." zu einem laengst verlassenen Spiel gesagt.
-- W.fensterZu() ist wortlos und schliesst nichts nach; der Aufruf steht in BEIDEN Wegen, weil
-- der Prueftstand-Frame bei Hide() kein OnHide feuert und der echte Client bei ESC kein
-- D.schliesse.
local function spielBeenden()
    local W14 = ns.Welle14e
    if W14 and type(W14.fensterZu) == "function" then pcall(W14.fensterZu) end
end
local function spielLaeuft()
    local W14 = ns.Welle14e
    if not (W14 and type(W14.laeuft) == "function") then return false end
    local ok, l = pcall(W14.laeuft)
    return (ok and l) and true or false
end

function D.schliesse()
    if ticker then ticker:Cancel(); ticker = nil end
    stimmeStopp()    -- REVIEW7: wer das Fenster zumacht, will sie auch nicht weiterreden hoeren
    D.aktuell = nil
    D.loreLauf = 0   -- FIX2: neues Gespraech = wieder bis zu drei Lore-Zeilen
    kb(false)
    freitextZu()
    spielBeenden()   -- REVIEW17
    f:Hide()
end
f:SetScript("OnHide", function()
    if ticker then ticker:Cancel(); ticker = nil end
    D.aktuell = nil
    D.loreLauf = 0   -- FIX2: auch bei ESC / Ausblenden
    kb(false)
    freitextZu()
    spielBeenden()   -- REVIEW17: ESC beendet das Minispiel genauso wie jeder andere Weg
end)

-- Knoten anzeigen
function D.zeigeKnoten(id, vars)
    local k = knoten(id)
    if not k then ns.debug("Dialog: Knoten fehlt " .. tostring(id)); return false end
    if ticker then ticker:Cancel(); ticker = nil end
    D.aktuell = k
    D.aktuellVars = vars    -- B-1: fuer das Neu-Bemessen nach einem UI-Scale-Wechsel
    if ns.Blase and ns.Blase.verstecke then ns.Blase.verstecke() end
    if ns.Gestalt and k.miene then ns.Gestalt.miene(k.miene, 10) end
    layoutFarben()
    anker()
    text:SetText(txt(k.text, vars))
    -- REVIEW7: Dialog-Stimme. Jeder Knotenwechsel stoppt die laufende Zeile zuerst (sprich() tut
    -- das auch, wenn dieser Knoten selbst keine Datei hat) - sonst ueberlagert die Antwort auf
    -- Knoten 1 noch den Text von Knoten 2. Warnungen bleiben unberuehrt.
    sprich(stimmeName("dialog_k_" .. tostring(k.id or id):lower(), k.text))
    if portrait then portrait:miene(k.miene or (ns.Gestalt and ns.Gestalt.aktuell) or "neutral") end
    local h = math.max(RAND + NAME_H + text:GetStringHeight(), RAND + PORTRAIT) + 8
    linie:ClearAllPoints()
    linie:SetPoint("TOPLEFT", RAND, -h)
    linie:SetPoint("TOPRIGHT", -RAND, -h)
    h = h + 8
    local n = 0
    for _, a in ipairs(k.antworten or {}) do
        -- FIX2: Abschneiden war bisher stumm - im Debug-Modus faellt es jetzt auf.
        if n >= MAX_ANTWORTEN then ns.debug("Dialog: zu viele Antworten in " .. tostring(id)); break end
        local ok = true
        if a.bedingung then
            local fn = D.bedingungen[a.bedingung]
            ok = fn and fn() and true or false
        end
        if ok then
            n = n + 1
            local b = knoepfe[n]
            b.antwort = a
            b.nr:SetText(n .. ".")           -- FIX3: Ziffer als eigene FontString (Gold)
            b.text:SetText(txt(a.text))
            D.knopfFarbe(b, false)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", RAND, -h)
            b:SetPoint("RIGHT", -RAND, 0)
            b:Show()
            h = h + knopfH + KNOPF_ABSTAND
        end
    end
    for i = n + 1, MAX_ANTWORTEN do knoepfe[i]:Hide(); knoepfe[i].antwort = nil end
    -- B-4: Die Kuerzel-Zeile steht nur, wenn es Knoepfe gibt. Auf einem Ende-Knoten gibt es keine
    -- Tasten, also auch keinen Hinweis darauf.
    local fussH = 0
    if n > 0 then fuss:Show(); fussH = FUSS else fuss:Hide() end
    f:SetHeight(math.max(48, h + RAND + fussH))
    -- B-3: weiche Oeffnung (Alpha 0 -> 1 in 0,08 s) - aber nur beim OEFFNEN. Ein Knotenwechsel
    -- im laufenden Gespraech darf nicht jedes Mal neu aufblenden, das waere Flackern.
    if f:IsShown() then
        f:Show()
    elseif ns.Optik and ns.Optik.einblenden then
        ns.Optik.einblenden(f)
    else
        f:Show()
    end
    if k.ende or n == 0 then
        kb(false)
        ticker = ns.Compat.NewTicker(ENDE_DAUER, function() D.schliesse() end, 1)
    else
        tastaturAn()
    end
    -- W9b: das Eingabefeld unter das Fenster haengen. OHNE Fokus - der kommt nur auf Klick.
    -- Das ist keine Bequemlichkeitsfrage: ein EditBox, das sich beim Oeffnen den Fokus nimmt,
    -- frisst die Ziffern 1-4 des Antwortmenues und im Ernstfall WASD.
    -- REVIEW17: WAEHREND EINES MINISPIELS BLEIBT DAS FELD ZU. "Maus, nur Maus" (Recherche 19
    -- §2.2, Punkt 1) war bisher nur fuer Sinne/Welle14e.lua und spiel_dialog.lua zugesagt - das
    -- Gespraechsfenster haengte sein EditBox aber an JEDEN Knoten mit Knoepfen, also auch an
    -- jede Quizfrage. Ein Gespraech dauert Sekunden, ein Spiel Minuten: in diesen Minuten steht
    -- ein anklickbares Eingabefeld unter dem Fenster, und ein Klick hinein frisst WASD, bis der
    -- Fokus faellt. Der Kampf-Riegel in UI/Freitext.lua raeumt den Fokus zwar weg, aber erst
    -- NACH PLAYER_REGEN_DISABLED. Fuer ein Spiel ist das die falsche Reihenfolge.
    if ns.Freitext and ns.Freitext.zeige and not (k.ende or n == 0) then
        if spielLaeuft() then freitextZu() else pcall(ns.Freitext.zeige) end
    end
    return true
end

-- Einstellung setzen (immer ueber ns.Settings.setze, damit ein offenes Panel synchron bleibt).
function D.setze(key, value)
    if ns.Settings and ns.Settings.setze then ns.Settings.setze(key, value) else ns.Set(key, value) end
end

-- Antwort ausfuehren: erst "setzt" (Einstellungen), dann Aktion (kann Knoten + Vars liefern),
-- die Vorrang vor "weiter" hat.
function D.antwort(a)
    if not a then return end
    if type(a.setzt) == "table" then
        for k, v in pairs(a.setzt) do D.setze(k, v) end
    end
    -- W17: Feld "merkt" neben "setzt" — schreibt ins Personen-Gedaechtnis (ns.Person) statt in
    -- die Einstellungen. Form: { schluessel = "...", wert = ..., ebene = "char"|"konto" }.
    -- Existenzpruefung + pcall: ns.Person kann fehlen (Welle 17 nicht gemergt), dann ist dieser
    -- Knopf wie jeder andere ohne "merkt" — er "weiter"t oder fuehrt seine Aktion trotzdem aus.
    if type(a.merkt) == "table" and ns.Person and type(ns.Person.setze) == "function" then
        local m = a.merkt
        if type(m.schluessel) == "string" and m.schluessel ~= "" then
            pcall(ns.Person.setze, m.schluessel, m.wert, m.quelle or "frage", m.ebene)
        end
    end
    local ziel, vars = a.weiter, nil
    if a.aktion then
        local fn = D.aktionen[a.aktion]
        if fn then
            -- REVIEW17: die Aktion in pcall. Sie lief bisher nackt - ein Fehler darin ist ein
            -- roter Lua-Fehler mitten im Klick, und seit Welle 14e haengen acht Aktionen des
            -- Minispiels daran, die auf einem Flug ueber Minuten immer wieder gerufen werden.
            -- Hausregel des Projekts: Ausfall ist Schweigen, nie ein Fehler. Der Fehler geht
            -- nicht verloren - er steht in /lyra debug -, und das Fenster faellt auf "weiter"
            -- bzw. auf schliessen zurueck (ziel bleibt a.weiter).
            local ok, id, v = pcall(fn)
            if not ok then
                ns.debug("Dialog: Aktion " .. tostring(a.aktion) .. " gestolpert: " .. tostring(id))
            elseif id then
                ziel, vars = id, v
            end
        else
            ns.debug("Dialog: Aktion fehlt " .. tostring(a.aktion))
        end
    end
    if ziel then D.zeigeKnoten(ziel, vars) else D.schliesse() end
end

function D.oeffne(id)
    local d = daten()
    if not d then ns.print(L("Dialog missing")); return false end
    if ns.Menue and ns.Menue.schliesse then ns.Menue.schliesse() end
    D.loreLauf = 0   -- FIX2: jedes neu geoeffnete Gespraech faengt mit dem Lore-Kontingent neu an
    return D.zeigeKnoten(id or d.start or "start")
end

-- FIX5 (0.6.1): Der Rechtsklick auf die Gestalt landet hier. Kontextsensitiv - wer mit einem
-- feindlichen Ungeheuer im Ziel nach ihr greift, will fast immer wissen, WAS das ist; die
-- Antwort "Was weisst du ueber mein Ziel?" wird also gleich mitgenommen. Die Ziel-Knoten
-- (ziel_info / ziel_bekannt) haben "Zurueck." zum Start-Knoten, es geht also nichts verloren.
-- Grenze B bleibt: ueber Spieler redet sie nicht - UnitIsPlayer steht als Erstes und fuehrt
-- zum normalen Start-Knoten, nicht zu ziel_spieler.
local function zielFeindlichesUngeheuer()
    if not (UnitExists and UnitExists("target")) then return false end
    if UnitIsPlayer and UnitIsPlayer("target") then return false end
    if UnitIsDead and UnitIsDead("target") then return false end
    if UnitCanAttack then
        local ok, v = pcall(UnitCanAttack, "player", "target")
        if ok and not v then return false end
    end
    return true
end
D.zielFeindlich = zielFeindlichesUngeheuer

function D.oeffneKontext()
    local d = daten()
    if not d then ns.print(L("Dialog missing")); return false end
    if D.offen() then D.schliesse(); return false end   -- Rechtsklick ist ein Schalter
    if ns.Menue and ns.Menue.schliesse then ns.Menue.schliesse() end
    D.loreLauf = 0
    -- W17 (MERGE 0.19.0): eine KUERZLICH GESPROCHENE Einladung ("Darf ich dich was fragen?
    -- Rechtsklick.") geht vor jedem anderen Rechtsklick-Ziel - sonst landet der Spieler auf dem
    -- Startknoten und die Einladung war eine Luege. ns.Welle17.rechtsklickAngebot() liefert nur
    -- innerhalb seines eigenen Zeitfensters etwas und verbraucht das Angebot dabei; ausserhalb
    -- gibt es nil und dieser Block ist ein No-op. Dasselbe Muster (pcall + knoten()-Pruefung)
    -- wie die Ziel-Weiche direkt darunter.
    if ns.Welle17 and type(ns.Welle17.rechtsklickAngebot) == "function" then
        local ok, id, vars = pcall(ns.Welle17.rechtsklickAngebot)
        if ok and id and knoten(id) then return D.zeigeKnoten(id, vars) end
    end
    if zielFeindlichesUngeheuer() and type(D.aktionen.ziel) == "function" then
        local ok, id, vars = pcall(D.aktionen.ziel)
        if ok and id and knoten(id) then return D.zeigeKnoten(id, vars) end
    end
    return D.zeigeKnoten(d.start or "start")
end

-- ---------------------------------------------------------------------------------------------
-- Freitext: /lyra <text>
-- ---------------------------------------------------------------------------------------------
local function normalisiere(s)
    s = tostring(s or ""):lower()
    s = s:gsub("ä", "ae"):gsub("ö", "oe"):gsub("ü", "ue"):gsub("ß", "ss")
    s = s:gsub("Ä", "ae"):gsub("Ö", "oe"):gsub("Ü", "ue")
    s = s:gsub("[^%w%s]", " "):gsub("%s+", " ")
    return " " .. s:gsub("^%s+", ""):gsub("%s+$", "") .. " "
end

local function trifft(norm, woerter)
    for _, w in ipairs(woerter or {}) do
        if norm:find(" " .. w .. " ", 1, true) then return true end
    end
    return false
end

-- Rotierende Antwort je Intent (Reihenfolge, nicht Zufall -> "3 rotierende Varianten")
-- REVIEW7: liefert zusaetzlich den INDEX. Die Stimme braucht ihn - die Dateien heissen
-- dialog_i_<intent>_<n>-1, und ohne den Index waere nicht zu sagen, welche Zeile gerade dran ist.
local function naechster(id, texte)
    if not texte or #texte == 0 then return nil, nil end
    local i = ((D.intentIndex[id] or 0) % #texte) + 1
    D.intentIndex[id] = i
    return texte[i], i
end
D.naechster = naechster

-- Ausgabe: Blase + Miene; wenn die Gestalt versteckt ist, in den lokalen Chat-Frame.
-- REVIEW7: vierter, optionaler Parameter = Stimm-Dateiname (ohne .ogg). Alte Aufrufer
-- (Core/Start.lua, Slash) reichen ihn nicht durch und bleiben damit still wie bisher - aber
-- schliesse() hat die laufende Dialogzeile vorher ohnehin gestoppt.
function D.sage(str, miene, dauer, stimme)
    if not str or str == "" then return end
    if D.offen() then D.schliesse() end
    if ns.Gestalt and miene then ns.Gestalt.miene(miene, 10) end
    sprich(stimme)
    if ns.Get("versteckt") or not ns.Blase then ns.print(str) return end
    ns.Blase.zeige(str, dauer or 8)
end

local function notizSpeichern(inhalt)
    if not (LyraGestaltDB and ns.charKey) then return false end
    LyraGestaltDB.chronik = LyraGestaltDB.chronik or {}
    local c = LyraGestaltDB.chronik[ns.charKey]
    if type(c) ~= "table" then c = {}; LyraGestaltDB.chronik[ns.charKey] = c end
    c.notizen = c.notizen or {}
    local _, zone = ortText()
    table.insert(c.notizen, { t = time(), zone = zone, text = inhalt })
    while #c.notizen > NOTIZEN_MAX do table.remove(c.notizen, 1) end
    return true
end

local function intentSuchen(roh)
    local d = daten()
    local norm = normalisiere(roh)
    local rohLower = tostring(roh or ""):lower()
    for _, it in ipairs(d.intents or {}) do
        if it.praefix then
            for _, p in ipairs(it.praefix) do
                if rohLower:sub(1, #p) == p then
                    local inhalt = tostring(roh):sub(#p + 1):gsub("^%s+", ""):gsub("%s+$", "")
                    if inhalt ~= "" then return it, inhalt end
                end
            end
        elseif trifft(norm, it.woerter) then
            return it
        end
    end
    return nil
end

-- REVIEW7: liefert zusaetzlich die ID des Intents, dem die TEXTE gehoeren. "lob" hat keine eigenen
-- Zeilen (wie = "danke"), und die Stimmdateien heissen nach dem Besitzer der Zeile: dialog_i_danke_2-1.
local function intentTexte(it)
    local d = daten()
    if it.wie then
        for _, o in ipairs(d.intents or {}) do
            if o.id == it.wie then return o.texte, it.miene or o.miene, o.id end
        end
    end
    return it.texte, it.miene, it.id
end

local function statusVars()
    local _, zone = ortText()
    local hp, max = UnitHealth and UnitHealth("player") or 0, UnitHealthMax and UnitHealthMax("player") or 0
    local pct = (max and max > 0) and math.floor(hp / max * 100 + 0.5) or 0
    return {
        zone = zone,
        level = tostring(UnitLevel and UnitLevel("player") or "?"),
        hp = tostring(pct),
        kampf = fragment("kampf", imKampf() and "ja" or "nein"),
    }
end

function D.frage(roh)
    local d = daten()
    roh = tostring(roh or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if not d then ns.print(L("Dialog missing")); return false end
    if roh == "" then return D.oeffne() end
    local it, inhalt = intentSuchen(roh)
    if not it then
        -- W9b (Freitext, Stufe 1): EIN weiterer Rueckfall vor d.unbekannt. Die 29 Intents und
        -- ihre 241 Schluesselwoerter behalten die Vorfahrt - sie sind die schnellste und
        -- sicherste Zuordnung. Erst wenn KEINER trifft, fragt die Absichts-Bank aus
        -- UI/Freitext.lua nach. Sie antwortet selbst (ueber die Regie, mit vars.direkt) und
        -- meldet nur zurueck, ob sie etwas gesagt hat. Fehlt das Modul, ist alles wie vorher.
        if ns.Freitext and ns.Freitext.an and ns.Freitext.an() then
            local ok, art = pcall(ns.Freitext.antworte, roh)
            if ok and art then return art == "treffer" end
        end
        local u = d.unbekannt or {}
        local z, i = naechster("unbekannt", u.texte)
        D.sage(txt(z), u.miene or "hmm", nil, i and stimmeName("dialog_unbekannt_" .. i, z) or nil)
        return false
    end
    -- Aktions-Intents (befinden/ort/ziel/lore): Text aus dem passenden Dialog-Knoten
    if it.aktion then
        local fn = D.aktionen[it.aktion]
        local id, vars
        if fn then id, vars = fn(inhalt, roh) end   -- REVIEW: nicht "fn and fn()"; Praefix-Rest + Rohtext an die Aktion (Bruecken)
        local k = id and knoten(id)
        -- REVIEW7: derselbe Knoten, derselbe Dateiname wie im Fenster (dialog_k_<id>). Zeilen mit
        -- Platzhaltern (ort, ziel_info, w2_*) haben keine Datei und bleiben still.
        if k then D.sage(txt(k.text, vars), k.miene, nil, stimmeName("dialog_k_" .. tostring(k.id):lower(), k.text)) end
        return true
    end
    local texte, miene, besitzer = intentTexte(it)
    local vars
    if it.id == "notiz" then
        if notizSpeichern(inhalt) then ns.print(L("Note saved")) end
        vars = { text = inhalt }
    elseif it.id == "status" then
        vars = statusVars()
    elseif it.id == "still" then
        if ns.stillSetzen then ns.stillSetzen(true) else ns.stillModus = true end
    elseif it.id == "hilfe" then
        if ns.hilfe then ns.hilfe() end
    end
    local z, i = naechster(it.id, texte)
    -- REVIEW7: Zeilen mit Platzhaltern (status, notiz_1/_3) haben keine Datei -> stimmeName gibt
    -- nil zurueck und die Zeile bleibt still. Kein Sonderfall, kein Aufzaehlen.
    local name = (i and besitzer) and stimmeName("dialog_i_" .. tostring(besitzer):lower() .. "_" .. i, z) or nil
    D.sage(txt(z, vars), miene, nil, name)
    return true
end

-- =============================================================================================
-- W7 (20.09.2026) — CHRONIK-FENSTER
--
-- BEFUND (Bildschirmfoto_20260920_112728.png): "/lyra chronik" schrieb fuenf Zeilen in den Chat.
--   Fuer einen CurseForge-Screenshot ist das nichts: die Zeilen stehen zwischen Kanalwechseln und
--   Schadenszahlen, in Chatschrift, ueber die halbe Bildschirmbreite verteilt. Und inhaltlich
--   fehlte die ZONENLISTE ganz - ns.Chronik.status() zaehlt Zonen nur ("Zones visited: 2"),
--   es steht nirgends, WELCHE.
-- FIX: ein eigenes Fenster in der Optik von Menue und Gespraech (ns.Optik, eine Kachel fuer alle
--   drei). Vier Abschnitte: Zonen (mit Namen und Besuchszahl), Beinahe-Tode (Datum, Ort, Gegner),
--   Bestiarium (die Rivalen, nach Gefaehrlichkeit), Sitzungen.
-- WOHER DIE DATEN: direkt aus LyraGestaltDB.chronik[charKey] ueber chronikDB() - dieselbe
--   lesende Struktur, die dieses Modul seit 0.4 fuer zoneInfo()/bestiariumZahl() benutzt.
--   Sinne/Chronik.lua wird dafuer NICHT angefasst; ns.Chronik.status() bleibt der Rueckfall
--   (und der Weg in den Chat, wenn kein Fenster gebaut werden kann).
-- NAMEN: Sinne/Chronik.lua schreibt keine Spielernamen in die Datenbank (UnitIsPlayer-Sperre).
--   Das Fenster verlaesst sich nicht darauf: sicher() streicht den eigenen Charakternamen, den
--   Realm und den Gildennamen aus JEDER Zeile, bevor sie gesetzt wird. Ein Screenshot, der in
--   einem Forum landet, soll nicht sagen, wer ihn gemacht hat.
-- =============================================================================================
local CH_BREITE, CH_RAND, CH_ZEILE = 330, 14, 4
D.CH_ZONEN_MAX, D.CH_BEINAHE_MAX, D.CH_TIERE_MAX = 6, 4, 4

-- Namen heraus. Gibt IMMER einen String zurueck.
local function sicher(s)
    s = tostring(s or "")
    local weg = {}
    local n = UnitName and UnitName("player")
    if type(n) == "string" and #n > 2 then weg[#weg + 1] = n end
    local r = GetRealmName and GetRealmName()
    if type(r) == "string" and #r > 2 then weg[#weg + 1] = r end
    local g = GetGuildInfo and GetGuildInfo("player")
    if type(g) == "string" and #g > 2 then weg[#weg + 1] = g end
    for _, w in ipairs(weg) do
        -- gsub mit Zeichenklassen-Escape: ein Name darf ein "-" enthalten (Realm-Suffix).
        s = s:gsub((w:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")), "…")
    end
    return s
end
D.chronikSicher = sicher

local chF, chZeilen, chTitel, chFuss, chLinie
local function chBauen()
    if chF then return chF end
    if not CreateFrame then return nil end
    local ok, frame = pcall(CreateFrame, "Frame", "LyraGestaltChronik", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    if not ok or not frame then return nil end
    chF = frame
    chF:SetFrameStrata("MEDIUM")
    chF:SetFrameLevel(32)          -- ueber dem Gespraech (30), unter dem Menue (Strata DIALOG)
    chF:SetSize(CH_BREITE, 200)
    chF:SetClampedToScreen(true)
    chF:EnableMouse(true)
    if chF.SetBackdrop and ns.Optik then pcall(chF.SetBackdrop, chF, ns.Optik.BACKDROP) end
    chF:Hide()
    if UISpecialFrames then tinsert(UISpecialFrames, "LyraGestaltChronik") end
    chTitel = chF:CreateFontString(nil, "OVERLAY")
    chTitel:SetPoint("TOPLEFT", CH_RAND, -CH_RAND)
    chTitel:SetJustifyH("LEFT")
    chTitel:SetFont(STANDARD_TEXT_FONT, 16, "")   -- FIX5-Regel: Schrift VOR dem ersten SetText
    chLinie = ns.Optik and ns.Optik.trennlinie(chF) or chF:CreateTexture(nil, "ARTWORK")
    chFuss = chF:CreateFontString(nil, "OVERLAY")
    chFuss:SetPoint("BOTTOMLEFT", CH_RAND, 6)
    chFuss:SetPoint("BOTTOMRIGHT", -CH_RAND, 6)
    chFuss:SetJustifyH("CENTER")
    chFuss:SetFont(STANDARD_TEXT_FONT, 11, "")
    chZeilen = {}
    D.chronikFrame = chF
    return chF
end

-- Eine Zeile holen/anlegen. art: "kopf" (Abschnitt) oder "zeile" (Eintrag, eingerueckt).
local function chZeile(i)
    local fs = chZeilen[i]
    if fs then return fs end
    fs = chF:CreateFontString(nil, "OVERLAY")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)          -- eine Zeile je Eintrag; zu lange Namen kuerzt der Client
    fs:SetFont(STANDARD_TEXT_FONT, 13, "")
    chZeilen[i] = fs
    return fs
end

-- Der Inhalt. Gibt eine Liste { {art, text}, ... } zurueck - reine Daten, ohne Frame.
-- Damit ist sie im Trockentest pruefbar, ohne ein Fenster zu bauen.
function D.chronikZeilen()
    local c = chronikDB()
    local z = {}
    local function kopf(t) z[#z + 1] = { art = "kopf", text = sicher(t) } end
    local function zeile(t) z[#z + 1] = { art = "zeile", text = sicher(t) } end
    if type(c) ~= "table" then return z end

    -- 1. Zonen: die meistbesuchten zuerst, mit Besuchszahl und Beinahe-Toden.
    local zonen = {}
    if type(c.zonen) == "table" then
        for name, e in pairs(c.zonen) do
            if type(name) == "string" and type(e) == "table" then
                zonen[#zonen + 1] = { name = name, besuche = tonumber(e.besuche) or 0,
                                      beinahe = tonumber(e.beinahe) or 0 }
            end
        end
    end
    table.sort(zonen, function(a, b)
        if a.beinahe ~= b.beinahe then return a.beinahe > b.beinahe end
        if a.besuche ~= b.besuche then return a.besuche > b.besuche end
        return a.name < b.name
    end)
    if #zonen > 0 then
        kopf(L("Chronicle zones") .. " (" .. #zonen .. ")")
        for i = 1, math.min(D.CH_ZONEN_MAX, #zonen) do
            local e = zonen[i]
            local rechts = (e.beinahe > 0)
                and L("Chronicle zone near"):format(e.besuche, e.beinahe)
                or  L("Chronicle visits"):format(e.besuche)
            zeile(e.name .. "  -  " .. rechts)
        end
        if #zonen > D.CH_ZONEN_MAX then zeile(L("Chronicle more"):format(#zonen - D.CH_ZONEN_MAX)) end
    end

    -- 2. Beinahe-Tode: die juengsten zuerst, mit Datum, Ort und Gegner.
    local bn = (type(c.beinahe) == "table") and c.beinahe or {}
    if #bn > 0 then
        kopf(L("Chronicle close calls") .. " (" .. #bn .. ")")
        local n = 0
        for i = #bn, 1, -1 do
            local b = bn[i]
            if type(b) == "table" and n < D.CH_BEINAHE_MAX then
                n = n + 1
                local wann = b.t and date("%d.%m.%Y %H:%M", b.t) or "?"
                zeile(wann .. "  -  " .. tostring(b.zone or "?")
                    .. (b.gegner and ("  -  " .. tostring(b.gegner)) or ""))
            end
        end
        if #bn > D.CH_BEINAHE_MAX then zeile(L("Chronicle more"):format(#bn - D.CH_BEINAHE_MAX)) end
    end

    -- 3. Bestiarium: die Rivalen. Rang wie in Sinne/Chronik.lua - erst beinahe+tode, dann Schaden.
    local tiere = {}
    if type(c.bestiarium) == "table" then
        for _, e in pairs(c.bestiarium) do
            if type(e) == "table" and e.name then tiere[#tiere + 1] = e end
        end
    end
    table.sort(tiere, function(a, b)
        local ra = (a.beinahe or 0) + (a.tode or 0)
        local rb = (b.beinahe or 0) + (b.tode or 0)
        if ra ~= rb then return ra > rb end
        return (a.schaden or 0) > (b.schaden or 0)
    end)
    if #tiere > 0 then
        kopf(L("Chronicle bestiary") .. " (" .. #tiere .. ")")
        for i = 1, math.min(D.CH_TIERE_MAX, #tiere) do
            local e = tiere[i]
            local rang = (e.beinahe or 0) + (e.tode or 0)
            local rechts = (rang > 0)
                and L("Chronicle rival"):format(e.beinahe or 0, e.tode or 0)
                or  L("Chronicle hits"):format(e.treffer or 0, e.maxHit or 0)
            zeile(tostring(e.name) .. "  -  " .. rechts)
        end
        if #tiere > D.CH_TIERE_MAX then zeile(L("Chronicle more"):format(#tiere - D.CH_TIERE_MAX)) end
    end

    -- 4. Sitzungen.
    local sitz = (type(c.sitzungen) == "table") and #c.sitzungen or 0
    if sitz > 0 then
        kopf(L("Chronicle sessions"))
        local seit = "?"
        local s = c.sitzungen[#c.sitzungen]
        if type(s) == "table" and s.start then seit = date("%d.%m.%Y %H:%M", s.start) end
        zeile(L("Chronicle session"):format(sitz, seit))
    end
    return z
end

-- Das Fenster fuellen und zeigen. Rueckgabe true, wenn es wirklich steht.
function D.chronikFenster()
    if not chBauen() then return false end
    local size = (ns.Optik and ns.Optik.schriftgroesse and ns.Optik.schriftgroesse()) or 14
    if size < 12 then size = 12 elseif size > 20 then size = 20 end   -- screenshot-tauglich: lesbar, kompakt
    local c = farben()
    if ns.Optik then
        ns.Optik.panel(chF)
        if chLinie and chLinie.SetColorTexture then
            ns.Optik.flaeche(chLinie, c.linie or { 0.706, 0.549, 1, 0.35 })
        end
    end
    -- Titel in der aktiven Sprache. W7 Punkt 4: ns.L liest bei JEDEM Zugriff die aktuelle
    -- Sprache - dieses Fenster baut seine Beschriftung beim Oeffnen, ein /reload braucht es nie.
    if ns.Optik and ns.Optik.setzeText then
        ns.Optik.setzeText(chTitel, L("Chronicle"), size + 2, c.titel or c.text)
        ns.Optik.setzeText(chFuss, L("Esc hint"), math.max(9, size - 3), c.linie or ns.Optik.LILA)
    else
        chTitel:SetFont(STANDARD_TEXT_FONT, size + 2, ""); chTitel:SetText(L("Chronicle"))
        chFuss:SetFont(STANDARD_TEXT_FONT, math.max(9, size - 3), ""); chFuss:SetText(L("Esc hint"))
    end
    local kopfH = CH_RAND + size + 10
    if chLinie.SetPoint then
        chLinie:ClearAllPoints()
        chLinie:SetPoint("TOPLEFT", CH_RAND, -kopfH)
        chLinie:SetPoint("TOPRIGHT", -CH_RAND, -kopfH)
    end

    local liste = D.chronikZeilen()
    if #liste == 0 then liste = { { art = "zeile", text = L("Chronicle empty") } } end
    local y = kopfH + 10
    local breiteste = 0
    for i, e in ipairs(liste) do
        local fs = chZeile(i)
        local istKopf = (e.art == "kopf")
        local gr = istKopf and size or math.max(11, size - 1)
        local farbe = istKopf and (c.titel or ns.Optik and ns.Optik.LILA or c.text) or c.text
        if ns.Optik and ns.Optik.setzeText then ns.Optik.setzeText(fs, e.text, gr, farbe)
        else fs:SetFont(STANDARD_TEXT_FONT, gr, ""); fs:SetText(e.text) end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", CH_RAND + (istKopf and 0 or 12), -(y + (istKopf and 6 or 0)))
        y = y + gr + CH_ZEILE + (istKopf and 6 or 0)
        local w = tonumber(fs.GetStringWidth and fs:GetStringWidth()) or 0
        if w + (istKopf and 0 or 12) > breiteste then breiteste = w + (istKopf and 0 or 12) end
        fs:Show()
    end
    for i = #liste + 1, #chZeilen do chZeilen[i]:Hide() end
    local breite = math.max(CH_BREITE, breiteste + 2 * CH_RAND + 8)
    local maxB = ((UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920) * 0.5
    if breite > maxB then breite = maxB end
    chF:SetSize(breite, y + CH_RAND + 18)
    chF:ClearAllPoints()
    chF:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    if ns.Optik and ns.Optik.einblenden then ns.Optik.einblenden(chF) else chF:Show() end
    return true
end

function D.chronikZu()
    if chF then chF:Hide() end
end

function D.chronikOffen() return (chF and chF:IsShown()) and true or false end

-- Chronik (/lyra chronik). W7: zuerst das Fenster; nur wenn dabei etwas schiefgeht, der alte
-- Weg in den Chat. Der Chat-Weg bleibt ausdruecklich stehen - er ist das einzige, was ein
-- Spieler noch hat, wenn eine UI-Bibliothek fehlt oder ein anderes Addon UIParent zerlegt.
function D.chronik()
    if D.chronikOffen() then D.chronikZu(); return true end
    local ok, stand = pcall(D.chronikFenster)
    if ok and stand then return true end
    if not ok then ns.debug("Chronik-Fenster: " .. tostring(stand)) end
    local zeilen = chronikRuf("status")
    if type(zeilen) == "table" and #zeilen > 0 then
        for _, z in ipairs(zeilen) do ns.print(sicher(z)) end
        return true
    elseif type(zeilen) == "string" and zeilen ~= "" then
        for line in zeilen:gmatch("[^\n]+") do ns.print(sicher(line)) end
        return true
    end
    local cc = LyraGestaltDB and LyraGestaltDB.chronik and ns.charKey and LyraGestaltDB.chronik[ns.charKey]
    local n = cc and type(cc.notizen) == "table" and #cc.notizen or 0
    ns.print(L("Chronicle missing") .. (n > 0 and (" " .. L("Notes") .. ": " .. n) or ""))
    return false
end
