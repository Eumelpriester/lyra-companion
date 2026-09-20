-- Sinne/Faehigkeiten.lua — Notfallknoepfe, Cooldowns, Lernen der Nutzung, Klassenrat (Welle 2).
-- API : IsSpellKnown/IsPlayerSpell, C_Spell.GetSpellCooldown | GetSpellCooldown, GetSpellInfo | C_Spell.GetSpellInfo,
--       UNIT_SPELLCAST_SUCCEEDED (nur "player"), UnitClass("player"), GetItemCooldown/C_Container.GetItemCooldown.
-- Nur lesend. Lyra sagt, was bereit ist — sie drueckt nichts.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local F = {}
ns.Sinne.Faehigkeiten = F
ns.Faehigkeiten = F

-- Notfallknoepfe je Klasse (Classic-Era-Grundraenge; IsSpellKnown prueft, ob der Charakter sie hat).
F.NOTFALL = {
    MAGE    = { 1953, 11958, 122, 12051 },        -- Blinzeln, Eisblock, Frostnova, Hervorrufung
    ROGUE   = { 1856, 2983, 5277, 1776 },         -- Verschwinden, Sprint, Entrinnen, Solarplexus
    HUNTER  = { 5384, 781, 2974 },                -- Totstellen, Rueckzug, Fluegelschlag
    WARRIOR = { 5246, 20230, 871 },               -- Drohruf, Vergeltung, Schildwall
    PRIEST  = { 8122, 17, 586, 13908 },           -- Psychischer Schrei, Machtwort: Schild, Verblassen, Verzweifeltes Gebet
    PALADIN = { 642, 633, 498, 853 },             -- Gottesschild, Handauflegung, Goettlicher Schutz, Hammer der Gerechtigkeit
    DRUID   = { 22812, 16689, 5211, 783 },        -- Baumrinde, Griff der Natur, Hieb, Reisegestalt
    WARLOCK = { 5484, 5782, 6789 },               -- Schreckensgeheul, Furcht, Todesmantel
    -- REVIEW6B: 2484 ist das Erdfessel-Totem (Earthbind), nicht "Totem der Erdung" (Grounding 8177).
    -- Als Notfallknopf beim Weglaufen ist Erdfessel richtig; nur der Kommentar war falsch.
    SHAMAN  = { 2645, 2484, 5730 },               -- Geisterwolf, Erdfesseltotem, Steinklauentotem
}
F.RUHESTEIN = 6948

local klasse = nil
local function meineKlasse()
    if not klasse then klasse = select(2, UnitClass("player")) end
    return klasse
end

