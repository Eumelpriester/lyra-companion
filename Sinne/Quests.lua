-- Sinne/Quests.lua — Quest-Fortschritt nativ (Welle 2): Ziel erledigt, fast fertig, Quest komplett,
-- Abgabe in der Naehe (nur mit Questie-Daten). API: ns.Compat.questAnzahl/questLogEintrag/
-- questObjectives, QUEST_LOG_UPDATE, C_Map.GetBestMapForUnit. Nur lesend, keine Questie-Interna
-- ohne pcall.
-- PORT (0.9.0): Das Questlog ist die zweite echte Bruchstelle neben dem Combat-Log.
--   Classic Era/TBC/MoP: GetNumQuestLogEntries() + GetQuestLogTitle(i) + GetQuestLogLeaderBoard(j, i)
--   Retail 12.x / Forever: GetQuestLogTitle ist seit 9.0.1 ENTFERNT; es gibt C_QuestLog.GetInfo(i),
--     C_QuestLog.GetNumQuestLogEntries() und C_QuestLog.GetQuestObjectives(questID).
--   Diese Datei kennt keinen der beiden Wege mehr — sie fragt ns.Compat (Core/Compat.lua).
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local Q = {}
ns.Sinne.Quests = Q
ns.Quests = Q

local stand = {}        -- [questID] = { titel, komplett, ziele = { [j] = { fertig, rest } } }
local ersterScan = true
local geplant = false

local C = ns.Compat

local function scan()
    geplant = false
    -- PORT: eine Schleife fuer beide Welten. C.questAnzahl liefert 0, wenn der Client keinen
    -- der beiden Wege hat — dann tut diese Datei einfach nichts (wie bisher).
    local n = C.questAnzahl()
    if n <= 0 then return end
    local neu = {}
    for i = 1, n do
        local q = C.questLogEintrag(i)
        if q and q.titel and not q.header then
            local qid = q.questID or q.titel
            local e = { titel = q.titel, komplett = q.complete, ziele = {} }
            -- PORT: Ziele ueber den Shim. Classic geht weiter ueber den Logbuch-Index
            -- (getestet), Mainline ueber C_QuestLog.GetQuestObjectives(questID).
            local ziele = C.questObjectives(q.questID, i)
            for j = 1, #ziele do
                local z = ziele[j]
                local rest = nil
                if z.haben and z.brauchen then rest = z.brauchen - z.haben end
                e.ziele[j] = { fertig = z.fertig, rest = rest, text = z.text }
            end
            neu[qid] = e
            local alt = stand[qid]
            if alt and not ersterScan then
                if e.komplett and not alt.komplett then
                    ns.melde("QUEST_FERTIG", { quest = q.titel, key = qid })
                else
                    for j, z in ipairs(e.ziele) do
                        local az = alt.ziele[j]
                        if az then
                            if z.fertig and not az.fertig and not e.komplett then
                                ns.melde("QUEST_ZIEL_FERTIG", { quest = q.titel, ziel = (tostring(z.text):gsub("%s*%d+%s*/%s*%d+", "")), key = qid .. ":" .. j })
                            elseif z.rest == 1 and (az.rest or 0) > 1 then
                                ns.melde("QUEST_FAST", { quest = q.titel, key = qid })
                            end
                        end
                    end
                end
            end
        end
    end
    stand = neu
    ersterScan = false
end

local function planen()
    if geplant then return end
    geplant = true
    ns.Compat.After(1.5, function() pcall(scan) end)
end
ns.on("QUEST_LOG_UPDATE", planen)
ns.on("PLAYER_ENTERING_WORLD", function() ersterScan = true; planen() end)

-- Abgabe in der Naehe (Questie): komplette Quest, deren Abgabe-NPC in der aktuellen Karte spawnt
local function questieDB()
    if not (QuestieLoader and QuestieLoader.ImportModule) then return nil end
    local ok, db = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
    if ok and type(db) == "table" and db.QueryQuestSingle then return db end
    return nil
end
local function abgabeKarte(qid)
    local db = questieDB(); if not db or type(qid) ~= "number" then return nil end
    local ok, fin = pcall(db.QueryQuestSingle, qid, "finishedBy")
    if not ok or type(fin) ~= "table" then return nil end
    local npcs = fin[1]
    if type(npcs) ~= "table" then return nil end
    local ok2, ZoneDB = pcall(QuestieLoader.ImportModule, QuestieLoader, "ZoneDB")
    for _, npc in ipairs(npcs) do
        local ok3, spawns = pcall(db.QueryNPCSingle, npc, "spawns")
        if ok3 and type(spawns) == "table" then
            for areaId in pairs(spawns) do
                if ok2 and ZoneDB and ZoneDB.GetUiMapIdByAreaId then
                    local ok4, ui = pcall(ZoneDB.GetUiMapIdByAreaId, ZoneDB, areaId)
                    if ok4 and ui then return ui end
                end
            end
        end
    end
    return nil
end
local abgabeGesagt = {}
ns.on("ZONE_CHANGED_NEW_AREA", function()
    ns.Compat.After(20, function()
        local karte = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if not karte then return end
        for qid, e in pairs(stand) do
            if e.komplett and not abgabeGesagt[qid] then
                local ok, ui = pcall(abgabeKarte, qid)
                if ok and ui == karte then
                    abgabeGesagt[qid] = true
                    ns.melde("QUEST_ABGABE_NAH", { quest = e.titel, key = qid })
                    return
                end
            end
        end
    end)
end)

function Q.status()
    local n, fertig, nah = 0, 0, nil
    for _, e in pairs(stand) do
        n = n + 1
        if e.komplett then fertig = fertig + 1 else
            local rest = 0
            for _, z in ipairs(e.ziele) do if not z.fertig then rest = rest + (z.rest or 1) end end
            if not nah or rest < nah.rest then nah = { titel = e.titel, rest = rest } end
        end
    end
    local sp = ns.sprache()
    local zeilen = { (sp == "de" and "%d Quests im Buch, %d abgabebereit." or "%d quests in the log, %d ready to turn in."):format(n, fertig) }
    if nah then zeilen[#zeilen + 1] = (sp == "de" and "Am naechsten dran: %s (noch %d)." or "Closest: %s (%d left)."):format(nah.titel, nah.rest) end
    return zeilen
end
function Q.zusammenfassung() return table.concat(Q.status(), " ") end

ns.on("PLAYER_LOGIN", function()
    if not (ns.Dialog and type(ns.Dialog.aktionen) == "table") then return end
    ns.Dialog.aktionen.w2_quests = function() return "w2_quests", { liste = Q.zusammenfassung() } end
end)
