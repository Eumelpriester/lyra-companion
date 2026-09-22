-- Sinne/Welle17.lua — Welle 17 "Sie fragt zurück" (0.19.0, 22.09.2026).
-- Bauplan: docs/recherche/20-gespraechsumfang-2026-09-21.md §3.1 (Welle 15a) UND
-- docs/recherche/21-lernen-entwicklung-2026-09-21.md §3 "Welle 17" — beide Berichte beschreiben
-- dasselbe Bauteil aus zwei Blickwinkeln; diese Datei vereinigt sie nach dem Wellenauftrag vom
-- 22.09.2026 (Bericht 20 §4 ist die verbindliche Datenmodell-Fassung).
--
-- WAS DIESE DATEI TUT (drei Teile):
--   1. ns.Person — das Personen-Gedaechtnis. setze/lies/alle/vergiss, je Charakter
--      (LyraGestaltDB.chronik[charKey].person) und je Konto (LyraGestaltDB.account.person).
--      W18 liest/loescht darueber (Schnittstelle unten, Abschnitt 1).
--   2. Das Angebot PERSON_FRAGE_ANGEBOT — eine Plauderzeile, hoechstens einmal je Sitzung, nur bei
--      Rast oder auf dem Taxi, nie im Kampf/Tod/Instanz, erst ab Bindungsstufe 1 ODER 5 Spielstunden.
--      Das Gespraechsfenster oeffnet sich NIE von selbst — die Zeile laedt nur ein.
--   3. Zehn Rueckfragen (person_dialog.lua liefert die Knoten) plus die zwei Leseschnittstellen,
--      ueber die die Antworten in bestehende Zeilen zurueckwirken: ein ns.melde-Mantel fuer
--      Platzhalter ({lieblingszone}, {haustier}, {lieblingsberuf} — Muster Sinne/Rituale.lua
--      {erinnerung}) und ein Doppel-Wrapper um ns.Stimmung.tags/.passt fuer die Tags "p_<schluessel>"
--      (Muster Sinne/Welle15.lua).
--
-- KONTRAKT: kein SendChatMessage, kein SendAddonMessage, kein C_ChatInfo, kein RunMacro, kein
-- CastSpell, kein ChatFrame-Print, keine neue Globale, keine Arbeit ohne Drossel in
-- OnUpdate/UNIT_AURA/BAG_UPDATE (diese Datei hat keinen dieser drei Ausloeser). Jeder Zugriff auf
-- eine Spiel-API steht in pcall hinter einer Existenzpruefung auf EIN konkretes Feld; faellt eine
-- Quelle aus, ist die Datei still — /lyra status sagt, was fehlt.
--
-- FREMDE SPIELER BLEIBEN DRAUSSEN (Regel 6, docs/recherche/18-andockstellen-2026-09-21.md §3):
-- der Haustiername kommt AUSSCHLIESSLICH aus UnitName("pet") des EIGENEN Charakters, nie aus
-- target/party/raid. Kein Freitext-Feld fuer den Namen — nur Bestaetigung ja/nein (Auftrag).
--
-- WO DIESE DATEI IN DER TOC STEHT: hinter den anderen Sinne (sie liest ns.Bindung, ns.Chronik,
-- ns.Welle13a, ns.Stimmung — alle muessen stehen). person_dialog.lua steht wie jede andere
-- *_dialog.lua-Datei zwischen welle2_dialog.lua und UI/Dialog.lua.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Welle17 = W
ns.Sinne.Welle17 = W
ns.Person = W   -- Muster Sinne/Welle16.lua: ns.Bindung == ns.Welle16 == ns.Sinne.Welle16

-- ---------------------------------------------------------------------------------------------
-- Voreinstellungen. Core/Init.lua bleibt unberuehrt (Muster Sinne/Welle13a.lua/Welle16.lua) —
-- beide Schluessel haengen auf DATEIEBENE an ns.DEFAULTS_ACCOUNT, lange vor ns.initDB().
--   personFragen  "Lyra darf mich etwas fragen." Standard AN. Aus = das Angebot kommt nie mehr,
--                 UND das Gespraechsfenster bietet keine offene Frage mehr an (Rueckfragen laufen
--                 nur noch ueber die Beantwortung schon offener Knoten, s. u.).
--   warnLauter    "Bei Gefahr lauter werden" — die Antwort auf die Frage "laut" wird HIER
--                 gespeichert (Auftrag: "setzt zusaetzlich einen setzt-Wert, Frage als Einstellung,
--                 wie Erst-Start"). Die WIRKUNG (Core/Regie.lua liest den Schluessel fuer die
--                 Lautstaerke/Uebertreibung bei Gefahr) ist NICHT Teil dieser Welle — Regie.lua
--                 gehoert einem anderen Team; der Wert wird nur ehrlich gespeichert und beantwortet
--                 (siehe Bericht §4 "Bewusst nicht gebaut").
-- ---------------------------------------------------------------------------------------------
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.personFragen == nil then D.personFragen = true end
    if D.warnLauter == nil then D.warnLauter = false end
end

