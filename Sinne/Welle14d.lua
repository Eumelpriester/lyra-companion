-- Sinne/Welle14d.lua — Welle 14d "Tempo und Leitung" (0.20.0, 22.09.2026).
--
-- Bauplan: docs/OFFEN-HARALD.md Zeile 143 (Harald 21.09.), gemeinsamer Auftrag
-- scratchpad/w20-brief-gemeinsam.md, Regel 1-6 aus docs/recherche/18-andockstellen-2026-09-21.md §3.
--
-- WAS DIESE DATEI TUT, in einem Satz: sie sagt NUR, wenn es gefaehrlich (die Leitung) oder
-- bemerkenswert (das eigene Tempo) wird — nie, was Blizzard am Latenz-Knopf, am XP-Balken oder
-- am Ruf-Balken schon selbst zeigt (Regel 1/2 der Andockstellen-Regel: kein Nachplappern, hoechstens
-- eine Zahl je Zeile).
--
-- DREI TEILE, NATIV, KEINE ANDOCKSTELLE AN EIN FREMDES ADDON:
--   A. PING-WARNUNG (Haekchen "leitung"). Ticker alle zehn Sekunden liest GetNetStats(),
--      glaettet ueber den Median der letzten drei Werte, meldet nur an FLANKEN (unter -> ueber
--      einer Schwelle), nie eine Zahl in der Sprachzeile (nur optional als Untertitel).
--   B. STUFENTEMPO (Haekchen "tempo"). Gespielte Sekunden je Charakterstufe, ueber Sitzungen
--      hinweg im Char-Bereich gemerkt; bei Levelup (20 s Verzug) ein Vergleich mit der Stufe
--      davor — nur wenn beide vollstaendig MIT dem Addon gespielt wurden.
--   C. RUFTEMPO (Haekchen "tempo"). Beobachtete Fraktion, Zuwachs seit Sitzungsbeginn; einmal je
--      Sitzung eine Prognose, wenn die naechste Ruf-Stufe in unter drei Stunden erreicht waere.
--
-- WARUM VIER PING-EREIGNISSE UND NICHT ZWEI ZEILEN AN EINEM GEMEINSAMEN TOPF (dasselbe Argument
-- wie Sinne/Welle14b.lua bei den vier Flugdauer-Klassen): Core/Regie.lua waehle() zieht eine
-- Zeile ZUFAELLIG aus dem Topf eines Ereignisses; der einzige Filter ist ein fehlender
-- Platzhalter und der wenn-Tag (der die LAUNE liest, nicht vars). Ein "Zieh den jetzt nicht"
-- duerfte niemals zufaellig anstelle von "Leitung bricht weg" fallen, wenn beide im selben Topf
-- laegen — die beiden sagen etwas fachlich anderes. Vier eigene IDs (PING_HOCH, PING_KRITISCH,
-- PING_VOR_PULL, PING_GUT) sind darum kein neues Muster, sondern das bestehende.
--
-- WARUM ZWEI STUFENTEMPO-EREIGNISSE UND NICHT EINS MIT DREI TEXTEN: derselbe Grund. "Die ging
-- schneller" und "Die hat gedauert" duerfen nie gegeneinander vertauscht werden — Core/Regie.lua
-- kennt keinen Filter auf vars, der "schneller" von "langsamer" trennen koennte. Der dritte Fall
-- ("sonst") bekommt gar keine ID: er ist schlicht Stille, kein drittes Ereignis.
--
-- KONTRAKT: kein SendChatMessage, kein SendAddonMessage, kein C_ChatInfo, kein RunMacro, kein
-- CastSpell, keine geschuetzte Funktion, kein Netz, keine Fremddaten, keine neue Globale. Jeder
-- Zugriff auf eine Spiel-API steht in pcall hinter einer Existenzpruefung auf EIN konkretes Feld.
-- Faellt eine API aus, ist diese Datei an genau dieser Stelle still — kein Lua-Fehler — und
-- /lyra status sagt es (W.status()). Kein OnUpdate: ein einziger Ticker (Ping, 10 s), mit
-- Notbremse ueber das Haekchen "leitung" (Start/Stop ueber ns.onSetting, zusaetzlich prueft
-- jeder Tick das Haekchen selbst). Das Stufentempo braucht KEINEN Ticker fuer die Ansage —
-- nur einen 60-s-Schreib-Ticker, der reine Rechenarbeit ist (GetTime-Differenz), kein Zustand,
-- der je aus dem Ruder laufen koennte.
--
-- NIE IM KAMPF (Stufe 1), NIE TOT, NIE IM LADEBILDSCHIRM: Core/Regie.lua haelt den Tod-Riegel
-- (60 s) und die Stufe-1-Bremse (15 s / 10 je Stunde) ohnehin; diese Datei prueft zusaetzlich
-- explizit UnitIsDeadOrGhost/UnitAffectingCombat (Muster: Sinne/Extra.lua, Sinne/Kampf.lua) und
-- ns.Welle14b.imLadebildschirm() (existenzgeprueft — das Schwesterteam der Flugzeit-Welle baut
-- diese Klammer; fehlt die Datei, gilt "nicht im Ladebildschirm").
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Welle14d = W
ns.Sinne.Welle14d = W

