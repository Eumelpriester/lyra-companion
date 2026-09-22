-- Sinne/Welle16.lua — Welle 16 "Bindung aus Ereignissen" (0.18.0, 22.09.2026).
--
-- ns.Bindung RECHNET, MELDET EIN EREIGNIS (BINDUNG_STUFE) UND STELLT DIE STUFE FUER ALLE ANDEREN
-- BEREIT. Auftrag docs/recherche/21-lernen-entwicklung-2026-09-21.md §3 "Welle 16", eingeschraenkt
-- und praezisiert durch den Wellenauftrag vom 22.09.2026 (Haralds Antworten: Punkte 15/60/140 ja,
-- Stunden bleiben nur der Boden, kein Lernen aus Lautstaerke, Spitzname ab Stufe 2 nur im Text).
--
-- WAS PUNKTE GIBT (nur Ereignisse, nie Zeit):
--   Beinahe-Tod gemeinsam ueberstanden (HP20, danach den Kampf gewonnen)   x3
--   Spieltag (erster Login des Kalendertags)                              x2
--   Meilenstein (LEVELUP-Zehner/STUFE_MEILENSTEIN, REITTIER_ERSTES,
--                GOLD_MEILENSTEIN — ein einziger Meilenstein je Level,
--                s. Abschnitt 3)                                          x5
--   beantwortete Rueckfrage (ns.Bindung.antwort(), Welle 17, heute nie gerufen) x3
-- Proben (vars.test == true) zaehlen NIE — derselbe Wall wie in Sinne/Leben2.lua und
-- Sinne/Profil.lua (HOTFIX 0.16.1).
--
-- SPEICHER: LyraGestaltDB.bindung ist KONTO-WEIT (wie LyraGestaltDB.account.spielzeit) — die
-- Beziehung ist die Hardcore-Alleinstellung des Addons und soll den Charaktertod ausdruecklich
-- ueberleben (docs/recherche/21…§2.2 L2). Core/Init.lua gehoert in dieser Runde einem anderen
-- Team; das Feld wird darum HIER mit "or {}"/"or 0" angelegt (Muster Sinne/Leben2.lua ladeDB()).
-- Daneben traegt ns.char (CHARAKTER-SavedVariables) einen kleinen, rein informativen Anteil —
-- wie viele Punkte DIESES Leben beigetragen hat. Er speist NIE die Stufe; die Stufe ist immer
-- Kontosache.
--
-- STUFE: max(Stufe aus Punkten [15/60/140], Stunden-Boden [alte Treppe 10/50/100, unveraendert
-- aus Sinne/Leben2.lua]) und NIE SINKEND — beide Quellen sind selbst schon monoton (Punkte werden
-- nur addiert, Spielstunden nur gezaehlt); zusaetzlich haelt ein persistiertes Hoechst-Feld
-- dagegen, falls sich eine der beiden Rechnungen je aendert (Muster Sinne/Persoenlichkeit.lua:262,
-- "nie nach unten").
--
-- KONTRAKT: kein SendChatMessage, kein RunMacro, kein CastSpell, kein ChatFrame-Print, keine
-- neue Globale, keine Arbeit ohne Drossel in OnUpdate/UNIT_AURA/BAG_UPDATE (diese Datei hat gar
-- kein OnUpdate). Jeder Spiel-API-Zugriff (UnitAffectingCombat, UnitIsDeadOrGhost) steht in pcall
-- hinter einer Existenzpruefung; faellt eine API aus, zaehlt die betroffene Quelle einfach nicht
-- mit — kein Lua-Fehler, keine halbe Zeile.
--
-- SCHNITTSTELLE (fuer W16v "Gesichter/Ring", W16b "Erbe", W17 "Rueckfragen"):
--   ns.Bindung.stufe()      -> 0..3, nie sinkend
--   ns.Bindung.punkte()     -> Konto-Punkte (Zahl, ganzzahlig gerundet)
--   ns.Bindung.konto()      -> dieselbe Zahl wie punkte(); eigener Name, weil die Schnittstelle
--                              ausdruecklich "Konto-Punkte" (nicht "dieses Lebens Punkte") nennt
--   ns.Bindung.beiStufe(fn) -> fn(neueStufe, alteStufe) IMMER, wenn die Stufe steigt — unabhaengig
--                              davon, ob die gesprochene BINDUNG_STUFE-Zeile gerade durchkam (Regie-
--                              Abstand, Kampf, Stumm). Fuer Visuals (Ring/Gesicht), die im Kampf
--                              nicht auf einen Regie-Slot warten sollen (Harald: "nichts davon darf
--                              im Kampf stoeren").
--   ns.Bindung.antwort()    -> von W17 zu rufen, wenn der Spieler eine Rueckfrage beantwortet hat.
--                              Heute von niemandem gerufen; die Funktion existiert trotzdem, damit
--                              W17 sie einfach findet.
--   ns.Bindung.spitzname()  -> Text-Spitzname ab Stufe 2 (siehe Abschnitt 6) oder nil.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Bindung = W
ns.Welle16 = W
ns.Sinne.Welle16 = W

-- ---------------------------------------------------------------------------------------------
-- Haekchen "Bindung waechst" (Standard an). Core/Init.lua bleibt unberuehrt (Muster Sinne/
-- Welle13a.lua) — der Schluessel haengt sich auf DATEIEBENE an, lange vor ns.initDB().
-- AUS heisst: die VIER Zaehler frieren ein (keine neuen Punkte). Die Stufe selbst kann trotzdem
-- noch ueber den Stunden-Boden steigen — das ist Sinne/Leben2.lua und bleibt unberuehrt von
-- diesem Haekchen; "Punkte frieren ein" ist woertlich gemeint.
-- ---------------------------------------------------------------------------------------------
if type(ns.DEFAULTS_ACCOUNT) == "table" and ns.DEFAULTS_ACCOUNT.bindungWaechst == nil then
    ns.DEFAULTS_ACCOUNT.bindungWaechst = true
end

local function an(key) return ns.Get(key) ~= false end

local function jetzt() return (GetTime and GetTime()) or 0 end
local function tot()
    if type(_G.UnitIsDeadOrGhost) ~= "function" then return false end
    local ok, t = pcall(_G.UnitIsDeadOrGhost, "player")
    return (ok and t) and true or false
end
local function imKampf()
    if type(_G.UnitAffectingCombat) ~= "function" then return false end
    local ok, k = pcall(_G.UnitAffectingCombat, "player")
    return (ok and k) and true or false
end

local function melde(id, vars)
    if not ns.melde then return false end
    local ok, v = pcall(ns.melde, id, vars)
    return (ok and v) and true or false
end

-- Nachhol-Muster wie Sinne/Welle13a.lua meldeNachhol: EIN zweiter Versuch, NUR wenn der Regie-
-- ABSTAND der Grund war (Drossel, Gruppe, Still-Modus, Stummschaltung sind endgueltig).
local W_NACHHOL = 35
local function meldeNachhol(id, vars, gilt)
    if melde(id, vars) then return true end
    local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
    if not (d and d[2] == id and d[1] == "abstand") then return false end
    local rest = 0
    if ns.Regie and ns.Regie.abstandRest then
        local ok, r = pcall(ns.Regie.abstandRest)
        if ok and type(r) == "number" then rest = r end
    end
    local verzug = math.max(W_NACHHOL, math.min(rest + 1, 180))
    ns.Compat.After(verzug, function()
        if gilt and not gilt() then return end
        melde(id, vars)
    end)
    return false
end

-- =============================================================================================
-- 1  SPEICHER — LyraGestaltDB.bindung (konto-weit) + kleiner Anteil in ns.char
-- =============================================================================================
local VERLAUF_MAX = 40

local function speicher()
    if type(_G.LyraGestaltDB) ~= "table" then
        if ns.initDB then pcall(ns.initDB) end
    end
    if type(_G.LyraGestaltDB) ~= "table" then return nil end
    local b = LyraGestaltDB.bindung
    if type(b) ~= "table" then b = {}; LyraGestaltDB.bindung = b end
    -- Muell-Riegel: jede Zahl wird ueber tonumber() UND math.max(0, ...) geschleust. Ein
    -- negativer Zaehler (kaputte SavedVariables, ein Drehbuch, das direkt in die Tabelle
    -- schreibt) darf punkteAus() nicht nach unten ziehen — das waere dieselbe Falle wie ein
    -- negativer Rang in Sinne/Welle13a.lua berufeLesen().
    local function zahl(x) return math.max(0, tonumber(x) or 0) end
    b.v = b.v or 1
    b.beinahe        = zahl(b.beinahe)
    b.tage           = zahl(b.tage)
    b.letzterTag     = type(b.letzterTag) == "string" and b.letzterTag or ""
    b.meilensteine   = zahl(b.meilensteine)
    b.antworten      = zahl(b.antworten)
    -- Stufen-Felder zusaetzlich auf 0..3 gedeckelt: Muell darf hier weder eine kuenftige
    -- Steigerung ewig blockieren (zu hoch) noch eine bereits gesprochene Stufe erneut ausloesen
    -- (zu niedrig waere fuer sich harmlos, der Deckel haelt die Zahl trotzdem im gueltigen Bereich).
    b.stufeAngewandt = math.min(3, zahl(b.stufeAngewandt))   -- letzte an beiStufe() gemeldete Stufe
    b.stufeGesagt    = math.min(3, zahl(b.stufeGesagt))      -- letzte per BINDUNG_STUFE GESPROCHENE Stufe
    b.grundlinie     = b.grundlinie == true
    if type(b.verlauf) ~= "table" then b.verlauf = {} end
    return b
end
W.speicher = speicher   -- fuer den Pruefstand; kein anderer Sinn braucht das direkt

local function verlaufEintrag(quelle, punkte)
    local b = speicher(); if not b then return end
    table.insert(b.verlauf, 1, { t = (type(time) == "function" and time()) or 0, quelle = quelle, punkte = punkte })
    while #b.verlauf > VERLAUF_MAX do table.remove(b.verlauf) end
end

-- Kleiner, rein informativer Anteil je Charakter — NICHT Teil der Stufen-Rechnung.
local function charBeitrag(punkte)
    if type(ns.char) ~= "table" then return end
    ns.char.bindungBeitrag = (tonumber(ns.char.bindungBeitrag) or 0) + punkte
end

-- =============================================================================================
-- 2  PUNKTE UND STUFE
-- =============================================================================================
W.PUNKTE_BEINAHE  = 3
W.PUNKTE_TAG      = 2
W.PUNKTE_MEILENSTEIN = 5
W.PUNKTE_ANTWORT  = 3

-- Deckel je Quelle, damit keine einzelne Quelle die Rechnung allein traegt (dieselbe Vorsicht wie
-- der 20-Stunden-Deckel im Klick/Frage-Bonus aus Sinne/Persoenlichkeit.lua). Meilensteine haben
-- ohnehin nur eine Handvoll moegliche Quellen im Spiel (sechs Zehner-Stufen, ein Reittier, zwei
-- Gold-Stufen) — der Deckel dort ist nur ein Riegel gegen kuenftige, ungeplante Quellen.
W.DECKEL_BEINAHE      = 30
W.DECKEL_TAGE         = 60
W.DECKEL_ANTWORTEN    = 10
W.DECKEL_MEILENSTEINE = 40

W.STUFEN_PUNKTE = { 15, 60, 140 }   -- Stufe 1 / 2 / 3

local function punkteAus(b)
    local beinahe = math.min(b.beinahe, W.DECKEL_BEINAHE)
    local tage    = math.min(b.tage, W.DECKEL_TAGE)
    local meilen  = math.min(b.meilensteine, W.DECKEL_MEILENSTEINE)
    local antw    = math.min(b.antworten, W.DECKEL_ANTWORTEN)
    return beinahe * W.PUNKTE_BEINAHE + tage * W.PUNKTE_TAG
         + meilen * W.PUNKTE_MEILENSTEIN + antw * W.PUNKTE_ANTWORT
end

local function stufeAusPunkten(p)
    if p >= W.STUFEN_PUNKTE[3] then return 3 end
    if p >= W.STUFEN_PUNKTE[2] then return 2 end
    if p >= W.STUFEN_PUNKTE[1] then return 1 end
    return 0
end

function W.punkte()
    local b = speicher(); if not b then return 0 end
    return punkteAus(b)
end
W.konto = W.punkte   -- "Konto-Punkte" — dieselbe Zahl, eigener Name fuer die Schnittstelle

-- Stunden-Boden: DIESELBE Treppe wie die alte Rechnung in Sinne/Leben2.lua (S.vertrautAusStunden),
-- ueber pcall gelesen — Leben2.lua gehoert in dieser Runde uns nur fuer EINE Zeile (S.vertraut()).
local function stundenBoden()
    if not (ns.Stimmung and ns.Stimmung.vertrautAusStunden) then return 0 end
    local ok, h = pcall(ns.Stimmung.vertrautAusStunden)
    return (ok and type(h) == "number") and h or 0
end

-- Rohe Stufe: Punkte-Treppe gegen den Stunden-Boden gehalten — OHNE die persistierten
-- "nie sinkend"-Felder. Das ist die Zahl, gegen die eine STEIGERUNG erkannt wird.
local function stufeRoh()
    local b = speicher()
    local ps = b and stufeAusPunkten(punkteAus(b)) or 0
    return math.max(ps, stundenBoden())
end

function W.stufe()
    local b = speicher()
    local roh = stufeRoh()
    local hoechste = b and math.max(b.stufeAngewandt, b.stufeGesagt) or 0
    if roh > hoechste then return roh end   -- nie sinkend, aber auch nie kuenstlich gedeckelt
    return hoechste
end

-- ---------------------------------------------------------------------------------- beiStufe()
local beiStufeFns = {}
function W.beiStufe(fn)
    if type(fn) ~= "function" then return end
    beiStufeFns[#beiStufeFns + 1] = fn
end
local function beiStufeFeuern(neu, alt)
    for _, fn in ipairs(beiStufeFns) do pcall(fn, neu, alt) end
end

-- =============================================================================================
-- 3  BINDUNG_STUFE melden — genau einmal je Stufe, nie im Kampf, nie tot
-- =============================================================================================
-- Die Zeilen je Stufe sind eigene Textbloecke im Katalog (docs/phrasen-w16.json), unterschieden
-- ueber einen FLUECHTIGEN Tag "bindungStufe" (Muster Sinne/Rituale.lua: "emote", nur fuer die
-- naechste Meldung gueltig). Der eigentliche wenn-Schluessel "bindung" (Abschnitt 5) ist bewusst
-- NICHT dafuer da — er ist MIN-Semantik und wuerde bei einer spaeteren Stufe die Zeilen der
-- frueheren Stufe mit hineinziehen (der Deckel wird ja nie unterschritten). "bindungStufe" ist
-- exaktes Matching und lebt komplett in unserem eigenen ns.Stimmung.passt-Wrapper (Abschnitt 5) —
-- Sinne/Leben2.lua muss den Schluessel dafuer nicht kennen.
local function versucheBindungStufe(stufe)
    local b = speicher(); if not b then return false end
    if b.stufeGesagt >= stufe then return true end   -- schon gesagt (Nachhol-Aufruf o.ae.)
    local function einmalVersuch()
        if ns.Stimmung and ns.Stimmung.fluechtig then ns.Stimmung.fluechtig({ bindungStufe = stufe }) end
        local ok = melde("BINDUNG_STUFE", { stufe = stufe, key = stufe })
        if ns.Stimmung and ns.Stimmung.fluechtig then ns.Stimmung.fluechtig(nil) end
        return ok
    end
    if einmalVersuch() then
        b.stufeGesagt = stufe
        return true
    end
    -- Nachhol, wie meldeNachhol — aber mit demselben fluechtigen Tag um den verzoegerten Versuch.
    local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
    if not (d and d[2] == "BINDUNG_STUFE" and d[1] == "abstand") then return false end
    local rest = 0
    if ns.Regie and ns.Regie.abstandRest then
        local ok, r = pcall(ns.Regie.abstandRest)
        if ok and type(r) == "number" then rest = r end
    end
    local verzug = math.max(W_NACHHOL, math.min(rest + 1, 180))
    ns.Compat.After(verzug, function()
        if tot() or imKampf() then return end
        local b2 = speicher(); if not b2 or b2.stufeGesagt >= stufe then return end
        if einmalVersuch() then b2.stufeGesagt = stufe end
    end)
    return false
end

-- =============================================================================================
-- 4  WIRKUNG — wird nach JEDEM Punkte-Ereignis gerufen
-- =============================================================================================
-- Erst die (immer sofortige) Visual-Flanke beiStufe(), dann — nur ausserhalb von Kampf/Tod und
-- ohne Nachhol-Zwang — der Versuch, BINDUNG_STUFE tatsaechlich zu sprechen.
local function auswirken()
    local b = speicher(); if not b then return end
    local roh = stufeRoh()
    if roh > b.stufeAngewandt then
        local alt = b.stufeAngewandt
        b.stufeAngewandt = roh
        beiStufeFeuern(roh, alt)
    end
    if roh > b.stufeGesagt and roh <= 3 and not tot() and not imKampf() then
        -- Sequenziell, Stufe fuer Stufe (im Alltag ist roh - stufeGesagt fast immer 1).
        for s = b.stufeGesagt + 1, roh do
            if not versucheBindungStufe(s) then break end
        end
    end
end
W.auswirken = auswirken   -- fuer den Pruefstand: nach einer direkten Feldaenderung neu auswerten
W.stufeRoh = stufeRoh     -- fuer den Pruefstand: Stufe OHNE die "nie sinkend"-Persistenz

-- =============================================================================================
-- 5  PUNKTEQUELLEN
-- =============================================================================================

-- ---- 5.1 Beinahe-Tod gemeinsam ueberstanden: HP20 IM KAMPF, danach der Kampf GEWONNEN ---------
-- HP20 ist Stufe 3 (warn) und geht an Abstand/Budget/Stumm vorbei (Core/Regie.lua) — sie kommt
-- praktisch immer durch, wenn die Lage eintritt. Wir hoeren sie trotzdem ueber ns.nachAusgabe ab
-- (Muster Sinne/Chronik.lua "beinaheTod"): nur eine WIRKLICH GESPROCHENE HP20 zaehlt, eine
-- unterdrueckte (Stummschaltung) zaehlt nicht — wer HP20 abschaltet, will davon auch hier nichts.
local BEINAHE_FENSTER = 300   -- s: wie lange eine offene HP20 auf das Kampfende wartet (Muell-Riegel)
local beinaheOffenSeit = 0    -- 0 = kein offener Beinahe-Tod

ns.nachAusgabe(function(id, _, vars)
    if vars and vars.test then return end   -- Proben zaehlen nie
    if id == "HP20" and imKampf() then
        beinaheOffenSeit = jetzt()
    end
end)
ns.on("PLAYER_DEAD", function() beinaheOffenSeit = 0 end)   -- gestorben ist NICHT "ueberstanden"
ns.on("PLAYER_REGEN_ENABLED", function()
    if beinaheOffenSeit == 0 then return end
    local offen = (jetzt() - beinaheOffenSeit) <= BEINAHE_FENSTER
    beinaheOffenSeit = 0
    if not offen then return end
    if tot() then return end
    local b = speicher(); if not b then return end
    if an("bindungWaechst") then
        b.beinahe = b.beinahe + 1
        verlaufEintrag("beinahe", W.PUNKTE_BEINAHE)
        charBeitrag(W.PUNKTE_BEINAHE)
    end
    auswirken()
end)

-- ---- 5.2 Spieltag: erster Login des Kalendertags, konto-weit -----------------------------------
-- PLAYER_LOGIN (nicht PLAYER_ENTERING_WORLD — das feuert je Ladebildschirm mehrfach).
ns.on("PLAYER_LOGIN", function()
    local b = speicher(); if not b then return end
    -- Grundlinie: beim ALLERERSTEN Anlegen von LyraGestaltDB.bindung wird die heutige Stufe still
    -- uebernommen (Flag ERST NACH DIESEM Block gesetzt) — dieselbe Regel wie beim Reittier und
    -- beim Gold in Sinne/Welle13a.lua: "das erste Mal" ist eine Flanke, keine, die man nachtraeglich
    -- erzaehlt. Ein Bestandskonto mit 55 h Spielzeit bleibt damit sofort auf Stufe 2, ohne dass
    -- BINDUNG_STUFE fuer Stufe 1 UND 2 nachtraeglich aufploppt.
    if not b.grundlinie then
        local roh = stufeRoh()
        b.stufeAngewandt = math.max(b.stufeAngewandt, roh)
        b.stufeGesagt = math.max(b.stufeGesagt, roh)
        b.grundlinie = true
    end
    local heute = type(date) == "function" and date("%Y%m%d") or nil
    if heute and heute ~= "" and heute ~= b.letzterTag then
        b.letzterTag = heute
        if an("bindungWaechst") then
            b.tage = b.tage + 1
            verlaufEintrag("tag", W.PUNKTE_TAG)
            charBeitrag(W.PUNKTE_TAG)
        end
    end
    auswirken()
end)

-- ---- 5.3 Meilensteine: LEVELUP-Zehner/STUFE_MEILENSTEIN, REITTIER_ERSTES, GOLD_MEILENSTEIN ----
-- LEVELUP-Zehner (Sinne/Alltag.lua) und STUFE_MEILENSTEIN (Sinne/Chronik.lua, MEILENSTEINE =
-- {10,20,...,60}) sind FUER DENSELBEN LEVEL dieselbe reale Beobachtung — STUFE_MEILENSTEIN kommt
-- 5 s nach genau dem LEVELUP, das durch zehn teilbar ist (Chronik.lua:627-636). Wer beide als
-- eigene Quelle zaehlte, wuerde jeden Zehner-Levelup doppelt vergueten. Ein Dedup-Tisch je Level
-- sorgt dafuer, dass WELCHE der beiden Zeilen auch immer zuerst durchkommt, den Punkt genau
-- einmal vergibt — und faengt zugleich den Fall ab, dass eine der beiden Zeilen (Drossel, Stumm)
-- gar nicht gesprochen wird, die andere aber schon.
local zehnerVergeben = {}   -- [level] = true

local function meilensteinVergeben(quelle)
    local b = speicher(); if not b then return end
    if an("bindungWaechst") then
        b.meilensteine = b.meilensteine + 1
        verlaufEintrag(quelle, W.PUNKTE_MEILENSTEIN)
        charBeitrag(W.PUNKTE_MEILENSTEIN)
    end
    auswirken()
end

ns.nachAusgabe(function(id, _, vars)
    if vars and vars.test then return end
    if id == "REITTIER_ERSTES" or id == "GOLD_MEILENSTEIN" then
        meilensteinVergeben(id:lower())
    elseif id == "STUFE_MEILENSTEIN" then
        local lvl = vars and tonumber(vars.level)
        if lvl and not zehnerVergeben[lvl] then
            zehnerVergeben[lvl] = true
            meilensteinVergeben("levelzehner")
        end
    elseif id == "LEVELUP" then
        local lvl = vars and tonumber(vars.level)
        if lvl and lvl % 10 == 0 and not zehnerVergeben[lvl] then
            zehnerVergeben[lvl] = true
            meilensteinVergeben("levelzehner")
        end
    end
end)

-- ---- 5.4 Beantwortete Rueckfrage (W17-Schnittstelle, heute ungenutzt) --------------------------
-- Rueckgabe: true, wenn der Punkt verbucht wurde (auch bei ausgeschaltetem Haekchen — dann zaehlt
-- der Aufruf einfach nicht, ohne dass W17 selbst pruefen muss). Proben gibt es hier nicht: W17
-- ruft diese Funktion ausschliesslich nach einer ECHTEN Spielerantwort.
function W.antwort()
    local b = speicher(); if not b then return false end
    if an("bindungWaechst") then
        b.antworten = b.antworten + 1
        verlaufEintrag("antwort", W.PUNKTE_ANTWORT)
        charBeitrag(W.PUNKTE_ANTWORT)
    end
    auswirken()
    return true
end

-- =============================================================================================
-- 6  SPITZNAME (nur Text, ab Stufe 2) — Core/Anrede.lua ruft diese Funktion seit 0.18.0.
-- =============================================================================================
-- MERGE18: der Diff aus docs/welle16-2026-09-22.md §3g ist eingebaut (Core/Anrede.lua, Marke
-- "-- W16:"). ns.Anrede() wuerfelt den Spitznamen EINMAL je Aufruf (nicht je Token) und nur,
-- wenn die Anrede nicht auf "keine" steht. Die Stimmdatei bleibt unberuehrt: Core/Regie.lua
-- waehlt sie ueber ns.hatToken() auf dem ROHEN Text, vor jeder Aufloesung.
--
-- "darf" ein Spitzname sein, nicht "muss": in JEDEM Aufruf wird gewuerfelt, mit steigender Chance
-- je Stufe — Held/Heldin bleibt die haeufigere Form, der Spitzname bleibt ein Moment und nutzt
-- sich nicht ab (companion-v3-Sorge "kein Ratschlag mit Zeitangabe", hier: kein Wort, das durch
-- Wiederholung banal wird). Stufe 3 zieht den Vorrat der Stufe 2 mit, weil "mein Lieber"/"du" auch
-- auf der hoechsten Stufe noch passt; Stufe 3 bekommt zusaetzlich den waermeren Satz.
W.SPITZNAME_CHANCE = { [2] = 0.30, [3] = 0.45 }
W.SPITZNAMEN = {
    de = {
        m = { [2] = { "du", "mein Lieber" }, [3] = { "du", "mein Lieber", "mein Freund" } },
        f = { [2] = { "du", "meine Liebe" }, [3] = { "du", "meine Liebe", "meine Freundin" } },
    },
    en = {
        m = { [2] = { "you", "my friend" },  [3] = { "you", "my friend", "old friend" } },
        f = { [2] = { "you", "my friend" },  [3] = { "you", "my friend", "old friend" } },
    },
}

function W.spitzname()
    local ok, stufe = pcall(W.stufe)
    if not ok or type(stufe) ~= "number" or stufe < 2 then return nil end
    local chance = W.SPITZNAME_CHANCE[stufe] or W.SPITZNAME_CHANCE[2]
    if math.random() > chance then return nil end
    local g = (ns.geschlecht and ns.geschlecht()) or "m"
    if g ~= "m" and g ~= "f" then return nil end   -- "keine": kein Spitzname, keine Anrede ueberhaupt
    local sprache = (ns.sprache and ns.sprache()) or "de"
    local pool = W.SPITZNAMEN[sprache] or W.SPITZNAMEN.de
    local liste = (pool[g] or pool.m)[stufe] or (pool[g] or pool.m)[2]
    if not liste or #liste == 0 then return nil end
    return liste[math.random(#liste)]
end

-- =============================================================================================
-- 7  wenn-Filter: Tag "bindung" (numerisch, MIN) + interner Tag "bindungStufe" (exakt)
-- =============================================================================================
-- Wrapper um BEIDE ns.Stimmung.tags UND ns.Stimmung.passt (Muster Sinne/Profil.lua "stil" — dort
-- reicht ein Wrapper um tags(), weil Sinne/Leben2.lua "stil" schon in BEKANNT fuehrt. "bindung"
-- und "bindungStufe" stehen dort NICHT, und Leben2.lua darf ausser S.vertraut() nicht angefasst
-- werden — darum wickelt dieser Wrapper zusaetzlich passt() selbst ein und beantwortet beide
-- Schluessel, BEVOR er den Rest an die urspruengliche Pruefung weiterreicht.
--
-- BEWUSST AUF DATEIEBENE (nicht erst bei PLAYER_LOGIN wie Sinne/Profil.lua/Sinne/Welle15.lua):
-- Abschnitt 5.2 meldet BINDUNG_STUFE unter Umstaenden SELBST innerhalb des eigenen PLAYER_LOGIN-
-- Handlers (Spieltag laesst die Stufe steigen). Waere der Wrapper noch nicht aktiv, saehe
-- Sinne/Leben2.lua den Schluessel "bindungStufe" nicht, jede Zeile fiele durch den Filter, und
-- die Meldung ginge textlos (nur Miene) heraus. Sinne/Leben2.lua legt ns.Stimmung.tags/.passt auf
-- Dateiebene an, lange vor PLAYER_LOGIN (Zeile 28f.), und laedt laut TOC vor dieser Datei — der
-- Wrapper kann also sofort greifen, mit derselben Existenzpruefung wie sonst ueberall.
-- Die Reihenfolge mit Sinne/Welle15.lua (WENN es gemergt ist) ist trotzdem beliebig: beide
-- Wrapper trennen "wenn" in "meine Schluessel" und "Rest" und reichen den Rest weiter - das
-- komponiert in jeder Ladereihenfolge.
local gewrappt = false
local function tagsUndPasstWrappen()
    if gewrappt then return end
    if not (ns.Stimmung and type(ns.Stimmung.tags) == "function" and type(ns.Stimmung.passt) == "function") then
        return
    end
    gewrappt = true
    local origTags = ns.Stimmung.tags
    local origPasst = ns.Stimmung.passt
    ns.Stimmung.tags = function(...)
        local t = origTags(...)
        if type(t) == "table" then
            local ok, p = pcall(W.punkte)
            t.bindung = (ok and type(p) == "number") and p or nil
        end
        return t
    end
    ns.Stimmung.passt = function(wenn)
        if type(wenn) ~= "table" then return origPasst(wenn) end
        if wenn.bindung == nil and wenn.bindungStufe == nil then return origPasst(wenn) end
        local rest, hatRest = {}, false
        for k, v in pairs(wenn) do
            if k ~= "bindung" and k ~= "bindungStufe" then rest[k] = v; hatRest = true end
        end
        if hatRest and not origPasst(rest) then return false end
        local ok, tags = pcall(ns.Stimmung.tags)
        if not ok or type(tags) ~= "table" then return false end
        if wenn.bindungStufe ~= nil and tags.bindungStufe ~= wenn.bindungStufe then return false end
        if wenn.bindung ~= nil then
            local p = tags.bindung
            if type(p) ~= "number" or type(wenn.bindung) ~= "number" or p < wenn.bindung then return false end
        end
        return true
    end
end
tagsUndPasstWrappen()   -- sofort, Begruendung oben
W.tagsUndPasstWrappen = tagsUndPasstWrappen   -- fuer den Pruefstand: erneut aufrufbar (idempotent)

-- =============================================================================================
-- /lyra status (eine Zeile) und /lyra bindung (Details) — Textbausteine, Merge im Bericht.
-- =============================================================================================
local TEXT = {
    de = {
        statusZeile = "Bindung: Stufe %d, %d Punkte",
        kopf   = "Bindung:",
        stufe  = "  Stufe %d von 3 (%d Punkte; naechste Stufe ab %s)",
        boden  = "  Stunden-Boden: Stufe %d (haelt die Bindung nie unter dem, was die Spielzeit ohnehin traegt)",
        quellen = "  Beinahe-Tode: %d (x3), Spieltage: %d (x2), Meilensteine: %d (x5), Rueckfragen: %d (x3)",
        aus    = "  Haekchen 'Bindung waechst' ist AUS - die Punkte sind eingefroren.",
        maxx   = "erreicht (Stufe 3)",
        anteil = "  Dieses Leben hat %d Punkte beigetragen (informativ, nicht Teil der Stufe).",
    },
    en = {
        statusZeile = "Bond: tier %d, %d points",
        kopf   = "Bond:",
        stufe  = "  Tier %d of 3 (%d points; next tier at %s)",
        boden  = "  Hour floor: tier %d (the bond never drops below what play time alone carries)",
        quellen = "  Near-deaths: %d (x3), play-days: %d (x2), milestones: %d (x5), answers: %d (x3)",
        aus    = "  'Bond grows' is OFF - points are frozen.",
        maxx   = "reached (tier 3)",
        anteil = "  This life has contributed %d points (informational, not part of the tier).",
    },
}

function W.status()
    local T = TEXT[ns.sprache and ns.sprache() or "de"] or TEXT.de
    local ok, stufe = pcall(W.stufe)
    local ok2, punkte = pcall(W.punkte)
    if not (ok and ok2) then return { T.statusZeile:format(0, 0) } end
    return { T.statusZeile:format(stufe, punkte) }
end

function W.bindung()
    local T = TEXT[ns.sprache and ns.sprache() or "de"] or TEXT.de
    local b = speicher()
    if not b then return { T.kopf, "  ?" } end
    local stufe = W.stufe()
    local punkte = punkteAus(b)
    local naechste = (stufe >= 3) and T.maxx or tostring(W.STUFEN_PUNKTE[stufe + 1])
    local out = { T.kopf, T.stufe:format(stufe, punkte, naechste), T.boden:format(stundenBoden() >= 100 and 3
        or stundenBoden() >= 50 and 2 or stundenBoden() >= 10 and 1 or 0) }
    out[#out + 1] = T.quellen:format(b.beinahe, b.tage, b.meilensteine, b.antworten)
    if not an("bindungWaechst") then out[#out + 1] = T.aus end
    if type(ns.char) == "table" and tonumber(ns.char.bindungBeitrag) then
        out[#out + 1] = T.anteil:format(ns.char.bindungBeitrag)
    end
    return out
end
