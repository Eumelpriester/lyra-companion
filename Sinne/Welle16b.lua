-- Sinne/Welle16b.lua — Welle 16b "Sie erinnert sich an den Vorgänger" (0.18, 22.09.2026).
--
-- DREI BAUTEILE, alle auf Sinne/Erbe.lua aufgesetzt (LyraGestaltDB.erbe, kontoweit) und keines
-- davon aendert Sinne/Leben2.lua oder Sinne/Erbe.lua ausser um die zwei Funktionen aus Baustein 4
-- (siehe dort, mit "-- W16B:" markiert):
--
--   1. TRAUER NACH TOD — zwei leisere Sitzungen des Nachfolgers. Kein neues Ereignis, nur eine
--      Modulation der bestehenden: ns.Stimmung.abstandFaktor (Plauder-Abstand x1,5) und
--      ns.Stimmung.mikroPool (besorgt-nahe Mikro-Mimik), beide ueber einen WRAPPER in DIESER
--      Datei — Sinne/Leben2.lua bleibt Wort fuer Wort, wie der Auftrag verlangt. Dazu die
--      Leerlauf-Stille: LEERLAUF wird ueber die vorhandene Stummschaltung (Core/Regie.lua
--      R.stumm/R.istStumm, dasselbe wie "/lyra stumm LEERLAUF") an- und wieder abgeschaltet -
--      kein neuer, vierter Mantel um ns.melde (siehe Sinne/Karte2.lua, Abschnitt "WARUM HIER
--      KEIN MANTEL UM ns.melde LIEGT" — dieselbe Lehre, hier auf ein einzelnes Ereignis
--      angewandt: die bestehende Positivliste tut das schon).
--
--   2. ERBE_UEBERHOLT (neu) — der Nachfolger erreicht eine hoehere Stufe, als der juengste
--      Vorgaenger je hatte. Einmal je Vorgaenger, gemerkt im Erbe-Eintrag selbst (e.ueberholt).
--
--   3. ERBE_NEUANFANG (neu) — "ich kenn dich, nicht deinen Namen". Beim ERSTEN Login eines NEUEN
--      Charakters auf einem Konto mit Bindungsstufe >= 1 (ns.Bindung.stufe(), existenzgeprueft,
--      sonst ns.Gestalt.bindungsstufe()/ns.Stimmung.vertraut() als Rueckfall — dieselbe Kette,
--      die Gestalt/Gestalt.lua fuer W16v schon benutzt). Einmal je Charakter.
--
-- WARUM DIE TRAUER KEIN NEUES EREIGNIS BRAUCHT: sie ist kein Satz, sie ist ein Tonfall. Ein
-- Ereignis "ERBE_TRAUER_AN" haette selbst wieder einen Text gebraucht und waere damit genau die
-- Zeile geworden, die eine gedaempfte Sitzung NICHT will. "/lyra stimmung" bekommt trotzdem einen
-- Satz dazu (W.status()), damit die Stille erklaerbar bleibt (companion-v3 A.2).
--
-- SPEICHER:
--   LyraGestaltDB.account.erbeTrauerStand = { rest = 0..2, leerlaufVonUns = false }   -- Konto-
--     Flag + Sitzungszaehler. EIGENER Schluessel, bewusst NICHT "erbeTrauer": ns.db IST
--     LyraGestaltDB.account (Core/Init.lua ns.initDB), und "erbeTrauer" ist schon der Name des
--     Haekchens (ns.Get/ns.Set) — derselbe Schluessel fuer beides haette das Haekchen beim
--     ersten Tod mit einer Tabelle ueberschrieben. rest ist die Zahl der NOCH gedaempften
--     Sitzungen; leerlaufVonUns merkt,
--     ob DIESE Datei LEERLAUF gerade stummgeschaltet haelt (sonst wuerde ein Spieler, der
--     LEERLAUF von Hand stummgeschaltet hat, beim Sitzungsende versehentlich wieder laut gestellt).
--   ns.char.erbeTrauerSitzungStart = unix   -- welche Chronik-Sitzung (Startzeit als Schluessel)
--     hier schon ausgewertet wurde. Char-gebunden und ueberlebt damit einen /reload MITTEN in der
--     Sitzung: eine neue Auswertung findet nur statt, wenn Sinne/Chronik.lua wirklich eine NEUE
--     Sitzung begonnen hat (anderer Startzeitpunkt), nicht bei jedem PLAYER_ENTERING_WORLD.
--   ns.char.erbeTrauerSitzung = true|false   -- gilt TRAUER in der laufenden Sitzung.
--   ns.char.erbeNeuanfangGesagt = true       -- ERBE_NEUANFANG schon gesagt (dieser Charakter).
--   e.ueberholt = true   -- additiv auf einem EIGENEN Erbe-Eintrag (Sinne/Erbe.lua-Liste).
--
-- API (nur lesend, alles bereits oeffentlich): ns.Erbe.liste/stand, ns.Stimmung.abstandFaktor/
--   mikroPool/vertraut, ns.Bindung.stufe (existenzgeprueft), ns.Gestalt.bindungsstufe
--   (existenzgeprueft), ns.Regie.stumm/istStumm/loginSlot/dropLog/abstandRest, ns.Compat.istHardcore,
--   UnitLevel, GetTime, time. Nichts Fremdes, kein Netz, kein Chat-Output.
-- Events: PLAYER_DEAD, PLAYER_ENTERING_WORLD, PLAYER_LOGIN, PLAYER_LEVEL_UP.
--
-- KONTRAKT: kein SendChatMessage, kein Makro, kein Zauber, keine geschuetzte Funktion, keine
-- neue Globale, kein OnUpdate, kein Ticker. Jeder Fremd-/Kontozugriff hinter Existenzpruefung
-- und pcall. Faellt etwas aus, schweigt diese Datei — kein Lua-Fehler, keine halbe Zeile.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Welle16b = W
ns.Sinne.Welle16b = W