local C = ns.Compat

-- ---------------------------------------------------------------------------------------------
-- Voreinstellungen. ZWEI Kaestchen, benannt nach dem, was sie TUN. Core/Init.lua gehoert einem
-- anderen Team, darum haengen die Schluessel hier an ns.DEFAULTS_ACCOUNT — auf DATEIEBENE, also
-- lange vor ns.initDB() (Muster: Sinne/Welle13a.lua, Sinne/Welle14b.lua).
-- ---------------------------------------------------------------------------------------------
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.leitung == nil then D.leitung = true end   -- A) Ping-Warnung
    if D.tempo == nil then D.tempo = true end        -- B+C) Stufen- und Ruftempo
end

-- ---------------------------------------------------------------------------------------------
-- Feature-Weiche ZUERST. Gefragt wird nach der FUNKTION, nicht nach dem Client (Core/Compat.lua,
-- Kopf). Jede fehlende Faehigkeit schaltet nur IHREN Teil still — die drei Teile sind
-- unabhaengig voneinander.
-- ---------------------------------------------------------------------------------------------
W.F = {
    ping   = (type(_G.GetNetStats) == "function"),
    ticker = (type(_G.C_Timer) == "table" and type(_G.C_Timer.NewTicker) == "function"),
    ruf    = (type(_G.GetWatchedFactionInfo) == "function")
             or (type(_G.C_Reputation) == "table"
                 and type(_G.C_Reputation.GetWatchedFactionData) == "function"),
}

-- ---------------------------------------------------------------------------------------------
-- Konstanten. Alle Schwellen und Fristen stehen HIER und nirgends sonst im Code.
-- ---------------------------------------------------------------------------------------------
W.TICK             = 10       -- s, Ping-Ticker
W.MEDIAN_N         = 3        -- Glaettung: Median der letzten drei Rohwerte
W.HOCH             = 250      -- ms, Schwelle "hoch"
W.KRITISCH         = 600      -- ms, Schwelle "kritisch"
W.HYSTERESE_UNTER  = 200      -- ms, muss zwischen zwei PING_HOCH-Meldungen unterschritten werden
W.DROSSEL_HOCH     = 600      -- s = 10 min, Mindestabstand zweier PING_HOCH
W.DROSSEL_KRIT     = 300      -- s = 5 min, Mindestabstand zweier PING_KRITISCH
W.VOR_PULL_ABSTAND = 120      -- s = 2 min seit der letzten Ping-Zeile
W.STUFE_AB         = 10       -- Stufentempo erst ab dieser abgeschlossenen Stufe
W.SCHNELLER_FAKTOR = 0.8      -- <= 80 % der vorigen Dauer = "schneller" (>= 20 % kuerzer)
W.LANGSAMER_FAKTOR = 1.5      -- >= 150 % der vorigen Dauer = "langsamer" (>= 50 % laenger)
W.LEVELUP_VERZUG   = 20       -- s nach PLAYER_LEVEL_UP, damit die Feier zuerst kommt
W.CHECKPOINT       = 60       -- s, Absturzsicherung fuer das Stufentempo
W.MUELL_DELTA      = 3700     -- s, groesserer GetTime-Sprung (Systemuhr) wird nicht gutgeschrieben
W.RUF_MIN_SITZUNG  = 1800     -- s = 30 min, fruehester Zeitpunkt fuer RUF_TEMPO
W.RUF_MIN_ZUWACHS  = 500      -- Mindestzuwachs seit Sitzungsbeginn
W.RUF_ETA_MAX      = 10800    -- s = 3 h, Prognose muss darunter liegen

-- ---------------------------------------------------------------------------------------------
-- Werkzeug. Dieselben Helfer wie in jedem anderen Sinn (Muster: Sinne/Extra.lua, Sinne/Kampf.lua,
-- Sinne/Welle14b.lua).
-- ---------------------------------------------------------------------------------------------
local function jetzt() return (GetTime and GetTime()) or 0 end
local function tot() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false end
local function imKampf() return UnitAffectingCombat and UnitAffectingCombat("player") or false end
-- nil zaehlt als AN: vor ns.initDB() gibt ns.Get die Vorgabe zurueck, und die steht oben auf true.
local function an(schluessel) return ns.Get(schluessel) ~= false end

local function inLadebildschirm()
    if ns.Welle14b and type(ns.Welle14b.imLadebildschirm) == "function" then
        local ok, v = pcall(ns.Welle14b.imLadebildschirm)
        return ok and v == true
    end
    return false
end

local function melde(id, vars)
    if not ns.melde then return false end
    local ok, v = pcall(ns.melde, id, vars)
    return (ok and v) and true or false
end

