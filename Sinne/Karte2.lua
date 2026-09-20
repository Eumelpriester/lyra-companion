-- W5: Sinne/Karte2.lua — Feature-Welle 5 "Karte" (companion-v3 D.2, W2-5).
--
-- Vier Bauteile in einer Datei:
--
--   1. PIN-INFRASTRUKTUR ueber HereBeDragons-Pins-2.0. Ein eigener Frame-Pool, drei
--      Kategorien, jede einzeln abschaltbar:
--        (a) beinahe  Beinahe-Tod-Orte aus LyraGestaltDB.chronik[charKey].beinahe
--        (b) notiz    eigene Punkte aus .notizen  ("/lyra punkt <Notiz>")
--        (c) gefahr   Gefahrenkarten-Overlay: die Zellen, vor denen Lyra auch WARNT
--                     (ns.Gefahren, gefuellt von Sinne/Gefahren_Daten.lua) — halbtransparente
--                     Flaechen auf der Weltkarte der AKTUELLEN Zone, Farbe nach Art,
--                     Deckkraft nach Zahl der Tode. Nur Era-Profile (ns.Compat.F.gefahrenkarte).
--   2. GEOFENCE fuer EIGENE PUNKTE (Ereignis PUNKT_NAH) — echte Yard-Entfernung ueber
--      HBD:GetZoneDistance, Drossel 10 min je Ort (phrasen: "stelle-600"), nie im Kampf.
--      Dazu die Yard-Korrektur fuer den BESTEHENDEN Beinahe-Geofence, siehe unten.
--   3. TomTom: die Erweiterung liegt in Sinne/Bruecken.lua (dort die Zeilen mit "-- W5:"),
--      weil dort schon die ganze TomTom-Bruecke steht. Hier nichts davon.
--   4. /lyra karte — Uebersicht und Schalter. Verdrahtet in UI/Slash.lua.
--
-- WARUM ES HIER KEINEN ZWEITEN BEINAHE-GEOFENCE GIBT
-- ---------------------------------------------------
-- Der Auftrag nennt als Bauteil 2 eine Zeile, wenn der Spieler sich einer gemerkten
-- Beinahe-Tod-Stelle naehert — und sagt dazu: "bestehendes Ereignis pruefen". Geprueft:
-- ES GIBT SIE SCHON. Sinne/Chronik.lua traegt jede Beinahe-Stelle als
-- { x, y, r, art="beinahe", key="b<t>" } in ns.Gefahren ein (Chronik.lua:413-424, 556-559),
-- und der 3-s-Puls in Sinne/Umwelt.lua (:200-231) meldet daraufhin GEOFENCE_BEINAHE.
-- Ein zweites Modul auf derselben Quelle ist genau der Fehler, den der Welle-3-Audit zweimal
-- gefunden hat und den Welle 4 bei CHAT_MSG_SKILL bewusst vermieden hat.
--
-- Was an der bestehenden Loesung wirklich fehlt, ist nicht das Ereignis, sondern der RADIUS.
-- Chronik.lua setzt fuer jede Beinahe-Stelle r = GEFAHR_R = 0.015 (Chronik.lua:50, benutzt
-- in :423). Das ist ein ANTEIL DER KARTENBREITE, kein Abstand. Und Zonen sind verschieden
-- gross: derselbe Anteil ist in einer grossen Aussenzone ein Vielfaches dessen, was er in
-- einer Stadtkarte ist. Die Warnung kommt also je nach Zone deutlich zu frueh oder zu spaet,
-- und zwar ohne dass irgendjemand das je gewollt haette — es ist eine Zahl aus Welle 1, die
-- nie an einer Entfernung gemessen wurde.
--
-- (Konkrete Yard-Zahlen stehen hier bewusst NICHT: HBD haelt keine Tabelle mit Zonengroessen,
-- es rechnet sie beim Laden aus C_Map.GetMapWorldSize aus (HereBeDragons-2.0.lua:185-192).
-- Sie sind also erst im laufenden Client nachzulesen, nicht im Quelltext. Was hier zaehlt,
-- ist auch nicht die einzelne Zahl, sondern dass sie je Zone eine ANDERE ist.)
--
-- GENAU DAS kann HBD beheben: HBD:GetZoneSize(uiMapID) liefert Breite und Hoehe in Yard, und
-- damit wird aus einer festen Yard-Zahl je Karte der richtige Anteil. Karte2 schreibt deshalb
-- nur das r der EIGENEN Beinahe-Stellen um (Schluessel-Praefix "b", das ist Chroniks eigener)
-- und laesst Ereignis, Puls und Drossel dort, wo sie hingehoeren.
--
-- Die Gefahrenkarten-Zellen (Praefix "d") bleiben unangetastet: dort IST 0.02 der richtige
-- Wert, weil die Zelle selbst ein 2-%-Raster ist (Gefahren_Daten.lua:17). Ein Raster ist
-- kein Abstand — das ist derselbe Unterschied, nur andersherum.
--
-- Neu ist hier deshalb genau ein Geofence: der auf die SELBST gesetzten Punkte. Die kennt
-- heute niemand, sie liegen nur in der Chronik und auf der Karte.
--
-- SCHALTER (Account, UI/Settings.lua Abschnitt "Welle 5"):
--   pinBeinahe (an), pinNotiz (an), pinGefahr (an), punktNah (an).
--   Der alte Sammelschalter "karte" aus Welle 2 bleibt der HAUPTSCHALTER: ist er aus, liegt
--   kein einziger Pin auf der Karte. Die drei neuen Kaestchen sind darunter.
--
-- SPEICHER: keiner. Karte2 liest LyraGestaltDB.chronik[charKey].beinahe/.notizen (angelegt von
--   Sinne/Chronik.lua bzw. Sinne/Bruecken.lua) und loescht auf Zuruf einen Notiz-Eintrag.
--   Keine eigene Tabelle, kein eigenes Format.
--
-- LEISTUNG (der Grund, warum diese Datei so viele Deckel hat):
--   * Deckel MAX_PINS (120) ueber ALLE Kategorien. Die Gefahrenkarte allein bringt in Elwynn
--     bis zu 30 Mob-Zellen plus Umwelt-Zellen mit; ohne Deckel liegen bei einem Rundgang
--     mehrere hundert Frames auf der Weltkarte.
--   * Das Overlay zeigt NUR die aktuelle Zone. Beinahe-Orte und Notizen liegen auf allen
--     Karten — das sind zusammen hoechstens 50 + 50 Eintraege, die traegt HBD mit links.
--   * Neu gezeichnet wird nur bei Zonenwechsel, beim Oeffnen der Weltkarte und nach einer
--     Aenderung an den Punkten. Kein Ticker zeichnet.
--   * Der EINZIGE Ticker ist die Abstandspruefung, Takt 2 s (Kontrakt: nichts unter 0,5 s,
--     Abstand hoechstens 1x/s), und er kehrt im Kampf in der ersten Zeile um.
--   * Frames werden nie freigegeben (WoW gibt sie nicht frei) — Pool wie in Sinne/Karte.lua,
--     REVIEW6B. Ueberzaehlige Pins werden versteckt, nicht neu gebaut.
--
-- FREMD-API (eingebettet unter Libs/, siehe LICENSES/HereBeDragons.txt):
--   LibStub("HereBeDragons-2.0")        Libs/HereBeDragons/HereBeDragons-2.0.lua:3 (Rev 33)
--     :GetPlayerZonePosition()          :677  -> x, y, uiMapID, mapType   (x,y 0-1)
--     :GetZoneDistance(oZ,oX,oY,dZ,dX,dY) :601 -> Abstand in YARD (nil ueber Kontinente hinweg)
--     :GetZoneSize(uiMapID)             :405  -> Breite, Hoehe in Yard
--     :GetLocalizedMap(uiMapID)         :398  -> Zonenname
--   LibStub("HereBeDragons-Pins-2.0")   Libs/HereBeDragons/HereBeDragons-Pins-2.0.lua:3 (Rev 17)
--     :AddWorldMapIconMap(ref,icon,uiMapID,x,y,showFlag,frameLevel)   :734
--     :AddMinimapIconMap(ref,icon,uiMapID,x,y,showInParentZone,floatOnEdge) :601
--     :RemoveAllWorldMapIcons(ref)      :788      :RemoveAllMinimapIcons(ref)  :651
--     HBD_PINS_WORLDMAP_SHOW_WORLD = 3  :685
--   Beide Bibliotheken sind EINGEBETTET, aber trotzdem hinter LibStub(name, true) und pcall:
--   laedt ein anderes Addon eine hoehere Revision, gewinnt dessen Kopie (so ist LibStub
--   gebaut), und auf einem Client, den HBD nicht kennt, faellt Karte2 still aus.
--
-- KONTRAKT: kein SendChatMessage, keine geschuetzte Funktion, keine Daten anderer Spieler,
--   kein Netz, keine Animationsgruppe. Pins sind Anzeige — Lyra ZEIGT, sie bewegt nichts.
--
-- PORT: Das Overlay haengt an ns.Compat.F.gefahrenkarte (aus auf retail/forever, REVIEW9:
--   hinter den Vanilla-mapIDs liegt dort eine andere Welt). Pins fuer eigene Beinahe-Orte und
--   eigene Notizen laufen ueberall: das sind Daten dieses Spielers auf dieser Karte.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local K2 = {}
ns.Sinne.Karte2 = K2
ns.Karte2 = K2

