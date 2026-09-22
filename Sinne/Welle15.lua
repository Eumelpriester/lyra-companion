-- Sinne/Welle15.lua — Welle 15 "Zeilen mit Gedaechtnis" (0.18.0, 22.09.2026).
--
-- Zwei neue Zeilenfelder ("k", "einmal", "nach") bekommen ihre Regie-Logik in Core/Regie.lua
-- (waehle()/ausgeben(), "ein kleiner Block fuer gesagt"). WAS DIESE DATEI TUT: neun neue
-- wenn-Schluessel aus der eigenen Chronik/dem eigenen Client, als WRAPPER (Muster
-- Sinne/Profil.lua) - Sinne/Chronik.lua und Sinne/Leben2.lua bleiben unangetastet.
--
-- WARUM ZWEI WRAPPER STATT EINEM (die Abweichung vom woertlichen "wrappt ns.Stimmung.tags"):
-- Sinne/Profil.lua wrappt NUR ns.Stimmung.tags() - das reicht dort, weil "stil" in Leben2.lua
-- schon in der lokalen BEKANNT-Tabelle steht (REVIEW6B, Leben2.lua:312-317). Diese Tabelle ist
-- eine Lua-Local, nicht exportiert: ns.Stimmung.passt() lehnt jeden Schluessel ab, den BEKANNT
-- nicht kennt, ohne dass ein Wrapper um tags() daran irgendetwas aendern koennte. Der Auftrag
-- verbietet ausdruecklich, Leben2.lua fuer die neun neuen Schluessel anzufassen - also wird auch
-- ns.Stimmung.passt() gewrappt, nach demselben Prinzip (denselben Namen behalten, die alte
-- Funktion hinter sich herziehen). Ergebnis: Core/Regie.lua ruft weiterhin nur
-- ns.Stimmung.passt(z.wenn) und weiss nichts von dieser Datei.
--
-- DIE NEUN SCHLUESSEL (nur Beobachtung, eine Zahl je Zeile, Ausfall = Schweigen, nichts
-- Fremdes, keine fremden Spieler - docs/recherche/18-andockstellen-2026-09-21.md §3):
--   besuche       Besuche DIESER Zone (ns.Chronik DB.zonen[zone].besuche)        MIN
--   beinahe_hier  Beinahe-Tode DIESER Zone (DB.zonen[zone].beinahe)              MIN
--   beinahe       Beinahe-Tode insgesamt (#DB.beinahe)                          MIN
--   tode          Gefallene Vorgaenger im Konto (#LyraGestaltDB.erbe)           MIN
--   stufe         Charakterstufe (UnitLevel)                                    MIN
--   sitzungen     Sitzungen dieses Charakters (#DB.sitzungen)                   MIN
--   tage_weg      Tage seit der VORHERIGEN Sitzung (nur einmal je Login fest)   MIN
--   klasse        UnitClass-Token ("MAGE", "WARRIOR", ...)                      exakt
--   rasse         UnitRace-Token ("Human", "Tauren", ...)                       exakt
-- "zone" (GetRealZoneText(), exakt) haengt NICHT an der Chronik und bleibt bewusst auf den in
-- docs/phrasen-w15.json benutzten Zonen beschraenkt, deren deDE/enUS-Name identisch ist (Westfall,
-- Dun Morogh, Durotar, Mulgore, Tanaris, Feralas, Desolace, Silithus, Azshara, Teldrassil,
-- Darnassus, Orgrimmar, Loch Modan - UI/Freitext.lua:660-667 zaehlt genau diese als
-- "Abbildung auf sich selbst" auf). UI/Freitext.lua fuehrt daneben eine private ZONEN-Tausch-
-- tabelle fuer die restlichen, lokalisierungs-ungleichen Zonen; sie ist nicht exportiert, und sie
-- zu exportieren waere ein Zugriff auf eine fremde Datei, die diese Welle nicht besitzt. Ein
-- Zeilenautor, der eine lokalisierungs-ungleiche Zone in "wenn":{"zone": ...} benutzt, bekommt
-- also nur die Sprache, die er selbst getestet hat - dokumentiert, kein stiller Fehler.
--
-- KONTRAKT: kein SendChatMessage, kein RunMacro, kein CastSpell, keine geschuetzte Funktion,
-- kein Netz, keine Fremddaten, keine neue Globale, kein OnUpdate. Jeder Spiel-API-Zugriff steht
-- in pcall hinter einer Existenzpruefung. Faellt eine Quelle aus, liefert der jeweilige Schluessel
-- einfach nichts (nil) - eine Zeile mit diesem Tag schweigt dann wie bei jedem unbekannten Wert.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Welle15 = W
ns.Sinne.Welle15 = W

-- ---------------------------------------------------------------------------------------------
-- Cache: dieselbe Regel wie Sinne/Leben2.lua S.zustand() (CACHE_S) - der wenn-Filter kann in
-- einer Sekunde mehrfach gefragt werden (mehrere Kandidatenzeilen desselben Ereignisses), und
-- jede Frage einzeln ueber Chronik/Client zu rechnen waere Arbeit ohne Nutzen. 2 s reichen: kein
-- Wert hier aendert sich schneller (Zonenwechsel braucht laut Chronik.lua ohnehin einen
-- Ladebildschirm-Riegel plus 1,5 s Verzug).
local CACHE_S = 2
local cache, cacheBis = nil, 0

local function chronikDB()
    if not (ns.Chronik and ns.Chronik.stand) then return nil end
    local ok, db = pcall(ns.Chronik.stand)
    if ok and type(db) == "table" then return db end
    return nil
end

local function zoneJetzt()
    if type(_G.GetRealZoneText) ~= "function" then return nil end
    local ok, z = pcall(_G.GetRealZoneText)
    if ok and type(z) == "string" and z ~= "" then return z end
    return nil
end

local function klasseToken()
    if type(_G.UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(_G.UnitClass, "player")
    if ok and type(token) == "string" and token ~= "" then return token end
    return nil
end

local function rasseToken()
    if type(_G.UnitRace) ~= "function" then return nil end
    local ok, _, token = pcall(_G.UnitRace, "player")
    if ok and type(token) == "string" and token ~= "" then return token end
    return nil
end

local function stufeWert()
    if type(_G.UnitLevel) ~= "function" then return nil end
    local ok, lvl = pcall(_G.UnitLevel, "player")
    lvl = ok and tonumber(lvl) or nil
    if lvl and lvl > 0 then return lvl end
    return nil
end

-- Gefallene Vorgaenger im Konto. LyraGestaltDB.erbe gehoert Sinne/Erbe.lua; hier wird NUR
-- gelesen, und zwar so, dass es auch ohne geladenes Erbe.lua (die Tabelle existiert dann noch
-- nicht) nicht abstuerzt - dann sind es schlicht null Vorgaenger.
local function todeWert()
    local e = _G.LyraGestaltDB and _G.LyraGestaltDB.erbe
    if type(e) ~= "table" then return 0 end
    return #e
end

-- Tage seit der VORHERIGEN Sitzung. DB.sitzungen[#DB.sitzungen] ist die LAUFENDE Sitzung
-- (Sinne/Chronik.lua sitzungBeginnen() legt sie beim Login an bzw. setzt eine fortgesetzte
-- fort); die davor ist die vorherige. Ein /reload waehrend der Sitzung aendert daran nichts -
-- dieselbe Sitzung bleibt an derselben Stelle stehen, und "tage_weg" bleibt fuer die ganze
-- Sitzung, was es beim Login war (kein "die Tage laufen waehrend du spielst mit"-Effekt).
local function tageWegWert(db)
    if not (db and type(db.sitzungen) == "table") then return nil end
    local n = #db.sitzungen
    if n < 2 then return nil end
    local vorher, jetzt_ = db.sitzungen[n - 1], db.sitzungen[n]
    local ende = vorher and tonumber(vorher.ende)
    local start = jetzt_ and tonumber(jetzt_.start)
    if not (ende and start) or start <= ende then return nil end
    return math.floor((start - ende) / 86400)
end

local function rechne()
    local t = {}
    local db = chronikDB()
    local z = zoneJetzt()
    if db and z and type(db.zonen) == "table" then
        local e = db.zonen[z]
        if e then
            local b, n = tonumber(e.besuche), tonumber(e.beinahe)
            if b then t.besuche = b end
            if n then t.beinahe_hier = n end
        end
    end
    if db and type(db.beinahe) == "table" then t.beinahe = #db.beinahe end
    if db and type(db.sitzungen) == "table" then
        t.sitzungen = #db.sitzungen
        local tw = tageWegWert(db)
        if tw then t.tage_weg = tw end
    end
    t.tode = todeWert()
    local stufe = stufeWert(); if stufe then t.stufe = stufe end
    local klasse = klasseToken(); if klasse then t.klasse = klasse end
    local rasse = rasseToken(); if rasse then t.rasse = rasse end
    if z then t.zone = z end
    return t
end

-- Oeffentlich, fuer /lyra warum und den Pruefstand - dieselben Werte, die der wenn-Filter sieht.
function W.werte()
    local jt = (_G.GetTime and _G.GetTime()) or 0
    if cache and jt < cacheBis then return cache end
    cache = rechne()
    cacheBis = jt + CACHE_S
    return cache
end

-- MIN-Schluessel (>=) vs. exakte Schluessel - dieselbe Unterscheidung wie Leben2.lua MIN_KEYS.
local MIN = { besuche = true, beinahe_hier = true, beinahe = true, tode = true, stufe = true,
              sitzungen = true, tage_weg = true }
local MEINE = { besuche = true, beinahe_hier = true, beinahe = true, tode = true, stufe = true,
                sitzungen = true, tage_weg = true, klasse = true, rasse = true, zone = true }

-- ---------------------------------------------------------------------------------------------
-- Die zwei Wrapper. Beide laufen einmalig bei PLAYER_LOGIN (Muster Sinne/Profil.lua) - erst dann
-- steht ns.Stimmung sicher (Sinne/Leben2.lua registriert sich selbst auf PLAYER_LOGIN, die
-- TOC-Reihenfolge stellt sicher, dass Leben2.lua VOR dieser Datei laeuft, siehe unten "WO DIESE
-- DATEI STEHT"). Ein Flag verhindert doppeltes Wrappen bei einem zweiten PLAYER_LOGIN (Relog im
-- selben Prozess, wie es der Pruefstand tut).
-- ---------------------------------------------------------------------------------------------
ns.on("PLAYER_LOGIN", function()
    if ns.Stimmung and ns.Stimmung.tags and not W.tagsGewrappt then
        W.tagsGewrappt = true
        local origTags = ns.Stimmung.tags
        ns.Stimmung.tags = function(...)
            local t = origTags(...) or {}
            local eigene = W.werte()
            for k, v in pairs(eigene) do t[k] = v end
            return t
        end
    end
    -- Der zweite Wrapper: passt() statt nur tags(). Begruendung im Dateikopf ("WARUM ZWEI
    -- WRAPPER"). Er trennt "wenn" in zwei Haelften - die neun eigenen Schluessel werden HIER
    -- gegen W.werte() geprueft, der Rest geht unveraendert an den urspruenglichen passt() (der
    -- seinerseits ns.Stimmung.tags() neu liest - mit dem ERSTEN Wrapper schon dabei, ein
    -- unbekannter Schluessel bleibt fuer ihn also weiterhin unbekannt und schweigt wie bisher).
    if ns.Stimmung and ns.Stimmung.passt and not W.passtGewrappt then
        W.passtGewrappt = true
        local origPasst = ns.Stimmung.passt
        ns.Stimmung.passt = function(wenn)
            if type(wenn) ~= "table" then return true end
            local eigene, rest, hatEigene = {}, {}, false
            for k, v in pairs(wenn) do
                if MEINE[k] then eigene[k] = v; hatEigene = true else rest[k] = v end
            end
            if hatEigene then
                local t = W.werte()
                for k, v in pairs(eigene) do
                    local ist = t[k]
                    if MIN[k] then
                        if type(ist) ~= "number" or type(v) ~= "number" or ist < v then return false end
                    elseif ist ~= v then
                        return false
                    end
                end
            end
            if next(rest) == nil then return true end
            return origPasst(rest)
        end
    end
end)

-- ---------------------------------------------------------------------------------------------
-- /lyra status - Regel 4 des gemeinsamen Auftrags: eine Zeile je Quelle, "fehlt" statt Fehler.
-- ---------------------------------------------------------------------------------------------
function W.status()
    local d = (ns.sprache() == "de")
    local t = W.werte()
    local teile = {}
    for _, name in ipairs({ "besuche", "beinahe_hier", "beinahe", "tode", "stufe",
                            "sitzungen", "tage_weg", "klasse", "rasse", "zone" }) do
        if t[name] ~= nil then teile[#teile + 1] = name .. "=" .. tostring(t[name]) end
    end
    if #teile == 0 then
        return { d and "Gedaechtnis-Tags: keine (Chronik/Client noch nicht bereit)"
                   or "Memory tags: none (chronicle/client not ready yet)" }
    end
    return { (d and "Gedaechtnis-Tags: %s" or "Memory tags: %s"):format(table.concat(teile, ", ")) }
end
