-- Sinne/Chronik.lua — Gedaechtnis: Zonen, Beinahe-Tode (+ eigene Gefahren-Stellen), Bestiarium,
--   Sitzungen/Rituale. Alles pro Charakter in LyraGestaltDB.chronik[ns.charKey], versioniert (v = 1),
--   Ringpuffer mit festen Kappen. Schema und Pruefpunkte: Sinne/CHRONIK.md.
-- Ereignisse: ZONE_ERSTMALS, ZONE_BEINAHE, ZONE_ERINNERUNG (eines je Zonenwechsel), BEINAHE_NACHWIRKUNG,
--   BESTIARIUM, BESTIARIUM_RIVALE, WIEDERKEHR (statt LOGIN), TAG_ERSTER, STUFE_MEILENSTEIN, SPIELDAUER,
--   INSTANZ_AN. ZONE/LOGIN/LEVELUP selbst melden Umwelt/Start/Alltag — hier kommt nur der Nachsatz.
-- API (nur lesend): GetRealZoneText/GetZoneText, time, date, GetTime, UnitGUID, UnitName, UnitExists,
--   UnitIsPlayer, UnitPlayerControlled, UnitCanAttack, UnitIsDeadOrGhost, UnitAffectingCombat, UnitLevel,
--   IsInInstance, C_Map.GetBestMapForUnit/GetPlayerMapPosition, CombatLogGetCurrentEventInfo.
-- Events: PLAYER_LOGIN, PLAYER_LOGOUT, PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, PLAYER_REGEN_ENABLED,
--   PLAYER_TARGET_CHANGED, PLAYER_LEVEL_UP, PLAYER_DEAD, PLAYER_ALIVE, COMBAT_LOG_EVENT_UNFILTERED
--   (nur wenn ns.Compat.F.combatLog) + Hook ns.nachAusgabe (HP20/STURZ -> Beinahe-Tod).
-- PORT (0.9.0): Auf Retail 12.x und WoW: Forever ist COMBAT_LOG_EVENT_UNFILTERED fuer Addons
--   NICHT REGISTRIERBAR — der Versuch feuert ADDON_ACTION_FORBIDDEN mit unserem Namen darin.
--   Dort laeuft statt des Combat-Logs die Ersatz-Heuristik weiter unten
--   (UNIT_COMBAT + PLAYER_TARGET_CHANGED + NAME_PLATE_UNIT_ADDED/REMOVED). Was sie kann und
--   was nicht, steht dort im Block und in docs/port-2026-09-18.md.
-- Takt: EIN 60-s-Ticker (Sitzungsende nachfuehren, Spieldauer, Nachwirkung, frische Gefahren-Stellen).
--   Kein OnUpdate. Combat-Log-Handler: nur GUID-Vergleich + Tabellen-Update.
-- Privatsphaere (Grenze B): Quellen im Combat-Log NUR Creature-GUIDs (Player-/Pet-GUIDs fallen durch),
--   Ziel-Pfade mit UnitIsPlayer-Sperre als Erstes. Es landet NIE ein Spielername in der Chronik.
-- Quelle der Logik: claudebuddy bestiarium.sh (Rang: Beinahe, dann Schaden), chronik.sh (datierte
--   Meilensteine, Kappe), rituale.sh (Wiederkehr nur mit belegten Tagen, Nachwirkung 1200 s, level-tier).
local ADDON, ns = ...
ns.Chronik = {}
local Ch = ns.Chronik
ns.Gefahren = ns.Gefahren or {}                 -- Geofence-Tabelle von Umwelt.lua (dort dasselbe Muster)

local VERSION = 1
local MAX_BEINAHE, MAX_BESTIARIUM, MAX_SITZUNGEN = 50, 300, 30
local TAG = 86400
local WIEDERKEHR_TAGE, ERINNERUNG_TAGE = 3, 3
local ZONE_VERZUG, NACHHOL = 8, 35              -- s: erst ZONE (Umwelt), dann unser Nachsatz; Nachhol bei Drop
-- REVIEW4: Login-Zeitplan. Die festen Sekundenzahlen sind nur noch WUENSCHE ("nicht vor ..."); den
-- echten Zeitpunkt vergibt ns.Regie.loginSlot, damit sich die Login-Zeilen aus Chronik, Erbe und
-- Start nicht gegenseitig aus dem Plauder-Abstand draengen. Reihenfolge der Anfragen = TOC-Folge:
-- Gruss (reserviert) -> WIEDERKEHR -> TAG_ERSTER -> ERBE_VORGAENGER -> ERBE_WORTE -> DEBRIEF.
-- WIEDERKEHR ersetzt den LOGIN-Gruss (ns.loginUnterdruecken) und nimmt darum dessen RESERVIERTEN
-- Slot bei +6 s - sie holt sich keinen eigenen, sonst ruecken alle anderen unnoetig nach hinten.
local TAG_ERSTER_AB = 20
local function loginSlot(ab)
    if ns.Regie and ns.Regie.loginSlot then return ns.Regie.loginSlot(ab) end
    return ab
