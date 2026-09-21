-- Sinne/Welle13a.lua — Welle 13a "Nativ" (0.16.0, 21.09.2026).
--
-- VIER BAUTEILE, DIE ALLE OHNE EIN EINZIGES FREMD-ADDON AUSKOMMEN. Das ist der Grund, warum sie
-- zusammen in einer Datei stehen und warum sie in der Welle "Andockstellen" die ERSTEN sind:
-- docs/recherche/18-andockstellen-2026-09-21.md §0 Nr. 1 sagt es in einem Satz — "der groesste
-- Gewinn kommt nicht von einem Fremd-Addon, sondern von Blizzard". Wenn die Welle nach dieser
-- Datei abgebrochen wuerde, staende sie trotzdem gut da (§4.2 Punkt 1).
--
--   1. QUEST_FERTIG_MEHRERE (neu)  — "drei fertige Quests im Buch".
--      ns.Compat.questLogEintrag(i).complete liegt seit Welle 2 fertig in Core/Compat.lua:471
--      und wird nirgends gezaehlt. Sinne/Quests.lua meldet QUEST_FERTIG je EINZELNER Quest und
--      rechnet die Summe in Q.status() aus — fuer /lyra quests, und wirft sie dann weg.
--      Questie wird dafuer nicht gebraucht; der Shim traegt alle fuenf Clients.
--
--   2. BERUF_GRENZE (bestehendes Ereignis, neuer AUSLOESER) — Rang ohne offenes Fenster.
--      Sinne/Welle4.lua liest den Berufsrang aus dem Handwerks- bzw. Craft-Fenster und hat die
--      Luecke im eigenen Kopf stehen: "dadurch kommt die Zeile nur, wenn das Fenster offen ist.
--      Wer im Laufen Erz abbaut, sieht sie nicht." GetNumSkillLines/GetSkillLineInfo bei
--      SKILL_LINES_CHANGED schliessen genau das (Recherche §1.3, §2.4).
--
--   3. REITTIER_ERSTES (neu) — das erste Reittier. docs/review-bindung-2026-09-20.md §3.4 nennt
--      es die "lohnendste Luecke Nr. 1". Einmal je Charakter, nie nachtraeglich.
--
--   4. GOLD_MEILENSTEIN (neu) — erstmals 100 Gold (und 1000). GetMoney/PLAYER_MONEY.
--
-- WO DIESE DATEI IN DER TOC STEHT: GANZ ZULETZT, hinter Sinne/Welle9.lua. Drei Gruende:
--   * Sie liest ns.Compat (Questlog-Shim) und ns.Regie (abstandRest, dropLog fuer den Nachhol).
--   * Der ns.melde-Wrapper aus Sinne/Persoenlichkeit.lua und der {erinnerung}-Wrapper aus
--     Sinne/Rituale.lua sollen auch um ihre vier Ereignisse liegen — beide legen sich bei
--     PLAYER_LOGIN drueber, also nach dem Laden; wer frueher steht, gewinnt dabei nichts, wer
--     spaeter steht, verliert nichts. Entscheidend ist der dritte Punkt.
--   * Sie haengt sich mit ns.nachAusgabe an die AUSGABE-Kette, um QUEST_FERTIG mitzuhoeren
--     (Muster aus Sinne/Welle4.lua, das dort SKILL mithoert). Diese Kette soll vollstaendig sein.
-- Sie haengt DREI Schluessel an ns.DEFAULTS_ACCOUNT; Core/Init.lua bleibt unberuehrt. Kein
-- OnUpdate, kein Ticker, keine Schleife ausserhalb eines Ereignisses.
--
-- KONTRAKT: kein SendChatMessage, kein RunMacro, kein CastSpell, keine geschuetzte Funktion,
-- kein Netz, keine Fremddaten, keine neue Globale. Jeder Zugriff auf eine Spiel-API steht in
-- pcall und hinter einer Existenzpruefung auf EIN konkretes Feld. Faellt eine API aus, ist diese
-- Datei still — kein Lua-Fehler, keine halbe Zeile — und /lyra status sagt, was fehlt.
--
-- NIE GESCHRIEBEN WIRD: ExpandSkillHeader. Siehe Abschnitt 2, das ist der wichtigste Satz der
-- ganzen Datei.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Welle13a = W
ns.Sinne.Welle13a = W

