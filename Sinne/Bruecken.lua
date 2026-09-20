-- Sinne/Bruecken.lua — Bruecken zu fremden Addons: TomTom (Wegpunkte), Questie (NPC-/Quest-Datenbank),
--   !BugGrabber/BugSack (Fehler = "wildgewordene Runen"), DBM (Boss-Rufe), natives Threat-API.
-- Grenze: Lyra ZEIGT und SPRICHT. Wegpunkte setzen ist erlaubt (der Spieler hat gefragt), Bewegung,
--   Tastendruck, Automation und SendChatMessage nie. Kein Fremd-Addon ist Voraussetzung: JEDER
--   Zugriff steht hinter einer Existenzpruefung UND in pcall. Fehlt alles, bleibt Lyra still.
-- Belege (Datei:Zeile aus dem installierten Client) und Pruefpunkte: Sinne/BRUECKEN.md.
--
-- API (eigene): ns.Bruecken.hat, .status(), .punkt(titel), .punkte(), .punktZeigen(n),
--   .sucheNpc(name), .sucheQuest(titel), .runen(), .stand()
-- Ereignisse: PUNKT_GESETZT, PUNKT_OHNE_TOMTOM, MOB_GEFUNDEN, MOB_UNBEKANNT, MOB_OHNE_QUESTIE,
--   MOB_RIVALE_WARNUNG, QUEST_GEBER_GEFUNDEN, RUNEN_FEHLER, AGGRO, BOSS_PULL, BOSS_KILL, BOSS_WIPE,
--   BOSS_ENRAGE_BALD. Antworten auf Fragen des Spielers immer mit vars.direkt = true.
-- Blizzard-API (nur lesend): C_Map.GetBestMapForUnit/GetPlayerMapPosition/GetMapInfo, GetRealZoneText,
--   UnitLevel, UnitThreatSituation, IsInGroup/IsInRaid, GetTime, time, date.
-- Events: PLAYER_LOGIN, PLAYER_ENTERING_WORLD, PLAYER_REGEN_DISABLED, UNIT_THREAT_SITUATION_UPDATE.
local ADDON, ns = ...
ns.Bruecken = {}
local B = ns.Bruecken

local NOTIZEN_MAX   = 50    -- wie UI/Dialog.lua (dieselbe Liste)
local RUNEN_FENSTER = 600   -- s zwischen zwei Runen-Meldungen nach der ersten
local RUNEN_ZEIGE   = 3     -- /lyra runen: so viele Fehler
local RUNEN_KUERZE  = 120   -- Zeichen je Fehlerzeile
local ENRAGE_VOR    = 20    -- s vor Ablauf eines Enrage-Timers
local TREFFER_MAX   = 25    -- so viele Namens-Treffer werden nach Levelnaehe sortiert
local PFEIL_DIST    = 15    -- yard, Ankunftsradius fuer SetCrazyArrow

B.hat = { tomtom = false, questie = false, buggrabber = false, bugsack = false,
          dbm = false, handynotes = false, threat = false }

B.fehler = { n = 0, letzte = 0, gemeldet = 0, weg = nil }   -- Runen-Zaehler der Sitzung
B.letzterPunkt = nil        -- uid-Tabelle von TomTom (fuer /lyra punkt erneut)
local aggroImKampf = false
local npcIndex = nil        -- { ids = {id,...}, namen = {kleingeschrieben,...} }, einmal je Sitzung
local enrageGeplant = {}    -- [timerId] = true, damit ein Timer nur einmal vorwarnt

-- ---------------------------------------------------------------------------------------------
-- Texte fuer ns.print (Listen). Gesprochene Zeilen stehen in phrasen.lua, nicht hier.
-- ---------------------------------------------------------------------------------------------
local TEXT = {
    de = {
        kopf       = "Bruecken",
        da         = "da", weg = "fehlt",
        punkteLeer = "Keine Punkte in der Chronik.",
        punkteKopf = "Punkte (%d):",
        punktZeile = "  %d. %s - %s - %s",
        punktPfeil = " [Pfeil]",
        punktWeg   = "So einen Punkt habe ich nicht.",
        punktOhne  = "Zu diesem Punkt habe ich keine Koordinaten.",
        keinePos   = "Ich weiss gerade nicht, wo wir stehen.",
        runenLeer  = "Keine wildgewordenen Runen in dieser Sitzung.",
        runenKopf  = "Wildgewordene Runen (%d):",
        runenZeile = "  %d. %s",
        ohneGrabber= "BugSack/!BugGrabber ist nicht da - ich sehe keine Runen.",
        ohneQuestie= "Questie-Daten nicht lesbar.",
        keinName   = "Wen soll ich suchen?",
        suchLaeuft = "Ich blaettere durch die Runen ...",
        hilfe = {
            "/lyra punkt [Titel] - Stelle merken (TomTom + Chronik)",
            "/lyra punkte [n] - Liste, oder Wegpunkt zu Punkt n",
            "/lyra such <Name> - Mob ueber Questie finden",
            "/lyra quest <Titel> - Questgeber finden",
            "/lyra runen - letzte Fehlermeldungen",
        },
    },
    en = {
        kopf       = "Bridges",
        da         = "yes", weg = "missing",
        punkteLeer = "No waypoints in the chronicle.",
        punkteKopf = "Waypoints (%d):",
        punktZeile = "  %d. %s - %s - %s",
        punktPfeil = " [arrow]",
        punktWeg   = "I don't have that waypoint.",
        punktOhne  = "I have no coordinates for that waypoint.",
        keinePos   = "I don't know where we are right now.",
        runenLeer  = "No runaway runes this session.",
        runenKopf  = "Runaway runes (%d):",
        runenZeile = "  %d. %s",
        ohneGrabber= "BugSack/!BugGrabber isn't here - I can't see any runes.",
        ohneQuestie= "Questie data not readable.",
        keinName   = "Who should I look for?",
        suchLaeuft = "Leafing through the runes ...",
        hilfe = {
            "/lyra waypoint [title] - remember this spot (TomTom + chronicle)",
            "/lyra waypoints [n] - list, or point the arrow at waypoint n",
            "/lyra find <name> - locate a mob via Questie",
            "/lyra quest <title> - locate a quest giver",
            "/lyra runes - last error messages",
        },
    },
}
local function T() return TEXT[ns.sprache()] or TEXT.en end