-- Ein Nachhol, EINMAL, nur wenn Regie's Mindestabstand der Grund war (Muster: Sinne/Welle14b.lua
-- meldeNachhol, Sinne/Welle16b.lua). Wozu das noetig ist: der 20-s-Verzug nach PLAYER_LEVEL_UP
-- ist KUERZER als der normale plauder-Mindestabstand (ab Werk 30 s) - und Sinne/Alltag.lua feiert
-- den Levelup selbst mit einer eigenen plauder-Zeile, die genau diesen Abstand fast immer zuerst
-- verbraucht. Ohne Nachhol waere STUFE_TEMPO_SCHNELLER/LANGSAMER in der Praxis fast nie zu hoeren.
-- MERGE20 (Merge 0.20.0, 22.09.2026): auf das 4x-Muster aus Sinne/Welle14b.lua (FIX 0.19.1)
-- angeglichen - nach einem Levelup stehen LEVELUP-Feier, Chronik-Meilenstein und ggf. ZONE
-- Schlange, und ein einziger Nachhol faellt genauso in den Abstand wie der erste Versuch.
-- Gleiches Verhalten in allen Kopien (Welle14b/14c/14d).
W.NACHHOL_MAX = 4
local function meldeNachhol(id, vars, gilt, versuch)
    versuch = versuch or 1
    if melde(id, vars) then return true end
    if versuch >= W.NACHHOL_MAX then return false end
    local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
    if not (d and d[2] == id and d[1] == "abstand") then return false end
    local rest = 0
    if ns.Regie and ns.Regie.abstandRest then
        local ok, r = pcall(ns.Regie.abstandRest)
        if ok and type(r) == "number" then rest = r end
    end
    local verzug = math.max(2, math.min(rest + 1, 180))
    C.After(verzug, function()
        if gilt and not gilt() then return end
        meldeNachhol(id, vars, gilt, versuch + 1)
    end)
    return false
end

-- MERGE 0.20.0 (22.09.2026): "EIN ZIELWECHSEL, HOECHSTENS EIN SATZ." Am selben
-- PLAYER_TARGET_CHANGED sprechen vor uns schon Sinne/Kampf.lua (GEFAHR_ELITE ist Stufe 2 und
-- NICHT von der Stufe-1-Bremse erfasst, GEFAHR_STUFEN Stufe 1), Sinne/Extra.lua (RUNNER_BEKANNT,
-- Stufe 2) und Sinne/Chronik.lua (BESTIARIUM/MOB_RIVALE_WARNUNG); Sinne/Welle13b.lua sagt 1,5 s
-- spaeter die Mechanik des Ziels. Ein Vorbereitungs-Hinweis obendrauf waere die Doppelung, die
-- Regel 1 verbietet (Blase ersetzt, Stimme schneidet ab). Also: hat dieser Zielwechsel schon
-- gesprochen (eine Nicht-still-Ausgabe in derselben Sekunde) ODER steht die Mechanik-Zeile an,
-- schweigt der Hinweis - OHNE seine Drossel zu verbrauchen; er kommt beim naechsten Zielwechsel.
-- Die Gefahr des Ziels selbst geht jedem Vorbereitungs-Hinweis vor.
W.ZIEL_RUHE = 1   -- s: "in derselben Sekunde" (ns.on ruft alle Haken eines Ereignisses im selben Frame)
local letzteSatzZeit = -1e9
if ns.nachAusgabe then
    ns.nachAusgabe(function(_, e) if not (e and e.klasse == "still") then letzteSatzZeit = jetzt() end end)
end
local function zielBelegt()
    if jetzt() - letzteSatzZeit < W.ZIEL_RUHE then return true end
    local w13b = ns.Welle13b
    if w13b and type(w13b.mechanikSteht) == "function" then
        local ok, v = pcall(w13b.mechanikSteht)
        if ok and v == true then return true end
    end
    return false
end
W.zielBelegt = zielBelegt   -- fuer den Pruefstand

-- Median einer Liste (bis zu drei Rohwerte). Muell (Strings, negative Zahlen) wird ausgesiebt.
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

-- =================================================================================================
-- A) PING-WARNUNG
-- =================================================================================================
-- puf           Ringpuffer der letzten (bis zu drei) Rohmessungen
-- wert          aktueller Median oder nil (vor der ersten gueltigen Messung, oder wenn die API
--               dauerhaft ausfaellt/wirft/Muell liefert)
-- hochGesperrtBis / kritGesperrtBis   naechster erlaubter Zeitpunkt fuer die jeweilige Meldung
-- hystereseOffen   true, sobald der Median seit der letzten PING_HOCH-Meldung unter 200 ms war
-- nachholHoch      true, waehrend eine PING_HOCH-Flanke auf das Kampfende wartet
-- letzteZeile      Zeitpunkt der letzten ERFOLGREICHEN Ping-Zeile (fuer den Vor-Pull-Abstand)
-- gutFaellig       true, sobald einmal PING_HOCH/PING_KRITISCH/PING_VOR_PULL kam - erst dann darf
--                  PING_GUT ueberhaupt in Frage kommen ("die Leitung STEHT WIEDER" braucht einen
--                  vorherigen Anlass, sonst waere die allererste gute Sitzung schon "wieder gut")
local ping = {
    puf = {}, wert = nil,
    hochGesperrtBis = 0, kritGesperrtBis = 0,
    hystereseOffen = true, nachholHoch = false,
    letzteZeile = -1e9, gutFaellig = false,
    ticker = nil,
}
W.ping_ = ping   -- fuer den Pruefstand (roher Zustand, nur lesen)

