-- person_dialog.lua — Knoten und ein Intent fuer die Rueckfragen (Welle 17, "Sie fragt zurück").
-- NUR Daten, kein Code, kein eigener Global: alles haengt sich an LyraGestalt_Dialog aus dialog.lua.
-- Laedt zwischen welle2_dialog.lua und UI/Dialog.lua (TOC), wie jede andere *_dialog.lua-Datei
-- (Muster spiel_dialog.lua/rituale_dialog.lua). Die Aktions-Funktionen registriert
-- Sinne/Welle17.lua bei PLAYER_LOGIN in ns.Dialog.aktionen; diese Datei kennt nur Strings.
--
-- ZEHN FRAGE-KNOTEN (Reihenfolge/Auswahl: Sinne/Welle17.lua W.FRAGEN), je hoechstens vier
-- Antwortknoepfe (MAX_ANTWORTEN). Die meisten Antworten tragen "merkt" direkt (ein fester
-- Auswahlwert je Knopf) — UI/Dialog.lua schreibt ihn VOR der Aktion ins Personen-Gedaechtnis
-- (D.antwort(): erst setzt/merkt, dann Aktion), die geteilte Aktion "person_registriert" muss den
-- Schluessel darum nicht kennen. Drei Knoten (Lieblingszone, Lieblingsberuf, Spitzname) bekommen
-- ihre Knopftexte/merkt-Werte ERST beim Oeffnen von Sinne/Welle17.lua gefuellt (Muster
-- spiel_dialog.lua: "die Antwortknoepfe des Fragenknotens sind absichtlich leer").
--
-- TON: kurz, trocken, eine Beobachtung, nie "leider/du hättest" (gemeinsamer Auftrag). Keine
-- Anrede-Token — diese Knoten sind neu und sollen nicht automatisch die Aufnahmenzahl verdoppeln;
-- die Fragen selbst sind ohnehin Text im Fenster, keine Katalogzeilen mit Stimme (Ausnahme: falls
-- ein spaeteres Team sie vertonen will, foegt die Stimme wie ueberall im Gespraech ueber die
-- Namensregel dialog_k_<knotenid>-1 automatisch hinzu, sobald der Text platzhalterfrei ist).
--
-- MAUS, NUR MAUS: kein EditBox, kein SetFocus in dieser Datei. "Haustier" ist bewusst nur
-- Bestaetigung ja/nein (Auftrag) — der Name kommt aus UnitName("pet"), nie aus Tastatur.

local D = LyraGestalt_Dialog
if type(D) ~= "table" then return end
D.intents = D.intents or {}
D.knoten = D.knoten or {}

-- ---------------------------------------------------------------------------------------------
-- Intent: /lyra frag du mich (u. Varianten). Bewusst NICHT "frag mich was"/"frag mich etwas" —
-- die gehoeren seit Welle 14e schon dem Quiz (spiel_dialog.lua); eine Ueberschneidung wuerde die
-- Rueckfrage hinter dem Quiz verstecken. Der Menue-Eintrag (Sinne/Welle17.lua W.menueEintrag) ist
-- der zweite Weg; von selbst geht hier nie etwas auf.
-- ---------------------------------------------------------------------------------------------
D.intents[#D.intents + 1] = { id = "person_frag", aktion = "person_frag_start", woerter = {
    "frag du mich", "frag mich zurück", "frag zurück", "stell du mir eine frage",
    "du fragst mich", "jetzt frag mich",
    "ask me back", "you ask me", "your turn to ask", "ask me a question for once",
} }