-- ---------------------------------------------------------------------------------------------
-- Voreinstellungen. Core/Init.lua gehoert in dieser Runde einem anderen Team, darum haengen die
-- Schluessel hier an ns.DEFAULTS_ACCOUNT. Das laeuft auf DATEIEBENE, also lange vor ADDON_LOADED
-- — und genau dort ruft ns.initDB() defaults(). Reihenfolge stimmt (Muster: Sinne/Welle6.lua).
--
-- DREI Kaestchen fuer VIER Bauteile, und der Schnitt ist Absicht: benannt wird nach dem, was die
-- Andockstelle TUT (Regel aus §3), und "Reittier" und "100 Gold" tun dasselbe — sie nennen den
-- einen Meilenstein, den ein Charakter genau einmal erreicht. Wer den einen nicht will, will den
-- anderen auch nicht; zwei Kaestchen waeren eine Unterscheidung ohne Unterschied auf einer Seite,
-- die der Design-Deckel B-5 gerade erst kurz gemacht hat. Die zwei Quest- und Berufs-Schalter
-- bleiben dagegen getrennt: sie haben nichts miteinander zu tun ausser der Welle.
-- ---------------------------------------------------------------------------------------------
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.questStapel == nil then D.questStapel = true end
    if D.berufRangNativ == nil then D.berufRangNativ = true end
    if D.meilensteine == nil then D.meilensteine = true end
end

-- ---------------------------------------------------------------------------------------------
-- Feature-Weiche ZUERST, Interface-Nummer nie (Core/Compat.lua, Kopf). Gefragt wird nach der
-- FUNKTION, nicht nach dem Client: Forever/Camelot (Interface 16001) ist ein Ziel, und dort ist
-- die Frage "gibt es GetSkillLineInfo" die einzige, die sich beantworten laesst.
--
-- Die Weiche faellt beim LADEN. Jede Lesefunktion prueft den Typ TROTZDEM noch einmal im Moment
-- des Aufrufs — eine Attrappe (und ein Fremd-Addon) kann eine Globale zur Laufzeit wegnehmen,
-- und dann soll hier geschwiegen und nicht geworfen werden.
-- ---------------------------------------------------------------------------------------------
local C = ns.Compat
W.F = {
    quests   = (type(C) == "table" and type(C.questAnzahl) == "function"
                and type(C.questLogEintrag) == "function") and true or false,
    skill    = (type(_G.GetNumSkillLines) == "function"
                and type(_G.GetSkillLineInfo) == "function") and true or false,
    reittier = (type(_G.IsMounted) == "function") and true or false,
    gold     = (type(_G.GetMoney) == "function") and true or false,
}

W.QUEST_SCHWELLE   = 3      -- ab so vielen fertigen Quests im Buch faellt ueberhaupt eine Zeile
W.QUEST_VERZUG     = 1.5    -- s Sammelfrist nach QUEST_LOG_UPDATE (wie Sinne/Quests.lua)
W.QUEST_LOGIN_RUHE = 60     -- s nach dem Ladebildschirm: das Questbuch ist noch nicht verlaesslich
W.QUEST_NACH_FERTIG = 8     -- s Abstand zu einer QUEST_FERTIG-Zeile aus Sinne/Quests.lua
W.QUEST_MAX        = 100    -- Muell-Riegel: mehr Eintraege hat kein Questlog
W.SKILL_VERZUG     = 0.5    -- s Sammelfrist nach SKILL_LINES_CHANGED (das Ereignis kommt in Salven)
W.SKILL_MAX        = 200    -- Muell-Riegel fuer GetNumSkillLines
W.GRENZEN = { [75] = true, [150] = true, [225] = true, [300] = true }  -- Lehrling/Geselle/Experte/Kuenstler
W.NACHHOL = 35              -- s: zweiter Versuch fuer Plauder-Zeilen, die der Regie-Abstand frisst
W.GOLD_STUFEN = {           -- in KUPFER. Reihenfolge = Meldereihenfolge.
    { name = "100",  kupfer = 1000000 },
    { name = "1000", kupfer = 10000000 },
}

local function jetzt() return (GetTime and GetTime()) or 0 end
-- an(): nil zaehlt als AN. Vor ns.initDB() gibt ns.Get die Vorgabe zurueck, und die steht oben
-- auf true — ein Ereignis in den ersten Millisekunden nach dem Laden waere sonst still.
local function an(key) return ns.Get(key) ~= false end

local function melde(id, vars)
    if not ns.melde then return false end
    local ok, v = pcall(ns.melde, id, vars)
    return (ok and v) and true or false
end

-- Plauder-Zeile mit EINEM Nachhol (Muster aus Sinne/Welle4.lua und Sinne/Chronik.lua). NUR wenn
-- der Regie-ABSTAND der Grund war — Drossel, Gruppe, Still-Modus und Stummschaltung sind
-- endgueltige Antworten und werden nicht nachgeklopft.
local function meldeNachhol(id, vars, gilt)
    if melde(id, vars) then return true end
    local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
    if not (d and d[2] == id and d[1] == "abstand") then return false end
    local rest = 0
    if ns.Regie and ns.Regie.abstandRest then
        local ok, r = pcall(ns.Regie.abstandRest)
        if ok and type(r) == "number" then rest = r end
    end
    local verzug = math.max(W.NACHHOL, math.min(rest + 1, 180))
    ns.Compat.After(verzug, function()
        if gilt and not gilt() then return end
        melde(id, vars)
    end)
    return false
