-- Sinne/Welle14b.lua — Welle 14b "Flugzeit" (0.17.0, 21.09.2026).
--
-- Bauplan: docs/recherche/19-minispiele-flugzeit-2026-09-21.md §3 (3.1 bis 3.7).
--
-- WAS DIESE DATEI TUT, in einem Satz: sie MISST, wie lange eine Flugroute dauert, merkt sich den
-- Median der letzten fuenf Messungen kontoweit — und macht daraus KEINE Uhr, sondern drei
-- gesprochene Momente und einen stillen Ring.
--
--   1. MESSUNG. Schluessel "<Profil>|<Fraktion>|<von>><nach>". Die Knoten sind nodeIDs
--      (C_TaxiMap.GetAllTaxiNodes), Namen nur als Rueckfall. Gespeichert wird in
--      LyraGestaltDB.account.flugzeiten — Konto, nicht Charakter: eine Strecke dauert fuer jeden
--      Charakter gleich lang, und auf Hardcore faengt man oft neu an (§3.3).
--   2. DREI MOMENTE. Abflug (Dauer als KLASSE, nie als Ziffer), eine Minute vor der Landung
--      ("Gleich da."), Landung nach langem Flug. Alle drei sind eigene Ereignisse, siehe unten.
--   3. EIN STILLER RING. Gestalt/Gestalt.lua bekommt dafuer einen EIGENEN Cooldown-Frame unter
--      dem Portrait-Ring (G.flugRing). Der vorhandene Ring gehoert der WARNSTUFE und wird nicht
--      angefasst — wer den Flugfortschritt darauf legt, hat ihn beim naechsten HP20 ueberschrieben.
--
-- WARUM SECHS NEUE EREIGNISSE UND NICHT VIER ZEILEN AN TAXI_START (die Entscheidung aus dem
-- Auftrag, begruendet):
--   Core/Regie.lua waehle() zieht eine Zeile ZUFAELLIG aus dem Topf eines Ereignisses. Der
--   einzige Filter, den es gibt, ist (a) ein fehlender Platzhalter und (b) ns.Stimmung.passt()
--   ueber den wenn-Tag — und der liest LAUNE, nicht vars. Es gibt also keinen Weg, aus einem
--   gemeinsamen TAXI_START-Topf gezielt die Zeile der richtigen Dauerklasse zu ziehen.
--   Haengte man "Kurzer Huepfer. Halt dich fest." dort hinein, faele sie mit gleicher
--   Wahrscheinlichkeit auf einem Zehn-Minuten-Flug — eine LUEGE, und zwar eine mit Aufnahme.
--   Darum: TAXI_DAUER_KURZ / _MITTEL / _LANG / _NEU als vier eigene IDs (dasselbe Muster wie
--   ATEM30 gegen ATEM10, die auch nur eine Schwelle trennt), dazu TAXI_BALD und TAXI_LANDUNG.
--   TAXI_START (Sinne/Umwelt.lua, mit {ziel}) bleibt WORT FUER WORT wie es ist und kommt
--   weiter zuerst; die Dauerzeile folgt acht Sekunden spaeter, wenn Lyra sich gesetzt hat.
--   TAXI_ENDE bleibt ebenfalls unberuehrt (klasse "still", null Zeilen) — es ist der
--   Mienen-Rueckfall bei JEDER Landung; unsere Landezeile faellt nur nach einem LANGEN Flug.
--
-- DER ALTFEHLER, DEN DIESE WELLE REPARIERT (§3.1): U.flugFlanken() in Sinne/Umwelt.lua beendete
-- den Flug, sobald UnitOnTaxi("player") falsch liefert. Waehrend eines Ladebildschirms mitten im
-- Flug (Kontinent-/Faehrgrenze) liefert UnitOnTaxi aber falsch, OBWOHL der Spieler fliegt.
-- Bisher kostete das nur eine stumme TAXI_ENDE-Meldung. Mit Zeilen und Messung daran waere es
-- "Da waeren wir" mitten ueber dem Meer plus eine kaputte Messung. Die Ladebildschirm-Klammer
-- fuehrt DIESE Datei (W.imLadebildschirm); Umwelt.lua fragt sie an genau einer Stelle.
--
-- KONTRAKT: kein SendChatMessage, kein SendAddonMessage, kein C_ChatInfo, kein RunMacro, kein
-- CastSpell, keine geschuetzte Funktion, kein Netz, keine Fremddaten, keine neue Globale. Jeder
-- Zugriff auf eine Spiel-API steht in pcall hinter einer Existenzpruefung auf EIN konkretes
-- Feld. Faellt eine API aus, ist diese Datei still — kein Lua-Fehler — und /lyra status sagt es.
--
-- NIE UEBERNOMMEN WIRD: InFlights vorgemessene Flugzeit-Tabelle (§3.5a). InFlight steht unter
-- All Rights Reserved; die MECHANIK (Haken auf TakeTaxiNode plus UnitOnTaxi-Polling) ist kein
-- schuetzbares Werk und wird nachgebaut, die 875 gemessenen ZAHLEN sind eine gepflegte
-- Datensammlung und es kommt kein Byte davon in dieses Addon. Wir messen selbst.
--
-- KEIN OnUpdate. Zwei Ticker, beide begrenzt: der Anflug-Ticker lebt hoechstens fuenf Sekunden,
-- der Flug-Ticker hoechstens einen Flug lang und wird bei der Landung gekuendigt.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Welle14b = W
ns.Sinne.Welle14b = W

