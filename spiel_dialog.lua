-- spiel_dialog.lua — Knoten und ein Intent fuer das Minispiel "Weisst du noch?" (Welle 14e).
-- NUR Daten, kein Code, kein eigener Global: alles haengt sich an LyraGestalt_Dialog aus dialog.lua.
-- Laedt NACH welle2_dialog.lua und VOR UI/Dialog.lua (TOC). Zu diesem Zeitpunkt ist
-- LyraGestalt_Dialog da, ns.Dialog aber noch nicht; die Aktions-Funktionen registriert
-- Sinne/Welle14e.lua bei PLAYER_LOGIN in ns.Dialog.aktionen. Diese Datei kennt nur Strings.
--
-- WARUM DAS SPIEL KEIN EIGENES FENSTER HAT (Recherche 19 §2.1): UI/Dialog.lua kann bis zu vier
-- Antwortknoepfe, ESC ueber UISpecialFrames und einen Kampfriegel - geprueft und im Feld
-- gelaufen. Ein Quiz ist damit Daten plus Logik, kein Frame. Kein CreateFrame, kein OnUpdate,
-- kein Ticker kommt aus dieser Welle dazu.
--
-- ZWEI SORTEN KNOTEN, und der Unterschied entscheidet ueber die Aufnahme (§2.5):
--   * Knoten MIT Platzhalter ({frage} {antwort} {ergebnis}) - Untertitel, KEINE Stimme.
--     UI/Dialog.lua (stimmeName) rendert nichts, was ein {wort} traegt; eine vorgelesene
--     Frage waere ohnehin langsamer als vier Knoepfe zu lesen.
--   * Knoten OHNE Platzhalter (leer / richtig / falsch / schluss / nicht_jetzt) - voll vertont
--     ueber die bestehende Namensregel dialog_k_<knotenid>-1. Dort sitzt die Figur.
-- KEINE dieser Zeilen traegt ein Anrede-Token {Held|Heldin}: das waere die Verdopplung des
-- Rendersatzes auf -m/-f (§2.5, letzter Absatz). Wer hier eines einbaut, rechnet die Zahl mit.
--
-- DIE ANTWORTKNOEPFE DES FRAGEKNOTENS SIND ABSICHTLICH LEER: UI/Dialog.lua fuellt Platzhalter
-- nur im KNOTENTEXT (txt(k.text, vars)), nicht in den Knopftexten (txt(a.text) ohne vars).
-- Sinne/Welle14e.lua schreibt die vier Antworten darum vor jedem Zeigen direkt in diese
-- Tabellen. Das ist kein Trick an UI/Dialog.lua vorbei, sondern die einzige Stelle, an der
-- diese Datei nicht nur gelesen wird - und sie gehoert derselben Welle.
--
-- Maus, nur Maus: kein EditBox, kein SetFocus, kein EnableKeyboard steht in dieser Datei und in
-- Sinne/Welle14e.lua. Die Ziffern 1-4 des Gespraechs sind waehrend eines Spiels abseits des
-- Taxis gesperrt (Sinne/Welle14e.lua, Abschnitt "Tastatur-Riegel").

local D = LyraGestalt_Dialog
if type(D) ~= "table" then return end
D.intents = D.intents or {}
D.knoten = D.knoten or {}

-- ---------------------------------------------------------------------------------------------
-- Intent: /lyra spiel. HINTEN angehaengt - "wie lange spiele ich" gehoert weiter dem Intent
-- rit_wielange aus rituale_dialog.lua, der vorne steht. Die Worttreffer laufen mit Wortgrenzen
-- (UI/Dialog.lua normalisiere()), " spielzeit " faengt " spiel " also nicht ab.
-- Der Menueeintrag ist der zweite Weg (UI/Menue.lua, W14E). Von selbst geht hier nie etwas auf.
-- ---------------------------------------------------------------------------------------------
D.intents[#D.intents + 1] = { id = "spiel", aktion = "spiel_start", woerter = {
    "spiel", "spiele", "spielen", "lass uns spielen", "quiz", "raten", "rate mal",
    "frag mich was", "frag mich etwas",
    "game", "a game", "play", "lets play", "quiz me", "ask me something",
} }