end
local STURZ_BEINAHE_PCT = 35
local BEINAHE_DEDUP = 60                        -- s: HP20 und STURZ desselben Moments = EIN Eintrag
local NACHWIRKUNG_S = 1200                      -- 20 min (rituale.sh NACHWIRK_S)
local SPIELDAUER_AB, SPIELDAUER_TAKT = 10800, 7200
local SITZUNG_FORTSETZEN = 600                  -- s: /reload oder kurzer Relog setzt die Sitzung fort
local GEFAHR_R = 0.015
local TREFFER_FRIST = 30                        -- s: Letzt-Treffer zaehlt beim Tod nur so lange
local MEILENSTEINE = { [10] = true, [20] = true, [30] = true, [40] = true, [50] = true, [60] = true }

local DB = nil                                  -- LyraGestaltDB.chronik[ns.charKey], ab PLAYER_LOGIN
local sitzung = nil                             -- aktueller Eintrag in DB.sitzungen

local function jetzt() return GetTime() end
local function unix() return time() end
local function tot() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false end
local function imKampf() return UnitAffectingCombat and UnitAffectingCombat("player") or false end
local function echterTimer() return C_Timer and C_Timer.After and true or false end

local function zoneJetzt()
    return (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
end

local function ring(t, eintrag, max)
    t[#t + 1] = eintrag
    while #t > max do table.remove(t, 1) end
end

local function rund3(v) return math.floor(v * 1000 + 0.5) / 1000 end

local function position()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local ok, karte = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not karte then return nil end
    local ok2, pos = pcall(C_Map.GetPlayerMapPosition, karte, "player")
    if not ok2 or not pos then return nil end
    local x, y
    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    if not x or not y then return nil end
    return karte, x, y
end

-- NPC-Typ-ID aus einer GUID (Feld 6). Nur Kreaturen; Player-/Pet-/Vehicle-GUIDs -> nil.
local function npcIdAus(guid)
    if type(guid) ~= "string" then return nil end
    return guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
end

-- Feindlicher NPC als Einheit? Grenze B: UnitIsPlayer als Erstes.
local function feindNpc(unit)
    if not (UnitExists and UnitExists(unit)) then return nil end
    if UnitIsPlayer and UnitIsPlayer(unit) then return nil end
    if UnitPlayerControlled and UnitPlayerControlled(unit) then return nil end
    if not (UnitCanAttack and UnitCanAttack("player", unit)) then return nil end
    local id = npcIdAus(UnitGUID and UnitGUID(unit))
    if not id then return nil end
    local name = UnitName and UnitName(unit)
    if not name or name == "" then return nil end
    return id, name
end

-- Melden mit EINEM Nachhol: Regie-Abstand (30 s) frisst sonst jeden Nachsatz, der kurz nach
-- ZONE/LEVELUP/LOGIN kommt. Die Session-Drossel wird erst beim Erfolg verbraucht, daher ist
-- der zweite Versuch unschaedlich. `gilt()` prueft vor jedem Versuch, ob der Anlass noch steht.
-- FIX 0.19.1 (Spieltest Harald 22.09.): bis zu NACHHOL_MAX Anlaeufe statt einem - nach einer
-- Landung stehen TAXI_LANDUNG, ZONE und unser Nachsatz Schlange, und der zweite Anlauf fiel
-- genauso in den Abstand wie der erste. Weiter geht es NUR nach einem Abstand-Drop; Drossel,
-- Gruppe, Still-Modus sind endgueltige Antworten (die Session-Drossel ist dann verbraucht).
local NACHHOL_MAX = 4
local function nurAbstand(id)
    local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
    return d and d[2] == id and d[1] == "abstand"
end
local function meldeNachhol(id, vars, verzug, gilt, versuch)
    versuch = versuch or 1
    ns.Compat.After(verzug, function()
        if gilt and not gilt() then return end
        if ns.melde(id, vars) then return end
        if not echterTimer() then return end
        if versuch >= NACHHOL_MAX or not nurAbstand(id) then return end
        -- REVIEW2: Nachhol nach dem tatsaechlichen Regie-Abstand (Preset "wenig" = 90 s: fester 35-s-Nachhol fiel immer in den Abstand)
        local rest = (ns.Regie and ns.Regie.abstandRest and ns.Regie.abstandRest()) or 0
        meldeNachhol(id, vars, math.max(NACHHOL, math.min(rest + 1, 180)), gilt, versuch + 1)
    end)
end

-- ---------------------------------------------------------------- DB
local function ladeDB()
    if not ns.charKey and ns.initDB then ns.initDB() end
    if not ns.charKey then return end
    LyraGestaltDB.chronik = LyraGestaltDB.chronik or {}
    local c = LyraGestaltDB.chronik[ns.charKey]
    if type(c) ~= "table" then c = {} end
    c.v = c.v or VERSION                        -- hoehere Versionen bleiben unangetastet (nie wischen)
    c.zonen = c.zonen or {}
    c.beinahe = c.beinahe or {}
    c.bestiarium = c.bestiarium or {}
    c.sitzungen = c.sitzungen or {}
    LyraGestaltDB.chronik[ns.charKey] = c
    DB = c
end

-- ---------------------------------------------------------------- Zonen
local letzteZone = nil                          -- nil = Basislinie fehlt
local zoneBereit = false

local function zoneEintrag(z)
    local e = DB.zonen[z]
    if not e then
        e = { erst = unix(), zuletzt = unix(), besuche = 0, beinahe = 0 }
        DB.zonen[z] = e
    end
    return e
end

-- Nachsatz zur Zone: BEINAHE > ERSTMALS > ERINNERUNG, nur einer. Wird VOR dem Fortschreiben
-- des Eintrags entschieden (sonst ist "zuletzt" schon jetzt).
local function zoneNachsatz(z)
    local e = DB.zonen[z]
    local t = unix()
    local id, vars = nil, { zone = z, key = z }
    if e and (e.beinahe or 0) > 0 then
        id = "ZONE_BEINAHE"
    elseif not e then
        id = "ZONE_ERSTMALS"
    elseif e.zuletzt and t - e.zuletzt >= ERINNERUNG_TAGE * TAG then
        id = "ZONE_ERINNERUNG"
        vars.tage = math.floor((t - e.zuletzt) / TAG)
    end
    return id, vars
end

local function zoneBetreten(z, still)
    local id, vars
    if not still then id, vars = zoneNachsatz(z) end
    local e = zoneEintrag(z)
    e.zuletzt = unix()
    e.besuche = (e.besuche or 0) + 1
    if sitzung then sitzung.zone = z end
    if id then
        meldeNachhol(id, vars, ZONE_VERZUG, function() return letzteZone == z and not tot() end)
    end
end

local function pruefeZone()
    if not DB then return end
    local z = zoneJetzt()
    if z == "" then return end
    if not zoneBereit then return end
    if z == letzteZone then return end
    -- FIX 0.19.1 (Spieltest Harald 22.09.): AUF DEM TAXI zaehlt eine Zone nicht als betreten.
    -- Bisher bekam jede ueberflogene Zone einen Besuch in DB.zonen UND einen Nachsatz
    -- (ZONE_ERSTMALS im Abstand-Drop, die W15-Kette "hier warst du schon dreimal" fuellte sich
    -- mit Ueberfluegen). Jetzt: nichts merken, nichts melden, alle 15 s nachsehen, bis der
    -- Flug vorbei ist - dann ist die Zielzone die erste, die zaehlt. Umwelt.lua macht es fuer
    -- ZONE genauso.
    if UnitOnTaxi and UnitOnTaxi("player") then
        if echterTimer() then ns.Compat.After(15, pruefeZone) end
        return
    end
    -- Umwelt.lua wartet den Lade-Riegel der Regie ab, bevor ZONE faellt: wir ebenso, damit
    -- unser Nachsatz nach ZONE kommt.
    local riegel = ns.Regie and ns.Regie.ladeRiegelBis or 0
    if jetzt() < riegel then
        if echterTimer() then ns.Compat.After(riegel - jetzt() + 1, pruefeZone) end
        return
    end
    letzteZone = z
    zoneBetreten(z, false)
end

ns.on("ZONE_CHANGED_NEW_AREA", function()
    ns.Compat.After(1.5, pruefeZone)
end)

-- ---------------------------------------------------------------- Bestiarium (Combat-Log)
local spielerGUID = nil
local kampfNpcs = {}                            -- npcID -> true (haben in DIESEM Kampf getroffen)
local kampfAktiv = false                        -- mind. ein Eintrag seit dem letzten Kampfende
local letzterTreffer = { id = nil, name = nil, t = 0 }
local bestN = nil                               -- Anzahl Eintraege (bei Login gezaehlt)

local function bestZaehlen()
    local n = 0
    for _ in pairs(DB.bestiarium) do n = n + 1 end
    bestN = n
end

-- Aeltesten Eintrag (nach zuletzt-Zeit) entfernen. Nur beim Ueberlauf, nie im Treffer-Pfad.
local function bestKappen()
    while bestN > MAX_BESTIARIUM do
        local altId, altT = nil, nil
        for id, e in pairs(DB.bestiarium) do
            if not altT or (e.t or 0) < altT then altId, altT = id, (e.t or 0) end
        end
        if not altId then return end
        DB.bestiarium[altId] = nil
        bestN = bestN - 1
    end
end

local function bestEintrag(id, name)
    local e = DB.bestiarium[id]
    if not e then
        -- t schon hier setzen: sonst hielte die Kappe den frischen Eintrag (t = 0) fuer den aeltesten.
        e = { name = name, treffer = 0, schaden = 0, maxHit = 0, kaempfe = 0, beinahe = 0, tode = 0, t = unix() }
        DB.bestiarium[id] = e
        bestN = (bestN or 0) + 1
        if bestN > MAX_BESTIARIUM then bestKappen() end
    elseif name and not e.name then
        e.name = name
    end
    return e
end

local function treffer(id, name, betrag)
    local e = bestEintrag(id, name)
    e.treffer = e.treffer + 1
    e.schaden = e.schaden + betrag
    if betrag > e.maxHit then e.maxHit = betrag end
    e.t = unix()
    if not kampfNpcs[id] then
        kampfNpcs[id] = true
        kampfAktiv = true
        e.kaempfe = e.kaempfe + 1
    end
    letzterTreffer.id, letzterTreffer.name, letzterTreffer.t = id, name, jetzt()
end

-- Heisser Pfad: keine API ausser CombatLogGetCurrentEventInfo, kein pcall, keine Allokation.
local function cleu()
    if not DB or not spielerGUID then return end
    local _, sub, _, srcGUID, srcName, _, _, dstGUID, _, _, _, a12, _, _, a15 = CombatLogGetCurrentEventInfo()
    if dstGUID ~= spielerGUID then return end
    local betrag
    if sub == "SWING_DAMAGE" then
        betrag = a12
    elseif sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" or sub == "RANGE_DAMAGE" then
        betrag = a15
    else
        return
    end
    if type(betrag) ~= "number" or betrag <= 0 then return end
    local id = npcIdAus(srcGUID)               -- nur Creature-GUIDs; Spieler/Begleiter fallen durch
    if not id then return end
    treffer(id, srcName, betrag)
end

-- PORT: EINE Weiche, und sie haengt am Feature-Flag, nicht an einer Versionsnummer.
-- W8 (A9): die Weiche fragt jetzt den Selbsttest (Core/Selbsttest.lua, Flaeche "cleu") statt
-- direkt ns.Compat.F.combatLog. Der Selbsttest prueft dasselbe Flag UND haengt einen echten
-- RegisterEvent-Versuch auf einem Wegwerf-Frame dahinter - denn auf einem Client, der den
-- Combat-Log fuer Addons zumacht, ist schon der VERSUCH der Fehler (ADDON_ACTION_FORBIDDEN, ein
-- Blizzard-Fenster mit Lyras Namen darin, das kein pcall faengt). Genau deshalb steht der
-- Selbsttest in der TOC direkt hinter Core/Compat.lua: sein Ergebnis muss stehen, bevor diese
-- Zeile laeuft. Fehlt die Datei (alte Ladereihenfolge), gilt unveraendert das Flag.
local cleuOk = ns.Selbsttest and ns.Selbsttest.ok("cleu") or (not ns.Selbsttest and ns.Compat.F.combatLog)
if cleuOk and CombatLogGetCurrentEventInfo then
    ns.on("COMBAT_LOG_EVENT_UNFILTERED", cleu)
end

-- ---------------------------------------------------------------- Bestiarium ohne Combat-Log
-- PORT (0.9.0): Mainline-Ersatzpfad fuer Retail 12.x und Forever.
--
-- WAS FEHLT, EHRLICH: Der Combat-Log ist die einzige Quelle, die "wer hat mich getroffen"
-- mit einer GUID beantwortet. Ohne ihn gibt es keinen Absender. UNIT_COMBAT("player", "WOUND",
-- flags, betrag, schule) liefert den SCHADEN, aber nicht die Quelle. Die Quelle wird deshalb
-- GERATEN: der feindliche NPC, den der Spieler gerade anvisiert, sonst der letzte, dessen
-- Namensplakette im laufenden Kampf aufgetaucht ist.
--
-- Folgen, die wir in Kauf nehmen:
--   * Bei Adds landet Schaden auf dem falschen Eintrag (immer auf dem angevisierten).
--   * Umgebungsschaden (Sturz, Lava, Ertrinken) hat keinen Verdaechtigen — richtig so.
--   * Periodischer Schaden ohne UNIT_COMBAT (DoT-Ticks) wird nicht gezaehlt.
--   * Ob die UNIT_COMBAT-Argumente auf Mainline im Kampf SECRET sind, ist offen — deshalb
--     laeuft der Betrag durch ns.Compat.zahl(). Ist er secret, bleibt "treffer/schaden/maxHit"
--     auf 0, und das Bestiarium zaehlt nur noch Begegnungen, Beinahe-Tode und Tode.
--     Genau das ist der Punkt, den ein echter Retail-Test klaeren muss.
--
-- WAS WEITER GEHT, und das ist der grosse Teil: Begegnungen, Beinahe-Tode und Tode brauchen
-- keinen Combat-Log. Sie haengen an UnitGUID/UnitName (keine Kampfwerte, also nicht secret)
-- und an der HP-Wacht des Spielers, die Blizzard unter Secret Values ausdruecklich lesbar
-- laesst. BESTIARIUM und BESTIARIUM_RIVALE funktionieren damit auf allen fuenf Clients.
local VERDACHT_FRIST = 20                       -- s: so lange gilt ein Verdaechtiger ohne Sicht
local verdaechtig = { id = nil, name = nil, t = 0 }
local plattenId = {}                            -- unit-token -> npcID (fuer NAME_PLATE_UNIT_REMOVED)

-- Verdaechtigen merken UND die Begegnung zaehlen. Die Begegnungszaehlung teilt sich den
-- kampfNpcs-Riegel mit treffer(), deshalb zaehlt sie nie doppelt.
local function verdachtSetzen(unit)
    if not DB then return nil end
    local id, name = feindNpc(unit)
    if not id then return nil end
    verdaechtig.id, verdaechtig.name, verdaechtig.t = id, name, jetzt()
    -- Auch der Todes-/Beinahe-Pfad braucht einen "Letzt-Treffer" — ohne Combat-Log ist der
    -- Verdaechtige der beste Wert, den es gibt.
    letzterTreffer.id, letzterTreffer.name, letzterTreffer.t = id, name, jetzt()
    if imKampf() and not kampfNpcs[id] then
        kampfNpcs[id] = true
        kampfAktiv = true
        local e = bestEintrag(id, name)
        e.kaempfe = e.kaempfe + 1
        e.t = unix()
    end
    return id
end

local function unitCombat(unit, art, _flags, betrag)
    if unit and unit ~= "player" then return end
    if art ~= "WOUND" then return end
    local b = ns.Compat.zahl(betrag)
    if not b or b <= 0 then return end
    if not DB then return end
    local id, name = feindNpc("target")
    if not id and verdaechtig.id and jetzt() - verdaechtig.t <= VERDACHT_FRIST then
        id, name = verdaechtig.id, verdaechtig.name
    end
    if not id then return end
    treffer(id, name, b)
end

if not ns.Compat.F.combatLog then
    ns.onUnit("UNIT_COMBAT", "player", function(unit, art, flags, betrag)
        local ok, err = pcall(unitCombat, unit, art, flags, betrag)
        if not ok then ns.debug("Chronik UNIT_COMBAT: " .. tostring(err)) end
    end)
    ns.on("PLAYER_TARGET_CHANGED", function() pcall(verdachtSetzen, "target") end)
    ns.on("NAME_PLATE_UNIT_ADDED", function(unit)
        if not unit then return end
        -- Nur im Kampf: auf einer Wiese stehen zwanzig Plaketten, und keine davon schlaegt.
        if not imKampf() then return end
        local ok, id = pcall(verdachtSetzen, unit)
        if ok and id then plattenId[unit] = id end
    end)
    ns.on("NAME_PLATE_UNIT_REMOVED", function(unit)
        if not unit then return end
        local id = plattenId[unit]
        plattenId[unit] = nil
        -- Weg ist weg: einen verschwundenen Gegner soll sie nicht mehr fuer den naechsten
        -- Treffer verantwortlich machen. (Ob es ein Kill oder ein Despawn war, sagt uns
        -- ohne Combat-Log niemand — deshalb wird hier auch KEIN Kill gezaehlt.)
        if id and verdaechtig.id == id then
            verdaechtig.id, verdaechtig.name, verdaechtig.t = nil, nil, 0
        end
    end)
    -- Kampfende und Ladebildschirm wischen den Verdacht. Nameplate-Tokens werden vom Client
    -- wiederverwendet — eine Leiche im Dict ginge sonst als frischer Gegner durch.
    local function verdachtWischen()
        verdaechtig.id, verdaechtig.name, verdaechtig.t = nil, nil, 0
        for k in pairs(plattenId) do plattenId[k] = nil end
    end
    ns.on("PLAYER_REGEN_ENABLED", verdachtWischen)
    ns.on("PLAYER_ENTERING_WORLD", verdachtWischen)
end

-- Kampfende: Set leeren (Treffer VOR PLAYER_REGEN_DISABLED landen so trotzdem im richtigen Kampf).
ns.on("PLAYER_REGEN_ENABLED", function()
    if kampfAktiv then
        for k in pairs(kampfNpcs) do kampfNpcs[k] = nil end
        kampfAktiv = false
    end
end)

ns.on("PLAYER_DEAD", function()
    if not DB then return end
    local lt = letzterTreffer
    if lt.id and jetzt() - lt.t <= TREFFER_FRIST then
        local e = bestEintrag(lt.id, lt.name)
        e.tode = e.tode + 1
        e.t = unix()
    end
    lt.id = nil
end)

-- Anvisieren: alter Bekannter? RIVALE (hat dich getoetet) schlaegt BESTIARIUM (Beinahe).
local function zielPruefe()
    if not DB or tot() then return end
    local id, name = feindNpc("target")
    if not id then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("target") then return end
    local e = DB.bestiarium[id]
    if not e then return end
    if (e.tode or 0) >= 1 then
        ns.melde("BESTIARIUM_RIVALE", { name = name, n = e.tode, key = id })
    elseif (e.beinahe or 0) >= 1 then
        ns.melde("BESTIARIUM", { name = name, n = e.beinahe, key = id })
    end
end
ns.on("PLAYER_TARGET_CHANGED", zielPruefe)

-- ---------------------------------------------------------------- Beinahe-Tode / Gefahren-Stellen
local letzterBeinahe = 0                        -- GetTime
local nachwirkungAb = 0                         -- unix, 0 = keine faellig
local frischeStellen = {}                       -- eigene Stellen, die erst nach dem Weggehen scharf werden

-- Format exakt wie Umwelt.lua gefahrPuls es liest: ns.Gefahren[mapID] = { {x, y, r, art, key}, ... }
local function gefahrEintragen(b)
    if not (b.mapID and b.x and b.y) then return end
    ns.Gefahren = ns.Gefahren or {}
    local liste = ns.Gefahren[b.mapID]
    if type(liste) ~= "table" then liste = {}; ns.Gefahren[b.mapID] = liste end
    local key = "b" .. tostring(b.t)
    for _, s in ipairs(liste) do
        if s.key == key then return end
    end
    liste[#liste + 1] = { x = b.x, y = b.y, r = GEFAHR_R, art = "beinahe", key = key }
end

-- Frische Stelle: sofort eintragen hiesse, dass der Geofence direkt nach dem Kampf an Ort und Stelle
-- warnt ("hier sind schon welche gestuerzt" — ja, du, eben). Erst scharf, wenn wir ausserhalb 2r
-- oder auf einer anderen Karte sind. Prueft der 60-s-Ticker.
local function frischeStellenPruefen()
    if #frischeStellen == 0 then return end
    local karte, px, py = position()
    for i = #frischeStellen, 1, -1 do
        local b = frischeStellen[i]
        local weg = true
        if karte and karte == b.mapID and px and py then
            local dx, dy = px - b.x, py - b.y
            weg = (dx * dx + dy * dy) >= 4 * GEFAHR_R * GEFAHR_R
        end
        if weg then
            gefahrEintragen(b)
            table.remove(frischeStellen, i)
        end
    end
end

local function beinaheTod(hp)
    if not DB or tot() then return end
    local t = jetzt()
    if t - letzterBeinahe < BEINAHE_DEDUP then return end
    letzterBeinahe = t
    local z = zoneJetzt()
    local b = { t = unix(), zone = z, hp = hp }
    local karte, x, y = position()
    if karte and x and y then b.mapID, b.x, b.y = karte, rund3(x), rund3(y) end
    -- Gegner: aktuelles Ziel, wenn NPC; sonst der Letzt-Treffer aus dem Combat-Log. Nie ein Spieler.
    local id, name = feindNpc("target")
    if not id and letzterTreffer.id and t - letzterTreffer.t <= TREFFER_FRIST then
        id, name = letzterTreffer.id, letzterTreffer.name
    end
    if id then b.npcID = id; b.gegner = name end
    ring(DB.beinahe, b, MAX_BEINAHE)
    if z ~= "" then
        local e = zoneEintrag(z)
        e.beinahe = (e.beinahe or 0) + 1
    end
    -- Bestiarium: alle NPCs dieses Kampfs haben dich in die Knie gezwungen.
    local wer = false
    for nid in pairs(kampfNpcs) do
        local e = DB.bestiarium[nid]
        if e then e.beinahe = e.beinahe + 1; e.t = unix(); wer = true end
    end
    if not wer and id and DB.bestiarium[id] then
        local e = DB.bestiarium[id]
        e.beinahe = e.beinahe + 1; e.t = unix()
    end
    if b.mapID then frischeStellen[#frischeStellen + 1] = b end
    nachwirkungAb = unix() + NACHWIRKUNG_S
end

-- Hook hinter jeder Regie-Ausgabe: HP20 gemeldet, oder STURZ mit Stand unter 35 %.
ns.nachAusgabe(function(id, _, vars)
    if vars and vars.test then return end   -- HOTFIX 0.16.1: Proben schreiben keine Chronik
    if id == "HP20" then
        -- HOTFIX 0.16.1: ein "Beinahe" mit mehr als 35 % Leben gibt es nicht (Muell-Riegel,
        -- derselbe Deckel wie beim Sturz) - lieber kein Eintrag als ein falscher Pin.
        local pct = ns.Sinne and ns.Sinne.Leben and ns.Sinne.Leben.pct or 20
        if pct >= STURZ_BEINAHE_PCT then return end
        beinaheTod(pct)
    elseif id == "STURZ" then
        local pct = ns.Sinne and ns.Sinne.Leben and ns.Sinne.Leben.pct
        if pct and pct < STURZ_BEINAHE_PCT then beinaheTod(pct) end
    end
end)

-- Wer wirklich stirbt, hat keine Nachwirkung des Beinahe — der Tod hat seine eigene Ruhe.
ns.on("PLAYER_DEAD", function() nachwirkungAb = 0 end)

local function nachwirkungPruefen()
    if nachwirkungAb == 0 then return end
    if unix() < nachwirkungAb then return end
    if imKampf() or tot() then return end       -- naechster Tick versucht es wieder
    nachwirkungAb = 0
    ns.melde("BEINAHE_NACHWIRKUNG")
end

-- ---------------------------------------------------------------- Sitzungen / Rituale
local ersterPEW = true
local wiederkehrTage = nil                      -- gesetzt bei PLAYER_LOGIN, gemeldet beim ersten PEW
local tagErster = false
local inInstanz = nil                           -- nil = Basislinie fehlt
local ticker = nil

local function sitzungBeginnen()
    local t = unix()
    local liste = DB.sitzungen
    local letzte = liste[#liste]
    local lvl = (UnitLevel and UnitLevel("player")) or 0
    if letzte then
        local ende = letzte.ende or letzte.start or 0
        local pause = t - ende
        if pause < SITZUNG_FORTSETZEN then
            -- /reload oder kurzer Relog: dieselbe Sitzung, keine Rituale.
            sitzung = letzte
            sitzung.ende = t
            if lvl > 0 then sitzung.level = lvl end
            return
        end
        if pause >= WIEDERKEHR_TAGE * TAG then
            wiederkehrTage = math.floor(pause / TAG)
        end
        if date("%Y%m%d", ende) ~= date("%Y%m%d", t) then tagErster = true end
    end
    -- Ganz ohne Vorgeschichte: LOGIN reicht, kein TAG_ERSTER obendrauf.
    sitzung = { start = t, ende = t, level = lvl, zone = "" }
    ring(liste, sitzung, MAX_SITZUNGEN)
end

local function spieldauerPruefen()
    if not sitzung then return end
    local t = unix()
    sitzung.ende = t
    local dauer = t - (sitzung.start or t)
    if dauer < SPIELDAUER_AB then return end
    if sitzung.sd and t - sitzung.sd < SPIELDAUER_TAKT then return end
    if imKampf() or tot() then return end
    if ns.melde("SPIELDAUER") then sitzung.sd = t end
end

local function tick()
    if not DB then return end
    spieldauerPruefen()
    nachwirkungPruefen()
    frischeStellenPruefen()
end

ns.on("PLAYER_LOGIN", function()
    ladeDB()
    if not DB then return end
    spielerGUID = UnitGUID and UnitGUID("player") or nil
    bestZaehlen()
    sitzungBeginnen()
    -- Eigene Beinahe-Stellen wieder in den Geofence spielen (Umwelt.lua liest ns.Gefahren).
    for _, b in ipairs(DB.beinahe) do gefahrEintragen(b) end
    if wiederkehrTage then ns.loginUnterdruecken = true end   -- Start.lua liest das vor LOGIN
end)

ns.on("PLAYER_LOGOUT", function()
    if sitzung then sitzung.ende = unix() end
end)

ns.on("PLAYER_ENTERING_WORLD", function()
    if not DB then return end
    if not spielerGUID then spielerGUID = UnitGUID and UnitGUID("player") or nil end
    -- Instanz-Flanke (Login in einer Instanz: still).
    local drin = false
    if IsInInstance then
        local ok, v = pcall(IsInInstance)
        drin = ok and v and true or false
    end
    if inInstanz == nil then
        inInstanz = drin
    elseif drin ~= inInstanz then
        inInstanz = drin
        if drin then
            meldeNachhol("INSTANZ_AN", nil, 7, function() return inInstanz and not tot() end)
        end
    end
    if ersterPEW then
        ersterPEW = false
        -- Zonen-Basislinie wie Umwelt: Login-Zone still merken (zaehlt als Besuch, kein Nachsatz).
        ns.Compat.After(5, function()
            local z = zoneJetzt()
            if z ~= "" then letzteZone = z; zoneBetreten(z, true) end
            zoneBereit = true
        end)
        if wiederkehrTage then
            local tage = wiederkehrTage
            ns.Compat.After(6, function() ns.melde("WIEDERKEHR", { tage = tage }) end)
        end
        -- REVIEW4 Login-Zeitplan: TAG_ERSTER lag fest bei +46 s und damit nur 4 s neben ERBE_WORTE
        -- (+50, Sinne/Erbe.lua). Beide sind plauder; die zweite Zeile fiel dem Regie-Abstand zum
        -- Opfer, und TAG_ERSTER hatte als einzige keinen Nachhol - die Zeile war schlicht weg,
        -- sobald ein Vorgaenger vorgestellt wurde. Jetzt holt sie sich einen Slot bei der Regie
        -- (ns.Regie.loginSlot), die alle Login-Zeilen einen vollen Abstand auseinanderhaelt.
        if tagErster then
            meldeNachhol("TAG_ERSTER", nil, loginSlot(TAG_ERSTER_AB), function() return not tot() end)
        end
        if not ticker then
            ticker = ns.Compat.NewTicker(60, function()
                local ok, err = pcall(tick)
                if not ok then ns.debug("Chronik tick: " .. tostring(err)) end
            end)
        end
    else
        ns.Compat.After(1.5, pruefeZone)
    end
end)

-- Stufe: Alltag.lua meldet LEVELUP; der Meilenstein kommt 5 s spaeter (Nachhol, falls der Abstand greift).
local letztesLevel = 0
ns.on("PLAYER_LEVEL_UP", function(level)
    local lvl = tonumber(level) or (UnitLevel and UnitLevel("player")) or 0
    if lvl <= letztesLevel then return end
    letztesLevel = lvl
    if sitzung then sitzung.level = lvl end
    if MEILENSTEINE[lvl] then
        meldeNachhol("STUFE_MEILENSTEIN", { level = lvl, key = lvl }, 5, function() return not tot() end)
    end
end)

-- ---------------------------------------------------------------- Export (/lyra chronik)
local TEXT = {
    de = {
        leer = "Chronik: noch leer.",
        zonen = "Zonen besucht: %d (davon mit Beinahe-Tod: %d)",
        beinahe = "Beinahe-Tode: %d",
        letzter = "  zuletzt %s in %s%s",
        best = "Bestiarium: %d Gegnertypen",
        top = "  %s: %dx beinahe, %dx Tod, %d Treffer (max %d)",
        sitz = "Sitzungen: %d, diese seit %s (%s)",
        std = "%dh%02d",
        gegen = " gegen ",
    },
    en = {
        leer = "Chronicle: still empty.",
        zonen = "Zones visited: %d (with near-death: %d)",
        beinahe = "Near-deaths: %d",
        letzter = "  last %s in %s%s",
        best = "Bestiary: %d creature types",
        top = "  %s: %dx near-death, %dx death, %d hits (max %d)",
        sitz = "Sessions: %d, this one since %s (%s)",
        std = "%dh%02d",
        gegen = " vs ",
    },
}

function Ch.status()
    local out = {}
    local T = TEXT[ns.sprache()] or TEXT.en
    if not DB then out[1] = T.leer; return out end
    local nz, nzb = 0, 0
    for _, e in pairs(DB.zonen) do
        nz = nz + 1
        if (e.beinahe or 0) > 0 then nzb = nzb + 1 end
    end
    out[#out + 1] = T.zonen:format(nz, nzb)
    out[#out + 1] = T.beinahe:format(#DB.beinahe)
    local b = DB.beinahe[#DB.beinahe]
    if b then
        out[#out + 1] = T.letzter:format(date("%d.%m.%Y %H:%M", b.t), b.zone or "?",
            b.gegner and (T.gegen .. b.gegner) or "")
    end
    local liste = {}
    for id, e in pairs(DB.bestiarium) do liste[#liste + 1] = e end
    out[#out + 1] = T.best:format(#liste)
    table.sort(liste, function(a, c)
        local ra, rc = (a.beinahe or 0) + (a.tode or 0), (c.beinahe or 0) + (c.tode or 0)
        if ra ~= rc then return ra > rc end
        return (a.schaden or 0) > (c.schaden or 0)
    end)
    for i = 1, math.min(3, #liste) do
        local e = liste[i]
        out[#out + 1] = T.top:format(e.name or "?", e.beinahe or 0, e.tode or 0, e.treffer or 0, e.maxHit or 0)
    end
    if sitzung then
        local dauer = unix() - (sitzung.start or unix())
        out[#out + 1] = T.sitz:format(#DB.sitzungen, date("%d.%m.%Y %H:%M", sitzung.start),
            T.std:format(math.floor(dauer / 3600), math.floor(dauer % 3600 / 60)))
    end
    return out
end

function Ch.stand()
    return DB, sitzung, letzteZone, nachwirkungAb, #frischeStellen
end