-- ---------------------------------------------------------------------------------------------
-- Voreinstellung. EIN Kaestchen, benannt nach dem, was es tut. Core/Init.lua gehoert einem
-- anderen Team, darum haengt der Schluessel hier an ns.DEFAULTS_ACCOUNT — auf DATEIEBENE, also
-- vor ns.initDB() (Muster: Sinne/Welle13a.lua).
-- Der Messwert-Speicher steht bewusst NICHT in den DEFAULTS: defaults() wuerde eine leere
-- Tabelle hineinkopieren, und eine SavedVariable, die es immer gibt, auch wenn nie geflogen
-- wurde, ist Muell in der Datei des Spielers. Sie entsteht beim ersten gemessenen Flug.
-- ---------------------------------------------------------------------------------------------
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.flugzeit == nil then D.flugzeit = true end
end

-- ---------------------------------------------------------------------------------------------
-- Feature-Weiche ZUERST, Interface-Nummer nie (Core/Compat.lua, Kopf). Gefragt wird nach der
-- FUNKTION. Auf Forever/Camelot ist C_TaxiMap der ERSTE Weg und die alten Globals der Rueckfall
-- (§3.6) — genau umgekehrt zu dem, was man aus Era-Gewohnheit baut: ueber die Flugkarte
-- (Blizzard_FlightMap) sind NumTaxiNodes/TaxiNodeGetType nicht garantiert gefuellt.
-- Die Weiche faellt beim Laden; jede Lesefunktion prueft den Typ im Moment des Aufrufs erneut.
-- ---------------------------------------------------------------------------------------------
local C = ns.Compat
W.F = {
    taxi  = (type(_G.UnitOnTaxi) == "function") and true or false,
    hook  = (type(_G.hooksecurefunc) == "function" and type(_G.TakeTaxiNode) == "function")
            and true or false,
    karte = (type(_G.C_TaxiMap) == "table" and type(_G.C_TaxiMap.GetAllTaxiNodes) == "function")
            and true or false,
    alt   = (type(_G.NumTaxiNodes) == "function" and type(_G.TaxiNodeName) == "function"
             and type(_G.TaxiNodeGetType) == "function") and true or false,
}

W.TICK          = 0.25    -- s, Anflug-Ticker: wartet auf die UnitOnTaxi-Flanke
W.TICK_MAX      = 20      -- Durchlaeufe = 5 s. Danach ist kein Flug zustande gekommen.
W.FLUG_TICK     = 1       -- s, Landeticker. Lebt nur waehrend eines Fluges.
W.DAUER_VERZUG  = 8       -- s nach dem Abheben faellt die Dauerzeile (TAXI_START hat Vorrang)
W.VOR_LANDUNG   = 60      -- s vor der geschaetzten Landung faellt TAXI_BALD
W.WECK_MIN      = 150     -- s: kuerzere Fluege bekommen KEINEN Weckruf (die Abflugzeile ist
                          --    gerade erst verklungen, §3.4)
W.KURZ_BIS      = 120     -- s  <  : Klasse "kurz"
W.MITTEL_BIS    = 300     -- s  <= : Klasse "mittel"; darueber "lang"
W.LANDUNG_AB    = 300     -- s: erst nach einem langen Flug gibt es eine Landezeile
W.MIN_DAUER     = 5       -- s  Muell-Riegel unten  (Auftrag Welle 14b)
W.MAX_DAUER     = 1800    -- s  Muell-Riegel oben = 30 min (Auftrag Welle 14b)
W.MESSUNGEN     = 5       -- Ringpuffer je Strecke
W.DECKEL        = 300     -- Strecken insgesamt; der aelteste "stand" fliegt
W.EIGEN_ABSTAND = 90      -- s eigene Drossel zwischen zwei Dauerzeilen (zwei Fluege hintereinander)
W.LADE_NOTAUS   = 120     -- s: kommt kein PLAYER_ENTERING_WORLD, loest sich die Klammer selbst
W.DB_VERSION    = 1

-- Fremde Flugzeit-Addons. Ist eines geladen, entfaellt die MINUTENZEILE und der RING; die
-- Figurenzeilen bleiben (Andockstellen-Regel 1: wo ein anderes Addon eine Zahl anzeigt, sagt
-- Lyra sie nicht — dieselbe Stillhalte wie bei GTFO in Welle 6).
W.FREMDE = { "InFlight", "InFlight_Load", "EnhancedFlightMap", "TaxiFlightTimes",
             "FlyTravelTimes", "FlightTimerClassic" }

