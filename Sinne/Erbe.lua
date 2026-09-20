-- Sinne/Erbe.lua — Vorgaenger-Erbe (account-weit) und Sitzungs-Debrief. Doku: Sinne/EXTRA.md.
-- Ereignisse: ERBE_TOD (still), ERBE_VORGAENGER, ERBE_WORTE, DEBRIEF.
-- Daten: LyraGestaltDB.erbe = Liste (max 20) eigener gefallener Charaktere dieses Accounts:
--   { name, realm, level, zone, mapID, x, y, gegner, npcID, t, klasse, worte, vorgestellt }.
-- HARTE REGEL: Quelle ist NUR der eigene Charakter (UnitName("player")) bei PLAYER_DEAD. Nie Deathlog,
--   nie Daten anderer Spieler, nie ein Spielername als "gegner" (UnitIsPlayer-Sperre, Chronik-Bestiarium
--   enthaelt nur Creature-GUIDs).
-- API (nur lesend): UnitName/GetRealmName/UnitLevel/UnitClass/UnitGUID/UnitExists/UnitIsPlayer/
--   UnitPlayerControlled/UnitCanAttack, GetRealZoneText, C_Map.GetBestMapForUnit/GetPlayerMapPosition,
--   UnitIsDeadOrGhost, UnitAffectingCombat, GetTime, time, date. Nichts Fremdes.
-- Events: PLAYER_DEAD, PLAYER_ALIVE, PLAYER_UNGHOST, PLAYER_LOGIN, PLAYER_ENTERING_WORLD.
-- Hook: ns.Dialog.frage wird bei PLAYER_LOGIN gewrappt (Dialog.lua bleibt unangetastet): solange
--   ns.erbeWarteAufWorte gesetzt ist, nimmt /lyra <text> die letzten Worte (max 120 Zeichen).
local ADDON, ns = ...
local E = {}
ns.Erbe = E

local MAX_ERBE = 20
local WORTE_MAX = 120
local WORTE_FRIST = 60             -- s: so lange nimmt /lyra <text> die letzten Worte
local WORTE_BLASE = 15             -- s Standzeit der Frage
local VORGAENGER_LEVEL_MAX = 5
-- REVIEW4: feste Sekundenzahlen sind nur noch WUENSCHE ("nicht vor ..."); den echten Zeitpunkt
-- vergibt ns.Regie.loginSlot, damit sich die Login-Zeilen aus Chronik, Erbe und Start nicht
-- gegenseitig aus dem Plauder-Abstand draengen (siehe Kommentar in Core/Regie.lua).
local VORGAENGER_AB, WORTE_AB, DEBRIEF_AB = 20, 4, 60
local function loginSlot(ab)
    if ns.Regie and ns.Regie.loginSlot then return ns.Regie.loginSlot(ab) end
    return ab
end
local NACHHOL = 35
local GEGNER_FRIST = 30            -- s: Bestiarium-Tod / Beinahe zaehlt als Toeter nur so lange
local SITZUNG_FRISCH = 120         -- s: aelterer Sitzungsstart beim Login = fortgesetzte Sitzung (/reload)

local function jetzt() return GetTime() end
local function unix() return time() end
local function tot() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false end
local function imKampf() return UnitAffectingCombat and UnitAffectingCombat("player") or false end
local function echterTimer() return C_Timer and C_Timer.After and true or false end
local function rund3(v) return math.floor(v * 1000 + 0.5) / 1000 end