local function jetzt() return (GetTime and GetTime()) or 0 end
local function an() return ns.Get("personFragen") ~= false end
local function imKampf()
    if type(_G.UnitAffectingCombat) ~= "function" then return false end
    local ok, k = pcall(_G.UnitAffectingCombat, "player")
    return (ok and k) and true or false
end
local function tot()
    if type(_G.UnitIsDeadOrGhost) ~= "function" then return false end
    local ok, t = pcall(_G.UnitIsDeadOrGhost, "player")
    return (ok and t) and true or false
end
local function inInstanz()
    if type(_G.IsInInstance) ~= "function" then return false end
    local ok, drin = pcall(_G.IsInInstance)
    return (ok and drin) and true or false
end
local function aufTaxi()
    if type(_G.UnitOnTaxi) ~= "function" then return false end
    local ok, t = pcall(_G.UnitOnTaxi, "player")
    return (ok and t) and true or false
end
local function rastet()
    if type(_G.IsResting) ~= "function" then return false end
    local ok, r = pcall(_G.IsResting)
    return (ok and r) and true or false
end
local function inGruppe()
    local ok1, g = pcall(_G.IsInGroup)
    local ok2, r = pcall(_G.IsInRaid)
    return ((ok1 and g) or (ok2 and r)) and true or false
end
local function zufall(n)
    if n <= 1 then return 1 end
    if type(math.random) ~= "function" then return 1 end
    return math.random(n)
end

-- =============================================================================================
-- 1  ns.Person — das Personen-Gedaechtnis (Auftrag §1, Bericht 20 §4)
-- =============================================================================================
-- Ebene "char"  -> LyraGestaltDB.chronik[charKey].person   (je Charakter)
-- Ebene "konto" -> LyraGestaltDB.account.person             (je Konto/Spieler)
-- Jeder Schluessel: { wert, t, quelle = "frage"|"beobachtet", n, hoch = false }. hoch bleibt in
-- dieser Welle IMMER false (Bericht 20 §6 F7: der Redakteur-Auszug liest "person" nicht vor 1.0 —
-- ein spaeteres Team darf das Feld gezielt umschalten, diese Datei tut es nicht).
W.KAPPE = 60   -- Schluessel je Ebene (Auftrag)

local function charPerson()
    if type(ns.char) ~= "table" or not ns.charKey then
        if ns.initDB then pcall(ns.initDB) end
    end
    if type(_G.LyraGestaltDB) ~= "table" or not ns.charKey then return nil end
    LyraGestaltDB.chronik = LyraGestaltDB.chronik or {}
    local c = LyraGestaltDB.chronik[ns.charKey]
    if type(c) ~= "table" then c = {}; LyraGestaltDB.chronik[ns.charKey] = c end
    if type(c.person) ~= "table" then c.person = {} end
    return c.person
end

local function kontoPerson()
    if type(_G.LyraGestaltDB) ~= "table" then
        if ns.initDB then pcall(ns.initDB) end
    end
    if type(_G.LyraGestaltDB) ~= "table" then return nil end
    LyraGestaltDB.account = LyraGestaltDB.account or {}
    if type(LyraGestaltDB.account.person) ~= "table" then LyraGestaltDB.account.person = {} end
    return LyraGestaltDB.account.person
end

-- ebene: "konto" -> Kontotabelle, alles andere (nil, "char", ...) -> Charaktertabelle.
local function speicher(ebene)
    if ebene == "konto" then return kontoPerson() end
    return charPerson()
end
W.speicher = speicher   -- fuer den Pruefstand

local function zaehleEintraege(p)
    local n = 0
    for _ in pairs(p) do n = n + 1 end
    return n
end

