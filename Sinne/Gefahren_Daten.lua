-- Sinne/Gefahren_Daten.lua — Uebernahme der Gefahrenkarte aus dem Daten-Addon Lyra_Gestalt_Daten.
-- Quelle: globale Tabelle LyraGestalt_Daten (gefahren.lua, GPLv3, aggregiert aus Deathlog).
--   LyraGestalt_Daten.zellen[mapID] = { {x=, y=, n=, sturz=, wasser=, npc=, nn=, lvl=}, ... }
--   x, y Zellmitte als Kartenanteil 0..1 (2%-Raster), n Tode, sturz Fallschaden, wasser
--   Ertrinken+Ermuedung, npc/nn Top-NPC-ID und dessen Tode, lvl Median-Level der Toten.
-- Ziel: ns.Gefahren[mapID] im Format von Sinne/Umwelt.lua:
--   { x=, y=, r=0.02, art="sturz"|"wasser"|"mob", key="d<mapID>_<x>_<y>" }
-- Regeln:
--   art = "sturz"  wenn sturz >= 3 und sturz >= 50 % der Tode der Zelle
--   art = "wasser" wenn wasser >= 3 und wasser >= 50 % der Tode
--   art = "mob"    sonst — aber nur, wenn n >= MOB_MIN (Standard 100); zusaetzlich hoechstens
--                  MOB_MAX_JE_KARTE Mob-Zellen je Karte (die toedlichsten). Ohne diese Bremse
--                  waere z. B. Elwynn mit 744 Zellen belegt und Lyra wuerde im 3-s-Takt warnen.
--   Level-Relevanz: nur Zellen mit |lvl - Spielerlevel| <= LEVEL_FENSTER (8); Nachfuehren bei
--                  PLAYER_LEVEL_UP. Sonst warnt Lyra in Elwynn mit Level 40.
-- Events: ADDON_LOADED (Lyra_Gestalt_Daten), PLAYER_LOGIN (Fallback), PLAYER_LEVEL_UP.
-- API (nur lesend): UnitLevel. Kein Ticker, kein OnUpdate — der Puls liegt in Umwelt.lua.
-- Grenzen: fremde Eintraege in ns.Gefahren (andere Quellen) bleiben unangetastet; nur
--   Schluessel mit Praefix "d" aus dieser Datei werden beim Neuaufbau ersetzt.
--   vars.art = "mob" kennt phrasen.lua (GEOFENCE) noch nicht — die Zeile ist dort zufaellig.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
ns.Gefahren = ns.Gefahren or {}
local G = {}
ns.Sinne.GefahrenDaten = G

G.DATEN_ADDON      = "Lyra_Gestalt_Daten"
G.LEVEL_FENSTER    = 8       -- +- Level um das Spielerlevel
G.UMWELT_MIN       = 3       -- Mindestzahl Sturz- bzw. Wasser-Tode fuer art sturz/wasser
G.MOB_MIN          = 100     -- Mindest-Tode fuer eine Mob-Zelle
G.MOB_MAX_JE_KARTE = 30      -- Deckel fuer Mob-Zellen je Karte
G.RADIUS           = 0.02    -- Kartenanteil; Zelle ist 0.02 breit, Re-Arm in Umwelt.lua bei 2r

local eigene = {}            -- [mapID] = { [key] = true } — was wir eingespielt haben
local level = nil            -- zuletzt verwendetes Spielerlevel
local stand = { karten = 0, zellen = 0, sturz = 0, wasser = 0, mob = 0 }

local function spielerLevel()
    if not UnitLevel then return nil end
    local ok, l = pcall(UnitLevel, "player")
    l = ok and tonumber(l) or nil
    if l and l > 0 then return l end
    return nil
end

local function artVon(z)
    local n = tonumber(z.n) or 0
    local s = tonumber(z.sturz) or 0
    local w = tonumber(z.wasser) or 0
    if s >= G.UMWELT_MIN and s * 2 >= n then return "sturz" end
    if w >= G.UMWELT_MIN and w * 2 >= n then return "wasser" end
    return "mob"
end

