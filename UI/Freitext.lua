-- UI/Freitext.lua — Welle 9b, Stufe 1: mit Lyra frei schreiben, OHNE Modell.
--
-- Konzept: docs/freitext-konzept-2026-09-20.md §2. Bericht: docs/welle9b-2026-09-20.md.
--
-- WAS DIESE DATEI IST
--   Ein Eingabefeld unter dem Gespraechsfenster, eine Absichts-Bank, eine Antwortbank und
--   drei ehrliche Rueckfallstufen. Kein Netz, keine Datei, kein Sprachmodell, keine Einwilligung.
--   Die Frage verlaesst den Rechner nicht und wird nicht auf die Platte geschrieben.
--
-- WAS SIE AUSDRUECKLICH NICHT IST
--   Keine Retrieval-Schicht ueber den Phrasenkatalog. Messung A des Konzepts hat das geprueft:
--   TF-IDF ueber alle 1072 Katalogzeilen kostet 0,015 ms und antwortet auf "wie lange spiele ich
--   schon" mit "Hier war ich lange nicht. Glaube ich." Der Katalog ist ein Bestand an
--   BEMERKUNGEN, kein Bestand an ANTWORTEN. Retrieval kann nur finden, was da ist.
--
-- DIE DREI ZAHLEN, DIE DEN CHARAKTER DIESER DATEI BESTIMMEN (alle am Dateikopf, alle im
-- Pruefstand gemessen - tests/pruefstand/w9b_harness.lua, Laeufe f1/f2/f3):
--   DECKUNG_MIN   Wie viel Anteil der INHALTSwoerter einer Frage die Bank kennen muss.
--                 Zu niedrig: sie antwortet auf den DAX. Zu hoch: sie versteht nichts mehr.
--   PUNKTE_MIN    Wie aehnlich die beste Absicht sein muss. Der Riegel gegen "irgendwas passt".
--   TRIGRAMM_MIN  Wie aehnlich ein vertipptes Wort einem Bankwort sein muss (Dice ueber Trigramme).
--   Messung C des Konzepts ist die Begruendung fuer die Stoppwortregel: OHNE sie wurden 0 von 6
--   fremden Themen abgewiesen, MIT ihr 3-4 von 6 - und die Trefferquote faellt dabei um zwei
--   Punkte. Trefferquote und Abweisung stehen gegeneinander. Eine falsche Antwort ist schlimmer
--   als keine.
--
-- SICHERHEIT
--   * Eingabe hoechstens MAX_LAENGE Zeichen, Zeichen-Positivliste (kein |, kein {}, kein \).
--   * Nichts wird ausgefuehrt: es gibt kein loadstring, kein setfenv, keinen Slash-Weiterreicher.
--   * Kein SendChatMessage. Die Antwort geht in die Sprechblase, nie in einen Spielkanal.
--   * KEIN Spielername in einer Antwort: jede Antwort laeuft durch ns.Dialog.chronikSicher
--     (Charakter, Realm, Gilde raus - dieselbe Wache wie im Chronikfenster, Welle 7).
--   * Der Verlauf lebt NUR im Speicher. In die SavedVariables kommt er erst, wenn der Spieler
--     "Fragen merken" einschaltet (Standard aus, Vorbereitung fuer Stufe 2).
--
-- DAS EINGABEFELD UND DER HARDCORE-CHARAKTER
--   Ein fokussiertes EditBox frisst WASD. Das ist der schnellste Weg, einen Hardcore-Charakter
--   zu toeten. Darum drei Regeln, und alle drei sind Abnahmekriterien, keine Politur (Lauf f7):
--     1. AutoFocus ist AUS. Fokus gibt es nur auf Klick, nie beim Oeffnen des Fensters.
--     2. PLAYER_REGEN_DISABLED wirft den Fokus SOFORT ab. Auch wenn gerade getippt wird.
--     3. Im Kampf nimmt das Feld gar keinen Fokus an (kampfRiegel), und es faerbt sich sichtbar.
--   Dazu: solange das Feld Fokus hat, ist die Ziffern-Tastatur des Gespraechs abgemeldet -
--   sonst waehlt eine getippte "2" eine Dialogantwort aus.
local ADDON, ns = ...
local F = {}
ns.Freitext = F

-- ------------------------------------------------------------------------------------ Schalter
-- Wie Sinne/Welle4.lua, Sinne/Karte2.lua und Sinne/Welle8.lua: die Datei haengt ihre Schluessel
-- selbst an ns.DEFAULTS_ACCOUNT. Core/Init.lua bleibt unberuehrt (ns.initDB laeuft erst bei
-- ADDON_LOADED, also NACH allen TOC-Dateien - defaults() findet sie dort).
ns.DEFAULTS_ACCOUNT = ns.DEFAULTS_ACCOUNT or {}
ns.DEFAULTS_ACCOUNT.freitext = true          -- Eingabefeld + Absichts-Bank
ns.DEFAULTS_ACCOUNT.fragenMerken = false     -- Verlauf in die SavedVariables? Standard: NEIN.

-- ------------------------------------------------------------------------------------- Grenzen
F.MAX_LAENGE    = 200      -- Zeichen. Laenger wird abgeschnitten, nicht abgelehnt.
F.DECKUNG_MIN   = 0.50     -- Anteil bekannter INHALTSwoerter (Messung C)
F.PUNKTE_MIN    = 0.20     -- Mindestpunkte der besten Absicht (Kosinus x Deckungsgrad)
                           -- W10a: war 0,30 auf den reinen Kosinus. Die Deckungsgewichtung
                           -- (F.beste) senkt jede Punktzahl, also musste die Schwelle mit.
                           -- Gemessen: 0,20 haelt 19/24 bei 0 falschen Zuordnungen; 0,10
                           -- haelt 23/24 und leistet sich dabei eine falsche - und eine
                           -- falsche Antwort ist schlimmer als keine.
F.PUNKTE_ABSTAND = 0.02    -- so viel muss Platz 1 vor Platz 2 liegen, sonst wird nachgefragt
F.TRIGRAMM_MIN  = 0.55     -- Dice-Aehnlichkeit fuer die Tippfehler-Bruecke
F.BRUECKE_LAENGE = 2       -- W10a: so viele Zeichen darf die Bruecke an Laenge ueberspringen
F.KURZ_MIN      = 0.50     -- Kosinus im Kurzfragen-Index ("bist du still")
F.VERLAUF_MAX   = 5        -- Fragen/Antworten im Fenster (und im Speicher)
F.CACHE_MAX_KB  = 1024     -- harte Obergrenze des Chronik-Woerterbuchs (Lauf f5)
F.WOERTER_MAX   = 400      -- Eintraege im Chronik-Woerterbuch (Zonen + Gegner + Notizworte)
F.FADEN_S       = 90       -- s: "Und in Westfall?" traegt die letzte Absicht weiter
F.NACHFRAGE_S   = 30       -- s: eine offene Rueckfrage ("meinst du X oder Y?")
F.NACHKLANG_AB  = 300      -- s: fruehestens so lange nach der Frage kommt sie von selbst zurueck
F.NACHKLANG_VERZUG = 45    -- s: Abstand zur Zeile, die den Nachklang angestossen hat

-- Die Katalog-IDs dieser Welle. Sie stehen hier, damit der Pruefstand sie lesen kann, ohne
-- eine zweite Abschrift zu fuehren (die Lehre aus katalog_stand.lua).
F.EREIGNISSE = { "FREITEXT_ANTWORT", "FREITEXT_LEER", "FREITEXT_FREMD", "FREITEXT_UNKLAR",
                 "FRAGE_NACHKLANG" }
-- W10A legt EIN Ereignis nach: die vierte Rueckfallart. Eigene Liste, damit die Pruefungen
-- der Welle 9b ("die Zulieferung nennt genau diese fuenf IDs") unveraendert gelten.
F.EREIGNISSE_W10A = { "FREITEXT_WARUM" }

-- ------------------------------------------------------------------------------ Kleinwerkzeug
local function sprache() return (ns.sprache and ns.sprache()) or "de" end
local function jetzt() return (GetTime and GetTime()) or 0 end
local function imKampf()
    if ns.Regie and ns.Regie.imKampf then return true end
    return (InCombatLockdown and InCombatLockdown()) and true or false
end