-- =============================================================================================
-- Voreinstellung. Haengt an ns.DEFAULTS_ACCOUNT beim LADEN der Datei (Core/Init.lua unberuehrt,
-- Muster aus Sinne/Karte2.lua/Welle13a.lua/Welle13c.lua).
-- =============================================================================================
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.erbeTrauer == nil then D.erbeTrauer = true end
end

W.TRAUER_SITZUNGEN = 2      -- so viele Sitzungen NACH dem Tod sind gedaempft
W.TRAUER_FAKTOR    = 1.5    -- Plauder-Abstand mal so viel, solange die Trauer wirkt
W.UEBERHOLT_AB     = 5      -- s nach PLAYER_LEVEL_UP: dann erst wird gemeldet (Muster STUFE_MEILENSTEIN)
W.NEUANFANG_AB     = 20     -- s: Login-Slot, wie ERBE_VORGAENGER (Sinne/Erbe.lua VORGAENGER_AB)
W.NACHHOL          = 35     -- s: zweiter Versuch, wenn der Regie-Abstand der Grund war

local function jetzt() return (GetTime and GetTime()) or 0 end
local function unix() return time() end
local function an(key) return ns.Get(key) ~= false end
local function trauerAn() return an("erbeTrauer") end
local function echterTimer() return C_Timer and C_Timer.After and true or false end

-- Dasselbe Gate wie Sinne/Erbe.lua erbeAktiv() (dort privat) — auf den oeffentlichen APIs
-- nachgebaut, weil ERBE_UEBERHOLT und die Trauer nur zaehlen sollen, wo auch Sinne/Erbe.lua
-- ueberhaupt Eintraege anlegt. Ausserhalb Hardcore also nur mit "/lyra erbeImmer".
local function erbeAktiv()
    if ns.Compat and ns.Compat.istHardcore and ns.Compat.istHardcore() then return true end
    return ns.Get("erbeImmer") and true or false
end
W.erbeAktiv = erbeAktiv

