-- Sinne/Alltag.lua — Taschen, Ruestung, Heiltrank, Buffs, Beute, Handwerk, Quest, Stufe,
--   Gruppe, Tod, Leerlauf.
-- Ereignisse: BAGS, DURA, TRANK, BUFF_WEG, BUFF_BALD (still), LOOT, SKILL, QUEST_AN/QUEST_AB (still),
--   LEVELUP, GRUPPE (still), GEFALLEN (still), LEERLAUF.
-- API (nur lesend): ns.Compat.Container (C_Container/Fallback), GetInventoryItemDurability,
--   ns.Compat.auraByIndex, GetItemInfo, IsInGroup/IsInRaid, UnitIsAFK, UnitOnTaxi,
--   UnitAffectingCombat, UnitIsDeadOrGhost, GetTime; globale Format-Strings LOOT_ITEM_SELF,
--   LOOT_ITEM_SELF_MULTIPLE, SKILL_RANK_UP (lokalisierungssicher).
-- Events: BAG_UPDATE_DELAYED, UPDATE_INVENTORY_DURABILITY, UNIT_AURA (player), CHAT_MSG_LOOT,
--   CHAT_MSG_SKILL, QUEST_ACCEPTED, QUEST_TURNED_IN, PLAYER_LEVEL_UP, GROUP_ROSTER_UPDATE,
--   PLAYER_DEAD, PLAYER_ALIVE/UNGHOST, PLAYER_REGEN_ENABLED, PLAYER_ENTERING_WORLD
--   + billige Aktivitaetsmarken (Ziel, Bewegung, Zauber, Fenster) fuer den Leerlauf.
-- Takt: Scans debounced 2 s (Bag/Dura/Buff); ein 15-s-Ticker (Buff-Restzeit, nur ausser Kampf),
--   ein 60-s-Ticker (Leerlauf). Kein OnUpdate.
-- Grenzen: LOOT/SKILL lesen NUR eigene Systemzeilen ("You receive loot", "Your skill in"),
--   nie Chat anderer; GRUPPE traegt keinen Namen und keine Groesse; Buff-Liste kuratiert
--   (SpellIDs + Namen enUS/deDE); waehrend eines Ladebildschirms sind Taschen und Auren
--   nicht lesbar -> unbekannt ist kein Messwert, nie beim ersten Wert melden.
-- Portiert aus LyraAuge bagScan/duraScan/trankZaehlen/buffScan/buffBaldScan/lootZeile/
--   skillZeile/questAn/questAb/gruppeMarker/todMarker (Katalog D/E, 0.9.13, 0.9.17).
-- PORT (0.9.0): Diese Datei war schon ueber ns.Compat gebaut und laeuft darum auf allen fuenf
--   Clients ohne Umbau:
--   * Taschen ueber ns.Compat.Container. Auf Retail/Forever ist C_Container der EINZIGE Weg
--     (das globale GetContainerItemInfo ist seit 10.0.2 weg); Era/TBC/MoP haben C_Container
--     ebenfalls (Era seit 1.14.3). ns.Compat.F.container sagt, welcher Weg gezogen hat.
--   * Auren ueber ns.Compat.auraByIndex. Auf Retail/Forever ist UnitAura entfernt (11.0.2),
--     C_UnitAuras ist da; Era hat C_UnitAuras seit 1.15.1. Gelesen werden AUSSCHLIESSLICH
--     Auren des Spielers ("player", "HELPFUL") — die sind nicht secret, im Gegensatz zu Auren
--     fremder Einheiten in Kampf/Instanz.
--   * LOOT/SKILL lesen lokalisierte Format-Strings (LOOT_ITEM_SELF, SKILL_RANK_UP). Die gibt
--     es auf allen Clients; fehlt einer, faellt der Sinn still weg.
--   * QUEST_ACCEPTED: der Handler hier liest KEINE Argumente ("etwas angenommen" genuegt), also
--     ist ihm die Signatur-Aenderung auf Mainline (nur questID statt index+questID) egal.
--   * Munition/Reagenzien-Themen stehen in Sinne/Extra.lua, nicht hier.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local A = {}
ns.Sinne.Alltag = A

local BAGS_SCHWELLE, BAGS_ENTWARN = 4, 6      -- freie Plaetze
local DURA_SCHWELLE, DURA_ENTWARN = 20, 30    -- Prozent
local BUFF_GNADE = 10                         -- s Toleranz Server-Drift + Scan-Takt
local BUFF_BALD_REST = 60                     -- s Restzeit
local BUFF_BALD_MINDAUER = 300                -- s Gesamtdauer (Kurz-Procs fallen durch)
local LEERLAUF_MIN = 600                      -- s ohne Aktivitaet und ohne Plauder
local LOOT_MIN_QUALITAET = 3                  -- blau

