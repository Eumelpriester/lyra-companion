-- Sinne/Umwelt.lua — Ortssinn und Umgebung: Zone, Atem, Erschoepfung, Rast, Taxi, Geofence.
-- Ereignisse: ZONE, ATEM30, ATEM10, MUEDE, RAST_AN, TAXI_START, TAXI_ENDE, GEOFENCE.
-- API (nur lesend): GetRealZoneText/GetZoneText, GetMirrorTimerProgress/GetMirrorTimerInfo,
--   IsResting, UnitOnTaxi, TaxiNodeName (Post-Hook auf TakeTaxiNode, nicht protected),
--   C_Map.GetBestMapForUnit/GetPlayerMapPosition, UnitAffectingCombat, UnitIsDeadOrGhost, GetTime.
-- Events: ZONE_CHANGED_NEW_AREA, MIRROR_TIMER_START/STOP, PLAYER_UPDATE_RESTING,
--   PLAYER_CONTROL_LOST/GAINED, PLAYER_ENTERING_WORLD.
-- Takt: ein 3-s-Ticker (Geofence + Flug-Flanken), eine 2-s-Tick-Kette NUR waehrend eines
--   Atem-/Erschoepfungs-Timers. Kein OnUpdate.
-- Grenzen: Instanzen liefern keine Kartenposition (Geofence still); Gefahren-Tabelle
--   ns.Gefahren ist in Phase 1 leer (siehe Sinne/Gefahren_Beispiel.lua); TAXI_START ohne
--   Ziel, wenn der Hook den Klick verpasst; Taxi-Ende wird ueber den 3-s-Ticker abgesichert.
-- Portiert aus LyraAuge zoneMarker/atemTick/muedeTick/rastMarker/flugBeginn/flugSchluss/gefahrPuls.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local U = {}
ns.Sinne.Umwelt = U

-- Gefahren-Stellen (Phase 2 fuellt sie): [mapID] = { {x=0.xx, y=0.yy, r=0.02, art="sturz|wasser", key="..."} }
ns.Gefahren = ns.Gefahren or {}

local function jetzt() return GetTime() end
local function tot() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false end
local function imKampf() return UnitAffectingCombat and UnitAffectingCombat("player") or false end
local function aufTaxi() return UnitOnTaxi and UnitOnTaxi("player") or false end

-- ---------------------------------------------------------------- ZONE
local letzteZone = nil          -- nil = Basislinie noch nicht gesetzt
local zoneBereit = false        -- erst nach dem Login-Ladebildschirm melden

local function zoneJetzt()
    local z = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
    return z
end

local function pruefeZone()
    local z = zoneJetzt()
    if z == "" then return end
    if not zoneBereit then letzteZone = z; return end       -- Login: still merken
    if z == letzteZone then return end
    -- Ladebildschirm der Regie noch aktiv (Portal, Schiff, Instanz): spaeter noch einmal.
    local riegel = ns.Regie and ns.Regie.ladeRiegelBis or 0
    if jetzt() < riegel then
        -- Nur mit echtem Timer nachlegen (der Compat-Fallback ruft sofort auf -> Endlosschleife).
        if C_Timer and C_Timer.After then ns.Compat.After(riegel - jetzt() + 0.5, pruefeZone) end
        return
    end
    letzteZone = z
    ns.melde("ZONE", { zone = z, key = z })
end

ns.on("ZONE_CHANGED_NEW_AREA", function()
    ns.Compat.After(1, pruefeZone)
end)

-- ---------------------------------------------------------------- ATEM / MUEDE
-- Spiegel-Timer: Rest in ms. GetMirrorTimerProgress(name) ist der direkte Weg;
-- Fallback ueber GetMirrorTimerInfo(1..3).
local function timerRest(name)
    if GetMirrorTimerProgress then
        local ok, ms = pcall(GetMirrorTimerProgress, name)
        if ok and type(ms) == "number" then return ms end
    end
    if GetMirrorTimerInfo then
        for i = 1, 3 do
            local ok, t, v = pcall(GetMirrorTimerInfo, i)
            if ok and t == name then return tonumber(v) or 0 end
        end
    end
    return 0