-- ---------------------------------------------------------------------------------------------
-- Kleinkram
-- ---------------------------------------------------------------------------------------------
local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function klein(s) return tostring(s or ""):lower() end
-- Fuellwoerter rund um Titel und Namen ("such mir den Hogger" -> "Hogger"). Sie fallen vorn UND
-- hinten weg. Fuer Suchbegriffe ist das immer richtig (Questie sucht ohnehin als Teilstring);
-- der Titel aus "/lyra punkt <Titel>" bleibt dagegen unangetastet - was der Spieler tippt, steht da.
local FUELL = {
    hier = true, here = true, this = true, that = true, mal = true, bitte = true, please = true,
    jetzt = true, now = true, das = true, die = true, der = true, den = true, dem = true,
    ein = true, eine = true, einen = true, mir = true, dir = true, me = true,
    the = true, a = true, an = true, is = true, ist = true,
    setzen = true, set = true, stelle = true, spot = true, punkt = true, quest = true,
}
local function entfuellen(s)
    local w = {}
    for wort in tostring(s):gmatch("%S+") do w[#w + 1] = wort end
    while #w > 0 and FUELL[w[1]:lower()] do table.remove(w, 1) end
    while #w > 0 and FUELL[w[#w]:lower()] do table.remove(w) end
    return table.concat(w, " ")
end

local function jetzt() return (GetTime and GetTime()) or 0 end
local function unix() return (time and time()) or 0 end

local function melde(id, vars)
    if not ns.melde then return false end
    local ok, v = pcall(ns.melde, id, vars)
    return ok and v or false
end

local function zoneJetzt()
    return (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "?"
end

-- Aktuelle Karte + Position (0-1). Wie Sinne/Chronik.lua.
local function position()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local ok, karte = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not karte then return nil end
    local ok2, pos = pcall(C_Map.GetPlayerMapPosition, karte, "player")
    if not ok2 or not pos then return nil end
    local x, y
    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    return karte, x, y
end

local function kartenName(uiMapID)
    if not (C_Map and C_Map.GetMapInfo and uiMapID) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, uiMapID)
    if ok and type(info) == "table" and info.name and info.name ~= "" then return info.name end
    return nil
end

local function prozent(v) return math.floor((tonumber(v) or 0) * 1000 + 0.5) / 10 end
-- REVIEW4: Koordinaten auf drei Stellen runden, bevor sie in die SavedVariables gehen (wie
-- Sinne/Chronik.lua rund3). 0.5123 statt 0.51234567890123 - drei Stellen sind auf einer Karte
-- rund 5 Yard genau und sparen je Notiz gut 20 Zeichen in der Lua-Datei.
local function rund3(v) return math.floor((tonumber(v) or 0) * 1000 + 0.5) / 1000 end

-- Chronik-Notizen: dieselbe Liste wie UI/Dialog.lua ({ t, zone, text }), nur um mapID/x/y erweitert.
-- Es wird ausschliesslich angehaengt, nie ein Feld eines fremden Eintrags ueberschrieben.
local function notizen(anlegen)
    local c = LyraGestaltDB and ns.charKey and LyraGestaltDB.chronik and LyraGestaltDB.chronik[ns.charKey]
    if type(c) ~= "table" then
        if not (anlegen and LyraGestaltDB and ns.charKey) then return nil end
        LyraGestaltDB.chronik = LyraGestaltDB.chronik or {}
        c = {}
        LyraGestaltDB.chronik[ns.charKey] = c
    end
    if type(c.notizen) ~= "table" then
        if not anlegen then return nil end
        c.notizen = {}
    end
    return c.notizen
end

-- ---------------------------------------------------------------------------------------------
-- TomTom
-- ---------------------------------------------------------------------------------------------
-- Beleg: TomTom.lua:970 AddWaypoint(m, x, y, opts) - m = uiMapID, x/y 0-1 (Kommentar TomTom.lua:1003),
-- Rueckgabe ist eine uid-TABELLE (TomTom.lua:994/1025). TomTom.profile entsteht beim ADDON_LOADED
-- von TomTom, ist bei PLAYER_LOGIN also da (AddonCore.lua:308-309).
local function tomtomDa()
    return (type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function" and TomTom.profile ~= nil) and true or false
end

local function wegpunkt(uiMapID, x, y, titel, dauerhaft, pfeil)
    if not tomtomDa() then return nil end
    local opts = {
        title      = titel,
        persistent = dauerhaft and true or false,
        minimap    = true,
        world      = true,
        crazy      = pfeil and true or false,
        from       = "Lyra",
    }
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, uiMapID, x, y, opts)
    if not ok or type(uid) ~= "table" then return nil end
    if pfeil and type(TomTom.SetCrazyArrow) == "function" then
        pcall(TomTom.SetCrazyArrow, TomTom, uid, PFEIL_DIST, titel)
        B.pfeilFaerben()
    end
    B.letzterPunkt = uid
    return uid
end

-- W5: Pfeil einfaerben. Belegt: TomTom_CrazyArrow.lua:484 SetCrazyArrowColor(r, g, b, a) und
-- :497 HijackCrazyArrow(onupdate) / :504 ReleaseCrazyArrow() / :510 CrazyArrowIsHijacked().
--
-- Warum die Wache an HijackCrazyArrow haengt und nicht an SetCrazyArrowColor: TomToms EIGENES
-- OnUpdate faerbt den Pfeil bei jedem Frame nach Blickrichtung (gruen -> rot). Eine Farbe, die
-- wir davor setzen, ist eine Sechzigstelsekunde spaeter wieder weg. Faerben ist also nur dann
-- eine Zusage, die wir halten koennen, wenn der Pfeil uebernommen (hijacked) ist - und genau das
-- tun wir NICHT: ein eigenes OnUpdate auf einem fremden Frame waere ein Verstoss gegen den
-- Leistungs-Kontrakt (nichts unter 0,5 s) und wuerde TomToms Entfernungsanzeige abschalten.
--
-- Bleibt der EHRLICHE Fall: hat ein DRITTES Addon den Pfeil bereits uebernommen, laeuft TomToms
-- Nachfaerben nicht mehr, und unser Lila haelt. Nur dann faerben wir. Sonst passiert nichts -
-- lieber gar keine Farbe als eine, die einen Frame lang zu sehen ist.
-- Alles in pcall; ohne TomTom, ohne die drei Funktionen oder bei einem Fehler: still.
B.pfeilGefaerbt = false
function B.pfeilFaerben()
    B.pfeilGefaerbt = false
    if type(TomTom) ~= "table" then return false end
    if type(TomTom.HijackCrazyArrow) ~= "function" then return false end     -- unbelegte Fassung: weglassen
    if type(TomTom.SetCrazyArrowColor) ~= "function" then return false end
    if type(TomTom.CrazyArrowIsHijacked) ~= "function" then return false end
    local ok, uebernommen = pcall(TomTom.CrazyArrowIsHijacked, TomTom)
    if not ok or not uebernommen then return false end
    local ok2 = pcall(TomTom.SetCrazyArrowColor, TomTom, 0.75, 0.55, 1.0, 1.0)   -- Lyras Lila
    B.pfeilGefaerbt = ok2 and true or false
    return B.pfeilGefaerbt
end

-- ---------------------------------------------------------------------------------------------
-- Questie (versionstolerant: ImportModule liefert bei fehlendem Modul einen LEEREN Stub,
-- QuestieLoader.lua:172-177 - darum werden immer die Felder geprueft, nie nur die Tabelle)
-- ---------------------------------------------------------------------------------------------
local function modul(name)
    if not (QuestieLoader and type(QuestieLoader.ImportModule) == "function") then return nil end
    local ok, m = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
    if ok and type(m) == "table" then return m end
    return nil
end

local function questieDB()
    local db = modul("QuestieDB")
    if not db then return nil end
    -- Query* entstehen erst in QuestieDB:Initialize (QuestieDB.lua:295-331)
    if type(db.QueryNPCSingle) ~= "function" and type(db.GetNPC) ~= "function" then return nil end
    return db
end

local function zoneDB()
    local z = modul("ZoneDB")
    if z and type(z.GetUiMapIdByAreaId) == "function" then return z end
    return nil
end

-- Alle NPC-IDs: drei Wege, aeltestes Questie zuletzt.
local function npcZeiger(db)
    if type(db.NPCPointers) == "table" then return db.NPCPointers end
    if type(db.QueryNPC) == "table" and type(db.QueryNPC.pointers) == "table" then return db.QueryNPC.pointers end
    if type(db.npcData) == "table" then return db.npcData end
    return nil
end
local function questZeiger(db)
    if type(db.QuestPointers) == "table" then return db.QuestPointers end
    if type(db.QueryQuest) == "table" and type(db.QueryQuest.pointers) == "table" then return db.QueryQuest.pointers end
    if type(db.questData) == "table" then return db.questData end
    return nil
end

-- Einzelwert lesen. Unbekannte Schluessel loesen bei Questie eine Fehlermeldung aus
-- (compiler.lua:1108-1111), darum stehen hier nur Schluessel aus npcDB.lua:7-24 / questDB.lua:6-56.
local function npcWert(db, id, key)
    if type(db.QueryNPCSingle) == "function" then
        local ok, v = pcall(db.QueryNPCSingle, id, key)
        if ok and v ~= nil then return v end
    end
    if type(db.GetNPC) == "function" then
        local ok, t = pcall(db.GetNPC, db, id)
        if ok and type(t) == "table" then return t[key] end
    end
    return nil
end
local function questWert(db, id, key)
    if type(db.QueryQuestSingle) == "function" then
        local ok, v = pcall(db.QueryQuestSingle, id, key)
        if ok and v ~= nil then return v end
    end
    if type(db.GetQuest) == "function" then
        local ok, t = pcall(db.GetQuest, id)          -- GetQuest ist ein Punkt-Aufruf (QuestieDB.lua:1454)
        if ok and type(t) == "table" then return t[key] end
    end
    return nil
end

-- Questie-areaID -> uiMapID. GetAreaIdByUiMapId kann werfen (zoneDB.lua:114), darum ueberall pcall.
local function areaZuKarte(areaId)
    local z = zoneDB()
    if not z then return nil end
    local ok, uiMap = pcall(z.GetUiMapIdByAreaId, z, areaId)
    if ok and type(uiMap) == "number" then return uiMap end
    return nil
end
local function karteZuArea(uiMapID)
    local z = zoneDB()
    if not (z and type(z.GetAreaIdByUiMapId) == "function") then return nil end
    local ok, area = pcall(z.GetAreaIdByUiMapId, z, uiMapID)
    if ok and type(area) == "number" then return area end
    return nil
end

-- Namensindex einmal je Sitzung bauen (Questie hat keine Name->ID-Tabelle; QuestieSearch macht
-- denselben Durchlauf, Modules/Journey/QuestieSearch.lua:79-136). ~10 100 Eintraege auf Era.
-- REVIEW4: Der Aufbau lief am Stueck in EINEM Frame - 10 000 QueryNPCSingle-Aufrufe sind ein
-- sichtbarer Ruckler (Questies eigenes /questie search hat denselben). Jetzt in Haeppchen von
-- INDEX_HAPPEN Eintraegen ueber C_Timer: jeder Frame traegt nur einen Bruchteil. Der Aufruf ist
-- damit asynchron - Aufrufer bekommen den Index ueber den Rueckruf "fertig(idx)".
-- Ohne C_Timer (Trockentest/uralter Client) ruft ns.Compat.After sofort auf: dann laeuft es
-- wieder am Stueck durch, aber es bleibt korrekt.
B.INDEX_HAPPEN = 500
local indexLaeuft = false
local indexWarten = {}         -- Rueckrufe, die auf den fertigen Index warten

local function indexFertig(idx)
    indexLaeuft = false
    local warten = indexWarten
    indexWarten = {}
    for _, fn in ipairs(warten) do pcall(fn, idx) end
end

local function indexBauen(db, fertig)
    if npcIndex then fertig(npcIndex); return end
    indexWarten[#indexWarten + 1] = fertig
    if indexLaeuft then return end          -- ein zweiter /lyra such haengt sich nur an
    local zeiger = npcZeiger(db)
    if not zeiger then indexFertig(nil); return end
    local roh = {}
    local ok = pcall(function() for id in pairs(zeiger) do roh[#roh + 1] = id end end)
    if not ok or #roh == 0 then indexFertig(nil); return end
    indexLaeuft = true
    local ids, namen, i = {}, {}, 0
    local function schritt()
        local bis = math.min(i + B.INDEX_HAPPEN, #roh)
        pcall(function()
            while i < bis do
                i = i + 1                    -- vor dem Lesen: ein werfender Eintrag wird uebersprungen, nicht wiederholt
                local n = npcWert(db, roh[i], "name")
                if type(n) == "string" and n ~= "" then
                    ids[#ids + 1] = roh[i]
                    namen[#namen + 1] = n:lower()
                end
            end
        end)
        if i < #roh then ns.Compat.After(0, schritt); return end
        if #ids > 0 then npcIndex = { ids = ids, namen = namen } end
        ns.debug("Bruecken: NPC-Index " .. #ids .. " (" .. math.ceil(#roh / B.INDEX_HAPPEN) .. " Haeppchen)")
        indexFertig(npcIndex)
    end
    schritt()
end

-- Treffer suchen: exakt zuerst, sonst Teilstring. Sortiert nach Levelnaehe zum Spieler.
-- REVIEW4: asynchron - das Ergebnis kommt ueber fertig(liste); liste = nil heisst "kein Index".
local function npcSuchen(db, suche, fertig)
    indexBauen(db, function(idx)
    if not idx then return fertig(nil) end
    local s = klein(trim(suche))
    if s == "" then return fertig({}) end
    local exakt, teil = {}, {}
    for i = 1, #idx.namen do
        local n = idx.namen[i]
        if n == s then exakt[#exakt + 1] = idx.ids[i]
        elseif #teil < TREFFER_MAX * 4 and n:find(s, 1, true) then teil[#teil + 1] = idx.ids[i] end
    end
    local roh = (#exakt > 0) and exakt or teil
    local eigen = (UnitLevel and UnitLevel("player")) or 0
    local liste = {}
    for i = 1, math.min(#roh, TREFFER_MAX) do
        local id = roh[i]
        local lvl = tonumber(npcWert(db, id, "minLevel")) or 0
        liste[#liste + 1] = { id = id, name = npcWert(db, id, "name") or "?", level = lvl,
                              nah = math.abs(lvl - eigen) }
    end
    table.sort(liste, function(a, c)
        if a.nah ~= c.nah then return a.nah < c.nah end
        return (a.id or 0) < (c.id or 0)
    end)
    return fertig(liste)
    end)
end

-- Spawns eines NPC -> bester Punkt. Die aktuelle Zone hat Vorrang, sonst die Zone mit den meisten
-- Spawns. Koordinaten in der Questie-DB sind 0-100 (compiler.lua:224-247, QuestieMap.lua:584),
-- {-1,-1} markiert einen Instanz-Spawn (DistanceUtils.lua:29-43) und faellt hier raus.
local function besterSpawn(db, id)
    local spawns = npcWert(db, id, "spawns")
    if type(spawns) ~= "table" then return nil end
    local hierMap, hx, hy = position()
    local eigenArea = hierMap and karteZuArea(hierMap) or nil
    local bestArea, bestN = nil, -1
    for area, liste in pairs(spawns) do
        if type(liste) == "table" and #liste > 0 then
            local n = #liste
            if eigenArea and area == eigenArea then n = n + 100000 end    -- aktuelle Zone gewinnt immer
            if n > bestN then bestArea, bestN = area, n end
        end
    end
    if not bestArea then return nil end
    local liste = spawns[bestArea]
    local uiMap = areaZuKarte(bestArea)
    if not uiMap then return nil end
    -- Bezugspunkt: eigene Position in derselben Zone, sonst der Schwerpunkt der Spawns.
    local bx, by
    if hierMap and uiMap == hierMap then bx, by = hx, hy end
    if not bx then
        local sx, sy, n = 0, 0, 0
        for _, p in ipairs(liste) do
            if type(p) == "table" and tonumber(p[1]) and p[1] > 0 then
                sx, sy, n = sx + p[1] / 100, sy + p[2] / 100, n + 1
            end
        end
        if n == 0 then return nil end
        bx, by = sx / n, sy / n
    end
    local bx2, by2, bd = nil, nil, nil
    for _, p in ipairs(liste) do
        local px, py = tonumber(p and p[1]), tonumber(p and p[2])
        if px and py and px > 0 and py > 0 then
            px, py = px / 100, py / 100
            local d = (px - bx) * (px - bx) + (py - by) * (py - by)
            if not bd or d < bd then bx2, by2, bd = px, py, d end
        end
    end
    if not bx2 then return nil end
    return uiMap, bx2, by2
end

-- Rivale? Bestiarium aus Sinne/Chronik.lua: [npcId] = { name, beinahe, tode }. Schluessel koennen
-- String (aus der GUID) oder Zahl sein - beide Wege probieren, nur lesen.
local function rivale(id)
    local c = LyraGestaltDB and ns.charKey and LyraGestaltDB.chronik and LyraGestaltDB.chronik[ns.charKey]
    local best = type(c) == "table" and c.bestiarium
    if type(best) ~= "table" then return 0 end
    local e = best[tostring(id)] or best[tonumber(id) or -1]
    if type(e) ~= "table" then return 0 end
    return (tonumber(e.beinahe) or 0) + (tonumber(e.tode) or 0)
end

-- ---------------------------------------------------------------------------------------------
-- Oeffentlich: Wegpunkt setzen
-- ---------------------------------------------------------------------------------------------
function B.punkt(titel)
    titel = trim(titel)
    local uiMap, x, y = position()
    if not uiMap then ns.print(T().keinePos); return false end
    local zone = zoneJetzt()
    if titel == "" then titel = zone .. " " .. (date and date("%H:%M") or "") end
    local liste = notizen(true)
    if liste then
        table.insert(liste, { t = unix(), zone = zone, text = titel, mapID = uiMap, x = rund3(x), y = rund3(y) })
        while #liste > NOTIZEN_MAX do table.remove(liste, 1) end
    end
    if wegpunkt(uiMap, x, y, titel, true, false) then
        melde("PUNKT_GESETZT", { direkt = true, titel = titel })
    else
        melde("PUNKT_OHNE_TOMTOM", { direkt = true, titel = titel })
    end
    return true
end

function B.punkte()
    local liste = notizen(false)
    if not liste or #liste == 0 then ns.print(T().punkteLeer); return false end
    local t = T()
    ns.print(t.punkteKopf:format(#liste))
    for i = 1, #liste do
        local e = liste[i]
        if type(e) == "table" then
            local z = t.punktZeile:format(i, (date and date("%d.%m. %H:%M", e.t or 0)) or "?",
                tostring(e.zone or "?"), tostring(e.text or "?"))
            if e.mapID and e.x and e.y then z = z .. t.punktPfeil end
            ns.print(z)
        end
    end
    return true
end

function B.punktZeigen(n)
    local liste = notizen(false)
    n = tonumber(n)
    local e = (liste and n) and liste[n] or nil
    if type(e) ~= "table" then ns.print(T().punktWeg); return false end
    if not (e.mapID and e.x and e.y) then ns.print(T().punktOhne); return false end
    local titel = tostring(e.text or e.zone or "?")
    if wegpunkt(e.mapID, e.x, e.y, titel, false, true) then
        melde("PUNKT_GESETZT", { direkt = true, titel = titel })
    else
        melde("PUNKT_OHNE_TOMTOM", { direkt = true, titel = titel })
    end
    return true
end

-- ---------------------------------------------------------------------------------------------
-- Oeffentlich: Mob suchen
-- ---------------------------------------------------------------------------------------------
-- REVIEW4: Der Namensindex wird in Haeppchen gebaut (s. o.), die Antwort kommt darum ggf. erst ein
-- paar Frames spaeter. Der Rueckgabewert sagt nur noch, ob die Suche ueberhaupt losgelaufen ist -
-- es wertet ihn niemand aus (UI/Slash.lua und die Dialog-Aktion ignorieren ihn).
function B.sucheNpc(name)
    name = entfuellen(trim(name))
    if name == "" then ns.print(T().keinName); return false end
    local db = questieDB()
    if not db then melde("MOB_OHNE_QUESTIE", { direkt = true }); return false end
    if not npcIndex then ns.print(T().suchLaeuft) end
    npcSuchen(db, name, function(treffer)
        if not treffer then
            ns.print(T().ohneQuestie)
            melde("MOB_OHNE_QUESTIE", { direkt = true })
            return
        end
        if #treffer == 0 then melde("MOB_UNBEKANNT", { direkt = true, name = name }); return end
        local best, uiMap, x, y
        for i = 1, #treffer do
            local m, px, py = besterSpawn(db, treffer[i].id)
            if m then best, uiMap, x, y = treffer[i], m, px, py; break end
        end
        if not best then melde("MOB_UNBEKANNT", { direkt = true, name = name }); return end
        local zone = kartenName(uiMap) or zoneJetzt()
        -- Ohne TomTom bleibt die Zeile gleich, dazu kommen Zone und Koordinaten in Prozent im Chat.
        if not wegpunkt(uiMap, x, y, best.name, false, true) then
            ns.print(("%s: %s %.1f, %.1f"):format(tostring(best.name), tostring(zone), prozent(x), prozent(y)))
        end
        melde("MOB_GEFUNDEN", { direkt = true, name = best.name, zone = zone })
        local n = rivale(best.id)
        if n > 0 then
            melde("MOB_RIVALE_WARNUNG", { direkt = true, name = best.name, n = n, key = tostring(best.id) })
        end
    end)
    return true
end

-- ---------------------------------------------------------------------------------------------
-- Oeffentlich: Questgeber suchen (startedBy = { {npcIds}, {objectIds}, {itemIds} },
-- compiler.lua:257-263; questKeys questDB.lua:6-56)
-- ---------------------------------------------------------------------------------------------
function B.sucheQuest(titel)
    titel = entfuellen(trim(titel))
    if titel == "" then ns.print(T().keinName); return false end
    local db = questieDB()
    if not db or (type(db.QueryQuestSingle) ~= "function" and type(db.GetQuest) ~= "function") then
        melde("MOB_OHNE_QUESTIE", { direkt = true }); return false
    end
    local zeiger = questZeiger(db)
    if not zeiger then
        ns.print(T().ohneQuestie)
        melde("MOB_OHNE_QUESTIE", { direkt = true })
        return false
    end
    local s = klein(titel)
    local eigen = (UnitLevel and UnitLevel("player")) or 0
    local best, bestNah, bestName
    local ok = pcall(function()
        for id in pairs(zeiger) do
            local n = questWert(db, id, "name")
            if type(n) == "string" and n ~= "" then
                local kn = n:lower()
                if kn == s or kn:find(s, 1, true) then
                    local lvl = tonumber(questWert(db, id, "questLevel")) or 0
                    local nah = math.abs(lvl - eigen) - ((kn == s) and 1000 or 0)
                    if not bestNah or nah < bestNah then best, bestNah, bestName = id, nah, n end
                end
            end
        end
    end)
    if not ok or not best then melde("MOB_UNBEKANNT", { direkt = true, name = titel }); return false end
    local startedBy = questWert(db, best, "startedBy")
    local npcs = type(startedBy) == "table" and startedBy[1] or nil
    if type(npcs) ~= "table" or #npcs == 0 then
        melde("MOB_UNBEKANNT", { direkt = true, name = titel }); return false
    end
    local geber, uiMap, x, y
    for i = 1, #npcs do
        local m, px, py = besterSpawn(db, npcs[i])
        if m then geber, uiMap, x, y = npcs[i], m, px, py; break end
    end
    if not geber then melde("MOB_UNBEKANNT", { direkt = true, name = titel }); return false end
    local gname = npcWert(db, geber, "name") or "?"
    local zone = kartenName(uiMap) or zoneJetzt()
    if not wegpunkt(uiMap, x, y, gname, false, true) then
        ns.print(("%s: %s %.1f, %.1f"):format(tostring(gname), tostring(zone), prozent(x), prozent(y)))
    end
    melde("QUEST_GEBER_GEFUNDEN", { direkt = true, name = gname, zone = zone, titel = bestName or titel })
    return true
end

-- ---------------------------------------------------------------------------------------------
-- !BugGrabber: "wildgewordene Runen"
-- v12 feuert ueber EventRegistry ("BugGrabber.BugGrabbed", Argument ist eine tableID-Zeichenkette,
-- BugGrabber.lua:422). Aeltere Versionen nutzen CallbackHandler ("BugGrabber_BugGrabbed").
-- Beide Wege werden versucht; ohne Callback bleibt die Liste ueber GetDB() trotzdem lesbar.
-- ---------------------------------------------------------------------------------------------
local function grabberDa()
    return (type(BugGrabber) == "table" and type(BugGrabber.GetDB) == "function") and true or false
end

local function runenDB()
    if not grabberDa() then return nil end
    local ok, db = pcall(BugGrabber.GetDB, BugGrabber)
    if ok and type(db) == "table" then return db end
    return nil
end

local function runeGezaehlt()
    B.fehler.n = B.fehler.n + 1
    B.fehler.letzte = jetzt()
    local t = jetzt()
    if B.fehler.gemeldet == 0 or (t - B.fehler.gemeldet) >= RUNEN_FENSTER then
        B.fehler.gemeldet = t
        melde("RUNEN_FEHLER", { n = B.fehler.n })
    end
end

-- REVIEW4: Doppelte Registrierung ist ausgeschlossen - B.fehler.weg wird beim ersten Erfolg
-- gesetzt und riegelt das Nachfassen bei PLAYER_LOGIN + 10 s ab.
local function runenCallbacks()
    if B.fehler.weg or not grabberDa() then return end
    -- Weg 1 (aktuell): Blizzards EventRegistry, Callback bekommt (owner, tableID)
    if EventRegistry and type(EventRegistry.RegisterCallback) == "function" then
        -- REVIEW4: Eigner als Feld am Modul statt als lokale Tabelle. CallbackRegistryMixin legt
        -- den Eigner als Schluessel ab; ob diese Tabelle schwach ist, ist nicht belegt - eine
        -- lokale Tabelle koennte also eingesammelt werden und der Callback still verschwinden.
        B.fehlerEigner = B.fehlerEigner or {}
        local ok = pcall(EventRegistry.RegisterCallback, EventRegistry, "BugGrabber.BugGrabbed",
            function() runeGezaehlt() end, B.fehlerEigner)
        if ok then B.fehler.weg = "EventRegistry"; return end
    end
    -- Weg 2 (alt): CallbackHandler-Embed von !BugGrabber
    if type(BugGrabber.RegisterCallback) == "function" then
        local ok = pcall(BugGrabber.RegisterCallback, B, "BugGrabber_BugGrabbed", function() runeGezaehlt() end)
        if ok then B.fehler.weg = "CallbackHandler"; return end
    end
end

function B.runen()
    local t = T()
    if not grabberDa() then ns.print(t.ohneGrabber); return false end
    local db = runenDB()
    if not db or #db == 0 then ns.print(t.runenLeer); return false end
    ns.print(t.runenKopf:format(B.fehler.n > 0 and B.fehler.n or #db))
    local gezeigt = 0
    for i = #db, 1, -1 do
        local e = db[i]
        local msg = type(e) == "table" and e.message or (type(e) == "string" and e or nil)
        if msg then
            msg = tostring(msg):gsub("[\r\n]+", " ")
            if #msg > RUNEN_KUERZE then msg = msg:sub(1, RUNEN_KUERZE - 3) .. "..." end
            gezeigt = gezeigt + 1
            ns.print(t.runenZeile:format(gezeigt, msg))
            if gezeigt >= RUNEN_ZEIGE then break end
        end
    end
    if gezeigt == 0 then ns.print(t.runenLeer) end
    return true
end

-- ---------------------------------------------------------------------------------------------
-- Threat (nativ). UnitThreatSituation gibt es auf Era (Omen ruft es ohne jede Pruefung,
-- Omen.lua:65/1751). Status 3 = hoechste Bedrohung UND selbst im Nahkampf-Ziel. Solo ist das
-- der Normalfall und wird ignoriert.
-- ---------------------------------------------------------------------------------------------
local function inGruppe()
    return ((IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid())) and true or false
end

local function threatPruefen(unit)
    -- WELLE3: Seit 0.8.0 gehoert die Bedrohungs-Flanke ganz Sinne/Bedrohung.lua - dort mit der
    -- Unterscheidung "du hast Aggro" (AGGRO, wie hier) gegen "du hast sie dem Tank aus der Hand
    -- genommen" (AGGRO_TROTZ_TANK) und mit AGGRO_VERLOREN. Ohne diese Wache warnten beide
    -- Dateien in derselben Sekunde. B.hat.threat bleibt fuer /lyra status stehen.
    if ns.Bedrohung then return end
    if unit ~= "player" then return end
    if not B.hat.threat then return end
    if not inGruppe() then return end
    local ok, st = pcall(UnitThreatSituation, "player")
    if not ok then return end
    if st == 3 then
        if aggroImKampf then return end
        aggroImKampf = true
        melde("AGGRO")
    end
    -- Bedrohung verloren: still (kein Ereignis), der Merker bleibt bis Kampfbeginn stehen.
end

-- ---------------------------------------------------------------------------------------------
-- DBM (nicht installiert; alles hinter if DBM and DBM.RegisterCallback)
-- ---------------------------------------------------------------------------------------------
local dbmGebunden = false

local function bossName(mod)
    if type(mod) ~= "table" then return nil end
    local ok, n = pcall(function()
        local l = mod.localization
        return (l and l.general and l.general.name)
            or (mod.combatInfo and mod.combatInfo.name)
            or mod.name or mod.id
    end)
    if ok and type(n) == "string" and n ~= "" then return n end
    return nil
end

local function enrageName(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "string" then
            local k = v:lower()
            if k:find("enrage", 1, true) or k:find("berserk", 1, true)
                or k:find("raserei", 1, true) or k:find("berserker", 1, true) then return v end
        end
    end
    return nil
end

local function dbmBinden()
    if dbmGebunden then return end
    if not (DBM and type(DBM.RegisterCallback) == "function") then return end
    dbmGebunden = true
    B.hat.dbm = true
    pcall(DBM.RegisterCallback, DBM, "DBM_Pull", function(_, mod)
        melde("BOSS_PULL", { name = bossName(mod) or "?" })
    end)
    pcall(DBM.RegisterCallback, DBM, "DBM_Kill", function(_, mod)
        melde("BOSS_KILL", { name = bossName(mod) or "?" })
    end)
    pcall(DBM.RegisterCallback, DBM, "DBM_Wipe", function(_, mod)
        melde("BOSS_WIPE", { name = bossName(mod) or "?" })
    end)
    -- DBM_TimerStart(event, id, msg, timer, icon, timerType, spellId, ...) - Signatur schwankt je
    -- DBM-Version, darum wird jedes String-Argument auf "Enrage"/"Berserk" geprueft.
    -- REVIEW4: Der Rueckruf heisst je nach DBM-Stand DBM_TimerStart ODER DBM_TimerBegin. Beide
    -- werden registriert; feuern beide fuer denselben Timer, faengt enrageGeplant (Schluessel aus
    -- id + Dauer) die zweite Vorwarnung ab - es bleibt bei EINER Zeile.
    local function enrageTimer(_, id, ...)
        local name = enrageName(...)
        if not name then return end
        local dauer
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            if type(v) == "number" and v > ENRAGE_VOR + 5 then dauer = v; break end
        end
        if not dauer then return end
        local schluessel = tostring(id) .. ":" .. tostring(math.floor(dauer))
        if enrageGeplant[schluessel] then return end
        enrageGeplant[schluessel] = true
        ns.Compat.After(dauer - ENRAGE_VOR, function()
            enrageGeplant[schluessel] = nil
            if not (ns.Regie and ns.Regie.imKampf) then return end
            melde("BOSS_ENRAGE_BALD", { sek = ENRAGE_VOR, name = name })
        end)
    end
    pcall(DBM.RegisterCallback, DBM, "DBM_TimerStart", enrageTimer)
    pcall(DBM.RegisterCallback, DBM, "DBM_TimerBegin", enrageTimer)
    ns.debug("Bruecken: DBM gebunden")
end

-- ---------------------------------------------------------------------------------------------
-- Dialog-Aktionen. UI/Dialog.lua:573 ruft die Aktion seit 0.3.x als fn(inhalt, roh) auf -
-- "inhalt" ist der Rest hinter dem getroffenen Praefix aus bruecken_dialog.lua.
-- REVIEW4: Damit ist der frueher noetige Wrapper um ns.Dialog.frage (der sich den Rohtext merkte
-- und den Praefix selbst abschnitt) ersatzlos entfallen. Nebenwirkung des alten Wegs war ein
-- echter Fehler: ein Klick auf einen Dialog-Knopf ruft die Aktion OHNE Argumente auf, der Wrapper
-- lieferte dann den Rest der ZULETZT getippten Freitext-Frage nach ("/lyra wo ist Hogger", dann
-- spaeter ein Klick auf "Punkt setzen" -> Titel "Hogger"). Ausserdem lagen damit zwei Wrapper um
-- dieselbe Funktion (Sinne/Erbe.lua legt seinen bei PLAYER_LOGIN ebenfalls); jetzt ist es einer.
-- Rueckgabe nil = die Aktion hat schon selbst geantwortet (ueber ns.melde mit vars.direkt).
-- ---------------------------------------------------------------------------------------------
local function inhaltVon(inhalt)
    return entfuellen(trim(inhalt or ""))
end

local function aktionenRegistrieren()
    if not (ns.Dialog and type(ns.Dialog.aktionen) == "table") then return end
    local A = ns.Dialog.aktionen
    A.bruecke_punkt = function(inhalt)
        local uiMap = position()
        if not uiMap then return "bruecke_keine_position" end
        B.punkt(inhaltVon(inhalt))
        return nil
    end
    A.bruecke_punkte = function()
        local liste = notizen(false)
        if not liste or #liste == 0 then return "bruecke_keine_punkte" end
        B.punkte()
        return nil
    end
    A.bruecke_mob = function(inhalt)
        local name = inhaltVon(inhalt)
        if name == "" then return "bruecke_kein_name" end
        B.sucheNpc(name)
        return nil
    end
    A.bruecke_quest = function(inhalt)
        local titel = inhaltVon(inhalt)
        if titel == "" then return "bruecke_kein_name" end
        B.sucheQuest(titel)
        return nil
    end
    A.bruecke_runen = function()
        if not grabberDa() then return "bruecke_ohne_buggrabber" end
        local db = runenDB()
        if not db or #db == 0 then return "bruecke_keine_runen" end
        B.runen()
        return nil
    end
    ns.debug("Bruecken: Dialog-Aktionen registriert")
end

-- ---------------------------------------------------------------------------------------------
-- Erkennung und Status
-- ---------------------------------------------------------------------------------------------
local function erkennen()
    B.hat.tomtom     = tomtomDa()
    B.hat.questie    = questieDB() ~= nil
    B.hat.buggrabber = grabberDa()
    B.hat.bugsack    = (type(BugSack) == "table") and true or false
    B.hat.dbm        = (DBM and type(DBM.RegisterCallback) == "function") and true or false
    B.hat.handynotes = (type(HandyNotes) == "table" and type(HandyNotes.RegisterPluginDB) == "function") and true or false
    B.hat.threat     = (type(UnitThreatSituation) == "function") and true or false
end

function B.status()
    local t = T()
    erkennen()
    local out = { t.kopf .. ":" }
    local reihe = { "tomtom", "questie", "buggrabber", "bugsack", "dbm", "handynotes", "threat" }
    for _, k in ipairs(reihe) do
        out[#out + 1] = "  " .. k .. ": " .. (B.hat[k] and t.da or t.weg)
    end
    local liste = notizen(false)
    out[#out + 1] = "  " .. t.punkteKopf:format(liste and #liste or 0)
    out[#out + 1] = "  " .. t.runenKopf:format(B.fehler.n)
    return out
end

function B.hilfe()
    return T().hilfe or {}
end

function B.stand()
    return B.hat, B.runen, npcIndex and #npcIndex.ids or 0, aggroImKampf, B.letzterPunkt
end

-- ---------------------------------------------------------------------------------------------
-- Ereignisse
-- ---------------------------------------------------------------------------------------------
ns.on("PLAYER_LOGIN", function()
    erkennen()
    aktionenRegistrieren()
    runenCallbacks()
    dbmBinden()
    -- DBM/TomTom/Questie koennen nach uns laden (LoadOnDemand, Ladereihenfolge): ein Nachfassen.
    ns.Compat.After(10, function()
        erkennen()
        runenCallbacks()
        dbmBinden()
    end)
end)

ns.on("PLAYER_ENTERING_WORLD", function()
    aggroImKampf = false
    erkennen()
end)

ns.on("PLAYER_REGEN_DISABLED", function() aggroImKampf = false end)

if type(UnitThreatSituation) == "function" then
    ns.on("UNIT_THREAT_SITUATION_UPDATE", threatPruefen)
end
