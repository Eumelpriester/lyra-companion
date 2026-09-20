-- Sinne/Leben.lua — Lebens-Wacht: HP-Schwellen mit Hysterese, Sturz-Wacht, MaxHP-Nachfuehrung.
-- Ereignisse: HP50 (still), HP35, HP20, STURZ.
-- API (nur lesend): UnitHealth/UnitHealthMax("player"), UnitIsDeadOrGhost, UnitAffectingCombat, GetTime.
-- Events: UNIT_HEALTH/UNIT_MAXHEALTH (player), PLAYER_ENTERING_WORLD, PLAYER_ALIVE, PLAYER_UNGHOST.
-- Grenzen: Prozentwerte aus dem Client-Stand (kein Combat-Log); Sturz nur im Kampf (Fallschaden,
-- Sprung ins Wasser und Lade-Artefakte sind kein Gegner); beim Tod/Geist keine Meldung.
-- PORT (0.9.0): Diese Datei ist auf ALLEN fuenf Clients unveraendert lauffaehig, und das ist
-- kein Zufall — sie liest ausschliesslich "player". Blizzard laesst UnitHealth("player"),
-- UnitHealthMax("player") und UnitPowerMax("player") unter Secret Values ausdruecklich lesbar
-- (Secret Values betreffen FREMDE Einheiten in Kampf/Instanz/M+/PvP). Damit bleibt der Kern
-- des Addons — die Lebenswarnung, HP50/HP35/HP20/STURZ — auf Retail und Forever vollstaendig.
-- Der Weg ueber ns.Compat.unitHealthLesbar() ist hier bewusst NICHT gewaehlt: er kostet zwei
-- pcalls je UNIT_HEALTH-Ereignis, und fuer "player" kann er nichts abfangen, was es gibt.
-- Portiert aus LyraAuge lebenScan/sturzWacht (Katalog D, 0.9.13).
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local L = {}
ns.Sinne.Leben = L

-- Schwellen: EIN Marker je Unterschreitung; Re-Arm NUR ueber Heilung (Schwelle + 10 %).
-- Bewusst strenger als "1x je Kampf": wer chronisch tief steht, bekommt kein Dauer-Genoergel.
local SCHWELLEN = { { pct = 20, id = "HP20" }, { pct = 35, id = "HP35" }, { pct = 50, id = "HP50" } }
local RE_ARM = 10
local armed = { false, false, false }   -- erst nach der Basislinie scharf
local basisGesetzt = false

-- Sturz-Wacht: >= 30 % Verlust im 5-s-Fenster, nur im Kampf. Drossel (30 s) liegt in der Regie.
local STURZ_PCT, STURZ_FENSTER = 30, 5
local verlauf = {}                        -- { {zeit, pct}, ... }

L.pct = 100
L.maxhp = 0

local function jetzt() return GetTime() end

local function tot()
    return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false
end

local function prozent()
    local max = UnitHealthMax("player")
    if not max or max <= 0 then return nil end
    local cur = UnitHealth("player") or 0
    L.maxhp = max
    return math.floor(cur / max * 100 + 0.5)
end

-- Basislinie: Schwellen nach dem aktuellen Stand scharf stellen, NIE melden.
-- Wer tief einloggt (Geist, Rast nach Kampf), hoert erst nach echter Heilung wieder etwas.
local function basislinie()
    local pct = prozent()
    if not pct then return end
    basisGesetzt = true
    L.pct = pct
    for i, s in ipairs(SCHWELLEN) do
        armed[i] = pct >= s.pct
    end
    verlauf = {}
end

local function sturzWacht(pct)
    if not (UnitAffectingCombat and UnitAffectingCombat("player")) then
        -- Ausserhalb des Kampfs keine Historie mitschleppen: sonst gilt der
        -- Regenerations-Anstieg nach dem Kampf als Bezugswert fuer den naechsten.
        if #verlauf > 0 then verlauf = {} end
        return
    end
    local t = jetzt()
    while verlauf[1] and t - verlauf[1][1] > STURZ_FENSTER do
        table.remove(verlauf, 1)
    end
    local hoechster = pct
    for i = 1, #verlauf do
        if verlauf[i][2] > hoechster then hoechster = verlauf[i][2] end
    end
    verlauf[#verlauf + 1] = { t, pct }
    if hoechster - pct >= STURZ_PCT then
        verlauf = {}                      -- derselbe Sturz zaehlt nicht doppelt
        ns.melde("STURZ")
    end
end

local function lebenScan()
    if not basisGesetzt then basislinie(); return end
    if tot() then return end
    local pct = prozent()
    if not pct then return end
    L.pct = pct
    -- Lade-Artefakt: 0 HP ohne Tod ist kein Messwert.
    if pct <= 0 then return end
    local tiefste = nil
    for i, s in ipairs(SCHWELLEN) do
        if pct >= s.pct + RE_ARM then
            armed[i] = true
        elseif pct < s.pct and armed[i] then
            armed[i] = false
            if not tiefste then tiefste = s.id end   -- Liste ist aufsteigend: erste = tiefste
        end
    end
    -- Grosser Treffer quer durch mehrere Schwellen = EINE Meldung (die tiefste).
    if tiefste then
        ns.melde(tiefste)
        -- REVIEW2: derselbe Treffer loeste zusaetzlich STURZ aus (zwei Warnungen, zweite Stimme schnitt die erste ab).
        -- HP50 ist still, dort bleibt STURZ die eigentliche Warnung.
        if tiefste ~= "HP50" then verlauf = {} end
    end
    sturzWacht(pct)
end

ns.onUnit("UNIT_HEALTH", "player", function(unit)
    if unit and unit ~= "player" then return end
    lebenScan()
end)
ns.onUnit("UNIT_MAXHEALTH", "player", function(unit)
    if unit and unit ~= "player" then return end
    local max = UnitHealthMax("player")
    if max and max > 0 then L.maxhp = max end
end)

-- Ladebildschirm: Basislinie neu, kurz verzoegert (HP-Werte kommen nach dem Laden asynchron).
ns.on("PLAYER_ENTERING_WORLD", function()
    basisGesetzt = false
    verlauf = {}
    ns.Compat.After(1.5, function()
        if not basisGesetzt then basislinie() end
    end)
end)
-- Nach Wiederbelebung: alles neu (Geist-HP sind kein Messwert).
ns.on("PLAYER_ALIVE", function() ns.Compat.After(1, basislinie) end)
ns.on("PLAYER_UNGHOST", function() ns.Compat.After(1, basislinie) end)
ns.on("PLAYER_DEAD", function() verlauf = {} end)

function L.stand()
    return L.pct, L.maxhp, armed[1], armed[2], armed[3]
end