-- ---------------------------------------------------------------------------------------------
-- Voreinstellungen. Core/Init.lua ist in dieser Welle unantastbar (Version), darum haengen die
-- vier Schluessel hier an ns.DEFAULTS_ACCOUNT — beim LADEN der Datei, also lange vor
-- ADDON_LOADED, und dort ruft ns.initDB() defaults(). Muster aus Sinne/Welle4.lua:68.
-- ---------------------------------------------------------------------------------------------
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.pinBeinahe == nil then D.pinBeinahe = true end
    if D.pinNotiz   == nil then D.pinNotiz   = true end
    if D.pinGefahr  == nil then D.pinGefahr  = true end
    if D.punktNah   == nil then D.punktNah   = true end
end

K2.MAX_PINS     = 120   -- Deckel ueber ALLE Kategorien zusammen
K2.MAX_OVERLAY  = 80    -- und davon hoechstens so viele Gefahren-Zellen
K2.NAH_YD       = 60    -- ab hier gilt ein eigener Punkt als "erreicht"
K2.BEINAHE_YD   = 60    -- Yard-Radius, mit dem GEOFENCE_BEINAHE feuern SOLL
K2.R_MIN        = 0.004 -- Kartenanteil: Untergrenze fuer den umgerechneten Radius
K2.R_MAX        = 0.05  -- und Obergrenze (eine kaputte Zonengroesse soll nicht die halbe Karte warnen)
K2.TAKT         = 2     -- s zwischen zwei Abstandspruefungen (Kontrakt: hoechstens 1x/s)
K2.PIN_GROESSE  = 14
K2.ZELL_GROESSE = 16

