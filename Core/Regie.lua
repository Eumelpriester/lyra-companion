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

-- =============================================================================================
-- W11B-1: DIE DRITTE VORFAHRTSKLASSE - "warn" der STUFE 1 bekommt Abstand und Budget.
-- =============================================================================================
-- Befund docs/abgleich-claudebuddy-2026-09-20.md §4.1: ClaudeBuddy hat teuer gelernt, dass ein
-- gemeinsames Budget Warnungen frisst ("Nichts stumm drosseln", Budget 4 -> 10 -> 15/h). Lyra
-- hat die Lehre mit UMGEKEHRTEM Vorzeichen gebaut: hier laeuft JEDE warn-Zeile an Abstand,
-- Budget, Gruppen-Schweigen und Still-Modus vorbei. Fuer die drei Ereignisse der Stufe 3
-- (HP20, STURZ, ATEM10) ist das richtig und bleibt so. Fuer die FUENFZEHN der Stufe 1 ist es
-- der Grund, warum ein Testabend laut wird: GEOFENCE, GEOFENCE_WASSER, GEOFENCE_MOB, TRANK,
-- BESTIARIUM, RUNNER, GEFAHR_STUFEN, MOB_RIVALE_WARNUNG, RUNEN_FEHLER, BOSS_PULL,
-- STURZ_VORAUS, WASSER_VORAUS, TIEFES_WASSER (und die beiden Ausnahmen unten).
--
-- Stufe 1 heisst im Katalog "Hinweis" (docs/design-v2.md 5.2) - nicht "Warnung" und nicht
-- "Alarm". Ein Hinweis darf warten. Also: eigener Mindestabstand (15 s) und ein eigenes
-- Stundenbudget (10), beide GETRENNT von der Plauder-Rechnung - ein Hinweis nimmt dem
-- Geplauder nichts weg und das Geplauder ihm nichts. Stufe 2 und 3 sind unberuehrt.
--
-- DIE AUSNAHME-LISTE, und warum genau diese zwei:
--   NOTFALL_BEREIT / NOTFALL_CD  kommen ausschliesslich drei Sekunden NACH einer HP20/HP35-
--       Warnung und nur, wenn die Lage noch besteht (Sinne/Faehigkeiten.lua, NOTFALL_VERZUG).
--       Sie sind formal Stufe 1, inhaltlich aber die zweite Haelfte eines Alarms: "du bist bei
--       20 % - und dein Schutzstein ist bereit". Genau dieser Satz darf nicht am Abstand zu
--       einem Klippen-Hinweis von vor zehn Sekunden scheitern. Ihre eigene Drossel (20 s) und
--       der Verzug halten sie ohnehin kurz.
--   BOSS_PULL  ist ein COUNTDOWN. Er kommt von DBM/BigWigs, hoechstens einmal je Pull, und er
--       ist in genau den acht Sekunden etwas wert, in denen er kommt - fuenfzehn Sekunden
--       spaeter ist der Kampf laengst gelaufen. Der Pruefstand hat das sofort gezeigt: eine
--       Lua-Fehler-Rune (RUNEN_FEHLER, ebenfalls Stufe 1) eine Sekunde vor dem Pull hat den
--       Pull verschluckt. Eine Fehlermeldung ueber ein fremdes Addon darf keine Boss-Ansage
--       fressen - das ist genau der strukturelle Kollisionsfall aus Abgleich §4.6
--       (Flugmeister-Wink), und er wird an der Quelle geloest und nicht per Abstand.
-- Wer die Liste erweitert, schreibt den Grund dazu. "Ist mir wichtig" ist keiner.
--
-- WO DER ABSTAND LIEGT, und warum das keine Kleinigkeit ist: in R.cool, unter dem reservierten
-- Schluessel "#warn1". R.cool ist die Tabelle "naechster erlaubter Zeitpunkt je Schluessel" -
-- fachlich genau das, was ein Mindestabstand ist. Ein eigenes Feld daneben waere ein zweiter
-- Ort, an dem eine Sperre liegt, und jeder, der die Regie zuruecksetzt (der Prueftstand tut das
-- reihenweise mit R.cool = {}), haette ihn uebersehen. Das "#" kann mit keiner Ereignis-ID
-- kollidieren - die bestehen aus Grossbuchstaben, Ziffern und Unterstrichen.
R.WARN1_ABSTAND = 15        -- s zwischen zwei Stufe-1-Hinweisen
R.WARN1_BUDGET  = 10        -- Hinweise je Stunde
R.WARN1_KEY = "#warn1"
R.STUFE1_FREI = { NOTFALL_BEREIT = true, NOTFALL_CD = true, BOSS_PULL = true }
R.warn1Fenster = { start = 0, n = 0 }

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
R.dropLog = {}       -- Ringpuffer (Grund, id, Zeit) fuer /lyra debug und /lyra warum
R.letzteZeile = {}   -- [id] = zuletzt gezogene Zeilentabelle (W11B-5: selten nie zweimal hintereinander)
R.gehoert = {}       -- Ringpuffer der zuletzt AUSGEGEBENEN Ereignis-IDs (W11B-4: "was will ich abschalten?")