end

local function imKampf()
    if type(UnitAffectingCombat) ~= "function" then return false end
    local ok, k = pcall(UnitAffectingCombat, "player")
    return (ok and k) and true or false
end
local function inInstanz()
    if type(IsInInstance) ~= "function" then return false end
    local ok, drin = pcall(IsInInstance)
    return (ok and drin) and true or false
end

W.selbsttest = { quests = "?", skill = "?", reittier = "?", gold = "?" }

-- =============================================================================================
-- 1  QUEST_FERTIG_MEHRERE — "drei fertige Quests im Buch"
-- =============================================================================================
-- DIE ZAEHLUNG. Sie geht ausschliesslich ueber ns.Compat (Core/Compat.lua:457/471): C.questAnzahl
-- liefert auf Classic GetNumQuestLogEntries, auf Mainline C_QuestLog.GetNumQuestLogEntries;
-- C.questLogEintrag(i) gibt EINEN einheitlichen Eintrag { titel, level, header, complete, questID }
-- fuer beide Welten. Der Shim normalisiert complete bereits auf einen echten BOOLEAN (die lokale
-- Funktion complete(wert) dort oben) — darum steht hier q.complete == true und nicht ein
-- weichgespueltes "if q.complete then". Ein Client, der 1 statt true liefert, ist schon im Shim
-- abgefangen; ein Client, der "ja" liefert, faellt hier durch, und das ist richtig so.
--
-- WANN GEZAEHLT WIRD, und warum nicht bei jedem QUEST_LOG_UPDATE: das Ereignis feuert in Salven
-- (jeder Ziel-Fortschritt, jede Annahme, jeder Ladebildschirm, mehrfach hintereinander). Gezaehlt
-- wird deshalb in einer Sammelfrist von 1,5 s — dieselbe Zahl und dasselbe geplant-Flag wie in
-- Sinne/Quests.lua, damit beide Module denselben Rhythmus haben und nicht abwechselnd scannen.
--
-- WANN GESPROCHEN WIRD: nur, wenn die Zahl die Schwelle ERREICHT oder danach STEIGT. Das ist der
-- Unterschied zwischen "du hast drei fertige Quests" (ein Moment) und "du hast immer noch drei
-- fertige Quests" (Nerverei). Faellt die Zahl unter die Schwelle — der Spieler hat abgegeben —,
-- wird die Marke zurueckgesetzt, und beim naechsten Aufstieg auf drei gibt es wieder eine Zeile.
-- Die Regie-Drossel "1800" liegt zusaetzlich darueber: hoechstens alle 30 Minuten.
local questGeplant = false
local questStand = nil          -- zuletzt gezaehlte fertige Quests (nil = noch nie gezaehlt)
local questGemeldetBei = 0      -- Zahl, bei der zuletzt gesprochen wurde
local questRuheBis = 0          -- Login-Ruhe
local letzteQuestFertig = -1000 -- Zeitpunkt der letzten QUEST_FERTIG-Ausgabe

-- Gibt es den Questlog auf diesem Client ueberhaupt? Core/Compat.lua:457 antwortet auf ein
-- fehlendes GetNumQuestLogEntries mit 0 und nicht mit nil — fachlich richtig fuer den Shim
-- ("keine Quests"), fuer uns aber zweideutig: "null fertige Quests" und "gar kein Questbuch"
-- sind zwei verschiedene Auskuenfte, und Welle 13b muss sie auseinanderhalten koennen. Die
-- Existenzpruefung steht darum hier, auf EIN konkretes Feld je Welt (Regel 4).
local function questApiDa()
    if type(_G.GetNumQuestLogEntries) == "function" then return true end
    local Q = _G.C_QuestLog
    if type(Q) == "table" and type(Q.GetNumQuestLogEntries) == "function" then return true end
    return false
end
W.questApiDa = questApiDa

local function zaehleFertig()
    if not (type(C) == "table" and type(C.questAnzahl) == "function"
            and type(C.questLogEintrag) == "function") then return nil end
    if not questApiDa() then return nil end
    local ok, n = pcall(C.questAnzahl)
    if not ok then return nil end
    n = tonumber(n)
    if not n then return nil end
    if n <= 0 then return 0 end
    if n > W.QUEST_MAX then n = W.QUEST_MAX end
    local fertig = 0
    for i = 1, n do
        local ok2, q = pcall(C.questLogEintrag, i)
        if ok2 and type(q) == "table" and type(q.titel) == "string" and q.titel ~= ""
           and not q.header and q.complete == true then
            fertig = fertig + 1
        end
    end
    return fertig