-- GetNetStats(): bandwidthIn, bandwidthOut, latencyHome, latencyWorld (ms). Der Client
-- aktualisiert nur alle ~30 s. Welt-Latenz zaehlt (die zaehlt im Kampf), Rueckfall Heim-Latenz,
-- wenn Welt 0 oder nil ist.
local function pingLesen()
    if type(_G.GetNetStats) ~= "function" then return nil end
    local ok, _, _, latHeim, latWelt = pcall(_G.GetNetStats)
    if not ok then return nil end
    latWelt = tonumber(latWelt)
    if latWelt and latWelt > 0 then return latWelt end
    latHeim = tonumber(latHeim)
    if latHeim and latHeim > 0 then return latHeim end
    return nil
end

local function pruefePingGut()
    if not ping.gutFaellig then return end
    if not (ping.wert and ping.wert < W.HYSTERESE_UNTER) then return end
    if tot() or inLadebildschirm() then return end
    if not an("leitung") then return end
    -- MERGE20: gutFaellig wird VOR dem Versuch zurueckgenommen (Muster ruf.gemeldet). Vorher
    -- stiess JEDER 10-s-Tick unter 200 ms die Meldung neu an, und nach dem ersten Erfolg fiel
    -- sie alle zehn Sekunden als "drossel" in den Debug-Chat - dasselbe Rauschen wie beim
    -- FRAGE_NACHKLANG-Hotfix vom 22.09. Scharf wird sie erst wieder mit der naechsten Warnung.
    ping.gutFaellig = false
    -- Regie-Drossel "session": kommt ohnehin nur einmal je Sitzung durch. MERGE20: mit gilt() -
    -- ein spaeter Nachhol darf "Leitung steht wieder" nicht sagen, wenn sie inzwischen wieder haengt.
    meldeNachhol("PING_GUT", {}, function()
        return ping.wert ~= nil and ping.wert < W.HYSTERESE_UNTER and an("leitung")
               and not (tot() or inLadebildschirm())
    end)
end

-- PING_HOCH. Stufe 1 darf nie im Kampf sprechen (design-v2 5.2/Auftrag) - waehrend des Kampfes
-- wird nur GEMERKT, dass eine Meldung ansteht (ping.nachholHoch); PLAYER_REGEN_ENABLED ruft diese
-- Funktion danach ERNEUT auf und prueft dabei den AKTUELLEN Zustand noch einmal (das ist die
-- "eigene kleine Implementierung mit einer gilt()-Pruefung" aus dem Auftrag: kein gespeicherter
-- Text, sondern ein erneuter, vollstaendiger Durchlauf derselben Funktion).
local function pruefePingHoch()
    if not (ping.wert and ping.wert >= W.HOCH) then ping.nachholHoch = false; return end
    if tot() or inLadebildschirm() then return end
    if imKampf() then ping.nachholHoch = true; return end
    if not an("leitung") then return end
    local t = jetzt()
    if t < ping.hochGesperrtBis then return end
    if not ping.hystereseOffen then return end
    if melde("PING_HOCH", {}) then
        ping.hochGesperrtBis = t + W.DROSSEL_HOCH
        ping.hystereseOffen = false
        ping.nachholHoch = false
        ping.letzteZeile = t
        ping.gutFaellig = true
    end
end

-- PING_KRITISCH. Stufe 2 darf im Kampf - kommt sofort, kein Nachhol noetig.
local function pruefePingKrit()
    if not (ping.wert and ping.wert >= W.KRITISCH) then return end
    if tot() or inLadebildschirm() then return end
    if not an("leitung") then return end
    local t = jetzt()
    if t < ping.kritGesperrtBis then return end
    if melde("PING_KRITISCH", {}) then
        ping.kritGesperrtBis = t + W.DROSSEL_KRIT
        ping.letzteZeile = t
        ping.gutFaellig = true
    end
end

-- Der Ping-Ticker: alle zehn Sekunden lesen, glaetten, auf FLANKEN pruefen (unter -> ueber einer
-- Schwelle). Ein direkter Sprung von unter 250 auf ueber 600 zaehlt NUR als kritisch — zwei
-- Zeilen fuer denselben Sprung waeren Geplapper, und die dringendere gewinnt.
local function tickPing()
    if not an("leitung") then return end          -- Notbremse: der Tick selbst prueft das Haekchen
    if not W.F.ping then return end
    if inLadebildschirm() then return end
    local roh = pingLesen()
    if roh then
        table.insert(ping.puf, roh)
        while #ping.puf > W.MEDIAN_N do table.remove(ping.puf, 1) end
    end
    if #ping.puf == 0 then return end
    local vorher = ping.wert
    local neu = median(ping.puf)
    if not neu then return end
    ping.wert = neu
    if neu < W.HYSTERESE_UNTER then
        ping.hystereseOffen = true
        pruefePingGut()
    end
    local warKrit = (vorher ~= nil) and (vorher >= W.KRITISCH)
    local warHoch = (vorher ~= nil) and (vorher >= W.HOCH)
    if (not warKrit) and neu >= W.KRITISCH then
        pruefePingKrit()
    elseif (not warHoch) and neu >= W.HOCH then
        pruefePingHoch()
    end
