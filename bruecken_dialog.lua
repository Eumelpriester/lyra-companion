-- bruecken_dialog.lua — Intents und Antworttexte fuer die Bruecken (TomTom/Questie/BugGrabber).
-- NUR Daten, kein Code, kein eigener Global: alles haengt sich an LyraGestalt_Dialog aus dialog.lua.
-- Laedt NACH dialog.lua und VOR UI/Dialog.lua (TOC) — zu diesem Zeitpunkt ist LyraGestalt_Dialog
-- schon da, ns.Dialog aber noch nicht; die Aktions-Funktionen registriert deshalb Sinne/Bruecken.lua
-- bei PLAYER_LOGIN in ns.Dialog.aktionen. Diese Datei kennt nur Strings.
--
-- Aufbau wie dialog.lua:
--   intents[i] = { id, aktion = "name", praefix = { "..." } | woerter = { "..." } }
--   * praefix: Treffer nur am Satzanfang (roh:lower()), der Rest ist der Inhalt (Titel / Name).
--     UI/Dialog.lua reicht diesen Rest bei Aktions-Intents (noch) NICHT an die Aktion weiter,
--     darum stehen dieselben Praefixe unten in LyraGestalt_Dialog.bruecken — Sinne/Bruecken.lua
--     schneidet den Inhalt damit selbst ab. Praefixe sind je Gruppe LANG VOR KURZ sortiert
--     ("wo finde ich " vor "wo ist "), sonst frisst der kurze Praefix den langen.
--   * woerter: ASCII-normalisiert (ae/oe/ue/ss), kleingeschrieben, Treffer mit Wortgrenzen.
-- Reihenfolge = Prioritaet. Diese Intents haengen HINTEN an, die aus dialog.lua gehen also vor
-- (bekannte Folge: "/lyra finde den mob" trifft zuerst den alten Intent "ziel" wegen des Wortes "mob").
-- Knoten: Antworten, fuer die es kein Ereignis in phrasen.lua gibt (leere Liste, keine Position).
-- Anrede-Token {Held|Heldin} und Platzhalter {n} sind erlaubt (ns.Anrede / ns.fuelle).

local D = LyraGestalt_Dialog
if type(D) ~= "table" then return end
D.intents = D.intents or {}
D.knoten = D.knoten or {}

-- ---------------------------------------------------------------------------------------------
-- Praefix-Listen (Sinne/Bruecken.lua liest sie, um den Inhalt selbst abzuschneiden)
-- ---------------------------------------------------------------------------------------------
D.bruecken = {
    punkt = {
        "merk dir diese stelle ", "merk dir die stelle ", "merk dir hier ", "merk dir ",
        "markiere die stelle ", "markiere hier ", "markier hier ", "markiere ", "markier ",
        "setz einen punkt ", "punkt hier ", "punkt ",
        "waypoint here ", "mark this spot ", "mark this ", "mark here ", "mark ",
    },
    quest = {
        "wo bekomme ich die quest ", "wo bekomme ich den auftrag ", "wo bekomme ich quest ",
        "wo bekomme ich ", "wo kriege ich die quest ", "wo kriege ich ",
        "wo startet die quest ", "wo startet ", "questgeber ", "quest geber ", "auftraggeber ",
        "where do i get the quest ", "where do i get quest ", "where do i get ",
        "where does the quest ", "quest giver ", "questgiver ",
    },
    mob = {
        "wo finde ich den ", "wo finde ich die ", "wo finde ich ", "wo steckt der ", "wo steckt ",
        "wo ist denn ", "wo ist der ", "wo ist die ", "wo ist das ", "wo ist ",
        "suche mir ", "such mir ", "suche nach ", "such nach ", "suche ", "such ",
        "finde mir ", "finde ", "find ",
        "where do i find the ", "where do i find ", "where can i find ",
        "where is the ", "where is a ", "where is ", "find me ", "locate ",
    },
}