local function jetzt() return GetTime() end
local function tot() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false end
local function imKampf() return UnitAffectingCombat and UnitAffectingCombat("player") or false end
local function aufTaxi() return UnitOnTaxi and UnitOnTaxi("player") or false end

local ladeBis = 0                             -- eigene Lade-Karenz (Auren/Taschen rehydrieren spaet)
local function laedt() return jetzt() < ladeBis end

-- Kuratierte Heiltrank-Kette (Era-Item-IDs, Minor bis Major): "letzter Heiltrank weg"
-- soll genau das heissen — kein Verband, kein Heilstein.
local TRANK_IDS = {
    [118] = true, [858] = true, [929] = true,
    [1710] = true, [3928] = true, [13446] = true,
}

-- Kuratierte Buffs: SpellIDs aller Classic-Raenge + Namen (enUS/deDE) als Rueckfall
-- fuer Proviant, dessen IDs je Speise verschieden sind.
local BUFF_IDS = {
    -- Arcane Intellect / Brilliance
    [1459] = true, [1460] = true, [1461] = true, [10156] = true, [10157] = true, [23028] = true,
    -- Power Word: Fortitude / Prayer of Fortitude
    [1243] = true, [1244] = true, [1245] = true, [2791] = true, [10937] = true, [10938] = true,
    [21562] = true, [21564] = true,
    -- Mark of the Wild / Gift of the Wild
    [1126] = true, [5232] = true, [6756] = true, [5234] = true, [8907] = true, [9884] = true,
    [9885] = true, [21849] = true, [21850] = true,
    -- Blessing of Kings / Greater
    [20217] = true, [25898] = true,
    -- Blessing of Might / Greater
    [19740] = true, [19834] = true, [19835] = true, [19836] = true, [19837] = true, [19838] = true,
    [25291] = true, [25782] = true, [25916] = true,
    -- Blessing of Wisdom / Greater
    [19742] = true, [19850] = true, [19852] = true, [19853] = true, [19854] = true, [25290] = true,
    [25894] = true, [25918] = true,
    -- Divine Spirit / Prayer of Spirit
    [14752] = true, [14818] = true, [14819] = true, [27841] = true, [27681] = true,
    -- Battle Shout
    [6673] = true, [5242] = true, [6192] = true, [11549] = true, [11550] = true, [11551] = true,
    [25289] = true,
}
local BUFF_NAMEN = {
    ["Well Fed"] = true, ["Wohlgenaehrt"] = true, ["Wohlgenährt"] = true,
    ["Arcane Intellect"] = true, ["Arkane Intelligenz"] = true,
    ["Power Word: Fortitude"] = true, ["Machtwort: Seelenstärke"] = true,
    ["Mark of the Wild"] = true, ["Mal der Wildnis"] = true,
    ["Blessing of Kings"] = true, ["Segen der Könige"] = true,
    ["Blessing of Might"] = true, ["Segen der Macht"] = true,
    ["Blessing of Wisdom"] = true, ["Segen der Weisheit"] = true,
    ["Divine Spirit"] = true, ["Göttlicher Willen"] = true,
    ["Battle Shout"] = true, ["Schlachtruf"] = true,
}
local function buffKuratiert(aura)
    if not aura then return false end
    if aura.spellId and BUFF_IDS[aura.spellId] then return true end
    if aura.name and BUFF_NAMEN[aura.name] then return true end
    return false
end

-- ---------------------------------------------------------------- Taschen / Trank
local C = ns.Compat.Container
local bagQueued = false
local bagsArmed = nil            -- nil = Basislinie fehlt
local letzterTrank = -1          -- -1 = unbekannt

-- Waehrend eines Ladebildschirms liefert GetContainerNumSlots fuer JEDE Tasche 0 — der
-- Rucksack hat aber immer Plaetze. 0 heisst hier "weiss ich gerade nicht".
local function taschenLesbar()
    if not (C and C.GetContainerNumSlots) then return false end
    for bag = 0, 4 do
        local ok, n = pcall(C.GetContainerNumSlots, bag)
        if ok and (tonumber(n) or 0) > 0 then return true end
    end
    return false
end

