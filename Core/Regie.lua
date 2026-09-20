-- Core/Regie.lua — Do-not-disturb-Kern. JEDE Ausgabe laeuft hier durch.
-- Klassen: warn (sofort, auch im Kampf, eigener Cooldown), plauder (Abstand, Budget,
-- nie im Kampf, nie in Gruppe), still (nur Miene). Riegel: Ladebildschirm 5 s, Tod 60 s.
-- API: GetTime, UnitAffectingCombat, IsInGroup/IsInRaid, UnitIsDeadOrGhost. Nur lesend.
local ADDON, ns = ...
local R = {}
ns.Regie = R
ns.hooksAusgabe = ns.hooksAusgabe or {}   -- fn(id, e, vars, text) nach jeder Ausgabe (Glow, Animation, Chronik)
function ns.nachAusgabe(fn) table.insert(ns.hooksAusgabe, fn) end

local PRESETS = {           -- Gespraechigkeit: Abstand (s), Budget je Stunde, Leerlauf erlaubt
    still  = { abstand = 999999, budget = 0,  leerlauf = false },
    wenig  = { abstand = 90,     budget = 4,  leerlauf = false },
    normal = { abstand = 30,     budget = 15, leerlauf = true },
    viel   = { abstand = 15,     budget = 25, leerlauf = true },
}
local WARTE_MAX, WARTE_TTL = 3, 180

R.zuletztPlauder = 0
R.budgetFenster = { start = 0, n = 0 }
R.cool = {}          -- [id] oder [id..":"..key] -> naechster erlaubter Zeitpunkt
R.session = {}       -- [id..":"..key] -> true (1x je Session)
R.warteliste = {}
R.ladeRiegelBis = 0
R.todRiegelBis = 0
-- REVIEW5: Funkstille NUR fuer plauder. Der Tod-Riegel (todRiegelBis) sperrt jede Klasse ausser
-- "still" - auch warn. Fuer den Tod ist das richtig, fuer eine Andacht nicht: Sinne/Rituale.lua
-- legt nach einem GEDENKEN 5 Minuten Ruhe ein, und mit dem Tod-Riegel haette das auf Hardcore
-- fuenf Minuten lang die HP20-Warnung verschluckt (im Harness reproduziert). Warnungen laufen hier
-- vorbei, Antworten auf eine Frage des Spielers ("direkt") ebenfalls.
R.plauderRuheBis = 0
R.imKampf = false
R.inGruppe = false
R.dropLog = {}       -- Ringpuffer (Grund, id, Zeit) fuer /lyra debug

local function jetzt() return GetTime() end
-- REVIEW5: das rohe Preset ohne Stimmungs-Modulation. Die Login-Slots rechnen damit (siehe
-- loginSchritt), sonst wandert der Slot-Abstand mit der Laune - und der Plan aus Review 4 haelt nicht.
local function basisPreset() return PRESETS[ns.Get("gespraechig") or "normal"] or PRESETS.normal end
local function preset()
    local p = basisPreset()
    -- W1 (Sinne/Leben2.lua): Gespraechigkeits-Modulation. Beruehrt NUR den Abstand, also plauder.
    -- warn laeuft in R.melde VOR dem Abstand - eine besorgte Lyra verschluckt keine Warnung.
    local f = (ns.Stimmung and ns.Stimmung.abstandFaktor and ns.Stimmung.abstandFaktor()) or 1
    if f == 1 then return p end
    return { abstand = p.abstand * f, budget = p.budget, leerlauf = p.leerlauf }
end
-- REVIEW2: Rest-Abstand bis zur naechsten Plauder-Zeile (fuer Nachhol-Timer der Chronik)
function R.abstandRest() return math.max(0, preset().abstand - (jetzt() - R.zuletztPlauder)) end