-- ---------------------------------------------------------------------------------------------
-- Intents (haengen hinten an; erst die Praefix-Intents, dann die Wort-Intents)
-- ---------------------------------------------------------------------------------------------
local I = D.intents
-- Praefix-Absichten (spezifisch: "such ", "wo ist ", "punkt ") kommen VOR die allgemeinen aus dialog.lua,
-- sonst faengt z. B. das Wort "mob" im Intent "ziel" ein "finde den mob" ab. Wort-Absichten haengen hinten an.
local vorn = 0
local function intent(t)
    if t.praefix then vorn = vorn + 1; table.insert(I, vorn, t) else I[#I + 1] = t end
end

-- Quest VOR Mob: "wo bekomme ich ..." und "wo startet ..." wuerden sonst am Mob-Praefix "wo ist "
-- vorbeilaufen, sobald jemand "wo ist die quest ..." tippt.
intent({ id = "bruecke_punkt_titel", aktion = "bruecke_punkt", praefix = D.bruecken.punkt })
intent({ id = "bruecke_quest",       aktion = "bruecke_quest", praefix = D.bruecken.quest })
intent({ id = "bruecke_mob",         aktion = "bruecke_mob",   praefix = D.bruecken.mob })

-- Ohne Titel / ohne Namen: dieselben Aktionen, nur als Stichwort.
intent({ id = "bruecke_punkte", aktion = "bruecke_punkte", woerter = {
    "meine punkte", "my waypoints", "welche punkte", "alle punkte", "punkte liste",
    "punkte", "waypoints", "markierungen", "wegpunkte",
} })
intent({ id = "bruecke_punkt", aktion = "bruecke_punkt", woerter = {
    "punkt hier", "punkt setzen", "setz einen punkt", "markier", "markiere", "markier das",
    "merk dir die stelle", "merk dir diese stelle", "merk dir das hier",
    "waypoint here", "mark this", "mark here", "remember this spot",
} })
intent({ id = "bruecke_runen", aktion = "bruecke_runen", woerter = {
    "runen", "fehler", "fehlermeldung", "fehlermeldungen", "bug", "bugs", "bugsack",
    "error", "errors", "lua fehler", "lua error",
} })

-- ---------------------------------------------------------------------------------------------
-- Knoten: Antworten ohne eigenes Ereignis in phrasen.lua (Aktion liefert die ID zurueck)
-- ---------------------------------------------------------------------------------------------
local K = D.knoten
local function knoten(t) K[#K + 1] = t end

knoten({ id = "bruecke_keine_position", miene = "hmm", ende = true,
    text = { de = "Ich weiß gerade selbst nicht, wo wir stehen. Die Karte schweigt.",
             en = "Right now I don't know where we are either. The map is silent." } })

knoten({ id = "bruecke_keine_punkte", miene = "whatever", ende = true,
    text = { de = "Keine Punkte in der Chronik. Du merkst dir wohl alles selbst, {Held|Heldin}.",
             en = "No waypoints in the chronicle. You must remember everything yourself, hero." } })

knoten({ id = "bruecke_punkt_unbekannt", miene = "hmm", ende = true,
    text = { de = "So einen Punkt habe ich nicht. Schau in „/lyra punkte“, welche Nummern es gibt.",
             en = "I don't have that waypoint. Check \"/lyra waypoints\" for the numbers I do have." } })

knoten({ id = "bruecke_keine_runen", miene = "veryhappy", ende = true,
    text = { de = "Keine einzige wildgewordene Rune. Bei den Leylinien, ein guter Tag.",
             en = "Not a single runaway rune. By the ley lines, a good day." } })

knoten({ id = "bruecke_ohne_buggrabber", miene = "whatever", ende = true,
    text = { de = "Ohne BugSack fängt niemand die Runen ein. Ich sehe nur, was ich selbst verschütte.",
             en = "Without BugSack nobody catches the runes. I only see what I spill myself." } })

knoten({ id = "bruecke_kein_name", miene = "thinking", ende = true,
    text = { de = "Du hast vergessen zu sagen, wen ich suchen soll.",
             en = "You forgot to tell me who I should look for." } })