local K = D.knoten
local function knoten(t) K[#K + 1] = t end

-- ---------------------------------------------------------------------------------------------
-- Leer-Absage: die Chronik gibt noch keine fuenf Fragen her. Das ist ein KOEDER, kein Fehler
-- (§2.6) - Lyra sagt, dass sie mehr ueber den Spieler wissen will, nicht dass etwas kaputt ist.
-- ---------------------------------------------------------------------------------------------
knoten({ id = "spiel_leer_1", miene = "shy", ende = true,
    text = { de = "Frag mich in ein paar Stunden nochmal. Ich hab noch zu wenig über dich.",
             en = "Ask me again in a few hours. I don't have enough on you yet." } })
knoten({ id = "spiel_leer_2", miene = "thinking", ende = true,
    text = { de = "Wir kennen uns zu kurz für dieses Spiel. Gib mir Zeit.",
             en = "We haven't known each other long enough for this. Give me time." } })

-- Kein Anlass (kein Taxi, keine Rast) oder ein Riegel liegt: eine Zeile, kein Vortrag.
knoten({ id = "spiel_nicht_jetzt", miene = "whatever", ende = true,
    text = { de = "Nicht jetzt. Frag mich, wenn du sitzt oder fliegst.",
             en = "Not now. Ask me when you're sitting down or in the air." } })

-- ---------------------------------------------------------------------------------------------
-- Die Frage. {frage} kommt aus Sinne/Welle14e.lua; die vier Knopftexte werden dort direkt in
-- diese Tabellen geschrieben (siehe Kopf). Genau vier Knoepfe, genau eine richtige Antwort.
-- ---------------------------------------------------------------------------------------------
knoten({ id = "spiel_frage", miene = "interested",
    text = { de = "{frage}", en = "{frage}" },
    antworten = {
        { text = { de = "", en = "" }, aktion = "spiel_a1" },
        { text = { de = "", en = "" }, aktion = "spiel_a2" },
        { text = { de = "", en = "" }, aktion = "spiel_a3" },
        { text = { de = "", en = "" }, aktion = "spiel_a4" },
    } })

-- ---------------------------------------------------------------------------------------------
-- Richtig (fuenf Zeilen, alle vertont). Ein Knopf, damit der Spieler den Takt bestimmt und
-- nichts von selbst weiterlaeuft - ein Quiz, das wegklickt, waehrend man liest, ist keines.
-- ---------------------------------------------------------------------------------------------
local function weiter()
    return { { text = { de = "Weiter.", en = "Next." }, aktion = "spiel_weiter" } }
end

knoten({ id = "spiel_richtig_1", miene = "amused", antworten = weiter(),
    text = { de = "Richtig. Du passt doch auf.", en = "Right. So you do pay attention." } })
knoten({ id = "spiel_richtig_2", miene = "happy", antworten = weiter(),
    text = { de = "Ja. Genau das.", en = "Yes. Exactly that." } })
knoten({ id = "spiel_richtig_3", miene = "smug", antworten = weiter(),
    text = { de = "Richtig, und du hast nicht mal überlegt.", en = "Right, and you didn't even have to think." } })
knoten({ id = "spiel_richtig_4", miene = "smirk", antworten = weiter(),
    text = { de = "Stimmt. Ich hatte kurz Zweifel.", en = "Correct. I had my doubts there." } })
knoten({ id = "spiel_richtig_5", miene = "touched", antworten = weiter(),
    text = { de = "Ja. Du erinnerst dich besser, als du zugibst.", en = "Yes. You remember more than you admit." } })

-- ---------------------------------------------------------------------------------------------
-- Falsch (fuenf Zeilen, alle vertont). Kein "leider", kein "du haettest" - Ton-Regel des
-- gemeinsamen Auftrags. Danach kommt die Aufloesung, nie ein zweiter Versuch.
-- ---------------------------------------------------------------------------------------------
local function aufloesen()
    return { { text = { de = "Und was war richtig?", en = "So what was it?" }, aktion = "spiel_aufloesung" } }
end

knoten({ id = "spiel_falsch_1", miene = "smug", antworten = aufloesen(),
    text = { de = "Nein. Ich merk mir sowas besser als du.", en = "No. I keep better track of this than you do." } })
knoten({ id = "spiel_falsch_2", miene = "whatever", antworten = aufloesen(),
    text = { de = "Falsch. Du warst auch beschäftigt, ich weiß.", en = "Wrong. You were busy, I know." } })
knoten({ id = "spiel_falsch_3", miene = "hmm", antworten = aufloesen(),
    text = { de = "Daneben. Ich sag's dir gleich.", en = "Off. I'll tell you in a second." } })
knoten({ id = "spiel_falsch_4", miene = "shy", antworten = aufloesen(),
    text = { de = "Nein. Und das tut mir fast leid.", en = "No. And I almost feel bad about it." } })
knoten({ id = "spiel_falsch_5", miene = "thinking", antworten = aufloesen(),
    text = { de = "Knapp vorbei. Fast ist auch daneben.", en = "Close. Close doesn't count." } })

-- Aufloesung: {antwort} traegt einen Zonen- oder Gegnernamen, also nie eine Aufnahme.
knoten({ id = "spiel_aufloesung", miene = "thinking",
    text = { de = "{antwort}", en = "{antwort}" },
    antworten = weiter() })

-- ---------------------------------------------------------------------------------------------
-- Schluss: erst die Zahl (Untertitel, {ergebnis} - hier steht auch das Geisterduell gegen den
-- eigenen Rekord), dann Lyras Wort dazu. Getrennt, weil die Schlusszeilen vertont sind und
-- eine Zahl in einer vertonten Zeile keine Aufnahme bekommen koennte (§2.5).
-- ---------------------------------------------------------------------------------------------
knoten({ id = "spiel_ergebnis", miene = "interested",
    text = { de = "{ergebnis}", en = "{ergebnis}" },
    antworten = { { text = { de = "Und?", en = "And?" }, aktion = "spiel_schluss" } } })

knoten({ id = "spiel_schluss_1", miene = "neutral", ende = true,
    text = { de = "Reicht für heute. Schau wieder nach vorn.", en = "That's enough. Eyes forward again." } })
knoten({ id = "spiel_schluss_2", miene = "smirk", ende = true,
    text = { de = "Genug gefragt. Ich muss ja nicht alles ausplaudern.", en = "Enough questions. I don't have to tell you everything." } })
knoten({ id = "spiel_schluss_3", miene = "touched", ende = true,
    text = { de = "Das war's. Du kennst uns ganz gut.", en = "That's it. You know us pretty well." } })
knoten({ id = "spiel_schluss_4", miene = "wonder", ende = true,
    text = { de = "Schluss. Ich will auch mal aus dem Fenster sehen.", en = "Done. I'd like to look out the window too." } })