local TEX_PIN   = ns.PFAD .. "bilder\\icon.png"
local TEX_FLAECHE = "Interface\\Buttons\\WHITE8X8"

-- Farben je Kategorie/Art. r, g, b, a
local FARBE = {
    beinahe = { 1.00, 0.45, 0.45, 1.00 },
    notiz   = { 0.80, 0.60, 1.00, 1.00 },
    sturz   = { 1.00, 0.65, 0.15, 1.00 },
    wasser  = { 0.35, 0.60, 1.00, 1.00 },
    mob     = { 1.00, 0.25, 0.25, 1.00 },
}
-- Deckkraft nach Gefahrenstufe (1 = wenige Tode, 3 = viele).
local ALPHA = { 0.22, 0.34, 0.48 }

local function de() return (ns.sprache and ns.sprache() == "de") and true or false end
local function jetzt() return (GetTime and GetTime()) or 0 end
local function Get(k) return ns.Get and ns.Get(k) end
local function an(k) return Get(k) ~= false end

-- ---------------------------------------------------------------------------------------------
-- HereBeDragons
-- ---------------------------------------------------------------------------------------------
local HBD, HBDP = nil, nil
local hbdGeprueft = false

local function hbd()
    if hbdGeprueft then return HBD, HBDP end
    hbdGeprueft = true
    if type(LibStub) ~= "function" and type(LibStub) ~= "table" then return nil, nil end
    local ok1, lib1 = pcall(LibStub, "HereBeDragons-2.0", true)
    local ok2, lib2 = pcall(LibStub, "HereBeDragons-Pins-2.0", true)
    if ok1 and type(lib1) == "table" and lib1.GetPlayerZonePosition then HBD = lib1 end
    if ok2 and type(lib2) == "table" and lib2.AddWorldMapIconMap then HBDP = lib2 end
    return HBD, HBDP
end
K2.hbd = hbd

-- Selbsttest beim Login: eine bekannte Zone messen. Findet HBD sie nicht, ist die Kartendaten-
-- Tabelle fuer diesen Client leer und jede Yard-Rechnung waere geraten.
-- 1519 = Sturmwind, 37 = Wald von Elwynn (uiMapIDs, auf allen fuenf Clients dieselben).
K2.selbsttest = nil
local function selbsttest()
    local h = hbd()
    if not h or not h.GetZoneSize then K2.selbsttest = "keine-lib"; return false end
    for _, id in ipairs({ 37, 1519, 1411 }) do
        local ok, w = pcall(h.GetZoneSize, h, id)
        if ok and type(w) == "number" and w > 0 then K2.selbsttest = "ok"; return true end
    end
    K2.selbsttest = "keine-kartendaten"
    return false
end

-- Yard -> Kartenanteil fuer eine bestimmte Karte. Bewusst die GROESSERE Kante: der Geofence in
-- Sinne/Umwelt.lua rechnet sqrt(dx^2+dy^2) im Anteilsraum, ein Kreis dort ist in Yard eine
-- Ellipse. Mit max(w,h) ist der Radius nie WEITER als gewollt — lieber etwas spaeter warnen
-- als in der schmalen Richtung doppelt so frueh.
local function ydZuAnteil(mapID, yd)
    local h = hbd()
    if not (h and h.GetZoneSize and mapID) then return nil end
    local ok, w, hgt = pcall(h.GetZoneSize, h, mapID)
    if not ok then return nil end
    w, hgt = tonumber(w) or 0, tonumber(hgt) or 0
    local gross = math.max(w, hgt)
    if gross <= 0 then return nil end
    local r = yd / gross
    if r < K2.R_MIN then r = K2.R_MIN end
    if r > K2.R_MAX then r = K2.R_MAX end
    return r
end
K2.ydZuAnteil = ydZuAnteil

