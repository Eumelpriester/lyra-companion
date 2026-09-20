-- rituale_dialog.lua — Intents und Antworttexte fuer das Lebensecht-Modell (Welle 1).
-- NUR Daten, kein Code, kein eigener Global: alles haengt sich an LyraGestalt_Dialog aus dialog.lua.
-- Laedt NACH bruecken_dialog.lua und VOR UI/Dialog.lua (TOC). Zu diesem Zeitpunkt ist
-- LyraGestalt_Dialog da, ns.Dialog aber noch nicht; die Aktions-Funktionen registriert
-- Sinne/Rituale.lua bei PLAYER_LOGIN in ns.Dialog.aktionen. Diese Datei kennt nur Strings.
--
-- Aufbau wie dialog.lua / bruecken_dialog.lua:
--   intents[i] = { id, aktion = "name", woerter = { "..." } }
--   * woerter sind ASCII-normalisiert (ae/oe/ue/ss), kleingeschrieben, Treffer mit Wortgrenzen
--     (UI/Dialog.lua normalisiere()). "wie spaet" steht hier deshalb OHNE Umlaut.
--   * Reihenfolge = Prioritaet (UI/Dialog.lua nimmt den ERSTEN Treffer). Diese Intents kommen
--     darum VORNE hinein: "wie lange kennen wir uns" wuerde sonst nie am Intent "befinden"
--     vorbeikommen, und "wie ist deine laune" nicht am Wort "gehts".
--   * Der Intent "stimmung" nimmt "how do you feel" bewusst dem alten Intent "befinden" ab -
--     die Antwort ist dieselbe Frage, nur mit Begruendung. "wie fuehlst du dich" bleibt bei
--     "befinden". Wer das nicht will, streicht "how do you feel" aus dem Intent rit_stimmung.
-- Knoten: Antworten, fuer die es kein Ereignis in phrasen.lua gibt (ende = true, keine Position).
-- Anrede-Token {Held|Heldin} und Platzhalter {uhr} {stunden} {sitzung} {erinnerung} sind erlaubt.

local D = LyraGestalt_Dialog
if type(D) ~= "table" then return end
D.intents = D.intents or {}
D.knoten = D.knoten or {}

-- ---------------------------------------------------------------------------------------------
-- Intents (VORNE einfuegen, Reihenfolge untereinander bleibt erhalten)
-- ---------------------------------------------------------------------------------------------
local neu = {
    { id = "rit_zeit", aktion = "rit_zeit", woerter = {
        "wie spaet", "wie spat", "wie viel uhr", "wieviel uhr", "uhrzeit", "welche uhrzeit",
        "what time", "how late", "time is it",
    } },
    { id = "rit_wielange", aktion = "rit_wielange", woerter = {
        "wie lange spiele ich", "wie lange spielen wir", "wie lange kennen wir uns",
        "wie lange kennst du mich", "wie lange schon", "seit wann kennen wir uns", "seit wann",
        "wie viele stunden", "wieviele stunden", "spielzeit",
        "how long have we", "how long do you know me", "how long have you known me",
        "how long", "how many hours",
    } },
    { id = "rit_erinnerst", aktion = "rit_erinnerst", woerter = {
        "erinnerst du dich", "erinnerst du", "weisst du noch", "weiss du noch", "weist du noch",
        "denkst du noch", "erinnerung", "do you remember", "remember when", "you remember",
    } },
    { id = "rit_stimmung", aktion = "rit_stimmung", woerter = {
        "wie ist deine laune", "deine laune", "wie ist deine stimmung", "deine stimmung",
        "laune", "stimmung", "how do you feel", "your mood", "whats your mood",
    } },
}
for i = #neu, 1, -1 do table.insert(D.intents, 1, neu[i]) end

