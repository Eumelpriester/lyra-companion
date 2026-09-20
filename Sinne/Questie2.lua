-- Sinne/Questie2.lua — Questie tiefer (Welle 3). NUR LESEND, versionstolerant wie Sinne/Bruecken.lua.
--
-- Questie zeigt, WO etwas ist. Das ist geloest und braucht keine zweite Stimme. Was Questie nicht
-- kann: die neue Quest mit dem verbinden, was dir dort schon einmal passiert ist. "Die geht nach
-- Westfall, Stufe 14 - da warst du vor neun Tagen fast tot." Dafuer braucht es beides: Questies
-- Datenbank (Zielzone, Stufe, Kette) und Lyras Chronik (Besuche, Beinahe-Tode, letzter Besuch).
-- Diese Datei ist genau diese Verbindung.
--
-- Ereignisse:
--   QUEST_ZIEL_ZONE        beim Annehmen: Zielzone + Queststufe            ({quest} {zone} {level})
--   QUEST_ZONE_ERINNERUNG  dasselbe, aber die Chronik hat dort etwas       (+ {tage} {beinahe})
--   QUEST_KETTE_WEITER     beim Abgeben: die naechste Quest der Kette      ({quest})
--   QUEST_WORAN            auf Zuruf (/lyra woran): woran du gerade bist   ({quest} {ziel})
--   Alle plauder. QUEST_WORAN immer mit vars.direkt (Antwort auf eine Frage).
-- Schalter: "questieTief" (Account, Default an). Aus = diese Datei fragt Questie nicht.
--
-- FREMD-API (Questie 11.37.1, Belege aus dem installierten Addon; ImportModule liefert bei einem
-- unbekannten Namen einen LEEREN Stub - QuestieLoader.lua:172-177 -, darum wird immer ein FELD
-- geprueft, nie nur die Tabelle):
--   QuestieLoader:ImportModule("QuestieDB"|"ZoneDB"|"QuestiePlayer")
--   QuestieDB.QueryQuestSingle(id, key)        QuestieDB.lua:331 (Punkt-Aufruf, ein Schluessel)
--   QuestieDB.GetQuest(id)                     QuestieDB.lua:1454 (Punkt-Aufruf, Rueckfall)
--   Quest-Schluessel: name, questLevel, requiredLevel, zoneOrSort (=areaID, >0),
--                     nextQuestInChain, preQuestSingle   Database/questDB.lua:6-56
--   ZoneDB:GetUiMapIdByAreaId(areaId)          Database/Zones/zoneDB.lua:87
--   ZoneDB:GetLocalizedDungeonName(areaId)     Database/Zones/zoneDB.lua:155
--   QuestiePlayer.currentQuestlog              Modules/QuestiePlayer.lua (questId -> Quest)
--   Questie.db.char.TrackedQuests              Modules/Tracker/QuestieTracker.lua:207 (questId-Menge)
-- W9 (P2-1): Die OFFIZIELLE Flaeche - Questie.API.RegisterOnReady / .RegisterForQuestUpdates,
--   Public/README.md:3 "stable and safe to use" - wird in Sinne/Welle9.lua angemeldet und ruft
--   dann Q.angenommen / Q.abgegeben. Alles oben Genannte bleibt intern und bleibt in pcall;
--   eine Datenbank-Funktion hat Questie.API nicht, Zielzone/Stufe/Kette kommen weiter aus
--   QuestieDB. Ist der offizielle Weg angemeldet, steht Q.apiWeg auf true und die eigenen
--   QUEST_ACCEPTED/QUEST_TURNED_IN-Handler halten still (sonst kaeme jede Zeile doppelt).
-- Blizzard-API (nur lesend): C_Map.GetMapInfo, ns.Compat.questAnzahl/questLogEintrag/
--   questObjectives (Questlog-Shim), GetRealZoneText, UnitLevel, time.
-- Events: QUEST_ACCEPTED, QUEST_TURNED_IN, PLAYER_LOGIN.
-- PORT (0.9.0): Questie gibt es nur fuer Classic-Clients. Auf Retail/Forever findet questieDB()
--   nichts, an() gibt false zurueck und die Datei ist still — das ist der richtige Zustand und
--   war schon vorher so gebaut. Portiert wurde nur Q.woran(), weil die Funktion Questie gar
--   nicht braucht (Questlog-Shim statt GetQuestLogTitle). questIdAus() deckt beide
--   QUEST_ACCEPTED-Signaturen ab, indem es BEIDE Argumente gegen die Datenbank prueft; auf
--   Mainline liefert QUEST_ACCEPTED nur (questID), und genau das faellt dort auf a.
--
-- WAS ABSICHTLICH FEHLT: der Rueckwaerts-Weg ueber `preQuestSingle` ("welche Quest braucht die
--   gerade abgegebene als Vorbedingung?"). Questie hat dafuer keinen Index; es waere ein Lauf
--   ueber ~5 000 Quests mit je einer QueryQuestSingle - bei JEDER Abgabe. `nextQuestInChain`
--   deckt die Ketten ab, die man als Kette erlebt; der Rest ist es nicht wert.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local Q = {}
ns.Sinne.Questie2 = Q
ns.Questie2 = Q

local TAG = 86400
Q.VERZUG      = 6              -- s nach dem Annehmen (die Quest-Annahme-Blase des Clients zuerst)
Q.KETTE_VERZUG = 5             -- s nach der Abgabe (QUEST_AB/QUEST_FERTIG stehen schon)
Q.ERINNERUNG_MIN = 2           -- Tage: darunter ist "da warst du" keine Erinnerung, sondern eben
Q.ZIEL_KUERZE = 60             -- Zeichen je Zieltext

local function an() return ns.Get("questieTief") ~= false end
local function unix() return (time and time()) or 0 end

local function melde(id, vars)
    if not ns.melde then return false end
    local ok, v = pcall(ns.melde, id, vars)
    return (ok and v) and true or false
end

-- HARNESS-BEFUND (dieselbe Falle wie REVIEW6B bei KAMPF_REKORD und REVIEW5 bei FEIERTAG):
-- Sinne/Alltag.lua meldet beim Annehmen QUEST_AN und beim Abgeben QUEST_AB - beides plauder.
-- Damit steht der 30-s-Plauder-Abstand, wenn unsere Zeile sechs Sekunden spaeter kommt, und sie
-- fiel im Trockentest zuverlaessig mit Drop-Grund "abstand" heraus. Also EIN Nachhol, genau wie
-- Sinne/Chronik.lua es macht: den Rest des Abstands (und eine laufende Stillhalte-Ruhe aus
-- Sinne/DBM.lua) abwarten und ein zweites Mal versuchen. Die Drossel wird von der Regie erst
-- beim ERFOLG verbraucht - der zweite Versuch ist darum unschaedlich.
local function meldeSpaeter(id, vars, verzug)
    ns.Compat.After(verzug, function()
        if melde(id, vars) then return end
        local rest = 0
        if ns.Regie and ns.Regie.abstandRest then
            local ok, r = pcall(ns.Regie.abstandRest)
            if ok and type(r) == "number" then rest = r end
        end
        if ns.BossBruecke and ns.BossBruecke.ruheRest then
            local ok, r = pcall(ns.BossBruecke.ruheRest)
            if ok and type(r) == "number" and r > rest then rest = r end
        end
        if rest <= 0 then return end
        ns.Compat.After(math.min(rest + 1, 180), function() melde(id, vars) end)
    end)
end

-- ---------------------------------------------------------------------------------------------
-- Questie-Zugriff (Muster aus Sinne/Bruecken.lua)
-- ---------------------------------------------------------------------------------------------
local function modul(name)
    if not (QuestieLoader and type(QuestieLoader.ImportModule) == "function") then return nil end
    local ok, m = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
    if ok and type(m) == "table" then return m end
    return nil
end

local function questieDB()
    local db = modul("QuestieDB")
    if not db then return nil end
    if type(db.QueryQuestSingle) ~= "function" and type(db.GetQuest) ~= "function" then return nil end
    return db
end
Q.db = questieDB

local function questWert(db, id, key)
    if type(db.QueryQuestSingle) == "function" then
        local ok, v = pcall(db.QueryQuestSingle, id, key)
        if ok and v ~= nil then return v end
    end
    if type(db.GetQuest) == "function" then
        local ok, t = pcall(db.GetQuest, id)          -- Punkt-Aufruf (QuestieDB.lua:1454)
        if ok and type(t) == "table" then return t[key] end
    end
    return nil
end
Q.wert = questWert

local function zoneDB()
    local z = modul("ZoneDB")
    if z and type(z.GetUiMapIdByAreaId) == "function" then return z end
    return nil
end

-- areaID (Questie zoneOrSort, > 0) -> lokalisierter Zonenname. Derselbe Text, den
-- GetRealZoneText() liefert - nur so trifft der Schluessel in der Chronik.
local function zoneName(areaId)
    areaId = tonumber(areaId)
    if not areaId or areaId <= 0 then return nil end       -- < 0 ist ein QuestSort (Berufe, Klassen)
    local z = zoneDB()
    if not z then return nil end
    local ok, uiMap = pcall(z.GetUiMapIdByAreaId, z, areaId)
    if ok and type(uiMap) == "number" and C_Map and C_Map.GetMapInfo then
        local ok2, info = pcall(C_Map.GetMapInfo, uiMap)
        if ok2 and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end
    if type(z.GetLocalizedDungeonName) == "function" then
        local ok3, n = pcall(z.GetLocalizedDungeonName, z, areaId)
        if ok3 and type(n) == "string" and n ~= "" then return n end
    end
    return nil
end
Q.zoneName = zoneName

-- ---------------------------------------------------------------------------------------------
-- Chronik (nur lesen). Format: Sinne/Chronik.lua, zonen[name] = { erst, zuletzt, besuche, beinahe }
-- ---------------------------------------------------------------------------------------------
local function zoneChronik(name)
    if type(name) ~= "string" or name == "" then return nil end
    local c = LyraGestaltDB and ns.charKey and LyraGestaltDB.chronik and LyraGestaltDB.chronik[ns.charKey]
    local z = type(c) == "table" and c.zonen
    if type(z) ~= "table" then return nil end
    local e = z[name]
    if type(e) ~= "table" then return nil end
    return e
end
Q.zoneChronik = zoneChronik

-- ---------------------------------------------------------------------------------------------
-- Quest angenommen
-- ---------------------------------------------------------------------------------------------
-- QUEST_ACCEPTED traegt je Client-Stand (questLogIndex, questID) ODER nur (questID). Beide
-- Argumente werden gegen die Datenbank geprueft: welches davon einen Questnamen hat, ist die ID.
local function questIdAus(db, a, b)
    local kand = {}
    if tonumber(b) then kand[#kand + 1] = tonumber(b) end
    if tonumber(a) then kand[#kand + 1] = tonumber(a) end
    for _, id in ipairs(kand) do
        if id > 0 then
            local n = questWert(db, id, "name")
            if type(n) == "string" and n ~= "" then return id, n end
        end
    end
    return nil
end
Q.questIdAus = questIdAus

local function angenommen(a, b)
    if not an() then return end
    local db = questieDB()
    if not db then return end
    local id, name = questIdAus(db, a, b)
    if not id then return end
    local stufe = tonumber(questWert(db, id, "questLevel"))
    local zone = zoneName(questWert(db, id, "zoneOrSort"))
    if not zone and not stufe then return end          -- nichts zu sagen
    local vars = { quest = name, key = tostring(id) }
    if zone then vars.zone = zone end
    if stufe and stufe > 0 then vars.level = stufe end
    -- Die Chronik entscheidet, welcher Satz kommt. Ein Beinahe-Tod dort schlaegt alles.
    local ch = zone and zoneChronik(zone) or nil
    local id2 = "QUEST_ZIEL_ZONE"
    if ch then
        local beinahe = tonumber(ch.beinahe) or 0
        local zuletzt = tonumber(ch.zuletzt) or 0
        local tage = (zuletzt > 0) and math.floor((unix() - zuletzt) / TAG) or nil
        if beinahe > 0 and tage and tage >= Q.ERINNERUNG_MIN then
            id2 = "QUEST_ZONE_ERINNERUNG"
            vars.tage = tage
            vars.beinahe = beinahe
        elseif beinahe > 0 then
            -- Heute erst dort fast gestorben: die Zahl der Beinahe-Tode reicht als Aufhaenger.
            id2 = "QUEST_ZONE_ERINNERUNG"
            vars.beinahe = beinahe
        end
    end
    -- Die Quest-Annahme selbst macht Laerm (Blase des Clients, QUEST_AN aus Sinne/Alltag.lua).
    -- Luft lassen - und notfalls den Plauder-Abstand abwarten (siehe meldeSpaeter oben).
    meldeSpaeter(id2, vars, Q.VERZUG)
end

-- ---------------------------------------------------------------------------------------------
-- Quest abgegeben: naechste Quest der Kette
-- ---------------------------------------------------------------------------------------------
local function abgegeben(a, b)
    if not an() then return end
    local db = questieDB()
    if not db then return end
    local id = questIdAus(db, a, b)
    if not id then return end
    local naechste = tonumber(questWert(db, id, "nextQuestInChain"))
    if not naechste or naechste <= 0 then return end
    local name = questWert(db, naechste, "name")
    if type(name) ~= "string" or name == "" then return end
    -- Zu hoch fuer diese Stufe? Dann ist der Hinweis eine Enttaeuschung, kein Tipp.
    local nStufe = tonumber(questWert(db, naechste, "requiredLevel")) or 0
    local eigen = (UnitLevel and UnitLevel("player")) or 0
    if eigen > 0 and nStufe > eigen + 4 then return end
    local vars = { quest = name, key = tostring(naechste) }
    if nStufe > 0 then vars.level = nStufe end
    meldeSpaeter("QUEST_KETTE_WEITER", vars, Q.KETTE_VERZUG)
end

-- ---------------------------------------------------------------------------------------------
-- "Was mache ich hier gerade?" — das verfolgte Ziel als vars
-- ---------------------------------------------------------------------------------------------
-- Questies Tracker-Zustand, nur lesend: Questie.db.char.TrackedQuests (QuestieTracker.lua:207)
-- ist eine Menge von questIds, wenn "autoTrackQuests" AUS ist; sonst verfolgt Questie alles aus
-- QuestiePlayer.currentQuestlog. Beide Wege werden geprueft, keiner ist Voraussetzung.
local function verfolgt()
    if not an() then return nil end
    local t = {}
    local ok = pcall(function()
        local db = Questie and Questie.db
        local char = db and db.char
        if type(char) == "table" and type(char.TrackedQuests) == "table" then
            for qid in pairs(char.TrackedQuests) do
                local n = tonumber(qid)
                if n then t[n] = true end
            end
        end
    end)
    if ok and next(t) then return t end
    local p = modul("QuestiePlayer")
    if p and type(p.currentQuestlog) == "table" then
        local ok2 = pcall(function()
            for qid in pairs(p.currentQuestlog) do
                local n = tonumber(qid)
                if n then t[n] = true end
            end
        end)
        if ok2 and next(t) then return t end
    end
    return nil
end
Q.verfolgt = verfolgt

local function kuerze(s)
    s = tostring(s or ""):gsub("[\r\n]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #s > Q.ZIEL_KUERZE then s = s:sub(1, Q.ZIEL_KUERZE - 3) .. "..." end
    return s
end

-- Die Quest, an der du am naechsten dran bist: von den verfolgten (sonst allen) unfertigen
-- Quests die mit dem geringsten Restbedarf. Rueckgabe { quest = Titel, ziel = Zieltext } oder nil.
-- PORT (0.9.0): laeuft ueber ns.Compat (Questlog-Shim) und damit auf allen fuenf Clients.
-- `/lyra woran` braucht Questie NICHT — nur verfolgt() liest Questie, und das ist optional.
-- Auf Retail/Forever bleibt darum genau diese Funktion nutzbar, waehrend der Rest der Datei
-- (Zielzone, Queststufe, Questkette) ohne Questie still ist.
function Q.woran()
    local verf = verfolgt()
    local best = nil
    local ok = pcall(function()
        local n = ns.Compat.questAnzahl()
        for i = 1, n do
            local q = ns.Compat.questLogEintrag(i)
            if q and q.titel and not q.header and not q.complete then
                local qid = q.questID
                if not verf or (qid and verf[qid]) then
                    local rest, ziel = 0, nil
                    local ziele = ns.Compat.questObjectives(qid, i)
                    for j = 1, #ziele do
                        local z = ziele[j]
                        if not z.fertig then
                            rest = rest + ((z.haben and z.brauchen) and (z.brauchen - z.haben) or 1)
                            if not ziel then ziel = z.text end
                        end
                    end
                    if rest > 0 and (not best or rest < best.rest) then
                        best = { quest = q.titel, ziel = ziel and kuerze(ziel) or nil, rest = rest,
                                 verfolgt = verf ~= nil }
                    end
                end
            end
        end
    end)
    if not ok then return nil end
    return best
end

-- /lyra woran -> eine gesprochene Zeile (direkt) plus die Liste im Chat.
function Q.frage()
    local w = Q.woran()
    local de = ns.sprache() == "de"
    if not w then
        ns.print(de and "Du bist an nichts dran, was ich sehen kann." or "Nothing in progress that I can see.")
        return false
    end
    local vars = { direkt = true, quest = w.quest, key = w.quest }
    if w.ziel then vars.ziel = w.ziel end
    melde("QUEST_WORAN", vars)
    return true
end

-- ---------------------------------------------------------------------------------------------
-- Ereignisse
-- ---------------------------------------------------------------------------------------------
-- W9 (P2-1): Beide Funktionen sind jetzt oeffentlich. Sinne/Welle9.lua ruft sie ueber die
-- OFFIZIELLE Questie.API (RegisterForQuestUpdates) mit einer questId, die Questie selbst
-- liefert - statt sie wie hier aus den beiden Argumenten von QUEST_ACCEPTED zu erraten.
-- Q.apiWeg wird dort auf true gesetzt, und zwar ERST, wenn die Anmeldung wirklich durch ist.
-- Solange sie es nicht ist (kein Questie, altes Questie, API wirft), bleibt dieser Weg hier
-- der einzige - er ist der Rueckfall, nicht die Altlast.
Q.angenommen, Q.abgegeben = angenommen, abgegeben
Q.apiWeg = false

ns.on("QUEST_ACCEPTED", function(a, b)
    if Q.apiWeg then return end        -- Questie meldet es selbst, sonst kaeme die Zeile doppelt
    local ok, err = pcall(angenommen, a, b)
    if not ok then ns.debug("Questie2 angenommen: " .. tostring(err)) end
end)

ns.on("QUEST_TURNED_IN", function(a, b)
    if Q.apiWeg then return end
    local ok, err = pcall(abgegeben, a, b)
    if not ok then ns.debug("Questie2 abgegeben: " .. tostring(err)) end
end)

-- ---------------------------------------------------------------------------------------------
-- /lyra quests zeigt die Tiefe mit an (die Liste selbst kommt aus Sinne/Quests.lua)
-- ---------------------------------------------------------------------------------------------
function Q.status()
    local de = ns.sprache() == "de"
    local db = questieDB()
    local out = {
        (de and "Questie tief: %s, Schalter %s." or "Questie deep: %s, switch %s."):format(
            db and (de and "Daten lesbar" or "data readable") or (de and "keine Daten" or "no data"),
            an() and (de and "an" or "on") or (de and "aus" or "off")),
    }
    local w = Q.woran()
    if w then
        out[#out + 1] = (de and "  Am naechsten dran: %s%s" or "  Closest: %s%s"):format(
            tostring(w.quest), w.ziel and (" - " .. w.ziel) or "")
    end
    local v = verfolgt()
    if v then
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        out[#out + 1] = (de and "  Questie verfolgt %d Quests." or "  Questie tracks %d quests."):format(n)
    end
    -- W9 (P2-1): welcher Weg die Quest-Meldung traegt - die offizielle API oder der eigene
    -- Ereignis-Weg. Steht hier und nicht in Sinne/Welle9.lua, weil man es genau hier sucht.
    out[#out + 1] = (de and "  Meldeweg: %s." or "  Update path: %s."):format(
        Q.apiWeg and (de and "offizielle Questie.API" or "official Questie.API")
                 or (de and "eigene Ereignisse (Rueckfall)" or "own events (fallback)"))
    return out
end

function Q.stand() return questieDB() ~= nil, an(), Q.woran() end