-- Bindungsstufe: erst das echte W16-Modul, dann der W16v-Helfer (Gestalt/Gestalt.lua, dieselbe
-- Rueckfallkette), zuletzt ns.Stimmung.vertraut() direkt. Jede Stufe einzeln existenzgeprueft -
-- der Wellenbrief verlangt genau das ("nur mit Existenzpruefung").
local function bindungStufe()
    if ns.Bindung and ns.Bindung.stufe then
        local ok, s = pcall(ns.Bindung.stufe)
        if ok and type(s) == "number" then return s end
    end
    if ns.Gestalt and ns.Gestalt.bindungsstufe then
        local ok, s = pcall(ns.Gestalt.bindungsstufe)
        if ok and type(s) == "number" then return s end
    end
    if ns.Stimmung and ns.Stimmung.vertraut then
        local ok, s = pcall(ns.Stimmung.vertraut)
        if ok and type(s) == "number" then return s end
    end
    return 0
end
W.bindungStufe = bindungStufe

local function chronikDB()
    local c = LyraGestaltDB and LyraGestaltDB.chronik and ns.charKey and LyraGestaltDB.chronik[ns.charKey]
    return type(c) == "table" and c or nil
end

local function melde(id, vars)
    if not ns.melde then return false end
    local ok, v = pcall(ns.melde, id, vars)
    return (ok and v) and true or false
end

-- Plauder-Zeile mit EINEM Nachhol, Muster aus Sinne/Erbe.lua meldeNachhol: nur wenn der
-- Regie-ABSTAND der Grund des Ausfalls war (Drossel/Gruppe/Still-Modus sind endgueltig).
-- danach() feuert bei JEDEM Erfolg — dem sofortigen wie dem nachgeholten.
local function meldeNachhol(id, vars, verzug, gilt, danach)
    ns.Compat.After(verzug, function()
        if gilt and not gilt() then return end
        if melde(id, vars) then if danach then danach() end return end
        if not echterTimer() then return end
        local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
        if not (d and d[2] == id and d[1] == "abstand") then return end
        local rest = (ns.Regie and ns.Regie.abstandRest and ns.Regie.abstandRest()) or 0
        ns.Compat.After(math.max(W.NACHHOL, math.min(rest + 1, 180)), function()
            if gilt and not gilt() then return end
            if melde(id, vars) and danach then danach() end
        end)
    end)
end

-- =============================================================================================
-- 1  TRAUER NACH TOD — zwei leisere Sitzungen
-- =============================================================================================

local function trauerKonto()
    if not (LyraGestaltDB and type(LyraGestaltDB.account) == "table") then return nil end
    local a = LyraGestaltDB.account
    if type(a.erbeTrauerStand) ~= "table" then a.erbeTrauerStand = { rest = 0, leerlaufVonUns = false } end
    if type(a.erbeTrauerStand.rest) ~= "number" then a.erbeTrauerStand.rest = 0 end
    return a.erbeTrauerStand
end
W.trauerKonto = trauerKonto

-- Nach dem eigenen Tod: zwei Sitzungen gedaempft, egal welcher Charakter sie als Naechstes spielt
-- (die Liste ist kontoweit, siehe Sinne/Erbe.lua Dateikopf). Der letzte Eintrag der Erbe-Liste
-- (ns.Erbe.stand()) ist bei diesem Aufruf IMMER der eigene, gerade angelegte — E.stand()s einzige
-- Schreibstelle ist ns.Erbe.todEintragen(), und die schreibt ausschliesslich UnitName("player").
local letzterEigenerTod = nil
local function todGesehen()
    if not trauerAn() then return end
    if not erbeAktiv() then return end
    if not (ns.Erbe and ns.Erbe.stand) then return end
    local ok, eintrag = pcall(ns.Erbe.stand)
    if not ok or type(eintrag) ~= "table" then return end
    if eintrag == letzterEigenerTod then return end   -- derselbe Tod schon gesehen
    letzterEigenerTod = eintrag
    local t = trauerKonto()
    if not t then return end
    t.rest = W.TRAUER_SITZUNGEN
end
W.todGesehen = todGesehen

ns.on("PLAYER_DEAD", function()
    -- 0,6 s: sicher HINTER Sinne/Erbe.lua (dort 0,5 s ns.Compat.After bis der Eintrag steht).
    ns.Compat.After(0.6, function() pcall(todGesehen) end)
end)