end
W.zaehleFertig = zaehleFertig

-- ---------------------------------------------------------------------------------------------
-- DIE SCHNITTSTELLE FUER WELLE 13b (Questie-Abgabeort).
--
--   local n = ns.Welle13a.fertigeQuests()
--
-- Rueckgabe: die Anzahl fertiger Quests im Log als ZAHL, oder nil, wenn der Questlog-Shim auf
-- diesem Client nichts hergibt (dann hat 13b nichts zu rechnen und schweigt ebenfalls).
-- Die Zahl ist der Stand der letzten Zaehlung; wurde noch nie gezaehlt (ganz frueh nach dem
-- Login), zaehlt der Aufruf selbst einmal nach. Er ist damit IMMER beantwortbar und kostet im
-- Normalfall nichts — aber er ist auch nicht gratis, wenn er der erste ist: 13b ruft ihn auf
-- einer Ereignis-Flanke, nicht in einer Schleife.
--
-- WICHTIG fuer 13b: der Zaehler laeuft auch dann mit, wenn das Haekchen "questStapel" AUS ist
-- oder die Zeile gerade nicht kommen darf (Kampf, Instanz, Login-Ruhe, Drossel). Abgeschaltet
-- ist die ZEILE, nicht die Zaehlung — sonst waere 13b von einem Kaestchen abhaengig, das mit
-- dem Abgabeort nichts zu tun hat.
-- ---------------------------------------------------------------------------------------------
function W.fertigeQuests()
    if questStand == nil then questStand = zaehleFertig() end
    return questStand
end

local function questBlick()
    questGeplant = false
    local n = zaehleFertig()
    if n == nil then return end                 -- API fehlt oder wirft: still
    questStand = n                              -- Zaehler laeuft immer mit (siehe W.fertigeQuests)
    if not an("questStapel") then return end
    if n < W.QUEST_SCHWELLE then questGemeldetBei = 0; return end
    if n <= questGemeldetBei then return end    -- nicht gestiegen: kein neuer Moment
    if imKampf() then return end                -- plauder landete sonst auf der Warteliste
    if inInstanz() then return end
    local t = jetzt()
    if t < questRuheBis then return end
    if t - letzteQuestFertig < W.QUEST_NACH_FERTIG then return end
    -- Die Marke wird ERST NACH ERFOLG gesetzt. Haette der Abstand die Zeile gefressen, waere der
    -- Moment sonst still verbraucht und die Zahl muesste erst noch weiter steigen.
    if meldeNachhol("QUEST_FERTIG_MEHRERE", { n = n }, function() return an("questStapel") end) then
        questGemeldetBei = n
    end
end
W.questBlick = questBlick

local function questPlanen()
    if questGeplant then return end
    questGeplant = true
    ns.Compat.After(W.QUEST_VERZUG, function() pcall(questBlick) end)
end

if W.F.quests then
    ns.on("QUEST_LOG_UPDATE", questPlanen)
    ns.on("QUEST_TURNED_IN", questPlanen)
end
ns.on("PLAYER_ENTERING_WORLD", function()
    questRuheBis = jetzt() + W.QUEST_LOGIN_RUHE
    questStand = nil
    if W.F.quests then questPlanen() end
end)

