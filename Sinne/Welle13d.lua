-- Sinne/Welle13d.lua — Welle 13d "Was woanders liegt" (Recherche 18 §2.6, §4.1 Nr. 6).
--
-- ZWEI ANLAESSE, EINE QUELLE.
--   (a) REISECHECK-Anhaengsel: vor einer Instanz fehlt ein Verbrauchsgut im Beutel, liegt aber
--       bei einem anderen EIGENEN Charakter oder in der eigenen Bank. Zwei ergaenzte Zeilen an
--       das bestehende Ereignis REISECHECK, ueber den Platzhalter {lager}.
--   (b) LAGER_ANDERSWO: beim Aufheben einer Handelsware oder eines Rezepts, von dem ein anderer
--       eigener Charakter schon welche hat. Eine Zeile, dann nie wieder fuer diese Item-ID.
--
-- DIE QUELLE IST BAGBROTHER, NICHT SYNDICATOR. Harald hat am 21.09. entschieden, den Autor von
-- Syndicator NICHT zu fragen (Recherche 18 §5, Frage 3) - damit faellt dessen API weg, obwohl sie
-- die bequemere waere. Es bleibt die SavedVariable von BagBrother, und die hat eine Eigenschaft,
-- die jede Zeile dieser Datei praegt: sie ist ein STAND VOM LETZTEN LOGOUT des anderen
-- Charakters, nicht von jetzt. Darum traegt jede Sprechzeile den Zusatz "beim letzten Mal".
-- Eine Zeile im Praesens waere schlicht gelogen (Recherche 18 §2.6, letzter Absatz).
--
-- BELEGE aus dem installierten Client ($A = Interface/AddOns), nur gelesen:
--   BrotherBags                              $A/BagBrother/BagBrother.toc  (## SavedVariables)
--   BrotherBags[realm][id] = cache           $A/BagBrother/core/api/owners.lua:105
--                                            (GetOrCreateTableEntry(GetOrCreateTableEntry(BrotherBags, realm), id))
--   Realm-Liste = GetNormalizedRealmName() + GetAutoCompleteRealms()
--                                            $A/BagBrother/core/api/owners.lua:52
--   cache[bag] = { items = {[slot]=".."}, size, link }
--                                            $A/BagBrother/core/features/caching.lua:255-273 (PopulateBag)
--   Item-String "itemID[:enchant:..][;count]"  $A/BagBrother/core/features/caching.lua:275-311 (ParseItem)
--   cache.equip / cache.mail / cache.money / cache.level
--                                            $A/BagBrother/core/features/caching.lua:20-28
--   Geschrieben wird beim Schliessen der Bank / bei Post
--                                            $A/BagBrother/core/features/caching.lua:200-213
--   GILDENBANK: BrotherBags[realm][gildenname .. "*"]
--                                            $A/BagBrother/core/api/owners.lua:69 (self:New(name..'*', realm))
--                                            Kennzeichen ist das "*" am Ende der id (owners.lua:107).
--   Bagnon haelt KEINE eigenen Gegenstandsdaten (Oberflaeche ueber BagBrother, Bagnon.toc
--   ## Dependencies: BagBrother) - deshalb wird hier ausschliesslich BrotherBags gelesen.
--
-- DIE GILDENBANK WIRD NIE BENUTZT. Sie steht in derselben Tabelle, unter derselben Realm-Ebene,
-- und ihre Faecher sehen mit {name, icon, items} fast genauso aus wie ein Taschenfach. Das
-- einzige sichere Unterscheidungsmerkmal ist das "*" in der id - und darum ist es hier die
-- ERSTE Pruefung je Besitzer, nicht die letzte. Was in einer Gildenbank liegt, haben andere
-- Spieler eingelagert (Regel 6, Recherche 18 §3). Gezaehlt wird sie trotzdem, aber nur fuer
-- /lyra status: "N Gildenbanken uebersprungen" ist der Beleg, dass der Filter greift.
--
-- KONTRAKT: kein SendChatMessage, keine geschuetzte Funktion, kein Netz, keine neuen Globals.
-- Jeder Zugriff auf BrotherBags steht in pcall; faellt er aus, ist diese Datei still, es gibt
-- keinen Lua-Fehler, und /lyra status sagt "fehlt" bzw. "unlesbar". In BagBrother wird nichts
-- geschrieben - kein Feld, kein Callback, kein hooksecurefunc.
--
-- API (nur lesend): GetTime, UnitName, UnitAffectingCombat, UnitIsDeadOrGhost,
--   GetRealmName / GetNormalizedRealmName / GetAutoCompleteRealms, GetItemInfo,
--   ns.Compat.Container (eigener Beutel), ns.Sinne.Extra.reisecheckFehlt (eigener Code).
-- Events: BAG_UPDATE_DELAYED, PLAYER_LOGIN, PLAYER_REGEN_ENABLED.
-- Neue Ereignisse: LAGER_ANDERSWO (plauder, Stufe 0). Erweitert: REISECHECK (+2 Zeilen).
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Welle13d = W
ns.Sinne.Welle13d = W

-- ---------------------------------------------------------------------------------------------
-- Voreinstellung. Core/Init.lua und UI/Settings.lua gehoeren in dieser Runde anderen Teams,
-- darum haengt der Schluessel hier an ns.DEFAULTS_ACCOUNT - auf DATEIEBENE, also lange vor
-- ADDON_LOADED und damit vor ns.initDB(). Genau das Muster aus Sinne/Welle6.lua:65.
-- Der Name sagt, was der Schalter TUT, nicht welches Fremd-Addon dahintersteckt: wer BagBrother
-- deinstalliert, soll in den Einstellungen keine tote Zeile suchen muessen (Recherche 18 §3).
-- EIN Haekchen fuer beide Anlaesse, weil es EINE Andockstelle ist: dieselbe Quelle, dieselbe
-- Ehrlichkeitsregel, dieselbe Enttaeuschung, wenn man sie nicht will.
-- ---------------------------------------------------------------------------------------------
W.SCHLUESSEL = "lagerAnderswo"
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    if ns.DEFAULTS_ACCOUNT[W.SCHLUESSEL] == nil then ns.DEFAULTS_ACCOUNT[W.SCHLUESSEL] = true end
end

-- ---------------------------------------------------------------------------------------------
-- Zahlen, und warum sie so stehen
-- ---------------------------------------------------------------------------------------------
-- BEUTEL_TAKT: BAG_UPDATE_DELAYED feuert bei JEDEM Beutelvorgang - Loot, Verkauf, Umstapeln,
--   Herstellen. Beim Leerraeumen eines Gruftlager-Stapels sind das ein Dutzend Ereignisse in
--   zwei Sekunden. Der Takt macht daraus hoechstens einen Beutel-Scan alle 3 s; alles
--   dazwischen wird nicht gezaehlt, sondern beim naechsten Scan als EINE Veraenderung gesehen.
-- INDEX_TTL: die Faecher der ANDEREN Charaktere aendern sich waehrend dieser Sitzung gar nicht
--   (geschrieben wird beim Logout des jeweiligen Charakters). Fuenf Minuten sind also grosszuegig
--   und decken nur den eigenen Bankbesuch ab, der den eigenen Bank-Teil des Index verschiebt.
-- MAX_JE_SITZUNG: die harte Obergrenze. Wer einen Abend lang Kraeuter sammelt, hoert diese Zeile
--   nicht zwanzigmal. Sechs ist gewaehlt, weil die Drossel "session" je Item-ID ohnehin greift
--   und diese Grenze nur den Fall "zwanzig verschiedene Handelswaren" abfaengt.
-- VERSUCHE_MAX: eine von der Regie verworfene Zeile (Abstand, Budget, Gruppe) wird nicht sofort
--   verbrannt - die Item-ID darf es dreimal versuchen und gilt dann als erledigt. Ohne Deckel
--   probierte derselbe Stapel Leinenstoff es bis zum Abmelden alle drei Sekunden erneut.
-- KLASSEN: 7 = Handelsware, 9 = Rezept (GetItemInfo, 12. Rueckgabe classID). Alles andere
--   schweigt - Ruestung, Waffen, Quest-Gegenstaende und Verbrauchbares sagen ueber ein Lager
--   nichts Interessantes. QUALI_MIN = 1 haelt Grau draussen.
local BEUTEL_TAKT   = 3
local INDEX_TTL     = 300
local MAX_JE_SITZUNG = 6
local VERSUCHE_MAX  = 3
local QUALI_MIN     = 1
local KLASSEN_ERLAUBT = { [7] = true, [9] = true }

-- Faecher-Nummern (Classic): 0-4 Beutel, -1 Bankfach, 5-11 Bankbeutel, -2 Schluesselbund,
-- -3 Reagenzienbank (auf spaeteren Clients). Beim EIGENEN Charakter interessiert nur die Bank -
-- was im Beutel liegt, sieht der Spieler ohne Lyra.
local BANK_FAECHER = { [-3] = true, [-1] = true, [5] = true, [6] = true, [7] = true,
                       [8] = true, [9] = true, [10] = true, [11] = true }
-- Bei einem ANDEREN Charakter zaehlt alles, was ein Fach sein KANN. Die Liste steht ausdruecklich
-- da und ist nicht "jede Zahl": eine SavedVariable, in der unter Fach -7 etwas liegt, ist Muell,
-- und Muell wird nicht gezaehlt, sondern uebergangen (dieselbe Linie wie bei einer Stueckzahl,
-- die keine positive ganze Zahl ist).
local ALLE_FAECHER = { [-3] = true, [-2] = true, [-1] = true }
for i = 0, 11 do ALLE_FAECHER[i] = true end

local function jetzt() return (GetTime and GetTime()) or 0 end
local function tot() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false end
local function imKampf() return UnitAffectingCombat and UnitAffectingCombat("player") or false end
local function de() return ns.sprache() == "de" end
local function an() return ns.Get(W.SCHLUESSEL) and true or false end
W.an = an

-- Texte fuer ns.print und fuer den Platzhalter {lager}. Gesprochene Zeilen stehen in
-- phrasen.lua, nicht hier - hier steht nur, was in eine Statuszeile oder in EINEN Platzhalter
-- muss. Core/Locale.lua gehoert einem anderen Team, darum dieselbe Bauart wie in
-- Sinne/Bruecken.lua:38 (eigene TEXT-Tabelle im File).
local TEXT = {
    de = {
        aus      = "Was woanders liegt: aus.",
        fehlt    = "Was woanders liegt: BagBrother fehlt - ich sehe nur diesen Beutel.",
        unlesbar = "Was woanders liegt: BagBrother da, aber unlesbar - ich sage dazu nichts.",
        leer     = "Was woanders liegt: BagBrother da, noch keine anderen Charaktere gespeichert.",
        da       = "Was woanders liegt: an, %d andere Charaktere, %d Sorten, Bank %d Sorten (Stand vom letzten Logout).",
        gilde    = "  Gildenbanken uebersprungen: %d (die werden nie gelesen).",
        bank     = "Deine Bank",
    },
    en = {
        aus      = "Stored elsewhere: off.",
        fehlt    = "Stored elsewhere: BagBrother missing - I only see this bag.",
        unlesbar = "Stored elsewhere: BagBrother present but unreadable - I'll say nothing about it.",
        leer     = "Stored elsewhere: BagBrother present, no other characters stored yet.",
        da       = "Stored elsewhere: on, %d other characters, %d kinds, bank %d kinds (as of last logout).",
        gilde    = "  Guild banks skipped: %d (never read).",
        bank     = "Your bank",
    },
}
local function T(k) return (TEXT[de() and "de" or "en"])[k] end

-- Verbrauchsgueter fuer das REISECHECK-Anhaengsel.
--
-- MERGE 0.16.0 (21.09.2026): hier stand bis zum Merge eine ABSCHRIFT der Item-IDs aus
-- Sinne/Extra.lua, weil diese Datei einem anderen Team gehoerte und ihre Listen nicht
-- herausreichte (Bericht 13d §5 Punkt 1). Der Merge hat X.TRANK_IDS / X.VERBAND_IDS in
-- Sinne/Extra.lua exportiert; die Abschrift ist damit weg und kann nicht mehr driften.
-- Extra.lua steht in der TOC VOR dieser Datei, gefragt wird trotzdem erst beim Aufruf und
-- hinter einer Existenzpruefung - faellt die Quelle aus, gibt es kein {lager} und der
-- Reisecheck sieht aus wie vor dieser Welle.
-- Die SCHWELLEN werden weiterhin NICHT gelesen: ob etwas fehlt, entscheidet allein
-- X.reisecheckFehlt(). Hier steht nur, WONACH dann woanders gesucht wird.
local VERBRAUCH_FELD = { potions = "TRANK_IDS", bandages = "VERBAND_IDS" }
local function verbrauchIDs(key)
    local feld = VERBRAUCH_FELD[key]
    if not feld then return nil end
    local X = ns.Sinne and ns.Sinne.Extra
    local t = X and X[feld]
    return type(t) == "table" and t or nil
end
-- "repair", "ammo" und "reagents" stehen absichtlich nicht dabei: eine kaputte Ruestung
-- repariert kein Zweitcharakter, und Munition wie Runen der Teleportation sind an Klasse bzw.
-- Beruf gebunden - "dein Magier hat Runen" hilft dem Krieger nicht.

W.stand = {
    grund = "nicht geprueft",   -- fehlt | unlesbar | leer | da
    index = nil,                -- [itemID] = { {name=..., n=...}, ... } absteigend
    bank = nil,                 -- [itemID] = n   (eigene Bank)
    gebaut = 0,
    chars = 0, gilden = 0,
    letzteBeutel = 0,
    basis = nil,                -- Beutel-Schnappschuss der letzten Messung
    gesagt = {},                -- [itemID] = true, nach erfolgreicher Zeile
    versuche = {},              -- [itemID] = Zahl der Anlaeufe
    n = 0,                      -- ausgegebene LAGER_ANDERSWO-Zeilen dieser Sitzung
}

-- ---------------------------------------------------------------------------------------------
-- Die Quelle
-- ---------------------------------------------------------------------------------------------
-- Realm-Schluessel wie BagBrother sie selbst bildet (owners.lua:52): der normalisierte eigene
-- Realm plus die verbundenen Realms. GetRealmName() kommt als Rueckfall dazu, mit entfernten
-- Leerzeichen - genau das ist die Normalisierung ("Der Abyssische Rat" -> "DerAbyssischeRat").
function W.realms()
    local out, gesehen = {}, {}
    local function rein(r)
        if type(r) ~= "string" then return end
        r = r:gsub("%s+", "")
        if r == "" or gesehen[r] then return end
        gesehen[r] = true
        out[#out + 1] = r
    end
    if GetNormalizedRealmName then local ok, r = pcall(GetNormalizedRealmName); if ok then rein(r) end end
    if GetRealmName then local ok, r = pcall(GetRealmName); if ok then rein(r) end end
    if GetAutoCompleteRealms then
        local ok, liste = pcall(GetAutoCompleteRealms)
        if ok and type(liste) == "table" then
            for _, r in ipairs(liste) do rein(r) end
        end
    end
    return out
end

-- Existenzpruefung auf EIN KONKRETES FELD, nie nur type(x) == "table" (Regel 4, Recherche 18 §3):
-- BrotherBags entsteht als { account = {} } noch vor jedem Charakter (settings.lua:15) - ein
-- blosser Typtest waere also auch bei einer voellig leeren Datenbank gruen. Gepruefte Bedingung
-- ist deshalb: unter einem unserer Realm-Schluessel liegt mindestens ein Besitzer-Cache.
-- Rueckgabe: tabelle, "da" | nil, "fehlt" | nil, "unlesbar" | nil, "leer".
function W.quelle()
    local bb = rawget(_G, "BrotherBags")
    if type(bb) ~= "table" then return nil, "fehlt" end
    local realms = W.realms()
    local gesehen = false
    for _, realm in ipairs(realms) do
        local ok, hat = pcall(function()
            local t = bb[realm]
            if type(t) ~= "table" then return false end
            for id, cache in pairs(t) do
                if type(id) == "string" and id ~= "" and type(cache) == "table" then return true end
            end
            return false
        end)
        if not ok then return nil, "unlesbar" end
        if hat then gesehen = true end
    end
    if not gesehen then return nil, "leer" end
    return bb, "da"
end

-- "itemID", "itemID:ench:g1:g2:g3", beides optional mit ";count" (caching.lua:275-311).
-- Alles, was nicht mit einer Ziffernfolge beginnt, ist KEIN Gegenstand (BagBrother legt dort
-- z. B. "battlepet:..." ab) und faellt heraus. Eine Stueckzahl, die keine positive ganze Zahl
-- ist, macht den ganzen Eintrag unbrauchbar - geraten wird nicht.
local function itemAus(s)
    if type(s) ~= "string" then return nil end
    local roh = s:match("^(%d+)")
    if not roh then return nil end
    local id = tonumber(roh)
    if not id or id <= 0 then return nil end
    local n = 1
    local zahl = s:match(";(.*)$")
    if zahl ~= nil then
        n = tonumber(zahl)
        if not n or n < 1 or n ~= math.floor(n) then return nil end
    end
    return id, n
end
W.itemAus = itemAus

-- Ein Besitzer-Cache in eine Zaehltabelle. filter ist immer gesetzt (BANK_FAECHER oder
-- ALLE_FAECHER) - ein Cache-Schluessel ausserhalb der Liste ist kein Fach und wird uebergangen.
local function cacheZaehlen(cache, filter, ziel)
    for fachNr, fach in pairs(cache) do
        if type(fachNr) == "number" and type(fach) == "table" and filter[fachNr] then
            local items = fach.items
            if type(items) == "table" then
                for _, s in pairs(items) do
                    local id, n = itemAus(s)
                    if id then ziel[id] = (ziel[id] or 0) + n end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------------------------
-- Index bauen
-- ---------------------------------------------------------------------------------------------
-- Gebaut wird in LOKALE Tabellen und erst am Ende uebernommen. Wirft irgendetwas unterwegs,
-- bleibt ein LEERER Index stehen und nicht ein halber - ein halber Index waere eine Zeile, die
-- etwas behauptet, das so nie in den Taschen stand. Ausfall ist Schweigen, nicht Raten.
function W.bauen()
    W.stand.gebaut = jetzt()
    local bb, grund = W.quelle()
    W.stand.grund = grund
    if not bb then
        W.stand.index, W.stand.bank, W.stand.chars, W.stand.gilden = {}, {}, 0, 0
        return false
    end

    local index, bank, chars, gilden = {}, {}, 0, 0
    local ichName = UnitName and select(1, UnitName("player")) or nil
    local eigenerRealm = (W.realms())[1]

    local ok = pcall(function()
        for _, realm in ipairs(W.realms()) do
            local besitzer = bb[realm]
            if type(besitzer) == "table" then
                for id, cache in pairs(besitzer) do
                    if type(id) == "string" and id ~= "" and type(cache) == "table" then
                        if id:find("*", 1, true) then
                            -- GILDENBANK. Erste Pruefung, nicht letzte. Wird gezaehlt und
                            -- danach nie wieder angefasst (Regel 6).
                            gilden = gilden + 1
                        elseif ichName and id == ichName and realm == eigenerRealm then
                            -- Ich selbst: nur die BANK. Was im Beutel liegt, sieht der Spieler.
                            cacheZaehlen(cache, BANK_FAECHER, bank)
                        else
                            local eigen = {}
                            cacheZaehlen(cache, ALLE_FAECHER, eigen)
                            local hatWas = false
                            for itemID, n in pairs(eigen) do
                                hatWas = true
                                local liste = index[itemID]
                                if not liste then liste = {}; index[itemID] = liste end
                                liste[#liste + 1] = { name = id, n = n }
                            end
                            if hatWas then chars = chars + 1 end
                        end
                    end
                end
            end
        end
        for _, liste in pairs(index) do
            table.sort(liste, function(a, b)
                if a.n ~= b.n then return a.n > b.n end
                return a.name < b.name
            end)
        end
    end)

    if not ok then
        W.stand.grund = "unlesbar"
        W.stand.index, W.stand.bank, W.stand.chars, W.stand.gilden = {}, {}, 0, 0
        ns.debug("Welle13d: BrotherBags wirft, Index bleibt leer")
        return false
    end
    W.stand.index, W.stand.bank, W.stand.chars, W.stand.gilden = index, bank, chars, gilden
    return true
end

function W.indexHolen()
    if W.stand.index and (jetzt() - W.stand.gebaut) < INDEX_TTL then return W.stand.index end
    -- Im Kampf wird nicht neu gerechnet. Ein veralteter Index ist hier belanglos (die Daten der
    -- anderen Charaktere aendern sich in dieser Sitzung ohnehin nicht), eine Rechenspitze
    -- mitten im Kampf waere es nicht.
    if imKampf() and W.stand.index then return W.stand.index end
    W.bauen()
    return W.stand.index
end

-- Der staerkste andere eigene Charakter fuer diese Item-ID. Rueckgabe: name, n | nil.
function W.woanders(itemID)
    if not an() then return nil end
    local index = W.indexHolen()
    local liste = index and index[itemID]
    if type(liste) ~= "table" or not liste[1] then return nil end
    local e = liste[1]
    if type(e.name) ~= "string" or e.name == "" then return nil end
    local n = tonumber(e.n)
    if not n or n < 1 then return nil end
    return e.name, n
end

-- Stueckzahl in der EIGENEN Bank (Stand vom letzten Bankbesuch).
function W.inBank(itemID)
    if not an() then return 0 end
    W.indexHolen()
    local n = W.stand.bank and tonumber(W.stand.bank[itemID])
    if not n or n < 1 then return 0 end
    return n
end

-- ---------------------------------------------------------------------------------------------
-- (a) REISECHECK: der Platzhalter {lager}
-- ---------------------------------------------------------------------------------------------
-- Was fehlt, entscheidet weiterhin Sinne/Extra.lua - hier wird nur nachgeschlagen, wo es sonst
-- noch liegt. X.reisecheckFehlt() ist der EINZIGE Weg dorthin (Extra.lua exportiert sie
-- ausdruecklich); die Schwellen stehen damit weiter an genau einer Stelle.
-- Rueckgabe: eine fertige Anrede fuer {lager} ("Thorgrim" / "Deine Bank") oder nil.
function W.reiseLager()
    if not an() then return nil end
    local X = ns.Sinne and ns.Sinne.Extra
    if not (X and type(X.reisecheckFehlt) == "function") then return nil end
    local ok, fehlt = pcall(X.reisecheckFehlt)
    if not ok or type(fehlt) ~= "table" then return nil end
    for _, key in ipairs(fehlt) do
        local ids = verbrauchIDs(key)
        if ids then
            local besterName, besteN, bankN = nil, 0, 0
            -- MERGE 0.16.0: X.TRANK_IDS/X.VERBAND_IDS sind MENGEN ([id] = true), keine Listen -
            -- also pairs() statt ipairs(). Die Reihenfolge ist egal: gesucht wird das Maximum.
            for itemID in pairs(ids) do
                local nm, n = W.woanders(itemID)
                if nm and n > besteN then besterName, besteN = nm, n end
                bankN = bankN + W.inBank(itemID)
            end
            -- Ein anderer Charakter schlaegt die eigene Bank: die Bank ist eine Wegstrecke,
            -- ein Zweitcharakter ist eine Entscheidung. Beides nur, wenn es wirklich da lag.
            if besterName then return besterName end
            if bankN > 0 then return T("bank") end
        end
    end
    return nil
end

-- Der Mantel um ns.melde. Genau das Muster aus Sinne/Rituale.lua:284 und Sinne/Persoenlich.lua:203:
-- REISECHECK wird in Sinne/Extra.lua gemeldet, und Extra.lua gehoert dieser Welle nicht. Der
-- Mantel legt {lager} in vars ab, sonst nichts - Drossel, Abstand, Gruppe, Anrede, Auswahl
-- bleiben unberuehrt. Ohne Mangel (vars.fehlt fehlt) passiert gar nichts, und ohne {lager} in
-- vars fallen die beiden neuen Zeilen in Core/Regie.lua waehle() von selbst aus den Kandidaten.
local gewrappt = false
local function wrappen()
    if gewrappt or type(ns.melde) ~= "function" then return end
    gewrappt = true
    local echt = ns.melde
    ns.melde = function(id, vars)
        if id == "REISECHECK" and type(vars) == "table" and vars.fehlt and vars.lager == nil then
            local ok, lager = pcall(W.reiseLager)
            if ok and type(lager) == "string" and lager ~= "" then vars.lager = lager end
        end
        return echt(id, vars)
    end
end

-- ---------------------------------------------------------------------------------------------
-- (b) LAGER_ANDERSWO
-- ---------------------------------------------------------------------------------------------
-- Nur Handelsware (7) und Rezept (9), kein Grau. Ist der Item-Cache noch kalt, liefert
-- GetItemInfo nil - dann wird geschwiegen und nicht geraten (dieselbe Regel wie beim
-- Reisecheck: "unbekannt ist kein Messwert"). Beim naechsten Aufheben ist der Cache warm.
local function taugt(itemID)
    if type(GetItemInfo) ~= "function" then return false end
    local ok, _, _, quali, _, _, _, _, _, _, _, _, klasseID = pcall(GetItemInfo, itemID)
    if not ok then return false end
    quali, klasseID = tonumber(quali), tonumber(klasseID)
    if quali == nil or klasseID == nil then return false end
    if quali < QUALI_MIN then return false end
    return KLASSEN_ERLAUBT[klasseID] and true or false
end
W.taugt = taugt

-- Der eigene Beutel als { [itemID] = Stueckzahl }. nil heisst "nicht lesbar" und ist etwas
-- anderes als eine leere Tabelle - ohne diese Unterscheidung waere ein Ladebildschirm ein
-- geleerter Beutel und der naechste Scan ein Schauer von Zeilen.
local function beutelZaehlen()
    local C = ns.Compat and ns.Compat.Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return nil end
    local t, gelesen = {}, false
    for bag = 0, 4 do
        local ok, slots = pcall(C.GetContainerNumSlots, bag)
        slots = (ok and tonumber(slots)) or 0
        if slots > 0 then gelesen = true end
        for slot = 1, slots do
            local ok2, info = pcall(C.GetContainerItemInfo, bag, slot)
            if ok2 and type(info) == "table" then
                local id = tonumber(info.itemID)
                local n = tonumber(info.stackCount) or 1
                if id and id > 0 and n > 0 then t[id] = (t[id] or 0) + n end
            end
        end
    end
    if not gelesen then return nil end
    return t
end
W.beutelZaehlen = beutelZaehlen

-- Eine Zeile fuer genau diese Item-ID. Rueckgabe: true, wenn sie wirklich herausgegangen ist.
function W.meldeLager(itemID)
    if W.stand.gesagt[itemID] then return false end
    if (W.stand.versuche[itemID] or 0) >= VERSUCHE_MAX then return false end
    if not taugt(itemID) then
        -- Kein Anlauf-Verbrauch: taugt() sagt "nie" (Grau/falsche Klasse) oder "noch nicht"
        -- (kalter Item-Cache). Beides ist kein verworfener Sprechversuch.
        return false
    end
    local name, n = W.woanders(itemID)
    if not name then return false end
    W.stand.versuche[itemID] = (W.stand.versuche[itemID] or 0) + 1
    local vars = { key = tostring(itemID), charakter = name }
    -- Hoechstens EINE Zahl je Zeile, und nur dort, wo sie die Beobachtung IST (Regel 2).
    -- Bei genau einem Stueck waere "einen" keine Beobachtung, sondern Fuellmaterial.
    if n > 1 then vars.anzahl = n end
    if ns.melde("LAGER_ANDERSWO", vars) then
        -- Erst NACH der erfolgreichen Meldung abgehakt (Lehre aus Welle 11c): haette der
        -- Regie-Abstand sie verschluckt, waere die einzige Gelegenheit still verbraucht.
        W.stand.gesagt[itemID] = true
        W.stand.n = W.stand.n + 1
        return true
    end
    return false
end

local function beutelGeprueft()
    if not an() then return end
    local t = jetzt()
    if t - W.stand.letzteBeutel < BEUTEL_TAKT then return end
    W.stand.letzteBeutel = t
    -- Im Kampf und im Tod wird nicht einmal gezaehlt. Die Basislinie faellt dabei weg, damit
    -- die Beute eines ganzen Kampfes hinterher nicht als ein Schwall neuer Gegenstaende
    -- erscheint; der erste Scan danach setzt still eine neue Basislinie.
    if tot() or imKampf() then W.stand.basis = nil; return end
    if W.stand.n >= MAX_JE_SITZUNG then return end

    local nun = beutelZaehlen()
    if not nun then return end
    local alt = W.stand.basis
    W.stand.basis = nun
    if not alt then return end       -- erste Messung ist Basislinie, nie eine Zeile

    local neu = {}
    for itemID, n in pairs(nun) do
        if n > (alt[itemID] or 0) and not W.stand.gesagt[itemID] then neu[#neu + 1] = itemID end
    end
    if #neu == 0 then return end
    table.sort(neu)                  -- deterministisch: pairs() haette hier gewuerfelt
    for _, itemID in ipairs(neu) do
        if W.meldeLager(itemID) then return end   -- hoechstens EINE Zeile je Beutelvorgang
    end
end

-- ---------------------------------------------------------------------------------------------
-- Ereignisse
-- ---------------------------------------------------------------------------------------------
ns.on("BAG_UPDATE_DELAYED", function() pcall(beutelGeprueft) end)

-- Nach dem Kampf einmal still nachziehen: die Basislinie ist weg (siehe oben), und ohne diesen
-- Anstoss stuende sie erst beim naechsten Beutelvorgang wieder. Kein Vergleich, keine Zeile.
ns.on("PLAYER_REGEN_ENABLED", function()
    if not an() then return end
    if W.stand.basis ~= nil then return end
    if not (ns.Compat and ns.Compat.After) then return end
    ns.Compat.After(2, function()
        if tot() or imKampf() or W.stand.basis ~= nil then return end
        local ok, t = pcall(beutelZaehlen)
        if ok and t then W.stand.basis = t end
    end)
end)

ns.on("PLAYER_LOGIN", function()
    wrappen()
    if not (ns.Compat and ns.Compat.After) then return end
    -- Der Index wird NICHT beim Login gebaut. Die ersten Sekunden nach dem Login gehoeren dem
    -- Spiel; und wer BagBrother nicht hat, soll fuer nichts bezahlen. Gebaut wird beim ersten
    -- Bedarf. Die Beutel-Basislinie dagegen muss frueh stehen, sonst waere der erste Loot nach
    -- dem Login eine Zeile ueber etwas, das schon vorher im Beutel lag.
    ns.Compat.After(20, function()
        if not an() then return end
        local ok, t = pcall(beutelZaehlen)
        if ok and t then W.stand.basis = t end
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- /lyra status
-- ---------------------------------------------------------------------------------------------
function W.status()
    local z = {}
    if not an() then z[1] = T("aus"); return z end
    W.indexHolen()
    local g = W.stand.grund
    if g == "fehlt" then z[1] = T("fehlt")
    elseif g == "unlesbar" then z[1] = T("unlesbar")
    elseif g == "leer" then z[1] = T("leer")
    else
        local sorten, bankSorten = 0, 0
        for _ in pairs(W.stand.index or {}) do sorten = sorten + 1 end
        for _ in pairs(W.stand.bank or {}) do bankSorten = bankSorten + 1 end
        z[1] = (T("da")):format(W.stand.chars, sorten, bankSorten)
    end
    if (W.stand.gilden or 0) > 0 then z[#z + 1] = (T("gilde")):format(W.stand.gilden) end
    return z
end

return W
