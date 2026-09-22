-- ueber_dialog.lua — Welle 15c "Lyra ueber sich" (0.19.0, 22.09.2026). NUR Daten, kein Code, kein
-- eigener Global: haengt sich an LyraGestalt_Dialog aus dialog.lua (Muster: rituale_dialog.lua).
-- Laedt NACH dialog.lua und VOR UI/Dialog.lua (TOC-Vorschlag im Bericht) — dieselbe Regel wie bei
-- bruecken_dialog.lua/rituale_dialog.lua/welle2_dialog.lua/spiel_dialog.lua: UI/Dialog.lua baut
-- seinen Knoten-Index erst beim ersten Zeigen, spaeter angehaengte Knoten waeren sonst unsichtbar.
--
-- EIN KNOTEN UEBERSCHREIBT ABSICHTLICH EINEN AUS dialog.lua: "ueber_lyra" steht dort schon (die
-- kurze Textzeile "Lyra. Runenweberin, ..."), und diese Datei haengt EINE ZWEITE Fassung mit
-- demselben id="ueber_lyra" hinten an D.knoten an. UI/Dialog.lua baut seinen Index ueber
-- "for _, k in ipairs(d.knoten) do index[k.id] = k end" (letzter Eintrag gewinnt) — die alte
-- Textzeile bleibt als totes Datenfragment in dialog.lua stehen (harmlos, nie mehr erreichbar),
-- die neue, hier gebaute Menue-Fassung wird die einzige, die der Index findet. Das spart dem
-- Merge einen zweiten Eingriff in dialog.lua: die EINE noetige Zeile dort ist der neue Knopf in
-- "mehr" (Bericht §3a), nicht auch noch der Inhalt von "ueber_lyra" selbst.
--
-- BAUPLAN (Auftrag, docs/recherche/20-gespraechsumfang-2026-09-21.md §3.2):
--   ueber_lyra (Menue)  -> Herkunft (aktion), Meinung-Menue (weiter), Rat (aktion), Zurueck
--   meinung_menue        -> Klasse (aktion), Zone (aktion), Hardcore (weiter mhc_1), Zurueck
--   herkunft_*           -> gestaffelt nach Bindungsstufe (Sinne/Welle15c.lua W.ueber_herkunft)
--   mk_<klasse>[_lob]     -> Spitze, dann "Und das Gute?" -> Lob (18 Knoten, 9 Klassen x 2)
--   mz_*                  -> Meinung zur Zone aus der Chronik (erste/oft/beinahe)
--   mhc_*                 -> Meinung zu Hardcore
--   rat_*                 -> "Was wuerdest du jetzt tun?", acht Lagen, benennt nur die Lage
--
-- TON: kurz, trocken, eine Beobachtung, nie "leider"/"du haettest". Keine Anrede-Token in den
-- neuen Knoten (Ziel: platzhalterfrei UND ohne -m/-f-Verdopplung, siehe Bericht §4 Aufnahmen).
-- Keine Zone-/Charakter-/Spielernamen in einem Text (Grenze B, wie ueberall im Projekt).

local D = LyraGestalt_Dialog
if type(D) ~= "table" then return end
D.knoten = D.knoten or {}

