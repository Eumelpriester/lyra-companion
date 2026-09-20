-- dialog.lua — Gespraechsbaum v0 und Intent-Antworten. NUR Daten, kein Code.
-- Namensraum: LyraGestalt_Dialog (einziger Global neben LyraGestaltDB/LyraGestalt_Phrasen).
-- Knoten: { id, text = {de=,en=}, miene = "...", ende = true|nil, antworten = { {text={de=,en=},
--   weiter = "knotenId"|nil, aktion = "fn"|nil, bedingung = "fn"|nil, setzt = { schluessel = wert }|nil} } }
--   * setzt: Einstellungen, die diese Antwort setzt (ueber ns.Settings.setze). Erst setzt, dann aktion.
--     Damit braucht der Erst-Start-Assistent keine eigene Aktion je Knopf.
--   * aktion kann eine Knoten-ID (und Platzhalter-Tabelle) zurueckgeben, die "weiter" ueberschreibt.
--   * ende = true: keine Antworten, Fenster schliesst nach kurzer Zeit.
--   * Anrede-Token {Held|Heldin} erlaubt (ns.Anrede), Platzhalter {zone} usw. (ns.fuelle).
-- Intents: Reihenfolge = Prioritaet; woerter sind ASCII-normalisiert (ae/oe/ue/ss, kleingeschrieben).
LyraGestalt_Dialog = {
  start = "start",
  knoten = {
    { id = "start", miene = "interested",
      text = { de = "Was gibt's, {Held|Heldin}?", en = "What is it, hero?" },
      antworten = {
        { text = { de = "Wie geht's dir?", en = "How are you?" }, aktion = "befinden" },
        { text = { de = "Wo bin ich?", en = "Where am I?" }, aktion = "ort" },
        { text = { de = "Was weißt du über mein Ziel?", en = "What do you know about my target?" }, bedingung = "hatZiel", aktion = "ziel" },
        { text = { de = "Erzähl mir was.", en = "Tell me something." }, bedingung = "keinZiel", aktion = "lore" },
        { text = { de = "Mehr...", en = "More..." }, weiter = "mehr" },
      } },
    -- FIX2: "Mehr..." bot mit "Erzähl mir was." genau den Knopf an, der ohne Ziel schon im Start-Knoten
    -- steht -> es sah aus, als fuehre "Mehr..." wieder auf dieselbe Auswahl.
    -- Jetzt schliessen sich die beiden ersten Eintraege aus (hatZiel / keinZiel): der Start-Knoten zeigt
    -- ohne Ziel "Erzähl mir was.", dann steht hier der neue Knoten ueber_lyra - und umgekehrt.
    -- So sind es immer genau 4 Knoepfe (Tasten 1-4) und nie derselbe wie eine Ebene darueber.
    { id = "mehr", miene = "amused",
      text = { de = "Noch was?", en = "Anything else?" },
      antworten = {
        { text = { de = "Erzähl mir was.", en = "Tell me something." }, bedingung = "hatZiel", aktion = "lore" },
        { text = { de = "Wer bist du eigentlich?", en = "Who are you, really?" }, bedingung = "keinZiel", weiter = "ueber_lyra" },
        { text = { de = "Sei still.", en = "Be quiet." }, aktion = "still" },
        { text = { de = "Nichts, schon gut.", en = "Nothing, never mind." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
      } },
    { id = "ueber_lyra", miene = "smug",
      text = { de = "Lyra. Runenweberin, zweite Lehre abgebrochen, seitdem an dich gebunden. Kurzfassung.",
               en = "Lyra. Rune weaver, second apprenticeship abandoned, bound to you ever since. Short version." },
      antworten = {
        { text = { de = "Und die Langfassung?", en = "And the long version?" }, aktion = "lore" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
      } },

    -- Befinden (aktion "befinden" waehlt: kampf > beinahe > rast > normal)
    { id = "befinden_kampf", miene = "alert",
      text = { de = "Das fragst du JETZT? Da steht was mit Zähnen vor dir!", en = "You're asking that NOW? There's something with teeth in front of you!" },
      antworten = {
        { text = { de = "Stimmt. Später.", en = "Right. Later." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
      } },
    { id = "befinden_beinahe", miene = "concerned",
      text = { de = "Ehrlich? Ich zittere noch. Das vorhin war knapp, {Held|Heldin}.", en = "Honestly? Still shaking. That was close earlier, hero." },
      antworten = {
        { text = { de = "Ich weiß. Sorry.", en = "I know. Sorry." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
      } },
    { id = "befinden_rast", miene = "amused",
      text = { de = "Gasthaus, warmes Licht, kein Blut. Mir geht's prächtig. Bestell mir Mana.", en = "An inn, warm light, no blood. I'm splendid. Order me some mana." },
      antworten = {
        { text = { de = "Schön.", en = "Nice." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
      } },
    { id = "befinden_normal", miene = "happy",
      text = { de = "Gut. Die Leylinien summen, du lebst, ich rede. Alles im Lot.", en = "Good. The ley lines hum, you're alive, I'm talking. All is well." },
      antworten = {
        { text = { de = "Schön.", en = "Nice." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
      } },

    -- Ort (aktion "ort": {ort} = Subzone, Zone; {info} aus ns.Chronik.zoneInfo, falls vorhanden)
    { id = "ort", miene = "interested",
      text = { de = "{ort}. Ich lese die Runen hier: alt, aber stabil.", en = "{ort}. Reading the runes here: old, but stable." },
      antworten = {
        { text = { de = "Danke.", en = "Thanks." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
      } },
    { id = "ort_chronik", miene = "thinking",
      text = { de = "{ort}. {info}", en = "{ort}. {info}" },
      antworten = {
        { text = { de = "Danke.", en = "Thanks." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
      } },

    -- Ziel (aktion "ziel": UnitIsPlayer-Sperre zuerst; {name} {level} {art} {vergleich} {n})
    { id = "ziel_info", miene = "thinking",
      text = { de = "{name}, Stufe {level}{art}. {vergleich}", en = "{name}, level {level}{art}. {vergleich}" },
      antworten = {
        { text = { de = "Verstanden.", en = "Got it." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
      } },
    { id = "ziel_bekannt", miene = "alert",
      text = { de = "{name}. Den kenne ich. {n} Mal hat er dich in die Knie gezwungen, {Held|Heldin}.", en = "{name}. I know that one. It has brought you to your knees {n} times, hero." },
      antworten = {
        { text = { de = "Diesmal nicht.", en = "Not this time." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
      } },
    { id = "ziel_keins", miene = "whatever",
      text = { de = "Kein Ziel. Du starrst ins Leere. Ich auch, aber mit Stil.", en = "No target. You're staring at nothing. So am I, but with style." },
      antworten = {
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
      } },
    { id = "ziel_spieler", miene = "shy",
      text = { de = "Über Leute rede ich nicht. Nur über Monster. Ehrensache.", en = "I don't talk about people. Only monsters. Matter of honor." },
      antworten = {
        { text = { de = "Fair.", en = "Fair." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
      } },

    -- Lore / Neckerei. FIX2: sechs Zeilen statt drei; die Reihenfolge merkt sich UI/Dialog.lua in
    -- LyraGestaltDB.chronik[charKey].loreIdx (ueberlebt /reload), pro Gespraech gibt es hoechstens
    -- drei Zeilen, danach lore_ende. Neue Zeilen einfach als lore_7, lore_8 ... anhaengen:
    -- UI/Dialog.lua zaehlt die Knoten selbst (loreAnzahl), keine Zahl im Code anpassen.
    { id = "lore_1", miene = "wonder",
      text = { de = "Ohne Runenfehler kein echter Zauber. Meine erste Rune hat ein Loch in den Turm gebrannt, der Meister nannte es Fenster.", en = "No rune error, no real spell. My first rune burned a hole in the tower; the master called it a window." },
      antworten = {
        { text = { de = "Noch eine.", en = "Another one." }, aktion = "lore" },
        { text = { de = "Danke, reicht.", en = "Thanks, that's enough." }, weiter = "ende" },
      } },
    { id = "lore_2", miene = "smug",
      text = { de = "Die Leylinien unter Azeroth sind wie Adern. Und du trampelst seit Stufe eins darauf herum.", en = "The ley lines under Azeroth are like veins. And you've been stomping on them since level one." },
      antworten = {
        { text = { de = "Noch eine.", en = "Another one." }, aktion = "lore" },
        { text = { de = "Danke, reicht.", en = "Thanks, that's enough." }, weiter = "ende" },
      } },
    { id = "lore_3", miene = "amused",
      text = { de = "Mana schmeckt übrigens nach Blaubeere. Frag nicht, woher ich das weiß.", en = "Mana tastes like blueberry, by the way. Don't ask how I know." },
      antworten = {
        { text = { de = "Noch eine.", en = "Another one." }, aktion = "lore" },
        { text = { de = "Danke, reicht.", en = "Thanks, that's enough." }, weiter = "ende" },
      } },
    { id = "lore_4", miene = "thinking",
      text = { de = "Ein Portal ist eine Tür, die vergisst, wo sie stand. Deshalb zähle ich immer bis zwei, bevor ich hindurchgehe.", en = "A portal is a door that forgets where it stood. That's why I always count to two before stepping through." },
      antworten = {
        { text = { de = "Noch eine.", en = "Another one." }, aktion = "lore" },
        { text = { de = "Danke, reicht.", en = "Thanks, that's enough." }, weiter = "ende" },
      } },
    { id = "lore_5", miene = "interested",
      text = { de = "Arkane Magie ist laut. Du hörst sie nur nicht. Ich schon - seit Jahren, ohne Pause.", en = "Arcane magic is loud. You just can't hear it. I can - for years now, without a single break." },
      antworten = {
        { text = { de = "Noch eine.", en = "Another one." }, aktion = "lore" },
        { text = { de = "Danke, reicht.", en = "Thanks, that's enough." }, weiter = "ende" },
      } },
    { id = "lore_6", miene = "shy",
      text = { de = "Meine Lehre endete mit einem brennenden Vorhang und einem sehr ruhigen Meister. Seitdem passe ich auf andere auf.", en = "My apprenticeship ended with a burning curtain and a very quiet master. I've been watching over other people ever since." },
      antworten = {
        { text = { de = "Noch eine.", en = "Another one." }, aktion = "lore" },
        { text = { de = "Danke, reicht.", en = "Thanks, that's enough." }, weiter = "ende" },
      } },
    -- FIX2: nach drei Zeilen je Gespraech ist Schluss - vorher lief "Noch eine" endlos im Kreis.
    { id = "lore_ende", miene = "whatever",
      text = { de = "Das war's für heute, {Held|Heldin}. Der Rest steht in Büchern, die ich nicht mehr habe.", en = "That's it for today, hero. The rest is in books I don't have any more." },
      antworten = {
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
        { text = { de = "Danke, reicht.", en = "Thanks, that's enough." }, weiter = "ende" },
      } },

    -- Erst-Start-Assistent (design-v2.md 6.3 / 7). Laeuft beim allerersten Login statt des
    -- LOGIN-Grusses und ueber /lyra einrichten. Antworten setzen ihre Werte ueber das Feld
    -- "setzt" (UI/Dialog.lua ruft dafuer ns.Settings.setze) - kein blockierendes Popup, kein Panel.
    { id = "setup_sprache", miene = "interested",
      text = { de = "Ich bin Lyra. Bevor ich mich einrichte: drei kurze Fragen. Sprichst du Deutsch oder English?",
               en = "I'm Lyra. Before I settle in: three short questions. Do you speak German or English?" },
      antworten = {
        { text = { de = "Deutsch.", en = "Deutsch." }, setzt = { sprache = "de" }, weiter = "setup_anrede" },
        { text = { de = "English.", en = "English." }, setzt = { sprache = "en" }, weiter = "setup_anrede" },
        { text = { de = "Nimm, was das Spiel sagt.", en = "Take whatever the game says." }, setzt = { sprache = "auto" }, weiter = "setup_anrede" },
        { text = { de = "Später.", en = "Later." }, aktion = "setupFertig" },
      } },
    { id = "setup_anrede", miene = "thinking",
      text = { de = "Gut. Und wie rede ich dich an?", en = "Good. And how should I address you?" },
      antworten = {
        { text = { de = "Wie mein Charakter aussieht.", en = "However my character looks." }, setzt = { anrede = "auto" }, weiter = "setup_reden" },
        { text = { de = "Männlich.", en = "Male." }, setzt = { anrede = "m" }, weiter = "setup_reden" },
        { text = { de = "Weiblich.", en = "Female." }, setzt = { anrede = "f" }, weiter = "setup_reden" },
        { text = { de = "Gar nicht.", en = "Not at all." }, setzt = { anrede = "keine" }, weiter = "setup_reden" },
      } },
    -- DESIGN-V3 B-12 (17.09.2026): Der Knoten "setup_ansicht" ist ENTFALLEN - drei Fragen statt vier.
    -- Er bot als zweite Antwort "Ganze Figur" an und war damit der kuerzeste Weg von "frisch
    -- installiert" zu einer Ansicht, die der Sprite-Satz in Ganzfigur nicht auslieferbar macht
    -- (Dekollete in praktisch jeder Miene; CurseForge-NSFW-Regel, ESRB "T" - design-v3 b.5,
    -- vermarktung/paywall-antwort.md Blocker 1 und 5). Portrait bleibt Default; die Figur ist
    -- weiterhin ueber Doppelklick, /lyra figur und das Menue erreichbar, aber nicht mehr die
    -- erste Frage, die ein neuer Nutzer beantwortet.
    { id = "setup_reden", miene = "amused",
      text = { de = "Letzte Frage: Wie viel soll ich reden? Warnungen kommen immer, die zähle ich nicht mit.",
               en = "Last question: how much should I talk? Warnings always come through, those don't count." },
      antworten = {
        { text = { de = "Nur wenn es brennt.", en = "Only when something's on fire." }, setzt = { gespraechig = "still" }, aktion = "setupFertig" },
        { text = { de = "Wenig.", en = "Little." }, setzt = { gespraechig = "wenig" }, aktion = "setupFertig" },
        { text = { de = "Normal.", en = "Normal." }, setzt = { gespraechig = "normal" }, aktion = "setupFertig" },
        { text = { de = "Red ruhig.", en = "Talk away." }, setzt = { gespraechig = "viel" }, aktion = "setupFertig" },
      } },
    -- design-v3 g: Der Ausschalter gehoert in die erste Minute, nicht in die FAQ.
    { id = "setup_ende", miene = "happy", ende = true,
      text = { de = "Fertig, {Held|Heldin}. Rechtsklick auf mich öffnet das Gespräch, Shift+Rechtsklick das Menü, /lyra auch. Wenn ich zu viel rede: /lyra still.",
               en = "Done, hero. Right-click me to talk, shift+right-click for the menu, /lyra works too. If I talk too much: /lyra still." } },

    -- Abschluesse
    { id = "still_ok", miene = "shy", ende = true,
      text = { de = "Gut. Ich schweige. Bis es brennt.", en = "Fine. I'll hush. Until something's on fire." } },
    { id = "ende", miene = "happy", ende = true,
      text = { de = "Schon gut. Ich bin da, wenn's brennt. Bei den Leylinien.", en = "Alright. I'm here when things burn. By the ley lines." } },
  },

  -- Textbausteine fuer Platzhalter (Sprache waehlt der Code)
  fragmente = {
    art = {
      elite = { de = ", Elite", en = ", elite" },
      rareelite = { de = ", seltene Elite", en = ", rare elite" },
      rare = { de = ", selten", en = ", rare" },
      worldboss = { de = ", Weltboss", en = ", world boss" },
      trivial = { de = ", harmlos", en = ", trivial" },
      minus = { de = ", Kleinvieh", en = ", small fry" },
      normal = { de = "", en = "" },
      unbekannt = { de = "", en = "" },
    },
    vergleich = {
      leicht = { de = "Das schaffst du mit links. Nimm trotzdem rechts.", en = "You'll manage that left-handed. Use your right anyway." },
      gleich = { de = "Auf Augenhöhe. Also: Augen auf.", en = "On even footing. So: eyes open." },
      schwer = { de = "Zu stark, {Held|Heldin}. Deine Zauber verfehlen, seine nicht.", en = "Too strong, hero. Your spells miss, his don't." },
      unbekannt = { de = "Die Stufe kann ich nicht lesen. Das ist selten ein gutes Zeichen.", en = "Can't read the level. That's rarely a good sign." },
    },
    kampf = {
      ja = { de = "Und du kämpfst gerade, falls es dir nicht aufgefallen ist.", en = "And you're fighting right now, in case you hadn't noticed." },
      nein = { de = "Kein Kampf. Gut so.", en = "No fighting. Good." },
    },
    zone = {   -- Chronik-Fallback fuer {info} in ort_chronik
      beinahe = { de = "Hier bist du schon {n} Mal fast gestorben, {Held|Heldin}. Ich zähle mit.", en = "You've nearly died here {n} times, hero. I'm keeping count." },
      besuche = { de = "Dein {n}. Besuch. Die Runen kennen dich hier schon.", en = "Your visit number {n}. The runes here know you by now." },
    },
  },

  -- Intents fuer /lyra <freitext>. Reihenfolge = Prioritaet. Antworten rotieren.
  -- aktion: Knoten-Text ueber die Dialog-Aktion holen (befinden/ort/ziel/lore). wie: Texte eines anderen Intents.
  intents = {
    { id = "notiz", miene = "interested", praefix = { "notiz:", "note:", "notiz ", "note " },
      texte = {
        { de = "Notiert: „{text}“. Ich vergesse nichts. Fast nichts.", en = "Noted: \"{text}\". I forget nothing. Almost nothing." },
        { de = "Steht in der Chronik. Mit Tinte aus Mana.", en = "It's in the chronicle. Written in mana ink." },
        { de = "„{text}“. Aufgeschrieben, {Meister|Meisterin}. Frag mich in einer Woche, ob ich's noch weiß.", en = "\"{text}\". Written down, master. Ask me in a week if I still remember." },
      } },
    { id = "hilfe", miene = "thinking", woerter = { "hilfe", "help", "befehle", "commands", "was kannst du", "what can you do" },
      texte = {
        { de = "Die Befehle stehen im Chat. Lesen musst du selbst, {Meister|Meisterin}.", en = "The commands are in the chat. Reading them is on you, master." },
        { de = "Alles, was ich kann, steht jetzt unten. Bis auf das Charmante, das lernt man nicht.", en = "Everything I can do is listed below. Except the charm, that can't be taught." },
        { de = "Hilfe? Ich? Immer. Schau in den Chat.", en = "Help? Me? Always. Check the chat." },
      } },
    { id = "still", miene = "shy", woerter = { "sei still", "ruhe", "quiet", "shut up", "still", "klappe", "psst", "leise", "silence", "hush", "halt den mund" },
      texte = {
        { de = "Schon gut. Ich schweige. Bis es brennt.", en = "Fine. I'll hush. Until something's on fire." },
        { de = "Klappe zu, Runen an. Warnungen kommen trotzdem.", en = "Lips sealed, runes on. Warnings still come through." },
        { de = "Still wie ein Leylinien-Knoten. Also: leise brummend.", en = "Quiet as a ley node. That is: humming softly." },
      } },
    { id = "befinden", aktion = "befinden", woerter = { "wie geht", "how are", "alles gut", "geht es dir", "gehts", "you ok", "you okay", "how do you feel", "wie fuehlst", "wie fuhlst" } },
    { id = "ort", aktion = "ort", woerter = { "wo bin", "wo sind wir", "where am", "where are we", "welche zone", "what zone", "wo ist das hier" } },
    { id = "ziel", aktion = "ziel", woerter = { "ziel", "target", "wer ist das", "who is that", "who is this", "was ist das", "what is that", "gegner", "enemy", "mob" } },
    { id = "status", miene = "interested", woerter = { "status", "stand", "bericht", "report", "lage", "zustand" },
      texte = {
        { de = "{zone}, Stufe {level}, {hp} % Leben. {kampf}", en = "{zone}, level {level}, {hp} % health. {kampf}" },
        { de = "Bericht: Stufe {level}, {hp} % Leben, Ort {zone}. {kampf}", en = "Report: level {level}, {hp} % health, location {zone}. {kampf}" },
      } },
    { id = "erzaehl", aktion = "lore", woerter = { "witz", "erzaehl", "erzahl", "tell me", "joke", "story", "geschichte", "lore", "unterhalt" } },
    { id = "danke", miene = "overjoyed", woerter = { "danke", "thanks", "thank you", "thx", "merci", "dankeschoen", "dankeschon" },
      texte = {
        { de = "Danke? DANKE? Bei den Leylinien! ...Ich meine: ja, schon gut. War nichts.", en = "Thanks? THANKS? By the ley lines! ...I mean: sure, whatever. It was nothing." },
        { de = "Oh! Oh, das... das ist... ähm. Ist mir egal. Völlig. Hihi.", en = "Oh! Oh, that's... that's... um. I don't care. At all. Hihi." },
        { de = "Ich schreib mir das auf. Mit Sternchen. Also, wenn ich sowas machen würde.", en = "I'm writing that down. With a little star. If I did that sort of thing." },
      } },
    { id = "lob", wie = "danke", woerter = { "gut gemacht", "toll", "super", "great", "good job", "well done", "klasse", "nice", "prima", "spitze", "awesome", "brav" } },
    { id = "liebe", miene = "shy", woerter = { "ich mag dich", "love you", "liebe dich", "hab dich lieb", "i like you", "heirate", "marry", "kuss", "kiss" },
      texte = {
        { de = "Charmant. Aber ich bin aus Runen und Sturheit, {Süßer|Süße}. Halte dich lieber an Tränke.", en = "Charming. But I'm made of runes and stubbornness, sweetie. Better stick to potions." },
        { de = "Ich mag dich auch. Meistens. Wenn du nicht im Feuer stehst.", en = "I like you too. Mostly. When you're not standing in fire." },
        { de = "Bei den Leylinien, das Mana steigt mir zu Kopf. Sag es nochmal. Nein, sag es nicht.", en = "By the ley lines, the mana's going to my head. Say it again. No, don't." },
      } },
    { id = "gruss", miene = "happy", woerter = { "hallo", "hi", "hey", "moin", "hello", "servus", "huhu", "guten tag", "guten morgen", "guten abend", "good morning", "good evening", "yo", "hoi" },
      texte = {
        { de = "Hallo, {Held|Heldin}. Die Leylinien summen heute besonders schön.", en = "Hello, hero. The ley lines are humming nicely today." },
        { de = "Da bist du ja. Ich hab nicht gewartet. Nur ein bisschen.", en = "There you are. I wasn't waiting. Only a little." },
        { de = "Hey. Ich bin wach. Du auch?", en = "Hey. I'm awake. Are you?" },
      } },
  },

  unbekannt = { miene = "hmm", texte = {
    { de = "Diese Rune muss ich erst entschlüsseln. Frag anders.", en = "I'll have to decipher that rune first. Ask differently." },
    { de = "Hm. Das Wort kenne ich nicht. Noch nicht.", en = "Hm. I don't know that word. Not yet." },
    { de = "Bei den Leylinien, das war Kauderwelsch. Oder Zwergisch. /lyra hilfe hilft.", en = "By the ley lines, that was gibberish. Or Dwarvish. /lyra help helps." },
  } },
}