local function freieTaschenplaetze()
    local frei = 0
    for bag = 0, 4 do
        local ok, n = pcall(C.GetContainerNumFreeSlots, bag)
        if ok and tonumber(n) then frei = frei + n end
    end
    return frei
end

local function trankZaehlen()
    local n = 0
    if not C.GetContainerItemInfo then return n end
    for bag = 0, 4 do
        local ok, slots = pcall(C.GetContainerNumSlots, bag)
        for slot = 1, (ok and tonumber(slots) or 0) do
            local ok2, info = pcall(C.GetContainerItemInfo, bag, slot)
            if ok2 and info and info.itemID and TRANK_IDS[info.itemID] then
                n = n + (info.stackCount or 1)
            end
        end
    end
    return n
end

local function bagScan()
    bagQueued = false
    if not taschenLesbar() then
        -- Unbekannt ist kein Messwert: nichts melden, nichts merken, spaeter noch einmal.
        if C_Timer and C_Timer.After and not bagQueued then
            bagQueued = true
            ns.Compat.After(3, bagScan)
        end
        return
    end
    local frei = freieTaschenplaetze()
    if bagsArmed == nil then
        bagsArmed = frei > BAGS_SCHWELLE           -- Basislinie: still
    elseif frei > BAGS_ENTWARN then
        bagsArmed = true
    elseif frei <= BAGS_SCHWELLE and bagsArmed then
        bagsArmed = false
        ns.melde("BAGS")
    end
    -- Trank-Flanke im selben Scan: nur der Weg von >0 auf 0 ist eine Nachricht.
    local traenke = trankZaehlen()
    if letzterTrank > 0 and traenke == 0 and not tot() then
        ns.melde("TRANK")
    end
    letzterTrank = traenke
end

local function planeBagScan()
    if bagQueued then return end
    bagQueued = true
    ns.Compat.After(2, function()
        local ok, err = pcall(bagScan)
        if not ok then bagQueued = false; ns.debug("Alltag bags: " .. tostring(err)) end
    end)
end

ns.on("BAG_UPDATE_DELAYED", planeBagScan)

-- ---------------------------------------------------------------- Ruestung
local duraQueued = false
local duraArmed = nil            -- nil = Basislinie fehlt

local function minHaltbarkeit()
    if not GetInventoryItemDurability then return -1 end
    local minPct = -1
    for slot = 1, 18 do
        local ok, cur, max = pcall(GetInventoryItemDurability, slot)
        if ok and cur and max and max > 0 then
            local pct = math.floor(cur / max * 100)
            if minPct < 0 or pct < minPct then minPct = pct end
        end
    end
    return minPct
end

local function duraScan()
    duraQueued = false
    local pct = minHaltbarkeit()
    if pct < 0 then return end                     -- nichts Getragenes mit Haltbarkeit
    if duraArmed == nil then
        duraArmed = pct >= DURA_SCHWELLE           -- Basislinie: still
    elseif pct > DURA_ENTWARN then
        duraArmed = true
    elseif pct < DURA_SCHWELLE and duraArmed then
        duraArmed = false
        if not tot() then ns.melde("DURA") end
    end
end

local function planeDuraScan()
    if duraQueued then return end
    duraQueued = true
    ns.Compat.After(2, function()
        local ok, err = pcall(duraScan)
        if not ok then duraQueued = false; ns.debug("Alltag dura: " .. tostring(err)) end
    end)
end

ns.on("UPDATE_INVENTORY_DURABILITY", planeDuraScan)

-- ---------------------------------------------------------------- Buffs
-- Abgang: nicht die ANWESENHEIT entscheidet, sondern die RESTZEIT. Fehlt die Aura, obwohl
-- die zuletzt gesehene Ablaufzeit noch in der Zukunft liegt, ist das ein Lade-Artefakt
-- (Port, Ladebildschirm) -> schweigen, Merkstand halten. Dispels/Abbrueche melden wir damit
-- bewusst nicht als "verpufft". Buffs ohne Ablaufzeit (exp == 0) gelten nur ausserhalb der
-- Lade-Karenz als weg.
local buffQueued = false
local buffDa = {}                -- name -> zuletzt gesehene expirationTime (0 = unbekannt)
local baldGemeldet = {}          -- name@exp -> true (je Buff-Instanz)

local function aurenLesen()
    local sicht = {}
    for i = 1, 64 do
        local ok, aura = pcall(ns.Compat.auraByIndex, "player", i, "HELPFUL")
        if not ok or not aura then break end
        if buffKuratiert(aura) and aura.name then
            local exp = aura.expirationTime
            sicht[aura.name] = { exp = (exp and exp > 0) and exp or 0, dauer = aura.duration or 0 }
        end
    end
    return sicht
