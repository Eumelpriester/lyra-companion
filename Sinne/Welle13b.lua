-- Sinne/Welle13b.lua — Welle 13b "Andockstellen": zwei Bruecken, die nichts miteinander zu tun
-- haben ausser der Welle, und deshalb in zwei klar getrennten Abschnitten stehen.
--
--   1. DER ABGABEORT IN SCHRITTEN (Recherche 18 §2.1, §4.1 Nr. 2).
--      QUEST_ABGABE_NAH sagt heute "der Questgeber ist in dieser Gegend" — das ist die
--      Karten-ID des Abgebers, also "irgendwo in dieser Zone" (Sinne/Quests.lua:106-113).
--      Diese Datei legt den fehlenden Schritt dazu: Questie kennt den Abgeber-NPC und seine
--      Spawns, HereBeDragons rechnet den Abstand in Yard, Lyra sagt ihn in SCHRITTEN und grob:
--      "Der Abgeber steht zweihundert Schritt nach Norden." Eine Zahl, eine Richtung, Schluss.
--
--   2. EINE MECHANIK VOR DEM PULL (Recherche 18 §2.3, §4.1 Nr. 3).
--      NpcAbilities haelt drei reine Datentabellen in _G (npcs.lua, priorities.lua,
--      Abilities/deDE.lua + enUS.lua). Beim Anvisieren eines LOHNENDEN feindlichen NPC
--      AUSSERHALB des Kampfes nennt Lyra GENAU EINE Mechanik, nur bei Prioritaet 1, einmal je
--      NPC-Typ und Sitzung, eingebettet im Satz: "Der macht Betaeubt. Nicht am Abgrund kaempfen."
--      Die LISTE haengt NpcAbilities selbst an den Tooltip — die sagt Lyra nicht (Regel 1).
--      REVIEW13 (0.16.0): "lohnend" heisst Elite/Rare/Boss ODER Stufe >= eigene Stufe minus
--      zwei, und nicht, wenn Sinne/Kampf.lua gerade ueber dasselbe Ziel gewarnt hat. Beides
--      fehlte in der Zulieferung; die Begruendung steht unten bei "DER FILTER".
--
-- DIE SECHS REGELN (Recherche 18 §3), auf diese Datei angewandt:
--   1. Keine Doppelung: die Entfernung zeigt TomTom, die Faehigkeitenliste NpcAbilities. Lyra
--      sagt, was es bedeutet — einmal, grob, und nur, wenn es eine Handlung nahelegt.
--   2. Hoechstens EINE Zahl je Zeile, und die steht als WORT da ("zweihundert"), weil ein
--      Mensch neben dir auch nicht "zweihundertdreizehn" sagen wuerde.
--   3. Nur menschliche Beobachtung. Keine Zauberzeit, keine Reichweite, keine Abklingzeit.
--   4. Ausfall ist Schweigen: Existenzpruefung auf EIN FELD (nie nur type(x)=="table" —
--      QuestieLoader:ImportModule gibt fuer unbekannte Namen einen LEEREN Stub zurueck,
--      QuestieLoader.lua:172-177) UND pcall um jeden Fremdzugriff.
--   5. Nie in ein fremdes Addon hineinschreiben. Diese Datei liest ausschliesslich.
--   6. Fremde Spieler bleiben draussen: GUIDs, die nicht "Creature"/"Vehicle" sind, fallen raus.
--
-- FREMD-API, BELEGT (installierte Addons, 21.09.2026):
--   QuestieLoader:ImportModule("QuestieDB"|"ZoneDB")           Questie/Modules/QuestieLoader.lua
--   QuestieDB.GetQuest(id).Finisher.NPC = { npcId, ... }       Questie/Database/QuestieDB.lua:1433/1519
--   QuestieDB.QueryQuestSingle(id, "finishedBy") -> {npcs, gos} Questie/Database/QuestieDB.lua:1453
--   QuestieDB:GetNPC(id).spawns = { [areaId] = { {x,y}, ... } } Questie/Database/npcDB.lua:14
--                                                               Koordinaten 0-100, {-1,-1} = Instanz
--   ZoneDB:GetUiMapIdByAreaId(areaId) -> uiMapID                Questie/Database/Zones/zoneDB.lua:87
--   HBD:GetZoneDistance(oZ,oX,oY,dZ,dX,dY) -> Yard, nil ueber Kontinente   HereBeDragons-2.0.lua:601
--   _G.NpcAbilitiesNpcData[npcId] = { sod_spell_ids, classic_spell_ids }  NpcAbilities/Database/npcs.lua:1
--   _G.NpcAbilitiesPriorityData[spellId] = 1..4 (1 = rot)                 NpcAbilities/Database/priorities.lua:1
--   _G.NpcAbilitiesAbilityData["de"|"en"][spellId] = { name, mechanic, ... }
--                                                    NpcAbilities/Database/Abilities/deDE.lua:1, enUS.lua:1
--
-- WARUM DIE RICHTUNG AUS KARTENKOORDINATEN KOMMT UND NICHT AUS DEM HBD-WINKEL
--   HBD:GetZoneDistance gibt ausser der Entfernung zwei Deltas in WELT-Yard zurueck, und deren
--   Achsen sind ohne Kenntnis der Weltkoordinaten-Konvention mehrdeutig (HereBeDragons-2.0.lua
--   rechnet intern mit (posY, posX) aus UnitPosition und dreht den Winkel in GetWorldVector
--   noch einmal). Falsch herum waere die Richtung ein Fehler, den niemand im Prueflauf sieht,
--   aber jeder Spieler im Feld. Die Kartenkoordinaten sind dagegen eindeutig: x waechst nach
--   OSTEN, y waechst nach SUEDEN — und beide Punkte liegen hier per Anlass in DERSELBEN Zone.
--   Der Abstand kommt trotzdem aus HBD:GetZoneDistance, denn nur die Bibliothek kennt die
--   Zonengroesse in Yard und gibt ueber Kontinente hinweg ehrlich nil zurueck.
--
-- Kontrakt: kein SendChatMessage, keine geschuetzte Funktion, keine Fremddaten, kein Netz,
-- keine neuen Globalen. Kein OnUpdate, kein Ticker — beide Bruecken haengen an Ereignissen.
-- Neue Ereignisse: GEGNER_MECHANIK (neu) und drei Zeilen an QUEST_ABGABE_NAH (ergaenzt).
-- Neue SavedVariables: zwei Schalter in ns.DEFAULTS_ACCOUNT, sonst nichts.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Welle13b = W
ns.Sinne.Welle13b = W

