-- welle2_dialog.lua — Intents und Antwortknoten fuer Welle 2 (Cooldowns, Klassenrat, Quests, Marks, Profil, Karte).
-- Nur Daten; Aktionen registrieren Sinne/Faehigkeiten.lua, Quests.lua, Profil.lua, Karte.lua bei PLAYER_LOGIN.
local D = LyraGestalt_Dialog
if type(D) ~= "table" then return end
D.intents = D.intents or {}
D.knoten = D.knoten or {}
local I = D.intents
local vorn = 0
local function intent(t)
    if t.praefix then vorn = vorn + 1; table.insert(I, vorn, t) else I[#I + 1] = t end
end
-- REVIEW6B: Praefix-Intents verlangen in UI/Dialog.lua intentSuchen() einen nicht leeren Rest
-- ("if inhalt ~= '' then return it, inhalt end"). Die kurzen Formen ("totenkopf", "skull",
-- "mark target", "setz ein zeichen") standen als Praefix und konnten deshalb NIE greifen - sie
-- landeten bei "Unbekannter Befehl". Sie sind jetzt ein zweiter Intent auf dieselbe Aktion, ueber
-- woerter. Die Aktion nimmt das Zeichen dann aus dem Rohtext.
intent({ id = "w2_mark", aktion = "w2_mark", praefix = { "markier das ziel ", "markiere das ziel ", "mark target ", "mark the target ", "setz ein zeichen ", "zeichen auf ziel " } })
intent({ id = "w2_mark_wort", aktion = "w2_mark", woerter = { "totenkopf", "skull", "markier das ziel", "markiere das ziel", "mark target", "mark the target", "setz ein zeichen", "zeichen auf ziel", "markier das" } })
intent({ id = "w2_cooldowns", aktion = "w2_cooldowns", woerter = { "cooldowns", "cooldown", "was ist bereit", "notfall", "notfallknopf", "notfallknoepfe", "abklingzeit", "abklingzeiten", "what's ready", "whats ready", "what is ready", "emergency" } })
intent({ id = "w2_rat", aktion = "w2_rat", woerter = { "rat", "tipp", "tip", "klassenrat", "advice", "ratschlag", "was soll ich skillen", "wie spiele ich meine klasse" } })
intent({ id = "w2_quests", aktion = "w2_quests", woerter = { "quests", "questlog", "questbuch", "quest fortschritt", "quest progress", "wie weit bin ich", "how far am i", "was ist offen", "what's open" } })
intent({ id = "w2_profil", aktion = "w2_profil", woerter = { "profil", "spielstil", "playstyle", "wie spiele ich", "how do i play", "bin ich vorsichtig", "am i careful" } })
intent({ id = "w2_karte", aktion = "w2_karte", woerter = { "karte", "pins", "map pins", "zeig mir die karte", "show me the map", "kartenpunkte" } })

local function knoten(id, miene, de, en)
    D.knoten[#D.knoten + 1] = { id = id, miene = miene, text = { de = de, en = en }, ende = true }
end
knoten("w2_cooldowns", "thinking", "Dein Notfall-Stand: {liste}", "Your emergency kit: {liste}")
knoten("w2_rat", "smug", "Mein Rat, {Held|Heldin}: {rat}", "My advice, hero: {rat}")
knoten("w2_quests", "interested", "{liste}", "{liste}")
knoten("w2_profil", "thinking", "{profil}", "{profil}")
knoten("w2_karte", "interested", "{n} Punkte auf der Karte: deine knappen Stellen und Notizen. Sieh nach.", "{n} points on the map: your close calls and notes. Have a look.")
-- REVIEW6B: "w2_mark_ok" entfernt - die Aktion gibt bei Erfolg nil zurueck, den Satz sagt das
-- Ereignis MARK_GESETZT (phrasen.json). Der Knoten war ein toter Eintrag und haette, wenn ihn
-- jemand verdrahtet, eine zweite Zeile zur selben Sache erzeugt.
knoten("w2_mark_nein", "hmm", "Kein Ziel, oder ein Spieler. Ich markiere nur Ungeheuer.", "No target, or a player. I only mark monsters.")