local K = D.knoten
local function knoten(t) K[#K + 1] = t end

-- ---------------------------------------------------------------------------------------------
-- Riegel und Leer-Absagen.
-- ---------------------------------------------------------------------------------------------
knoten({ id = "person_frag_nicht_jetzt", miene = "whatever", ende = true,
    text = { de = "Nicht jetzt. Frag mich, wenn du sitzt oder fliegst.",
             en = "Not now. Ask me when you're sitting down or in the air." } })

knoten({ id = "person_frag_leer", miene = "smug", ende = true,
    text = { de = "Ich weiß genug. Für heute.", en = "I know enough. For today." } })

knoten({ id = "person_lass_gut_sein_1", miene = "neutral", ende = true,
    text = { de = "Gut. Ein andermal.", en = "Fine. Another time." } })

knoten({ id = "person_lass_gut_sein_aus", miene = "neutral", ende = true,
    text = { de = "Gut. Ich frag nicht mehr. Steht in den Einstellungen, falls du's dir anders überlegst.",
             en = "Fine. I'll stop asking. It's in the settings if you change your mind." } })

-- Quittungen: drei Zeilen, geteilt ueber alle zehn Fragen (Sinne/Welle17.lua zufall(3)). Kurz,
-- keine Dankesrede (Muster spiel_dialog.lua spiel_richtig_*).
knoten({ id = "person_dank_1", miene = "touched", ende = true,
    text = { de = "Merk ich mir.", en = "I'll remember that." } })
knoten({ id = "person_dank_2", miene = "interested", ende = true,
    text = { de = "Gut zu wissen.", en = "Good to know." } })
knoten({ id = "person_dank_3", miene = "smirk", ende = true,
    text = { de = "Notiert.", en = "Noted." } })

-- Gemeinsamer "Lass gut sein"-Knopf, an jede Frage angehaengt, die noch Platz hat (MAX_ANTWORTEN
-- = 4). Zwei Fragen (Lieblingszone, Lieblingsberuf) brauchen ihre vier Plaetze fuer Auswahlwerte
-- und tragen ihn darum nicht — er bleibt ueber jede andere Frage derselben Sitzung erreichbar.
local function lassGutSein()
    return { text = { de = "Lass gut sein.", en = "Never mind." }, aktion = "person_lass_gut_sein" }
end

-- ---------------------------------------------------------------------------------------------
-- 1  Lieblingszone (char). Knoepfe 1-2 dynamisch (Top-2 Zonen), 3 = "Anderswo.", 4 = Lass gut sein.
-- Sinne/Welle17.lua fuellt 1-2 vor dem Zeigen; ohne genug Zonen blendet "person_leer" sie aus.
-- ---------------------------------------------------------------------------------------------
knoten({ id = "person_frag_lieblingszone", miene = "interested",
    text = { de = "Wenn du dir eine Zone aussuchen dürftest, um dort alt zu werden — welche?",
             en = "If you could pick one zone to grow old in — which one?" },
    antworten = {
        { text = { de = "", en = "" } },
        { text = { de = "", en = "" } },
        { text = { de = "Anderswo.", en = "Somewhere else." },
          merkt = { schluessel = "lieblingszone", wert = "andere", ebene = "char" },
          aktion = "person_registriert" },
        { text = { de = "Lass gut sein.", en = "Never mind." }, aktion = "person_lass_gut_sein" },
    } })

-- ---------------------------------------------------------------------------------------------
-- 2  Wasser (konto) — "Angst vor Wasser: ja/nein" (Auftrag), plus Lass gut sein.
-- ---------------------------------------------------------------------------------------------
knoten({ id = "person_frag_wasser", miene = "hmm",
    text = { de = "Wasser. Macht dir das was aus, oder gehst du gern rein?",
             en = "Water. Does it bother you, or do you like going in?" },
    antworten = {
        { text = { de = "Macht mir was aus.", en = "It bothers me." },
          merkt = { schluessel = "wasser", wert = "ja", ebene = "konto" }, aktion = "person_registriert" },
        { text = { de = "Nichts dabei.", en = "Doesn't bother me." },
          merkt = { schluessel = "wasser", wert = "nein", ebene = "konto" }, aktion = "person_registriert" },
        lassGutSein(),
    } })

-- ---------------------------------------------------------------------------------------------
-- 3  Haustier (char, nur mit UnitExists("pet")) — reine Bestaetigung, kein Tippen.
-- {haustier} kommt aus vars (Sinne/Welle17.lua starten()), frisch aus UnitName("pet").
-- ---------------------------------------------------------------------------------------------
knoten({ id = "person_frag_haustier", miene = "amused",
    text = { de = "Hat {haustier} einen Namen, den ich benutzen darf?",
             en = "Does {haustier} have a name I'm allowed to use?" },
    antworten = {
        { text = { de = "Ja.", en = "Yes." }, aktion = "person_haustier_ja" },
        { text = { de = "Lieber nicht.", en = "Rather not." },
          merkt = { schluessel = "haustier", wert = false, ebene = "char" }, aktion = "person_registriert" },
        lassGutSein(),
    } })

-- ---------------------------------------------------------------------------------------------
-- 4  Lieblingsberuf (char). Knoepfe 1-2 dynamisch (eigene Berufe, ns.Welle13a.berufeLesen), 3 =
-- "Kein Favorit.", 4 = Lass gut sein.
-- ---------------------------------------------------------------------------------------------
knoten({ id = "person_frag_lieblingsberuf", miene = "thinking",
    text = { de = "Was ist dein Lieblingsberuf von den beiden?",
             en = "Which of your two professions do you like better?" },
    antworten = {
        { text = { de = "", en = "" } },
        { text = { de = "", en = "" } },
        { text = { de = "Kein Favorit.", en = "No favorite." },
          merkt = { schluessel = "lieblingsberuf", wert = "keiner", ebene = "char" },
          aktion = "person_registriert" },
        { text = { de = "Lass gut sein.", en = "Never mind." }, aktion = "person_lass_gut_sein" },
    } })

-- ---------------------------------------------------------------------------------------------
-- 5  Tageszeit (konto).
-- ---------------------------------------------------------------------------------------------
knoten({ id = "person_frag_tageszeit", miene = "interested",
    text = { de = "Spielst du lieber tagsüber oder nachts?", en = "Do you prefer playing by day or by night?" },
    antworten = {
        { text = { de = "Tagsüber.", en = "By day." },
          merkt = { schluessel = "tageszeit", wert = "tag", ebene = "konto" }, aktion = "person_registriert" },
        { text = { de = "Nachts.", en = "At night." },
          merkt = { schluessel = "tageszeit", wert = "nacht", ebene = "konto" }, aktion = "person_registriert" },
        { text = { de = "Ist mir gleich.", en = "Doesn't matter to me." },
          merkt = { schluessel = "tageszeit", wert = "gleich", ebene = "konto" }, aktion = "person_registriert" },
        lassGutSein(),
    } })

-- ---------------------------------------------------------------------------------------------
-- 6  Spitzname (konto, nur wenn ns.Bindung.spitzname() etwas vorschlaegt). Knopf 1 dynamisch
-- (der Vorschlag selbst als merkt-Wert), 2-3 statisch.
-- ---------------------------------------------------------------------------------------------
knoten({ id = "person_frag_spitzname", miene = "shy",
    text = { de = "Sag mal — nennst du mich lieber {spitzname}?",
             en = "Tell me — would you rather call me {spitzname}?" },
    antworten = {
        { text = { de = "", en = "" } },
        { text = { de = "Nein, lieber nicht.", en = "No, rather not." },
          merkt = { schluessel = "spitzname", wert = false, ebene = "konto" }, aktion = "person_registriert" },
        lassGutSein(),
    } })

-- ---------------------------------------------------------------------------------------------
-- 7  Mut / Selbsteinschaetzung (char).
-- ---------------------------------------------------------------------------------------------
knoten({ id = "person_frag_mut", miene = "hmm",
    text = { de = "Wie würdest du dich einschätzen: vorsichtig, normal, oder Draufgänger?",
             en = "How would you rate yourself: careful, normal, or reckless?" },
    antworten = {
        { text = { de = "Vorsichtig.", en = "Careful." },
          merkt = { schluessel = "mut", wert = "vorsichtig", ebene = "char" }, aktion = "person_registriert" },
        { text = { de = "Normal.", en = "Normal." },
          merkt = { schluessel = "mut", wert = "normal", ebene = "char" }, aktion = "person_registriert" },
        { text = { de = "Draufgänger.", en = "Reckless." },
          merkt = { schluessel = "mut", wert = "draufgaenger", ebene = "char" }, aktion = "person_registriert" },
        lassGutSein(),
    } })

-- ---------------------------------------------------------------------------------------------
-- 8  Ziel (char).
-- ---------------------------------------------------------------------------------------------
knoten({ id = "person_frag_ziel", miene = "interested",
    text = { de = "Was willst du eigentlich mit dem hier — Stufe 60, oder einfach überleben?",
             en = "What's your actual goal here — level 60, or just staying alive?" },
    antworten = {
        { text = { de = "Stufe 60.", en = "Level 60." },
          merkt = { schluessel = "ziel", wert = "60", ebene = "char" }, aktion = "person_registriert" },
        { text = { de = "Überleben.", en = "Staying alive." },
          merkt = { schluessel = "ziel", wert = "ueberleben", ebene = "char" }, aktion = "person_registriert" },
        { text = { de = "Seh ich, wenn ich da bin.", en = "I'll see when I get there." },
          merkt = { schluessel = "ziel", wert = "offen", ebene = "char" }, aktion = "person_registriert" },
        lassGutSein(),
    } })

-- ---------------------------------------------------------------------------------------------
-- 9  Allein oder Gruppe (konto).
-- ---------------------------------------------------------------------------------------------
knoten({ id = "person_frag_allein", miene = "thinking",
    text = { de = "Lieber allein unterwegs oder in einer Gruppe?", en = "Do you prefer going alone or with a group?" },
    antworten = {
        { text = { de = "Allein.", en = "Alone." },
          merkt = { schluessel = "allein", wert = "allein", ebene = "konto" }, aktion = "person_registriert" },
        { text = { de = "In der Gruppe.", en = "With a group." },
          merkt = { schluessel = "allein", wert = "gruppe", ebene = "konto" }, aktion = "person_registriert" },
        { text = { de = "Kommt drauf an.", en = "Depends." },
          merkt = { schluessel = "allein", wert = "beides", ebene = "konto" }, aktion = "person_registriert" },
        lassGutSein(),
    } })

-- ---------------------------------------------------------------------------------------------
-- 10  Laut bei Gefahr (konto). Schreibt zusaetzlich "setzt" (Muster Erst-Start) — die WIRKUNG
-- des Schluessels "warnLauter" ist nicht Teil dieser Welle (Bericht §4).
-- ---------------------------------------------------------------------------------------------
knoten({ id = "person_frag_laut", miene = "hmm",
    text = { de = "Soll ich bei Gefahr lauter werden, oder reicht dir das, was ich jetzt mache?",
             en = "Should I get louder when things get dangerous, or is what I do now enough?" },
    antworten = {
        { text = { de = "Lauter werden.", en = "Get louder." },
          setzt = { warnLauter = true },
          merkt = { schluessel = "laut", wert = "ja", ebene = "konto" }, aktion = "person_registriert" },
        { text = { de = "Reicht so.", en = "It's enough." },
          setzt = { warnLauter = false },
          merkt = { schluessel = "laut", wert = "nein", ebene = "konto" }, aktion = "person_registriert" },
        lassGutSein(),
    } })