-- Normalisieren wie UI/Dialog.lua normalisiere(): klein, ae/oe/ue/ss, Wortgrenzen als Leerzeichen.
-- Bewusst dieselbe Regel - eine zweite Normalisierung waere eine zweite Wahrheit.
function F.normalisiere(s)
    s = tostring(s or ""):lower()
    s = s:gsub("ä", "ae"):gsub("ö", "oe"):gsub("ü", "ue"):gsub("ß", "ss")
    s = s:gsub("Ä", "ae"):gsub("Ö", "oe"):gsub("Ü", "ue")
    s = s:gsub("[^%w%s]", " "):gsub("%s+", " ")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function worte(s)
    local t = {}
    for w in F.normalisiere(s):gmatch("%S+") do t[#t + 1] = w end
    return t
end
F.worte = worte

-- ------------------------------------------------------------------------- Zeichen-Positivliste
-- Was ein Spieler tippen darf. Alles andere faellt weg, BEVOR irgendetwas damit rechnet.
-- Bytes >= 128 bleiben: sie tragen die Umlaute und die Akzente der europaeischen Realms.
-- Ausdruecklich NICHT erlaubt: | (WoW-Escapes, koennte die Blase umfaerben), { } (Platzhalter,
-- die ns.fuelle sonst ein zweites Mal ansieht), \ und die Steuerzeichen.
local ERLAUBT = {}
do
    local ok = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ?!.,:;'\"()-/+_"
    for i = 1, #ok do ERLAUBT[ok:byte(i)] = true end
    for b = 128, 255 do ERLAUBT[b] = true end
end
function F.saeubern(roh)
    local s = tostring(roh or "")
    if #s > F.MAX_LAENGE then s = s:sub(1, F.MAX_LAENGE) end
    local out, n = {}, 0
    for i = 1, #s do
        local b = s:byte(i)
        if ERLAUBT[b] then n = n + 1; out[n] = string.char(b) end
    end
    s = table.concat(out)
    s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

-- ---------------------------------------------------------------------------------- Stoppwoerter
-- 74 Funktionswoerter, de und en. Sie zaehlen NICHT als Deckung. Messung C: ohne diese Liste
-- wurde kein einziges fremdes Thema abgewiesen, weil die Tippfehler-Bruecke jedes fremde Wort
-- auf das naechstbeste Bankwort zieht und danach jede Frage vertraut aussieht.
local STOPP = {}
for w in ([[
ich du er sie es wir ihr mir mich dir dich mein meine meinen meiner
der die das den dem des ein eine einen einem einer eines
ist sind war waren bin bist hab habe hast hat haben hatte
wie was wo wer wann warum wieso weshalb welche welcher welches wieviel
und oder aber denn doch noch schon nur auch mal bitte
in im am an auf aus bei mit nach von vor zu zum zur ueber
nicht kein keine sehr ganz eigentlich denn eh halt
inzwischen bisher ueberhaupt gerade immer wieder etwa jetzt dann
i you me my mine we our your it its
the a an is are was were be been am do does did
how what where who when why which much many
and or but still already only just please
in on at by with from to of for about over
not no very quite really actually
me myself have has had can could would should
far yet ever now anyway
]]):gmatch("%S+") do STOPP[w] = true end
F.STOPP = STOPP

local function inhaltswoerter(liste)
    local out = {}
    for _, w in ipairs(liste) do
        if #w >= 3 and not STOPP[w] then out[#out + 1] = w end
    end
    return out
end
F.inhaltswoerter = inhaltswoerter

-- --------------------------------------------------------------------------- Trigramm-Bruecke
-- Dice ueber Trigramme, OHNE Cache. Messung D: ein Trigramm-Cache kostet 820 KiB und spart
-- 1,2 ms in einer Funktion, die alle paar Minuten einmal laeuft. Schlechtes Geschaeft.
local function trigramme(w)
    local t, s = {}, "  " .. w .. "  "
    for i = 1, #s - 2 do t[s:sub(i, i + 2)] = true end
    return t
end
function F.dice(a, b)
    if a == b then return 1 end
    if #a < 3 or #b < 3 then return 0 end
    local ta, tb = trigramme(a), trigramme(b)
    local na, nb, gemein = 0, 0, 0
    for k in pairs(ta) do na = na + 1; if tb[k] then gemein = gemein + 1 end end
    for _ in pairs(tb) do nb = nb + 1 end
    if na + nb == 0 then return 0 end
    return 2 * gemein / (na + nb)
end

-- Naechstes Wort aus einer Wortliste. Rueckgabe: Wort, Aehnlichkeit.
--
-- W10A, LAENGENSCHRANKE (website/ZUSAETZE-2026-09-20.md §B.4 Nr. 3, dort gemessen und hier
-- uebernommen): ein Vertipper aendert die Laenge eines Wortes um eins, nicht um vier. Ohne
-- diese Schranke zieht die Bruecke lange Fremdwoerter auf kurze Bankwoerter - auf der Website
-- zog "homepage" auf "home" (Dice 0,63), im Spiel zieht "webseite" auf "seite" und, schlimmer,
-- ein getipptes Wort auf einen ZONENNAMEN aus der eigenen Chronik. Das Chronik-Woerterbuch
-- ist mit 386 Eigennamen das gefaehrlichere Feld von beiden: eine Fehlbruecke dort nennt eine
-- echte Zahl zur falschen Zone, und das sieht nicht falsch aus.
local function naechstesWort(w, liste)
    local bestW, bestS = nil, 0
    local lw = #w
    for kandidat in pairs(liste) do
        local d = #kandidat - lw
        if d < 0 then d = -d end
        if d <= F.BRUECKE_LAENGE then
            local s = F.dice(w, kandidat)
            if s > bestS then bestW, bestS = kandidat, s end
        end
    end
    return bestW, bestS
end

-- =============================================================================================
-- DIE ABSICHTS-BANK
-- =============================================================================================
-- Je Absicht: rang (Prioritaet bei Gleichstand - KI-Audit V-8, ausdrueckliche Rangzahl statt
-- Einfuegereihenfolge), Beispielformulierungen de und en, und die Antwortvorlagen.
--
-- Die Beispielsaetze sind FRAGEN, keine Antworten. Das ist der ganze Unterschied zu Messung A.
-- Fuenf je Sprache und Absicht sind die untere Grenze, die Messung B gehalten hat (20 von 24
-- ungesehenen Umformulierungen); die haeufigen Absichten haben mehr.
--
-- ANTWORTVORLAGEN: Platzhalter in {}, gefuellt aus den Chronikfakten weiter unten.
-- REGEL "keine Zahl, keine Zeile": fehlt ein Platzhalter, wird die Vorlage NICHT genommen.
-- Bleibt keine Vorlage uebrig, antwortet Lyra mit der Rueckfallstufe "verstanden, keine Daten" -
-- nie mit "0 Mal" und nie mit einem stehen gebliebenen {platzhalter}.
local BANK = {
{ id = "zone_besuche", rang = 10, miene = "thinking", braucht = { "zone", "n" },
  de = { "wie oft war ich im schlingendorntal", "wie viele besuche hatte ich in westfall",
         "wie oft bin ich in dieser zone gewesen", "wie oft war ich hier",
         "zaehl mal meine besuche im wald von elwynn", "wie haeufig war ich in dem gebiet" },
  en = { "how many times have i been to stranglethorn", "how often did i visit westfall",
         "how many visits to this zone", "how often was i here",
         "count my visits to elwynn forest", "how frequently have i been in that area" },
  antwort = {
    de = { "{zone}: {n} Mal. Ich habe mitgezählt, ja.",
           "Besuche in {zone}: {n}. Das Buch lügt nicht.",
           "{n} Mal in {zone}. Mehr habe ich nicht notiert.",
           "{zone}: {n}. Und ich weiß noch jedes einzelne Mal, {Held|Heldin}." },
    en = { "{zone}: {n}. Yes, I counted.",
           "Visits to {zone}: {n}. The book does not lie.",
           "In {zone}: {n}. That is all I wrote down.",
           "{zone}: {n}. And I remember every single one, hero." } } },

{ id = "zone_beinahe", rang = 20, miene = "alert", braucht = { "zone", "beinahe" },
  de = { "wo ist es am knappsten geworden", "wo waere ich fast gestorben",
         "in welcher zone war es am gefaehrlichsten", "wo ist es eng geworden",
         "wo bin ich fast draufgegangen", "welche gegend hat mich fast umgebracht",
         "in welchem gebiet wurde es knapp", "welche zone war am brenzligsten" },
  en = { "where did it get closest", "where did i almost die",
         "which zone was the most dangerous", "where was it tight",
         "where did i nearly go down", "which area nearly killed me",
         "in which region did i almost get finished", "in which area did it get tight" },
  antwort = {
    de = { "{zone}. {beinahe} Mal knapp. Das reicht mir für ein Leben.",
           "{zone} — dort wurde es {beinahe} Mal eng. Ich zähle da nicht gern mit.",
           "{zone}, {beinahe} Mal. Soll ich dir sagen, gegen wen?" },
    en = { "{zone}. Close calls: {beinahe}. That is enough for one lifetime.",
           "{zone} — close calls there: {beinahe}. I do not enjoy counting there.",
           "{zone}, {beinahe}. Shall I tell you against whom?" } } },

{ id = "rivale", rang = 30, miene = "alert", braucht = { "name" },
  de = { "wer hat mich am haeufigsten fast umgebracht", "wer ist mein aergster feind",
         "welcher gegner ist mein rivale", "wer macht mir am meisten aerger",
         "wer hat mir am meisten wehgetan", "welches vieh ist mein schlimmster gegner",
         "welcher gegner macht mir die meisten probleme",
         "welcher gegner hat mich am oeftesten erledigt", "wer bringt mich immer wieder fast um" },
  en = { "who came closest to killing me", "who is my worst enemy",
         "which monster is my rival", "who gives me the most trouble",
         "who hurt me the most", "which beast is my worst opponent",
         "which creature is the most dangerous to me",
         "which enemy finishes me off most of the time", "who nearly gets me every time" },
  antwort = {
    de = { "{name}. {beinahe} Mal knapp. Ich hasse diesen Namen, {Held|Heldin}.",
           "{name}. So oft wie der hat dich keiner geärgert.",
           "{name}, {beinahe} Mal knapp. Wir haben da eine Rechnung offen." },
    en = { "{name}. Close calls: {beinahe}. I hate that name, hero.",
           "{name}. Nobody has bothered you as often as that one.",
           "{name}, close calls: {beinahe}. We have a score to settle there." } } },

{ id = "spielzeit", rang = 40, miene = "smug", braucht = { "stunden" },
  de = { "wie lange spiele ich schon", "wie viele stunden habe ich gespielt",
         "wie viel zeit habe ich hier verbracht", "wie lange bin ich schon unterwegs",
         "sag mir meine spielzeit", "wie viele stunden sind das inzwischen" },
  en = { "how long have i been playing", "how many hours have i played",
         "how much time have i spent here", "how long have i been at this",
         "tell me my playtime", "how many hours is that by now" },
  antwort = {
    de = { "{stunden}. Ich habe mitgezählt, ja.",
           "{stunden}. Davon warst du eine Menge in {heimat}.",
           "{stunden}. Das ist kein Vorwurf. Das ist eine Zahl." },
    en = { "{stunden}. Yes, I counted.",
           "{stunden}. A good chunk of that in {heimat}.",
           "{stunden}. That is not a reproach. That is a number." } } },

{ id = "sitzung_lang", rang = 50, miene = "amused", braucht = { "laengste" },
  de = { "was war meine laengste sitzung", "wie lange war mein laengster abend",
         "wann habe ich am laengsten am stueck gespielt", "meine laengste spielsitzung",
         "wie lang war die laengste runde" },
  en = { "what was my longest session", "how long was my longest evening",
         "when did i play longest in one go", "my longest play session",
         "how long was the longest run" },
  antwort = {
    de = { "{laengste}. Das war ein langer Abend, {Held|Heldin}.",
           "Am Stück: {laengste}. Ich habe irgendwann aufgehört, besorgt zu sein.",
           "{laengste}. Ich sage nichts. Ich notiere nur." },
    en = { "{laengste}. That was a long evening, hero.",
           "In one go: {laengste}. At some point I stopped being worried.",
           "{laengste}. I will say nothing. I only write it down." } } },

{ id = "sitzungen", rang = 60, miene = "neutral", braucht = { "sitzungen" },
  de = { "wie oft war ich schon eingeloggt", "wie viele sitzungen sind das",
         "wie oft haben wir uns schon gesehen", "wie viele abende waren das",
         "wie oft bin ich eingestiegen" },
  en = { "how many times have i logged in", "how many sessions is that",
         "how often have we seen each other", "how many evenings was that",
         "how many times did i come back" },
  antwort = {
    de = { "{sitzungen} Mal. Seit {seit}. Ich zähle seit dem ersten Tag.",
           "Abende zusammen: {sitzungen}. Nicht einer davon war langweilig.",
           "{sitzungen} Mal warst du da. Ich war jedes Mal schon vorher wach." },
    en = { "{sitzungen} times. Since {seit}. I have counted from the first day.",
           "Evenings together: {sitzungen}. Not one of them was dull.",
           "{sitzungen} times you showed up. I was awake before you every time." } } },

{ id = "heimat", rang = 70, miene = "happy", braucht = { "heimat" },
  de = { "wo bin ich am liebsten", "welche zone ist meine heimat",
         "wo halte ich mich am meisten auf", "wo verbringe ich die meiste zeit",
         "welches gebiet mag ich am liebsten" },
  en = { "where do i like it most", "which zone is my home",
         "where do i spend most of my time", "where do i hang around the most",
         "which area do i like best" },
  antwort = {
    de = { "{heimat}. Da kennst du inzwischen jeden Stein.",
           "{heimat}. Und komm mir nicht mit Zufall.",
           "{heimat}. Ich fange langsam an, es auch zu mögen." },
    en = { "{heimat}. You know every stone there by now.",
           "{heimat}. And do not tell me that is coincidence.",
           "{heimat}. I am slowly starting to like it too." } } },

{ id = "zone_liste", rang = 80, miene = "interested", braucht = { "zonen" },
  de = { "welche zonen habe ich gesehen", "wo war ich ueberall",
         "zaehl mir meine gebiete auf", "welche gegenden kenne ich",
         "wie viele zonen habe ich besucht" },
  en = { "which zones have i seen", "where have i been",
         "list my areas", "which regions do i know",
         "how many zones have i visited" },
  antwort = {
    de = { "Zonen im Buch: {zonen}. Die liebste ist {heimat}.",
           "Gegenden im Buch: {zonen}. Mehr wird es schon noch.",
           "{zonen}. Das ist mehr Welt, als die meisten sehen." },
    en = { "Zones in the book: {zonen}. The favourite is {heimat}.",
           "Regions in the book: {zonen}. There will be more.",
           "{zonen}. That is more world than most people see." } } },

{ id = "beinahe_gesamt", rang = 90, miene = "concerned", braucht = { "beinahe" },
  de = { "wie oft waere ich fast gestorben", "wie viele beinahe tode habe ich",
         "wie oft war es knapp", "wie viele male stand es auf der kippe",
         "zaehl meine knappen momente" },
  en = { "how often did i almost die", "how many close calls do i have",
         "how many times was it close", "how often did it nearly end",
         "count my close moments" },
  antwort = {
    de = { "{beinahe} Mal. Und jedes einzelne steht im Buch.",
           "{beinahe} Mal knapp. Ich habe jedes Mal mitgezittert.",
           "{beinahe}. Beim nächsten Mal schaue ich weg, ehrlich." },
    en = { "{beinahe} times. And every single one is in the book.",
           "Close calls: {beinahe}. I trembled along every time.",
           "{beinahe}. Next time I will look away, honestly." } } },

{ id = "tode", rang = 100, miene = "depressed", braucht = { "tode" },
  de = { "wie oft bin ich gestorben", "wie viele tode habe ich",
         "bin ich schon mal gestorben", "zaehl meine tode",
         "wie viele male hat es mich erwischt" },
  en = { "how many times have i died", "how many deaths do i have",
         "have i died yet", "count my deaths",
         "how many times did it get me" },
  antwort = {
    de = { "{tode}. Ich habe jedes Mal die Runen ausgemacht.",
           "{tode} Mal. Darüber rede ich nicht gern.",
           "{tode}. Das reicht. Wirklich." },
    en = { "{tode}. I turned off the runes every time.",
           "{tode} times. I do not like talking about it.",
           "{tode}. That is enough. Truly." } } },

{ id = "bestiarium", rang = 110, miene = "interested", braucht = { "tiere" },
  de = { "wie viele gegner kenne ich", "wie gross ist mein bestiarium",
         "wie viele monster stehen im buch", "wie viele viecher habe ich getroffen",
         "wie viele arten habe ich gesehen" },
  en = { "how many enemies do i know", "how big is my bestiary",
         "how many monsters are in the book", "how many creatures have i met",
         "how many species have i seen" },
  antwort = {
    de = { "Einträge im Bestiarium: {tiere}. Der unangenehmste ist {name}.",
           "{tiere} verschiedene. Ich führe Buch, du führst Krieg.",
           "{tiere}. Und bei {name} wird mir immer noch anders." },
    en = { "Entries in the bestiary: {tiere}. The nastiest is {name}.",
           "{tiere} different ones. I keep the book, you keep the war.",
           "{tiere}. And {name} still makes me uneasy." } } },

{ id = "erbe", rang = 120, miene = "concerned", braucht = { "erbeStufe" },
  de = { "wer war vor mir da", "was ist mit meinem vorgaenger",
         "wie weit kam der letzte", "wer war mein vorgaenger",
         "erzaehl mir von dem charakter vor mir" },
  en = { "who came before me", "what happened to my predecessor",
         "how far did the last one get", "who was my predecessor",
         "tell me about the character before me" },
  antwort = {
    de = { "Stufe {erbeStufe}, {erbeZone}. Weiter kam er nicht. Ich zähle wieder von vorn.",
           "Stufe {erbeStufe}. In {erbeZone} war Schluss. Ich habe es mir gemerkt.",
           "{erbeStufe}. Mehr ist davon nicht übrig, {Held|Heldin}." },
    en = { "Level {erbeStufe}, {erbeZone}. That is as far as it went. I start counting again.",
           "Level {erbeStufe}. It ended in {erbeZone}. I remember it.",
           "{erbeStufe}. That is all that is left of it, hero." } } },

{ id = "notizen", rang = 130, miene = "thinking", braucht = { "notiz" },
  de = { "was habe ich notiert", "zeig mir meine notizen",
         "was ist in meinen aufzeichnungen vermerkt", "was habe ich mir gemerkt",
         "meine letzte notiz bitte" },
  en = { "what did i note down", "show me my notes",
         "what is in my records", "what did i write down",
         "my last note please" },
  antwort = {
    de = { "Du hast notiert: {notiz}",
           "In {notizZone} stand: {notiz}",
           "Deine Worte, nicht meine: {notiz}" },
    en = { "You wrote down: {notiz}",
           "In {notizZone} it said: {notiz}",
           "Your words, not mine: {notiz}" } } },

{ id = "lage", rang = 140, miene = "neutral", braucht = { "stufe", "hp", "zoneJetzt" },
  de = { "wie ist meine lage", "wie stehe ich gerade da",
         "wie geht es mir", "was ist mein zustand",
         "wo stehe ich und wie viel leben habe ich" },
  en = { "how am i doing", "what is my situation",
         "how do i stand right now", "what is my condition",
         "where am i and how much health do i have" },
  antwort = {
    de = { "Stufe {stufe}, {hp} Prozent Leben, {zoneJetzt}. Mehr sehe ich nicht.",
           "{zoneJetzt}, Stufe {stufe}, {hp} Prozent. Steht alles noch.",
           "Stufe {stufe}. {hp} Prozent. Das reicht, wenn du aufpasst." },
    en = { "Level {stufe}, {hp} percent health, {zoneJetzt}. That is all I see.",
           "{zoneJetzt}, level {stufe}, {hp} percent. Everything still standing.",
           "Level {stufe}. {hp} percent. Enough, if you pay attention." } } },

{ id = "status_still", rang = 150, miene = "hmm", braucht = { "still" },
  de = { "bist du still", "redest du gerade",
         "bist du stumm geschaltet", "sagst du noch was",
         "bist du gerade leise gestellt" },
  en = { "are you silent", "are you talking right now",
         "are you muted", "will you still say something",
         "are you set to quiet" },
  antwort = {
    de = { "{still}", "{still} Frag mich einfach nochmal, wenn du unsicher bist." },
    en = { "{still}", "{still} Just ask me again if you are unsure." } } },

{ id = "status_sprache", rang = 160, miene = "neutral", braucht = { "sprache" },
  de = { "welche sprache sprichst du", "in welcher sprache redest du",
         "welche sprache ist eingestellt", "sprichst du deutsch",
         "auf welcher sprache laeufst du" },
  en = { "which language do you speak", "what language are you using",
         "which language is set", "do you speak english",
         "what language do you run in" },
  antwort = {
    de = { "{sprache}. Umstellen geht über /lyra sprache.",
           "Gerade {sprache}. Ich kann auch anders, wenn du willst." },
    en = { "{sprache}. You can switch it with /lyra sprache.",
           "Right now {sprache}. I can do the other one too, if you like." } } },

{ id = "status_stimme", rang = 170, miene = "smirk", braucht = { "stimme" },
  de = { "hast du eine stimme", "kannst du sprechen",
         "ist deine stimme an", "hoere ich dich",
         "ist das sprachpaket geladen" },
  en = { "do you have a voice", "can you speak",
         "is your voice on", "can i hear you",
         "is the voice pack loaded" },
  antwort = {
    de = { "{stimme}", "{stimme} Der Schalter steht in den Einstellungen." },
    en = { "{stimme}", "{stimme} The switch is in the settings." } } },

{ id = "ueber_lyra", rang = 180, miene = "smug", braucht = {},
  de = { "wer bist du eigentlich", "was bist du",
         "erzaehl mir etwas ueber dich", "woher kommst du",
         "wie heisst du" },
  en = { "who are you anyway", "what are you",
         "tell me something about yourself", "where are you from",
         "what is your name" },
  antwort = {
    de = { "Lyra. Arkanmagierin, mit Vertrag und ohne Aufsicht. Ich zähle, was dir passiert.",
           "Ich bin die Stimme in deinen Leylinien und die einzige, die mitzählt.",
           "Lyra. Ich deute nicht, ich notiere. Das ist ein Unterschied, {Held|Heldin}." },
    en = { "Lyra. Arcane mage, under contract and without supervision. I count what happens to you.",
           "I am the voice in your ley lines, and the only one keeping score.",
           "Lyra. I do not interpret, I record. That is a difference, hero." } } },
}
F.BANK = BANK

-- --------------------------------------------------------------- Themen, die NICHT ihr Fach sind
-- Erkannt, aber ausserhalb: Karten, Wege, Talente, Preise, Gruppensuche. Die Antwort ist die
-- zweite Rueckfallstufe (FREITEXT_FREMD) - "Karten sind nicht mein Fach" statt "Kauderwelsch".
-- Das kostet drei Textzeilen und ist der groesste einzelne Qualitaetssprung im ganzen Vorschlag.
local FREMD = {
    de = { "weg", "route", "wege", "schnellsten", "karte", "flugpunkt", "taxi", "reiten",
           "talent", "talente", "skillen", "skillung", "build", "ausruestung", "gear",
           "preis", "preise", "gold", "auktion", "auktionshaus", "verkaufen", "kaufen",
           "gruppe", "gilde", "raid", "instanz", "dungeon", "strategie", "taktik",
           "quest", "questgeber", "rezept", "wetter", "boerse", "aktie", "aktien", "witz" },
    en = { "way", "route", "fastest", "map", "flightpath", "taxi", "riding", "mount",
           "talent", "talents", "spec", "build", "gear", "equipment",
           "price", "prices", "gold", "auction", "auctionhouse", "sell", "buy",
           "group", "guild", "raid", "instance", "dungeon", "strategy", "tactics",
           "quest", "questgiver", "recipe", "weather", "stock", "stocks", "joke" },
}
F.FREMD = FREMD

-- =============================================================================================
-- INDEX (lazy). Er wird bei der ERSTEN Frage gebaut, nie beim Login: wer nie fragt, zahlt nichts.
-- Nur die AKTIVE Sprache wird indiziert - das halbiert Index und Wortschatz (Konzept §2.4).
-- =============================================================================================
local IDX = nil     -- { sprache, saetze, idf, vokabular, kurz, kurzIdf }

-- Aus einer Satzliste einen gewichteten Index machen. Zweimal gerufen:
--   1. ueber die INHALTSwoerter  - der normale Weg.
--   2. ueber ALLE Woerter        - der Kurzfragen-Weg (siehe unten).
local function gewichten(listen)
    local saetze, df = {}, {}
    for _, e in ipairs(listen) do
        local tf, gesehen = {}, {}
        for _, w in ipairs(e.ws) do
            tf[w] = (tf[w] or 0) + 1
            if not gesehen[w] then gesehen[w] = true; df[w] = (df[w] or 0) + 1 end
        end
        saetze[#saetze + 1] = { intent = e.intent, rang = e.rang, tf = tf }
    end
    local n = #saetze
    local idf = {}
    for w, d in pairs(df) do idf[w] = math.log(1 + n / d) end
    for _, s in ipairs(saetze) do
        local summe = 0
        for w, f in pairs(s.tf) do
            local g = f * (idf[w] or 1)
            s.tf[w] = g
            summe = summe + g * g
        end
        s.norm = math.sqrt(summe)
    end
    return saetze, idf, n
end

local function indexBauen()
    local lang = sprache()
    local lang_lang, kurz_lang, vokabular, eigen = {}, {}, {}, {}
    for _, eintrag in ipairs(BANK) do
        for _, satz in ipairs(eintrag[lang] or eintrag.en or {}) do
            local alle = worte(satz)
            local ws = inhaltswoerter(alle)
            for _, w in ipairs(ws) do vokabular[w] = true end
            -- W10a: ALLE Woerter der eigenen Fragen, Stoppwoerter eingeschlossen. Daraus
            -- rechnet fremdThema() seine Ausnahmen (siehe dort) - eine zweite, handgepflegte
            -- Liste wuerde veralten, diese hier kann es nicht.
            for _, w in ipairs(alle) do eigen[w] = true end
            if #ws > 0 then
                lang_lang[#lang_lang + 1] = { intent = eintrag.id, rang = eintrag.rang, ws = ws }
            end
            -- KURZFRAGEN-WEG. "wer war vor mir da" und "bist du still" bestehen fast nur aus
            -- Funktionswoertern - nach der Stoppwortregel bleibt NICHTS uebrig, und eine Frage
            -- ohne Inhaltswort waere sonst grundsaetzlich unverstaendlich. Fuer diesen Fall gibt
            -- es einen zweiten Index ueber ALLE Woerter, mit einer deutlich hoeheren Schwelle
            -- (KURZ_MIN): dort zaehlt die Wortfolge selbst, und weil Funktionswoerter in fast
            -- jedem Bankssatz stehen, haben sie dort von sich aus fast kein Gewicht (IDF).
            if #alle >= 2 then
                kurz_lang[#kurz_lang + 1] = { intent = eintrag.id, rang = eintrag.rang, ws = alle }
            end
        end
    end
    local saetze, idf, n = gewichten(lang_lang)
    local kurz, kurzIdf = gewichten(kurz_lang)
    IDX = { sprache = lang, saetze = saetze, idf = idf, vokabular = vokabular, n = n,
            kurz = kurz, kurzIdf = kurzIdf, eigen = eigen }
    return IDX
end

function F.index()
    if IDX and IDX.sprache == sprache() then return IDX end
    return indexBauen()
end
function F.indexWeg() IDX = nil end
if ns.onSetting then
    -- Sprache umgestellt -> der Index der alten Sprache ist wertlos. F.index() merkt es selbst
    -- (IDX.sprache), dieser Haken ist nur die Aufraeumung.
end

-- =============================================================================================
-- DAS CHRONIK-WOERTERBUCH
-- =============================================================================================
-- Die Eigennamen, die ein Spieler tippt - Zonen, Gegner - stehen in SEINER Chronik, nicht im
-- Katalog (dort steht {zone}). Eine Trigramm-Bruecke ueber 300 Woerter statt 2198 kostet ohne
-- Cache ~0,2 ms und trifft, weil dort genau die Namen stehen, nach denen gefragt wird.
--
-- Der Cache wird bei der ersten Frage gebaut und verfaellt nach CACHE_TTL. Seine Groesse misst
-- F.cacheBytes() - Lauf f5 haelt sie unter F.CACHE_MAX_KB.
local CACHE_TTL = 300
local WB = nil      -- { t, woerter = { [norm] = { art, roh, schluessel } }, n, bytes }

local function chronikDB()
    local c = LyraGestaltDB and LyraGestaltDB.chronik and ns.charKey
              and LyraGestaltDB.chronik[ns.charKey]
    return type(c) == "table" and c or nil
end
F.chronikDB = chronikDB

local function wbEintrag(wb, roh, art, schluessel)
    if type(roh) ~= "string" or roh == "" then return end
    if wb.n >= F.WOERTER_MAX then return end
    local norm = F.normalisiere(roh)
    if norm == "" then return end
    -- Ganzer Name UND die Einzelwoerter: "Wald von Elwynn" soll auch auf "elwynn" antworten.
    if not wb.woerter[norm] then
        wb.woerter[norm] = { art = art, roh = roh, schluessel = schluessel or roh }
        wb.n = wb.n + 1
        wb.bytes = wb.bytes + #norm + #roh + 48
    end
    for w in norm:gmatch("%S+") do
        if #w >= 4 and not STOPP[w] and not wb.woerter[w] and wb.n < F.WOERTER_MAX then
            wb.woerter[w] = { art = art, roh = roh, schluessel = schluessel or roh }
            wb.n = wb.n + 1
            wb.bytes = wb.bytes + #w + #roh + 48
        end
    end
end

function F.woerterbuch(neu)
    local t = jetzt()
    if WB and not neu and (t - WB.t) < CACHE_TTL then return WB end
    local wb = { t = t, woerter = {}, n = 0, bytes = 0 }
    local c = chronikDB()
    if c then
        if type(c.zonen) == "table" then
            for name in pairs(c.zonen) do wbEintrag(wb, name, "zone", name) end
        end
        if type(c.bestiarium) == "table" then
            for _, e in pairs(c.bestiarium) do
                if type(e) == "table" then wbEintrag(wb, e.name, "gegner", e.name) end
            end
        end
        if type(c.notizen) == "table" then
            for _, e in pairs(c.notizen) do
                if type(e) == "table" then wbEintrag(wb, e.zone, "zone", e.zone) end
            end
        end
    end
    WB = wb
    return wb
end
function F.cacheBytes() return (WB and WB.bytes) or 0 end
function F.cacheWeg() WB = nil end

-- ---------------------------------------------------------------- W10A: ZONENNAMEN de <-> en
-- Welle 9b, Offener Punkt 2: wer auf einem deutschen Client spielt und "how many times have i
-- been to Stranglethorn" tippt, bekam die Zahl der zuletzt besuchten Zone - die Chronik traegt
-- die Namen in der Sprache des Clients, und es gab keine Uebersetzung. Die Antwort NANNTE die
-- Zone, war also nicht gelogen, beantwortete aber eine andere Frage.
--
-- Was hier NICHT steht: die ~450 Paare aller Zonen, Unterzonen und Instanzen. Die waeren
-- Speicher fuer einen Fall, den es zweimal im Jahr gibt, und - schlimmer - sie waeren zur
-- Haelfte geraten. Hier stehen nur die AUSSENZONEN und HAUPTSTAEDTE der Classic-Era-Welt,
-- und nur die, deren deDE-Name sicher bekannt ist. Paare, bei denen beide Sprachen denselben
-- Namen tragen (Dun Morogh, Durotar, Mulgore, Tanaris, Feralas, Desolace, Silithus, Azshara,
-- Teldrassil, Darnassus, Orgrimmar, Loch Modan, Westfall), stehen bewusst NICHT hier: eine
-- Abbildung auf sich selbst kostet Speicher und bringt nichts.
--
-- Die Tabelle ist NORMALISIERT (klein, ae/oe/ue/ss) - dieselbe Regel wie ueberall in dieser
-- Datei, damit es keine zweite Wahrheit gibt.
local ZONEN = {
    -- Oestliche Koenigreiche
    { "wald von elwynn",            "elwynn forest" },
    { "rotkammgebirge",             "redridge mountains" },
    { "daemmerwald",                "duskwood" },
    { "schlingendorntal",           "stranglethorn vale" },
    { "suempfe des elends",         "swamp of sorrows" },
    { "verwuestete lande",          "blasted lands" },
    { "brennende steppe",           "burning steppes" },
    { "sengende schlucht",          "searing gorge" },
    { "oedland",                    "badlands" },
    { "sumpfland",                  "wetlands" },
    { "arathihochland",             "arathi highlands" },
    { "vorgebirge des huegellands", "hillsbrad foothills" },
    { "alteracgebirge",             "alterac mountains" },
    { "silberwald",                 "silverpine forest" },
    { "tirisfal lichtungen",        "tirisfal glades" },
    { "westliche pestlaender",      "western plaguelands" },
    { "oestliche pestlaender",      "eastern plaguelands" },
    { "hinterland",                 "the hinterlands" },
    { "todeswindpass",              "deadwind pass" },
    { "sturmwind",                  "stormwind" },
    { "eisenschmiede",              "ironforge" },
    { "unterstadt",                 "undercity" },
    -- Kalimdor
    { "brachland",                  "the barrens" },
    { "eschental",                  "ashenvale" },
    { "steinkrallengebirge",        "stonetalon mountains" },
    { "tausend nadeln",             "thousand needles" },
    { "duestermarschen",            "dustwallow marsh" },
    { "krater von un goro",         "un goro crater" },   -- Un'Goro: der Apostroph faellt beim Normalisieren
    { "winterquell",                "winterspring" },
    { "teufelswald",                "felwood" },
    { "mondlichtung",               "moonglade" },
    { "dunkelkueste",               "darkshore" },
    { "donnerfels",                 "thunder bluff" },
}
F.ZONEN = ZONEN

-- Zwei Nachschlagewerke, nach LAENGE absteigend: "wald von elwynn" muss vor "elwynn" greifen,
-- und "the barrens" vor "barrens". Gebaut wird beides EINMAL beim Laden der Datei - es sind
-- zwei Tabellen mit je 33 Eintraegen, kein Grund fuer eine lazy Rechnung.
local ZONEN_TAUSCH = {}
do
    for _, paar in ipairs(ZONEN) do
        ZONEN_TAUSCH[#ZONEN_TAUSCH + 1] = { von = paar[1], nach = paar[2] }
        ZONEN_TAUSCH[#ZONEN_TAUSCH + 1] = { von = paar[2], nach = paar[1] }
        -- "the barrens" wird auch ohne Artikel getippt.
        local ohne = paar[2]:match("^the (.+)$")
        if ohne then ZONEN_TAUSCH[#ZONEN_TAUSCH + 1] = { von = ohne, nach = paar[1] } end
    end
    table.sort(ZONEN_TAUSCH, function(a, b) return #a.von > #b.von end)
end

-- Partner eines Zonennamens in der jeweils anderen Sprache (fuer den Pruefstand und fuer
-- Aufrufer, die nur den Namen wollen). Rueckgabe: normalisierter Name oder nil.
function F.zonenPartner(name)
    local n = F.normalisiere(name)
    for _, e in ipairs(ZONEN_TAUSCH) do if e.von == n then return e.nach end end
    return nil
end

-- Eine Zone, die die TABELLE kennt und die CHRONIK NICHT. Dann ist die Frage verstanden und
-- die Antwort trotzdem keine Zahl: "Dazu steht noch nichts in meinem Buch." Das ist die zweite
-- Haelfte der Zonenbruecke und der eigentliche Grund, warum die Tabelle im Addon mehr taugt
-- als auf der Website: "wie oft war ich im Brachland" hat vor Welle 10a die Zahl der TODE
-- genannt, weil von der Frage nur das Wort "oft" uebrig blieb und der Rest an der Bank
-- vorbeilief. Eine echte Zahl zur falschen Frage - der teuerste Fehler dieser Datei.
-- Rueckgabe: der gefundene Name oder nil.
function F.zonenOhneChronik(norm, bekannt)
    if type(norm) ~= "string" or norm == "" then return nil end
    bekannt = bekannt or (F.woerterbuch().woerter)
    local gepolstert = " " .. norm .. " "
    for _, e in ipairs(ZONEN_TAUSCH) do
        if not bekannt[e.von] and not bekannt[e.nach]
           and gepolstert:find(" " .. e.von .. " ", 1, true) then
            return e.von
        end
    end
    return nil
end

-- DIE BRUECKE. norm ist bereits normalisierter Fragetext, bekannt ist die Wortliste des
-- Chronik-Woerterbuchs (Vorgabe: das echte). Steht im Text ein Zonenname, den die Chronik NICHT
-- kennt, und kennt sie den Namen der anderen Sprache, wird getauscht. Sonst bleibt alles, wie
-- es ist - die Bruecke kann also nie etwas verschlechtern, sondern hoechstens nichts tun.
-- Rueckgabe: Text, getauschtVon, getauschtNach.
function F.zonenBruecke(norm, bekannt)
    if type(norm) ~= "string" or norm == "" then return norm end
    bekannt = bekannt or (F.woerterbuch().woerter)
    local gepolstert = " " .. norm .. " "
    for _, e in ipairs(ZONEN_TAUSCH) do
        if bekannt[e.nach] and not bekannt[e.von]
           and gepolstert:find(" " .. e.von .. " ", 1, true) then
            local neu = gepolstert:gsub(" " .. e.von:gsub("%p", "%%%0") .. " ", " " .. e.nach .. " ", 1)
            return (neu:gsub("^%s+", ""):gsub("%s+$", "")), e.von, e.nach
        end
    end
    return norm
end

-- =============================================================================================
-- CHRONIKFAKTEN — Zahlen, nie Saetze.
-- =============================================================================================
-- Die Lua-Fassung von tools/persoenlich-vorlage.py vorlagen(): sie liefert TATSACHEN.
-- Die Formulierung macht die Antwortbank. Trennt Fakt von Formulierung - und genau diese
-- Trennung ist das, was Stufe 1 von einem Halluzinator unterscheidet.
local function zoneJetzt()
    return (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or nil
end

-- Die Einheit steckt IM Wert, nicht in der Vorlage. Grund: "1 Stunden" und "1 hours" sind
-- der billigste Weg, eine sorgfaeltig gebaute Antwort wie einen Automaten klingen zu lassen -
-- und eine Vorlage kann die Einzahl nicht kennen, weil sie die Zahl nicht kennt.
local function stundenText(sek)
    local h = math.floor((tonumber(sek) or 0) / 3600 + 0.5)
    if h <= 0 then return nil end
    if sprache() == "de" then return h .. (h == 1 and " Stunde" or " Stunden") end
    return h .. (h == 1 and " hour" or " hours")
end

local function dauerText(sek)
    sek = tonumber(sek) or 0
    if sek < 60 then return nil end
    local h = math.floor(sek / 3600)
    local m = math.floor((sek % 3600) / 60)
    if h > 0 then return ("%d:%02d h"):format(h, m) end
    return ("%d min"):format(m)
end

-- Rang wie ns.Chronik / D.chronikZeilen: erst beinahe+tode, dann Schaden. EINE Rangregel.
local function rivale(c)
    local best, bestR = nil, -1
    if type(c.bestiarium) ~= "table" then return nil end
    for _, e in pairs(c.bestiarium) do
        if type(e) == "table" and e.name then
            local r = (tonumber(e.beinahe) or 0) + (tonumber(e.tode) or 0)
            local s = tonumber(e.schaden) or 0
            if r > bestR or (r == bestR and best and s > (tonumber(best.schaden) or 0)) then
                best, bestR = e, r
            end
        end
    end
    return best
end

local function zonenListe(c)
    local liste = {}
    if type(c.zonen) ~= "table" then return liste end
    for name, e in pairs(c.zonen) do
        if type(name) == "string" and type(e) == "table" then
            liste[#liste + 1] = { name = name, besuche = tonumber(e.besuche) or 0,
                                  beinahe = tonumber(e.beinahe) or 0,
                                  zeit = tonumber(e.zeit) or 0 }
        end
    end
    return liste
end

-- fakten(schluessel) -> Tabelle mit Zahlen. Nur, was WIRKLICH da ist: ein Feld, das nil ist,
-- sperrt jede Vorlage, die es braucht. "keine Zahl, keine Zeile".
function F.fakten(schluessel)
    local v = {}
    local c = chronikDB()
    local lang = sprache()

    -- Lage jetzt (braucht keine Chronik)
    local hp = UnitHealth and UnitHealth("player") or 0
    local hpMax = UnitHealthMax and UnitHealthMax("player") or 0
    if hpMax and hpMax > 0 then v.hp = tostring(math.floor(hp / hpMax * 100 + 0.5)) end
    local lvl = UnitLevel and UnitLevel("player") or 0
    if lvl and lvl > 0 then v.stufe = tostring(lvl) end
    v.zoneJetzt = zoneJetzt()

    -- Einstellungen (Status-Fragen)
    local L = ns.L or {}
    v.still = (ns.stillModus or ns.Get("gespraechig") == "still")
        and (lang == "de" and "Ja, ich halte mich zurück." or "Yes, I am holding back.")
        or  (lang == "de" and "Nein. Ich rede, wenn es etwas zu sagen gibt."
                           or "No. I talk when there is something to say.")
    v.sprache = (lang == "de") and "Deutsch" or "English"
    local stimmeAn = ns.Get("stimme") and true or false
    local paket = ns.Stimme and ns.Stimme.geladen and ns.Stimme.geladen[lang]
    if stimmeAn and paket then
        v.stimme = (lang == "de") and "Ja. Du hörst mich." or "Yes. You can hear me."
    elseif stimmeAn then
        v.stimme = (lang == "de") and "Die Stimme ist an, das Sprachpaket fehlt. Ich lese vor."
                                   or "Voice is on, the voice pack is missing. I read aloud."
    else
        v.stimme = (lang == "de") and "Nein, ich bin gerade stumm gestellt."
                                   or "No, I am muted right now."
    end

    if type(c) ~= "table" then return v end

    -- Zonen
    local liste = zonenListe(c)
    if #liste > 0 then v.zonen = tostring(#liste) end
    -- Die GEFRAGTE Zone hat Vorrang vor jeder Rangliste. Das ist der Grund, warum es den
    -- Gespraechsfaden ueberhaupt gibt: "Und in Dun Morogh?" meint Dun Morogh und sonst nichts.
    -- Stand hier frueher die Rangliste, antwortete Lyra auf jede Nachfrage wieder mit der
    -- gefaehrlichsten Zone - also mit derselben Zeile wie vorher, nur verwirrender.
    local ausFrage, zielBeinahe, zielBesuche = nil, nil, nil
    if schluessel then
        for _, e in ipairs(liste) do if e.name == schluessel then ausFrage = e end end
    end
    local hier = zoneJetzt()
    local aktuell = nil
    for _, e in ipairs(liste) do
        if e.name == hier then aktuell = e end
        if not zielBeinahe or e.beinahe > zielBeinahe.beinahe then zielBeinahe = e end
        if not zielBesuche or e.besuche > zielBesuche.besuche then zielBesuche = e end
    end
    local zoneFuerZahl = ausFrage or aktuell or zielBesuche
    if zoneFuerZahl and zoneFuerZahl.besuche > 0 then
        v.zone = zoneFuerZahl.name
        v.n = tostring(zoneFuerZahl.besuche)
    end
    -- "Wo war es am knappsten" ohne Zonennamen: die gefaehrlichste Zone. MIT Zonennamen: genau
    -- die, und nur wenn es dort ueberhaupt knapp war. Sonst bleibt das Feld leer, und die
    -- Rueckfallstufe "verstanden, keine Daten" springt ein - statt einer Zahl aus der falschen
    -- Zone, die wie eine Antwort aussieht und keine ist.
    local knapp = ausFrage or zielBeinahe
    if knapp and knapp.beinahe > 0 then
        v.zoneKnapp = knapp.name
        v.beinaheZone = tostring(knapp.beinahe)
    end

    -- Beinahe-Tode insgesamt
    local bn = (type(c.beinahe) == "table") and #c.beinahe or 0
    if bn > 0 then v.beinahe = tostring(bn) end

    -- Bestiarium und Rivale
    local tiere = 0
    if type(c.bestiarium) == "table" then for _ in pairs(c.bestiarium) do tiere = tiere + 1 end end
    if tiere > 0 then v.tiere = tostring(tiere) end
    local r = rivale(c)
    if r and r.name then
        v.name = r.name
        local rb = (tonumber(r.beinahe) or 0)
        if rb > 0 then v.beinahe = v.beinahe or tostring(rb) end
        if rb > 0 then v.rivaleBeinahe = tostring(rb) end
    end

    -- Sitzungen und Spielzeit
    if type(c.sitzungen) == "table" and #c.sitzungen > 0 then
        v.sitzungen = tostring(#c.sitzungen)
        local summe, laengste = 0, 0
        for _, s in ipairs(c.sitzungen) do
            if type(s) == "table" then
                local d = (tonumber(s.ende) or 0) - (tonumber(s.start) or 0)
                if d > 0 and d < 24 * 3600 then
                    summe = summe + d
                    if d > laengste then laengste = d end
                end
            end
        end
        v.stunden = stundenText(summe)
        v.laengste = dauerText(laengste)
        local erste = c.sitzungen[1]
        if type(erste) == "table" and erste.start and date then
            v.seit = date("%d.%m.%Y", erste.start)
        end
    end

    -- Heimat: die Zone mit der meisten Zeit (Persoenlichkeit.heimat() ist die Hauptquelle)
    if ns.Persoenlichkeit and ns.Persoenlichkeit.heimat then
        local ok, h = pcall(ns.Persoenlichkeit.heimat)
        if ok and type(h) == "string" and h ~= "" then v.heimat = h end
    end
    if not v.heimat and type(c.zonenZeit) == "table" then
        local bestN, bestT = nil, 0
        for name, sek in pairs(c.zonenZeit) do
            if type(name) == "string" and (tonumber(sek) or 0) > bestT then
                bestN, bestT = name, tonumber(sek)
            end
        end
        v.heimat = bestN
    end
    if not v.heimat and zielBesuche and zielBesuche.besuche > 1 then v.heimat = zielBesuche.name end

    -- Tode
    local tode = tonumber(c.tode)
    if not tode and type(c.bestiarium) == "table" then
        tode = 0
        for _, e in pairs(c.bestiarium) do
            if type(e) == "table" then tode = tode + (tonumber(e.tode) or 0) end
        end
    end
    if tode and tode > 0 then v.tode = tostring(tode) end

    -- Notizen (die juengste)
    if type(c.notizen) == "table" and #c.notizen > 0 then
        local letzte = c.notizen[#c.notizen]
        if type(letzte) == "table" and type(letzte.text) == "string" and letzte.text ~= "" then
            v.notiz = letzte.text
            v.notizZone = letzte.zone
        end
    end

    -- Erbe (Vorgaenger)
    local erbe = LyraGestaltDB and LyraGestaltDB.erbe
    if type(erbe) == "table" then
        local e = erbe[ns.charKey] or erbe
        if type(e) == "table" then
            local st = tonumber(e.stufe or e.level)
            if st and st > 0 then v.erbeStufe = tostring(st) end
            if type(e.zone) == "string" and e.zone ~= "" then v.erbeZone = e.zone end
        end
    end

    return v
end

-- =============================================================================================
-- ERKENNEN
-- =============================================================================================
-- Rueckgabe von F.erkenne(roh):
--   { art = "treffer", intent = <Eintrag>, punkte, deckung, schluessel, zweiter }
--   { art = "fremd" }  |  { art = "unklar", deckung }
--
-- Reihenfolge, wie im Konzept §2.3 empfohlen:
--   1. Der Gespraechsfaden ("und in Westfall?") - ohne ihn wirkt jeder Bot kaputt.
--   2. Deckungsrechnung ueber die INHALTSwoerter, mit Tippfehler-Bruecke.
--   3. TF-IDF-Kosinus gegen die Bankfragen, Rangzahl entscheidet bei Gleichstand.
--   4. Fremdthemen-Liste VOR dem Abweisen - "nicht mein Fach" ist eine bessere Antwort
--      als "Kauderwelsch".
local faden = { intent = nil, schluessel = nil, t = 0 }
local nachfrage = nil   -- { intentA, intentB, t }
F.stand = function() return faden, nachfrage, IDX, WB end

local FADEN_WORT = { de = { "und", "auch", "davon", "dort" }, en = { "and", "also", "there" } }
local JA = { ja = true, jo = true, jep = true, klar = true, gerne = true, bitte = true,
             yes = true, yeah = true, sure = true, please = true, ok = true }

-- Schluessel (Zone/Gegner) aus der Frage ziehen. Erst woertlich, dann ueber die Trigramm-Bruecke
-- gegen die EIGENE Chronik: "schlingendorntahl" findet "Schlingendorntal", weil der Name dort
-- steht und nicht im Katalog.
function F.schluesselAus(roh)
    local wb = F.woerterbuch()
    if wb.n == 0 then return nil end
    local norm = F.normalisiere(roh)
    -- 1. ganze Namen woertlich (laengster zuerst, damit "Wald von Elwynn" vor "elwynn" gewinnt)
    local bestE, bestLen = nil, 0
    for w, e in pairs(wb.woerter) do
        if #w > bestLen and norm:find(w, 1, true) then
            -- treffer = der Wortlaut, wie er in der FRAGE steht. Ihn braucht F.erkenne, um
            -- genau diese Woerter von der Tippfehler-Bruecke fernzuhalten (W10a).
            bestE, bestLen = { schluessel = e.schluessel, art = e.art, treffer = w }, #w
        end
    end
    if bestE then return bestE.schluessel, bestE.art, 1, bestE.treffer end
    -- 2. Tippfehler-Bruecke ueber die Einzelwoerter
    local bestW, bestS, bestT = nil, 0, nil
    for _, w in ipairs(inhaltswoerter(worte(roh))) do
        local kandidat, s = naechstesWort(w, wb.woerter)
        if kandidat and s > bestS then bestW, bestS, bestT = kandidat, s, w end
    end
    if bestW and bestS >= F.TRIGRAMM_MIN then
        local e = wb.woerter[bestW]
        return e.schluessel, e.art, bestS, bestT
    end
    return nil
end

-- W10A, DIE AUSNAHME (§B.4 Nr. 2): die Fremdliste gilt nur fuer Woerter, die die BANK NICHT
-- SELBST BENUTZT. Auf der Website stand "map" auf der Fremdliste und gleichzeitig in der
-- eigenen Frage "where does the danger map come from" - das Veto wies damit eigene Fragen ab.
-- Im Spiel gilt dasselbe, sobald die Fremdliste oder die Bank waechst: "gilde", "quest" und
-- "raid" sind heute Fremdwoerter und koennen morgen in einer eigenen Frage stehen.
--
-- Die Ausnahme wird BEIM INDEXAUFBAU gerechnet (IDX.eigen, alle Woerter aller Bankfragen der
-- aktiven Sprache) und nicht von Hand gepflegt. Eine zweite Handliste waere genau die zweite
-- Wahrheit, die der Dateikopf fuer die Normalisierung schon ablehnt: sie veraltet still, und
-- zwar in die gefaehrliche Richtung - das Veto weist dann eigene Fragen ab.
local function fremdThema(ws)
    local lang = sprache()
    local eigen = (IDX and IDX.eigen) or {}
    local treffer = {}
    for _, w in ipairs(FREMD[lang] or FREMD.en) do
        if not eigen[w] then treffer[w] = true end
    end
    -- die andere Sprache mitpruefen: ein deutscher Spieler tippt "route" genauso
    for _, w in ipairs((lang == "de") and FREMD.en or FREMD.de) do
        if not eigen[w] then treffer[w] = true end
    end
    for _, w in ipairs(ws) do if treffer[w] then return true end end
    return false
end
-- Fuer den Pruefstand: welche Fremdwoerter die Bank selbst benutzt (und damit nicht mehr
-- vetofaehig sind). Ohne Index gibt es keine Ausnahme - dann ist die Liste leer.
function F.fremdAusnahmen()
    local eigen = (IDX and IDX.eigen) or {}
    local out = {}
    for _, liste in pairs(FREMD) do
        for _, w in ipairs(liste) do
            if eigen[w] then
                local doppelt = false
                for _, x in ipairs(out) do if x == w then doppelt = true end end
                if not doppelt then out[#out + 1] = w end
            end
        end
    end
    table.sort(out)
    return out
end

-- Kosinus der Frage gegen jede Bankfrage; je Absicht das Maximum, dann die beste und die
-- zweitbeste Absicht. Bei GLEICHSTAND gewinnt die kleinere Rangzahl - nicht die Position in
-- der Tabelle (KI-Audit V-8). Ohne diese Regel entscheidet, wer zufaellig zuerst dasteht, und
-- neue Absichten werden von alten gefressen (bekannter Fall im Dialog: "finde den mob" -> ziel).
--
-- W10A, DECKUNGSGEWICHTUNG (§B.4 Nr. 3): der Kosinus allein sagt nur, ob die Richtungen der
-- beiden Vektoren zusammenpassen - nicht, WIE VIEL der Frage ueberhaupt getroffen wurde. Ein
-- einziges gemeinsames Wort ergibt einen glatten Kosinus von 1,00, wenn der Bankssatz nach der
-- Stoppwortregel selbst nur aus diesem Wort besteht. Auf der Website traf so "does the addon
-- think for me" mit dem einen Wort "addon" eine Absicht mit 1,00; im Spiel traf "wie oft war
-- ich im brachland" mit dem einen Wort "oft" die Absicht "tode" mit 0,61 - und antwortete mit
-- der Zahl der Tode auf eine Frage nach Besuchen in einer Zone, die die Chronik gar nicht kennt.
-- Darum: Punkte = Kosinus x Deckungsgrad, und der Deckungsgrad ist der Anteil der
-- INHALTSwoerter der Frage, die in diesem Bankssatz wirklich vorkommen. qn ist die Zahl der
-- Inhaltswoerter der ganzen Frage (nicht nur der erkannten) - fehlt sie, zaehlt die Zahl der
-- uebergebenen Woerter, was der Kurzfragen-Weg braucht.
--
-- Rueckgabe: bestEintrag, bestPunkte, zweiterEintrag, zweitePunkte.
function F.beste(qwoerter, saetze, idf, qn)
    local qtf, summe, verschieden = {}, 0, 0
    for _, w in ipairs(qwoerter) do
        if not qtf[w] then verschieden = verschieden + 1 end
        qtf[w] = (qtf[w] or 0) + 1
    end
    for w, f in pairs(qtf) do
        local g = f * (idf[w] or 1)
        qtf[w] = g
        summe = summe + g * g
    end
    local qnorm = math.sqrt(summe)
    if qnorm == 0 then return nil, 0, nil, 0 end
    qn = qn or verschieden
    if qn < 1 then qn = 1 end
    local punkte = {}
    for _, s in ipairs(saetze) do
        local p, treffer = 0, 0
        for w, g in pairs(qtf) do
            local sg = s.tf[w]
            if sg then p = p + g * sg; treffer = treffer + 1 end
        end
        if s.norm > 0 then
            p = p / (qnorm * s.norm)
            -- Deckungsgrad. Mehr Treffer als Frageworte kann es nicht geben, aber qn kommt von
            -- aussen - der Deckel haelt die Rechnung auch dann bei hoechstens 1.
            local deck = treffer / qn
            if deck > 1 then deck = 1 end
            p = p * deck
            if p > (punkte[s.intent] or 0) then punkte[s.intent] = p end
        end
    end
    local best, bestP, zweiter, zweiterP = nil, 0, nil, 0
    for _, eintrag in ipairs(BANK) do
        local p = punkte[eintrag.id] or 0
        if p > bestP or (p == bestP and best and eintrag.rang < best.rang) then
            zweiter, zweiterP = best, bestP
            best, bestP = eintrag, p
        elseif p > zweiterP then
            zweiter, zweiterP = eintrag, p
        end
    end
    return best, bestP, zweiter, zweiterP
end

-- ------------------------------------------------------------------------- W10A: "Warum?"
-- Konzept §2.5, Welle 9b Offener Punkt 7. "Warum bin ich in Westfall immer fast gestorben?"
-- hat in einer Zahlentabelle keine Antwort, und eine erfundene Erklaerung waere genau das,
-- was diese ganze Datei nicht tut. Die ehrliche Ausweichzeile gibt die TATSACHE zurueck und
-- sagt dazu, dass sie nicht deutet: "Warum? Ich zaehle, ich deute nicht. Ich weiss nur: ..."
--
-- Das ist eine neue Rueckfall-ART, keine neue Absicht: die Frage wird ganz normal zugeordnet,
-- nur der RAHMEN um die Antwort wechselt (FREITEXT_WARUM statt FREITEXT_ANTWORT). Wird gar
-- nichts erkannt, bleibt es bei den drei alten Stufen - eine Warum-Zeile ohne Tatsache waere
-- eine Floskel, und Floskeln sind hier teurer als Schweigen ("keine Zahl, keine Zeile").
local WARUM = { warum = true, wieso = true, weshalb = true, why = true,
                warums = true, wiesos = true }

function F.istWarum(roh)
    for _, w in ipairs(worte(F.saeubern(roh))) do if WARUM[w] then return true end end
    return false
end

local erkenneKern

function F.erkenne(roh)
    local e = erkenneKern(roh)
    if F.istWarum(roh) then e.warum = true end
    return e
end

erkenneKern = function(roh)
    local text = F.saeubern(roh)
    if text == "" then return { art = "unklar", deckung = 0 } end
    local idx = F.index()
    -- W10A: Zonenname in der anderen Sprache -> Name, den die Chronik wirklich traegt.
    -- Das passiert VOR allem anderen, damit auch die Deckung und der Kosinus den richtigen
    -- Namen sehen und nicht nur der Schluessel.
    local gebrueckt, zonVon, zonNach = F.zonenBruecke(F.normalisiere(text))
    if zonVon then text = gebrueckt end
    -- Zone bekannt, Chronik leer: verstanden, aber keine Zahl. Das ist Rueckfallstufe 1 und
    -- nicht Stufe 3 - "ich war nie dort" ist keine Verstaendnisluecke.
    local zonLeer = F.zonenOhneChronik(F.normalisiere(text))
    if zonLeer then return { art = "leer", deckung = 1, zonLeer = zonLeer } end
    local alleW = worte(text)
    local ws = inhaltswoerter(alleW)

    -- Offene Rueckfrage: "ja" beantwortet sie.
    if nachfrage and (jetzt() - nachfrage.t) < F.NACHFRAGE_S and #alleW <= 2 then
        for _, w in ipairs(alleW) do
            if JA[w] then
                local ziel = nachfrage.intentA
                nachfrage = nil
                return { art = "treffer", intent = ziel, punkte = 1, deckung = 1,
                         schluessel = faden.schluessel, ausFaden = true }
            end
        end
    end

    -- Gespraechsfaden: "Und in Westfall?" traegt die letzte Absicht weiter.
    if faden.intent and (jetzt() - faden.t) < F.FADEN_S and #ws <= 2 then
        local fw = FADEN_WORT[sprache()] or FADEN_WORT.en
        local traegt = false
        for _, w in ipairs(alleW) do
            for _, f in ipairs(fw) do if w == f then traegt = true end end
        end
        if traegt or #ws == 1 then
            local schl = F.schluesselAus(text)
            if schl then
                return { art = "treffer", intent = faden.intent, punkte = 1, deckung = 1,
                         schluessel = schl, ausFaden = true }
            end
        end
    end

    -- Kurzfragen-Weg: hoechstens EIN Inhaltswort. Dann entscheidet die Wortfolge selbst,
    -- gegen den zweiten Index und mit hoeherer Schwelle.
    if #ws <= 1 and #alleW >= 2 then
        local best, bestP = F.beste(alleW, idx.kurz, idx.kurzIdf)
        if best and bestP >= F.KURZ_MIN then
            return { art = "treffer", intent = best, punkte = bestP, deckung = 1,
                     schluessel = F.schluesselAus(text), kurz = true }
        end
        if #ws == 0 then
            if fremdThema(alleW) then return { art = "fremd", deckung = 0 } end
            return { art = "unklar", deckung = 0, punkte = bestP }
        end
    end

    if #ws == 0 then return { art = "unklar", deckung = 0 } end

    -- Der Schluessel (Zone/Gegner) wird ZUERST gesucht. Grund (W10a): sein Wortlaut ist ein
    -- EIGENNAME aus der eigenen Chronik und darf nicht ueber die Tippfehler-Bruecke auf ein
    -- Bankwort gezogen werden. Gemessener Fall: "wie oft war ich in stranglethorn vale" -
    -- "vale" (4 Zeichen) zog auf "rivale" (6 Zeichen, Dice 0,57), und die Zonenfrage bekam den
    -- Namen des Erzfeinds zur Antwort. Die Laengenschranke allein faengt das nicht: zwei
    -- Zeichen Unterschied sind erlaubt, und genau zwei sind es hier.
    --
    -- Die Sperre gilt NUR fuer einen WOERTLICH gefundenen Namen (Guete 1). Wurde der Name
    -- selbst erst ueber die Tippfehler-Bruecke gefunden ("wesfall" -> Westfall), dann ist das
    -- getippte Wort eben KEIN sauberer Eigenname, und es darf weiter auf das Bankwort
    -- "westfall" ziehen - sonst bliebe von "wie oft war ich in wesfall" nur "oft" uebrig, und
    -- die Frage landete bei den Toden. Genau so gemessen.
    local schluessel, art, guete, keyText = F.schluesselAus(text)
    local keyWorte = {}
    if keyText and guete == 1 then
        for w in keyText:gmatch("%S+") do keyWorte[w] = true end
    end

    -- Deckung: wie viele Inhaltswoerter kennt die Bank (woertlich oder ueber die Bruecke)?
    -- Das ist der Riegel gegen "wie hoch ist der DAX" (Messung C).
    local ersetzt, bekannt = {}, 0
    for _, w in ipairs(ws) do
        if idx.vokabular[w] then
            bekannt = bekannt + 1
            ersetzt[#ersetzt + 1] = w
        elseif keyWorte[w] then
            -- Verstanden - aber als Eigenname, nicht als Bankwort. Er zaehlt fuer die Deckung
            -- und geht NICHT in den Kosinus.
            bekannt = bekannt + 1
        else
            local kandidat, s = naechstesWort(w, idx.vokabular)
            if kandidat and s >= F.TRIGRAMM_MIN then
                bekannt = bekannt + 1
                ersetzt[#ersetzt + 1] = kandidat
            end
        end
    end
    local deckung = bekannt / #ws
    if schluessel then deckung = math.min(1, deckung + 1 / #ws) end

    if deckung < F.DECKUNG_MIN then
        if fremdThema(ws) then return { art = "fremd", deckung = deckung } end
        return { art = "unklar", deckung = deckung }
    end

    -- TF-IDF-Kosinus gegen jede Bankfrage; je Absicht das Maximum.
    local best, bestP, zweiter, zweiterP = F.beste(ersetzt, idx.saetze, idx.idf, #ws)

    if not best or bestP < F.PUNKTE_MIN then
        if fremdThema(ws) then return { art = "fremd", deckung = deckung } end
        return { art = "unklar", deckung = deckung, punkte = bestP }
    end
    -- Ein Fremdthema, das trotzdem Punkte holt (z. B. "welche zone hat die besten quests"),
    -- geht als "nicht mein Fach" raus - nicht als falsche Zahl.
    if fremdThema(ws) and bestP < (F.PUNKTE_MIN + 0.25) then
        return { art = "fremd", deckung = deckung }
    end
    return { art = "treffer", intent = best, punkte = bestP, deckung = deckung,
             schluessel = schluessel, schluesselArt = art, zonVon = zonVon, zonNach = zonNach,
             zweiter = (zweiter and (bestP - zweiterP) < F.PUNKTE_ABSTAND) and zweiter or nil }
end

-- =============================================================================================
-- ANTWORTEN
-- =============================================================================================
local rotation = {}

local function fuelle(vorlage, v)
    return (vorlage:gsub("{(%a+)}", function(k)
        local x = v[k]
        return x ~= nil and tostring(x) or ("{" .. k .. "}")
    end))
end

-- Alle Platzhalter einer Vorlage vorhanden? "keine Zahl, keine Zeile".
local function vollstaendig(vorlage, v)
    for k in vorlage:gmatch("{(%a+)}") do
        if k ~= "Held" and k ~= "Heldin" and v[k] == nil then return false end
    end
    return true
end

-- Vorlage waehlen: rotierend (Reihenfolge, nicht Zufall - wie D.naechster), und nur unter den
-- Vorlagen, deren Platzhalter WIRKLICH gefuellt sind.
local function vorlageWaehlen(eintrag, v)
    local lang = sprache()
    local liste = (eintrag.antwort and (eintrag.antwort[lang] or eintrag.antwort.en)) or {}
    local moeglich = {}
    for _, vorlage in ipairs(liste) do
        -- {Held|Heldin} ist KEIN Platzhalter (da steht ein | drin) - ns.Anrede loest ihn auf.
        if vollstaendig(vorlage, v) then moeglich[#moeglich + 1] = vorlage end
    end
    if #moeglich == 0 then return nil end
    local i = ((rotation[eintrag.id] or 0) % #moeglich) + 1
    rotation[eintrag.id] = i
    return moeglich[i]
end

-- Die Sonderfaelle, in denen eine Absicht eine andere Zahl braucht als die Standardfakten.
local function fuerIntent(id, v)
    if id == "zone_beinahe" then
        v.zone = v.zoneKnapp or v.zone
        v.beinahe = v.beinaheZone or v.beinahe
    elseif id == "rivale" then
        v.beinahe = v.rivaleBeinahe or v.beinahe
    end
    return v
end

-- Namen heraus. Dieselbe Wache wie im Chronikfenster (Welle 7): Charakter, Realm, Gilde.
-- Lauf f8 prueft, dass KEINE Antwort einen davon traegt.
local function sicher(s)
    if ns.Dialog and ns.Dialog.chronikSicher then
        local ok, out = pcall(ns.Dialog.chronikSicher, s)
        if ok and type(out) == "string" then return out end
    end
    return tostring(s or "")
end
F.sicher = sicher

-- Der Verlauf. NUR im Speicher - ausser der Spieler hat "Fragen merken" eingeschaltet.
F.verlauf = {}
local function verlaufLegen(frage, antwort)
    table.insert(F.verlauf, { frage = frage, antwort = antwort, t = jetzt() })
    while #F.verlauf > F.VERLAUF_MAX do table.remove(F.verlauf, 1) end
    if ns.Get("fragenMerken") and LyraGestaltDB then
        -- Vorbereitung fuer Stufe 2 (docs/freitext-konzept §3). Standard AUS, eigene Kappe,
        -- und ausdruecklich nur die Frage - nie die Antwort, nie ein Zeitstempel mehr als noetig.
        LyraGestaltDB.fragen = LyraGestaltDB.fragen or {}
        table.insert(LyraGestaltDB.fragen, { t = (time and time()) or 0, text = frage })
        while #LyraGestaltDB.fragen > F.VERLAUF_MAX do table.remove(LyraGestaltDB.fragen, 1) end
    end
end

-- F.antworte(roh) -> art, text
--   "treffer" | "leer" | "fremd" | "unklar"
-- Die Ausgabe laeuft ueber die Regie mit vars.direkt: kein Budget, kein Abstand, kein
-- Still-Modus - aber der Kampf-Riegel und der Tod-Riegel bleiben. Eine Antwort ist eine
-- Antwort auf eine Frage des Spielers, keine Plauderei.
function F.antworte(roh)
    local frage = F.saeubern(roh)
    if frage == "" then return "unklar", nil end
    local e = F.erkenne(frage)
    local art, text, id = e.art, nil, nil

    if e.art == "treffer" then
        local v = fuerIntent(e.intent.id, F.fakten(e.schluessel))
        local vorlage = vorlageWaehlen(e.intent, v)
        if vorlage then
            text = sicher(ns.Anrede and ns.Anrede(fuelle(vorlage, v)) or fuelle(vorlage, v))
            -- W10A: dieselbe Tatsache, anderer Rahmen. "warum" wird nicht beantwortet,
            -- sondern ehrlich zurueckgegeben.
            id = e.warum and "FREITEXT_WARUM" or "FREITEXT_ANTWORT"
            faden.intent, faden.schluessel, faden.t = e.intent, e.schluessel, jetzt()
            if e.zweiter then
                nachfrage = { intentA = e.zweiter, intentB = e.intent, t = jetzt() }
            else
                nachfrage = nil
            end
        else
            art, id = "leer", "FREITEXT_LEER"     -- verstanden, aber keine Daten
        end
    elseif e.art == "leer" then
        -- W10A: eine Zone, die es gibt, in der der Spieler nur nie war.
        art, id = "leer", "FREITEXT_LEER"
    elseif e.art == "fremd" then
        id = "FREITEXT_FREMD"
    else
        id = "FREITEXT_UNKLAR"
    end

    local vars = { direkt = true, antwort = text, frageText = frage }
    if e.intent then vars.key = e.intent.id end
    local gesagt = false
    if ns.melde then
        local ok, r = pcall(ns.melde, id, vars)
        gesagt = ok and r and true or false
    end
    verlaufLegen(frage, text)
    F.nachklangAnstossen()
    return art, text, gesagt
end

-- Der Nachklang: Lyra kommt spaeter von selbst auf eine Frage zurueck ("Du hast vorhin nach
-- dem Schlingendorntal gefragt. Ich musste daran denken."). Der Platzhalter {frage} existiert
-- seit Welle 3 in Sinne/Persoenlichkeit.lua und wurde von KEINER Zeile benutzt - vier
-- Katalogzeilen, und Stufe 1 wirkt doppelt so lebendig (Konzept §2.6).
--
-- KEIN eigener Ticker. Der Anstoss haengt an ns.nachAusgabe, also an einer Zeile, die die Regie
-- ohnehin gerade herausgelassen hat. Ein Dauer-Ticker mehr waere in w8_leistung.lua sichtbar
-- und waere fuer eine Zeile je Sitzung nicht zu rechtfertigen.
-- FIX 0.19.1 (Spieltest Harald 22.09.): FRAGE_NACHKLANG hat die Katalog-Drossel "session" -
-- EINMAL je Sitzung. Der Anstoss hing aber an JEDER Ausgabe, also lief nach dem ersten
-- Nachklang bei jeder weiteren Zeile ein neuer Versuch in die Drossel ("Regie drop
-- FRAGE_NACHKLANG: drossel" im Debug-Chat, den ganzen Abend). nachklangErledigt merkt sich
-- die Sitzung: nach einem Erfolg oder einem Drossel-Drop wird nichts mehr angestossen.
-- Nur ein Abstand-Drop darf es spaeter noch einmal versuchen (naechste Ausgabe).
local nachklangGeplant, nachklangErledigt = false, false
function F.nachklangAnstossen()
    if nachklangGeplant or nachklangErledigt then return end
    if not (ns.Persoenlichkeit and ns.Persoenlichkeit.frage) then return end
    local ok, txt = pcall(ns.Persoenlichkeit.frage)
    if not ok or not txt then return end
    if imKampf() then return end
    nachklangGeplant = true
    local function raus()
        nachklangGeplant = false
        if imKampf() then return end
        if not ns.melde then return end
        local ok2, durch = pcall(ns.melde, "FRAGE_NACHKLANG", {})
        if ok2 and durch then nachklangErledigt = true; return end
        local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
        if d and d[2] == "FRAGE_NACHKLANG" and d[1] ~= "abstand" then nachklangErledigt = true end
    end
    if ns.Compat and ns.Compat.After then ns.Compat.After(F.NACHKLANG_VERZUG, raus) else raus() end
end
if ns.nachAusgabe then
    ns.nachAusgabe(function(id)
        if id == "FRAGE_NACHKLANG" then nachklangErledigt = true; return end
        if id == "FREITEXT_ANTWORT" or id == "FREITEXT_WARUM" then return end
        F.nachklangAnstossen()
    end)
end

-- =============================================================================================
-- DAS EINGABEFELD
-- =============================================================================================
-- Es haengt UNTER dem Gespraechsfenster (LyraGestaltDialog) und traegt den Verlauf der letzten
-- F.VERLAUF_MAX Fragen darueber. Eigenes Fenster statt Umbau von UI/Dialog.lua: das Gespraech
-- misst seine Hoehe aus Text und Knoepfen, und ein Feld mittendrin haette diese Rechnung
-- angefasst. So bleibt UI/Dialog.lua bei zwei Haken.
local BREITE_MIN, FELD_H, RAND, ZEILE_H = 380, 22, 14, 14
local fr, eb, verlaufFS, hinweis
F.fokus = false

local function farben() return (ns.Optik and ns.Optik.farben()) or { text = { 1, 1, 1 } } end
local function groesse() return (ns.Optik and ns.Optik.schriftgroesse and ns.Optik.schriftgroesse()) or 14 end
local function L(k) return (ns.L and ns.L[k]) or k end

function F.an() return ns.Get("freitext") ~= false end

-- Die Ziffern 1-4 des Antwortmenues duerfen nicht im Feld landen, und umgekehrt darf das Feld
-- die Tastatur des Gespraechs nicht blockieren. Solange Fokus liegt, ist die Gespraechs-Tastatur
-- abgemeldet; faellt der Fokus, kommt sie zurueck.
local function tastaturDesGespraechs(an)
    local d = ns.Dialog
    if not (d and d.frame) then return end
    if an then
        if d.frame:IsShown() and not imKampf() then pcall(d.frame.EnableKeyboard, d.frame, true) end
    else
        pcall(d.frame.EnableKeyboard, d.frame, false)
    end
end

function F.fokusWeg()
    F.fokus = false
    if eb then pcall(eb.ClearFocus, eb) end
    F.rahmen()
    tastaturDesGespraechs(true)
end

function F.fokusHin()
    -- Der Riegel. Im Kampf nimmt das Feld keinen Fokus an - ein fokussiertes EditBox frisst
    -- WASD, und das ist der schnellste Weg, einen Hardcore-Charakter zu toeten.
    if imKampf() then F.fokusWeg(); return false end
    if not eb then return false end
    F.fokus = true
    tastaturDesGespraechs(false)
    pcall(eb.SetFocus, eb)
    F.rahmen()
    return true
end

function F.rahmen()
    if not (fr and ns.Optik) then return end
    local c = farben()
    local farbe = F.fokus and (ns.Optik.GOLD or { 1, 0.82, 0 }) or (c.linie or ns.Optik.LILA)
    if fr.rand and fr.rand.SetColorTexture then ns.Optik.flaeche(fr.rand, farbe) end
end

local function verlaufText()
    local out = {}
    for i = 1, #F.verlauf do
        local e = F.verlauf[i]
        out[#out + 1] = "> " .. sicher(e.frage)
        if e.antwort then out[#out + 1] = sicher(e.antwort) end
    end
    return table.concat(out, "\n")
end
F.verlaufText = verlaufText

function F.bauen()
    if fr then return fr end
    if not CreateFrame then return nil end
    local ok, frame = pcall(CreateFrame, "Frame", "LyraGestaltFreitext", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    if not ok or not frame then return nil end
    fr = frame
    fr:SetFrameStrata("MEDIUM")
    fr:SetFrameLevel(31)
    fr:SetSize(BREITE_MIN, FELD_H + 2 * RAND)
    fr:SetClampedToScreen(true)
    fr:EnableMouse(true)
    if fr.SetBackdrop and ns.Optik then pcall(fr.SetBackdrop, fr, ns.Optik.BACKDROP) end
    fr:Hide()

    verlaufFS = fr:CreateFontString(nil, "OVERLAY")
    verlaufFS:SetPoint("TOPLEFT", RAND, -RAND)
    verlaufFS:SetPoint("TOPRIGHT", -RAND, -RAND)
    verlaufFS:SetJustifyH("LEFT")
    verlaufFS:SetFont(STANDARD_TEXT_FONT, 12, "")   -- FIX5-Regel: Schrift VOR dem ersten SetText
    verlaufFS:SetWordWrap(true)

    local okEB, feld = pcall(CreateFrame, "EditBox", "LyraGestaltFreitextEdit", fr)
    if not okEB or not feld then return fr end
    eb = feld
    eb:SetHeight(FELD_H)
    eb:SetAutoFocus(false)              -- Regel 1: nie Fokus beim Oeffnen
    eb:SetMaxLetters(F.MAX_LAENGE)      -- Regel: hoechstens 200 Zeichen
    if eb.SetFontObject and _G.ChatFontNormal then pcall(eb.SetFontObject, eb, _G.ChatFontNormal) end
    pcall(eb.SetFont, eb, STANDARD_TEXT_FONT, 13, "")
    eb:SetScript("OnEnterPressed", function(self)
        local txt = self:GetText()
        self:SetText("")
        F.fokusWeg()
        if txt and txt ~= "" then F.senden(txt) end
    end)
    eb:SetScript("OnEscapePressed", function(self)
        -- ESC nimmt ERST den Fokus, dann das Fenster (UI/Dialog.lua UISpecialFrames).
        self:SetText("")
        F.fokusWeg()
        F.verstecke()
    end)
    eb:SetScript("OnEditFocusGained", function()
        if imKampf() then F.fokusWeg(); return end
        F.fokus = true
        tastaturDesGespraechs(false)
        F.rahmen()
    end)
    eb:SetScript("OnEditFocusLost", function()
        F.fokus = false
        tastaturDesGespraechs(true)
        F.rahmen()
    end)
    fr.rand = fr:CreateTexture(nil, "ARTWORK")
    fr.rand:SetPoint("BOTTOMLEFT", RAND - 2, RAND - 3)
    fr.rand:SetPoint("BOTTOMRIGHT", -(RAND - 2), RAND - 3)
    fr.rand:SetHeight(2)
    hinweis = fr:CreateFontString(nil, "OVERLAY")
    hinweis:SetPoint("BOTTOMRIGHT", -RAND, 4)
    hinweis:SetJustifyH("RIGHT")
    hinweis:SetFont(STANDARD_TEXT_FONT, 10, "")
    F.frame, F.editbox = fr, eb
    return fr
end

-- Absenden - der EINE Weg von der Tastatur zu Lyra. Er ruft ns.Dialog.frage, damit der
-- bestehende Intent-Parser (29 Intents) Vorrang behaelt und der Mitschnitt aus
-- Sinne/Persoenlichkeit.lua (letzteFrage, {frage}) weiter greift.
function F.senden(roh)
    local txt = F.saeubern(roh)
    if txt == "" then return false end
    if ns.Dialog and ns.Dialog.frage then
        ns.Dialog.frage(txt)
    else
        F.antworte(txt)
    end
    F.zeichne()
    return true
end

function F.zeichne()
    if not fr then return end
    local size = groesse()
    local c = farben()
    if ns.Optik then ns.Optik.panel(fr) end
    if ns.Optik and ns.Optik.setzeText then
        ns.Optik.setzeText(verlaufFS, verlaufText(), math.max(10, size - 2), c.text)
        ns.Optik.setzeText(hinweis, L("Freetext hint"), math.max(9, size - 4),
            c.linie or (ns.Optik and ns.Optik.LILA) or c.text)
    else
        verlaufFS:SetText(verlaufText())
        hinweis:SetText(L("Freetext hint"))
    end
    local hoehe = 0
    if verlaufFS.GetStringHeight then hoehe = verlaufFS:GetStringHeight() or 0 end
    if #F.verlauf == 0 then hoehe = 0 end
    local breite = BREITE_MIN
    local d = ns.Dialog and ns.Dialog.frame
    if d and d.GetWidth then breite = math.max(BREITE_MIN, d:GetWidth() or BREITE_MIN) end
    fr:SetSize(breite, RAND + hoehe + (hoehe > 0 and 8 or 0) + FELD_H + RAND + 6)
    if eb then
        eb:ClearAllPoints()
        eb:SetPoint("BOTTOMLEFT", RAND, RAND)
        eb:SetPoint("BOTTOMRIGHT", -RAND, RAND)
    end
    F.rahmen()
end

function F.zeige()
    if not F.an() then return false end
    if not F.bauen() then return false end
    F.zeichne()
    fr:ClearAllPoints()
    local d = ns.Dialog and ns.Dialog.frame
    if d then fr:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -4)
    else fr:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
    fr:Show()
    return true
end

function F.verstecke()
    F.fokusWeg()
    if fr then fr:Hide() end
    if ns.Dialog and ns.Dialog.schliesse and ns.Dialog.offen and ns.Dialog.offen() then
        ns.Dialog.schliesse()
    end
end

function F.offen() return (fr and fr:IsShown()) and true or false end

-- Der Kampf-Riegel. DAS Abnahmekriterium dieser Welle (Lauf f7).
if ns.on then
    ns.on("PLAYER_REGEN_DISABLED", function()
        F.fokusWeg()
        if eb then pcall(eb.SetText, eb, "") end
        F.rahmen()
    end)
end

-- /lyra freitext an|aus. UI/Slash.lua reicht nur durch.
function F.schalten(wert)
    if wert ~= nil then
        if ns.Settings and ns.Settings.setze then ns.Settings.setze("freitext", wert)
        else ns.Set("freitext", wert) end
    end
    if not F.an() then F.verstecke() end
    return F.an()
end

return F