end

local function buffScan()
    buffQueued = false
    if tot() then
        for k in pairs(buffDa) do buffDa[k] = nil end     -- Tod wischt den Merkstand
        return
    end
    if imKampf() or laedt() then return end
    local t = jetzt()
    local sicht = aurenLesen()
    for name, s in pairs(sicht) do buffDa[name] = s.exp end
    for name, exp in pairs(buffDa) do
        if not sicht[name] then
            local rest = (exp > 0) and (exp - t) or 0
            if rest <= BUFF_GNADE then
                buffDa[name] = nil
                ns.melde("BUFF_WEG", { buff = name, key = name })
            end
        end
    end
end

local function planeBuffScan()
    if buffQueued then return end
    buffQueued = true
    ns.Compat.After(2, function()
        local ok, err = pcall(buffScan)
        if not ok then buffQueued = false; ns.debug("Alltag buff: " .. tostring(err)) end
    end)
end

-- Vor-Auslauf: UNIT_AURA feuert nicht mit der ablaufenden Zeit -> 15-s-Ticker, nur ausser Kampf.
local function buffBaldScan()
    if tot() or imKampf() or laedt() then return end
    local t = jetzt()
    local sicht = aurenLesen()
    for name, s in pairs(sicht) do
        if s.exp > 0 and s.dauer >= BUFF_BALD_MINDAUER then
            local rest = s.exp - t
            local k = name .. "@" .. math.floor(s.exp)
            if rest > 0 and rest < BUFF_BALD_REST and not baldGemeldet[k] then
                baldGemeldet[k] = true
                ns.melde("BUFF_BALD", { buff = name, key = name })
            end
        end
    end
end

ns.onUnit("UNIT_AURA", "player", function(unit)
    if unit and unit ~= "player" then return end
    planeBuffScan()
end)
ns.on("PLAYER_REGEN_ENABLED", planeBuffScan)      -- haengige Abgaenge aus dem Kampf