-- LEERLAUF an-/abschalten ueber die VORHANDENE Positivliste (Core/Regie.lua R.stumm), nicht ueber
-- einen neuen Mantel um ns.melde. "leerlaufVonUns" verhindert, dass wir eine manuelle Stumm-
-- schaltung des Spielers beim Sitzungsende versehentlich wieder aufheben.
local function leerlaufStummSetzen(daempfen)
    if not (ns.Regie and ns.Regie.stumm and ns.Regie.istStumm) then return end
    local t = trauerKonto()
    if not t then return end
    if daempfen then
        if not ns.Regie.istStumm("LEERLAUF") then
            local ok = ns.Regie.stumm("LEERLAUF", true)
            if ok then t.leerlaufVonUns = true end
        end
    elseif t.leerlaufVonUns then
        ns.Regie.stumm("LEERLAUF", false)
        t.leerlaufVonUns = false
    end
end
W.leerlaufStummSetzen = leerlaufStummSetzen

function W.trauerAktiv()
    return ns.char and ns.char.erbeTrauerSitzung == true and trauerAn() and true or false
end

-- Sitzungsgrenze: ueber die Sitzungs-STARTZEIT aus Sinne/Chronik.lua statt einer eigenen
-- "ersterPEW"-Marke. Eine neue Sitzung (Login, nicht /reload) traegt eine ANDERE Startzeit als
-- die zuletzt ausgewertete — Sinne/Chronik.lua entscheidet das schon (SITZUNG_FORTSETZEN), diese
-- Datei liest es nur ab. Der Vorteil gegenueber einer Lua-lokalen Marke: das Feld liegt in den
-- CHARAKTER-SavedVariables und bleibt darum auch ueber einen /reload MITTEN in der Sitzung
-- richtig, ohne dass diese Datei neu geladen werden muesste.
function W.sitzungsgrenze()
    local c = chronikDB()
    local s = c and c.sitzungen
    local aktuell = type(s) == "table" and s[#s]
    if not (aktuell and ns.char) then return end
    local start = tonumber(aktuell.start)
    if not start then return end
    if ns.char.erbeTrauerSitzungStart == start then return end   -- diese Sitzung schon gewertet
    ns.char.erbeTrauerSitzungStart = start
    if not trauerAn() then
        ns.char.erbeTrauerSitzung = false
        leerlaufStummSetzen(false)
        return
    end
    local t = trauerKonto()
    local gedaempft = (t and t.rest and t.rest > 0) and true or false
    ns.char.erbeTrauerSitzung = gedaempft
    if t and gedaempft then t.rest = t.rest - 1 end
    leerlaufStummSetzen(gedaempft)
end

ns.on("PLAYER_ENTERING_WORLD", function() pcall(W.sitzungsgrenze) end)

-- Mikro-Mimik der Trauer: dieselben vier Gesichter wie Sinne/Leben2.lua MIKRO_BESORGT (dort
-- privat) — hier gespiegelt, weil Leben2.lua nicht angefasst werden darf. "besorgt-nah", nicht
-- "besorgt": die echte Laune (ns.Stimmung.tags().laune) bleibt unveraendert und damit ehrlich in
-- /lyra stimmung; nur die Mikro-Auswahl (Gestalt/Gestalt.lua G.blinzeln) faerbt sich mit.
local MIKRO_TRAUER = { "hmm", "thinking", "concerned", "anxious" }

local abstandGewrappt, mikroGewrappt = false, false
local original_abstandFaktor, original_mikroPool = nil, nil

local function abstandFaktorWrappen()
    if abstandGewrappt or not (ns.Stimmung and type(ns.Stimmung.abstandFaktor) == "function") then return end
    abstandGewrappt = true
    original_abstandFaktor = ns.Stimmung.abstandFaktor
    ns.Stimmung.abstandFaktor = function()
        local ok, f = pcall(original_abstandFaktor)
        f = (ok and type(f) == "number") and f or 1
        if W.trauerAktiv() then f = f * W.TRAUER_FAKTOR end
        return f
    end
end

local function mikroPoolWrappen()
    if mikroGewrappt or not (ns.Stimmung and type(ns.Stimmung.mikroPool) == "function") then return end
    mikroGewrappt = true
    original_mikroPool = ns.Stimmung.mikroPool
    ns.Stimmung.mikroPool = function()
        if W.trauerAktiv() then return MIKRO_TRAUER end
        return original_mikroPool()
    end
end

-- MERGE18 (22.09.2026): zwei Leser auf die umwickelten Originale. Sie aendern nichts und werden
-- vom Addon selbst nirgends gerufen - sie stehen fuer die Pruefstaende der Wellen 8 und 9a, die
-- seit langem die Zusage halten "Sinne/Welle8.lua loest ns.Stimmung.abstandFaktor NICHT ab,
-- W.abstandFaktor ist DIESELBE Funktion". Mit dem Trauer-Mantel dieser Datei ist das eine Schicht
-- tiefer wahr statt falsch; ohne einen Weg zum Original haetten beide Pruefungen nur noch
-- abgeschaltet werden koennen, und das waere ein Regressionsnetz weniger gewesen.
function W.originalAbstandFaktor() return original_abstandFaktor end
function W.originalMikroPool() return original_mikroPool end

-- Deferred bis PLAYER_LOGIN (wie Sinne/Erbe.lua ns.Dialog.frage-Wrapper): Sinne/Leben2.lua steht
-- in der TOC zwar davor, aber der Wrapper soll nicht von der Reihenfolge abhaengen. Die zwei
-- Bool-Marken machen ihn re-entrant-sicher (mehrere PLAYER_LOGIN in einem Testlauf legen sich
-- nicht doppelt darueber).
ns.on("PLAYER_LOGIN", function()
    abstandFaktorWrappen()
    mikroPoolWrappen()
end)

-- =============================================================================================
-- 2  ERBE_UEBERHOLT
-- =============================================================================================

-- Der juengste Vorgaenger (Zeit, nicht Listenplatz waere genauer — aber die Liste WAECHST nur
-- ans Ende (Sinne/Erbe.lua todEintragen), ist also schon zeitlich geordnet; derselbe Vorbehalt
-- wie in E.sterbeorte() gilt hier nicht, weil MAX_ERBE nur VORNE abschneidet, nie in der Mitte).
-- Gefiltert wie ueberall in diesem Bereich: nur "selbst"/kein Feld, nie der eigene Charakter.
local function juengsterVorgaenger()
    local liste = ns.Erbe and ns.Erbe.liste and ns.Erbe.liste()
    if type(liste) ~= "table" then return nil end
    local eigen = ns.charKey or ((UnitName and UnitName("player") or "?") .. "-"
                                 .. ((GetRealmName and GetRealmName()) or "?"))
    for i = #liste, 1, -1 do
        local e = liste[i]
        if type(e) == "table" and e.name and e.name ~= ""
           and (e.quelle == nil or e.quelle == "selbst")
           and (tostring(e.name) .. "-" .. tostring(e.realm or "?")) ~= eigen then
            return e
        end
    end
    return nil
end
W.juengsterVorgaenger = juengsterVorgaenger

-- level optional (PLAYER_LEVEL_UP liefert es als erstes Argument); ohne das Argument wird
-- UnitLevel("player") gelesen — so kann der Pruefstand die Funktion auch direkt rufen.
function W.ueberholtPruefen(level)
    if not erbeAktiv() then return end
    level = tonumber(level) or (UnitLevel and UnitLevel("player")) or 0
    if level <= 0 then return end
    local v = juengsterVorgaenger()
    if not v or v.ueberholt then return end
    local vLevel = tonumber(v.level) or 0
    if level <= vLevel then return end          -- nie bei gleicher oder niedrigerer Stufe
    local vars = { vorgaenger = tostring(v.name), stufe = level }
    local gilt = function() return v.ueberholt ~= true end
    meldeNachhol("ERBE_UEBERHOLT", vars, W.UEBERHOLT_AB, gilt, function() v.ueberholt = true end)
end

ns.on("PLAYER_LEVEL_UP", function(level) pcall(W.ueberholtPruefen, level) end)

-- =============================================================================================
-- 3  ERBE_NEUANFANG — "ich kenn dich, nicht deinen Namen"
-- =============================================================================================

-- Neuer Charakter: hoechstens die eine Sitzung, die Sinne/Chronik.lua bei diesem Login gerade
-- angelegt hat (Muster aus Sinne/Leben2.lua ersteSitzung(), dort privat).
local function neuerCharakter()
    local c = chronikDB()
    local s = c and c.sitzungen
    return type(s) == "table" and #s <= 1
end
W.neuerCharakter = neuerCharakter

-- Einmal je SITZUNG geplant, nicht einmal je Prozess: dieselbe Sitzungs-Startzeit-Wache wie
-- W.sitzungsgrenze() oben (statt einer "ersterPEW"-Marke), damit mehrere PLAYER_ENTERING_WORLD
-- in der ERSTEN Sitzung (Zonenwechsel, bevor der Login-Slot gefeuert hat) nicht zweimal planen -
-- ein zweiter Plan waere sonst ein zweites meldeNachhol auf dieselbe, noch offene Zusage und
-- koennte die Zeile theoretisch doppelt ausliefern. ns.char.erbeNeuanfangGesagt bleibt trotzdem
-- die eigentliche "einmal je Charakter"-Zusage; diese Wache verhindert nur das Doppel-PLANEN.
function W.neuanfangPruefen()
    if not (ns.char and not ns.char.erbeNeuanfangGesagt) then return end
    local c = chronikDB()
    local s = c and c.sitzungen
    local aktuell = type(s) == "table" and s[#s]
    if not aktuell then return end
    local start = tonumber(aktuell.start)
    if not start then return end
    if ns.char.erbeNeuanfangSitzungStart == start then return end   -- diese Sitzung schon geplant
    ns.char.erbeNeuanfangSitzungStart = start
    if not neuerCharakter() then return end
    if bindungStufe() < 1 then return end
    local verzug = W.NEUANFANG_AB
    if ns.Regie and ns.Regie.loginSlot then
        local ok, v = pcall(ns.Regie.loginSlot, W.NEUANFANG_AB)
        if ok and type(v) == "number" then verzug = v end
    end
    local gilt = function() return ns.char and not ns.char.erbeNeuanfangGesagt end
    meldeNachhol("ERBE_NEUANFANG", nil, verzug, gilt, function()
        if ns.char then ns.char.erbeNeuanfangGesagt = true end
    end)
end

ns.on("PLAYER_ENTERING_WORLD", function() pcall(W.neuanfangPruefen) end)

-- =============================================================================================
-- /lyra status + Introspektion fuer den Pruefstand
-- =============================================================================================
local TEXT = {
    de = {
        an   = "Trauer nach Tod: an — %s.",
        aus  = "Trauer nach Tod: aus.",
        keine = "keine (kein eigener Tod nachgetragen)",
        rest = "noch %d gedaempfte Sitzung(en)",
        jetzt = "diese Sitzung ist gedaempft (Abstand x%.1f)",
    },
    en = {
        an   = "Grief after death: on — %s.",
        aus  = "Grief after death: off.",
        keine = "none (no death of your own on record)",
        rest = "%d dampened session(s) left",
        jetzt = "this session is dampened (spacing x%.1f)",
    },
}
local function T() return TEXT[ns.sprache()] or TEXT.en end

function W.status()
    local t = T()
    local out = {}
    if not trauerAn() then
        out[1] = t.aus
        return out
    end
    local konto = trauerKonto()
    local rest = konto and konto.rest or 0
    local satz
    if W.trauerAktiv() then satz = t.jetzt:format(W.TRAUER_FAKTOR)
    elseif rest and rest > 0 then satz = t.rest:format(rest)
    else satz = t.keine end
    out[1] = t.an:format(satz)
    return out
end

function W.stand()
    return trauerKonto(), W.trauerAktiv(), letzterEigenerTod, ns.char and ns.char.erbeNeuanfangGesagt
end
