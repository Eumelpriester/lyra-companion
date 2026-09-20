-- Sinne/DBM.lua — DBM- und BigWigs-Kopplung, Stillhalte-Regel, Boss-Chronik (Welle 3).
--
-- DIE REGEL, DIE DIESE DATEI EIGENTLICH IST
-- DBM ist laut. Es hat eigene Countdown-Stimmen (vier Pakete, Standard "Corsica", zaehlt die
-- letzten vier Sekunden jedes Timers vor), Spezialwarnungen mit eigenem Ton und Balken fuer
-- alles. Wer daneben eine zweite Stimme stellt, baut ein Radio mit zwei Sendern auf derselben
-- Frequenz. Also: **wenn DBM spricht, schweigt Lyra.** Umgesetzt ueber EINEN Hebel, den die
-- Regie schon hat - `ns.Regie.plauderRuheBis` (Core/Regie.lua, REVIEW5). Kein Regie-Umbau,
-- keine neue Klasse, kein zweiter Riegel.
--
--   * Der Hebel wird nur ANGEHOBEN, nie gesenkt (`B.ruhe`). Eine laengere Ruhe von woanders
--     (Sinne/Rituale.lua legt nach einem GEDENKEN 5 Minuten ein) bleibt damit unangetastet.
--   * `plauderRuheBis` bremst ausschliesslich `plauder`. Warnungen laufen in `R.melde` VOR dem
--     Riegel - eine HP20-Warnung im Bosskampf wird nicht verschluckt. Auf Hardcore ist das
--     nicht verhandelbar, und es ist der Grund, warum der Hebel genau dieser ist.
--   * Waehrend eines Boss-Encounters wird die Ruhe alle RUHE_TAKT Sekunden nachgelegt statt
--     einmal weit in die Zukunft gesetzt. Damit muss am Ende nichts zurueckgenommen werden -
--     wir hoeren einfach auf nachzulegen, und die Restruhe laeuft in <= RUHE_HALT Sekunden aus.
--
-- WAS LYRA STATTDESSEN BEITRAEGT: ein Gedaechtnis. DBM weiss nicht, dass das der dritte Versuch
-- an diesem Boss ist. Lyra weiss es - je Boss Pulls, Kills, Wipes und die beste Zeit, in
-- LyraGestaltDB.chronik[charKey].bosse. Daraus zwei Zeilen und sonst nichts:
--   BOSS_WIEDER       beim Pull, wenn es nicht der erste Versuch ist ("Der schon wieder. Drittes
--                     Mal. Diesmal bleibt er liegen.") - und nur, wenn noch Platz VOR dem
--                     Countdown ist, sonst schweigt sie.
--   BOSS_ERSTER_KILL  beim allerersten Kill dieses Bosses mit diesem Charakter.
-- BOSS_PULL/KILL/WIPE/ENRAGE_BALD bleiben, wo sie sind (Sinne/Bruecken.lua, Welle 1).
--
-- FREMD-API (Belege: github.com/DeadlyBossMods/DeadlyBossMods, github.com/BigWigsMods/BigWigs,
-- abgerufen 17.09.2026; hier nicht installiert, deshalb JEDER Zugriff geguarded und in pcall):
--   DBM:RegisterCallback(event, fn)             DBM-Core/DBM-Core.lua:2284, Dispatch ueber
--                                               securecall (DBM-Core.lua:2258-2262)
--   DBM_Pull   (mod, delay, synced, startHp)
--   DBM_Kill   (mod) / DBM_Wipe (mod)
--   DBM_TimerBegin (id, msg, timer, icon, simpType, spellId, colorId, modId, keep, fade, name,
--                   guid, timerCount, isPriority, type, hasVariance, maxTimer, isBarEnabled)
--                                               DBM-Core/modules/objects/Timer.lua:550
--   DBM_TimerStop  (id [, guid])                Timer.lua:396/745
--   DBM_Announce   (msg, icon, type, spellId, modId, isSpecialWarning, count)
--                                               Announce.lua:595, SpecialWarning.lua:711
--   DBM_PlaySound  (path)                       DBM-Core.lua:3572/3585 - feuert bei JEDEM Ton,
--                                               den DBM spielt, also auch bei jeder gesprochenen
--                                               Countdown-Zahl (Timer.lua:80-83 playCountSound
--                                               -> DBM:PlaySoundFile). Das ist das verlaesslichste
--                                               "DBM redet JETZT"-Signal, das es gibt.
--   BigWigsLoader.RegisterMessage(tabelle, msg, fn)   BigWigs/Loader.lua:1598 - PUNKT-Notation
--                                               ist Pflicht, ein ":" wirft dort einen Fehler.
--   BigWigs_OnBossEngage (module) / _OnBossWin (module) / _OnBossWipe (module, zeit, info)
--                                               Core/BossPrototype.lua:2126/2151/750
--   BigWigs_StartCountdown (module, key, text, time)   BossPrototype.lua:4573
--   BigWigs_StartBar (module, key, text, time, icon, isCooldownBar, maxTime, nil, eventId)
--                                               BossPrototype.lua:4570
--   BigWigs_Message (module, key, text, color, icon, emphasized, displayTime)   BossPrototype.lua:3953
--
-- Blizzard-API (nur lesend): GetTime, time, date, UnitIsDeadOrGhost, IsInGroup/IsInRaid.
-- Events: PLAYER_LOGIN, PLAYER_ENTERING_WORLD, ENCOUNTER_START, ENCOUNTER_END,
--   PLAYER_REGEN_ENABLED. Kein Dauerticker ausser dem Ruhe-Takt WAEHREND eines Encounters.
-- KEINE SPIELERNAMEN: gelesen werden Bossnamen (NPCs) und Zahlen. BigWigs_OnBossWipe liefert
--   eine unitInfo-Tabelle - die wird nicht angesehen.
--
-- PORT (0.9.0): laeuft auf allen fuenf Clients unveraendert. ENCOUNTER_START/ENCOUNTER_END sind
--   ueberall identisch (Era hat sie seit 1.13), und der tragende Teil dieser Datei — die
--   Stillhalte-Regel — haengt an genau diesen zwei Blizzard-Ereignissen und braucht darum
--   weder DBM noch BigWigs noch den Combat-Log. DBM/BigWigs-Callbacks stehen hinter
--   Existenzpruefung und pcall: gibt es das Addon auf dem Client nicht, passiert nichts.
--   Auf Retail/Forever kommt ein Grund DAZU, still zu sein: Blizzards eigene Combat Audio
--   Alerts (C_CombatAudioAlert, CVar CAAEnabled) sprechen dort selbst. Das ist ein
--   eigener Punkt fuer Welle 4 (docs/port-2026-09-18.md, "Was offen bleibt") und bewusst
--   NICHT in diese Runde gezogen - er verlangt einen Retail-Client zum Abhoeren.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local B = {}
ns.Sinne.DBM = B
ns.BossBruecke = B

-- Stillhalte-Zeiten (Sekunden)
B.TIMER_NAH    = 10            -- Timer, deren Restzeit darunter liegt, machen still
B.TIMER_MAX    = 900           -- laengere Timer werden nicht vorgemerkt (Weltbuff-artige Balken)
B.COUNT_RUHE   = 12            -- nach einer gesprochenen Countdown-Zahl
B.ANSAGE_RUHE  = 4             -- nach einer Ansage / einem beliebigen DBM-Ton
B.RUHE_HALT    = 8             -- Laenge der nachgelegten Ruhe im Encounter
B.RUHE_TAKT    = 4             -- s: so oft wird im Encounter nachgelegt
B.PULL_FENSTER = 2             -- s: Timer, die so kurz nach DBM_Pull kommen, sind DER Pull-Timer
B.WIEDER_PLATZ = 6             -- s: so viel Luft braucht BOSS_WIEDER vor dem Countdown
B.DEDUP        = 20            -- s: dasselbe Boss-Ergebnis aus zwei Quellen zaehlt einmal
B.MAX_BOSSE    = 100           -- Kappe der Boss-Chronik (Ringverhalten: aeltester fliegt)

B.hat = { dbm = false, bigwigs = false, encounter = false }

local bossAktiv = nil          -- Schluessel des laufenden Encounters, nil = keiner
local bossStart = 0            -- GetTime des Pulls/Engage
local ruheTicker = nil
local pullFensterBis = 0
local letzteZahl = 0           -- GetTime der letzten gesprochenen Countdown-Zahl
local timerGemerkt = {}        -- [id] = true, damit ein Timer nur einmal vorgemerkt wird
local dedup = {}               -- [key..":"..art] = GetTime
local gebunden = { dbm = false, bigwigs = false }
local statistik = { ruhe = 0, zahlen = 0, timer = 0, ansagen = 0 }

local function jetzt() return (GetTime and GetTime()) or 0 end
local function unix() return (time and time()) or 0 end

local function melde(id, vars)
    if not ns.melde then return false end
    local ok, v = pcall(ns.melde, id, vars)
    return (ok and v) and true or false
end

-- ---------------------------------------------------------------------------------------------
-- Der Hebel. Nur anheben - siehe Kopf.
-- ---------------------------------------------------------------------------------------------
function B.ruhe(sek, grund)
    sek = tonumber(sek)
    if not sek or sek <= 0 then return false end
    if sek > 60 then sek = 60 end           -- keine Sperre, die man nicht mehr erklaeren kann
    local R = ns.Regie
    if not R then return false end
    local bis = jetzt() + sek
    local alt = tonumber(R.plauderRuheBis) or 0
    if bis <= alt then return false end     -- es ist schon laenger still: nichts tun
    R.plauderRuheBis = bis
    statistik.ruhe = statistik.ruhe + 1
    ns.debug("DBM: Ruhe " .. tostring(math.floor(sek + 0.5)) .. " s (" .. tostring(grund or "?") .. ")")
    return true
end

-- Restliche Ruhe in Sekunden (0 = frei). Wer eine plauder-Zeile PLANT, muss sie abwarten -
-- sonst plant er sie in die eigene Stillhalte-Regel hinein und sie faellt mit Grund "ruhe".
function B.ruheRest()
    local R = ns.Regie
    if not R then return 0 end
    return math.max(0, (tonumber(R.plauderRuheBis) or 0) - jetzt())
end

-- Spricht DBM/BigWigs gerade? Genau die Frage, die eine Zeile vor dem Pull stellen muss.
function B.redetGerade()
    if jetzt() - letzteZahl < 3 then return true end
    return B.ruheRest() > 0
end

local function ruheNachlegen()
    if not bossAktiv then return end
    B.ruhe(B.RUHE_HALT, "encounter")
end

local function ruheTaktStart()
    if ruheTicker then return end
    ruheNachlegen()
    ruheTicker = ns.Compat.NewTicker(B.RUHE_TAKT, function()
        local ok, err = pcall(ruheNachlegen)
        if not ok then ns.debug("DBM Ruhe-Takt: " .. tostring(err)) end
    end)
end

local function ruheTaktStop()
    if not ruheTicker then return end
    if ruheTicker.Cancel then pcall(ruheTicker.Cancel, ruheTicker) end
    ruheTicker = nil
end

-- ---------------------------------------------------------------------------------------------
-- Bossnamen aus Fremd-Objekten. Beide Seiten liefern eine Modul-Tabelle mit schwankendem Aufbau,
-- darum jeder Zugriff in EINEM pcall und nur Strings werden akzeptiert.
-- ---------------------------------------------------------------------------------------------
local function dbmName(mod)
    if type(mod) ~= "table" then return nil end
    local ok, n = pcall(function()
        local l = mod.localization
        return (l and l.general and l.general.name)
            or (mod.combatInfo and mod.combatInfo.name)
            or mod.name or mod.id
    end)
    if ok and type(n) == "string" and n ~= "" then return n end
    if ok and type(n) == "number" then return tostring(n) end
    return nil
end

local function bwName(modul)
    if type(modul) ~= "table" then return nil end
    local ok, n = pcall(function()
        if modul.displayName and type(modul.displayName) == "string" then return modul.displayName end
        if type(modul.GetName) == "function" then return modul:GetName() end
        return modul.moduleName or modul.name
    end)
    if ok and type(n) == "string" and n ~= "" then return n end
    return nil
end

-- Schluessel der Chronik: kleingeschriebener NAME, und nur ohne Namen die Encounter-ID.
-- HARNESS-BEFUND: die ID war zuerst der Vorrang - und damit zaehlte ein Kill doppelt, sobald
-- DBM (nur Name) UND ENCOUNTER_END (Name + ID) denselben Boss melden: "e663" und "lucifron"
-- sind zwei Eintraege, und die Entprellung in frisch() greift je Schluessel. Der Name ist der
-- gemeinsame Nenner aller drei Quellen (DBM, BigWigs, Blizzard) - also traegt er.
-- Nebenwirkung, bewusst in Kauf genommen: zwei gleichnamige Bosse in zwei Instanzen teilen
-- einen Eintrag. Fuer "der schon wieder" ist das sogar das richtige Verhalten.
local function schluessel(name, id)
    if type(name) == "string" and name ~= "" then return (name:lower():gsub("%s+", " ")) end
    if type(id) == "number" and id > 0 then return "e" .. tostring(id) end
    return nil
end

-- ---------------------------------------------------------------------------------------------
-- Boss-Chronik
-- ---------------------------------------------------------------------------------------------
local function chronikAn() return ns.Get("bossChronik") ~= false end

local function bosse(anlegen)
    local c = LyraGestaltDB and ns.charKey and LyraGestaltDB.chronik and LyraGestaltDB.chronik[ns.charKey]
    if type(c) ~= "table" then
        if not (anlegen and LyraGestaltDB and ns.charKey) then return nil end
        LyraGestaltDB.chronik = LyraGestaltDB.chronik or {}
        c = {}
        LyraGestaltDB.chronik[ns.charKey] = c
    end
    if type(c.bosse) ~= "table" then
        if not anlegen then return nil end
        c.bosse = {}
    end
    return c.bosse
end
B.bosse = bosse

-- Aeltesten Eintrag wegwerfen, wenn die Kappe reisst (wie Sinne/Chronik.lua bestKappen).
local function kappen(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    while n > B.MAX_BOSSE do
        local altK, altT = nil, nil
        for k, e in pairs(t) do
            local zt = tonumber(e and e.zuletzt) or 0
            if not altT or zt < altT then altK, altT = k, zt end
        end
        if not altK then return end
        t[altK] = nil
        n = n - 1
    end
end

local function eintrag(key, name)
    local t = bosse(true)
    if not t then return nil end
    local e = t[key]
    if type(e) ~= "table" then
        e = { name = name or key, pulls = 0, kills = 0, wipes = 0, zuletzt = unix() }
        t[key] = e
        kappen(t)
    elseif name and name ~= "" and (e.name == nil or e.name == key) then
        e.name = name
    end
    e.pulls = tonumber(e.pulls) or 0
    e.kills = tonumber(e.kills) or 0
    e.wipes = tonumber(e.wipes) or 0
    return e
end

-- Dasselbe Ergebnis kann von DBM UND von ENCOUNTER_END kommen. Einmal zaehlen.
local function frisch(key, art)
    local k = key .. ":" .. art
    local t = jetzt()
    if (dedup[k] or 0) > t - B.DEDUP then return false end
    dedup[k] = t
    return true
end

-- Pull. `luft` = Sekunden bis zum Kampfbeginn (DBM-Pull-Timer) oder nil.
local function pull(name, id, luft)
    local key = schluessel(name, id)
    if not key then return end
    bossAktiv = key
    bossStart = jetzt()
    -- HARNESS-BEFUND (Reihenfolge ist hier der ganze Witz): ruheTaktStart() MUSS nach dem Melden
    -- kommen. Vorher stand es davor - und damit hat Lyra ihre eigene Zeile mit ihrer eigenen
    -- Stillhalte-Regel erschlagen: BOSS_WIEDER fiel mit Drop-Grund "ruhe", jedes Mal.
    -- Der Pull ist der EINE Moment, in dem sie noch reden darf; danach schweigt sie den
    -- ganzen Encounter. Die Pruefung, ob DBM gerade selbst zaehlt, bleibt (B.redetGerade).
    if chronikAn() and frisch(key, "pull") then
        local e = eintrag(key, name)
        if e then
            local vorher = e.pulls
            e.pulls = vorher + 1
            e.zuletzt = unix()
            -- Erster Versuch: dazu sagt sie nichts. Kein Platz vor dem Countdown (DBM spricht
            -- die letzten vier Sekunden jedes Pull-Timers): auch nichts.
            if vorher >= 1 and not (luft ~= nil and luft < B.WIEDER_PLATZ) and not B.redetGerade() then
                melde("BOSS_WIEDER", { boss = e.name or key, n = e.pulls, key = key })
            end
        end
    end
    ruheTaktStart()
end

local function ergebnis(name, id, gewonnen)
    local key = schluessel(name, id) or bossAktiv
    local dauer = (bossStart > 0) and (jetzt() - bossStart) or nil
    bossAktiv = nil
    bossStart = 0
    ruheTaktStop()
    for k in pairs(timerGemerkt) do timerGemerkt[k] = nil end
    if not key or not chronikAn() then return end
    if not frisch(key, gewonnen and "kill" or "wipe") then return end
    local e = eintrag(key, name)
    if not e then return end
    e.zuletzt = unix()
    if not gewonnen then
        e.wipes = e.wipes + 1
        return
    end
    local vorher = e.kills
    e.kills = vorher + 1
    if dauer and dauer > 5 and dauer < 3600 then
        local best = tonumber(e.bestZeit)
        if not best or dauer < best then e.bestZeit = math.floor(dauer + 0.5) end
    end
    if vorher > 0 then return end                 -- kein erster Kill: BOSS_KILL (Welle 1) reicht
    -- Der erste Kill kommt direkt nach BOSS_KILL aus Welle 1. Abstand abwarten wie die Chronik -
    -- UND die eigene Restruhe. HARNESS-BEFUND: ohne den zweiten Teil plante die Zeile sich in die
    -- gerade noch nachgelegte Encounter-Ruhe hinein und fiel mit Drop-Grund "ruhe". Der erste
    -- Kill eines Bosses passiert einmal im Leben eines Charakters; er darf nicht daran scheitern.
    local verzug = 2
    if ns.Regie and ns.Regie.abstandRest then
        local ok, rest = pcall(ns.Regie.abstandRest)
        if ok and type(rest) == "number" then verzug = rest + 2 end
    end
    verzug = math.max(verzug, B.ruheRest() + 1)
    local nm, vers = e.name or key, e.pulls
    ns.Compat.After(math.max(2, verzug), function()
        if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
        melde("BOSS_ERSTER_KILL", { boss = nm, n = vers, key = key })
    end)
end

B.pull = pull
B.ergebnis = ergebnis

-- ---------------------------------------------------------------------------------------------
-- Stillhalte-Quellen
-- ---------------------------------------------------------------------------------------------
-- Ein Timer. `id` dient nur der Entprellung, `dauer` ist die Restzeit in Sekunden.
local function timer(id, dauer, quelle)
    dauer = tonumber(dauer)
    if not dauer or dauer <= 0 or dauer > B.TIMER_MAX then return end
    statistik.timer = statistik.timer + 1
    if jetzt() < pullFensterBis then return end       -- DAS ist der Pull-Timer: BOSS_WIEDER darf raus
    if dauer <= B.TIMER_NAH then
        B.ruhe(dauer + 2, quelle .. "-timer")
        return
    end
    local k = tostring(id or "?") .. ":" .. tostring(math.floor(dauer))
    if timerGemerkt[k] then return end
    timerGemerkt[k] = true
    ns.Compat.After(dauer - B.TIMER_NAH, function()
        timerGemerkt[k] = nil
        B.ruhe(B.TIMER_NAH + 2, quelle .. "-timer-nah")
    end)
end
B.timer = timer

-- Eine gesprochene Countdown-Zahl? DBM legt die Pakete unter .../DBM-Core/Sounds/<Paket>/<n>.ogg
-- (Timer.lua:118-128). Ein eigener Pfad in den Optionen kann anders aussehen, darum wird
-- grosszuegig geprueft: endet der Pfad auf eine Zahl mit Tonendung, ist es eine Zahl.
local function istZahl(pfad)
    if type(pfad) ~= "string" then return false end
    local p = pfad:lower()
    if p:find("%d+%.ogg$") or p:find("%d+%.mp3$") or p:find("%d+%.wav$") then return true end
    return false
end
B.istZahl = istZahl

local function ton(pfad)
    if istZahl(pfad) then
        letzteZahl = jetzt()
        statistik.zahlen = statistik.zahlen + 1
        B.ruhe(B.COUNT_RUHE, "countdown")
        return
    end
    statistik.ansagen = statistik.ansagen + 1
    B.ruhe(B.ANSAGE_RUHE, "dbm-ton")
end
B.ton = ton

-- ---------------------------------------------------------------------------------------------
-- DBM binden
-- ---------------------------------------------------------------------------------------------
local function dbmBinden()
    if gebunden.dbm then return end
    if not (DBM and type(DBM.RegisterCallback) == "function") then return end
    gebunden.dbm = true
    B.hat.dbm = true
    local function reg(event, fn)
        pcall(DBM.RegisterCallback, DBM, event, function(...)
            local ok, err = pcall(fn, ...)
            if not ok then ns.debug("DBM " .. event .. ": " .. tostring(err)) end
        end)
    end
    -- DBM_Pull(mod, delay, ...) - delay ist der Pull-Timer in Sekunden.
    reg("DBM_Pull", function(_, mod, delay)
        pullFensterBis = jetzt() + B.PULL_FENSTER
        pull(dbmName(mod), nil, tonumber(delay))
    end)
    reg("DBM_Kill", function(_, mod) ergebnis(dbmName(mod), nil, true) end)
    reg("DBM_Wipe", function(_, mod) ergebnis(dbmName(mod), nil, false) end)
    -- DBM_TimerBegin(id, msg, timer, ...). Aeltere Staende feuern DBM_TimerStart - beide binden,
    -- die Entprellung in timer() faengt ein doppeltes Feuern fuer denselben Balken ab.
    local function beginn(_, id, _, dauer) timer(id, dauer, "dbm") end
    reg("DBM_TimerBegin", beginn)
    reg("DBM_TimerStart", beginn)
    reg("DBM_Announce", function() B.ruhe(B.ANSAGE_RUHE, "dbm-ansage") end)
    reg("DBM_PlaySound", function(_, pfad) ton(pfad) end)
    ns.debug("DBM: gebunden")
end

-- ---------------------------------------------------------------------------------------------
-- BigWigs binden. PUNKT-Notation, sonst wirft Loader.lua:1600.
-- ---------------------------------------------------------------------------------------------
local function bwBinden()
    if gebunden.bigwigs then return end
    local L = BigWigsLoader
    if not (type(L) == "table" and type(L.RegisterMessage) == "function") then return end
    -- Eigner-Tabelle als Feld am Modul, nicht lokal: BigWigs legt den Eigner als Schluessel in
    -- callbackMap ab (Loader.lua:1614) - eine lokale Tabelle koennte eingesammelt werden und der
    -- Rueckruf still verschwinden. Dasselbe Muster wie bei !BugGrabber (Sinne/Bruecken.lua).
    B.bwEigner = B.bwEigner or {}
    local eigner = B.bwEigner
    local ok = true
    local function reg(msg, fn)
        local o = pcall(L.RegisterMessage, eigner, msg, function(_, ...)
            local ok2, err = pcall(fn, ...)
            if not ok2 then ns.debug("BigWigs " .. msg .. ": " .. tostring(err)) end
        end)
        if not o then ok = false end
    end
    reg("BigWigs_OnBossEngage", function(modul) pull(bwName(modul), nil, nil) end)
    reg("BigWigs_OnBossWin", function(modul) ergebnis(bwName(modul), nil, true) end)
    reg("BigWigs_OnBossWipe", function(modul) ergebnis(bwName(modul), nil, false) end)
    -- Das gesuchte Signal: BigWigs zaehlt selbst vor.
    reg("BigWigs_StartCountdown", function(_, _, _, zeit)
        letzteZahl = jetzt()
        statistik.zahlen = statistik.zahlen + 1
        B.ruhe(math.min(tonumber(zeit) or B.COUNT_RUHE, 15) + 2, "bw-countdown")
    end)
    reg("BigWigs_StartBar", function(_, key, _, zeit) timer(key, zeit, "bw") end)
    reg("BigWigs_Message", function() B.ruhe(B.ANSAGE_RUHE, "bw-ansage") end)
    if not ok then
        ns.debug("BigWigs: Bindung teilweise fehlgeschlagen")
        return
    end
    gebunden.bigwigs = true
    B.hat.bigwigs = true
    ns.debug("BigWigs: gebunden")
end

-- ---------------------------------------------------------------------------------------------
-- Blizzards eigene Encounter-Ereignisse. Auf Era vorhanden und die einzige Quelle, die auch
-- OHNE DBM und OHNE BigWigs traegt - der wichtigste Fall, denn beide sind hier nicht installiert.
-- ENCOUNTER_START(encounterID, encounterName, difficultyID, groupSize)
-- ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success)
-- ---------------------------------------------------------------------------------------------
ns.on("ENCOUNTER_START", function(id, name)
    B.hat.encounter = true
    pullFensterBis = 0
    pull(type(name) == "string" and name or nil, tonumber(id), nil)
end)

ns.on("ENCOUNTER_END", function(id, name, _, _, erfolg)
    B.hat.encounter = true
    ergebnis(type(name) == "string" and name or nil, tonumber(id), (erfolg == 1 or erfolg == true))
end)

-- Netz gegen haengende Ruhe: kommt kein ENCOUNTER_END (Verbindungsabbruch, Gruppe loest sich auf),
-- beendet das erste Kampfende ohne Encounter den Takt. 20 s Kulanz, damit eine Phase mit kurzem
-- Kampfaussetzer (MC: Ragnaros-Tauchgang) den Encounter nicht abschaltet.
ns.on("PLAYER_REGEN_ENABLED", function()
    if not bossAktiv then return end
    ns.Compat.After(20, function()
        if not bossAktiv then return end
        if ns.Regie and ns.Regie.imKampf then return end
        ns.debug("DBM: Encounter ohne Ende - Ruhe-Takt beendet")
        bossAktiv = nil
        bossStart = 0
        ruheTaktStop()
    end)
end)

ns.on("PLAYER_ENTERING_WORLD", function()
    bossAktiv = nil
    bossStart = 0
    pullFensterBis = 0
    ruheTaktStop()
    for k in pairs(timerGemerkt) do timerGemerkt[k] = nil end
end)

ns.on("PLAYER_LOGIN", function()
    dbmBinden()
    bwBinden()
    -- Beide laden auf Zuruf (LoadOnDemand, Zonenwechsel): dreimal nachfassen wie Welle 1.
    ns.Compat.After(10, function() dbmBinden(); bwBinden() end)
    ns.Compat.After(60, function() dbmBinden(); bwBinden() end)
end)

-- ---------------------------------------------------------------------------------------------
-- /lyra bosse
-- ---------------------------------------------------------------------------------------------
local TEXT = {
    de = {
        kopf   = "Bosse:",
        quellen= "  DBM: %s, BigWigs: %s, Encounter-Ereignisse: %s",
        aus    = "  Boss-Chronik abgeschaltet (/lyra bosse an).",
        leer   = "  Noch kein Boss in der Chronik.",
        zeile  = "  %s: %d Versuche, %d Kills, %d Wipes%s",
        beste  = ", beste Zeit %d:%02d",
        mehr   = "  ... und %d weitere.",
        ruhe   = "  Stillhalten: %d Countdown-Zahlen, %d Timer, %d Ansagen, %d Ruhe-Sperren.",
        laeuft = "  Encounter laeuft (%s) - ich plaudere nicht.",
        regel  = "  Wenn DBM oder BigWigs redet, sage ich nichts. Warnungen laufen weiter.",
    },
    en = {
        kopf   = "Bosses:",
        quellen= "  DBM: %s, BigWigs: %s, encounter events: %s",
        aus    = "  Boss chronicle switched off (/lyra bosse on).",
        leer   = "  No boss in the chronicle yet.",
        zeile  = "  %s: %d attempts, %d kills, %d wipes%s",
        beste  = ", best time %d:%02d",
        mehr   = "  ... and %d more.",
        ruhe   = "  Holding back: %d countdown numbers, %d timers, %d announces, %d quiet spells.",
        laeuft = "  Encounter running (%s) - I'm not chatting.",
        regel  = "  When DBM or BigWigs talks, I say nothing. Warnings still get through.",
    },
}
local function T() return TEXT[ns.sprache()] or TEXT.en end
local function jn(b) local de = ns.sprache() == "de"; return b and (de and "da" or "yes") or (de and "fehlt" or "no") end

function B.status()
    local t = T()
    local out = { t.kopf }
    out[#out + 1] = t.quellen:format(jn(B.hat.dbm), jn(B.hat.bigwigs), jn(B.hat.encounter))
    if not chronikAn() then out[#out + 1] = t.aus end
    if bossAktiv then out[#out + 1] = t.laeuft:format(tostring(bossAktiv)) end
    local liste = {}
    local tb = bosse(false)
    if tb then
        for k, e in pairs(tb) do
            if type(e) == "table" then
                liste[#liste + 1] = { name = e.name or k, pulls = tonumber(e.pulls) or 0,
                    kills = tonumber(e.kills) or 0, wipes = tonumber(e.wipes) or 0,
                    beste = tonumber(e.bestZeit), zuletzt = tonumber(e.zuletzt) or 0 }
            end
        end
    end
    if #liste == 0 then
        out[#out + 1] = t.leer
    else
        table.sort(liste, function(a, c)
            if a.zuletzt ~= c.zuletzt then return a.zuletzt > c.zuletzt end
            return tostring(a.name) < tostring(c.name)
        end)
        for i = 1, math.min(8, #liste) do
            local e = liste[i]
            local best = ""
            if e.beste then best = t.beste:format(math.floor(e.beste / 60), e.beste % 60) end
            out[#out + 1] = t.zeile:format(tostring(e.name), e.pulls, e.kills, e.wipes, best)
        end
        if #liste > 8 then out[#out + 1] = t.mehr:format(#liste - 8) end
    end
    out[#out + 1] = t.ruhe:format(statistik.zahlen, statistik.timer, statistik.ansagen, statistik.ruhe)
    out[#out + 1] = t.regel
    return out
end

function B.stand() return bossAktiv, bossStart, statistik, gebunden, ruheTicker ~= nil end