end
W.tickPing = tickPing   -- fuer den Pruefstand (den Tick von Hand anstossen)

-- MERGE20 (Merge 0.20.0): EIN Ticker fuer diese Datei, nicht zwei. Der Pruefstand w8-leistung
-- deckelt die Dauer-Ticker des ganzen Addons auf zwoelf; mit dem Ping-Ticker UND einem eigenen
-- 60-s-Checkpoint-Ticker waeren es dreizehn gewesen. Darum: laeuft der Ping-Ticker, schreibt er
-- das Stufentempo gleich mit fest (checkpointFaellig, alle 50-60 s - der Absturz-Verlust bleibt
-- unter einer Minute); nur wenn er NICHT laeuft (Haekchen "leitung" aus, kein GetNetStats),
-- uebernimmt ein eigener 60-s-Checkpoint-Ticker. checkpointTakt() haelt genau einen am Laufen.
local checkpointFaellig, checkpointTakt   -- unten bei B) definiert (brauchen T und festschreiben)
local function tickerStart()
    if ping.ticker then return end
    if not (W.F.ping and W.F.ticker) then return end
    if not an("leitung") then return end
    ping.ticker = C.NewTicker(W.TICK, function()
        if checkpointFaellig then pcall(checkpointFaellig) end
        pcall(tickPing)
    end)
    if checkpointTakt then pcall(checkpointTakt) end
end
local function tickerStop()
    if ping.ticker then pcall(function() ping.ticker:Cancel() end); ping.ticker = nil end
    if checkpointTakt then pcall(checkpointTakt) end
end
W.tickerLaeuft = function() return ping.ticker ~= nil end   -- fuer den Pruefstand

-- Vor dem Pull: PLAYER_TARGET_CHANGED auf ein angreifbares, lebendiges, nicht spielergesteuertes
-- Ziel ausserhalb des Kampfes, wenn der Median gerade hoch ist und die letzte Ping-Zeile lange
-- genug her ist. Eigenes Ereignis PING_VOR_PULL (Muster Kampf.lua zielPruefe/feindImKampf: Grenze
-- B zuerst - UnitIsPlayer/UnitPlayerControlled - dann UnitCanAttack, dann UnitIsDeadOrGhost).
local function zielPruefeVorPull()
    if not (W.F.ping and an("leitung")) then return end
    if tot() or imKampf() or inLadebildschirm() then return end
    if not (ping.wert and ping.wert >= W.HOCH) then return end
    local t = jetzt()
    if t - ping.letzteZeile < W.VOR_PULL_ABSTAND then return end
    if not (UnitExists and UnitExists("target")) then return end
    if UnitIsPlayer and UnitIsPlayer("target") then return end          -- Grenze B, als Erstes
    if UnitPlayerControlled and UnitPlayerControlled("target") then return end
    if not (UnitCanAttack and UnitCanAttack("player", "target")) then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("target") then return end
    if zielBelegt() then return end   -- MERGE20: ein Zielwechsel, hoechstens ein Satz
    if melde("PING_VOR_PULL", {}) then
        ping.letzteZeile = t
        ping.gutFaellig = true
    end
end
W.zielPruefeVorPull = zielPruefeVorPull   -- fuer den Pruefstand