-- Eigene Eintraege aus ns.Gefahren[mapID] entfernen, fremde behalten.
local function raeumen(mapID)
    local keys = eigene[mapID]
    local liste = ns.Gefahren[mapID]
    if not keys or type(liste) ~= "table" then eigene[mapID] = nil; return end
    local rest = {}
    for _, s in ipairs(liste) do
        if not (s.key and keys[s.key]) then rest[#rest + 1] = s end
    end
    if #rest > 0 then ns.Gefahren[mapID] = rest else ns.Gefahren[mapID] = nil end
    eigene[mapID] = nil
end

-- Zellen einer Karte fuer das Level filtern und in ns.Gefahren[mapID] anhaengen.
local function einspielenKarte(mapID, zellen, lvl)
    local umwelt, mobs = {}, {}
    local fenster = G.LEVEL_FENSTER
    for _, z in ipairs(zellen) do
        local zl = tonumber(z.lvl)
        if type(z.x) == "number" and type(z.y) == "number" and zl and math.abs(zl - lvl) <= fenster then
            local art = artVon(z)
            if art == "mob" then
                if (tonumber(z.n) or 0) >= G.MOB_MIN then mobs[#mobs + 1] = z end
            else
                umwelt[#umwelt + 1] = { z = z, art = art }
            end
        end
    end
    if #mobs > G.MOB_MAX_JE_KARTE then
        table.sort(mobs, function(a, b) return (a.n or 0) > (b.n or 0) end)
        for i = #mobs, G.MOB_MAX_JE_KARTE + 1, -1 do mobs[i] = nil end
    end
    if #umwelt == 0 and #mobs == 0 then return 0 end

    local liste = ns.Gefahren[mapID]
    if type(liste) ~= "table" then liste = {}; ns.Gefahren[mapID] = liste end
    local keys = {}
    eigene[mapID] = keys
    local function anhaengen(z, art)
        local key = "d" .. mapID .. "_" .. z.x .. "_" .. z.y
        keys[key] = true
        liste[#liste + 1] = { x = z.x, y = z.y, r = G.RADIUS, art = art, key = key }
        stand.zellen = stand.zellen + 1
        stand[art] = (stand[art] or 0) + 1
    end
    for _, e in ipairs(umwelt) do anhaengen(e.z, e.art) end
    for _, z in ipairs(mobs) do anhaengen(z, "mob") end
    stand.karten = stand.karten + 1
    return #umwelt + #mobs
end

-- Kompletter Neuaufbau fuer ein Level. Idempotent; laeuft bei Laden und je Level-Up.
function G.neu(lvl)
    -- REVIEW9: Client-Weiche VOR allem anderen. Die Zellen sind Classic-Era-Hardcore-Tode; auf
    -- Retail und FOREVER steht hinter derselben mapID eine andere Welt. Bisher lief die Uebernahme
    -- dort mit und fand meist nichts — eine Zelle, die doch trifft, waere eine falsche Warnung.
    -- Begruendung steht bei C.F.gefahrenkarte in Core/Compat.lua. Es wird nur geraeumt, nie
    -- gemeldet: die Rueckmeldung holt man sich mit /lyra status.
    if ns.Compat and ns.Compat.F and ns.Compat.F.gefahrenkarte == false then
        for mapID in pairs(eigene) do raeumen(mapID) end
        stand = { karten = 0, zellen = 0, sturz = 0, wasser = 0, mob = 0 }
        ns.debug("Gefahrenkarte: auf Profil " .. tostring(ns.Compat.profil) .. " abgeschaltet (Era-Daten)")
        return false
    end
    local D = LyraGestalt_Daten
    if type(D) ~= "table" or type(D.zellen) ~= "table" then return false end
    lvl = tonumber(lvl) or spielerLevel()
    if not lvl then return false end
    level = lvl
    for mapID in pairs(eigene) do raeumen(mapID) end
    stand = { karten = 0, zellen = 0, sturz = 0, wasser = 0, mob = 0 }
    -- REVIEW2: Schalter aus -> nur raeumen. Vorher wurde lvl = 0 gesetzt und damit jede Zelle mit lvl <= 8 eingespielt.
    if ns.Get and ns.Get("gefahrenkarte") == false then ns.debug("Gefahrenkarte aus"); return true end
    for mapID, zellen in pairs(D.zellen) do
        if type(mapID) == "number" and type(zellen) == "table" then
            einspielenKarte(mapID, zellen, lvl)
        end
    end
    ns.debug(("Gefahrenkarte %s: Level %d, %d Karten, %d Zellen (Sturz %d, Wasser %d, Mob %d)"):format(
        tostring(D.version), lvl, stand.karten, stand.zellen, stand.sturz, stand.wasser, stand.mob))
    return true
end

local function nachfuehren(lvl)
    lvl = tonumber(lvl) or spielerLevel()
    if not lvl or lvl == level then return end
    G.neu(lvl)
end

ns.on("ADDON_LOADED", function(name)
    if name ~= G.DATEN_ADDON then return end
    -- UnitLevel kann hier noch 0 sein; dann uebernimmt PLAYER_LOGIN.
    if spielerLevel() then G.neu() end
end)
ns.on("PLAYER_LOGIN", function()
    if not level then G.neu() end
end)
ns.on("PLAYER_LEVEL_UP", function(neu)
    nachfuehren(neu)
end)

function G.stand()
    return level, stand.karten, stand.zellen, stand.sturz, stand.wasser, stand.mob
end

-- REVIEW9: eine Zeile fuer /lyra status. Bis 0.9.0 gab es ueberhaupt keine Rueckmeldung — wer
-- die Gefahrenkarte installiert hatte und nie eine Warnung bekam, konnte nicht unterscheiden,
-- ob das Paket fehlt, der Schalter aus ist oder der Client nicht passt. Genau diese drei Faelle
-- stehen hier, in der Reihenfolge ihrer Endgueltigkeit.
function G.status()
    local de = (ns.sprache and ns.sprache() == "de") and true or false
    local C = ns.Compat
    if C and C.F and C.F.gefahrenkarte == false then
        return { (de and "Gefahrenkarte: auf diesem Client (%s) aus - die Daten sind Classic-Era-Tode."
                     or "Danger map: off on this client (%s) - the data is Classic Era deaths."
                 ):format(tostring(C.profil)) }
    end
    if ns.Get and ns.Get("gefahrenkarte") == false then
        return { de and "Gefahrenkarte: in den Einstellungen aus." or "Danger map: switched off in the settings." }
    end
    if type(LyraGestalt_Daten) ~= "table" then
        return { de and "Gefahrenkarte: kein Datenpaket geladen." or "Danger map: no data pack loaded." }
    end
    return { (de and "Gefahrenkarte: %d Zellen auf %d Karten (Stufe %s)."
                 or "Danger map: %d cells on %d maps (level %s)."
             ):format(stand.zellen, stand.karten, tostring(level or "?")) }
end