local function zoneJetzt()
    return (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
end

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

local function npcIdAus(guid)
    if type(guid) ~= "string" then return nil end
    return guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
end

-- Feindlicher NPC als Einheit? Grenze B: UnitIsPlayer als Erstes.
local function feindNpc(unit)
    if not (UnitExists and UnitExists(unit)) then return nil end
    if UnitIsPlayer and UnitIsPlayer(unit) then return nil end
    if UnitPlayerControlled and UnitPlayerControlled(unit) then return nil end
    if not (UnitCanAttack and UnitCanAttack("player", unit)) then return nil end
    local id = npcIdAus(UnitGUID and UnitGUID(unit))
    if not id then return nil end
    local name = UnitName and UnitName(unit)
    if not name or name == "" then return nil end
    return id, name
end

local function chronikDB()
    local c = LyraGestaltDB and LyraGestaltDB.chronik and ns.charKey and LyraGestaltDB.chronik[ns.charKey]
    return type(c) == "table" and c or nil
end

local function erbeListe()
    if not LyraGestaltDB then return nil end
    if type(LyraGestaltDB.erbe) ~= "table" then LyraGestaltDB.erbe = {} end
    return LyraGestaltDB.erbe
end
E.liste = erbeListe

local function erbeAktiv()
    if ns.Compat and ns.Compat.istHardcore and ns.Compat.istHardcore() then return true end
    return ns.Get("erbeImmer") and true or false
end

-- Melden mit EINEM Nachhol (Muster aus Chronik.lua): der Regie-Abstand frisst sonst Zeilen kurz nach LOGIN.
local function meldeNachhol(id, vars, verzug, gilt, danach)
    ns.Compat.After(verzug, function()
        if gilt and not gilt() then return end
        if ns.melde(id, vars) then if danach then danach() end return end
        if not echterTimer() then return end
        -- Nur nachlegen, wenn der Abstand der Grund war (Drossel/Gruppe/Still-Modus sind endgueltig).
        local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
        if not (d and d[2] == id and d[1] == "abstand") then return end
        local rest = (ns.Regie and ns.Regie.abstandRest and ns.Regie.abstandRest()) or 0
        ns.Compat.After(math.max(NACHHOL, math.min(rest + 1, 180)), function()
            if gilt and not gilt() then return end
            if ns.melde(id, vars) and danach then danach() end
        end)
    end)
end

-- ---------------------------------------------------------------- Tod: Eintrag + Frage nach letzten Worten
-- Toeter: 1) aktuelles Ziel (NPC), 2) Bestiarium-Eintrag mit frischem Tod (Chronik zaehlt tode++ vor uns),
-- 3) juengster Beinahe-Eintrag der Chronik. Nie ein Spieler.
local function gegnerErmitteln()
    local id, name = feindNpc("target")
    if id then return name, id end
    local c = chronikDB()
    if not c then return nil end
    local t = unix()
    local bestId, bestE = nil, nil
    for nid, e in pairs(c.bestiarium or {}) do
        if type(e) == "table" and (e.tode or 0) >= 1 and (e.t or 0) >= t - GEGNER_FRIST then
            if not bestE or (e.t or 0) > (bestE.t or 0) then bestId, bestE = nid, e end
        end
    end
    if bestE and bestE.name then return bestE.name, bestId end
    local b = c.beinahe and c.beinahe[#c.beinahe]
    if type(b) == "table" and b.gegner and (b.t or 0) >= t - 120 then return b.gegner, b.npcID end
    return nil
end

local todGemerkt = false
local worteBis = 0
local letzterEintrag = nil

local function worteFrage()
    local L = ns.L
    ns.erbeWarteAufWorte = true
    worteBis = jetzt() + WORTE_FRIST
    if ns.Blase and ns.Blase.zeige and not ns.Get("versteckt") then
        ns.Blase.zeige(L["Last words prompt"], WORTE_BLASE, "plauder")
    end
    ns.print(L["Last words prompt"])
    ns.Compat.After(WORTE_FRIST, function()
        if jetzt() >= worteBis then ns.erbeWarteAufWorte = nil end
    end)
end

local function todEintragen()
    local liste = erbeListe()
    if not liste then return end
    local name = UnitName and UnitName("player") or nil      -- EIGENER Charakter
    if not name or name == "" then return end
    local _, klasse = nil, nil
    if UnitClass then _, klasse = UnitClass("player") end
    local e = {
        name = name,
        realm = (GetRealmName and GetRealmName()) or "?",
        level = (UnitLevel and UnitLevel("player")) or 0,
        zone = zoneJetzt(),
        t = unix(),
        klasse = klasse,
        vorgestellt = false,
    }
    local karte, x, y = position()
    if karte and x and y then e.mapID, e.x, e.y = karte, rund3(x), rund3(y) end
    local gegner, npcID = gegnerErmitteln()
    if gegner then e.gegner = gegner; e.npcID = npcID end
    liste[#liste + 1] = e
    while #liste > MAX_ERBE do table.remove(liste, 1) end
    letzterEintrag = e
    ns.melde("ERBE_TOD")
    worteFrage()
end

ns.on("PLAYER_DEAD", function()
    if todGemerkt then return end
    todGemerkt = true
    if not erbeAktiv() then return end
    -- Chronik (PLAYER_DEAD davor registriert) hat tode++ gesetzt; kurz warten, damit auch spaete Handler durch sind.
    ns.Compat.After(0.5, function() pcall(todEintragen) end)
end)
ns.on("PLAYER_ALIVE", function() if not tot() then todGemerkt = false end end)
ns.on("PLAYER_UNGHOST", function() todGemerkt = false end)

-- Letzte Worte speichern (max 120 Zeichen). Rueckgabe true, wenn angenommen.
function E.worte(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return false end
    local e = letzterEintrag
    if not e then
        local liste = erbeListe()
        e = liste and liste[#liste]
    end
    if not e then return false end
    if #text > WORTE_MAX then
        local n = WORTE_MAX
        -- UTF-8: nicht mitten in einer Mehrbyte-Folge schneiden (Folgebytes sind 0x80-0xBF)
        while n > 1 and text:byte(n + 1) and text:byte(n + 1) >= 128 and text:byte(n + 1) < 192 do n = n - 1 end
        text = text:sub(1, n)
    end
    e.worte = text
    ns.erbeWarteAufWorte = nil
    worteBis = 0
    if ns.Blase and ns.Blase.zeige and not ns.Get("versteckt") then
        ns.Blase.zeige(ns.L["Last words saved"], 8, "plauder")
    end
    ns.print(ns.L["Last words saved"])
    if ns.Gestalt and ns.Gestalt.miene then ns.Gestalt.miene("touched", 10) end
    return true
end

-- Wrapper um ns.Dialog.frage (Dialog.lua bleibt unveraendert): waehrend der Frist nimmt /lyra <text> die Worte.
local gewrappt = false
local function dialogWrappen()
    if gewrappt or not (ns.Dialog and type(ns.Dialog.frage) == "function") then return end
    gewrappt = true
    local original = ns.Dialog.frage
    ns.Dialog.frage = function(roh, ...)
        if ns.erbeWarteAufWorte and jetzt() < worteBis then
            local text = tostring(roh or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if text ~= "" then return E.worte(text) end
        end
        return original(roh, ...)
    end
end

-- ---------------------------------------------------------------- Login: Vorgaenger vorstellen, Debrief
-- Juengster Erbe-Eintrag eines ANDEREN Charakters, der noch nicht vorgestellt wurde.
local function vorgaengerFinden()
    local liste = erbeListe()
    if not liste then return nil end
    -- REVIEW3: Name-Realm statt nur Name (gleicher Name auf anderem Realm ist ein anderer Charakter)
    local eigen = ns.charKey or ((UnitName and UnitName("player") or "") .. "-" .. ((GetRealmName and GetRealmName()) or "?"))
    for i = #liste, 1, -1 do
        local e = liste[i]
        if type(e) == "table" and e.name and (tostring(e.name) .. "-" .. tostring(e.realm or "?")) ~= eigen and not e.vorgestellt then return e end
    end
    return nil
end

local function vorgaengerPlanen()
    local lvl = (UnitLevel and UnitLevel("player")) or 0
    if lvl > VORGAENGER_LEVEL_MAX then return end
    local e = vorgaengerFinden()
    if not e then return end
    local vars = { name = e.name, level = e.level or 0, zone = (e.zone and e.zone ~= "") and e.zone or "?" }
    -- REVIEW4: Beide Slots werden JETZT geholt, nicht erst nach dem Erfolg der ersten Zeile - sonst
    -- draengt sich DEBRIEF (das seinen Slot gleich danach holt) zwischen Vorgaenger und letzte Worte.
    -- Ob es letzte Worte gibt, steht hier schon fest.
    local verzugV = loginSlot(VORGAENGER_AB)
    local hatWorte = e.worte and e.worte ~= ""
    local verzugW = hatWorte and loginSlot(WORTE_AB) or nil
    meldeNachhol("ERBE_VORGAENGER", vars, verzugV, function() return not tot() end, function()
        e.vorgestellt = true
        if hatWorte then
            -- verzugW ist ab dem Slot-Zeitpunkt gerechnet; der Rest ab jetzt ist die Differenz.
            local rest = math.max(1, verzugW - verzugV)
            meldeNachhol("ERBE_WORTE", { name = e.name, worte = e.worte }, rest, function() return not tot() end)
        end
    end)
end

-- Debrief der letzten Sitzung: sitzungen[n] ist die eben von Chronik begonnene, sitzungen[n-1] die letzte.
local function debriefPlanen()
    local c = chronikDB()
    local s = c and c.sitzungen
    if type(s) ~= "table" or #s < 2 then return end
    local aktuell, letzte = s[#s], s[#s - 1]
    if type(aktuell) ~= "table" or type(letzte) ~= "table" then return end
    local t = unix()
    if (aktuell.start or 0) < t - SITZUNG_FRISCH then return end    -- fortgesetzte Sitzung (/reload): kein Debrief
    local start, ende = letzte.start or 0, letzte.ende or letzte.start or 0
    if start <= 0 or ende <= start then return end
    local stunden = (ende - start) / 3600
    -- Level-Start: Ende der vorletzten Sitzung (= Stand beim Start der letzten); sonst der gespeicherte Wert.
    local vorletzte = s[#s - 2]
    local von = (type(vorletzte) == "table" and vorletzte.level) or letzte.level or 0
    local bis = letzte.level or (UnitLevel and UnitLevel("player")) or von
    if von > bis then von = bis end
    local beinahe = 0
    for _, b in ipairs(c.beinahe or {}) do
        if type(b) == "table" and (b.t or 0) >= start and (b.t or 0) <= ende then beinahe = beinahe + 1 end
    end
    local vars = { stunden = string.format("%.1f", stunden), von = von, bis = bis, beinahe = beinahe }
    meldeNachhol("DEBRIEF", vars, loginSlot(DEBRIEF_AB), function() return not tot() and not imKampf() end)
end

local ersterPEW = true
ns.on("PLAYER_LOGIN", function()
    dialogWrappen()
    erbeListe()
end)
ns.on("PLAYER_ENTERING_WORLD", function()
    if not ersterPEW then return end
    ersterPEW = false
    pcall(vorgaengerPlanen)
    pcall(debriefPlanen)
end)

-- ---------------------------------------------------------------- Export (/lyra erbe)
function E.status()
    local out = {}
    local liste = erbeListe() or {}
    local L = ns.L
    if #liste == 0 then out[1] = L["Legacy empty"]; return out end
    out[1] = L["Legacy list"]
    for i = #liste, 1, -1 do
        local e = liste[i]
        if type(e) == "table" then
            local zeile = ("  %s (%d) - %s - %s"):format(tostring(e.name or "?"), tonumber(e.level) or 0,
                tostring((e.zone and e.zone ~= "") and e.zone or "?"), date("%d.%m.%Y %H:%M", e.t or 0))
            if e.gegner then zeile = zeile .. " - " .. tostring(e.gegner) end
            out[#out + 1] = zeile
            if e.worte and e.worte ~= "" then out[#out + 1] = "    \"" .. e.worte .. "\"" end
        end
    end
    return out
end

function E.stand()
    return letzterEintrag, ns.erbeWarteAufWorte, worteBis, gewrappt
end