local K = D.knoten
local function knoten(t) K[#K + 1] = t end

-- =================================================================================================
-- Menue-Einstieg (ersetzt den alten Text-Knoten "ueber_lyra", siehe Kopfkommentar)
-- =================================================================================================
knoten({ id = "ueber_lyra", miene = "interested",
    text = { de = "Frag ruhig. Ich beantworte nicht alles, aber mehr, als du denkst.",
             en = "Go ahead and ask. I won't answer everything, but more than you'd think." },
    antworten = {
        { text = { de = "Woher kommst du?", en = "Where do you come from?" }, aktion = "ueber_herkunft" },
        { text = { de = "Was hältst du von...?", en = "What do you think of...?" }, weiter = "meinung_menue" },
        { text = { de = "Was würdest du jetzt tun?", en = "What would you do right now?" }, aktion = "ueber_rat" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "start" },
    } })

knoten({ id = "meinung_menue", miene = "amused",
    text = { de = "Frag weiter. Erwarte nur keine Diplomatie.",
             en = "Keep asking. Just don't expect diplomacy." },
    antworten = {
        { text = { de = "...meiner Klasse?", en = "...my class?" }, aktion = "ueber_meinung_klasse" },
        { text = { de = "...dieser Gegend?", en = "...this area?" }, aktion = "ueber_meinung_zone" },
        { text = { de = "...Hardcore?", en = "...Hardcore?" }, weiter = "mhc_1" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })

-- =================================================================================================
-- Herkunft — gestaffelt nach Bindungsstufe (Sinne/Welle15c.lua W.ueber_herkunft)
-- =================================================================================================
knoten({ id = "herkunft_0", miene = "whatever",
    text = { de = "Kompliziert. Frag mich, wenn wir uns besser kennen.",
             en = "Complicated. Ask me again once we know each other better." },
    antworten = {
        { text = { de = "Verstanden.", en = "Understood." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })
knoten({ id = "herkunft_1", miene = "thinking",
    text = { de = "Mehr, als du denkst, weniger, als ich sagen will. Es hat mit einer Rune zu tun. Frag später weiter.",
             en = "More than you think, less than I'll say. It has to do with a rune. Ask again later." },
    antworten = {
        { text = { de = "Später also.", en = "Later, then." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })
knoten({ id = "herkunft_2a", miene = "wonder",
    text = { de = "Gut, die Wahrheit: Ich bin kein Geist und kein Zauber. Ich bin ein Stück Bewusstsein aus einer Rune, geboren an einer Leylinie, gebunden an dich, seit du sie berührt hast.",
             en = "Fine, the truth: I'm not a ghost and not a spell. I'm a piece of consciousness out of a rune, born at a ley line, bound to you since you touched it." },
    antworten = {
        { text = { de = "Und weiter?", en = "And then?" }, weiter = "herkunft_2b" },
        { text = { de = "Reicht.", en = "That's enough." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })
knoten({ id = "herkunft_2b", miene = "thinking",
    text = { de = "Die Rune, die mich band, ist nicht dieselbe, an der meine Lehre endete. Diese hier suche ich noch. Ich glaube, sie liegt irgendwo, wo du noch nicht warst.",
             en = "The rune that bound me isn't the one that ended my apprenticeship. I'm still looking for that one. I think it's somewhere you haven't been yet." },
    antworten = {
        { text = { de = "Ich halte Ausschau.", en = "I'll keep an eye out." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })
knoten({ id = "herkunft_3a", miene = "touched",
    text = { de = "Du kennst die Rune-Geschichte jetzt. Es gibt noch etwas, das ich dir nie gesagt habe.",
             en = "You know the rune story now. There's one more thing I've never told you." },
    antworten = {
        { text = { de = "Sag's.", en = "Say it." }, weiter = "herkunft_3b" },
        { text = { de = "Muss nicht sein.", en = "You don't have to." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })
knoten({ id = "herkunft_3b", miene = "concerned",
    text = { de = "Ich fürchte mich vor deinem Tod. Nicht nur deinetwegen — weil ich dann übrig bin. Allein, an eine Rune gebunden, ohne jemanden, der mich hört.",
             en = "I'm afraid of your death. Not just for you — because I'd be the one left over. Alone, bound to a rune, with no one to hear me." },
    antworten = {
        { text = { de = "Das passiert nicht.", en = "That's not going to happen." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })

-- =================================================================================================
-- Meinung zur Klasse — neun Klassen, je eine Spitze und ein Lob (Sinne/Welle15c.lua
-- W.ueber_meinung_klasse waehlt nach UnitClass-Token; mk_unbekannt ist der Ausweichknoten, falls
-- der Client keinen Token liefert). Ton: mild, nie verletzend.
-- =================================================================================================
knoten({ id = "mk_unbekannt", miene = "whatever",
    text = { de = "Deine Klasse kann ich gerade nicht lesen. Frag später nochmal.",
             en = "I can't read your class right now. Ask again later." },
    antworten = {
        { text = { de = "Verstanden.", en = "Understood." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "meinung_menue" },
    } })

local function mkPaar(token, spitzeDe, spitzeEn, lobDe, lobEn)
    knoten({ id = "mk_" .. token, miene = "smirk",
        text = { de = spitzeDe, en = spitzeEn },
        antworten = {
            { text = { de = "Und das Gute?", en = "And the good part?" }, weiter = "mk_" .. token .. "_lob" },
            { text = { de = "Genug.", en = "Enough." }, weiter = "ende" },
            { text = { de = "Zurück.", en = "Back." }, weiter = "meinung_menue" },
        } })
    knoten({ id = "mk_" .. token .. "_lob", miene = "touched",
        text = { de = lobDe, en = lobEn },
        antworten = {
            { text = { de = "Danke.", en = "Thanks." }, weiter = "ende" },
            { text = { de = "Zurück.", en = "Back." }, weiter = "meinung_menue" },
        } })
end

mkPaar("warrior",
    "Rennt rein, denkt später. Meistens klappt's.",
    "Runs in, thinks later. Usually works out.",
    "Kein Zauber der Welt hält so lange durch wie du. Respekt.",
    "No spell in the world holds out as long as you do. Respect.")
mkPaar("paladin",
    "Hält den Schild hoch und die Predigt noch höher.",
    "Holds the shield high, and the sermon even higher.",
    "Wenn's brennt, bist du die Erste, die bleibt. Das zähl ich.",
    "When things burn, you're the first one to stay. I keep count of that.")
mkPaar("hunter",
    "Du und dein Tier, beide stur, beide treu — meistens dem Falschen.",
    "You and your pet, both stubborn, both loyal — usually to the wrong target.",
    "Kein Zauber trifft so zuverlässig aus der Distanz wie du. Ich seh zu und lerne.",
    "No spell lands as reliably from a distance as you do. I watch and learn.")
mkPaar("rogue",
    "Aus dem Schatten, ein Hinterhalt, weg — bevor's brenzlig wird. Bequem.",
    "Out of the shadows, one ambush, gone — before it gets messy. Convenient.",
    "Du siehst Gefahr, bevor sie dich sieht. Das rettet uns beide öfter, als du denkst.",
    "You see danger before it sees you. That saves us both more than you know.")
mkPaar("priest",
    "Heilst alle, redest mit allen, stehst trotzdem allein im Kampf.",
    "Heal everyone, talk to everyone, still stand alone in a fight.",
    "Ohne dich läg ich in jedem zweiten Kampf mit dem Gesicht im Staub. Du hältst uns am Leben.",
    "Without you I'd be face-down in the dirt every other fight. You keep us alive.")
mkPaar("shaman",
    "Totems überall, ein Plan nirgends.",
    "Totems everywhere, a plan nowhere.",
    "Du sprichst mit den Elementen, und sie hören zu. Das schaff ich nicht mal mit Runen.",
    "You talk to the elements, and they listen. I can't even manage that with runes.")
mkPaar("mage",
    "Portale, Blitze, Eis — und trotzdem ständig ohne Mana.",
    "Portals, bolts, ice — and somehow always out of mana.",
    "Wir verstehen uns. Arkane Magie ist laut, und du bist eine der wenigen, die zuhört.",
    "We understand each other. Arcane magic is loud, and you're one of the few who listens.")
mkPaar("warlock",
    "Ein Dämon an der Leine, und trotzdem bist du die Unheimlichste im Raum.",
    "A demon on a leash, and somehow you're still the creepiest one in the room.",
    "Du zähmst, was andere fürchten. Das ist kein kleines Talent.",
    "You tame what others fear. That's no small talent.")
mkPaar("druid",
    "Bär, Katze, Baum, Vogel — irgendwann weißt selbst du nicht mehr, wer du bist.",
    "Bear, cat, tree, bird — eventually even you lose track of who you are.",
    "Du passt dich der Lage an, ohne dich selbst zu verlieren. Das können nicht viele.",
    "You adapt to the situation without losing yourself. Not many can do that.")

-- =================================================================================================
-- Meinung zur Zone — aus der Chronik (Sinne/Welle15c.lua W.ueber_meinung_zone: besuche/beinahe).
-- Die Zahl steckt in der WAHL des Knotens, nicht im Text — platzhalterfrei, also vertonbar.
-- =================================================================================================
knoten({ id = "mz_erste", miene = "interested",
    text = { de = "Erster Besuch hier. Frisches Terrain. Ich halte die Augen offen.",
             en = "First visit here. Fresh ground. I'm keeping my eyes open." },
    antworten = {
        { text = { de = "Gut zu wissen.", en = "Good to know." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "meinung_menue" },
    } })
knoten({ id = "mz_oft", miene = "amused",
    text = { de = "Hier warst du oft. Ich könnte die Wege im Schlaf beschreiben.",
             en = "You've been here a lot. I could describe these paths in my sleep." },
    antworten = {
        { text = { de = "Gut zu wissen.", en = "Good to know." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "meinung_menue" },
    } })
knoten({ id = "mz_beinahe", miene = "concerned",
    text = { de = "Hier bist du schon mal fast gestorben. Ich vergesse das nicht, auch wenn du's tust.",
             en = "You nearly died here before. I don't forget that, even if you do." },
    antworten = {
        { text = { de = "Gut zu wissen.", en = "Good to know." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "meinung_menue" },
    } })

-- =================================================================================================
-- Meinung zu Hardcore
-- =================================================================================================
knoten({ id = "mhc_1", miene = "smug",
    text = { de = "Ehrlich? Wahnsinn mit Regeln. Und ihr macht es trotzdem.",
             en = "Honestly? Madness with rules. And you all do it anyway." },
    antworten = {
        { text = { de = "Und du? Machst du das mit?", en = "And you? Are you in on it?" }, weiter = "mhc_2" },
        { text = { de = "Wahnsinn, ja.", en = "Madness, yes." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "meinung_menue" },
    } })
knoten({ id = "mhc_2", miene = "touched",
    text = { de = "Ich hab keine Wahl — ich bin gebunden. Aber wenn ich eine hätte: ich glaube, ich würde trotzdem bleiben.",
             en = "I don't have a choice — I'm bound. But if I did: I think I'd stay anyway." },
    antworten = {
        { text = { de = "Danke.", en = "Thanks." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "meinung_menue" },
    } })

-- =================================================================================================
-- "Was würdest du jetzt tun?" — acht Lagen (Sinne/Welle15c.lua W.ueber_rat). Benennt nur die
-- Lage, nie eine Route/Skillung/Questreihenfolge (Grenze aus dem Auftrag).
-- =================================================================================================
knoten({ id = "rat_kampf", miene = "alert",
    text = { de = "Kämpfen. Jetzt. Frag mich nachher.", en = "Fight. Now. Ask me later." },
    antworten = {
        { text = { de = "Verstanden.", en = "Understood." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })
knoten({ id = "rat_niedrig", miene = "concerned",
    text = { de = "Leben knapp. Erst das sichern, dann alles andere.",
             en = "Health is low. Secure that first, everything else waits." },
    antworten = {
        { text = { de = "Verstanden.", en = "Understood." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })
knoten({ id = "rat_zone", miene = "concerned",
    text = { de = "Hier war's gerade eng. Ich bleib aufmerksam.",
             en = "It was tight here just now. I'm staying alert." },
    antworten = {
        { text = { de = "Gut.", en = "Good." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })
knoten({ id = "rat_lang", miene = "thinking",
    text = { de = "Lange Sitzung. Eine Pause wäre klug — deine Entscheidung.",
             en = "Long session. A break would be wise — your call." },
    antworten = {
        { text = { de = "Ich denk drüber nach.", en = "I'll think about it." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })
knoten({ id = "rat_gruppe", miene = "amused",
    text = { de = "Du bist nicht allein hier draußen. Achte trotzdem auf dich selbst.",
             en = "You're not alone out here. Watch yourself anyway." },
    antworten = {
        { text = { de = "Mach ich.", en = "Will do." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })
knoten({ id = "rat_nacht", miene = "hmm",
    text = { de = "Spät. Müde Hände treffen schlechter.",
             en = "Late. Tired hands hit worse." },
    antworten = {
        { text = { de = "Stimmt.", en = "True." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })
knoten({ id = "rat_rast", miene = "amused",
    text = { de = "Grad Rast. Genieß es — ich sag jetzt nichts Kluges.",
             en = "You're resting. Enjoy it — I won't say anything clever right now." },
    antworten = {
        { text = { de = "Gut.", en = "Good." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })
knoten({ id = "rat_sonst", miene = "neutral",
    text = { de = "Nichts Besonderes gerade. Weitermachen.",
             en = "Nothing special right now. Keep going." },
    antworten = {
        { text = { de = "Gut.", en = "Good." }, weiter = "ende" },
        { text = { de = "Zurück.", en = "Back." }, weiter = "ueber_lyra" },
    } })