-- =============================================================================================
-- W11B-4a: EREIGNIS-SCHALTER. "/lyra stumm <ID>" / "/lyra laut <ID>".
-- =============================================================================================
-- Befund docs/review-bindung-2026-09-20.md §6.2: der ganze Baum kennt keine Per-Event-Stumm-
-- schaltung. Wer genau EIN Ereignis nervig findet, kann nur den ganzen Sinn abschalten oder auf
-- "wenig" gehen - die klassische "dann mach ich es halt ganz aus"-Falle, die die Recherche des
-- Projekts woertlich belegt.
--
-- POSITIVLISTE: stummschalten laesst sich nur, was im Katalog steht. Ein Tippfehler schaltet
-- damit nichts stumm, sondern sagt es. Und STUFE 3 IST AUSGENOMMEN (HP20, STURZ, ATEM10): ein
-- Addon, mit dem man seinen eigenen Todesalarm abschalten kann, hat auf Hardcore nichts
-- verloren - und der Spieler, der es tut, merkt es genau einmal.
-- Die Liste liegt account-weit in den SavedVariables. Core/Init.lua gehoert in dieser Runde
-- einem anderen Team, deshalb steht der Schluessel hier (dieselbe Bauart wie in
-- Gestalt/Stimme.lua) - das laeuft auf DATEIEBENE, also lange vor ns.initDB().
if type(ns.DEFAULTS_ACCOUNT) == "table" and ns.DEFAULTS_ACCOUNT.stummEreignisse == nil then
    ns.DEFAULTS_ACCOUNT.stummEreignisse = {}
end

local function katalog(id)
    return LyraGestalt_Phrasen and LyraGestalt_Phrasen.ereignisse
       and LyraGestalt_Phrasen.ereignisse[id] or nil
end
local function stufeVon(e)
    return tonumber(e.stufe) or ((e.klasse == "warn") and 2 or 0)
end
R.stufeVon = stufeVon

function R.stummListe()
    local t = ns.Get("stummEreignisse")
    if type(t) ~= "table" then return {} end
    return t
end
function R.istStumm(id) return R.stummListe()[id] and true or false end

-- R.stumm(id, an) -> ok, grund. grund: "unbekannt" (nicht im Katalog) | "alarm" (Stufe 3).
function R.stumm(id, an)
    id = tostring(id or ""):upper()
    local e = katalog(id)
    if not e then return false, "unbekannt" end
    if an and stufeVon(e) >= 3 then return false, "alarm" end
    -- Vor ns.initDB() gibt ns.Get die VORGABE-Tabelle aus ns.DEFAULTS_ACCOUNT zurueck. Wer sie
    -- hier veraenderte, haette die Stummschaltung in jede kuenftige Datenbank geschrieben -
    -- also auch in die des naechsten Charakters. ns.Set verwirft vor initDB ohnehin; diese
    -- Zeile sorgt dafuer, dass es dann auch gar nicht erst zum Schreiben kommt.
    if not ns.db then return false, "zu frueh" end
    local t = ns.Get("stummEreignisse")
    if type(t) ~= "table" then t = {}; ns.Set("stummEreignisse", t) end
    t[id] = an and true or nil
    -- ns.Set noch einmal, damit ns.onSetting laeuft (die Tabelle selbst ist schon geaendert).
    ns.Set("stummEreignisse", t)
    return true