-- ---------------------------------------------------------------------------------------------
-- Voreinstellungen. Core/Init.lua gehoert dieser Welle nicht, darum haengen die zwei Schluessel
-- hier an ns.DEFAULTS_ACCOUNT — beim LADEN der Datei, also lange vor ADDON_LOADED, und dort
-- ruft ns.initDB() defaults(). Muster aus Sinne/Welle8.lua:99 und Sinne/Karte2.lua:122.
-- Benannt nach dem, was sie TUN, nicht nach dem Fremd-Addon (Recherche 18 §3).
-- ---------------------------------------------------------------------------------------------
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.abgabeweg     == nil then D.abgabeweg     = true end   -- Weg zum Abgeber
    if D.gegnerMechanik == nil then D.gegnerMechanik = true end  -- Mechanik vor dem Pull
end

-- ---------------------------------------------------------------------------------------------
-- Stellschrauben. Alle an EINER Stelle, alle mit Einheit im Namen.
-- ---------------------------------------------------------------------------------------------
W.MAX_YD       = 400    -- weiter weg: das ist kein "um die Ecke" mehr, Lyra schweigt
W.NAH_YD       = 35     -- naeher: keine Zahl, "ein paar Schritt"
W.ZONE_VERZUG  = 12     -- s nach ZONE_CHANGED_NEW_AREA (VOR den 20 s aus Sinne/Quests.lua)
W.LOG_VERZUG   = 3      -- s nach QUEST_LOG_UPDATE (das Log ist dann fertig)
W.LOGIN_RUHE   = 60     -- s nach dem Ladebildschirm: LOGIN-Gruss und Welle-13a-Ruhe haben Vorfahrt (HOTFIX 0.16.1)
local abgabeRuheBis = 0
W.EIGEN_ABSTAND = 45    -- s zwischen zwei eigenen Abgabe-Pruefungen (Rechenzeit)
W.ZIEL_VERZUG  = 1.5    -- s zwischen Zielwechsel und Mechanik-Zeile
W.MAX_ABGEBER  = 4      -- so viele Abgeber-NPCs je Quest werden angesehen
W.MAX_SPAWNS   = 60     -- so viele Spawn-Punkte je NPC
W.MAX_QUESTS   = 12     -- so viele fertige Quests je Pruefung
W.MAX_LOG      = 100    -- REVIEW13: Muell-Riegel fuer questAnzahl (wie Welle13a.QUEST_MAX)
W.MAX_WORT     = 40     -- Zeichen: laenger ist kein Mechanik-Name, sondern ein Unfall
-- REVIEW13: Ziel-Filter fuer GEGNER_MECHANIK. Siehe Abschnitt 2, "DER FILTER".
W.STUFE_UNTER  = 2      -- Ziel darf hoechstens so viele Stufen UNTER dem Spieler liegen
W.ELITE_RUHE   = 10     -- s: so lange nach einer GEFAHR_ELITE/GEFAHR_STUFEN-Zeile still

-- ---------------------------------------------------------------------------------------------
-- Kleinkram
-- ---------------------------------------------------------------------------------------------
local function jetzt() return (GetTime and GetTime()) or 0 end
local function sprache() return (ns.sprache and ns.sprache() == "de") and "de" or "en" end
local function de() return sprache() == "de" end
local function an(k) return ns.Get and ns.Get(k) ~= false end