-- ---------------------------------------------------------------------------------------------
-- REVIEW4: Login-Slots.
-- Nach dem Login wollen bis zu fuenf Plauder-Zeilen aus drei Modulen nacheinander heraus:
-- LOGIN/WIEDERKEHR (Core/Start.lua, Sinne/Chronik.lua), TAG_ERSTER (Chronik), ERBE_VORGAENGER und
-- ERBE_WORTE (Sinne/Erbe.lua), DEBRIEF (Erbe). Jedes Modul hatte dafuer eine feste Sekundenzahl -
-- und die Summe passte nicht zum Plauder-Abstand (30 s bei "normal"): TAG_ERSTER (+46) lag 4 s
-- neben ERBE_WORTE (+50), wurde vom Abstand gefressen und hatte als einziges keinen Nachhol -
-- die Zeile war schlicht weg, sobald ein Vorgaenger vorgestellt wurde.
-- Statt fester Zahlen holt sich jetzt jede Login-Zeile einen SLOT: den fruehesten Zeitpunkt, der
-- sowohl ihren eigenen Wunsch-Verzug erfuellt als auch einen vollen Abstand hinter dem zuletzt
-- vergebenen Slot liegt. Die Reihenfolge ergibt sich aus der Reihenfolge der Anfragen
-- (TOC: Chronik vor Erbe), der Gruss steht per Reservierung immer vorn.
--
-- W8 (pruefstand-wiederaufbau §5 Punkt 6): DER ZEITPLAN HAT SEIT WELLE 3 ZWEI SLOTS MEHR.
-- Es sind nicht mehr fuenf Login-Zeilen, sondern sieben. Dazugekommen sind:
--   * LAUNE_GUT / LAUNE_BESORGT (Sinne/Persoenlichkeit.lua, Welle 3) - der Slot, den die
--     Tabelle in docs/review5-2026-09-17.md gar nicht kennt
--   * FEIERTAG (Sinne/Rituale.lua) - steht dort noch bei +176 und liegt heute eine Stufe tiefer
-- Gemessener schlimmster Fall bei Preset "normal", Schritt exakt 34 s (= min(abstand, LOGIN_MAX)
-- + LOGIN_LUECKE = min(30, 120) + 4):
--
--     +6   Gruss (LOGIN_GRUSS, reserviert)
--     +40  LOGIN / WIEDERKEHR
--     +74  TAG_ERSTER
--     +108 ERBE_VORGAENGER
--     +142 ERBE_WORTE / DEBRIEF
--     +176 LAUNE_GUT / LAUNE_BESORGT      <- Welle 3, in review5 nicht verzeichnet
--     +210 FEIERTAG                        <- in review5 noch +176
--
-- Kein Drop mit Grund "abstand", der Schritt ist ueber alle sieben Slots konstant: die Mechanik
-- stimmt, nur die Doku war eine Zeile zu kurz. docs/review5-2026-09-17.md bleibt als Protokoll
-- seines Tages unveraendert - was HEUTE gilt, steht hier. Wer einen achten Slot bucht, schiebt
-- FEIERTAG auf +244; ab da ist die Frage nicht mehr der Abstand, sondern ob eine Zeile dreieinhalb
-- Minuten nach dem Einloggen ueberhaupt noch zum Login gehoert.
R.LOGIN_LUECKE = 4          -- s Luft zusaetzlich zum Abstand, damit die Zeile nicht auf der Kante liegt
R.LOGIN_GRUSS = 6           -- s: der Slot des Login-Grusses (Core/Start.lua ns.GRUSS_NACH)
R.LOGIN_MAX = 120           -- s: Deckel fuer den Schritt (Preset "still" haette sonst 999999)
R.loginFrei = 0             -- absoluter Zeitpunkt, ab dem der naechste Slot frei ist

local function loginSchritt()
    -- REVIEW5: bewusst basisPreset(), NICHT preset(). Der Stimmungs-Faktor (Sinne/Leben2.lua) steht in
    -- den ersten fuenf Minuten auf 0,7 - der Schritt waere damit 25 s statt 34 s, und zwar GEPLANT mit
    -- 0,7, aber ABGELIEFERT mit dem Faktor, der beim Melden gilt (bis 1,4). Genau dann frisst der
    -- Abstand wieder eine Login-Zeile, was Review 4 abgestellt hat. Der Plan rechnet darum roh.
    return math.min(basisPreset().abstand, R.LOGIN_MAX) + R.LOGIN_LUECKE
end

-- R.loginSlot(fruehestens) -> Verzug in Sekunden ab JETZT. Fuer ns.Compat.After / meldeNachhol.
function R.loginSlot(fruehestens)
    local t = jetzt()
    local ziel = math.max(t + (tonumber(fruehestens) or 0), R.loginFrei)
    R.loginFrei = ziel + loginSchritt()
    return ziel - t
end

local function drop(grund, id)
    table.insert(R.dropLog, 1, { grund, id, date("%H:%M:%S") })
    if #R.dropLog > 30 then table.remove(R.dropLog) end
    ns.debug("Regie drop " .. id .. ": " .. grund)
end