-- =================================================================================================
-- B) STUFENTEMPO
-- =================================================================================================
-- Speicher im CHAR-Bereich (Muster Core/Init.lua ns.char/ns.DEFAULTS_CHAR): eine Strecke dauert
-- fuer jeden Charakter unterschiedlich lang, anders als Welle14b's Flugzeiten (Konto). Die
-- Tabelle steht NICHT in DEFAULTS_CHAR: defaults() wuerde eine leere Tabelle in jede
-- SavedVariables-Datei kopieren, auch wenn nie eine Stufe vollstaendig gemessen wurde.
--   ns.char.stufenTempo      = { [stufe] = gespielte Sekunden (Ringpuffer keiner, nur Summe) }
--   ns.char.stufenTempoStart = { [stufe] = true, wenn der START dieser Stufe MIT dem Addon
--                                gesehen wurde (per PLAYER_LEVEL_UP) - nur dann zaehlt ihre Dauer
--                                als vollstaendig gemessen und darf in einen Vergleich einfliessen.
local T = { level = nil, seit = 0, ticker = nil }

local function tabelle()
    if type(ns.char) ~= "table" then return nil end
    if type(ns.char.stufenTempo) ~= "table" then ns.char.stufenTempo = {} end
    return ns.char.stufenTempo
end
local function vollTabelle()
    if type(ns.char) ~= "table" then return nil end
    if type(ns.char.stufenTempoStart) ~= "table" then ns.char.stufenTempoStart = {} end
    return ns.char.stufenTempoStart
end

-- Schreibt die seit T.seit vergangene Zeit der AKTUELLEN Stufe fest. Wird bei PLAYER_LEAVING_WORLD/
-- PLAYER_LOGOUT und alle 60 s gerufen - ein Absturz kostet damit hoechstens eine Minute.
local function festschreiben()
    if not T.level then return end
    local t = tabelle()
    if not t then return end
    local jetztT = jetzt()
    local delta = jetztT - T.seit
    T.seit = jetztT
    if delta <= 0 or delta > W.MUELL_DELTA then return end   -- Systemuhr-Sprung: nicht gutschreiben
    t[T.level] = (tonumber(t[T.level]) or 0) + delta
end
W.festschreiben = festschreiben   -- fuer den Pruefstand (den 60-s-Checkpoint von Hand anstossen)

-- MERGE20: der Checkpoint reitet auf dem Ping-Ticker (siehe tickerStart). Faellig, sobald die
-- offene Strecke W.CHECKPOINT - W.TICK erreicht: bei 10-s-Takt also alle 50 s, und die offene
-- Strecke bleibt damit sicher unter W.CHECKPOINT (Pruefstand SB2).
checkpointFaellig = function()
    if T.level and jetzt() - T.seit >= (W.CHECKPOINT - W.TICK) then festschreiben() end
end
checkpointTakt = function()
    if ping.ticker then
        if T.ticker then pcall(function() T.ticker:Cancel() end); T.ticker = nil end
    elseif not T.ticker and T.level then
        T.ticker = C.NewTicker(W.CHECKPOINT, function() pcall(festschreiben) end)
    end
end

local function levelInit()
    if T.level then return end
    local lvl = C and C.unitLevelLesbar and C.unitLevelLesbar("player")
    lvl = tonumber(lvl)
    if not lvl then return end
    T.level = lvl
    T.seit = jetzt()
    checkpointTakt()
end
W.levelInit = levelInit   -- fuer den Pruefstand

-- Vergleich: die abgeschlossene Stufe gegen die davor. Nur wenn BEIDE vollstaendig gemessen
-- wurden (voll[abgeschlossen] und voll[davor]) und beide eine Dauer > 0 tragen.
local function stufeTempoAuswerten(abgeschlossen, davor)
    if not (abgeschlossen and davor) then return end
    if abgeschlossen < W.STUFE_AB then return end
    if not an("tempo") then return end
    local t, voll = tabelle(), vollTabelle()
    if not (t and voll) then return end
    if not (voll[abgeschlossen] and voll[davor]) then return end
    local neu, alt = tonumber(t[abgeschlossen]), tonumber(t[davor])
    if not (neu and alt and neu > 0 and alt > 0) then return end
    local verhaeltnis = neu / alt
    if verhaeltnis <= W.SCHNELLER_FAKTOR then
        local vars = {}
        local minuten = math.floor(neu / 60 + 0.5)
        if minuten >= 1 then vars.minuten = minuten end
        meldeNachhol("STUFE_TEMPO_SCHNELLER", vars, nil)
    elseif verhaeltnis >= W.LANGSAMER_FAKTOR then
        meldeNachhol("STUFE_TEMPO_LANGSAMER", {}, nil)
    end
    -- sonst (dazwischen): still - genau das ist der dritte "Lage" aus dem Auftrag.
end
W.stufeTempoAuswerten = stufeTempoAuswerten   -- fuer den Pruefstand

-- level optional (PLAYER_LEVEL_UP liefert es als erstes Argument); ohne das Argument wird
-- UnitLevel gelesen - so kann der Pruefstand die Funktion auch direkt rufen (Muster:
-- Sinne/Welle16b.lua W.ueberholtPruefen).
local function levelUp(levelRoh)
    local neu = tonumber(levelRoh)
    if not neu then
        local l = C and C.unitLevelLesbar and C.unitLevelLesbar("player")
        neu = tonumber(l)
    end
    if not neu then return end
    festschreiben()                 -- schreibt die Sekunden der GERADE ABGESCHLOSSENEN Stufe fest
    local alt = T.level
    T.level = neu
    T.seit = jetzt()
    local voll = vollTabelle()
    if voll then voll[neu] = true end   -- die neue Stufe beginnt JETZT - der Start ist bekannt
    pcall(checkpointTakt)               -- MERGE20: falls T.level bis eben fehlte
    if alt then
        -- 20 s Verzug: die Feier (LEVELUP, Sinne/Alltag.lua) kommt zuerst.
        C.After(W.LEVELUP_VERZUG, function() pcall(stufeTempoAuswerten, alt, alt - 1) end)
    end
end
W.levelUp = levelUp   -- fuer den Pruefstand

-- =================================================================================================
-- C) RUFTEMPO
-- =================================================================================================
-- Reine Sitzungsgroesse, keine SavedVariables noetig (der Auftrag verlangt "je Sitzung").
--   name/stufe   die beobachtete Fraktion und ihr Standing-Index (fuer den Fraktions-/Stufenwechsel)
--   start/wert   Ruf bei Sitzungsbeginn dieser Stufe / zuletzt gelesener Ruf (fuer den Zuwachs)
--   max          obere Bar-Grenze der aktuellen Stufe (fuer die Prognose)
--   seit         GetTime() des Sitzungsbeginns dieser Stufe
--   gemeldet     schon einmal in dieser Sitzung gemeldet (die Regie-Drossel "session" deckt das
--                zusaetzlich ab; dieses Feld haelt den Grund fest, warum wir gar nicht erst fragen)
local ruf = { name = nil, stufe = nil, start = nil, wert = nil, max = nil, seit = 0, gemeldet = false }