-- =============================================================================================
-- 2  BERUF_GRENZE — der Rang ohne offenes Fenster
-- =============================================================================================
-- WAS SINNE/WELLE4.LUA SCHON TUT, und was hier NICHT noch einmal getan wird: dort liest
-- berufBlick() bei TRADE_SKILL_SHOW/UPDATE und CRAFT_SHOW/UPDATE den Rang aus dem OFFENEN
-- Fenster (GetTradeSkillLine bzw. GetCraftName, dazu ein unbelegter Retail-Zweig) und meldet
-- BERUF_GRENZE mit vars { beruf, wert, key = Beruf .. ":" .. Rang }. Diese Datei aendert daran
-- keine Zeile. Sie legt EINEN zweiten Ausloeser daneben: SKILL_LINES_CHANGED.
--
-- WARUM DAS NICHT DOPPELT MELDET — und das ist keine Absprache, sondern Mechanik: BERUF_GRENZE
-- traegt im Katalog die Drossel "session", und Core/Regie.lua bildet den Drosselschluessel als
-- id .. ":" .. key. Beide Wege melden denselben key (Beruf:Rang), also ist der zweite Versuch
-- in derselben Sitzung ein R.session-Treffer und wird verworfen — mit Grund "drossel", also als
-- NORMALBETRIEB gezaehlt und nicht als Verlust. Wer den key hier aendert, baut die Doppelung
-- ein, die es heute nicht gibt.
--
-- DIE FALLE, DIE AUSDRUECKLICH NICHT GEBAUT WIRD (Recherche §2.4): GetSkillLineInfo ueberspringt
-- Zeilen unter einer EINGEKLAPPTEN Kopfzeile. Das installierte LyraLedger loest das mit
-- ExpandSkillHeader(0) und klappt hinterher zurueck (LyraLedger.lua:41, 54-55). Das ist ein
-- SCHREIBZUGRIFF auf die Oberflaeche des Spielers, und er ist hier tabu — das Wort
-- ExpandSkillHeader kommt in dieser Datei nur in Kommentaren vor, nie in Code. Steht der
-- Beruf eingeklappt im Buch, ist sein Rang unsichtbar, und eine Wissensluecke ist kein Messwert:
-- dann schweigt Lyra. Technisch ist dafuer nichts zu tun — die Zeile taucht in der Aufzaehlung
-- schlicht nicht auf, und was nicht auftaucht, kann keine Grenze erreichen.
--
-- DIE SKILL-WACHE AUS WELLE 4 GILT HIER BEWUSST NICHT, und das ist eine Korrektur an Recherche
-- §2.4. Dort steht als Schweige-Bedingung: "SKILL hat in den letzten 10 s gesprochen (die Wache
-- aus Welle 4 bleibt)". Die Wache haelt in Welle 4 nur BERUF_ERSTER zurueck, nicht die Grenze —
-- und das aus einem Grund, den man nachrechnen kann: Sinne/Alltag.lua meldet SKILL nur bei
-- wert % 25 == 0 (Alltag.lua:348-353), und 75, 150, 225 und 300 sind ALLE durch 25 teilbar. Eine
-- 10-Sekunden-Wache gegen SKILL wuerde BERUF_GRENZE also nicht gelegentlich, sondern IMMER
-- verschlucken — das Bauteil waere tot. Stattdessen greift die normale Regie: SKILL ist selbst
-- plauder, verbraucht den Plauder-Abstand, BERUF_GRENZE faellt mit Grund "abstand" durch und
-- kommt ueber meldeNachhol dreissig Sekunden spaeter. Zwei Saetze im Abstand einer halben Minute,
-- die etwas Verschiedenes sagen ("Bergbau 150" / "Das Buch ist voll") — keine Doppelung.
local skillGeplant = false
local berufStand = {}       -- [Beruf] = zuletzt gesehener Rang (nur Sitzung, nur fuer /lyra status)
W.berufe = berufStand