-- Drossel-String aus phrasen.lua auswerten. Rueckgabe true = erlaubt (und merkt sich den Verbrauch).
local function drossel(e, id, key)
    local d = e.drossel or "keine"
    local t = jetzt()
    local k = key and (id .. ":" .. tostring(key)) or id
    if d:find("session$") then
        if R.session[k] then return false end
        R.session[k] = true
        return true
    end
    local sek = tonumber(d:match("(%d+)$"))
    if sek then
        if (R.cool[k] or 0) > t then return false end
        R.cool[k] = t + sek
        return true
    end
    return true   -- flanke/tauchgang/kampf/flug/level/buff/einmal/keine: der Sinn drosselt selbst
end

local function budgetOk()
    local p = preset()
    local t = jetzt()
    if t - R.budgetFenster.start > 3600 then R.budgetFenster.start = t; R.budgetFenster.n = 0 end
    return R.budgetFenster.n < p.budget
end

local function ausgebenKern(e, id, vars, text)
    -- Miene + Pose
    if ns.Gestalt then ns.Gestalt.miene(e.miene, e.halte, e.pose) end
    if e.klasse == "still" then return end
    -- Text
    local sprache = ns.sprache()
    local zeile = text
    if zeile then
        local lauf = ns.fuelle(ns.Anrede(zeile[sprache] or zeile.en), vars)
        -- Stimme: Dateiname + -m/-f wenn Text der aktiven Sprache ein Token traegt
        -- REVIEW: Stimme zuerst; die Blase kommt auch dann, wenn die Stimme NICHT spielt
        -- (Paket fehlt, Datei fehlt, Anrede "keine" bei Token-Zeile, Zeile ohne Audio).
        local gespielt = false
        -- DESIGN-V2 5.2: Stufe 1 (Hinweis) spricht nur, wenn der Spieler ohnehin Gespraech will.
        -- Stufe 2/3 sprechen immer. plauder/still bleiben wie bisher.
        local stufe = tonumber(e.stufe) or ((e.klasse == "warn") and 2 or 0)
        local darfSprechen = true
        if stufe == 1 then
            local g = ns.Get("gespraechig")
            darfSprechen = (g == "normal" or g == "viel")
        end
        if zeile.stimme and darfSprechen and ns.Stimme and ns.Get("stimme") then
            local g = ns.geschlecht()
            local name = zeile.stimme
            if ns.hatToken(zeile[sprache] or "") then
                if g == "keine" then name = nil else name = name .. "-" .. g end
            end
            -- DESIGN-V3 B-14: die Stufe geht mit. Stimme.lua schaltet bei Stufe 3 auf den
            -- Kanal "Master", damit ein stummgeschalteter Dialogkanal den Alarm nicht verschluckt.
            if name then gespielt = ns.Stimme.spiele(name, e.klasse, stufe) and true or false end
        end
        if ns.Blase and (ns.Get("untertitel") or not gespielt) then
            ns.Blase.zeige(lauf, ns.Get("blaseDauer"), e.klasse, stufe)
        end
    end
    -- Cue (nur plauder, Cooldown 120 s, 50 % Zufall)
    if e.cue and e.klasse == "plauder" and ns.Stimme and ns.Get("cues") then
        ns.Stimme.cue(e.cue)
    end
end

local function ausgeben(e, id, vars, text)
    ausgebenKern(e, id, vars, text)
    for _, fn in ipairs(ns.hooksAusgabe) do pcall(fn, id, e, vars, text) end
end