end

-- Zuletzt gehoerte Ereignisse, neueste zuerst. Nur IDs aus dem eigenen Katalog - hier steht
-- kein Text, keine Zahl und kein Name.
R.GEHOERT_MAX = 12
function R.zuletztGehoert(n)
    local out = {}
    for i = 1, math.min(tonumber(n) or R.GEHOERT_MAX, #R.gehoert) do
        out[#out + 1] = { id = R.gehoert[i].id, zeit = R.gehoert[i].zeit, stumm = R.istStumm(R.gehoert[i].id) }
    end
    return out
end

-- =============================================================================================
-- W15 "ZEILEN MIT GEDAECHTNIS" - EIN KLEINER BLOCK FUER "gesagt".
-- =============================================================================================
-- Zwei neue Zeilenfelder (Katalog-Generator: tools/gen-phrasen-lua.py, Zulieferschema:
-- docs/phrasen.json _hinweis): "einmal" (nie wieder gezogen, sobald einmal ausgegeben) und
-- "nach" (nur Kandidat, wenn ihr "k" schon gesagt wurde - eine Kette). Beides braucht dieselbe
-- Frage: "wurde dieses k schon einmal ERFOLGREICH ausgegeben?" - und dieselbe Antwort: eine
-- Tabelle k -> unix-Zeit. Zwei Tabellen, nicht eine: "einmal: true" (Kurzform "char") betrifft
-- DIESEN Charakter (ns.char.gesagt - review-bindung: eine "einmalige" Zeile ueber den Vorgaenger
-- darf der Nachfolger wieder hoeren), "einmal: 'konto'" betrifft die Beziehung zum SPIELER
-- (LyraGestaltDB.account.gesagt). "nach" wird in BEIDEN Tabellen gesucht - eine Kette weiss beim
-- Lesen nicht mehr, in welcher der zwei Tabellen ihr Vorgaenger geschrieben wurde, und ein
-- doppeltes "k" wird schon vom Generator abgelehnt (kein Kollisionsrisiko).
--
-- PROBEN LERNEN NICHTS: dieselbe Zusage wie ueberall sonst (HOTFIX 0.16.1, vars.test). Die
-- Schreib-Stelle steht darum nicht hier, sondern unten in ausgeben() - direkt neben der Stelle,
-- die schon heute ueber vars.test entscheidet, ob R.gehoert/die Chronik etwas lernen.
--
-- DECKEL: 500 Eintraege je Tabelle (Auftrag W15 Punkt 2), aeltester nach Zeitstempel raus - und
-- zwar erst BEIM NEUEN Schluessel, nicht bei jedem erneuten Schreiben eines schon bekannten k
-- (eine Kette, die zwei Stufen weit ist, soll nicht am Deckel ihrer eigenen ersten Stufe scheitern).
R.GESAGT_DECKEL = 500

-- Tabelle fuer den scope ("char"/true -> ns.char.gesagt, "konto" -> LyraGestaltDB.account.gesagt).
-- nil, solange ns.char/ns.db noch nicht stehen (vor ns.initDB()) - dann wird weder gelesen noch
-- geschrieben, genau wie beim Stumm-Schalter oben (R.stumm).
function R.gesagtTabelle(scope)
    if scope == "konto" then
        if not ns.db then return nil end
        ns.db.gesagt = ns.db.gesagt or {}
        return ns.db.gesagt
    end
    if not ns.char then return nil end
    ns.char.gesagt = ns.char.gesagt or {}
    return ns.char.gesagt
end

-- "wurde k schon gesagt" - fuer "nach" IMMER ueber beide Tabellen (siehe Begruendung oben), fuer
-- "einmal" mit dem EIGENEN scope der Zeile, damit eine char-Zeile nicht durch einen zufaelligen
-- Konto-Treffer desselben Namens verschluckt wird (der Generator verbietet die Kollision ohnehin).
function R.gesagtHat(k, scope)
    if not k then return false end
    if scope then
        local t = R.gesagtTabelle(scope)
        return t ~= nil and t[k] ~= nil
    end
    local c, a = R.gesagtTabelle("char"), R.gesagtTabelle("konto")
    return (c and c[k] ~= nil) or (a and a[k] ~= nil) or false
end

-- Schreibt gesagt[z.k] = t, mit Deckel. z.einmal entscheidet den scope (true/"char" -> char,
-- "konto" -> Konto); eine Zeile OHNE "einmal" (ein blosser Kettenschritt) schreibt ebenfalls -
-- ihre Nachfolgerin braucht die Zeitmarke - und zwar in den charakterbezogenen scope, den Default.
function R.gesagtSchreiben(z, t)
    if not (z and z.k) then return end
    local scope = (z.einmal == "konto") and "konto" or "char"
    local tab = R.gesagtTabelle(scope)
    if not tab then return end
    if tab[z.k] == nil then
        local n = 0
        for _ in pairs(tab) do n = n + 1 end
        if n >= R.GESAGT_DECKEL then
            local altK, altT = nil, nil
            for kk, tt in pairs(tab) do
                if not altT or (tt or 0) < altT then altK, altT = kk, tt end
            end
            if altK then tab[altK] = nil end
        end
    end
    tab[z.k] = t
end

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

-- =============================================================================================
-- W11B-4b: DAS PROTOKOLL. "/lyra warum" - warum sagst du nichts?
-- =============================================================================================
-- Befund §4.4 (Abgleich): das Alarmblatt von ClaudeBuddy sagte zur Haelfte Rauschen, weil es
-- NORMALBETRIEB und VERLUST in einen Topf warf. Genau das tut R.dropLog bis heute: "drossel"
-- und "preset-leerlauf" sind eingestellt so gewollt, "abstand", "budget", "warteliste-voll"
-- und "warte-ttl" sind Verluste - da wollte etwas heraus und kam nicht. Wer /lyra debug liest,
-- sieht dreissig Zeilen ohne diese Unterscheidung.
--
-- Der Eintrag traegt ab jetzt BEIDE Formen: die alte Liste [1]=grund [2]=id [3]=Uhrzeit (darauf
-- baut UI/Slash.lua seit 0.5) und benannte Felder samt der Einordnung. Und er traegt NUR
-- Ereignis-IDs - kein Text, keine Zahl, kein Name eines Fremden.
R.NORMALBETRIEB = {
    ["drossel"] = true,           -- so eingestellt (Katalog-Drossel)
    ["preset-leerlauf"] = true,   -- Gespraechigkeit "wenig"/"still": Leerlauf ist aus
    ["session"] = true,
    ["stumm"] = true,             -- der Spieler hat genau das abgeschaltet
    ["ruhe"] = true,              -- Andacht/GTFO-Stillhalte: gewollt
    ["tod-ruhe"] = true,          -- 60 s Schweigen nach dem Tod: gewollt
    ["ladebildschirm"] = true,    -- der 5-s-Riegel
    ["still-preset"] = true,      -- HOTFIX 0.16.1: Gespraechigkeit "still" - Plaudern ist AUS, gewollt
}
R.dropZaehler = { normal = 0, verlust = 0 }

local function drop(grund, id)
    local verlust = not R.NORMALBETRIEB[grund]
    local eintrag = { grund, id, date("%H:%M:%S") }
    eintrag.grund, eintrag.id, eintrag.zeit = grund, id, eintrag[3]
    eintrag.t, eintrag.verlust = jetzt(), verlust
    table.insert(R.dropLog, 1, eintrag)
    if #R.dropLog > 30 then table.remove(R.dropLog) end
    if verlust then R.dropZaehler.verlust = R.dropZaehler.verlust + 1
    else R.dropZaehler.normal = R.dropZaehler.normal + 1 end
    ns.debug("Regie drop " .. id .. ": " .. grund)
end

-- Die letzten n verworfenen Meldungen, neueste zuerst. Fuer /lyra warum.
function R.verworfen(n)
    local out = {}
    for i = 1, math.min(tonumber(n) or 5, #R.dropLog) do
        local d = R.dropLog[i]
        out[#out + 1] = { id = d[2], grund = d[1], zeit = d[3], verlust = d.verlust and true or false }
    end
    return out
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

-- W11B-1: eigenes Stundenfenster fuer Stufe-1-Hinweise. Bewusst NICHT an das Preset gekoppelt:
-- "still"/"wenig" drehen das PLAUDER-Budget herunter, an einem Hinweis soll das nichts aendern.
-- Wer gar keine Hinweise will, schaltet sie einzeln ab (/lyra stumm <ID>) oder nimmt den Sinn aus.
local function warn1BudgetOk()
    local t = jetzt()
    if t - R.warn1Fenster.start > 3600 then R.warn1Fenster.start = t; R.warn1Fenster.n = 0 end
    return R.warn1Fenster.n < R.WARN1_BUDGET
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
    -- W11B-4: Ringpuffer der zuletzt gehoerten Ereignisse. Er steht VOR der Ausgabe, damit auch
    -- eine Zeile gezaehlt wird, deren Ausgabe irgendwo unterwegs haengt. Nur die ID und die Uhr.
    table.insert(R.gehoert, 1, { id = id, zeit = date("%H:%M:%S"), t = jetzt() })
    if #R.gehoert > R.GEHOERT_MAX then table.remove(R.gehoert) end
    ausgebenKern(e, id, vars, text)
    -- W15: die gewaehlte Zeile merken - NIE bei einer Probe (vars.test, HOTFIX-0.16.1-Muster).
    -- "text" ist die Zeilentabelle aus waehle() (oder nil bei klasse "still"); nur eine Zeile mit
    -- einem "k" hat ueberhaupt etwas zu merken.
    if type(text) == "table" and text.k and not (vars and vars.test) then
        R.gesagtSchreiben(text, time())
    end
    for _, fn in ipairs(ns.hooksAusgabe) do pcall(fn, id, e, vars, text) end
end

-- =============================================================================================
-- W11B-5: SELTENE ZEILEN.
-- =============================================================================================
-- docs/review-bindung-2026-09-20.md P-6: das Zeilenschema kennt de, en, v, wenn - keine
-- Seltenheitsstufe. Eine Zeile, die man nach zwanzig Stunden zum ersten Mal hoert, ist der
-- billigste "hast du DAS schon gehoert?"-Moment, den ein Addon haben kann. Team 11a liefert das
-- Feld ueber tools/gen-phrasen-lua.py als z.selten = true.
--
-- DIE GEWICHTE SIND ABSICHTLICH GANZZAHLIG. Die Auswahl arbeitet seit Welle 1 mit einem Topf,
-- in den jeder Kandidat so oft hineinkommt, wie sein Gewicht sagt (ungetaggt 1, erfuellter
-- wenn-Tag 3). Ein Bruchgewicht 0,25 geht darin nicht - also wurde der ganze Topf mit vier
-- multipliziert: 4 statt 1, 12 statt 3, und eine seltene Zeile bekommt 1 (= 0,25) bzw. 3
-- (= 0,25 x 3, wenn sie zusaetzlich einen erfuellten wenn-Tag traegt). Die Verhaeltnisse unter
-- den nicht-seltenen Zeilen bleiben damit EXAKT dieselben wie vorher - ein Katalog ohne
-- selten-Zeilen zieht Zeile fuer Zeile mit derselben Wahrscheinlichkeit wie in 0.14.0.
-- Das ist die Zusage, an der dieser Umbau gemessen wird.
--
-- NIE ZWEIMAL HINTEREINANDER gilt NUR fuer seltene Zeilen, und auch das ist Absicht: eine
-- allgemeine Wiederholungssperre waere eine gute Idee (P-7), sie WUERDE aber das Verhalten von
-- Ereignissen ohne selten-Zeilen aendern - und genau das darf diese Runde nicht. Sie steht als
-- offener Punkt im Bericht. Hat ein Ereignis nur eine einzige seltene Zeile und sonst nichts,
-- greift die Sperre nicht (sonst bliebe Lyra stumm).
local GEW_NORMAL, GEW_TAG, GEW_SELTEN, GEW_SELTEN_TAG = 4, 12, 1, 3

-- Zeile waehlen: bei "keine Anrede" tokenfreie Zeilen bevorzugen; Platzhalter-Zeilen nur mit Vars.
local function waehle(e, vars, sprache, id)
    local kand = {}
    local g = ns.geschlecht()
    local letzte = id and R.letzteZeile[id] or nil
    local seltenUebersprungen = false
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
        local gewicht = GEW_NORMAL
        if ok and z.wenn then
            if ns.Stimmung and ns.Stimmung.passt and ns.Stimmung.passt(z.wenn) then gewicht = GEW_TAG else ok = false end
        end
        -- W11B-5: seltene Zeile -> Viertel-Gewicht, und nicht direkt nach sich selbst.
        if ok and z.selten then
            gewicht = (gewicht == GEW_TAG) and GEW_SELTEN_TAG or GEW_SELTEN
            if z == letzte then ok = false; seltenUebersprungen = true end
        end
        -- W15 "Zeilen mit Gedaechtnis": einmal-Zeilen fallen aus dem Topf, sobald ihr k schon
        -- einmal ERFOLGREICH ausgegeben wurde (R.gesagtHat, scope aus z.einmal); nach-Zeilen sind
        -- nur Kandidat, wenn ihr Vorgaenger (z.nach) schon gesagt wurde. Beides gemeinsam, weil
        -- ein Kettenschritt beides zugleich sein kann ("stufe 2 von 3, aber auch: kommt nur
        -- einmal, dann geht die Kette weiter"). Frisch/Ketten-Zeilen bekommen dasselbe Gewicht
        -- wie ein erfuellter wenn-Tag (12 statt 4) - sie sollen kommen, solange sie NEU sind,
        -- ohne einen wenn-Treffer zu ueberstimmen (der bleibt bei seinem eigenen Gewicht stehen).
        if ok and z.k then
            if z.einmal and R.gesagtHat(z.k, (z.einmal == "konto") and "konto" or "char") then
                ok = false
            end
            if ok and z.nach and not R.gesagtHat(z.nach) then
                ok = false
            end
            if ok and (z.einmal or z.nach) and gewicht == GEW_NORMAL then
                gewicht = GEW_TAG
            end
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
        for _ = 1, GEW_TAG do kand[#kand + 1] = eintrag end
    end
    -- W11B-5: die Wiederholungssperre darf Lyra nie stumm machen. Hat sie gerade die EINZIGE
    -- verbliebene Zeile weggenommen, kommt diese Zeile eben doch - zweimal dieselbe seltene
    -- Zeile ist immer noch besser als Schweigen an einer Stelle, an der etwas zu sagen war.
    if #kand == 0 and seltenUebersprungen and letzte then return letzte end
    if #kand == 0 then return nil end
    local prim = {}
    for _, k in ipairs(kand) do if not k.reserve then prim[#prim + 1] = k.z end end
    local gewaehlt
    if #prim > 0 then gewaehlt = prim[math.random(#prim)]
    else gewaehlt = kand[math.random(#kand)].z end
    if id then R.letzteZeile[id] = gewaehlt end
    return gewaehlt
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
    -- W11B-4: einzeln stummgeschaltet. GANZ VORNE, weil eine abgeschaltete Zeile auch keine
    -- Miene, keine Drossel und keinen Budget-Verbrauch ausloesen soll - sie hat schlicht nicht
    -- stattgefunden. Stufe 3 kann gar nicht in der Liste stehen (R.stumm lehnt sie ab); steht
    -- sie durch eine von Hand editierte SavedVariables doch drin, gewinnt hier der Alarm.
    local eStufe = stufeVon(e)
    if eStufe < 3 and R.istStumm(id) then drop("stumm", id); return false end
    if t < R.ladeRiegelBis and not direktFrueh then drop("ladebildschirm", id); return false end
    if e.klasse ~= "still" and t < R.todRiegelBis then drop("tod-ruhe", id); return false end
    -- REVIEW: Drossel (session/cooldown) erst NACH Gruppe/Abstand/Budget verbrauchen. Vorher wurde
    -- z. B. "zone-session" schon beim Abstand-Drop verbraucht und die Zone nie mehr genannt.
    local key = vars and vars.key
    local sprache = ns.sprache()

    if e.klasse == "warn" or e.klasse == "still" then
        -- W11B-1: die dritte Vorfahrtsklasse. NUR warn/Stufe 1, nur ausserhalb der Ausnahmen.
        -- Sie steht VOR der Drossel - sonst waere die Stelle nach einem Abstands-Drop verbraucht
        -- und schwiege zehn Minuten (dieselbe Lehre wie oben bei "zone-session").
        -- "direkt" heisst: der Spieler hat gefragt (Klick, Menue "Sag was", /lyra test, Probe).
        -- Dieselbe Regel wie im Plauder-Zweig unten und aus demselben Grund: nach 10 Proben in
        -- einer Stunde waere /lyra test sonst stumm ("budget") - genau der Befund, der beim
        -- Pruefstand-Wiederaufbau am 20.09. fuer den Plauder-Pfad behoben wurde. Ein Hinweis,
        -- um den ausdruecklich gebeten wurde, ist kein ungefragter Hinweis.
        local gebremst = (e.klasse == "warn" and eStufe == 1 and not R.STUFE1_FREI[id]
                          and not direktFrueh)
        if gebremst then
            if (R.cool[R.WARN1_KEY] or 0) > t then drop("abstand", id); return false end
            if not warn1BudgetOk() then drop("budget", id); return false end
        end
        if not drossel(e, id, key) then drop("drossel", id); return false end
        if gebremst then
            R.cool[R.WARN1_KEY] = t + R.WARN1_ABSTAND
            R.warn1Fenster.n = R.warn1Fenster.n + 1
        end
        ausgeben(e, id, vars, waehle(e, vars, sprache, id))
        return true
    end
    -- plauder
    -- Direkt: der Spieler hat aktiv gefragt (Klick, Menue "Sag was", Probe, Test) -> keine Plauder-Drossel,
    -- kein Abstand, kein Budget, kein Still-Modus. Nur Lade-/Tod-Riegel oben gelten.
    local direkt = (vars and vars.direkt) or id == "KLICK" or id == "TEST"
    if direkt then
        local text = waehle(e, vars, sprache, id)
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
        table.insert(R.warteliste, { e = e, id = id, vars = vars, text = waehle(e, vars, sprache, id), bis = t + WARTE_TTL })
        ns.debug("Regie wartet: " .. id)
        return true
    end
    -- HOTFIX 0.16.1 (21.09.2026, Spieltest Harald): mit Gespraechigkeit "still" (Abstand 999999)
    -- fiel JEDE Plauder-Zeile als "abstand" durch, und /lyra warum zaehlte Begruessung, Zone und
    -- Rast als VERLUST - dabei ist es genau die Einstellung. Eigener Grund, eigene Einordnung.
    if p.abstand >= 999999 then drop("still-preset", id); return false end
    if t - R.zuletztPlauder < p.abstand then drop("abstand", id); return false end
    if not budgetOk() then drop("budget", id); return false end
    if not drossel(e, id, key) then drop("drossel", id); return false end
    local text = waehle(e, vars, sprache, id)
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