-- Erster Weg: C_Reputation.GetWatchedFactionData() (neuere Clients). Zweiter Weg:
-- GetWatchedFactionInfo() (Classic). Beide nur LESEND, beide in pcall, beide mit
-- Existenzpruefung auf EIN konkretes Feld (Andockstellen-Regel 4). Kein Text-Parsing von
-- CHAT_MSG_COMBAT_FACTION_CHANGE - das Ereignis ist nur ein ANLASS, hier noch einmal nachzusehen.
local function rufLesen()
    if type(_G.C_Reputation) == "table" and type(_G.C_Reputation.GetWatchedFactionData) == "function" then
        local ok, d = pcall(_G.C_Reputation.GetWatchedFactionData)
        if ok and type(d) == "table" and type(d.name) == "string" and d.name ~= "" then
            local stufe = tonumber(d.reaction)
            local minB  = tonumber(d.currentReactionThreshold)
            local maxB  = tonumber(d.nextReactionThreshold)
            local wert  = tonumber(d.currentStanding)
            if stufe and minB and maxB and wert then return d.name, stufe, minB, maxB, wert end
        end
    end
    if type(_G.GetWatchedFactionInfo) == "function" then
        local ok, name, stufe, minB, maxB, wert = pcall(_G.GetWatchedFactionInfo)
        if ok and type(name) == "string" and name ~= "" then
            stufe, minB, maxB, wert = tonumber(stufe), tonumber(minB), tonumber(maxB), tonumber(wert)
            if stufe and minB and maxB and wert then return name, stufe, minB, maxB, wert end
        end
    end
    return nil
end

local function rufPruefen()
    local name, stufe, minB, maxB, wert = rufLesen()
    if not (name and stufe and minB and maxB and wert
            and maxB > minB and wert >= minB and wert <= maxB) then
        return   -- API fehlt/wirft/liefert Muell, oder keine beobachtete Fraktion: still
    end
    local t = jetzt()
    if ruf.name ~= name or ruf.stufe ~= stufe then
        -- neue Fraktion ODER ein Stufensprung derselben Fraktion (die Bar-Grenzen springen mit,
        -- der Auftrag verlangt den Reset nur beim Fraktionswechsel - ein Stufensprung macht die
        -- alte Rechnung aber ebenso ungueltig, darum bewusst dieselbe Behandlung): Sitzungsmesser neu.
        ruf.name, ruf.stufe = name, stufe
        ruf.start, ruf.seit, ruf.gemeldet = wert, t, false
    end
    ruf.wert, ruf.max = wert, maxB
    if not an("tempo") then return end
    if ruf.gemeldet then return end
    local sitzungsdauer = t - ruf.seit
    if sitzungsdauer < W.RUF_MIN_SITZUNG then return end
    local zuwachs = wert - (ruf.start or wert)
    if zuwachs < W.RUF_MIN_ZUWACHS then return end     -- Verlust oder zu wenig: still
    local rate = zuwachs / sitzungsdauer                 -- Ruf je Sekunde
    if rate <= 0 then return end
    local rest = maxB - wert
    local etaSek = rest / rate
    if etaSek >= W.RUF_ETA_MAX then return end
    local vars = {}
    local label = _G["FACTION_STANDING_LABEL" .. tostring(stufe + 1)]
    if type(label) == "string" and label ~= "" then vars.standing = label end
    -- ruf.gemeldet wird OPTIMISTISCH sofort gesetzt (nicht erst beim Erfolg): sonst koennte das
    -- naechste UPDATE_FACTION, noch bevor der Nachhol gefeuert hat, denselben Versuch ein zweites
    -- Mal anstossen. Verpasst der seltene Nachhol seinen Anschluss doch (gilt() liefert false),
    -- bleibt RUF_TEMPO diese Sitzung eben ungesagt - besser als ein doppelter Versuch.
    ruf.gemeldet = true
    meldeNachhol("RUF_TEMPO", vars, function() return true end)
end
W.rufPruefen = rufPruefen   -- fuer den Pruefstand
W.rufStand = function() return ruf.name, ruf.stufe, ruf.start, ruf.wert, ruf.seit, ruf.gemeldet end