-- Zeile waehlen: bei "keine Anrede" tokenfreie Zeilen bevorzugen; Platzhalter-Zeilen nur mit Vars.
local function waehle(e, vars, sprache)
    local kand = {}
    local g = ns.geschlecht()
    for _, z in ipairs(e.texte or {}) do
        local s = z[sprache] or z.en or ""
        local ok = true
        for k in s:gmatch("{(%a+)}") do
            if not (vars and vars[k] ~= nil) then ok = false end
        end
        -- REVIEW3: vars.nurPlatzhalter = true -> Zeilen OHNE Platzhalter sind keine Kandidaten
        -- (REISECHECK mit fehlt = "Traenke" waehlte sonst zu 1/3 "Alles dabei").
        if ok and vars and vars.nurPlatzhalter and not s:find("{%a+}") then ok = false end
        -- W1 (Sinne/Leben2.lua): Zustands-Filter. Ohne ns.Stimmung fallen getaggte Zeilen einfach
        -- heraus - das ist exakt die heutige Auswahl. Treffer MIT Tag bekommen Gewicht 3, ungetaggte
        -- bleiben mit Gewicht 1 im Topf: kein "Tag gewinnt immer", keine Verhungerung.
        local gewicht = 1
        if ok and z.wenn then
            if ns.Stimmung and ns.Stimmung.passt and ns.Stimmung.passt(z.wenn) then gewicht = 3 else ok = false end
        end
        if ok then
            local eintrag = (g == "keine" and ns.hatToken(s)) and { z = z, reserve = true } or { z = z }
            for _ = 1, gewicht do kand[#kand + 1] = eintrag end
        end
    end
    -- PERSOENLICH: Sinne/Persoenlich.lua legt eine Zeile aus dem Datenpaket Lyra_Gestalt_Persoenlich
    -- in vars ab (Wrapper um ns.melde). Gewicht 3 wie ein erfuellter wenn-Tag: oft genug, um
    -- aufzufallen, selten genug, um besonders zu bleiben. Ohne Paket ist vars.persoenlichText nil
    -- und dieser Block ist ein toter Vergleich. Die Zeile hat keine stimme -> sie liest, sie
    -- spricht nicht (docs/redakteur-konzept.md 7.2).
    local pz = vars and vars.persoenlichText
    if type(pz) == "table" then
        local s = pz[sprache] or pz.en or ""
        local eintrag = (g == "keine" and ns.hatToken(s)) and { z = pz, reserve = true } or { z = pz }
        for _ = 1, 3 do kand[#kand + 1] = eintrag end
    end
    if #kand == 0 then return nil end
    local prim = {}
    for _, k in ipairs(kand) do if not k.reserve then prim[#prim + 1] = k.z end end
    if #prim > 0 then return prim[math.random(#prim)] end
    return kand[math.random(#kand)].z
end

-- Oeffentliche Meldung: ns.melde("HP20") / ns.melde("ZONE", {zone = "Westfall", key = "Westfall"})
function R.melde(id, vars)
    local e = LyraGestalt_Phrasen and LyraGestalt_Phrasen.ereignisse[id]
    if not e then ns.debug("unbekanntes Ereignis " .. tostring(id)); return false end
    local t = jetzt()
    -- REVIEW4 (Regel, bewusst asymmetrisch): "direkt" ist eine ANTWORT auf eine Frage des Spielers.
    -- Sie umgeht den Ladebildschirm-Riegel (wer direkt nach dem Portal "/lyra punkt" tippt, will die
    -- Antwort jetzt), aber NIE den Tod-Riegel: nach dem Tod hat Lyra 60 s zu schweigen, egal wer
    -- fragt. Was nach dem Tod trotzdem kommen muss - die Frage nach den letzten Worten und ihre
    -- Bestaetigung (Sinne/Erbe.lua) - geht darum absichtlich NICHT ueber die Regie, sondern direkt
    -- ueber ns.Blase.zeige + ns.print. ERBE_TOD selbst ist klasse "still" und damit ohnehin frei.
    local direktFrueh = (vars and vars.direkt) or id == "KLICK" or id == "TEST"
    if t < R.ladeRiegelBis and not direktFrueh then drop("ladebildschirm", id); return false end
    if e.klasse ~= "still" and t < R.todRiegelBis then drop("tod-ruhe", id); return false end
    -- REVIEW: Drossel (session/cooldown) erst NACH Gruppe/Abstand/Budget verbrauchen. Vorher wurde
    -- z. B. "zone-session" schon beim Abstand-Drop verbraucht und die Zone nie mehr genannt.
    local key = vars and vars.key
    local sprache = ns.sprache()

    if e.klasse == "warn" or e.klasse == "still" then
        if not drossel(e, id, key) then drop("drossel", id); return false end
        ausgeben(e, id, vars, waehle(e, vars, sprache))
        return true
    end
    -- plauder
    -- Direkt: der Spieler hat aktiv gefragt (Klick, Menue "Sag was", Probe, Test) -> keine Plauder-Drossel,
    -- kein Abstand, kein Budget, kein Still-Modus. Nur Lade-/Tod-Riegel oben gelten.
    local direkt = (vars and vars.direkt) or id == "KLICK" or id == "TEST"
    if direkt then
        local text = waehle(e, vars, sprache)
        R.zuletztPlauder = t
        ausgeben(e, id, vars, text)
        return true
    end
    if t < R.plauderRuheBis then drop("ruhe", id); return false end   -- REVIEW5: nur plauder
    if ns.stillModus then drop("still-modus", id); return false end
    local p = preset()
    if id == "LEERLAUF" and not p.leerlauf then drop("preset-leerlauf", id); return false end
    if R.inGruppe and ns.Get("gruppeSchweigen") and not e.gruppeOk then drop("gruppe", id); return false end   -- gruppeOk: Gruppenereignisse (Boss, Instanz) duerfen
    if R.imKampf and ns.Get("kampfNurWarnungen") then
        if #R.warteliste >= WARTE_MAX then drop("warteliste-voll", id); return false end
        if not drossel(e, id, key) then drop("drossel", id); return false end
        table.insert(R.warteliste, { e = e, id = id, vars = vars, text = waehle(e, vars, sprache), bis = t + WARTE_TTL })
        ns.debug("Regie wartet: " .. id)
        return true
    end
    if t - R.zuletztPlauder < p.abstand then drop("abstand", id); return false end
    if not budgetOk() then drop("budget", id); return false end
    if not drossel(e, id, key) then drop("drossel", id); return false end
    local text = waehle(e, vars, sprache)
    R.zuletztPlauder = t
    R.budgetFenster.n = R.budgetFenster.n + 1
    ausgeben(e, id, vars, text)
    return true
end
-- REVIEW5: ns.melde ist der EINZIGE oeffentliche Weg. Sinne/Rituale.lua legt hier bei PLAYER_LOGIN
-- einen Wrapper drueber, der {erinnerung} nachtraegt (wie Sinne/Erbe.lua bei ns.Dialog.frage).
-- Wer stattdessen ns.Regie.melde aufruft, geht am Wrapper vorbei und verliert den Platzhalter
-- still. Alle Sinne rufen ns.melde - das bitte so lassen.
ns.melde = R.melde

-- Warteliste nach dem Kampf abarbeiten (eine Zeile, Rest verfaellt mit TTL)
local function warteAbarbeiten()
    -- REVIEW: schon wieder im Kampf -> das naechste PLAYER_REGEN_ENABLED plant erneut.
    if R.imKampf then return end
    -- REVIEW2: Still-Modus oder Gruppe waehrend des Kampfs eingeschaltet -> Warteliste verwerfen statt nachholen
    if ns.stillModus then
        for _, w in ipairs(R.warteliste) do drop("still-modus", w.id) end
        R.warteliste = {}
        return
    end
    if R.inGruppe and ns.Get("gruppeSchweigen") then
        -- gruppeOk-Ereignisse (Boss-Kill/-Wipe, Instanz) bleiben, der Rest verfaellt
        local rest = {}
        for _, w in ipairs(R.warteliste) do
            if w.e and w.e.gruppeOk then rest[#rest + 1] = w else drop("gruppe", w.id) end
        end
        R.warteliste = rest
        if #rest == 0 then return end
    end
    local t = jetzt()
    local p = preset()
    while #R.warteliste > 0 do
        local w = R.warteliste[1]
        if w.bis <= t then
            table.remove(R.warteliste, 1); drop("warte-ttl", w.id)
        elseif not budgetOk() then
            table.remove(R.warteliste, 1); drop("budget", w.id)
        else
            -- REVIEW: Abstand zu KAMPF_AUS wahren (sonst zwei Zeilen binnen 2 s, Stimme faellt weg).
            local rest = p.abstand - (t - R.zuletztPlauder)
            if rest > 0 and C_Timer and C_Timer.After then
                ns.Compat.After(rest + 0.1, warteAbarbeiten)
                return
            end
            table.remove(R.warteliste, 1)
            R.zuletztPlauder = t
            R.budgetFenster.n = R.budgetFenster.n + 1
            ausgeben(w.e, w.id, w.vars, w.text)
            return
        end
    end
end

local ersterPEW = true
ns.on("PLAYER_ENTERING_WORLD", function()
    R.ladeRiegelBis = jetzt() + 5
    R.imKampf = UnitAffectingCombat("player") and true or false
    R.inGruppe = (IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid()) or false
    -- REVIEW4: Der Gruss-Slot wird reserviert, BEVOR irgendein Modul seinen Slot holt. Diese Datei
    -- steht in der TOC vor allen Sinnen, der Handler laeuft also als Erster.
    if ersterPEW then
        ersterPEW = false
        R.loginFrei = jetzt() + R.LOGIN_GRUSS + loginSchritt()
    end
end)
ns.on("PLAYER_REGEN_DISABLED", function() R.imKampf = true end)
ns.on("PLAYER_REGEN_ENABLED", function()
    R.imKampf = false
    ns.Compat.After(2, warteAbarbeiten)
end)
ns.on("GROUP_ROSTER_UPDATE", function()
    R.inGruppe = (IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid()) or false
end)
ns.on("PLAYER_DEAD", function()
    R.todRiegelBis = jetzt() + 60
    R.warteliste = {}
end)