-- Jeder Fremdaufruf geht hier durch: kein Wert ohne pcall, kein Fehler nach aussen.
local function frage(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c
end

-- Ein Feld aus einer FREMDEN Tabelle lesen. Sieht ueberfluessig aus ("das ist doch nur ein
-- Index") und ist es nicht: eine fremde Tabelle darf eine Metatabelle haben, und ein __index,
-- das wirft, wuerde sonst genau an der Stelle einen Lua-Fehler machen, an der Lyra schweigen
-- soll. Der Pruefstand faehrt diesen Fall als Modus "kaputt".
local function feld(t, k)
    if type(t) ~= "table" or k == nil then return nil end
    local ok, v = pcall(function() return t[k] end)
    if not ok then return nil end
    return v
end

local function imKampf()  return frage(UnitAffectingCombat, "player") and true or false end
local function tot()      return frage(UnitIsDeadOrGhost, "player") and true or false end
local function aufTaxi()  return frage(UnitOnTaxi, "player") and true or false end

-- GTFO-Stillhalte aus Sinne/Welle6.lua. Sie setzt ns.Regie.plauderRuheBis — und das gilt NUR
-- fuer plauder. GEGNER_MECHANIK ist warn und kaeme mitten in eine GTFO-Warnung hinein, wenn
-- diese Datei nicht selbst danach fragt. (Recherche 18 §2.3 nimmt an, die Stillhalte "greife
-- ohnehin"; sie greift fuer eine Warnung nicht.)
local function ruheLaeuft()
    local R = ns.Regie
    if not R then return false end
    return (tonumber(R.plauderRuheBis) or 0) > jetzt()
end

-- Lua 5.1 in WoW kennt math.atan2; LuaJIT ebenfalls. Der Rueckfall ist trotzdem da, weil ein
-- fehlendes atan2 sonst die ganze Richtung kostet (und damit die halbe Zeile).
local function atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
    return (y > 0 and math.pi / 2) or (y < 0 and -math.pi / 2) or 0
end

-- =============================================================================================
-- 1  Der Abgabeort in Schritten
-- =============================================================================================

-- --------------------------------------------------------------------------------- Questie
-- ImportModule gibt fuer einen unbekannten Namen einen LEEREN Stub zurueck. Deshalb wird hier
-- NIE nur die Tabelle geprueft, sondern immer EIN FELD, von dem der Rest abhaengt.
local function modul(name)
    if not (QuestieLoader and type(QuestieLoader.ImportModule) == "function") then return nil end
    local ok, m = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
    if ok and type(m) == "table" then return m end
    return nil
end

local function questieDB()
    local db = modul("QuestieDB")
    if not db then return nil end
    -- Query*/Get* entstehen erst in QuestieDB:Initialize (QuestieDB.lua:295-331). Vorher ist
    -- die Tabelle da und leer — genau der Fall, den type()=="table" nicht faengt.
    if type(db.QueryQuestSingle) ~= "function" and type(db.GetQuest) ~= "function" then return nil end
    return db
end

local function zoneDB()
    local z = modul("ZoneDB")
    if z and type(z.GetUiMapIdByAreaId) == "function" then return z end
    return nil
end

local function questWert(db, id, key)
    if type(db.QueryQuestSingle) == "function" then
        local v = frage(db.QueryQuestSingle, id, key)
        if v ~= nil then return v end
    end
    if type(db.GetQuest) == "function" then           -- Punkt-Aufruf (QuestieDB.lua:1454)
        local t = frage(db.GetQuest, id)
        if type(t) == "table" then return t[key] end
    end
    return nil
end

local function npcWert(db, id, key)
    if type(db.QueryNPCSingle) == "function" then
        local v = frage(db.QueryNPCSingle, id, key)
        if v ~= nil then return v end
    end
    if type(db.GetNPC) == "function" then             -- Doppelpunkt-Aufruf (QuestieDB.lua:1815)
        local t = frage(db.GetNPC, db, id)
        if type(t) == "table" then return t[key] end
    end
    return nil
end

-- Abgeber-NPC-IDs einer Quest. Zwei Wege, beide belegt: das fertige Quest-Objekt
-- (QO.Finisher.NPC) und der rohe Datenbankschluessel "finishedBy" = { npcs, gameobjects }.
-- Gegenstaende und Objekte als Abgeber fallen raus — sie haben keine Spawns, die ein Mensch
-- "zweihundert Schritt nach Norden" nennen wuerde.
local function abgeberNpcs(db, qid)
    local out = {}
    local fin = questWert(db, qid, "Finisher")
    if type(fin) == "table" and type(fin.NPC) == "table" then
        for _, n in ipairs(fin.NPC) do
            local id = tonumber(n)
            if id and id > 0 then out[#out + 1] = id end
            if #out >= W.MAX_ABGEBER then return out end
        end
    end
    if #out > 0 then return out end
    local roh = questWert(db, qid, "finishedBy")
    if type(roh) == "table" and type(roh[1]) == "table" then
        for _, n in ipairs(roh[1]) do
            local id = tonumber(n)
            if id and id > 0 then out[#out + 1] = id end
            if #out >= W.MAX_ABGEBER then return out end
        end
    end
    return out
end

-- Der naechste Spawn EINES NPC in EINER Karte, in Kartenanteilen 0-1.
-- Koordinaten stehen in der Questie-DB als 0-100 (npcDB.lua:14); {-1,-1} markiert einen
-- Instanz-Spawn (DistanceUtils.lua:29-43) und faellt hier heraus, genauso wie alles, was
-- keine Zahl oder groesser als 100 ist.
local function spawnInKarte(db, npcId, zdb, uiMap, px, py)
    local spawns = npcWert(db, npcId, "spawns")
    if type(spawns) ~= "table" then return nil end
    local bx, by, bd = nil, nil, nil
    for area, liste in pairs(spawns) do
        if type(liste) == "table" and #liste > 0 then
            local ui = frage(zdb.GetUiMapIdByAreaId, zdb, area)
            if tonumber(ui) == uiMap then
                for i = 1, math.min(#liste, W.MAX_SPAWNS) do
                    local p = liste[i]
                    local x = type(p) == "table" and tonumber(p[1]) or nil
                    local y = type(p) == "table" and tonumber(p[2]) or nil
                    if x and y and x > 0 and y > 0 and x <= 100 and y <= 100 then
                        x, y = x / 100, y / 100
                        local dx, dy = x - px, y - py
                        local d = dx * dx + dy * dy
                        if not bd or d < bd then bx, by, bd = x, y, d end
                    end
                end
            end
        end
    end
    if not bx then return nil end
    return bx, by
end

-- --------------------------------------------------------------------------------- Entfernung
-- Grobe Stufen. "zweihundert", nicht 213: eine Zahl, die genauer ist als die Beobachtung,
-- ist keine Beobachtung mehr (Recherche 18 §3 Nr. 2).
W.STUFEN = { 50, 100, 150, 200, 300, 400 }
W.ZAHLWORT = {
    de = { [50] = "fünfzig", [100] = "hundert", [150] = "hundertfünfzig",
           [200] = "zweihundert", [300] = "dreihundert", [400] = "vierhundert", nah = "ein paar" },
    en = { [50] = "fifty", [100] = "a hundred", [150] = "a hundred and fifty",
           [200] = "two hundred", [300] = "three hundred", [400] = "four hundred", nah = "a few" },
}

function W.schrittWort(yd, sp)
    yd = tonumber(yd)
    if not yd or yd < 0 then return nil end
    local t = W.ZAHLWORT[sp or sprache()] or W.ZAHLWORT.en
    if yd > W.MAX_YD then return nil end
    if yd <= W.NAH_YD then return t.nah end
    local beste, abstand = nil, nil
    for _, s in ipairs(W.STUFEN) do
        local d = math.abs(yd - s)
        if not abstand or d < abstand then beste, abstand = s, d end
    end
    return t[beste]
end

-- --------------------------------------------------------------------------------- Richtung
W.RICHTUNGEN = {
    de = { "Norden", "Nordosten", "Osten", "Südosten", "Süden", "Südwesten", "Westen", "Nordwesten" },
    en = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" },
}

-- Karte: x waechst nach OSTEN, y waechst nach SUEDEN. Die Zonengroesse in Yard macht aus den
-- Anteilen ein rechtwinkliges Dreieck, das auch auf einer langgezogenen Zone stimmt; fehlt sie,
-- wird mit den Anteilen gerechnet (dann ist die Richtung grob, aber nie falsch herum).
function W.richtungWort(uiMap, px, py, tx, ty, sp)
    local ost, nord = (tx - px), (py - ty)
    local K2 = ns.Karte2
    local h = K2 and type(K2.hbd) == "function" and K2.hbd() or nil
    if h and type(h.GetZoneSize) == "function" then
        local breite, hoehe = frage(h.GetZoneSize, h, uiMap)
        breite, hoehe = tonumber(breite) or 0, tonumber(hoehe) or 0
        if breite > 0 and hoehe > 0 then ost, nord = ost * breite, nord * hoehe end
    end
    if ost == 0 and nord == 0 then return nil end
    local w = atan2(ost, nord)                   -- 0 = Norden, positiv = nach Osten gedreht
    local zwei = math.pi * 2
    w = w % zwei
    local i = math.floor((w / (zwei / 8)) + 0.5) % 8
    local liste = W.RICHTUNGEN[sp or sprache()] or W.RICHTUNGEN.en
    return liste[i + 1]
end

-- --------------------------------------------------------------------------------- Anlass
-- Fertige Quests. Diese Datei braucht die QUEST-IDs, nicht die Anzahl — Welle 13a fuehrt aber
-- nur einen ZAEHLER (ns.Welle13a.fertigeQuests() gibt eine ZAHL oder nil, Welle13a.lua:225).
--
-- REVIEW13: hier stand ein Zweig, der von 13a eine LISTE erwartet hat
-- ("if type(liste) == 'table' then ... for _, e in ipairs(liste)"). Der konnte nie zutreffen:
-- 13a gibt eine Zahl zurueck, type() ist dann "number", und der Zweig fiel bei JEDEM Aufruf
-- still durch in den nativen Rueckfall. Kein Fehler im Spiel, aber die im Merge-Bericht §2.1
-- begruendete Kopplung ("13b liest ns.Welle13a.fertigeQuests") gab es in Wahrheit nicht, und
-- das Questlog wurde von beiden Sinnen doppelt durchgezaehlt.
-- Jetzt wird der Zaehler genau fuer das benutzt, was er hergibt: als billige ABSAGE. Sagt 13a
-- "null fertige Quests", ist hier nichts zu holen und die Schleife entfaellt ganz. Sagt er nil
-- (kein Questlog auf diesem Client), ebenso. Alles andere zaehlt diese Datei selbst ueber
-- ns.Compat — der Weg, der auf allen fuenf Clients belegt ist (Core/Compat.lua:456/471).
-- Kein Fremd-Addon dafuer.
function W.fertigeQuests()
    local out = {}
    local A = ns.Welle13a
    if A and type(A.fertigeQuests) == "function" then
        local ok, n = pcall(A.fertigeQuests)
        if ok then
            if n == nil then return out end                 -- kein Questlog: nichts zu rechnen
            if type(n) == "number" and n <= 0 then return out end
        end
    end
    local C = ns.Compat
    if not (C and type(C.questAnzahl) == "function" and type(C.questLogEintrag) == "function") then
        return out
    end
    local n = tonumber((frage(C.questAnzahl))) or 0
    -- REVIEW13: Muell-Riegel wie in Sinne/Welle13a.lua (W.QUEST_MAX). Eine Attrappe oder ein
    -- umgebauter Client, der hier 1e9 liefert, haette sonst eine Schleife ohne Ende gedreht -
    -- der Deckel darunter (#out >= W.MAX_QUESTS) greift nur, wenn auch wirklich Quests FERTIG
    -- sind, und schuetzt deshalb nicht.
    if n > W.MAX_LOG then n = W.MAX_LOG end
    for i = 1, n do
        local q = frage(C.questLogEintrag, i)
        if type(q) == "table" and q.complete and not q.header then
            local id = tonumber(q.questID)
            if id then out[#out + 1] = id end
            if #out >= W.MAX_QUESTS then return out end
        end
    end
    return out
end

W.letztePruefung = 0
W.abgabeStand = { db = false, hbd = false, quests = 0, treffer = nil, grund = "nicht versucht" }
local abgabeGeplant = false

-- Die eigentliche Suche. Rueckgabe: questId, Schrittwort, Richtungswort — oder nil.
function W.abgabeSuche()
    local S = W.abgabeStand
    S.db, S.hbd, S.treffer = false, false, nil
    local db = questieDB()
    if not db then S.grund = "kein Questie"; return nil end
    local zdb = zoneDB()
    if not zdb then S.grund = "kein ZoneDB"; return nil end
    S.db = true
    local K2 = ns.Karte2
    if not (K2 and type(K2.spielerOrt) == "function") then S.grund = "keine Karte"; return nil end
    local uiMap, px, py = K2.spielerOrt()
    if not (uiMap and px and py) then S.grund = "kein Standort"; return nil end
    local h = type(K2.hbd) == "function" and K2.hbd() or nil
    if not (h and type(h.GetZoneDistance) == "function") then S.grund = "kein HereBeDragons"; return nil end
    S.hbd = true
    local quests = W.fertigeQuests()
    S.quests = #quests
    if #quests == 0 then S.grund = "keine fertige Quest"; return nil end
    local sp = sprache()
    local bestQ, bestD, bestX, bestY = nil, nil, nil, nil
    for _, qid in ipairs(quests) do
        for _, npcId in ipairs(abgeberNpcs(db, qid)) do
            local tx, ty = spawnInKarte(db, npcId, zdb, uiMap, px, py)
            if tx then
                -- Ueber Kontinente hinweg gibt GetZoneDistance nil zurueck (HBD-2.0.lua:610).
                -- Hier liegen beide Punkte in derselben Karte; nil heisst dann: die Bibliothek
                -- kennt die Zone nicht. Beides endet gleich — schweigen.
                -- ACHTUNG: frage() gibt bis zu drei Werte zurueck (GetZoneDistance liefert
                -- Abstand und zwei Deltas). Ohne die Klammern waere der zweite Wert fuer
                -- tonumber die BASIS - und "bad argument #2 (base out of range)" faellt mitten
                -- im Spiel an. Genau hier hat der Pruefstand es gefunden.
                local yd = tonumber((frage(h.GetZoneDistance, h, uiMap, px, py, uiMap, tx, ty)))
                if yd and yd >= 0 and yd <= W.MAX_YD and (not bestD or yd < bestD) then
                    bestQ, bestD, bestX, bestY = qid, yd, tx, ty
                end
            end
        end
    end
    if not bestQ then S.grund = "kein Abgeber in Reichweite"; return nil end
    local schritt = W.schrittWort(bestD, sp)
    local richtung = W.richtungWort(uiMap, px, py, bestX, bestY, sp)
    if not (schritt and richtung) then S.grund = "keine Richtung"; return nil end
    S.treffer = { quest = bestQ, yd = bestD, schritt = schritt, richtung = richtung }
    S.grund = "da"
    return bestQ, schritt, richtung
end

function W.abgabePruefe()
    abgabeGeplant = false
    if not an("abgabeweg") then W.abgabeStand.grund = "abgeschaltet"; return false end
    if imKampf() or tot() or aufTaxi() then return false end
    local t = jetzt()
    -- HOTFIX 0.16.1 (21.09.2026, Spieltest Harald): QUEST_LOG_UPDATE kommt beim Login von selbst,
    -- drei Sekunden spaeter stand der Abgabeort in Orgrimmar fest - und die LOGIN-Begruessung
    -- (Core/Start.lua, +6 s) fiel mit "abstand" durch, zweimal hintereinander. Der Gruss hat
    -- Vorfahrt; dieselbe Login-Ruhe wie in Sinne/Welle13a.lua (QUEST_LOGIN_RUHE = 60 s).
    if t < abgabeRuheBis then W.abgabeStand.grund = "Login-Ruhe"; return false end
    if t - W.letztePruefung < W.EIGEN_ABSTAND then return false end
    W.letztePruefung = t
    local qid, schritt, richtung = W.abgabeSuche()
    if not qid then return false end
    -- KEIN {quest} in den vars, und das ist Absicht: Core/Regie.lua waehlt nur Zeilen, deren
    -- Platzhalter alle gefuellt sind (Regie.lua:379-382). Die drei ALTEN Zeilen tragen {quest}
    -- und fallen damit hier heraus; die neuen tragen {schritt} und {richtung} und fallen beim
    -- alten Aufruf aus Sinne/Quests.lua heraus. So sagt keiner der beiden Wege das, was der
    -- andere schon gesagt hat — ohne eine einzige bestehende Zeile anzufassen.
    -- nurPlatzhalter haelt zusaetzlich die platzhalterfreie Zeile (die Aufnahme) aus DIESEM
    -- Aufruf heraus: sie gehoert dem Zonen-Anlass, nicht dem Schritt-Anlass.
    -- key = questId: dieselbe Drossel ("1800") wie in Sinne/Quests.lua, also sagt Lyra je
    -- Quest hoechstens einmal je halber Stunde etwas — egal, welcher der beiden Wege zuerst da ist.
    return ns.melde("QUEST_ABGABE_NAH", {
        schritt = schritt, richtung = richtung, key = qid, nurPlatzhalter = true,
    }) and true or false
end

local function abgabePlanen(verzug)
    if abgabeGeplant then return end
    abgabeGeplant = true
    local After = ns.Compat and ns.Compat.After
    if type(After) ~= "function" then abgabeGeplant = false; return end
    After(verzug, function() pcall(W.abgabePruefe) end)
end

-- ZONE_CHANGED_NEW_AREA: 12 s, also VOR den 20 s aus Sinne/Quests.lua. Das ist kein Wettlauf,
-- sondern die Rangfolge: die genauere Zeile soll zuerst da sein, die groebere wird danach von
-- derselben Drossel (Ereignis + questId) gehalten.
ns.on("ZONE_CHANGED_NEW_AREA", function() abgabePlanen(W.ZONE_VERZUG) end)
ns.on("QUEST_LOG_UPDATE", function() abgabePlanen(W.LOG_VERZUG) end)

-- =============================================================================================
-- 2  Eine Mechanik vor dem Pull (GEGNER_MECHANIK)
-- =============================================================================================
-- NPC-Typ-ID aus der GUID. Feld 6 bei Kreaturen
-- (Creature-0-server-instanz-zoneUID-NPCID-spawnUID), Muster aus Sinne/Kampf.lua:135-139.
-- Spieler-GUIDs fallen durch = nil. Das ist Grenze B (Regel 6), und sie steht als Erstes.
local function npcIdVon(unit)
    local guid = frage(UnitGUID, unit)
    if type(guid) ~= "string" then return nil end
    local art, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if (art == "Creature" or art == "Vehicle") and id then return tonumber(id) end
    return nil
end
W.npcIdVon = npcIdVon

-- Die drei Datentabellen. Gepruefter EINZELWERT statt type()=="table": eine leere oder halb
-- geladene Tabelle sieht sonst aus wie eine volle.
local function npcZauber(npcId)
    local e = feld(_G.NpcAbilitiesNpcData, npcId)
    if type(e) ~= "table" then return nil end
    local liste = feld(e, "classic_spell_ids")
    if type(liste) ~= "table" then return nil end
    return liste
end

local function prioritaet(spellId)
    return tonumber(feld(_G.NpcAbilitiesPriorityData, spellId))
end

-- Die Sprache kommt aus LYRAS Einstellung, nicht aus NpcAbilitiesOptions["SELECTED_LANGUAGE"] —
-- sonst redet Lyra Englisch, weil der Nachbar sein Tooltip-Addon so eingestellt hat
-- (Recherche 18 §2.3).
local function mechanikWort(spellId, sp)
    local tabelle = feld(_G.NpcAbilitiesAbilityData, sp)
    if type(tabelle) ~= "table" then return nil end
    local a = feld(tabelle, spellId)
    if type(a) ~= "table" then return nil end
    -- mechanic ist der Fremdbegriff, um den es geht ("Betaeubt"/"Stunned"). Er fehlt bei vielen
    -- Zaubern (deDE.lua: mechanic = nil); dann traegt der NAME dieselbe Beobachtung und bleibt
    -- eine. Alles andere (description, range, cast_time, cooldown) bleibt liegen: das steht im
    -- Tooltip und ist dort besser aufgehoben.
    local wort = feld(a, "mechanic")
    if type(wort) ~= "string" or wort == "" then wort = feld(a, "name") end
    if type(wort) ~= "string" then return nil end
    wort = wort:gsub("^%s+", ""):gsub("%s+$", "")
    if wort == "" or #wort > W.MAX_WORT then return nil end
    return wort
end

W.mechanikStand = { tabellen = false, gesagt = 0, letzte = nil, grund = "nicht versucht" }
local mechanikGesagt = {}       -- [npcId] = true, Sitzung; zusaetzlich zur Regie-Drossel

-- =============================================================================================
-- REVIEW13: DER FILTER — warum GEGNER_MECHANIK nicht auf jeden Gegner faellt
-- =============================================================================================
-- Die Zulieferung hatte KEINEN Ziel-Filter: jeder feindliche NPC mit einem Prioritaet-1-Zauber
-- loeste die Zeile aus. Recherche 18 §2.3 sagt aber ausdruecklich "Still, wenn: ... der Gegner
-- ist kein Elite/Rare/Boss" - die Zusage stand im Text und nicht im Code. Beim Leveln ist das
-- der Unterschied zwischen einer Warnung und einem Kommentar zu jedem zweiten Gnoll: die Zeile
-- ist warn/Stufe 1, die Regie laesst davon zehn in der Stunde durch (Core/Regie.lua:58-59), und
-- die verbraucht ein Spieler in zehn Minuten Feldarbeit - danach ist die Stufe-1-Schiene fuer
-- eine Stunde leer und auch eine ECHTE Warnung kommt nicht mehr.
--
-- Gefiltert wird auf ZWEI Wegen, und es reicht EINER davon:
--   * Klassifikation elite / rareelite / rare / worldboss (UnitClassification) - das ist der
--     Fall aus der Recherche.
--   * Stufe des Ziels >= eigene Stufe minus zwei. Ein Gegner, der einen nicht mehr ernsthaft
--     treffen kann, braucht keine Mechanik-Warnung; einer auf Augenhoehe schon, auch wenn er
--     kein Elite ist (in Hardcore sterben die meisten an normalen Mobs, nicht an Elites).
-- Ist die Stufe nicht rechenbar (Mainline/Forever: secret values in Instanz und Kampf -
-- ns.Compat.unitLevelLesbar gibt dort nil), entscheidet allein die Klassifikation. Sie ist
-- KEIN Kampfwert und bleibt auf allen fuenf Clients lesbar (dieselbe Begruendung wie in
-- Sinne/Kampf.lua bei GEFAHR_ELITE). Schweigen ist dann die richtige Richtung.
local function zielTaugt()
    local k = frage(UnitClassification, "target")
    if k == "elite" or k == "rareelite" or k == "rare" or k == "worldboss" then return true end
    local C = ns.Compat
    if not (C and type(C.unitLevelLesbar) == "function") then return false end
    local ziel = C.unitLevelLesbar("target")
    if type(ziel) ~= "number" then return false end
    if ziel < 0 then return true end                 -- Totenkopf: Stufe unbekannt hoch
    local ich = C.unitLevelLesbar("player")
    if type(ich) ~= "number" or ich <= 0 then return false end
    return ziel >= (ich - W.STUFE_UNTER)
end
W.zielTaugt = zielTaugt

-- REVIEW13: Sinne/Kampf.lua meldet beim SELBEN Zielwechsel GEFAHR_ELITE (warn, Stufe 2) bzw.
-- GEFAHR_STUFEN - sofort, waehrend diese Zeile 1,5 s spaeter faellt. Zwei Warnungen im Abstand
-- von anderthalb Sekunden ueber dasselbe Ziel sind genau die Doppelung, die Regel 1 verbietet;
-- gehoert wird davon ohnehin nur die erste, die zweite laeuft ihr in die Sprechblase.
-- Die Mechanik-Zeile ist dann NICHT verloren: mechanikGesagt wird erst nach Erfolg gesetzt, und
-- GEFAHR_ELITE traegt die Drossel "name-session". Beim naechsten Gegner derselben Art schweigt
-- also die Elite-Zeile, und die Mechanik kommt. Erst "Elite, nicht allein", spaeter "der
-- betaeubt" - zwei verschiedene Auskuenfte, nacheinander statt uebereinander.
local letzteGefahr = -1000
if ns.nachAusgabe then
    ns.nachAusgabe(function(id)
        if id == "GEFAHR_ELITE" or id == "GEFAHR_STUFEN" then letzteGefahr = jetzt() end
    end)
end

-- Die EINE Mechanik: hoechste Prioritaet (1 = rot), bei Gleichstand die kleinere Zauber-ID,
-- damit derselbe Gegner in derselben Sitzung nicht zweierlei heisst.
function W.mechanikVon(npcId, sp)
    local liste = npcZauber(npcId)
    if not liste then return nil end
    local besteId, bestePrio = nil, nil
    for i = 1, #liste do
        local sid = tonumber(liste[i])
        if sid then
            local p = prioritaet(sid)
            if p == 1 and (not bestePrio or sid < besteId) then besteId, bestePrio = sid, p end
        end
    end
    if not besteId then return nil end
    return mechanikWort(besteId, sp or sprache()), besteId
end

function W.zielPruefe(erwarteteId)
    if not an("gegnerMechanik") then W.mechanikStand.grund = "abgeschaltet"; return false end
    if type(_G.NpcAbilitiesNpcData) ~= "table" then
        W.mechanikStand.grund = "kein NpcAbilities"; return false
    end
    W.mechanikStand.tabellen = true
    if imKampf() or tot() then W.mechanikStand.grund = "im Kampf"; return false end
    if ruheLaeuft() then W.mechanikStand.grund = "Stillhalte"; return false end
    if not frage(UnitExists, "target") then return false end
    if frage(UnitIsPlayer, "target") then return false end            -- Grenze B, als Erstes
    if frage(UnitIsDeadOrGhost, "target") then return false end
    if not frage(UnitCanAttack, "player", "target") then return false end
    -- REVIEW13: der Ziel-Filter (siehe "DER FILTER" oben). Steht VOR der NPC-ID, weil er der
    -- billigere Test ist und die haeufigste Absage.
    if not zielTaugt() then W.mechanikStand.grund = "kein lohnendes Ziel"; return false end
    -- REVIEW13: Sinne/Kampf.lua hat gerade ueber dasselbe Ziel gewarnt - dann nicht zweimal.
    if jetzt() - letzteGefahr < W.ELITE_RUHE then
        W.mechanikStand.grund = "Kampfsinn war schneller"; return false
    end
    local id = npcIdVon("target")
    if not id then return false end
    -- Der Zielwechsel liegt W.ZIEL_VERZUG zurueck: steht dasselbe Ziel noch, schaut der Spieler
    -- es wirklich an. Hat er inzwischen angegriffen oder weitergeklickt, ist der Moment vorbei
    -- und die Zeile faellt ersatzlos aus — sie ist eine Warnung VOR dem Pull, nicht danach.
    if erwarteteId and erwarteteId ~= id then return false end
    if mechanikGesagt[id] then W.mechanikStand.grund = "schon gesagt"; return false end
    local wort = W.mechanikVon(id, sprache())
    if not wort then W.mechanikStand.grund = "nichts mit Prioritaet 1"; return false end
    -- REVIEW13: die Sitzungs-Sperre wird ERST NACH ERFOLG gesetzt. Vorher stand sie hier davor -
    -- dann haette ein Abstands- oder Budget-Drop der Regie (warn/Stufe 1 ist gebremst) den
    -- Gegnertyp fuer die ganze Sitzung still verbrannt, ohne dass ein Wort gefallen waere.
    -- Dieselbe Lehre wie in Sinne/Karte2.lua (ERBE_STERBEORT) und Sinne/Welle13d.lua.
    -- Die Regie-Drossel "npc-session" wird dabei nicht doppelt verbraucht: sie wird in
    -- Core/Regie.lua:469 erst NACH der Stufe-1-Bremse gezogen.
    if not (ns.melde("GEGNER_MECHANIK", { mechanik = wort, key = id })) then
        W.mechanikStand.grund = "Regie hat verworfen"
        return false
    end
    mechanikGesagt[id] = true
    W.mechanikStand.gesagt = W.mechanikStand.gesagt + 1
    W.mechanikStand.letzte = wort
    W.mechanikStand.grund = "da"
    return true
end

ns.on("PLAYER_TARGET_CHANGED", function()
    if not an("gegnerMechanik") then return end
    if imKampf() or tot() then return end
    local id = npcIdVon("target")
    if not id then return end
    if mechanikGesagt[id] then return end
    -- REVIEW13: der Filter schon hier, nicht erst in zielPruefe. Beim Leveln wechselt das Ziel
    -- im Sekundentakt; ohne diese Zeile stuende fuer jeden angeklickten Hasen ein Timer in der
    -- Warteschlange. zielPruefe prueft es 1,5 s spaeter trotzdem noch einmal - das Ziel kann
    -- sich inzwischen geaendert haben.
    if not zielTaugt() then return end
    local After = ns.Compat and ns.Compat.After
    if type(After) ~= "function" then return end
    After(W.ZIEL_VERZUG, function() pcall(W.zielPruefe, id) end)
end)

-- Neue Sitzung im selben Spielstart (Charakterwechsel ohne Neustart): die Liste gehoert der
-- Sitzung, nicht dem Charakter — genau wie die Regie-Drossel "npc-session".
ns.on("PLAYER_ENTERING_WORLD", function()
    W.letztePruefung = 0
    abgabeRuheBis = jetzt() + W.LOGIN_RUHE   -- HOTFIX 0.16.1: der Gruss hat Vorfahrt
end)

-- =============================================================================================
-- Status (/lyra status)
-- =============================================================================================
-- Beide Zeilen sagen AUSDRUECKLICH "fehlt", wenn das Fremd-Addon nicht da ist. Das ist die
-- Zusage aus Regel 4: kein Lua-Fehler, keine Zeile, aber eine ehrliche Auskunft auf Nachfrage.
function W.status()
    local d = de()
    local out = {}
    local S = W.abgabeStand
    local db = questieDB()
    local K2 = ns.Karte2
    local h = (K2 and type(K2.hbd) == "function") and K2.hbd() or nil
    local hbdDa = (h and type(h.GetZoneDistance) == "function") and true or false
    local quelle
    if not an("abgabeweg") then
        quelle = d and "abgeschaltet" or "switched off"
    elseif not db then
        quelle = d and "fehlt (Questie)" or "missing (Questie)"
    elseif not hbdDa then
        quelle = d and "fehlt (HereBeDragons)" or "missing (HereBeDragons)"
    else
        quelle = d and "da" or "yes"
    end
    out[#out + 1] = (d and "Weg zum Abgeber: %s - zuletzt: %s"
                       or "Way to the turn-in: %s - last: %s"):format(quelle, tostring(S.grund))
    if S.treffer then
        out[#out + 1] = (d and "  zuletzt gefunden: %s Schritt nach %s"
                            or "  last found: %s paces to the %s")
            :format(tostring(S.treffer.schritt), tostring(S.treffer.richtung))
    end
    local M = W.mechanikStand
    local mq
    if not an("gegnerMechanik") then
        mq = d and "abgeschaltet" or "switched off"
    elseif type(_G.NpcAbilitiesNpcData) ~= "table" then
        mq = d and "fehlt (NpcAbilities)" or "missing (NpcAbilities)"
    else
        mq = d and "da" or "yes"
    end
    out[#out + 1] = (d and "Mechanik vor dem Pull: %s - %d genannt, zuletzt: %s"
                       or "Mechanic before the pull: %s - %d named, last: %s")
        :format(mq, M.gesagt, tostring(M.letzte or (d and "nichts" or "nothing")))
    return out
end

-- Fuer den Pruefstand und /lyra debug: die Sitzungsliste zuruecksetzen, ohne sie oeffentlich
-- beschreibbar zu machen.
function W.vergiss()
    mechanikGesagt = {}
    W.letztePruefung = 0
    W.mechanikStand.gesagt = 0
    W.mechanikStand.letzte = nil
end