-- ---------------------------------------------------------------- Beute / Handwerk
-- Lua-Muster aus einem globalen Format-String (lokalisierungssicher): %s -> (.+), %d -> (%d+),
-- auch positional (%1$s). Alles andere wird escaped.
local function musterAus(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local p = fmt:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
    p = p:gsub("%%%%%d+%%%$s", "(.+)"):gsub("%%%%%d+%%%$d", "(%%d+)")
    p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
    return "^" .. p
end

local LOOT_MUSTER = {}
for _, g in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF" }) do
    local m = musterAus(_G[g])
    if m then LOOT_MUSTER[#LOOT_MUSTER + 1] = m end
end
if #LOOT_MUSTER == 0 then LOOT_MUSTER[1] = "^You receive loot: (.+)" end
local SKILL_MUSTER = musterAus(_G.SKILL_RANK_UP) or "^Your skill in (.+) has increased to (%d+)"

-- Qualitaet aus GetItemInfo; Rueckfall ueber die Link-Farbe, falls der Item-Cache kalt ist.
local FARBE_QUALITAET = { ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6 }
local function qualitaetVon(link)
    if GetItemInfo then
        local ok, _, _, q = pcall(GetItemInfo, link)
        if ok and type(q) == "number" then return q end
    end
    local farbe = link:match("|cff(%x%x%x%x%x%x)")
    return farbe and FARBE_QUALITAET[farbe:lower()] or 0
end

local function lootZeile(text)
    if type(text) ~= "string" then return end
    local rest = nil
    for _, m in ipairs(LOOT_MUSTER) do
        rest = text:match(m)
        if rest then break end
    end
    if not rest then return end                    -- kein eigener Drop ("You receive item" = Kauf)
    local link = text:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
    if not link then return end
    if qualitaetVon(link) >= LOOT_MIN_QUALITAET then ns.melde("LOOT") end
end

local function skillZeile(text)
    if type(text) ~= "string" then return end
    local beruf, wert = text:match(SKILL_MUSTER)
    wert = tonumber(wert)
    if not (beruf and wert) then return end
    if wert % 25 == 0 then
        ns.melde("SKILL", { beruf = beruf, wert = wert })
    end
end

ns.on("CHAT_MSG_LOOT", function(text) lootZeile(text) end)
ns.on("CHAT_MSG_SKILL", function(text) skillZeile(text) end)

-- ---------------------------------------------------------------- Quest / Stufe / Gruppe / Tod
ns.on("QUEST_ACCEPTED", function() if not tot() then ns.melde("QUEST_AN") end end)
ns.on("QUEST_TURNED_IN", function() ns.melde("QUEST_AB") end)

local letztesLevel = 0
ns.on("PLAYER_LEVEL_UP", function(level)
    local lvl = tonumber(level) or (UnitLevel and UnitLevel("player")) or 0
    if lvl <= letztesLevel then return end         -- Drossel "level": je Stufe einmal
    letztesLevel = lvl
    ns.melde("LEVELUP", { level = lvl, key = lvl })
end)

local letzteGruppe = nil         -- nil = Basislinie fehlt; traegt NUR an/aus
local function inGruppe()
    if IsInGroup and IsInGroup() then return true end
    if IsInRaid and IsInRaid() then return true end
    if GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0 then return true end
    return false
end
local function pruefeGruppe()
    local drin = inGruppe()
    if letzteGruppe == nil then letzteGruppe = drin; return end
    if drin == letzteGruppe then return end
    letzteGruppe = drin
    if drin then ns.melde("GRUPPE") end
end
ns.on("GROUP_ROSTER_UPDATE", pruefeGruppe)

local todGemeldet = false
ns.on("PLAYER_DEAD", function()
    if todGemeldet then return end
    todGemeldet = true
    ns.melde("GEFALLEN")
end)
ns.on("PLAYER_ALIVE", function() if not tot() then todGemeldet = false end end)
ns.on("PLAYER_UNGHOST", function() todGemeldet = false end)

-- ---------------------------------------------------------------- Leerlauf
-- 10 min ohne eigene Aktivitaet UND ohne Plauder der Regie; nicht im Kampf, nicht AFK,
-- nicht auf Taxi, nicht tot. Regie-Drossel 1200 obendrauf; eigener Merker verhindert,
-- dass jeder 60-s-Tick erneut an die Regie klopft.
local letzteAktivitaet = 0
local leerlaufVersuch = 0
local leerlaufTicker = nil

local function aktiv() letzteAktivitaet = jetzt() end

for _, ev in ipairs({
    "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "BAG_UPDATE_DELAYED",
    "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "CHAT_MSG_LOOT", "QUEST_LOG_UPDATE",
    "PLAYER_LEVEL_UP", "PLAYER_STARTED_MOVING", "MERCHANT_SHOW", "GOSSIP_SHOW",
    "QUEST_DETAIL", "TRADE_SKILL_SHOW", "LOOT_OPENED", "MAIL_SHOW", "BANKFRAME_OPENED",
}) do
    ns.on(ev, aktiv)
end
ns.onUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(unit)
    if not unit or unit == "player" then aktiv() end
end)

local function leerlaufTick()
    if tot() or aufTaxi() or imKampf() then return end
    if ns.Regie and ns.Regie.imKampf then return end
    if UnitIsAFK and UnitIsAFK("player") then return end
    local t = jetzt()
    local plauder = ns.Regie and ns.Regie.zuletztPlauder or 0
    local ruhe = math.max(letzteAktivitaet, plauder, leerlaufVersuch)
    if t - ruhe < LEERLAUF_MIN then return end
    leerlaufVersuch = t
    ns.melde("LEERLAUF")
end

-- ---------------------------------------------------------------- Ladebildschirm
ns.on("PLAYER_ENTERING_WORLD", function()
    ladeBis = jetzt() + 8
    aktiv()
    leerlaufVersuch = jetzt()
    letzteGruppe = nil
    -- Basislinien neu und still: Taschen/Ruestung/Trank/Gruppe/Buffs.
    bagsArmed = nil
    duraArmed = nil
    letzterTrank = -1
    ns.Compat.After(6, function()
        pcall(bagScan)
        pcall(duraScan)
        pcall(pruefeGruppe)
    end)
    ns.Compat.After(9, function() pcall(buffScan) end)
    if not leerlaufTicker then
        leerlaufTicker = ns.Compat.NewTicker(60, function()
            local ok, err = pcall(leerlaufTick)
            if not ok then ns.debug("Alltag leerlauf: " .. tostring(err)) end
        end)
        ns.Compat.NewTicker(15, function()
            local ok, err = pcall(buffBaldScan)
            if not ok then ns.debug("Alltag buffbald: " .. tostring(err)) end
        end)
    end
end)

function A.stand()
    return bagsArmed, duraArmed, letzterTrank, letzteGruppe, jetzt() - letzteAktivitaet
end