-- Liest ALLE sichtbaren Berufs-/Waffenzeilen. Rueckgabe: Liste { name, rank, max } oder nil,
-- wenn die API fehlt oder wirft. Eine LEERE Liste ist kein Fehler — sie ist der eingeklappte
-- Fall und bedeutet dasselbe wie "nichts zu sagen".
local function berufeLesen()
    if not (type(_G.GetNumSkillLines) == "function" and type(_G.GetSkillLineInfo) == "function")
        then return nil end
    local ok, n = pcall(_G.GetNumSkillLines)
    if not ok then return nil end
    n = tonumber(n)
    if not n then return nil end
    if n <= 0 then return {} end
    if n > W.SKILL_MAX then n = W.SKILL_MAX end
    local out = {}
    for i = 1, n do
        -- GetSkillLineInfo(i) -> name, isHeader, isExpanded, rank, numTempPoints, modifier, maxRank, ...
        local ok2, name, isHeader, _, rank, _, _, maxRank = pcall(_G.GetSkillLineInfo, i)
        if ok2 and type(name) == "string" and name ~= "" and not isHeader then
            local r, m = tonumber(rank), tonumber(maxRank)
            -- Muell-Riegel: negative Raenge, Rang ueber dem Deckel und maxRank 0 gibt es nicht.
            if r and m and m > 0 and r >= 0 and r <= m then
                out[#out + 1] = { name = name, rank = r, max = m }
            end
        end
    end
    return out
end
W.berufeLesen = berufeLesen

local function berufBlick()
    skillGeplant = false
    local liste = berufeLesen()
    if liste == nil then W.selbsttest.skill = "keine API"; return end
    W.selbsttest.skill = #liste .. " sichtbare Zeilen"
    if not an("berufRangNativ") then return end
    if imKampf() then return end            -- plauder landete sonst auf der Warteliste
    for _, b in ipairs(liste) do
        berufStand[b.name] = b.rank
        if W.GRENZEN[b.max] and b.rank >= b.max then
            -- Derselbe key wie in Sinne/Welle4.lua:196. Das ist die ganze Doppelungs-Sperre.
            meldeNachhol("BERUF_GRENZE", { beruf = b.name, wert = b.rank,
                                           key = b.name .. ":" .. b.rank },
                         function() return an("berufRangNativ") end)
        end
    end
end
W.berufBlick = berufBlick

local function skillPlanen()
    if skillGeplant then return end
    skillGeplant = true
    ns.Compat.After(W.SKILL_VERZUG, function() pcall(berufBlick) end)
end

if W.F.skill then
    ns.on("SKILL_LINES_CHANGED", skillPlanen)
end

-- =============================================================================================
-- 3  REITTIER_ERSTES — das erste Mal im Sattel
-- =============================================================================================
-- ERKENNUNG, und warum nicht ueber die Reittier-Sammlung: C_MountJournal gibt es auf Era nicht
-- und auf Forever ist es unbelegt. IsMounted() dagegen ist eine Globale, die in jedem gelesenen
-- Era-Addon vorkommt (Recherche §1.3, Beleg $A/WeakAuras/Prototypes.lua:11292). Gefragt wird
-- darum nach dem ZUSTAND, nicht nach dem Besitz — "du sitzt oben" ist ohnehin die Beobachtung,
-- die ein Mensch machen wuerde, und nicht "du hast ein Reittier gekauft".
--
-- ZWEI FLANKEN, und beide sind noetig:
--   * PLAYER_MOUNT_DISPLAY_CHANGED ist die saubere Flanke. Sie gibt es auf Mainline und Forever;
--     auf Era gibt es sie nicht. ns.on() wickelt RegisterEvent in pcall (Core/Init.lua:189) —
--     ein unbekanntes Ereignis kostet dort also nichts und wirft nichts.
--   * UNIT_AURA("player") ist der Era-Weg: aufsitzen heisst, eine Aura zu bekommen. Das Ereignis
--     feuert oft, deshalb steht die BILLIGSTE Pruefung ganz vorn (ein Tabellenzugriff auf das
--     Charakter-Flag) und die teure (IsMounted) dahinter. Ist das Flag gesetzt, kostet ein
--     UNIT_AURA hier zwei Vergleiche.
--
-- DIE GESTALTWANDLER-AUSNAHME. Auf Mainline zaehlt die Reisegestalt des Druiden als "mounted",
-- auf Classic nicht. Forever ist Vanilla-Inhalt mit Mainline-API — also genau der Client, auf dem
-- ein Druide sonst mit 30 die Zeile "du sitzt oben" bekaeme, ohne ein Reittier zu besitzen. Wer
-- gerade verwandelt ist, wird darum uebersprungen. Das kostet einen Druiden hoechstens, dass die
-- Zeile erst beim naechsten echten Aufsitzen faellt; die Alternative waere eine falsche Zeile,
-- und die ist schlimmer als eine spaete (dieselbe Begruendung wie bei C.F.klassischeAusruestung).
--
-- EINMAL JE CHARAKTER, UND NIE NACHTRAEGLICH. Das Flag liegt in den CHARAKTER-SavedVariables
-- (ns.char.reittierErstes), nicht im Konto: der naechste Hardcore-Charakter soll den Moment
-- wieder haben. Beim Betreten der Welt wird eine GRUNDLINIE gezogen — wer bereits im Sattel
-- sitzt (Neuladen unterwegs), bekommt das Flag STILL gesetzt und hoert die Zeile nie. Das ist
-- Absicht: "das erste Mal" ist eine Flanke, und eine Flanke, die man nicht gesehen hat, erzaehlt
-- man nicht nachtraeglich.
-- Rueckgabe absichtlich DREIWERTIG: true (sitzt oben), false (zu Fuss), nil (weiss nicht).
-- "Weiss nicht" ist jeder Wert, der kein sauberes Ja oder Nein ist - eine Attrappe oder ein
-- umgebauter Client, der "ja" oder eine Tabelle liefert, darf nicht als "beritten" durchgehen.
-- Genau dieser Fall (ein wahrheitswertig WAHRER Muell-Wert) ist der einzige, den ein blosses
-- "m and true or false" nicht faengt, und er wuerde die eine Zeile dieses Charakters verbrennen.
local function istBeritten()
    if type(_G.IsMounted) ~= "function" then return nil end
    local ok, m = pcall(_G.IsMounted)
    if not ok then return nil end
    if m == true or m == 1 then return true end
    if m == false or m == nil or m == 0 then return false end
    return nil
end
W.istBeritten = istBeritten

local function verwandelt()
    if type(_G.GetShapeshiftForm) ~= "function" then return false end
    local ok, f = pcall(_G.GetShapeshiftForm)
    return (ok and tonumber(f) or 0) > 0
end

local function reittierFlagge()
    return (type(ns.char) == "table" and ns.char.reittierErstes) and true or false
end

local function reittierGrundlinie()
    if type(ns.char) ~= "table" then return end
    if ns.char.reittierErstes then return end
    if istBeritten() == true then
        ns.char.reittierErstes = true
        ns.debug("W13A: beim Betreten schon beritten - Reittier-Zeile still abgehakt")
    end
end

local function reittierBlick(unit)
    if unit ~= nil and unit ~= "player" then return end     -- UNIT_AURA fremder Einheiten
    if reittierFlagge() then return end
    if not an("meilensteine") then return end
    if istBeritten() ~= true then return end
    if verwandelt() then return end
    if type(ns.char) ~= "table" then return end             -- vor ns.initDB(): nichts merken, nichts sagen
    if imKampf() then return end
    -- Flag ERST NACH ERFOLG. Wird die Zeile vom Still-Modus oder vom Abstand gefressen, bleibt
    -- der Moment offen und kommt beim naechsten Aufsitzen wieder - besser als einmal still.
    if meldeNachhol("REITTIER_ERSTES", nil, function()
            return an("meilensteine") and not reittierFlagge()
        end) then
        ns.char.reittierErstes = true
    end
end
W.reittierBlick = reittierBlick

-- REVIEW13: UNIT_AURA feuert im Kampf mehrmals je Sekunde (jeder Tick, jedes Ab- und Auflaufen
-- eines Buffs). Solange das Charakter-Flag NOCH NICHT steht - also den ganzen Weg von Stufe 1
-- bis zum ersten Reittier, die laengste Zeit eines Hardcore-Charakters - kam bisher bei JEDEM
-- dieser Ereignisse ein pcall(IsMounted) dazu. Das ist keine Rechenspitze, aber es ist Arbeit
-- ohne Drossel an dem Ereignis, das in diesem Addon am haeufigsten feuert (Kontrakt Nr. 7).
-- Ein halbe-Sekunde-Takt reicht vollkommen: aufsitzen dauert laenger, und die saubere Flanke
-- (PLAYER_MOUNT_DISPLAY_CHANGED auf Mainline/Forever) laeuft ungedrosselt weiter.
W.AURA_TAKT = 0.5
local auraZuletzt = -1000
local function reittierAura(unit)
    if unit ~= nil and unit ~= "player" then return end
    if reittierFlagge() then return end             -- billigster Test zuerst: ein Tabellenlesen
    local t = jetzt()
    if t - auraZuletzt < W.AURA_TAKT then return end
    auraZuletzt = t
    reittierBlick(unit)
end

if W.F.reittier then
    ns.on("PLAYER_MOUNT_DISPLAY_CHANGED", reittierBlick)
    ns.onUnit("UNIT_AURA", "player", reittierAura)
    ns.on("PLAYER_ENTERING_WORLD", function()
        ns.Compat.After(0, function() pcall(reittierGrundlinie) end)
    end)
end

-- =============================================================================================
-- 4  GOLD_MEILENSTEIN — erstmals hundert Gold
-- =============================================================================================
-- EINE ZAHL, SONST NICHTS (Regel 2). Genannt wird der Meilenstein (100 bzw. 1000), nicht der
-- Kontostand: "du hast 107 Gold und 43 Silber" waere eine Ablesung, keine Beobachtung. Der
-- zweite Meilenstein kostet dabei KEINE zusaetzliche Zeile mit Zahl — beide laufen ueber
-- dasselbe Ereignis und dieselben vier Zeilen, {gold} traegt einmal die 100 und einmal die 1000.
-- Mehr als zwei Stufen gibt es bewusst nicht: ab 1000 Gold ist Geld kein Meilenstein mehr,
-- sondern ein Zustand, und Zustaende kommentiert Lyra nicht.
--
-- C.zahl() statt tonumber(): auf Mainline-Clients koennen Rueckgabewerte "secret values" sein
-- (Core/Compat.lua:223). GetMoney des SPIELERS ist das nach heutigem Stand nicht, aber die Wache
-- kostet nichts und ist die Hausregel dieses Projekts.
--
-- GRUNDLINIE WIE BEIM REITTIER: wer beim Betreten der Welt schon ueber einer Stufe liegt,
-- bekommt sie still abgehakt. "Erstmals" ist eine Flanke.
local function geldLesen()
    if type(_G.GetMoney) ~= "function" then return nil end
    local ok, g = pcall(_G.GetMoney)
    if not ok then return nil end
    local z = (C and C.zahl) and C.zahl(g) or (type(g) == "number" and g or nil)
    if type(z) ~= "number" or z < 0 then return nil end
    return z
end
W.geldLesen = geldLesen

local function goldFlaggen()
    if type(ns.char) ~= "table" then return nil end
    if type(ns.char.goldMeilenstein) ~= "table" then ns.char.goldMeilenstein = {} end
    return ns.char.goldMeilenstein
end

local function goldBlick(still)
    local f = goldFlaggen()
    if not f then return end
    local geld = geldLesen()
    if geld == nil then return end
    if not still and not an("meilensteine") then return end
    for _, stufe in ipairs(W.GOLD_STUFEN) do
        if not f[stufe.name] and geld >= stufe.kupfer then
            if still then
                f[stufe.name] = true
            elseif imKampf() then
                return                      -- plauder landete sonst auf der Warteliste
            elseif meldeNachhol("GOLD_MEILENSTEIN", { gold = stufe.name, key = stufe.name },
                       function() return an("meilensteine") end) then
                f[stufe.name] = true
            end
        end
    end
end
W.goldBlick = goldBlick

if W.F.gold then
    ns.on("PLAYER_MONEY", function() goldBlick(false) end)
    ns.on("PLAYER_ENTERING_WORLD", function()
        ns.Compat.After(0, function() pcall(goldBlick, true) end)
    end)
end

-- =============================================================================================
-- /lyra status
-- =============================================================================================
-- Regel 4 des gemeinsamen Auftrags: faellt eine Quelle aus, sagt der Status "fehlt". Hier steht
-- je Bauteil EINE Zeile, und sie sagt entweder eine Zahl (es laeuft) oder warum nicht.
function W.status()
    local d = (ns.sprache() == "de")
    local out = {}

    local n = W.fertigeQuests()
    out[#out + 1] = (d and "Fertige Quests (nativ): %s" or "Finished quests (native): %s"):format(
        (not W.F.quests) and (d and "fehlt (kein Questlog-Zugang)" or "missing (no quest log access)")
        or (n == nil) and (d and "fehlt (Shim gibt nichts her)" or "missing (shim returns nothing)")
        or ((d and "%d im Buch, Schwelle %d, Zeile %s" or "%d in the log, threshold %d, line %s")
            :format(n, W.QUEST_SCHWELLE, an("questStapel") and (d and "an" or "on") or (d and "aus" or "off"))))

    local liste = W.F.skill and berufeLesen() or nil
    out[#out + 1] = (d and "  Berufsrang ohne Fenster: %s" or "  Profession rank without window: %s"):format(
        (not W.F.skill) and (d and "fehlt (GetSkillLineInfo)" or "missing (GetSkillLineInfo)")
        or (liste == nil) and (d and "fehlt (API wirft)" or "missing (API throws)")
        or (#liste == 0) and (d and "nichts sichtbar (Kopfzeilen eingeklappt) - das ist kein Fehler"
                                or "nothing visible (headers collapsed) - not an error")
        or ((d and "%d Zeilen gelesen, Grenzen 75/150/225/300" or "%d lines read, ceilings 75/150/225/300")
            :format(#liste)))

    local ber = istBeritten()
    out[#out + 1] = (d and "  Erstes Reittier: %s" or "  First mount: %s"):format(
        (not W.F.reittier) and (d and "fehlt (kein IsMounted)" or "missing (no IsMounted)")
        or reittierFlagge() and (d and "schon abgehakt" or "already done")
        or (ber == nil) and (d and "fehlt (IsMounted wirft)" or "missing (IsMounted throws)")
        or (d and "offen (gerade %s)" or "open (currently %s)"):format(
            ber and (d and "beritten" or "mounted") or (d and "zu Fuss" or "on foot")))

    local f = goldFlaggen()
    local geld = geldLesen()
    out[#out + 1] = (d and "  Gold-Meilenstein: %s" or "  Gold milestone: %s"):format(
        (not W.F.gold) and (d and "fehlt (kein GetMoney)" or "missing (no GetMoney)")
        or (geld == nil) and (d and "fehlt (GetMoney gibt nichts Lesbares)" or "missing (GetMoney unreadable)")
        or (function()
            local offen = {}
            for _, s in ipairs(W.GOLD_STUFEN) do if not (f and f[s.name]) then offen[#offen + 1] = s.name end end
            if #offen == 0 then return d and "beide abgehakt" or "both done" end
            return (d and "offen: %s" or "open: %s"):format(table.concat(offen, ", "))
        end)())
    return out
end

-- =============================================================================================
-- QUEST_FERTIG mithoeren (Muster: Sinne/Welle4.lua haengt so SKILL ab)
-- =============================================================================================
-- Die Summen-Zeile darf nicht unmittelbar auf die Einzel-Zeile folgen ("Quest fertig!" - "Du hast
-- drei fertige Quests"). Das ist keine Drossel-, sondern eine Reihenfolgefrage: beide Zeilen sind
-- wahr, aber zusammen sind sie eine Doppelung. ns.nachAusgabe laeuft NACH jeder ausgegebenen
-- Zeile, also genau dann, wenn der Spieler sie wirklich gehoert hat - ein verworfener Versuch
-- setzt die Sperre nicht.
ns.nachAusgabe(function(id)
    if id == "QUEST_FERTIG" then letzteQuestFertig = jetzt() end
end)