-- ns.Person.setze(schluessel, wert, quelle, ebene, n) -> true/false
--   schluessel  Text, nicht leer
--   wert        beliebig (Auswahlwert oder Freitext); Freitext-Antworten (z. B. "haustier") tragen
--               hier trotzdem quelle = "frage" — sie werden nur nie hoch = true (siehe oben)
--   quelle      "frage" (Standard) oder "beobachtet"
--   ebene       "char" (Standard) oder "konto"
--   n           optional: fuer quelle = "beobachtet" die Zahl der Belege (Aufrufer liefert sie,
--               z. B. Besuche der meistbesuchten Zone); fuer "frage" zaehlt setze() die
--               Antworten auf denselben Schluessel selbst mit (1, 2, 3, ... bei "Ich hab's mir
--               anders ueberlegt").
function W.setze(schluessel, wert, quelle, ebene, n)
    if type(schluessel) ~= "string" or schluessel == "" then return false end
    local p = speicher(ebene)
    if not p then return false end
    quelle = (quelle == "beobachtet") and "beobachtet" or "frage"
    if p[schluessel] == nil then
        if zaehleEintraege(p) >= W.KAPPE then return false end   -- Deckel: nur NEUE Schluessel sperrt er
    end
    local vorher = p[schluessel]
    local zaehler = tonumber(n)
    if not zaehler then
        zaehler = (type(vorher) == "table" and tonumber(vorher.n) or 0) + 1
    end
    p[schluessel] = {
        wert = wert,
        t = (type(time) == "function" and time()) or 0,
        quelle = quelle,
        n = zaehler,
        hoch = false,
    }
    return true
end

-- ns.Person.lies(schluessel, ebene) -> wert, eintrag (beide nil, wenn unbekannt)
function W.lies(schluessel, ebene)
    local p = speicher(ebene)
    if not p or type(schluessel) ~= "string" then return nil end
    local e = p[schluessel]
    if type(e) ~= "table" then return nil end
    return e.wert, e
end

-- ns.Person.alle(ebene) -> flache Kopie EINER Ebene, ODER ohne Argument { char = ..., konto = ... }
-- fuer W18 ("/lyra weisst"). Kopien, damit W18 nicht versehentlich die lebende Tabelle veraendert.
local function kopie(p)
    local out = {}
    if type(p) == "table" then for k, v in pairs(p) do out[k] = v end end
    return out
end
function W.alle(ebene)
    if ebene == "char" or ebene == "konto" then return kopie(speicher(ebene)) end
    return { char = kopie(charPerson()), konto = kopie(kontoPerson()) }
end

-- ns.Person.vergiss(schluesselOderAlles, ebene) — W18 ruft es ("/lyra vergiss antworten" u. a.).
--   vergiss()                 loescht ALLES, beide Ebenen
--   vergiss("alles")          dasselbe
--   vergiss("alles", "char")  loescht nur die Charakter-Ebene
--   vergiss("wasser")         loescht den Schluessel "wasser" auf BEIDEN Ebenen (er steht ohnehin
--                             nur auf einer; das ist billiger als vorher nachzuschauen, wo)
--   vergiss("wasser","konto") loescht ihn nur dort
function W.vergiss(schluesselOderAlles, ebene)
    local alles = (schluesselOderAlles == nil or schluesselOderAlles == "alles")
    if ebene == "char" or ebene == "konto" then
        local p = speicher(ebene)
        if not p then return false end
        if alles then
            for k in pairs(p) do p[k] = nil end
        else
            p[schluesselOderAlles] = nil
        end
        return true
    end
    local p1, p2 = charPerson(), kontoPerson()
    if alles then
        if p1 then for k in pairs(p1) do p1[k] = nil end end
        if p2 then for k in pairs(p2) do p2[k] = nil end end
    else
        if p1 then p1[schluesselOderAlles] = nil end
        if p2 then p2[schluesselOderAlles] = nil end
    end
    return true
end

-- =============================================================================================
-- 2  Beobachtete Werte — aus der Chronik ableitbar, quelle = "beobachtet" (Auftrag §1)
-- =============================================================================================
-- Drei Werte, alle aus Daten, die ohnehin gefuehrt werden. Gerechnet wird EINMAL je Login (kein
-- Ticker, kein OnUpdate) — das reicht: keiner dieser Werte aendert sich schneller als eine Sitzung.
W.MIND_BELEGE = 5   -- Bericht 20 §4 "keine Zahl, keine Zeile" — Vorschlag ">= 5" wird uebernommen

local function chronikStand()
    if not (ns.Chronik and ns.Chronik.stand) then return nil end
    local ok, db = pcall(ns.Chronik.stand)
    if ok and type(db) == "table" then return db end
    return nil
end

-- Top-N Zonen dieses Charakters nach Besuchen, absteigend. Eigenstaendig (nicht auf Welle15.lua
-- angewiesen — die Welle koennte fehlen), liest nur ns.Chronik.stand().
local function topZonen(n)
    local db = chronikStand()
    local aus = {}
    if not (db and type(db.zonen) == "table") then return aus end
    local liste = {}
    for zone, e in pairs(db.zonen) do
        local b = tonumber(e and e.besuche) or 0
        if b > 0 then liste[#liste + 1] = { zone = zone, besuche = b } end
    end
    table.sort(liste, function(a, b) return a.besuche > b.besuche end)
    for i = 1, math.min(n, #liste) do aus[#aus + 1] = liste[i] end
    return aus
end
W.topZonen = topZonen

-- Bucket-Tabelle wie Sinne/Leben2.lua (frueh/tag/abend/nacht/spaet) — hier nachgebaut, weil die
-- Tabelle in Leben2.lua lokal und nicht exportiert ist (dieselbe Lage wie Sinne/Welle15.lua ueber
-- "stil"). Eigene Kopie, kein Zugriff auf eine fremde Datei.
local function zeitEimer(h)
    if h >= 5 and h <= 9 then return "frueh" end
    if h >= 10 and h <= 17 then return "tag" end
    if h >= 18 and h <= 21 then return "abend" end
    if h == 22 or h == 23 or h == 0 then return "nacht" end
    return "spaet"
end

local function meistgespielteZeit()
    local db = chronikStand()
    if not (db and type(db.sitzungen) == "table") then return nil, 0 end
    local eimer = {}
    local gesamt = 0
    for _, s in ipairs(db.sitzungen) do
        local start = tonumber(s and s.start)
        if start and type(date) == "function" then
            local ok, h = pcall(function() return tonumber(date("%H", start)) end)
            if ok and h then
                local e = zeitEimer(h)
                eimer[e] = (eimer[e] or 0) + 1
                gesamt = gesamt + 1
            end
        end
    end
    local best, bestN = nil, 0
    for e, n in pairs(eimer) do if n > bestN then best, bestN = e, n end end
    return best, gesamt
end

local function beobachteteWerteBerechnen()
    -- Meistbesuchte Zone (char-Ebene): eigener Schluessel "meistzone" — NICHT "lieblingszone",
    -- die bleibt der Frage vorbehalten. Widerspruch zwischen beiden ist eine spaetere Zeile
    -- (Auftrag: "spaeter"), diese Welle baut nur die zwei getrennten Werte.
    local top = topZonen(1)
    if top[1] and top[1].besuche >= W.MIND_BELEGE then
        W.setze("meistzone", top[1].zone, "beobachtet", "char", top[1].besuche)
    end
    -- Meistgespielte Tageszeit (konto-Ebene: eine Gewohnheit des Spielers, nicht des Charakters).
    local zeit, belege = meistgespielteZeit()
    if zeit and belege >= W.MIND_BELEGE then
        W.setze("meistzeit", zeit, "beobachtet", "konto", belege)
    end
    -- Klasse (char-Ebene): direkt gelesen, kein Zaehlwert noetig — n = 1 (eine sichere Quelle).
    if type(_G.UnitClass) == "function" then
        local ok, _, token = pcall(_G.UnitClass, "player")
        if ok and type(token) == "string" and token ~= "" then
            W.setze("klasse", token, "beobachtet", "char", 1)
        end
    end
end
W.beobachteteWerteBerechnen = beobachteteWerteBerechnen   -- fuer den Pruefstand

-- =============================================================================================
-- 3  Tags "p_<schluessel>" — Doppel-Wrapper um ns.Stimmung.tags/.passt (Muster Sinne/Welle15.lua)
-- =============================================================================================
-- Anders als Welle15.lua (fester Schluesselsatz) sind die Person-Schluessel DYNAMISCH (jede
-- Antwort ein neuer Schluessel) — der Filter erkennt sie am Praefix "p_", nicht an einer festen
-- Liste. Alle Werte sind exakte Vergleiche (Strings/Booleans aus einer festen Knopfauswahl); es
-- gibt keine numerische MIN-Semantik zu uebernehmen wie bei Welle15.lua.
--
-- EIN abgeleiteter Tag zusaetzlich zum reinen Durchreichen: "p_in_lieblingszone" (Boolean) —
-- aktuelle Zone == die per Frage gemerkte Lieblingszone. Das ist der Haken, an dem "Zone-
-- Rueckkehr in die Lieblingszone" (Auftrag §3) haengt, OHNE dass eine Katalogzeile den
-- Zonennamen selbst im wenn tragen muesste (der ist ja je Spieler verschieden).
local function personWerte()
    local t = {}
    local pkonto = kontoPerson()
    if type(pkonto) == "table" then
        for k, e in pairs(pkonto) do if type(e) == "table" then t["p_" .. k] = e.wert end end
    end
    local pchar = charPerson()
    if type(pchar) == "table" then
        for k, e in pairs(pchar) do if type(e) == "table" then t["p_" .. k] = e.wert end end
    end
    local lz = pchar and pchar.lieblingszone and pchar.lieblingszone.wert
    if type(lz) == "string" and lz ~= "" and lz ~= "andere" and type(_G.GetRealZoneText) == "function" then
        local ok, z = pcall(_G.GetRealZoneText)
        if ok and type(z) == "string" then t.p_in_lieblingszone = (z == lz) end
    end
    return t
end
W.werte = personWerte   -- fuer /lyra warum und den Pruefstand

local function tagsUndPasstWrappen()
    if W.tagsGewrappt and W.passtGewrappt then return end
    if not (ns.Stimmung and type(ns.Stimmung.tags) == "function" and type(ns.Stimmung.passt) == "function") then
        return
    end
    if not W.tagsGewrappt then
        W.tagsGewrappt = true
        local origTags = ns.Stimmung.tags
        ns.Stimmung.tags = function(...)
            local t = origTags(...) or {}
            local eigene = personWerte()
            for k, v in pairs(eigene) do t[k] = v end
            return t
        end
    end
    if not W.passtGewrappt then
        W.passtGewrappt = true
        local origPasst = ns.Stimmung.passt
        ns.Stimmung.passt = function(wenn)
            if type(wenn) ~= "table" then return origPasst(wenn) end
            local eigene, rest, hatEigene = {}, {}, false
            for k, v in pairs(wenn) do
                if k:sub(1, 2) == "p_" then eigene[k] = v; hatEigene = true else rest[k] = v end
            end
            if hatEigene then
                local t = personWerte()
                for k, v in pairs(eigene) do
                    if t[k] ~= v then return false end
                end
            end
            if next(rest) == nil then return true end
            return origPasst(rest)
        end
    end
end
W.tagsUndPasstWrappen = tagsUndPasstWrappen   -- fuer den Pruefstand: erneut aufrufbar (idempotent)

-- =============================================================================================
-- 4  Platzhalter — ns.melde-Mantel (Muster Sinne/Rituale.lua {erinnerung})
-- =============================================================================================
-- {lieblingszone}, {haustier}, {lieblingsberuf}: NUR fuer die Ereignisse, die docs/phrasen-w17.json
-- mit einer platzhaltertragenden Zeile "ergaenzt" (ZONE_ERINNERUNG, LEERLAUF) bzw. das neue
-- Ereignis PERSON_HAUSTIER_DA. Core/Regie.lua zeigt eine platzhaltertragende Zeile ohnehin nur,
-- wenn ihr Platzhalter gefuellt ist — fehlt der Wert, bleibt die Variable einfach leer.
local PLATZHALTER_IDS = { LEERLAUF = true, ZONE_ERINNERUNG = true, PERSON_HAUSTIER_DA = true }
local meldeGewrappt = false
local function meldeWrappen()
    if meldeGewrappt or type(ns.melde) ~= "function" then return end
    meldeGewrappt = true
    local original = ns.melde
    ns.melde = function(id, vars)
        if PLATZHALTER_IDS[id] then
            vars = vars or {}
            if vars.lieblingszone == nil then
                local w = W.lies("lieblingszone", "char")
                if type(w) == "string" and w ~= "" and w ~= "andere" then vars.lieblingszone = w end
            end
            if vars.lieblingsberuf == nil then
                local w = W.lies("lieblingsberuf", "char")
                if type(w) == "string" and w ~= "" and w ~= "keiner" then vars.lieblingsberuf = w end
            end
            if vars.haustier == nil then
                local w = W.lies("haustier", "char")
                if type(w) == "string" and w ~= "" then vars.haustier = w end
            end
        end
        return original(id, vars)
    end
end

-- =============================================================================================
-- 5  Der Fragenkatalog — Reihenfolge ist Prioritaet (Auftrag §2, ~10 Fragen)
-- =============================================================================================
-- Jeder Eintrag: schluessel (Person-Schluessel), ebene ("char"|"konto"), knoten (Id in
-- person_dialog.lua), optional verfuegbar() (Zusatzbedingung, z. B. "nur mit eigenem Tier").
local function eigenesTierDa()
    if type(_G.UnitExists) ~= "function" then return false end
    local ok, da = pcall(_G.UnitExists, "pet")
    return (ok and da) and true or false
end
W.eigenesTierDa = eigenesTierDa

local function spitznameVorschlag()
    if not (ns.Bindung and type(ns.Bindung.spitzname) == "function") then return nil end
    local ok, s = pcall(ns.Bindung.spitzname)
    if ok and type(s) == "string" and s ~= "" then return s end
    return nil
end
W.spitznameVorschlag = spitznameVorschlag

W.FRAGEN = {
    { schluessel = "lieblingszone", ebene = "char",  knoten = "person_frag_lieblingszone" },
    { schluessel = "wasser",        ebene = "konto", knoten = "person_frag_wasser" },
    { schluessel = "haustier",      ebene = "char",  knoten = "person_frag_haustier",
      verfuegbar = eigenesTierDa },
    { schluessel = "lieblingsberuf",ebene = "char",  knoten = "person_frag_lieblingsberuf" },
    { schluessel = "tageszeit",     ebene = "konto", knoten = "person_frag_tageszeit" },
    { schluessel = "spitzname",     ebene = "konto", knoten = "person_frag_spitzname",
      verfuegbar = function() return spitznameVorschlag() ~= nil end },
    { schluessel = "mut",           ebene = "char",  knoten = "person_frag_mut" },
    { schluessel = "ziel",          ebene = "char",  knoten = "person_frag_ziel" },
    { schluessel = "allein",        ebene = "konto", knoten = "person_frag_allein" },
    { schluessel = "laut",          ebene = "konto", knoten = "person_frag_laut" },
}

function W.naechsteFrage()
    for _, f in ipairs(W.FRAGEN) do
        if W.lies(f.schluessel, f.ebene) == nil then
            if not f.verfuegbar or f.verfuegbar() then return f end
        end
    end
    return nil
end
function W.hatOffeneFrage() return an() and W.naechsteFrage() ~= nil end

-- =============================================================================================
-- 6  "Lass gut sein" — zweimal, dann aus (Auftrag §2, Bericht 21 "FRAGE_AN")
-- =============================================================================================
local function lassGutSpeicher()
    if type(_G.LyraGestaltDB) ~= "table" then
        if ns.initDB then pcall(ns.initDB) end
    end
    if type(_G.LyraGestaltDB) ~= "table" then return nil end
    LyraGestaltDB.account = LyraGestaltDB.account or {}
    local a = LyraGestaltDB.account
    a.personLassGutSein = math.max(0, tonumber(a.personLassGutSein) or 0)
    return a
end
W.LASS_GUT_SCHWELLE = 2

-- Rueckgabe: true, wenn das Haekchen mit DIESEM Klick auf AUS gegangen ist (Schwelle erreicht).
function W.lassGutSein()
    local a = lassGutSpeicher()
    if not a then return false end
    a.personLassGutSein = a.personLassGutSein + 1
    if a.personLassGutSein >= W.LASS_GUT_SCHWELLE then
        ns.Set("personFragen", false)
        return true
    end
    return false
end

-- =============================================================================================
-- 7  Das Angebot PERSON_FRAGE_ANGEBOT — Muster Sinne/Welle14e.lua W.angebot()
-- =============================================================================================
W.angebotSitzung = false
W.angebotNachhol = false
W.angebotZeit = 0          -- GetTime(), wann die Einladung zuletzt WIRKLICH gesprochen wurde
W.RECHTSKLICK_FENSTER = 120 -- s: wie lange danach der naechste Rechtsklick auf die Frage zielt
W.MIND_STUNDEN = 5

local function stunden()
    local ok, s = pcall(function() return tonumber(ns.db and ns.db.spielzeit) end)
    if not (ok and s) then return 0 end
    return s / 3600
end

local function bindungOderStunden()
    if ns.Bindung and type(ns.Bindung.stufe) == "function" then
        local ok, s = pcall(ns.Bindung.stufe)
        if ok and type(s) == "number" and s >= 1 then return true end
    end
    return stunden() >= W.MIND_STUNDEN
end

-- darfFenster(): die Riegel, die auch fuer das GEOEFFNETE Fenster gelten (aktion, Rechtsklick,
-- Menue, Intent) — enger als darfAngebot() (das Angebot verlangt zusaetzlich Rast/Taxi/Anlass).
local function darfFenster()
    if imKampf() or tot() then return false end
    return true
end
W.darfFenster = darfFenster

local function darfAngebot()
    if not an() then return false end
    if ns.stillModus then return false end
    local preset = ns.Get("gespraechig")
    if preset == "still" or preset == "wenig" then return false end
    if not darfFenster() then return false end
    if inInstanz() then return false end
    if inGruppe() and ns.Get("gruppeSchweigen") ~= false then return false end
    if not bindungOderStunden() then return false end
    if not W.hatOffeneFrage() then return false end
    return true
end
W.darfAngebot = darfAngebot

local function anlass()
    if aufTaxi() then return "taxi" end
    if rastet() then return "rast" end
    return nil
end
W.anlass = anlass

function W.angebot()
    if W.angebotSitzung then return false end
    if not darfAngebot() then return false end
    if not anlass() then return false end
    if not ns.melde then return false end
    local ok, durch = pcall(ns.melde, "PERSON_FRAGE_ANGEBOT")
    if ok and durch then
        W.angebotSitzung = true
        return true
    end
    -- Nur ein Abstand-Drop bekommt einen zweiten Versuch, und nur einen (Muster Welle14e/Welle13a).
    local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
    local nurAbstand = d and d[2] == "PERSON_FRAGE_ANGEBOT" and d[1] == "abstand"
    if not nurAbstand or W.angebotNachhol or not (ns.Compat and type(ns.Compat.After) == "function") then
        W.angebotSitzung = true
        return false
    end
    W.angebotNachhol = true
    local rest = 0
    if ns.Regie and ns.Regie.abstandRest then
        local okR, r = pcall(ns.Regie.abstandRest)
        if okR and type(r) == "number" then rest = r end
    end
    ns.Compat.After(math.max(2, math.min(rest + 1, 180)), function()
        if not (darfAngebot() and anlass()) then W.angebotSitzung = true; return end
        pcall(W.angebot)
    end)
    return false
end

-- Merkt sich, WANN die Einladung wirklich zu hoeren war (nicht bei einer Probe /lyra test —
-- Proben schreiben nichts, dieselbe Wache wie Sinne/Welle16.lua bei HP20/Meilensteinen).
ns.nachAusgabe(function(id, _, vars)
    if vars and vars.test then return end
    if id == "PERSON_FRAGE_ANGEBOT" then W.angebotZeit = jetzt() end
end)

ns.on("PLAYER_UPDATE_RESTING", function()
    if not rastet() then return end
    if not (ns.Compat and type(ns.Compat.After) == "function") then return end
    ns.Compat.After(6, function()
        if not rastet() then return end
        pcall(W.angebot)
    end)
end)
ns.on("PLAYER_CONTROL_LOST", function()
    if not aufTaxi() then return end
    if not (ns.Compat and type(ns.Compat.After) == "function") then return end
    ns.Compat.After(6, function()
        if not aufTaxi() then return end
        pcall(W.angebot)
    end)
end)

-- =============================================================================================
-- 8  PERSON_HAUSTIER_DA — eigenstaendig ausgeloest (natives UNIT_PET), keine fremde Datei
-- =============================================================================================
local haustierZuletzt = -100000
W.HAUSTIER_ABSTAND = 1800   -- s: 30 min, ausser der Katalog-Drossel eine zusaetzliche Bremse

ns.on("UNIT_PET", function(unit)
    if unit ~= nil and unit ~= "player" then return end
    if not eigenesTierDa() then return end
    if imKampf() or tot() then return end
    local wert = W.lies("haustier", "char")
    if type(wert) ~= "string" or wert == "" then return end   -- kein bestaetigter Name: still
    local t = jetzt()
    if t - haustierZuletzt < W.HAUSTIER_ABSTAND then return end
    if not ns.melde then return end
    local ok, durch = pcall(ns.melde, "PERSON_HAUSTIER_DA", { haustier = wert })
    if ok and durch then haustierZuletzt = t end
end)

-- =============================================================================================
-- 9  Dialog — Knoten fuellen, Aktionen registrieren (Muster Sinne/Welle14e.lua)
-- =============================================================================================
local knotenIndex
local function knotenNachId(id)
    local d = _G.LyraGestalt_Dialog
    if type(d) ~= "table" then return nil end
    if not knotenIndex then
        knotenIndex = {}
        for _, k in ipairs(d.knoten or {}) do knotenIndex[k.id] = k end
    end
    return knotenIndex[id]
end
local function setzeKnopf(knotenId, i, textDe, textEn, merkt, bedingung)
    local k = knotenNachId(knotenId)
    if not (k and k.antworten and k.antworten[i]) then return false end
    k.antworten[i].text = { de = textDe, en = textEn }
    k.antworten[i].merkt = merkt
    k.antworten[i].bedingung = bedingung
    return true
end

local TEXT_ANDERE = { de = "Anderswo.", en = "Somewhere else." }
local TEXT_KEIN_BERUF = { de = "Kein Favorit.", en = "No favorite." }
local TEXT_SPITZNAME_JA = { de = "Ja, das passt.", en = "Yes, that fits." }

-- Fuellt die drei dynamischen Frage-Knoten (Zone/Beruf/Spitzname), je vor dem Zeigen.
local function fuelleLieblingszone()
    local top = topZonen(2)
    for i = 1, 2 do
        local e = top[i]
        if e then
            setzeKnopf("person_frag_lieblingszone", i, e.zone, e.zone,
                { schluessel = "lieblingszone", wert = e.zone, ebene = "char" }, nil)
        else
            setzeKnopf("person_frag_lieblingszone", i, "", "", nil, "person_leer")
        end
    end
end

local function berufeEigene()
    local W13 = ns.Welle13a
    if not (W13 and type(W13.berufeLesen) == "function") then return {} end
    local ok, liste = pcall(W13.berufeLesen)
    if not (ok and type(liste) == "table") then return {} end
    local gesehen, aus = {}, {}
    for _, b in ipairs(liste) do
        if type(b) == "table" and type(b.name) == "string" and b.name ~= "" and not gesehen[b.name] then
            gesehen[b.name] = true
            aus[#aus + 1] = b.name
            if #aus >= 2 then break end
        end
    end
    return aus
end

local function fuelleLieblingsberuf()
    local berufe = berufeEigene()
    for i = 1, 2 do
        local name = berufe[i]
        if name then
            setzeKnopf("person_frag_lieblingsberuf", i, name, name,
                { schluessel = "lieblingsberuf", wert = name, ebene = "char" }, nil)
        else
            setzeKnopf("person_frag_lieblingsberuf", i, "", "", nil, "person_leer")
        end
    end
end

local function fuelleSpitzname(vorschlag)
    setzeKnopf("person_frag_spitzname", 1, TEXT_SPITZNAME_JA.de, TEXT_SPITZNAME_JA.en,
        { schluessel = "spitzname", wert = vorschlag, ebene = "konto" }, nil)
end

-- Die naechste Frage bestimmen und den passenden Knoten (+ vars) liefern. Von drei Stellen genutzt:
-- Intent, Menue-Eintrag und der Rechtsklick-Sonderfall (Abschnitt 10).
local function starten()
    if not darfFenster() then return "person_frag_nicht_jetzt" end
    if not an() then return "person_frag_nicht_jetzt" end
    local f = W.naechsteFrage()
    if not f then return "person_frag_leer" end
    local vars = nil
    if f.schluessel == "lieblingszone" then
        fuelleLieblingszone()
    elseif f.schluessel == "lieblingsberuf" then
        fuelleLieblingsberuf()
    elseif f.schluessel == "haustier" then
        local ok, name = pcall(_G.UnitName, "pet")
        vars = { haustier = (ok and type(name) == "string" and name ~= "") and name or "?" }
    elseif f.schluessel == "spitzname" then
        local vorschlag = spitznameVorschlag() or "?"
        fuelleSpitzname(vorschlag)
        vars = { spitzname = vorschlag }
    end
    return f.knoten, vars
end
W.starten = starten   -- fuer den Pruefstand

-- ns.Bindung.antwort() nach JEDER beantworteten Frage (Auftrag §2). "beantwortet" heisst: ein
-- Wert wurde tatsaechlich per Klick GESCHRIEBEN — dieselbe Existenzpruefung, die ns.Bindung.antwort
-- selbst schon vorschreibt ("nur nach einer ECHTEN Spielerantwort").
local function nachAntwort()
    if ns.Bindung and type(ns.Bindung.antwort) == "function" then pcall(ns.Bindung.antwort) end
    return "person_dank_" .. zufall(3)
end

local function aktionenRegistrieren()
    if not (ns.Dialog and type(ns.Dialog.aktionen) == "table") then return false end
    local A = ns.Dialog.aktionen
    A.person_frag_start = starten
    -- Geteilte Quittung fuer alle Fragen mit STATISCHEM merkt (mut/ziel/allein/tageszeit/wasser/
    -- laut/lieblingszone/lieblingsberuf/spitzname-nein): UI/Dialog.lua hat den Wert schon ueber
    -- "merkt" geschrieben, BEVOR die Aktion laeuft (D.antwort() Reihenfolge: setzt/merkt, dann
    -- Aktion). Diese Aktion muss den Schluessel also nicht kennen.
    A.person_registriert = nachAntwort
    -- Haustier "Ja": der Wert ist dynamisch (der Name kommt frisch aus UnitName("pet")) und kann
    -- darum nicht als statisches "merkt" im Knoten stehen.
    A.person_haustier_ja = function()
        local ok, name = pcall(_G.UnitName, "pet")
        local n = (ok and type(name) == "string") and name or nil
        if not n or n == "" or #n > 20 then n = nil end   -- Muell-/Laengenriegel
        W.setze("haustier", n or false, "frage", "char")
        return nachAntwort()
    end
    A.person_lass_gut_sein = function()
        if W.lassGutSein() then return "person_lass_gut_sein_aus" end
        return "person_lass_gut_sein_1"
    end
    if type(ns.Dialog.bedingungen) == "table" and not ns.Dialog.bedingungen.person_leer then
        ns.Dialog.bedingungen.person_leer = function() return false end
    end
    W.dialogRegistriert = true
    ns.debug("Welle17: Dialog-Aktionen registriert")
    return true
end
W.aktionenRegistrieren = aktionenRegistrieren

-- =============================================================================================
-- 10  Einstiege: /lyra <intent>, Menue-Eintrag, Rechtsklick-Sonderfall
-- =============================================================================================
-- Der Rechtsklick selbst bleibt UI/Dialog.lua D.oeffneKontext() — diese Datei darf die Funktion
-- nicht aendern (Auftrag: nur die Auswertung von "merkt" ist erlaubt). Die Anbindung ist darum ein
-- FERTIGER, isoliert lauffaehiger Baustein: rechtsklickAngebot() liefert die Zielknoten-Id, WENN
-- kuerzlich (RECHTSKLICK_FENSTER) eine Einladung wirklich gesprochen wurde und noch eine Frage
-- offen ist — der Koordinator traegt den Drei-Zeilen-Diff aus dem Bericht (Baustein g) in
-- D.oeffneKontext() ein. Ohne diesen Diff bleiben Intent und Menue-Eintrag der Weg zur Frage.
function W.rechtsklickAngebot()
    if W.angebotZeit <= 0 then return nil end
    if (jetzt() - W.angebotZeit) > W.RECHTSKLICK_FENSTER then return nil end
    W.angebotZeit = 0   -- verbraucht: der naechste Rechtsklick landet wieder normal
    if not darfFenster() then return nil end
    if not W.naechsteFrage() then return nil end
    return starten()
end

function W.oeffne()
    if not (ns.Dialog and type(ns.Dialog.zeigeKnoten) == "function") then return false end
    aktionenRegistrieren()
    local id, vars = starten()
    if not id then return false end
    local ok = pcall(ns.Dialog.zeigeKnoten, id, vars)
    return ok and true or false
end

function W.menueEintrag()
    if not W.hatOffeneFrage() then return nil end
    if not darfFenster() then return nil end
    if not (ns.Dialog and type(ns.Dialog.zeigeKnoten) == "function") then return nil end
    local L = ns.L and ns.L["Ask me something"]
    local label = L or ((ns.sprache() == "de") and "Frag mich zurück." or "Ask me back.")
    return { label, function() W.oeffne() end }
end

ns.on("PLAYER_LOGIN", function()
    aktionenRegistrieren()
    meldeWrappen()
    tagsUndPasstWrappen()
    beobachteteWerteBerechnen()
    W.angebotSitzung = false
    W.angebotNachhol = false
    W.angebotZeit = 0
end)
ns.on("PLAYER_ENTERING_WORLD", function()
    aktionenRegistrieren()
    meldeWrappen()
    tagsUndPasstWrappen()
end)

-- =============================================================================================
-- /lyra status
-- =============================================================================================
function W.status()
    local d = (ns.sprache() == "de")
    local beantwortetChar, beantwortetKonto = 0, 0
    local pc, pk = charPerson(), kontoPerson()
    if pc then beantwortetChar = zaehleEintraege(pc) end
    if pk then beantwortetKonto = zaehleEintraege(pk) end
    local offene = 0
    for _, f in ipairs(W.FRAGEN) do
        if W.lies(f.schluessel, f.ebene) == nil and (not f.verfuegbar or f.verfuegbar()) then
            offene = offene + 1
        end
    end
    return {
        (d and "Rückfragen: %d/%d Charakter, %d Konto, %d offen, Häkchen %s"
            or "Answers: %d/%d character, %d account, %d open, checkbox %s"):format(
            beantwortetChar, W.KAPPE, beantwortetKonto, offene,
            an() and (d and "an" or "on") or (d and "aus" or "off")),
    }
end