local function spielerOrt()
    local h = hbd()
    if not (h and h.GetPlayerZonePosition) then return nil end
    local ok, x, y, mapID = pcall(h.GetPlayerZonePosition, h)
    if not ok or type(x) ~= "number" or type(y) ~= "number" or type(mapID) ~= "number" then return nil end
    return mapID, x, y
end
K2.spielerOrt = spielerOrt

local function abstandYd(aMap, ax, ay, bMap, bx, by)
    local h = hbd()
    if not (h and h.GetZoneDistance) then return nil end
    local ok, d = pcall(h.GetZoneDistance, h, aMap, ax, ay, bMap, bx, by)
    if not ok then return nil end
    return tonumber(d)
end
K2.abstandYd = abstandYd

-- ---------------------------------------------------------------------------------------------
-- Chronik-Zugriff (lesend; die Tabellen gehoeren Sinne/Chronik.lua und Sinne/Bruecken.lua)
-- ---------------------------------------------------------------------------------------------
local function chronik()
    local db = LyraGestaltDB
    if type(db) ~= "table" or type(db.chronik) ~= "table" or not ns.charKey then return nil end
    local c = db.chronik[ns.charKey]
    if type(c) ~= "table" then return nil end
    return c
end
local function beinaheListe() local c = chronik(); return (c and type(c.beinahe) == "table") and c.beinahe or {} end
local function notizListe()   local c = chronik(); return (c and type(c.notizen) == "table") and c.notizen or {} end

-- ---------------------------------------------------------------------------------------------
-- Pin-Pool
-- ---------------------------------------------------------------------------------------------
-- REVIEW6B (Sinne/Karte.lua): WoW legt Frames an und gibt sie NIE wieder frei. Deshalb ein Pool
-- mit laufendem Index: je Platz EIN Frame, bei jedem Neuzeichnen werden Text, Farbe und Groesse
-- umgesetzt und der Rest versteckt. Der Pool waechst hoechstens bis MAX_PINS.
local POOL = {}
local benutzt = 0

local function neuerPin()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(K2.PIN_GROESSE, K2.PIN_GROESSE)
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints(f)
    f.tex = t
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if not (GameTooltip and self.lyraText) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Lyra", 0.75, 0.55, 1)
        GameTooltip:AddLine(self.lyraText, 1, 1, 1, true)
        if self.lyraText2 then GameTooltip:AddLine(self.lyraText2, 0.7, 0.7, 0.7, true) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return f
end

-- Naechsten freien Pin holen und einrichten. Gibt nil zurueck, wenn der Deckel erreicht ist —
-- das ist kein Fehler, sondern die Bremse.
local function holePin(art, groesse, text, text2)
    if benutzt >= K2.MAX_PINS then return nil end
    benutzt = benutzt + 1
    local f = POOL[benutzt]
    if not f then f = neuerPin(); POOL[benutzt] = f end
    f.lyraText, f.lyraText2 = text, text2
    f.lyraArt = art
    f:SetSize(groesse, groesse)
    local farbe = FARBE[art] or FARBE.notiz
    if art == "sturz" or art == "wasser" or art == "mob" then
        f.tex:SetTexture(TEX_FLAECHE)
    else
        f.tex:SetTexture(TEX_PIN)
    end
    f.tex:SetVertexColor(farbe[1], farbe[2], farbe[3], farbe[4])
    f:Show()
    return f
end

local function poolAufraeumen()
    for i = benutzt + 1, #POOL do
        local f = POOL[i]
        if f then f:Hide(); f.lyraText, f.lyraText2 = nil, nil end
    end
end

-- ---------------------------------------------------------------------------------------------
-- Zeichnen
-- ---------------------------------------------------------------------------------------------
K2.stand = { beinahe = 0, notiz = 0, gefahr = 0, gesamt = 0, zone = nil, zellenZone = 0, gedeckelt = false }

local function tooltipBeinahe(b)
    local hp = tostring(b.hp or "?")
    local wer = b.gegner and (" - " .. tostring(b.gegner)) or ""
    return (de() and ("Hier war es knapp: %s%%%s") or ("Close call here: %s%%%s")):format(hp, wer)
end

local function tooltipZelle(art, n)
    local d = de()
    local kopf
    if art == "sturz" then kopf = d and "Hier wird gestuerzt." or "People fall here."
    elseif art == "wasser" then kopf = d and "Hier wird ertrunken." or "People drown here."
    else kopf = d and "Hier wird gestorben." or "People die here." end
    if n and n > 0 then
        kopf = kopf .. " " .. (d and ("%d aufgezeichnete Tode."):format(n) or ("%d recorded deaths."):format(n))
    end
    return kopf
end

-- Stufe einer Zelle aus der Zahl der Tode. Drei Stufen, damit die Karte lesbar bleibt:
-- ein Farbverlauf ueber 700 Werte ist eine Wolke, keine Auskunft.
local function stufeVon(n)
    n = tonumber(n) or 0
    if n >= 200 then return 3 end
    if n >= 50 then return 2 end
    return 1
end
K2.stufeVon = stufeVon