end

-- Atem: Tick-Kette NUR waehrend des BREATH-Timers. Re-Arm je Tauchgang.
local atem = { aktiv = false, ticker = nil, a30 = true, a10 = true }

local function atemStop()
    atem.aktiv = false
    if atem.ticker then atem.ticker:Cancel(); atem.ticker = nil end
end

local function atemTick()
    if not atem.aktiv then atemStop(); return end
    if tot() then return end
    local s = math.floor(timerRest("BREATH") / 1000)
    if s > 0 then
        if s <= 10 and atem.a10 then
            atem.a10 = false; atem.a30 = false
            ns.melde("ATEM10")
        elseif s <= 30 and atem.a30 then
            atem.a30 = false
            ns.melde("ATEM30")
        end
    end
end

local function atemStart()
    atem.aktiv = true
    atem.a30, atem.a10 = true, true
    if not atem.ticker then
        atem.ticker = ns.Compat.NewTicker(2, atemTick)
    end
end

-- Erschoepfung: der EXHAUSTION-Timer laeuft, sobald man im offenen Meer ist. Flanke am Start,
-- eine Meldung je Schwimmgang (Regie-Drossel 3600 obendrauf). Zwilling der Atem-Wache, aber
-- ohne Tick-Kette: die Warnung ist beim Start am meisten wert (Umkehren ist noch moeglich).
local muede = { aktiv = false, gemeldet = false }

local function muedeStart()
    muede.aktiv = true
    if muede.gemeldet or tot() then return end
    muede.gemeldet = true
    ns.melde("MUEDE")
end

local function muedeStop()
    muede.aktiv = false
    muede.gemeldet = false
end

ns.on("MIRROR_TIMER_START", function(name)
    if name == "BREATH" then atemStart()
    elseif name == "EXHAUSTION" then muedeStart() end
end)
ns.on("MIRROR_TIMER_STOP", function(name)
    if name == "BREATH" then atemStop()
    elseif name == "EXHAUSTION" then muedeStop() end
end)

-- ---------------------------------------------------------------- RAST
local letzteRast = nil          -- nil = Basislinie noch nicht gesetzt

local function pruefeRast()
    if not IsResting then return end
    local r = IsResting() and true or false
    if letzteRast == nil then letzteRast = r; return end     -- Login: still merken
    if r == letzteRast then return end
    letzteRast = r
    if r then ns.melde("RAST_AN") end
end

ns.on("PLAYER_UPDATE_RESTING", pruefeRast)

-- ---------------------------------------------------------------- TAXI
-- Post-Hook auf TakeTaxiNode (nicht protected) liest NUR den Knoten-Namen als Flugziel.
local flug = { drin = false, ziel = "", seit = 0 }

if hooksecurefunc and TaxiNodeName and TakeTaxiNode then
    pcall(hooksecurefunc, "TakeTaxiNode", function(idx)
        local ok, name = pcall(TaxiNodeName, idx)
        flug.ziel = (ok and type(name) == "string") and name or ""
        -- Der Flug beginnt kurz nach dem Klick; PLAYER_CONTROL_LOST kann VOR UnitOnTaxi feuern.
        ns.Compat.After(1, function() U.flugFlanken() end)
        ns.Compat.After(3, function() U.flugFlanken() end)
    end)
end

function U.flugFlanken()
    local taxi = aufTaxi()
    if taxi and not flug.drin then
        flug.drin = true
        flug.seit = jetzt()
        local vars = {}
        if flug.ziel ~= "" then vars.ziel = flug.ziel end
        ns.melde("TAXI_START", vars)
    elseif not taxi and flug.drin then
        flug.drin = false
        flug.ziel = ""
        flug.seit = 0
        ns.melde("TAXI_ENDE")
    end
end

ns.on("PLAYER_CONTROL_LOST", function()
    U.flugFlanken()
    ns.Compat.After(1, U.flugFlanken)
end)
ns.on("PLAYER_CONTROL_GAINED", function()
    U.flugFlanken()
    ns.Compat.After(1, U.flugFlanken)
end)