-- REVIEW6B: zwei Fallen auf Era 1.15.9, beide still.
-- (1) `IsSpellKnown`/`IsPlayerSpell` sind dort nur noch Deprecation-Fallbacks
--     (Blizzard_DeprecatedSpellBook/Deprecated_SpellBook.lua, ganz oben: `if not
--     GetCVarBool("loadDeprecationFallbacks") then return end`). Steht die CVar auf 0, sind beide
--     Globals nil - `bekannt()` gab dann fuer JEDEN Zauber false zurueck, die Notfall-Liste war
--     leer und "/lyra cd" zeigte nur den Ruhestein. Der belegte Weg ist `C_SpellBook`
--     (Namespace C_SpellBook, SpellBookDocumentation.lua: IsSpellKnown / IsSpellInSpellBook).
-- (2) Era hat RAENGE, und jeder Rang ist eine eigene Spell-ID. F.NOTFALL fuehrt Rang-1-IDs -
--     sobald der Charakter Rang 2 lernt, meldet die Rang-1-ID "nicht bekannt". Deshalb: Name aus
--     der ID aufloesen (das geht immer) und dann ueber den NAMEN pruefen und die Abklingzeit holen;
--     eine Namensabfrage trifft in Classic den hoechsten bekannten Rang.
local function spellName(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and type(info) == "table" and info.name then return info.name end
    end
    if GetSpellInfo then local ok, n = pcall(GetSpellInfo, id); if ok and n then return n end end
    return "#" .. tostring(id)
end

local function idBekannt(id)
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if C_SpellBook then
        if C_SpellBook.IsSpellKnown then
            local ok, v = pcall(C_SpellBook.IsSpellKnown, id, bank); if ok and v then return true end
        end
        if C_SpellBook.IsSpellInSpellBook then
            local ok, v = pcall(C_SpellBook.IsSpellInSpellBook, id, bank, false); if ok and v then return true end
        end
    end
    if IsPlayerSpell then local ok, v = pcall(IsPlayerSpell, id); if ok and v then return true end end
    if IsSpellKnown then local ok, v = pcall(IsSpellKnown, id); if ok and v then return true end end
    return false
end

-- Namensabfrage: liefert nur etwas, wenn der Zauber im Zauberbuch steht (hoechster Rang).
local function nameBekannt(name)
    if type(name) ~= "string" or name == "" or name:sub(1, 1) == "#" then return false end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        if ok and type(info) == "table" and info.name then return true end
    end
    if GetSpellInfo then local ok, n = pcall(GetSpellInfo, name); if ok and n then return true end end
    return false
end

local function bekannt(id, name)
    if nameBekannt(name) then return true end
    return idBekannt(id)
end

-- Rueckgabe: bereit (bool), restSekunden.
-- REVIEW6B: nimmt den Namen, wenn er bekannt ist (trifft den hoechsten Rang), sonst die ID.
-- C_Spell.GetSpellCooldown gibt es auf Era 1.15.9 (SpellDocumentation.lua, Namespace C_Spell) und
-- liefert eine Tabelle (SpellCooldownInfo: startTime, duration, isEnabled, isActive, modRate);
-- sie ist mit MayReturnNothing markiert, kann also nil sein - daher der type()-Test.
local function cooldown(id)
    local start, dauer = 0, 0
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, t = pcall(C_Spell.GetSpellCooldown, id)
        if ok and type(t) == "table" then start, dauer = t.startTime or 0, t.duration or 0 end
    elseif GetSpellCooldown then
        local ok, s, d = pcall(GetSpellCooldown, id)
        if ok then start, dauer = s or 0, d or 0 end
    end
    if dauer <= 1.5 or start == 0 then return true, 0 end
    local rest = (start + dauer) - GetTime()
    if rest <= 0 then return true, 0 end
    return false, rest
end

local function ruhesteinRest()
    local start, dauer = 0, 0
    if C_Container and C_Container.GetItemCooldown then
        local ok, s, d = pcall(C_Container.GetItemCooldown, F.RUHESTEIN); if ok then start, dauer = s or 0, d or 0 end
    elseif GetItemCooldown then
        local ok, s, d = pcall(GetItemCooldown, F.RUHESTEIN); if ok then start, dauer = s or 0, d or 0 end
    end
    if dauer == 0 or start == 0 then return 0 end
    return math.max(0, (start + dauer) - GetTime())
end

-- Gedaechtnis: Nutzung der Notfallknoepfe je Charakter
local function speicher()
    local c = LyraGestaltDB and LyraGestaltDB.chronik and LyraGestaltDB.chronik[ns.charKey]
    if not c then return nil end
    c.faehigkeiten = c.faehigkeiten or { genutzt = {}, beinahe = 0 }
    return c.faehigkeiten
end

-- Liste der bekannten Notfallknoepfe: { {id, name, bereit, rest}, ... }
function F.liste()
    local out = {}
    local k = meineKlasse()
    for _, id in ipairs(F.NOTFALL[k] or {}) do
        local name = spellName(id)
        if bekannt(id, name) then
            local bereit, rest = cooldown(nameBekannt(name) and name or id)
            out[#out + 1] = { id = id, name = name, bereit = bereit, rest = rest }
        end
    end
    return out
end

function F.status()
    local zeilen = {}
    for _, e in ipairs(F.liste()) do
        zeilen[#zeilen + 1] = ("%s: %s"):format(e.name, e.bereit and (ns.sprache() == "de" and "bereit" or "ready")
            or ((ns.sprache() == "de" and "noch %ds" or "%ds left"):format(math.ceil(e.rest))))
    end
    local hs = ruhesteinRest()
    zeilen[#zeilen + 1] = (ns.sprache() == "de" and "Ruhestein: %s" or "Hearthstone: %s"):format(
        hs == 0 and (ns.sprache() == "de" and "bereit" or "ready") or (math.ceil(hs / 60) .. " min"))
    return zeilen
end

function F.zusammenfassung()
    local z = F.status()
    return table.concat(z, " · ")
end

-- Bei Lebensgefahr: was ist bereit?
-- REVIEW6B: Der Hinweis lief bisher SOFORT los. ns.nachAusgabe-Hooks laufen synchron IN R.melde,
-- also im selben Frame wie die Warnung selbst - und NOTFALL_BEREIT ist klasse "warn", geht damit
-- an Abstand und Budget vorbei. Ergebnis: ns.Blase.zeige wird im selben Frame ein zweites Mal
-- gerufen, die HP20-Warnung ist weg, bevor sie jemand lesen konnte, und die Stimme schneidet sich
-- selbst ab (dieselbe Lehre wie STURZ/HP20 in Review 2 und KAMPF_AUS/Warteliste in der Regie).
-- Jetzt drei Sekunden Verzug, und der Hinweis kommt nur, wenn die Lage noch besteht.
local NOTFALL_VERZUG = 3
local zuletzt = 0
local function beiGefahr(id)
    if id ~= "HP20" and id ~= "HP35" then return end
    local t = GetTime()
    if t - zuletzt < 20 then return end
    zuletzt = t
    local sp = speicher(); if sp and id == "HP20" then sp.beinahe = (sp.beinahe or 0) + 1 end
    ns.Compat.After(NOTFALL_VERZUG, function()
        -- Gefahr vorbei (Kampf aus) oder tot? Dann ist der Hinweis nur noch Nachtreten.
        if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
        if UnitAffectingCombat and not UnitAffectingCombat("player") then return end
        local bereit, cd = {}, nil
        for _, e in ipairs(F.liste()) do
            if e.bereit then bereit[#bereit + 1] = e.name elseif not cd then cd = e end
        end
        if #bereit > 0 then
            ns.melde("NOTFALL_BEREIT", { name = table.concat(bereit, ", ", 1, math.min(2, #bereit)), key = id })
        elseif cd then
            ns.melde("NOTFALL_CD", { name = cd.name, sek = math.ceil(cd.rest), key = id })
        end
    end)
    -- Lernen: nie genutzter Notfallknopf nach >= 5 Beinahe-Toden
    if sp and id == "HP20" and (sp.beinahe or 0) >= 5 and not F.ungenutztGesagt then
        for _, e in ipairs(F.liste()) do
            if not sp.genutzt[e.id] then
                F.ungenutztGesagt = true
                ns.Compat.After(90, function() ns.melde("NOTFALL_UNGENUTZT", { name = e.name }) end)
                break
            end
        end
    end
end

ns.on("PLAYER_LOGIN", function()
    if ns.nachAusgabe then ns.nachAusgabe(function(id) pcall(beiGefahr, id) end) end
end)

-- Nutzung lernen (nur eigene Zauber)
ns.onUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(unit, _, spellID)
    if unit ~= "player" then return end
    local k = meineKlasse()
    for _, id in ipairs(F.NOTFALL[k] or {}) do
        if id == spellID then
            local sp = speicher(); if sp then sp.genutzt[id] = (sp.genutzt[id] or 0) + 1 end
            return
        end
    end
end)

-- Klassenrat (Kurzfassung; Quelle: klassenrat/magier.md — andere Klassen Struktur/Basisrat)
F.KLASSENRAT = {
    MAGE = {
        de = { "Frost ist fuers Solo-Leveln der Standard: Kontrolle schlaegt Schaden, tote Magier machen keine DPS.",
               "Trinken vor jedem Pull unter 60 Prozent Mana. Mana ist deine echte Ressource.",
               "Frostblitz auf Maximaldistanz, Nova wenn dran, zuruecklaufen, weiter Frostblitz. Rang-1-Frostblitz als billiger Snare.",
               "Eisblock ist dein Sicherheitsnetz. Vor dem Pull wissen, ob er bereit ist." },
        en = { "Frost is the solo-leveling standard: control beats damage, dead mages do no DPS.",
               "Drink before every pull below 60 percent mana. Mana is your real resource.",
               "Frostbolt at max range, Nova when up, step back, more Frostbolt. Rank-1 Frostbolt as a cheap snare.",
               "Ice Block is your safety net. Know if it's ready before you pull." },
    },
    ALLGEMEIN = {
        de = { "Pull nur, was du im Notfall auch loswirst. Fluchtweg vor dem Kampf, nicht im Kampf.",
               "Erste Hilfe ist auf Hardcore ein Beruf, kein Extra. Verbaende lernen und tragen.",
               "Zwei Gegner sind ein Kampf, drei sind ein Nachruf. Zaehl, bevor du ziehst.",
               "Trank ist kein Bonus, Trank ist Plan B. Immer drei dabei." },
        en = { "Only pull what you can escape from. Plan the exit before the fight, not during.",
               "First Aid is a profession on Hardcore, not an extra. Learn bandages and carry them.",
               "Two enemies are a fight, three are an obituary. Count before you pull.",
               "A potion is not a bonus, it's plan B. Always carry three." },
    },
}
function F.rat()
    local sp = ns.sprache()
    local tab = F.KLASSENRAT[meineKlasse()] or F.KLASSENRAT.ALLGEMEIN
    local liste = tab[sp] or tab.en
    if math.random() < 0.35 then liste = (F.KLASSENRAT.ALLGEMEIN[sp] or F.KLASSENRAT.ALLGEMEIN.en) end
    return liste[math.random(#liste)]
end

-- Dialog-Aktionen
ns.on("PLAYER_LOGIN", function()
    if not (ns.Dialog and type(ns.Dialog.aktionen) == "table") then return end
    local A = ns.Dialog.aktionen
    A.w2_cooldowns = function() return "w2_cooldowns", { liste = F.zusammenfassung() } end
    A.w2_rat = function() return "w2_rat", { rat = F.rat() } end
end)
