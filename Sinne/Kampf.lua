-- Sinne/Kampf.lua — Kampf-Flanken, Adds-Wache, Gefaehrder (Elite/Stufen), Seltene.
-- Ereignisse: KAMPF_AN (still), KAMPF_AUS (nur bei Kampfdauer >= 20 s), ADDS (1x je Kampf),
--   GEFAHR_ELITE, GEFAHR_STUFEN, RARE.
-- API (nur lesend): UnitExists, UnitIsPlayer, UnitCanAttack, UnitIsDeadOrGhost, UnitIsDead,
--   UnitPlayerControlled, UnitAffectingCombat, UnitClassification, UnitLevel, UnitName, UnitGUID,
--   C_NamePlate.GetNamePlates, UnitOnTaxi, GetTime.
-- Events: PLAYER_REGEN_DISABLED/ENABLED, PLAYER_TARGET_CHANGED, UPDATE_MOUSEOVER_UNIT,
--   NAME_PLATE_UNIT_ADDED/REMOVED, PLAYER_ENTERING_WORLD.
-- Grenzen: KEIN Combat-Log in Phase 1 (bewusst weggelassen); Nameplate-Sicht setzt
--   eingeschaltete Nameplates voraus (V-Taste), Ziel und Mouseover gehen immer.
-- PORT (0.9.0): Diese Datei war schon ohne Combat-Log gebaut und laeuft darum auf allen fuenf
--   Clients. Die EINZIGE Bruchstelle war das Ziel-Level in zielPruefe() — siehe dort.
--   UnitAffectingCombat(unit) fuer fremde Einheiten (Adds-Wache) ist ein bool, kein Zahlenwert,
--   und faellt damit nicht unter Secret Values; sollte der Aufruf auf Mainline doch werfen,
--   faengt ihn der pcall in addsZaehle() ab und die Add-Meldung entfaellt still.
-- Privatsphaere (Grenze B): UnitIsPlayer-Sperre steht in JEDEM Ziel-/Sicht-Pfad als Erstes —
--   Spieler-Ziele (Duell, PvP) erzeugen nichts, keine Namen anderer Spieler.
-- Portiert aus LyraAuge kampfAn/kampfAus/addsPruefe/zielMarker/rareSichtung (Katalog E, 0.8.2, 0.9.14).
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local K = {}
ns.Sinne.Kampf = K

local KAMPF_AUS_MIN = 20        -- s: erst ab dieser Dauer ist das Ende eine Nachricht wert
local STUFEN_ABSTAND = 3        -- Ziel-Level >= eigenes Level + 3

local function jetzt() return GetTime() end
local function tot() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false end
local function imKampf() return UnitAffectingCombat and UnitAffectingCombat("player") or false end
local function aufTaxi() return UnitOnTaxi and UnitOnTaxi("player") or false end

local function wipe(t) for k in pairs(t) do t[k] = nil end end

-- ---------------------------------------------------------------- Kampf-Flanken
local kampfSeit = 0

-- Adds-Wache: feindliche Nameplates IM Kampf. Ein Nameplate allein heisst nichts (auf einer
-- Wiese stehen zwanzig herum) — UnitAffectingCombat(unit) trennt "da sind Mobs" von
-- "die schlagen gerade". Eine Meldung je Kampf.
local platten = {}              -- unit-token -> true
local addsGemeldet = false
local addsGeplant = false

local function feindImKampf(u)
    if not (UnitExists and UnitExists(u)) then return false end
    if UnitIsPlayer and UnitIsPlayer(u) then return false end
    if UnitPlayerControlled and UnitPlayerControlled(u) then return false end
    if not (UnitCanAttack and UnitCanAttack("player", u)) then return false end
    if UnitIsDead and UnitIsDead(u) then return false end
    -- PORT (0.9.0): fremde Einheit. Der Rueckgabewert ist ein bool und faellt damit nicht unter
    -- Secret Values — aber addsPruefe laeuft aus einem C_Timer, und dort waere ein Fehler ein
    -- echter Lua-Fehler ohne Schutznetz. Deshalb pcall: wirft es auf Mainline doch, entfaellt
    -- nur die Add-Meldung.
    if not UnitAffectingCombat then return false end
    local ok, kampf = pcall(UnitAffectingCombat, u)
    if not (ok and kampf) then return false end
    return true
end

local function addsZaehle()
    local n = 0
    local gesehen = {}
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, liste = pcall(C_NamePlate.GetNamePlates)
        if ok and type(liste) == "table" then
            for _, np in ipairs(liste) do
                local u = np and (np.namePlateUnitToken or (np.UnitFrame and np.UnitFrame.unit))
                if u and not gesehen[u] then
                    gesehen[u] = true
                    if feindImKampf(u) then n = n + 1 end
                end
            end
        end
    end
    for u in pairs(platten) do
        if not gesehen[u] then
            gesehen[u] = true
            if feindImKampf(u) then n = n + 1 end
        end
    end
    return n
end

local function addsPruefe()
    addsGeplant = false
    if addsGemeldet or tot() or aufTaxi() or not imKampf() then return end
    if addsZaehle() >= 2 then
        addsGemeldet = true
        ns.melde("ADDS")
    end
end

-- Kurz verzoegert pruefen: UnitAffectingCombat(unit) haengt dem Nameplate um einen Tick nach.
local function addsPlanen(sek)
    if addsGeplant or addsGemeldet then return end
    addsGeplant = true
    ns.Compat.After(sek or 1, addsPruefe)
end