local function jetzt() return (GetTime and GetTime()) or 0 end
-- nil zaehlt als AN: vor ns.initDB() gibt ns.Get die Vorgabe zurueck, und die steht auf true.
local function an() return ns.Get("flugzeit") ~= false end
local function aufTaxi()
    if type(_G.UnitOnTaxi) ~= "function" then return false end
    local ok, t = pcall(_G.UnitOnTaxi, "player")
    return (ok and t) and true or false
end

local function melde(id, vars)
    if not ns.melde then return false end
    local ok, v = pcall(ns.melde, id, vars)
    return (ok and v) and true or false
end

-- Plauder-Zeile mit EINEM Nachhol (Muster aus Sinne/Welle13a.lua). NUR wenn der Regie-ABSTAND
-- der Grund war: Drossel, Gruppe, Still-Modus und Stummschaltung sind endgueltige Antworten.
-- Fuer uns ist das kein Luxus, sondern der Normalfall: TAXI_START faellt beim Abheben, und der
-- Mindestabstand fuer plauder steht ab Werk auf 30 s. Ohne Nachhol kaeme die Dauerzeile nie.
local function meldeNachhol(id, vars, gilt)
    if melde(id, vars) then return true end
    local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
    if not (d and d[2] == id and d[1] == "abstand") then return false end
    local rest = 0
    if ns.Regie and ns.Regie.abstandRest then
        local ok, r = pcall(ns.Regie.abstandRest)
        if ok and type(r) == "number" then rest = r end
    end
    local verzug = math.max(2, math.min(rest + 1, 180))
    ns.Compat.After(verzug, function()
        if gilt and not gilt() then return end
        melde(id, vars)
    end)
    return false
end

-- =============================================================================================
-- 1  DIE KNOTEN — nodeID zuerst, Name nur als Rueckfall
-- =============================================================================================
-- Warum nodeID und nicht der Name: der Name ist LOKALISIERT. Wer den Client von deutsch auf
-- englisch stellt, haette mit Namensschluesseln jede gemessene Strecke verloren und misst von
-- vorn. Die nodeID ist sprachunabhaengig und stabil (§3.3). InFlight benutzt auf Retail bereits
-- IDs und schleppt auf Classic eine eigene Normalisierungstabelle mit — genau den Aufwand
-- spart der erste Weg.
--
-- NICHT ANGEFASST wird textureKitPrefix aus TaxiNodeInfo: das Feld heisst in Forever
-- "textureKit". Wir lesen es nicht, und es steht hier, damit es niemand spaeter hineinschreibt.
-- knoten.slot[slotIndex]  = die KENNUNG des Knotens (nodeID, im Rueckfall der Name) -> Schluessel
-- knoten.name[slotIndex]  = der lesbare Name desselben Knotens                      -> {ziel}
-- Zwei Tabellen und nicht eine: der Schluessel soll sprachunabhaengig sein, die Zeile lesbar.
local knoten = { start = nil, startName = nil, slot = {}, name = {}, stand = 0 }

local function kartenId()
    if type(_G.GetTaxiMapID) == "function" then
        local ok, id = pcall(_G.GetTaxiMapID)
        if ok and type(id) == "number" then return id end
    end
    if type(_G.C_Map) == "table" and type(_G.C_Map.GetBestMapForUnit) == "function" then
        local ok, id = pcall(_G.C_Map.GetBestMapForUnit, "player")
        if ok and type(id) == "number" then return id end
    end
    return nil
end