-- ---------------------------------------------------------------- GEOFENCE
local geofenceZuletzt = {}
-- 3-s-Puls: Naehe zu bekannten Gefahren-Stellen der aktuellen Karte. Flanke innerhalb r,
-- Re-Arm erst ausserhalb 2r. Im Kampf, im Flug, tot: still (Warnung waere wertlos).
local gefahrArmed = {}          -- [key] = false (verbraucht) | true/nil (scharf)

local function position()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local ok, karte = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not karte then return nil end
    local ok2, pos = pcall(C_Map.GetPlayerMapPosition, karte, "player")
    if not ok2 or not pos then return nil end
    local x, y
    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    if not x or not y then return nil end
    return karte, x, y
end

local function gefahrPuls()
    -- W8 (A9): der Ortssinn haengt an C_Map. Hat der Selbsttest (Core/Selbsttest.lua) dort einen
    -- Ausfall gemessen, kehrt der Puls in der ersten Zeile um, statt jede Sekunde in denselben
    -- kaputten Aufruf zu laufen. Ohne Selbsttest antwortet ST.ok() fail-safe mit true.
    if ns.Selbsttest and not ns.Selbsttest.ok("karte") then return end
    local tab = ns.Gefahren
    if type(tab) ~= "table" or next(tab) == nil then return end
    if tot() or aufTaxi() or imKampf() then return end
    local karte, px, py = position()
    if not karte then return end
    local stellen = tab[karte]
    if type(stellen) ~= "table" then return end
    for i, s in ipairs(stellen) do
        local r = s.r or 0.02
        local k = s.key or (tostring(karte) .. ":" .. i)
        local dx, dy = px - (s.x or 0), py - (s.y or 0)
        local d2 = dx * dx + dy * dy
        if d2 <= r * r then
            if gefahrArmed[k] ~= false then
                gefahrArmed[k] = false                    -- Flanke verbraucht
                local art = s.art or "sturz"
                local id = (art == "beinahe" and "GEOFENCE_BEINAHE") or (art == "wasser" and "GEOFENCE_WASSER") or (art == "mob" and "GEOFENCE_MOB") or "GEOFENCE"
                -- globale Bremse je Art: Mob-Lager 90 s, Rest 20 s (sonst Warnsalve beim Durchqueren)
                local jetztT = GetTime()
                local pause = (art == "mob") and 90 or 45
                if jetztT - (geofenceZuletzt[art] or 0) >= pause then
                    geofenceZuletzt[art] = jetztT
                    ns.melde(id, { key = k, art = art })
                end
            end
        elseif d2 >= 4 * r * r then
            gefahrArmed[k] = true
        end
    end
end

-- Ein Ticker fuer Geofence und Flug-Flanken (faengt fehlende/zu fruehe Control-Events).
local puls = nil
local function pulsStart()
    if puls then return end
    puls = ns.Compat.NewTicker(3, function()
        local ok, err = pcall(function()
            U.flugFlanken()
            gefahrPuls()
        end)
        if not ok then ns.debug("Umwelt puls: " .. tostring(err)) end
    end)
end

-- ---------------------------------------------------------------- Ladebildschirm
ns.on("PLAYER_ENTERING_WORLD", function()
    atemStop()
    muedeStop()
    letzteRast = nil
    -- Zonen-Basislinie: beim Login still setzen, danach (Portal/Instanz) echter Wechsel.
    if not zoneBereit then
        ns.Compat.After(5, function()
            letzteZone = zoneJetzt()
            zoneBereit = true
        end)
    else
        ns.Compat.After(1, pruefeZone)
    end
    ns.Compat.After(2, pruefeRast)
    -- Flugzustand nachfuehren ohne Meldung, wenn wir MITTEN im Flug laden (selten, aber moeglich).
    if aufTaxi() and not flug.drin then flug.drin = true; flug.seit = jetzt() end
    pulsStart()
end)

function U.stand()
    return letzteZone, atem.aktiv, muede.aktiv, letzteRast, flug.drin, flug.ziel
end
