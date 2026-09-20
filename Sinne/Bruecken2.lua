-- Sinne/Bruecken2.lua — weitere Addon-Bruecken (Welle 2): WeakAuras (Lyra als Signalquelle via
-- WeakAuras.ScanEvents), Pawn (Beute-Upgrade), Details (eigener Schaden je Kampf, Rekord).
-- Alles hinter Existenzpruefung + pcall; ohne diese Addons passiert nichts.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local B2 = {}
ns.Sinne.Bruecken2 = B2
ns.Bruecken2 = B2

-- WeakAuras: jedes Lyra-Ereignis als Custom-Event "LYRA_GESTALT" (id, klasse, stufe)
ns.on("PLAYER_LOGIN", function()
    if ns.nachAusgabe then
        ns.nachAusgabe(function(id, e)
            if WeakAuras and WeakAuras.ScanEvents then
                pcall(WeakAuras.ScanEvents, "LYRA_GESTALT", id, e and e.klasse, e and e.stufe)
            end
        end)
    end
end)

-- Pawn: eigene Beute pruefen (LOOT_ITEM_SELF), nur Upgrades melden
local function istUpgrade(link)
    if not (PawnGetItemData and PawnIsItemAnUpgrade) then return nil end
    local ok, item = pcall(PawnGetItemData, link)
    if not ok or not item then return nil end
    local ok2, up = pcall(PawnIsItemAnUpgrade, item)
    if not ok2 then return nil end
    return up and true or false
end
ns.on("CHAT_MSG_LOOT", function(msg)
    if not (PawnGetItemData and msg) then return end
    local self1 = LOOT_ITEM_SELF and LOOT_ITEM_SELF:gsub("%%s", ""):gsub("%.$", "") or "You receive loot"
    if not msg:find(self1, 1, true) then return end
    local link = msg:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    if not link then return end
    local name = link:match("%[(.-)%]") or "?"
    ns.Compat.After(1, function()
        if istUpgrade(link) then ns.melde("LOOT_UPGRADE", { name = name, key = name }) end
    end)
end)

-- Details: eigener Schaden je Kampf, persoenlicher Rekord (DPS ueber >= 20 s Kampf)
-- WELLE3: Seit 0.8.0 gehoert die Details-Bruecke ganz Sinne/Details.lua - dort mit Schnitt,
-- erlittenem Schaden, Unterbrechungen, Schalter und /lyra details. Dieser Block hier bleibt nur
-- als Rueckfall stehen (falls die neue Datei einmal fehlt) und tritt zurueck, sobald sie da ist.
-- Ohne diese Wache haetten beide Dateien KAMPF_REKORD gemeldet - zwei Zeilen zur selben Sache.
local kampfStart
ns.on("PLAYER_REGEN_DISABLED", function() kampfStart = GetTime() end)
ns.on("PLAYER_REGEN_ENABLED", function()
    if ns.DetailsSinn then kampfStart = nil; return end
    if not kampfStart or not (Details and Details.GetCurrentCombat) then kampfStart = nil; return end
    local dauer = GetTime() - kampfStart
    kampfStart = nil
    if dauer < 20 then return end
    ns.Compat.After(2, function()
        local ok, combat = pcall(Details.GetCurrentCombat, Details)
        if not ok or not combat or not combat.GetActor then return end
        local ok2, actor = pcall(combat.GetActor, combat, DETAILS_ATTRIBUTE_DAMAGE or 1, UnitName("player"))
        if not ok2 or not actor or not actor.total then return end
        local dps = actor.total / dauer
        local c = LyraGestaltDB and LyraGestaltDB.chronik and LyraGestaltDB.chronik[ns.charKey]
        if not c then return end
        c.rekordDps = c.rekordDps or 0
        if dps > c.rekordDps * 1.1 and dps > 5 then
            c.rekordDps = dps
            -- REVIEW6B: zwei Sekunden nach dem Kampf steht KAMPF_AUS schon in der Blase (Sinne/Kampf.lua
            -- haengt am selben PLAYER_REGEN_ENABLED und ist in der TOC vorher dran). Der Rekord fiel
            -- damit praktisch immer am Plauder-Abstand heraus - im Harness reproduziert, Drop-Grund
            -- "abstand". Jetzt wartet er den Rest des Abstands ab, wie es die Chronik beim Nachhol tut.
            local verzug = 1
            if ns.Regie and ns.Regie.abstandRest then
                local ok3, rest = pcall(ns.Regie.abstandRest)
                if ok3 and type(rest) == "number" then verzug = rest + 2 end
            end
            ns.Compat.After(math.max(1, verzug), function()
                ns.melde("KAMPF_REKORD", { dps = math.floor(dps + 0.5) })
            end)
        end
    end)
end)

-- REVIEW6B: wird jetzt aus /lyra status gerufen (UI/Slash.lua); das unbenutzte "de" ist raus.
function B2.status()
    return {
        ("WeakAuras: %s · Pawn: %s · Details: %s"):format(
            WeakAuras and "ok" or "-", PawnGetItemData and "ok" or "-", Details and "ok" or "-"),
    }
end