-- Erster Weg: C_TaxiMap.GetAllTaxiNodes. Liefert TaxiNodeInfo{ nodeID, name, state, slotIndex }.
-- Enum.FlightPathState.Current markiert den Knoten, auf dem der Spieler steht. slotIndex
-- verbindet ihn mit dem Index, den TakeTaxiNode(idx) bekommt — damit ist auch das ZIEL als
-- nodeID greifbar, und zwar ohne einen einzigen lokalisierten Namen.
-- In Forever tragen GetAllTaxiNodes/GetTaxiNodesForMap ein SecretArguments-Attribut. Wir lesen
-- nur; trotzdem steht jeder Aufruf in pcall, und der Rueckfall darunter muss wirklich tragen.
local function knotenAusKarte()
    if not (type(_G.C_TaxiMap) == "table" and type(_G.C_TaxiMap.GetAllTaxiNodes) == "function") then
        return nil
    end
    local id = kartenId()
    local ok, liste = pcall(_G.C_TaxiMap.GetAllTaxiNodes, id)
    if not (ok and type(liste) == "table" and #liste > 0) then return nil end
    local cur = (type(_G.Enum) == "table" and type(_G.Enum.FlightPathState) == "table")
                and _G.Enum.FlightPathState.Current or 0
    local erg = { start = nil, startName = nil, slot = {}, name = {} }
    for _, n in ipairs(liste) do
        if type(n) == "table" and type(n.nodeID) == "number" then
            if type(n.slotIndex) == "number" then
                erg.slot[n.slotIndex] = n.nodeID
                if type(n.name) == "string" and n.name ~= "" then erg.name[n.slotIndex] = n.name end
            end
            if n.state == cur then
                erg.start = n.nodeID
                erg.startName = (type(n.name) == "string") and n.name or nil
            end
        end
    end
    if erg.start == nil and next(erg.slot) == nil then return nil end
    return erg
end

-- Rueckfall: die alten Globals. Schleife ueber NumTaxiNodes(), Knoten mit
-- TaxiNodeGetType(i) == "CURRENT" ist der Start, Name ueber TaxiNodeName(i).
-- Gefuellt sind sie nur, wenn das alte Taxifenster offen war — auf Forever ueber die Flugkarte
-- also moeglicherweise gar nicht. Deshalb steht dieser Weg ZWEITER.
local function knotenAusGlobals()
    if not (type(_G.NumTaxiNodes) == "function" and type(_G.TaxiNodeName) == "function"
            and type(_G.TaxiNodeGetType) == "function") then return nil end
    local ok, n = pcall(_G.NumTaxiNodes)
    n = ok and tonumber(n) or nil
    if not n or n <= 0 or n > 500 then return nil end
    local erg = { start = nil, startName = nil, slot = {}, name = {} }
    for i = 1, n do
        local ok2, name = pcall(_G.TaxiNodeName, i)
        local ok3, typ = pcall(_G.TaxiNodeGetType, i)
        if ok2 and type(name) == "string" and name ~= "" then
            erg.slot[i] = name
            erg.name[i] = name
            if ok3 and typ == "CURRENT" then erg.start = name; erg.startName = name end
        end
    end
    if erg.start == nil and next(erg.slot) == nil then return nil end
    return erg
end

-- Beide Wege, in dieser Reihenfolge. Das Ergebnis wird gemerkt, weil TakeTaxiNode() im selben
-- Augenblick das Taxifenster schliesst: wer erst DANN liest, liest nichts mehr.
local function knotenLesen()
    local erg = knotenAusKarte() or knotenAusGlobals()
    if not erg then return false end
    knoten.start, knoten.startName = erg.start, erg.startName
    knoten.slot, knoten.name, knoten.stand = erg.slot, erg.name or {}, jetzt()
    return true
end
W.knotenLesen = knotenLesen
W.knoten = knoten

-- =============================================================================================
-- 2  DER SPEICHER — Konto, Median, Deckel
-- =============================================================================================
local function fraktion()
    if type(_G.UnitFactionGroup) ~= "function" then return "?" end
    local ok, f = pcall(_G.UnitFactionGroup, "player")
    if not (ok and type(f) == "string" and f ~= "") then return "?" end
    return f:sub(1, 1)
end

local function profil()
    return (type(C) == "table" and type(C.profil) == "string") and C.profil or "era"
end

-- "era|A|456>457" (nodeIDs) oder "era|A|Ironforge>Menethil Harbor" (Rueckfall).
-- Fehlt der START, wird NICHT auf einen Ziel-only-Schluessel ausgewichen: zwei Strecken zum
-- selben Ziel sind verschieden lang, das waere eine falsche Zahl. Dann gibt es fuer diesen Flug
-- eben keine Schaetzung (§3.3).
local function schluesselBauen(von, nach)
    if von == nil or nach == nil then return nil end
    von, nach = tostring(von), tostring(nach)
    if von == "" or nach == "" then return nil end
    return profil() .. "|" .. fraktion() .. "|" .. von .. ">" .. nach
end
W.schluesselBauen = schluesselBauen

local function topf(anlegen)
    if not ns.db then return nil end
    local t = ns.db.flugzeiten
    if type(t) ~= "table" then
        if not anlegen then return nil end
        t = { v = W.DB_VERSION, strecken = {} }
        ns.db.flugzeiten = t
    end
    if type(t.strecken) ~= "table" then t.strecken = {} end
    if t.v ~= W.DB_VERSION then t.v = W.DB_VERSION end
    return t
end
W.topf = topf

-- Median statt Mittelwert: ein einzelner Ausreisser (Server-Haenger, Nachlade-Ruckler) zieht den
-- Mittelwert, den Median nicht. Bei EINER Messung ist der Median die Messung — die erste
-- Schaetzung ist also sofort brauchbar (§3.3).
local function median(liste)
    if type(liste) ~= "table" or #liste == 0 then return nil end
    local s = {}
    for _, v in ipairs(liste) do
        local z = tonumber(v)
        if z and z > 0 then s[#s + 1] = z end
    end
    if #s == 0 then return nil end
    table.sort(s)
    local m = #s
    if m % 2 == 1 then return s[(m + 1) / 2] end
    return (s[m / 2] + s[m / 2 + 1]) / 2
end
W.median = median

function W.schaetzung(schluessel)
    if not schluessel then return nil end
    local t = topf(false)
    if not t then return nil end
    local e = t.strecken[schluessel]
    if type(e) ~= "table" then return nil end
    return median(e.m)
end

local function deckelHalten(t)
    local n = 0
    for _ in pairs(t.strecken) do n = n + 1 end
    while n > W.DECKEL do
        local aeltester, altStand = nil, nil
        for k, e in pairs(t.strecken) do
            local s = (type(e) == "table" and tonumber(e.stand)) or 0
            if altStand == nil or s < altStand then aeltester, altStand = k, s end
        end
        if not aeltester then return end
        t.strecken[aeltester] = nil
        n = n - 1
    end
end

-- Ein verworfener Flug ueberschreibt nichts und loescht nichts (§3.3).
function W.speichern(schluessel, dauer)
    dauer = tonumber(dauer)
    if not (schluessel and dauer) then return false end
    if dauer < W.MIN_DAUER or dauer > W.MAX_DAUER then return false end
    local t = topf(true)
    if not t then return false end
    local e = t.strecken[schluessel]
    if type(e) ~= "table" or type(e.m) ~= "table" then e = { m = {} }; t.strecken[schluessel] = e end
    e.m[#e.m + 1] = math.floor(dauer + 0.5)
    while #e.m > W.MESSUNGEN do table.remove(e.m, 1) end
    e.stand = (type(_G.time) == "function") and (select(2, pcall(_G.time)) or 0) or 0
    if type(e.stand) ~= "number" then e.stand = 0 end
    deckelHalten(t)
    return true
end

-- =============================================================================================
-- 3  DIE STILLHALTE — fremde Flugzeit-Addons
-- =============================================================================================
-- Ist eines geladen, entfaellt die Minutenzeile UND der Ring. Umgesetzt wird das nicht mit einem
-- if vor jeder Zeile, sondern mit dem Mechanismus, den die Regie selbst mitbringt: vars.minuten
-- wird NICHT gesetzt, und Core/Regie.lua waehle() wirft jede Zeile mit einem Platzhalter ohne
-- vars von sich aus aus dem Topf. Uebrig bleibt genau die Figurenzeile.
local fremdStand = nil
local function fremdDa()
    if fremdStand ~= nil then return fremdStand end
    local geladen = (type(_G.C_AddOns) == "table" and _G.C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    fremdStand = false
    if type(geladen) == "function" then
        for _, name in ipairs(W.FREMDE) do
            local ok, drin = pcall(geladen, name)
            if ok and drin then fremdStand = true end
        end
    end
    -- InFlight_Load laedt InFlight erst beim Oeffnen der Flugmeister-Karte nach; die
    -- SavedVariable steht dann schon. Zweiter, billiger Blick (lesend, nie schreibend).
    if type(_G.InFlightDB) == "table" then fremdStand = true end
    return fremdStand
end
W.fremdDa = fremdDa
function W.fremdVergessen() fremdStand = nil end   -- nur fuer den Pruefstand

-- =============================================================================================
-- 4  DER FLUG
-- =============================================================================================
local flug = {
    drin = false, id = 0, seit = 0, verworfen = false,
    schluessel = nil, schaetzung = nil, klasse = nil, ziel = "",
    ausSeit = 0, ladeAbzug = 0,
}
W.flug = flug

local ladeKlammer = false     -- zwischen PLAYER_LEAVING_WORLD und PLAYER_ENTERING_WORLD
local letzteDauerzeile = -100000

-- DIE ANTWORT FUER Sinne/Umwelt.lua. U.flugFlanken() fragt sie an genau einer Stelle, bevor es
-- einen Flug fuer beendet erklaert. Die Klammer ist bewusst NICHT an flug.drin gekoppelt: sie
-- soll auch dann halten, wenn UNSERE Erkennung den Flug verpasst hat (kein Haken, kein
-- Taxifenster) und nur Umwelt.lua ihn fuehrt. Ausserhalb eines Fluges ist sie folgenlos —
-- flugFlanken() beendet nur, was es selbst begonnen hat.
function W.imLadebildschirm() return ladeKlammer end

local anflugTicker, anflugN, flugTicker

local function anflugStop()
    if anflugTicker then pcall(function() anflugTicker:Cancel() end); anflugTicker = nil end
    anflugN = 0
end

local function flugTickerStop()
    if flugTicker then pcall(function() flugTicker:Cancel() end); flugTicker = nil end
end

local function ringAus()
    local G = ns.Gestalt
    if G and type(G.flugRing) == "function" then pcall(G.flugRing, 0) end
end

local function zuruecksetzen()
    flug.drin = false
    flug.seit = 0
    flug.verworfen = false
    flug.schluessel = nil
    flug.schaetzung = nil
    flug.klasse = nil
    flug.ziel = ""
    flug.ausSeit = 0
    flug.ladeAbzug = 0
    flugTickerStop()
    ringAus()
end

local function klasseVon(sek)
    if not sek then return "neu" end
    if sek < W.KURZ_BIS then return "kurz" end
    if sek <= W.MITTEL_BIS then return "mittel" end
    return "lang"
end
W.klasseVon = klasseVon

local EREIGNIS = { kurz = "TAXI_DAUER_KURZ", mittel = "TAXI_DAUER_MITTEL",
                   lang = "TAXI_DAUER_LANG", neu = "TAXI_DAUER_NEU" }
W.EREIGNIS = EREIGNIS

-- Die Dauerzeile. Acht Sekunden nach dem Abheben, damit TAXI_START (Sinne/Umwelt.lua) zuerst
-- kommt und die beiden nicht uebereinanderfallen. Der Regie-Mindestabstand (ab Werk 30 s)
-- frisst sie an dieser Stelle fast immer — dafuer ist meldeNachhol da.
local function dauerzeile(meineId)
    if meineId ~= flug.id or not flug.drin then return end
    if not an() then return end
    local t = jetzt()
    if t - letzteDauerzeile < W.EIGEN_ABSTAND then return end
    local id = EREIGNIS[flug.klasse or "neu"] or EREIGNIS.neu
    local vars = {}
    if flug.ziel ~= "" then vars.ziel = flug.ziel end
    -- Die Minutenzahl: nur bei bekannter Strecke UND nur, wenn kein fremdes Flugzeit-Addon
    -- dieselbe Zahl schon anzeigt. Fehlt sie in vars, faellt die Zeile mit {minuten} von selbst
    -- aus dem Topf — und uebrig bleibt die Figurenzeile.
    if flug.schaetzung and not fremdDa() then
        local min = math.floor((flug.schaetzung / 60) + 0.5)
        if min >= 1 then vars.minuten = min end
    end
    letzteDauerzeile = t
    meldeNachhol(id, vars, function()
        return meineId == flug.id and flug.drin and an()
    end)
end

local function weckruf(meineId)
    if meineId ~= flug.id or not flug.drin then return end
    if not an() then return end
    if ladeKlammer then return end
    melde("TAXI_BALD")
end

local function beginne()
    if flug.drin then return end
    flug.id = flug.id + 1
    flug.drin = true
    flug.seit = jetzt()
    flug.verworfen = false
    flug.ladeAbzug = 0
    local meineId = flug.id

    -- Der Schluessel. Er entsteht aus dem GEMERKTEN Startknoten (TAXIMAP_OPENED) und dem Ziel,
    -- das der TakeTaxiNode-Haken gelesen hat. Fehlt eines von beiden, gibt es keinen Schluessel,
    -- keine Schaetzung und keinen Ring — aber die Abflugzeile kommt trotzdem, als Klasse "neu".
    flug.schaetzung = W.schaetzung(flug.schluessel)
    flug.klasse = klasseVon(flug.schaetzung)

    -- Der stille Ring. Kein Balken, keine Ziffer. Nur bei bekannter Strecke und nur, wenn kein
    -- fremdes Addon dieselbe Auskunft schon gibt.
    if flug.schaetzung and not fremdDa() and an() then
        local G = ns.Gestalt
        if G and type(G.flugRing) == "function" then pcall(G.flugRing, flug.schaetzung) end
    end

    -- OHNE SCHLUESSEL IST LYRA STILL. "Die Strecke kenn ich noch nicht, mal sehen wie lang das
    -- dauert" ist ein Versprechen — und ohne Start- oder Zielkennung koennen wir es nicht
    -- halten, weil es nichts gibt, woran die Messung haengen wuerde. Dann bleibt es bei
    -- TAXI_START aus Sinne/Umwelt.lua (die Figurenzeile) und sonst nichts: keine Dauerzeile,
    -- kein Ring, kein Weckruf, keine Landezeile. Das ist zugleich der Ausfall-Fall fuer einen
    -- Client ohne C_TaxiMap UND ohne TaxiNodeGetType (§3.7, letzter Absatz).
    if flug.schluessel then
        ns.Compat.After(W.DAUER_VERZUG, function() pcall(dauerzeile, meineId) end)
    end

    -- ns.Compat.After ist nicht abbrechbar (Core/Compat.lua:412 ist schlicht C_Timer.After).
    -- Darum der Flug-Zaehler: jeder Rueckruf prueft zuerst seine eigene Id. Sonst weckt ein
    -- Timer aus dem Flug von vorhin mitten im naechsten Kampf (§3.4).
    if flug.schaetzung and flug.schaetzung >= W.WECK_MIN then
        ns.Compat.After(flug.schaetzung - W.VOR_LANDUNG, function() pcall(weckruf, meineId) end)
    end

    flugTickerStop()
    flugTicker = ns.Compat.NewTicker(W.FLUG_TICK, function() pcall(W.nachsehen) end)
end

-- Landung. Wahrheitsquelle ist UnitOnTaxi — PLAYER_CONTROL_GAINED kommt zwischendurch und
-- manchmal gar nicht und ist nur der Anlass zum Nachsehen (§3.4).
local function lande()
    if not flug.drin then return end
    local dauer = jetzt() - flug.seit
    local schluessel, verworfen = flug.schluessel, flug.verworfen
    local lang = (dauer >= W.LANDUNG_AB)
    local meineId = flug.id
    zuruecksetzen()
    if not verworfen and schluessel then W.speichern(schluessel, dauer) end
    if lang and schluessel and an() and not verworfen then
        ns.Compat.After(1, function()
            if flug.id ~= meineId or flug.drin then return end
            melde("TAXI_LANDUNG")
        end)
    end
end
W.lande = lande

function W.nachsehen()
    if not flug.drin then return end
    if ladeKlammer then return end        -- Ladebildschirm: der Poller ist gesperrt
    if aufTaxi() then return end
    lande()
end

local function verwerfen()
    if flug.drin then flug.verworfen = true end
end
W.verwerfen = verwerfen

-- =============================================================================================
-- 5  HAKEN UND EREIGNISSE
-- =============================================================================================
-- Der Haken sitzt auf TakeTaxiNode und NICHT auf einem Knopf: in Forever ruft auch der Pin der
-- Flugkarte am Ende dieselbe Globale auf (TakeTaxiNode(self.taxiNodeData.slotIndex)), und damit
-- greift derselbe Haken auf beiden Wegen (§3.6).
if W.F.hook then
    pcall(_G.hooksecurefunc, "TakeTaxiNode", function(idx)
        local ok = pcall(function()
            -- Falls TAXIMAP_OPENED nie kam (Flugkarte, fremdes Fenster): jetzt noch einmal lesen.
            if knoten.start == nil then knotenLesen() end
            local ziel = knoten.slot[idx]         -- Kennung (nodeID oder Name)
            local zielName = knoten.name[idx]     -- lesbarer Name
            if type(_G.TaxiNodeName) == "function" and (ziel == nil or zielName == nil) then
                local ok2, name = pcall(_G.TaxiNodeName, idx)
                if ok2 and type(name) == "string" and name ~= "" then
                    zielName = zielName or name
                    ziel = ziel or name
                end
            end
            flug.ziel = (type(zielName) == "string") and zielName or ""
            flug.schluessel = schluesselBauen(knoten.start, ziel)
            -- Der Aufsitz-Vorlauf zaehlt NICHT mit: UnitOnTaxi wird erst ein bis zwei Sekunden
            -- nach dem Klick wahr. Ein begrenzter Ticker wartet auf die Flanke und beendet sich
            -- selbst. Zwanzig Durchlaeufe ohne Taxi heisst: kein Flug zustande gekommen (Gold
            -- gereicht nicht) — stillschweigend abbrechen (§3.1a Punkt 1).
            anflugStop()
            anflugN = 0
            anflugTicker = ns.Compat.NewTicker(W.TICK, function()
                anflugN = (anflugN or 0) + 1
                if aufTaxi() then
                    anflugStop()
                    pcall(beginne)
                elseif anflugN >= W.TICK_MAX then
                    anflugStop()
                end
            end)
        end)
        if not ok then anflugStop() end
    end)
end

-- Abbruchwege. Alle drei in pcall, alle drei nur LESEND gehakt — wir verhindern nichts, wir
-- merken uns nur, dass diese Messung nichts mehr wert ist (§3.1a Punkt 3).
if type(_G.hooksecurefunc) == "function" then
    if type(_G.TaxiRequestEarlyLanding) == "function" then
        pcall(_G.hooksecurefunc, "TaxiRequestEarlyLanding", function() pcall(verwerfen) end)
    end
    if type(_G.AcceptBattlefieldPort) == "function" then
        pcall(_G.hooksecurefunc, "AcceptBattlefieldPort", function() pcall(verwerfen) end)
    end
    if type(_G.C_SummonInfo) == "table" and type(_G.C_SummonInfo.ConfirmSummon) == "function" then
        pcall(_G.hooksecurefunc, _G.C_SummonInfo, "ConfirmSummon", function() pcall(verwerfen) end)
    end
end

ns.on("TAXIMAP_OPENED", function() pcall(knotenLesen) end)
ns.on("TAXIMAP_CLOSED", function() end)   -- Knoten bleiben gemerkt: TakeTaxiNode schliesst zuerst

-- Die Ladebildschirm-Klammer. Sie ist der Kern der Reparatur aus §3.1 und sperrt DREI Dinge:
-- den Poller, die Landeflanke in Sinne/Umwelt.lua und den Weckruf. Die Ladezeit wird nicht
-- verworfen, sondern HERAUSGERECHNET: die gespeicherte Zahl ist reine Flugzeit, weil der Spieler
-- die Ladezeit beim naechsten Mal nicht wieder hat (§3.1a Punkt 2).
ns.on("PLAYER_LEAVING_WORLD", function()
    ladeKlammer = true
    flug.ausSeit = jetzt()
    local marke = flug.ausSeit
    ns.Compat.After(W.LADE_NOTAUS, function()
        if ladeKlammer and flug.ausSeit == marke then ladeKlammer = false end
    end)
end)

ns.on("PLAYER_ENTERING_WORLD", function()
    if ladeKlammer and flug.drin and flug.ausSeit > 0 then
        local weg = jetzt() - flug.ausSeit
        if weg > 0 and weg < W.MAX_DAUER then
            flug.seit = flug.seit + weg
            flug.ladeAbzug = flug.ladeAbzug + weg
        end
    end
    ladeKlammer = false
    flug.ausSeit = 0
    -- REVIEW17: Guertel zum Hosentraeger fuer den Ring. ringAus() haengt sonst allein an lande().
    -- Nach einem Ladebildschirm, der den Flug beendet hat, ohne dass wir ihn fuehren (Portal
    -- mitten im Flug, Hinauswurf, Charakterwechsel im selben Client), stuende der Wischer sonst
    -- weiter ueber dem Portraet und liefe irgendwann stumm leer. Waehrend eines Fluges mit
    -- Ladebildschirm (Kontinentgrenze) ist flug.drin wahr - dort bleibt der Ring unberuehrt.
    if not flug.drin then ringAus() end
end)

ns.on("PLAYER_DEAD", function() pcall(verwerfen) end)
ns.on("PLAYER_LOGOUT", function() pcall(verwerfen) end)
ns.on("PLAYER_CONTROL_GAINED", function() pcall(W.nachsehen) end)

-- =============================================================================================
-- /lyra status
-- =============================================================================================
function W.status()
    local d = (ns.sprache() == "de")
    local out = {}

    local weg = W.F.karte and "C_TaxiMap" or (W.F.alt and (d and "Globals (Rueckfall)" or "globals (fallback)") or nil)
    out[#out + 1] = (d and "Flugzeit: %s" or "Flight time: %s"):format(
        (not W.F.taxi) and (d and "fehlt (kein UnitOnTaxi)" or "missing (no UnitOnTaxi)")
        or (not W.F.hook) and (d and "fehlt (kein Haken auf TakeTaxiNode)" or "missing (no TakeTaxiNode hook)")
        or (weg == nil) and (d and "fehlt (keine Knotenquelle)" or "missing (no node source)")
        or ((d and "Knoten ueber %s, Zeilen %s" or "nodes via %s, lines %s")
            :format(weg, an() and (d and "an" or "on") or (d and "aus" or "off"))))

    local t = topf(false)
    local n, mess = 0, 0
    if t then
        for _, e in pairs(t.strecken) do
            n = n + 1
            mess = mess + ((type(e) == "table" and type(e.m) == "table") and #e.m or 0)
        end
    end
    out[#out + 1] = (d and "  Gemessen: %d Strecken, %d Messungen (Deckel %d, je Strecke %d)"
                        or "  Measured: %d routes, %d samples (cap %d, %d per route)")
                    :format(n, mess, W.DECKEL, W.MESSUNGEN)

    out[#out + 1] = (d and "  Fremdes Flugzeit-Addon: %s" or "  Foreign flight-time addon: %s"):format(
        fremdDa() and (d and "ja - Minutenzeile und Ring schweigen" or "yes - minute line and ring stay silent")
                   or (d and "nein" or "no"))

    if flug.drin then
        out[#out + 1] = (d and "  Im Flug: %s, seit %.0f s%s"
                            or "  In flight: %s, for %.0f s%s"):format(
            flug.schluessel or (d and "Strecke unbekannt" or "route unknown"),
            jetzt() - flug.seit,
            flug.ladeAbzug > 0 and ((d and " (Ladezeit %.0f s abgezogen)" or " (loading %.0f s deducted)")
                                    :format(flug.ladeAbzug)) or "")
    else
        out[#out + 1] = (d and "  Im Flug: nein" or "  In flight: no")
    end

    -- /lyra debug: Start- und Zielkennung eines Fluges. EIN Flug im Beta-Client beantwortet die
    -- Forever-Frage vollstaendig — ob C_TaxiMap traegt, ob der Rueckfall traegt, ob
    -- TaxiNodeGetType dort "CURRENT" liefert (§3.6, Pruefpunkt fuer den Beta-Test).
    out[#out + 1] = (d and "  Letzte Knoten: Start %s, Ziel %s" or "  Last nodes: start %s, target %s")
        :format(tostring(knoten.start), flug.ziel ~= "" and tostring(flug.ziel) or "-")
    return out
end