-- =================================================================================================
-- HAKEN UND EREIGNISSE
-- =================================================================================================
ns.on("PLAYER_LOGIN", function()
    -- MERGE20: erst der Ping-Ticker, dann levelInit - so entscheidet checkpointTakt() einmal
    -- richtig, statt einen Checkpoint-Ticker anzulegen und gleich wieder zu stoppen.
    pcall(tickerStart)
    pcall(levelInit)
    pcall(rufPruefen)
end)
ns.on("PLAYER_LEVEL_UP", function(level) pcall(levelUp, level) end)
ns.on("PLAYER_LEAVING_WORLD", function() pcall(festschreiben) end)
ns.on("PLAYER_LOGOUT", function() pcall(festschreiben) end)
ns.on("PLAYER_TARGET_CHANGED", function() pcall(zielPruefeVorPull) end)
ns.on("PLAYER_REGEN_ENABLED", function()
    if ping.nachholHoch then pcall(pruefePingHoch) end
end)
ns.on("UPDATE_FACTION", function() pcall(rufPruefen) end)
ns.on("CHAT_MSG_COMBAT_FACTION_CHANGE", function() pcall(rufPruefen) end)

-- Notbremse: der Ticker wird gestoppt/gestartet, sobald das Haekchen "leitung" umgelegt wird.
-- ns.onSetting ist ein gemeinsamer Mantel (Muster: Sinne/Welle6.lua, Sinne/Welle9.lua,
-- Sinne/Welle18.lua, UI/Streamer.lua, UI/Farben.lua) - diese Datei laedt zuletzt in der TOC,
-- Gestalt/Gestalt.lua hat ns.onSetting also laengst gesetzt.
do
    local vorher = ns.onSetting
    ns.onSetting = function(key, value, ...)
        if vorher then vorher(key, value, ...) end
        if key == "leitung" then
            if value == false then tickerStop() else pcall(tickerStart) end
        end
    end
end

-- =================================================================================================
-- /lyra status
-- =================================================================================================
function W.status()
    local d = (ns.sprache() == "de")
    local out = {}

    if not W.F.ping then
        out[#out + 1] = d and "Leitung: fehlt (kein GetNetStats)" or "Connection: missing (no GetNetStats)"
    elseif not W.F.ticker then
        out[#out + 1] = d and "Leitung: fehlt (kein Ticker)" or "Connection: missing (no ticker)"
    else
        out[#out + 1] = (d and "Leitung: %s, Median %s" or "Connection: %s, median %s"):format(
            an("leitung") and (d and "an" or "on") or (d and "aus" or "off"),
            ping.wert and (tostring(math.floor(ping.wert + 0.5)) .. " ms")
                       or (d and "unbekannt" or "unknown"))
    end

    local t, voll = tabelle(), vollTabelle()
    local nStufen, nVoll = 0, 0
    if t then for _ in pairs(t) do nStufen = nStufen + 1 end end
    if voll then for _ in pairs(voll) do nVoll = nVoll + 1 end end
    out[#out + 1] = (d and "  Tempo: %s, %d Stufen gemessen (%d vollstaendig)"
                        or "  Pace: %s, %d levels measured (%d complete)")
                    :format(an("tempo") and (d and "an" or "on") or (d and "aus" or "off"), nStufen, nVoll)

    if not W.F.ruf then
        out[#out + 1] = d and "  Ruf: fehlt (keine Ruf-API)" or "  Reputation: missing (no reputation API)"
    elseif not ruf.name then
        out[#out + 1] = d and "  Ruf: keine beobachtete Fraktion" or "  Reputation: no watched faction"
    else
        local zuwachs = (ruf.wert and ruf.start) and (ruf.wert - ruf.start) or 0
        out[#out + 1] = (d and "  Ruf: %s, +%d seit %.0f min%s"
                            or "  Reputation: %s, +%d over %.0f min%s"):format(
            tostring(ruf.name), zuwachs, (jetzt() - ruf.seit) / 60,
            ruf.gemeldet and (d and " (gemeldet)" or " (reported)") or "")
    end
    return out
end

-- =================================================================================================
-- /lyra weisst und /lyra vergiss — Einbauzeilen fuer Sinne/Welle18.lua stehen im Bericht.
-- =================================================================================================
-- W.vergiss(): loescht das Stufentempo (beide Tabellen) und alle Sitzungsmerker (Ruf). Die
-- laufende Stufenmessung faengt bei der AKTUELLEN Stufe neu an - aber ohne "vollstaendig": nach
-- einem geloeschten Speicher ist der wahre Start dieser Stufe unbekannt, ein Vergleich waere ein
-- Fantasiewert.
function W.vergiss()
    if type(ns.char) == "table" then
        ns.char.stufenTempo = nil
        ns.char.stufenTempoStart = nil
    end
    local lvl = C and C.unitLevelLesbar and C.unitLevelLesbar("player")
    T.level = tonumber(lvl)
    T.seit = jetzt()
    pcall(checkpointTakt)               -- MERGE20: falls T.level bis eben fehlte
    ruf.name, ruf.stufe, ruf.start, ruf.wert, ruf.max, ruf.gemeldet = nil, nil, nil, nil, nil, false
    ruf.seit = jetzt()
    return true
end

-- =================================================================================================
-- Oeffentliche, nur lesende Zugriffe (Auftrag: W.ping(), W.stufenTempo())
-- =================================================================================================
function W.ping() return ping.wert end
function W.stufenTempo() return (type(ns.char) == "table" and ns.char.stufenTempo) or {} end
