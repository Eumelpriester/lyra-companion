-- Sinne/Profil.lua — Spielstil-Profil (Welle 2): misst je Kampf Dauer und Lebens-Tiefstand, zaehlt
-- Beinahe-Tode, Rast, Fehlalarme (HP35 ohne Folgeschaden) und leitet einen Stil ab (vorsichtig/normal/
-- draufgaenger). Erklaerbar per /lyra profil, abschaltbar (Einstellung "profil"). Nur eigene Werte.
-- API: PLAYER_REGEN_DISABLED/ENABLED, UNIT_HEALTH (player), PLAYER_UPDATE_RESTING, GetTime.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local P = {}
ns.Sinne.Profil = P
ns.Profil = P

local function speicher()
    local c = LyraGestaltDB and LyraGestaltDB.chronik and LyraGestaltDB.chronik[ns.charKey]
    if not c then return nil end
    c.profil = c.profil or { v = 1, kaempfe = 0, dauerSumme = 0, unter50 = 0, unter35 = 0, unter20 = 0, rast = 0, fehlalarm = 0, hp35 = 0 }
    return c.profil
end
local function an() return ns.Get("profil") ~= false end

local kampfStart, minPct = nil, 100
local hp35Zeit = nil

local function pct()
    local h, m = UnitHealth("player"), UnitHealthMax("player")
    if not h or not m or m == 0 then return 100 end
    return math.floor(h / m * 100 + 0.5)
end

ns.on("PLAYER_REGEN_DISABLED", function()
    if not an() then return end
    kampfStart, minPct = GetTime(), pct()
end)
ns.on("PLAYER_REGEN_ENABLED", function()
    if not an() or not kampfStart then return end
    local sp = speicher(); if not sp then kampfStart = nil; return end
    local dauer = GetTime() - kampfStart
    kampfStart = nil
    if dauer < 3 then return end
    sp.kaempfe = sp.kaempfe + 1
    sp.dauerSumme = sp.dauerSumme + dauer
    if minPct < 50 then sp.unter50 = sp.unter50 + 1 end
    if minPct < 35 then sp.unter35 = sp.unter35 + 1 end
    if minPct < 20 then sp.unter20 = sp.unter20 + 1 end
    if hp35Zeit and minPct >= 20 and pct() >= 50 then
        sp.fehlalarm = sp.fehlalarm + 1
        if sp.hp35 >= 8 and sp.fehlalarm / math.max(1, sp.hp35) > 0.7 and not P.fehlalarmGesagt then
            P.fehlalarmGesagt = true
            ns.Compat.After(30, function() ns.melde("PROFIL_FEHLALARM") end)
        end
    end
    hp35Zeit = nil
end)
ns.onUnit("UNIT_HEALTH", "player", function(unit)
    if unit ~= "player" or not kampfStart then return end
    local p = pct()
    if p < minPct then minPct = p end
end)
ns.on("PLAYER_UPDATE_RESTING", function()
    if not an() then return end
    if IsResting and IsResting() then local sp = speicher(); if sp then sp.rast = sp.rast + 1 end end
end)
ns.on("PLAYER_LOGIN", function()
    if ns.nachAusgabe then
        ns.nachAusgabe(function(id)
            if id == "HP35" then hp35Zeit = GetTime(); local sp = speicher(); if sp then sp.hp35 = sp.hp35 + 1 end end
        end)
    end
    -- Stil als Tag fuer den wenn-Filter (Wrapper um ns.Stimmung.tags, wenn vorhanden)
    if ns.Stimmung and ns.Stimmung.tags and not P.tagsGewrappt then
        P.tagsGewrappt = true
        local orig = ns.Stimmung.tags
        ns.Stimmung.tags = function(...)
            local t = orig(...) or {}
            t.stil = P.stil()
            return t
        end
    end
end)

-- Risiko 0..1 = Anteil Kaempfe unter 35 %; Stil daraus
function P.risiko()
    local sp = speicher(); if not sp or sp.kaempfe < 5 then return nil end
    return sp.unter35 / sp.kaempfe
end
function P.stil()
    local r = P.risiko()
    if r == nil then return "unbekannt" end
    if r < 0.1 then return "vorsichtig" elseif r > 0.3 then return "draufgaenger" end
    return "normal"
end
-- Warnfaktor fuer kuenftige Schwellen-Anpassung (1.0 = Standard; Draufgaenger frueher, Vorsichtige spaeter)
function P.warnFaktor()
    local s = P.stil()
    if s == "draufgaenger" then return 1.15 elseif s == "vorsichtig" then return 0.9 end
    return 1.0
end
function P.status()
    local sp = speicher(); local de = ns.sprache() == "de"
    if not sp or sp.kaempfe == 0 then return { de and "Noch kein Profil. Kaempfe erst ein paar Runden." or "No profile yet. Fight a few rounds first." } end
    local avg = sp.dauerSumme / sp.kaempfe
    local stil = P.stil()
    local namen = { vorsichtig = de and "vorsichtig" or "careful", normal = "normal", draufgaenger = de and "Draufgaenger" or "daredevil", unbekannt = de and "noch offen" or "open" }
    return {
        (de and "Stil: %s. %d Kaempfe, im Schnitt %.0f s." or "Style: %s. %d fights, %.0f s on average."):format(namen[stil] or stil, sp.kaempfe, avg),
        (de and "Unter 50 %%: %d, unter 35 %%: %d, unter 20 %%: %d. Rast: %d." or "Below 50%%: %d, below 35%%: %d, below 20%%: %d. Rests: %d."):format(sp.unter50, sp.unter35, sp.unter20, sp.rast),
        (de and "Warnungen bei 35 %% ohne Folgen: %d von %d." or "35%% warnings without consequences: %d of %d."):format(sp.fehlalarm, sp.hp35),
    }
end
function P.zusammenfassung() return table.concat(P.status(), " ") end
ns.on("PLAYER_LOGIN", function()
    if not (ns.Dialog and type(ns.Dialog.aktionen) == "table") then return end
    ns.Dialog.aktionen.w2_profil = function() return "w2_profil", { profil = P.zusammenfassung() } end
end)