-- ---------------------------------------------------------------------------------------------
-- Knoten (Sinne/Rituale.lua gibt die ID + Platzhalter zurueck, UI/Dialog.lua zeigt den Text)
-- ---------------------------------------------------------------------------------------------
local K = D.knoten
local function knoten(t) K[#K + 1] = t end

-- Uhrzeit nach Tageszeit ---------------------------------------------------------------------
knoten({ id = "rit_zeit_frueh", miene = "interested", ende = true,
    text = { de = "{uhr}. Früh. Die Leylinien sind noch kalt, und du bist schon wach.",
             en = "{uhr}. Early. The ley lines are still cold and you're already up." } })
knoten({ id = "rit_zeit_tag", miene = "amused", ende = true,
    text = { de = "{uhr}. Bester Teil des Tages, {Held|Heldin}. Nutz ihn, bevor er dir abhandenkommt.",
             en = "{uhr}. Best part of the day, hero. Use it before it slips away." } })
knoten({ id = "rit_zeit_abend", miene = "touched", ende = true,
    text = { de = "{uhr}. Abend. Die guten Geschichten fangen um diese Zeit an.",
             en = "{uhr}. Evening. The good stories start around now." } })
knoten({ id = "rit_zeit_nacht", miene = "hmm", ende = true,
    text = { de = "{uhr}. Nacht. Ich sag nichts. Ich nenne nur die Zahl.",
             en = "{uhr}. Night. I'm not saying anything. I'm only naming the number." } })
knoten({ id = "rit_zeit_spaet", miene = "concerned", ende = true,
    text = { de = "{uhr}. Das ist keine Uhrzeit mehr, das ist eine Ausrede. Seit {sitzung} Minuten.",
             en = "{uhr}. That's not a time any more, that's an excuse. For {sitzung} minutes now." } })

-- Wie lange kennen wir uns -------------------------------------------------------------------
knoten({ id = "rit_lange_0", miene = "shy", ende = true,
    text = { de = "{stunden} Stunden. Noch nicht genug, um dich einzuschätzen. Ich arbeite dran.",
             en = "{stunden} hours. Not enough to read you yet. I'm working on it." } })
knoten({ id = "rit_lange_1", miene = "smirk", ende = true,
    text = { de = "{stunden} Stunden. Ich kenne inzwischen deine schlechten Angewohnheiten. Alle drei.",
             en = "{stunden} hours. I know your bad habits by now. All three of them." } })
knoten({ id = "rit_lange_2", miene = "touched", ende = true,
    text = { de = "{stunden} Stunden, {Held|Heldin}. Ich weiß, wann du müde wirst, bevor du es weißt.",
             en = "{stunden} hours, hero. I know when you're getting tired before you do." } })
knoten({ id = "rit_lange_3", miene = "overjoyed", ende = true,
    text = { de = "{stunden} Stunden. Bei den Leylinien. Das ist kein Zufall mehr, das ist eine Gewohnheit.",
             en = "{stunden} hours. By the ley lines. That's not coincidence any more, that's a habit." } })

-- Erinnerst du dich --------------------------------------------------------------------------
knoten({ id = "rit_erinnert", miene = "thinking", ende = true,
    text = { de = "Natürlich. {erinnerung}. Ich vergesse so etwas nicht.",
             en = "Of course. {erinnerung}. I don't forget things like that." } })
knoten({ id = "rit_erinnert_nichts", miene = "hmm", ende = true,
    text = { de = "Woran? Bisher ist nichts passiert, was ich aufheben müsste. Gib mir Zeit.",
             en = "Remember what? Nothing worth keeping has happened yet. Give me time." } })

-- Wie ist deine Laune ------------------------------------------------------------------------
knoten({ id = "rit_laune_gut", miene = "happy", ende = true,
    text = { de = "Gut. Ehrlich gut. Frag nicht weiter, sonst verderb ich es mir selbst.",
             en = "Good. Honestly good. Don't press, I'll only ruin it for myself." } })
knoten({ id = "rit_laune_neutral", miene = "neutral", ende = true,
    text = { de = "Ausgeglichen. Die Runen summen, nichts brennt, niemand blutet. Ich nehme das.",
             en = "Level. The runes hum, nothing's burning, nobody's bleeding. I'll take it." } })
knoten({ id = "rit_laune_besorgt", miene = "concerned", ende = true,
    text = { de = "Nicht gut. Und du weißt genau, warum. Bleib in meiner Nähe, {Held|Heldin}.",
             en = "Not good. And you know exactly why. Stay close, hero." } })