-- Tode je Zelle aus dem Datenpaket nachschlagen. Gebaut wird der Index nur, wenn das Overlay
-- die Zone wirklich zeichnet — einmal je Zonenwechsel, nicht je Pin.
local function todesIndex(mapID)
    local D = LyraGestalt_Daten
    if type(D) ~= "table" or type(D.zellen) ~= "table" then return nil end
    local zellen = D.zellen[mapID]
    if type(zellen) ~= "table" then return nil end
    local idx = {}
    for _, z in ipairs(zellen) do
        if type(z) == "table" and z.x and z.y then
            idx["d" .. mapID .. "_" .. z.x .. "_" .. z.y] = tonumber(z.n) or 0
        end
    end
    return idx
end

-- Das Overlay zeigt GENAU die Zellen, vor denen Lyra auch warnt: ns.Gefahren[mapID], gefuellt
-- von Sinne/Gefahren_Daten.lua (Level-Fenster, Mob-Deckel je Karte, Art-Zuordnung sind dort
-- schon gefallen). Waeren es die Rohzellen aus LyraGestalt_Daten, zeigte die Karte in Elwynn
-- 744 Kaestchen, von denen Lyra 30 kennt — eine Karte, die etwas anderes behauptet als die
-- Begleiterin, ist schlimmer als keine.
local function zeichneOverlay(mapID, hbdp)
    local C = ns.Compat
    if C and C.F and C.F.gefahrenkarte == false then return 0, 0 end
    if not an("pinGefahr") then return 0, 0 end
    if Get("gefahrenkarte") == false then return 0, 0 end
    local liste = ns.Gefahren and ns.Gefahren[mapID]
    if type(liste) ~= "table" then return 0, 0 end

    -- nur eigene Zellen des Datenpakets (Praefix "d"); Beinahe-Stellen ("b") haben ihren
    -- eigenen Pin und duerfen nicht doppelt liegen
    local zellen = {}
    for _, s in ipairs(liste) do
        if type(s) == "table" and s.key and tostring(s.key):sub(1, 1) == "d" and s.x and s.y then
            zellen[#zellen + 1] = s
        end
    end
    local gesamt = #zellen
    if gesamt == 0 then return 0, 0 end

    local idx = todesIndex(mapID) or {}
    -- Die toedlichsten zuerst: wenn der Deckel greift, sollen die wichtigsten Zellen liegen
    -- bleiben — dieselbe Regel wie beim Mob-Deckel in Gefahren_Daten.lua:85.
    table.sort(zellen, function(a, b) return (idx[a.key] or 0) > (idx[b.key] or 0) end)

    local gezeichnet = 0
    for i = 1, math.min(#zellen, K2.MAX_OVERLAY) do
        local s = zellen[i]
        local n = idx[s.key] or 0
        local art = s.art or "mob"
        local pin = holePin(art, K2.ZELL_GROESSE, tooltipZelle(art, n))
        if not pin then break end
        pin.tex:SetAlpha(ALPHA[stufeVon(n)] or ALPHA[1])
        local ok = pcall(hbdp.AddWorldMapIconMap, hbdp, K2, pin, mapID, s.x, s.y, 0)
        if ok then gezeichnet = gezeichnet + 1 else benutzt = benutzt - 1; pin:Hide() end
    end
    return gezeichnet, gesamt
end

-- Alles neu zeichnen. Rueckgabe: Gesamtzahl der gesetzten Pins.
function K2.aktualisieren()
    local _, hbdp = hbd()
    K2.stand.beinahe, K2.stand.notiz, K2.stand.gefahr = 0, 0, 0
    K2.stand.gedeckelt = false
    if not hbdp then K2.stand.gesamt = 0; return 0 end

    -- Erst abraeumen, DANN Schalter pruefen (REVIEW6B: sonst bleiben alte Pins liegen, wenn
    -- man die Kategorie ausschaltet). Auch unter dem Welle-2-Namen abraeumen: bis 0.10.0 hat
    -- Sinne/Karte.lua unter ns.Karte eigene Pins gesetzt.
    pcall(hbdp.RemoveAllWorldMapIcons, hbdp, K2)
    pcall(hbdp.RemoveAllMinimapIcons, hbdp, K2)
    if ns.Karte then
        pcall(hbdp.RemoveAllWorldMapIcons, hbdp, ns.Karte)
        pcall(hbdp.RemoveAllMinimapIcons, hbdp, ns.Karte)
    end
    benutzt = 0

    if Get("karte") == false then poolAufraeumen(); K2.stand.gesamt = 0; return 0 end

    -- (a) Beinahe-Tod-Orte. Auf ALLEN Karten, nicht nur der aktuellen: es sind wenige, und
    -- der Sinn der Pins ist gerade, sie zu finden, bevor man hinlaeuft.
    if an("pinBeinahe") then
        for _, b in ipairs(beinaheListe()) do
            if type(b) == "table" and b.mapID and b.x and b.y then
                local txt = tooltipBeinahe(b)
                local pin = holePin("beinahe", K2.PIN_GROESSE, txt)
                if not pin then K2.stand.gedeckelt = true; break end
                pin.tex:SetAlpha(1)
                if pcall(hbdp.AddWorldMapIconMap, hbdp, K2, pin, b.mapID, b.x, b.y, 3) then
                    K2.stand.beinahe = K2.stand.beinahe + 1
                    local mini = holePin("beinahe", K2.PIN_GROESSE, txt)
                    if mini then
                        mini.tex:SetAlpha(1)
                        if not pcall(hbdp.AddMinimapIconMap, hbdp, K2, mini, b.mapID, b.x, b.y, false, false) then
                            benutzt = benutzt - 1; mini:Hide()
                        end
                    end
                else
                    benutzt = benutzt - 1; pin:Hide()
                end
            end
        end
    end

    -- (b) eigene Notizen
    if an("pinNotiz") then
        for _, z in ipairs(notizListe()) do
            if type(z) == "table" and z.mapID and z.x and z.y then
                local txt = tostring(z.text or z.zone or "?")
                local wann = z.t and date and date("%d.%m. %H:%M", z.t) or nil
                local pin = holePin("notiz", K2.PIN_GROESSE, txt, wann)
                if not pin then K2.stand.gedeckelt = true; break end
                pin.tex:SetAlpha(1)
                if pcall(hbdp.AddWorldMapIconMap, hbdp, K2, pin, z.mapID, z.x, z.y, 3) then
                    K2.stand.notiz = K2.stand.notiz + 1
                    local mini = holePin("notiz", K2.PIN_GROESSE, txt, wann)
                    if mini then
                        mini.tex:SetAlpha(1)
                        if not pcall(hbdp.AddMinimapIconMap, hbdp, K2, mini, z.mapID, z.x, z.y, false, true) then
                            benutzt = benutzt - 1; mini:Hide()
                        end
                    end
                else
                    benutzt = benutzt - 1; pin:Hide()
                end
            end
        end
    end

    -- (c) Gefahrenkarten-Overlay, nur die aktuelle Zone
    local mapID = select(1, spielerOrt())
    if not mapID and C_Map and C_Map.GetBestMapForUnit then
        local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
        if ok then mapID = m end
    end
    K2.stand.zone = mapID
    if mapID then
        local gezeichnet, gesamt = zeichneOverlay(mapID, hbdp)
        K2.stand.gefahr = gezeichnet
        K2.stand.zellenZone = gesamt
        if gesamt > gezeichnet then K2.stand.gedeckelt = true end
    else
        K2.stand.zellenZone = 0
    end

    if benutzt >= K2.MAX_PINS then K2.stand.gedeckelt = true end
    poolAufraeumen()
    K2.stand.gesamt = benutzt
    return benutzt
end

-- ---------------------------------------------------------------------------------------------
-- Yard-Korrektur am BESTEHENDEN Beinahe-Geofence (Begruendung im Dateikopf)
-- ---------------------------------------------------------------------------------------------
K2.radienGesetzt = 0
function K2.radienNachziehen()
    local h = hbd()
    if not h then return 0 end
    local tab = ns.Gefahren
    if type(tab) ~= "table" then return 0 end
    local n = 0
    for mapID, liste in pairs(tab) do
        if type(mapID) == "number" and type(liste) == "table" then
            local r = ydZuAnteil(mapID, K2.BEINAHE_YD)
            if r then
                for _, s in ipairs(liste) do
                    -- NUR Chroniks eigene Beinahe-Stellen. Die Zellen des Datenpakets ("d")
                    -- sind ein 2-%-Raster: dort ist 0.02 die Zellbreite und kein Abstand.
                    if type(s) == "table" and s.key and tostring(s.key):sub(1, 1) == "b" then
                        s.r = r
                        n = n + 1
                    end
                end
            end
        end
    end
    K2.radienGesetzt = n
    return n
end

-- ---------------------------------------------------------------------------------------------
-- Geofence auf die EIGENEN Punkte (Ereignis PUNKT_NAH)
-- ---------------------------------------------------------------------------------------------
local scharf = {}       -- [key] = false (verbraucht) | true/nil (scharf)
local ticker = nil
K2.letztePruefung = 0
K2.pruefungen = 0

local function notizKey(z)
    return ("n%s_%s_%s"):format(tostring(z.mapID), tostring(z.x), tostring(z.y))
end

-- Eine Runde Abstandspruefung. Oeffentlich, damit der Pruefstand sie ohne Ticker fahren kann.
function K2.nahPuls()
    if not an("punktNah") then return end
    if Get("karte") == false then return end
    -- Nie im Kampf: eine Zeile ueber einen Wegpunkt waehrend eines Kampfes ist Laerm.
    if UnitAffectingCombat then
        local ok, k = pcall(UnitAffectingCombat, "player")
        if ok and k then return end
    end
    if UnitIsDeadOrGhost then
        local ok, t = pcall(UnitIsDeadOrGhost, "player")
        if ok and t then return end
    end
    local mapID, px, py = spielerOrt()
    if not mapID then return end
    K2.pruefungen = K2.pruefungen + 1
    K2.letztePruefung = jetzt()
    for _, z in ipairs(notizListe()) do
        if type(z) == "table" and z.mapID and z.x and z.y then
            local d = abstandYd(mapID, px, py, z.mapID, z.x, z.y)
            if d then
                local key = notizKey(z)
                if d <= K2.NAH_YD then
                    if scharf[key] ~= false then
                        scharf[key] = false
                        if ns.melde then
                            -- Die 10-Minuten-Drossel je Ort steht im Katalog
                            -- (PUNKT_NAH, drossel "stelle-600") und rechnet ueber vars.key.
                            pcall(ns.melde, "PUNKT_NAH", { key = key, titel = tostring(z.text or z.zone or "?") })
                        end
                    end
                elseif d >= 2 * K2.NAH_YD then
                    scharf[key] = true          -- erst nach dem Weggehen wieder scharf
                end
            end
        end
    end
end

local function tickerStart()
    if ticker then return end
    ticker = ns.Compat.NewTicker(K2.TAKT, function()
        local ok, err = pcall(K2.nahPuls)
        if not ok then ns.debug("Karte2 nahPuls: " .. tostring(err)) end
    end)
end

-- ---------------------------------------------------------------------------------------------
-- Punkte loeschen  ("/lyra punkt weg" / "/lyra punkt weg <n>")
-- ---------------------------------------------------------------------------------------------
-- Geschrieben wird in DIESELBE Liste, die Sinne/Bruecken.lua fuellt (chronik[charKey].notizen).
-- Kein eigenes Format, keine zweite Wahrheit.
function K2.punktWeg(n)
    local liste = notizListe()
    if #liste == 0 then
        ns.print(de() and "Keine Punkte in der Chronik." or "No waypoints in the chronicle.")
        return false
    end
    n = tonumber(n)
    if n == nil then n = #liste end                 -- ohne Zahl: der zuletzt gesetzte
    if n < 1 or n > #liste then
        ns.print(de() and "So einen Punkt habe ich nicht." or "I don't have that waypoint.")
        return false
    end
    local weg = table.remove(liste, n)
    scharf = {}
    pcall(K2.aktualisieren)
    local titel = (type(weg) == "table" and tostring(weg.text or weg.zone or "?")) or "?"
    ns.print((de() and "Punkt %d geloescht: \"%s\". Es bleiben %d."
                   or "Waypoint %d removed: \"%s\". %d left."):format(n, titel, #liste))
    return true
end

-- ---------------------------------------------------------------------------------------------
-- /lyra karte
-- ---------------------------------------------------------------------------------------------
local AN_AUS = { an = true, on = true, ein = true, ja = true, yes = true,
                 aus = false, off = false, nein = false, no = false }

local function anAus(b) return b and (de() and "an" or "on") or (de() and "aus" or "off") end

-- Uebersicht als Zeilenliste (UI/Slash.lua gibt sie ueber ns.print aus).
function K2.status()
    local d = de()
    local out = {}
    local h, hp = hbd()
    if not (h and hp) then
        out[#out + 1] = d and "Karte: HereBeDragons ist nicht ansprechbar - keine Pins."
                          or "Map: HereBeDragons is not available - no pins."
        return out
    end
    if K2.selbsttest and K2.selbsttest ~= "ok" then
        out[#out + 1] = (d and "Karte: HereBeDragons antwortet, kennt aber keine Kartendaten (%s)."
                           or "Map: HereBeDragons answers but has no map data (%s)."):format(tostring(K2.selbsttest))
    end
    if Get("karte") == false then
        out[#out + 1] = d and "Karte: Pins sind in den Einstellungen aus (Hauptschalter)."
                          or "Map: pins are switched off in the settings (master switch)."
        return out
    end
    local s = K2.stand
    local zone = s.zone and h.GetLocalizedMap and select(2, pcall(h.GetLocalizedMap, h, s.zone)) or nil
    out[#out + 1] = (d and "Karte: %d Pins (Beinahe %d, Notizen %d, Gefahr %d von %d Zellen%s)."
                       or  "Map: %d pins (close calls %d, notes %d, danger %d of %d cells%s)."):format(
        s.gesamt or 0, s.beinahe or 0, s.notiz or 0, s.gefahr or 0, s.zellenZone or 0,
        s.gedeckelt and (d and ", Deckel erreicht" or ", cap reached") or "")
    out[#out + 1] = (d and "  Zone: %s - Overlay: %s, Beinahe: %s, Notizen: %s, Nah-Hinweis: %s."
                       or  "  Zone: %s - overlay: %s, close calls: %s, notes: %s, proximity: %s."):format(
        tostring(zone or s.zone or "?"), anAus(an("pinGefahr")), anAus(an("pinBeinahe")),
        anAus(an("pinNotiz")), anAus(an("punktNah")))
    local C = ns.Compat
    if C and C.F and C.F.gefahrenkarte == false then
        out[#out + 1] = (d and "  Overlay: auf diesem Client (%s) aus - die Zellen sind Classic-Era-Tode."
                           or "  Overlay: off on this client (%s) - the cells are Classic Era deaths."):format(tostring(C.profil))
    end
    return out
end

-- Drei Zeilen fuer /lyra hilfe. Bewusst im Modul, nicht in den Locales: Befehlslisten aendern
-- sich mit jeder Welle, Locales sind fuer Texte da (dasselbe Muster wie Sinne/Bruecken.lua:57).
function K2.hilfe()
    if de() then
        return {
            "/lyra karte - Pins und Gefahrenkarte: Uebersicht",
            "/lyra karte overlay|beinahe|notizen|nah [an|aus] - Kategorie schalten",
            "/lyra punkt weg [n] - Punkt loeschen (ohne Zahl den zuletzt gesetzten)",
        }
    end
    return {
        "/lyra karte - pins and danger map: overview",
        "/lyra karte overlay|beinahe|notizen|nah [on|off] - toggle a category",
        "/lyra punkt weg [n] - remove a waypoint (the last one without a number)",
    }
end

-- /lyra karte [overlay|beinahe|notizen|nah] [an|aus]
function K2.befehl(rest)
    rest = tostring(rest or ""):lower()
    local wort, wert = rest:match("^(%a+)%s*(%a*)$")
    local SCHLUESSEL = {
        overlay = "pinGefahr", gefahr = "pinGefahr", danger = "pinGefahr",
        beinahe = "pinBeinahe", close = "pinBeinahe",
        notizen = "pinNotiz", notiz = "pinNotiz", notes = "pinNotiz", punkte = "pinNotiz",
        nah = "punktNah", proximity = "punktNah",
    }
    local key = wort and SCHLUESSEL[wort] or nil
    if key then
        local v = AN_AUS[wert or ""]
        if v == nil then v = not an(key) end                 -- ohne "an/aus": umschalten
        if ns.Settings and ns.Settings.setze then ns.Settings.setze(key, v) else ns.Set(key, v) end
        pcall(K2.aktualisieren)
    end
    for _, z in ipairs(K2.status()) do ns.print(z) end
    return true
end

-- ---------------------------------------------------------------------------------------------
-- Anlaesse zum Neuzeichnen
-- ---------------------------------------------------------------------------------------------
local geplant = false
local function neuBald(verzug)
    if geplant then return end
    geplant = true
    ns.Compat.After(verzug or 0.5, function()
        geplant = false
        local ok, err = pcall(K2.aktualisieren)
        if not ok then ns.debug("Karte2: " .. tostring(err)) end
    end)
end
K2.neuBald = neuBald

ns.on("PLAYER_LOGIN", function()
    hbd()
    selbsttest()
    -- Spaet, aus demselben Grund wie in Sinne/Karte.lua: die Chronik laedt beim selben Event,
    -- und die Gefahrenkarte kommt aus einem anderen Addon (ADDON_LOADED Lyra_Gestalt_Daten).
    ns.Compat.After(12, function()
        local ok, err = pcall(function()
            K2.radienNachziehen()
            K2.aktualisieren()
        end)
        if not ok then ns.debug("Karte2 Login: " .. tostring(err)) end
        tickerStart()
    end)

    -- Welle 2 hat unter ns.Karte dieselben zwei Kategorien gezeichnet (ohne Overlay, ohne
    -- Deckel, ohne Yard-Rechnung). Ab jetzt zeichnet Karte2 — SONST liegt jeder Beinahe-Pin
    -- doppelt auf der Karte. Der alte Einstieg bleibt erreichbar (/lyra karte, der
    -- Dialog-Intent w2_karte, der nachAusgabe-Hook in Karte.lua) und zeigt jetzt hierher.
    if ns.Karte and ns.Karte.aktualisieren ~= K2.aktualisieren then
        ns.Karte.aktualisierenW2 = ns.Karte.aktualisieren
        ns.Karte.aktualisieren = K2.aktualisieren
    end

    if ns.nachAusgabe then
        ns.nachAusgabe(function(id)
            if id == "PUNKT_GESETZT" or id == "PUNKT_OHNE_TOMTOM" then neuBald(1) end
        end)
    end
end)

ns.on("ZONE_CHANGED_NEW_AREA", function()
    K2.radienNachziehen()
    neuBald(1)
end)

-- Beim Oeffnen der Weltkarte. WorldMapFrame gibt es auf allen fuenf Clients; der Hook steht in
-- pcall, weil ein Addon, das den Frame ersetzt, hier sonst Lyra mitreisst.
ns.on("PLAYER_ENTERING_WORLD", function()
    if K2.kartenHook then return end
    if type(WorldMapFrame) ~= "table" or type(WorldMapFrame.HookScript) ~= "function" then return end
    local ok = pcall(WorldMapFrame.HookScript, WorldMapFrame, "OnShow", function() neuBald(0.2) end)
    K2.kartenHook = ok and true or false
end)

return K2