ns.on("PLAYER_REGEN_DISABLED", function()
    kampfSeit = jetzt()
    addsGemeldet = false
    ns.melde("KAMPF_AN")
    -- Mobs, die schon Nameplates hatten, als der Kampf begann.
    ns.Compat.After(2, addsPruefe)
    ns.Compat.After(6, addsPruefe)
end)

ns.on("PLAYER_REGEN_ENABLED", function()
    local dauer = (kampfSeit > 0) and (jetzt() - kampfSeit) or 0
    kampfSeit = 0
    -- Nameplate-Tokens werden vom Client wiederverwendet; eine Leiche im Dict ginge sonst
    -- als frischer Add durch.
    wipe(platten)
    addsGemeldet = false
    if tot() then return end
    if dauer >= KAMPF_AUS_MIN then ns.melde("KAMPF_AUS") end
end)

ns.on("NAME_PLATE_UNIT_ADDED", function(unit)
    if not unit then return end
    platten[unit] = true
    K.rareSichtung(unit)
    if imKampf() then addsPlanen(1) end
end)
ns.on("NAME_PLATE_UNIT_REMOVED", function(unit)
    if unit then platten[unit] = nil end
end)

-- ---------------------------------------------------------------- Ziel-Wissen
-- NPC-Typ-ID aus der GUID (Feld 6 bei Kreaturen: Creature-0-server-instanz-zoneUID-NPCID-spawnUID).
-- Spieler-GUIDs ("Player-...") fallen durch = nil.
local function npcIdVon(unit)
    local guid = UnitGUID and UnitGUID(unit)
    if not guid then return nil end
    local art, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if (art == "Creature" or art == "Vehicle") and id then return id end
    return nil
end

-- Seltene in Sicht (Ziel, Mouseover, Nameplate). Nie Spieler. Dedup je NPC-Typ liegt
-- in der Regie (npc-1800), der Schluessel ist die NPC-ID.
function K.rareSichtung(unit)
    if not (UnitExists and UnitExists(unit)) then return end
    if UnitIsPlayer and UnitIsPlayer(unit) then return end          -- Grenze B, als Erstes
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return end
    local klasse = UnitClassification and UnitClassification(unit) or ""
    if klasse ~= "rare" and klasse ~= "rareelite" then return end
    local id = npcIdVon(unit)
    local name = UnitName(unit)
    if not id or not name or name == "" then return end
    ns.melde("RARE", { name = name, key = id })
end

-- Gefaehrder VOR dem Kampf: boss (Level -1 / worldboss) und elite/rareelite -> GEFAHR_ELITE,
-- sonst Stufenabstand >= 3 -> GEFAHR_STUFEN. Session-Dedup je Name liegt in der Regie.
local function zielPruefe()
    -- W8 (A9): der Gefaehrder-Blick rechnet mit Stufen (ns.Compat.unitLevelLesbar). Meldet der
    -- Selbsttest (Core/Selbsttest.lua) die Flaeche "leben" als ausgefallen, sind die Einheitswerte
    -- dieses Clients nicht rechenbar - dann schweigt der Kampfsinn, statt bei jedem Zielwechsel
    -- ins Leere zu greifen. Ohne Selbsttest antwortet ST.ok() fail-safe mit true.
    if ns.Selbsttest and not ns.Selbsttest.ok("leben") then return end
    if not (UnitExists and UnitExists("target")) then return end
    if UnitIsPlayer and UnitIsPlayer("target") then return end       -- Grenze B, als Erstes
    if not (UnitCanAttack and UnitCanAttack("player", "target")) then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("target") then return end
    if tot() then return end
    local name = UnitName("target")
    if not name or name == "" then return end
    local klasse = UnitClassification and UnitClassification("target") or ""
    -- PORT (0.9.0): Secret Values. Auf Retail 12.x und Forever ist das LEVEL einer fremden
    -- Einheit in Kampf, Instanz, M+ und PvP ein "secret": kein Rechnen, kein Vergleichen.
    -- `ziellvl - eigenlvl >= 3` waere dort ein Lua-Fehler bei jedem Zielwechsel im Kampf.
    -- ns.Compat.unitLevelLesbar() gibt in dem Fall nil zurueck — dann entfaellt GEFAHR_STUFEN
    -- still. Name und Klassifikation (UnitName/UnitClassification) sind KEINE Kampfwerte und
    -- bleiben ueberall lesbar, deshalb bleibt GEFAHR_ELITE auf allen fuenf Clients.
    local ziellvl  = ns.Compat.unitLevelLesbar("target")
    local eigenlvl = ns.Compat.unitLevelLesbar("player") or 0
    if (ziellvl and ziellvl < 0) or klasse == "worldboss" or klasse == "elite" or klasse == "rareelite" then
        ns.melde("GEFAHR_ELITE", { name = name, key = name })
    elseif ziellvl and eigenlvl > 0 and ziellvl - eigenlvl >= STUFEN_ABSTAND then
        ns.melde("GEFAHR_STUFEN", { name = name, key = name })
    end
    K.rareSichtung("target")
end

ns.on("PLAYER_TARGET_CHANGED", zielPruefe)
ns.on("UPDATE_MOUSEOVER_UNIT", function() K.rareSichtung("mouseover") end)

-- ---------------------------------------------------------------- Ladebildschirm
ns.on("PLAYER_ENTERING_WORLD", function()
    wipe(platten)
    addsGemeldet = false
    addsGeplant = false
    kampfSeit = imKampf() and jetzt() or 0     -- mitten im Kampf geladen: Dauer ab jetzt
end)

function K.stand()
    local n = 0
    for _ in pairs(platten) do n = n + 1 end
    return kampfSeit, n, addsGemeldet
end
