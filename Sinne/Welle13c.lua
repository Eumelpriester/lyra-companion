-- Sinne/Welle13c.lua — Welle 13c "Details + Rarity" (21.09.2026).
--
-- Zwei Andockstellen, die nichts miteinander zu tun haben ausser der Welle, und deshalb in zwei
-- klar getrennten Abschnitten stehen:
--
--   1. TOD_HERGANG — DIE LETZTEN SEKUNDEN (Recherche 18 §2.7, Plan §4.1 Nr. 5).
--      Beim EIGENEN Tod liest Lyra aus Details! den eigenen Todes-Eintrag und macht daraus
--      EINE menschliche Beobachtung. Keine Zahlenreihe, kein DPS, kein Prozent - das steht in
--      Details' eigenem Fenster und dort besser (Regel 1 und 2).
--
--   2. SAMMEL_AUSDAUER — DER ZAEHLER, DEN NIEMAND MEHR SEHEN WILL (§2.8, §4.1 +0).
--      Rarity zaehlt die Versuche. Lyra sagt nicht die Chance, sondern was die Zahl mit einem
--      macht - an drei runden Marken, einmal je Marke und Gegenstand.
--
-- ---------------------------------------------------------------------------------------------
-- 1  TOD_HERGANG: WARUM UEBERHAUPT
-- ---------------------------------------------------------------------------------------------
-- docs/review-bindung-2026-09-20.md §2.5: GEFALLEN und ERBE_TOD haben bis heute NULL Zeilen
-- (im ausgelieferten docs/phrasen.json nachgeprueft). Welle 11a hat den NACHRUF hinter den
-- 60-s-Riegel gesetzt - er sagt, WER du warst. Was fehlt, ist der Hergang: WAS passiert ist.
-- Details! fuehrt genau das ohnehin mit, der Autor sieht Fremdzugriff ausdruecklich vor
-- (Details/API.txt liegt dem Paket bei), und Lyra muss dafuer keinen einzigen Combat-Log-Haken
-- setzen.
--
-- WO DIE ZEILE IN DER KETTE STEHT, UND WARUM GENAU DA
-- --------------------------------------------------
--   t+0      PLAYER_DEAD. Core/Regie.lua setzt R.todRiegelBis = jetzt() + 60 und laesst nur
--            noch klasse "still" durch. GEFALLEN (still) und ERBE_TOD (still) laufen hier.
--            Sinne/Erbe.lua fragt ausserdem per Blase nach den letzten Worten - absichtlich an
--            der Regie vorbei, sonst frisst der Riegel sie.
--   t+2,5    DIESE DATEI LIEST. Nicht weil sie da schon reden wollte, sondern weil die Daten
--            spaeter weg sein koennen: Details schliesst das Segment erst nach dem Kampfende
--            ab (LESE_VERZUG in Sinne/Details.lua ist dafuer seit Welle 3 da), und beim
--            naechsten Kampf zeigt GetCurrentCombat() ein anderes Segment. Gelesen wird frueh,
--            geredet wird spaet. Das Ergebnis geht sofort in den Erbe-Eintrag (unten).
--   t+62     TOD_HERGANG. Zwei Sekunden hinter dem Riegel - das reicht, weil der Riegel exakte
--            GetTime-Arithmetik ist und C_Timer.After daran haengt; fuenf Sekunden Luft wie
--            beim Nachruf braucht es nur, wenn davor noch etwas rechnen muss, und hier ist
--            alles seit Sekunde 2,5 fertig.
--   t+65     ERBE_NACHRUF (Sinne/Erbe.lua, NACHRUF_AB = 65).
--
-- DIE DREI SEKUNDEN SIND KEIN VERSEHEN, UND SIE HABEN EINE FOLGE, DIE HIER HINGEHOERT:
-- der Plauder-Abstand betraegt bei Preset "normal" 30 s. Sagt TOD_HERGANG bei 62, faellt
-- ERBE_NACHRUF bei 65 mit dem Grund "abstand" - und genau dafuer hat Sinne/Erbe.lua seit
-- Welle 11a meldeNachhol(): der Nachruf kommt dann rund 35 s spaeter, also bei etwa t+100, die
-- Worte bei etwa t+134. Das ist ueberprueft (w13c_harness.lua, Szene S4) und es ist die
-- richtige Reihenfolge: erst was passiert ist, dann wer du warst. Wer sie umdrehen will, setzt
-- SAG_AB auf 97 - dann kommt der Hergang anderthalb Minuten nach dem Tod, und der Nachruf hat
-- den Gegner schon genannt.
--
-- KEINE DOPPELUNG MIT DEM NACHRUF (Regel 1)
-- -----------------------------------------
-- ERBE_NACHRUF hat eine eigene Zeile mit {gegner} ("{gegner} also. Ich nenne ihn nicht
-- schuld."). Darum waehlt diese Datei ihre eigene {gegner}-Zeile NUR, wenn der Erbe-Eintrag
-- noch gar keinen gegner traegt - dann kann der Nachruf ihn auch nicht nennen. Zweimal
-- derselbe Name hintereinander waere genau die Doppelung, die Regel 1 verbietet.
--
-- FREMDE SPIELER (Regel 6) - DER KERN DIESER DATEI
-- -----------------------------------------------
-- deathevents traegt in Feld 6 den Namen der Quelle. Das kann ein Spielername sein. Drei Riegel:
--   (1) Gelesen werden AUSSCHLIESSLICH Schadens-Eintraege (Feld 1 == true). Die Heil-Eintraege,
--       in denen in einer Gruppe die Mitspieler stehen, werden nie angefasst.
--   (2) Ein Name kommt nur in eine Zeile, wenn er auf einer POSITIVLISTE steht, die anderswo
--       schon belegt ist: das Chronik-Bestiarium (Sinne/Chronik.lua - enthaelt ausschliesslich
--       Creature-GUIDs) und der "gegner" des eigenen Erbe-Eintrags (Sinne/Erbe.lua - dort liegt
--       die UnitIsPlayer-Sperre davor). Steht der Toeter nicht darauf, wird die Zeile mit
--       {gegner} NICHT GEBILDET.
--   (3) KEIN Bindestrich-Filter. Der erste Entwurf hatte einen ("Name-Realm heisst Spieler"), und
--       er war falsch: die halbe deutsche Gegnerliste heisst so ("Gnoll-Wegelagerer",
--       "Defias-Spaeher"). Eine Heuristik, die raet, ist hier schlechter als gar keine - die
--       Positivliste verlangt einen BELEG, und das ist die staerkere Zusage.
-- Was bleibt, ist eine ZAHL ("drei auf einmal"). Gezaehlt wird, was auf MICH eingeschlagen hat;
-- die Zahl traegt keinen Namen und sagt ueber niemanden etwas aus ausser ueber den eigenen Tod.
--
-- DIE BEOBACHTUNG, UND ZWAR GENAU EINE
-- ------------------------------------
-- Rangfolge (die erste, die passt, gewinnt; passt keine, schweigt Lyra):
--   1. "schnell"  hoechstens SCHNELL_MAX Treffer und vorher noch fast volles Leben -> {schlaege}
--   2. "mehrere"  mindestens MEHRERE_AB verschiedene Angreifer                     -> {n}
--   3. "lange"    mindestens LANGE_SEK unter der Haelfte                           -> keine vars
--   4. "letzter"  ein freigegebener NPC-Name, und das Erbe hat noch keinen gegner   -> {gegner}
-- Bei 1, 2 und 4 steht vars.nurPlatzhalter = true, damit Core/Regie.lua die drei platzhalter-
-- freien Zeilen NICHT zieht: "Du warst schon lange unter der Haelfte" waere nach zwei Schlaegen
-- aus vollem Leben schlicht falsch.
--
-- WAS IN DEN ERBE-EINTRAG GESCHRIEBEN WIRD, DAMIT DER NACHFOLGER ES SIEHT
-- ----------------------------------------------------------------------
-- Der Erbe-Eintrag ist die einzige KONTO-weite Ablage, die der naechste Charakter ueberhaupt zu
-- sehen bekommt (Halle der Gefallenen, ERBE_STERBEORT). Diese Datei legt dort EIN neues,
-- rein additives Feld ab: e.hergang = { v, art, n, gegner }. Gelesen wird ueber ns.Erbe.liste(),
-- also ueber die bestehende Schnittstelle; Sinne/Erbe.lua wird NICHT angefasst. Geschrieben wird
-- nur in den EIGENEN Eintrag, nur einmal, und nie ein Name, der nicht durch die Positivliste
-- gekommen ist. Sauberer waere ein Setzer in Sinne/Erbe.lua (E.hergangSetzen/E.hergangVon) -
-- der steht als Merge-Baustein im Bericht, gehoert aber dieser Runde nicht.
--
-- ---------------------------------------------------------------------------------------------
-- 2  SAMMEL_AUSDAUER
-- ---------------------------------------------------------------------------------------------
-- Rarity.db.profile.groups[gruppe][gegenstand] mit .attempts, .found, .enabled, .session.attempts
-- (Rarity/Core/GUI.lua:76-157). Callbacks gibt es nicht, also Polling - aber nur auf Ereignis
-- und mit Mindestabstand, nie in OnUpdate.
-- Gesagt wird an drei runden Marken (100, 250, 500) und nur, wenn der Zaehler NOCH DICHT an der
-- Marke steht (FRISCH). Wer Lyra erst bei 480 Versuchen installiert, hoert nicht "250 Versuche" -
-- das waere eine falsche Zahl, und Regel 2 sagt: die Zahl muss die Beobachtung sein. Verpasste
-- Marken werden still abgehakt.
-- Still, wenn: Rarity fehlt · im Kampf · tot · das Stueck ist gefunden · in Rarity abgeschaltet
-- (.enabled == false - wer es dort ausgeblendet hat, will nicht daran erinnert werden) · der
-- Zaehler ist keine brauchbare Zahl. Nie eine Chance, nie ein Erwartungswert.
--
-- ---------------------------------------------------------------------------------------------
-- KONTRAKT
-- ---------------------------------------------------------------------------------------------
-- Kein SendChatMessage, kein Makro, kein Zauber, kein Netz, keine geschuetzte Funktion, kein
-- OnUpdate, keine neue Globale. In ein fremdes Addon wird NICHTS geschrieben (Regel 5): keine
-- Feldzuweisung an Details oder Rarity, kein hooksecurefunc, kein Nachladen. Jede Fremd-Beruehrung
-- steht hinter einer Existenzpruefung auf EIN konkretes Feld UND in pcall (Regel 4); faellt sie
-- aus, schweigt Lyra, /lyra status sagt "fehlt", und es erscheint kein Lua-Fehler.
-- Fremd-API (nur lesend, Belege aus dem installierten Addon):
--   combat = Details:GetCurrentCombat()             Details/classes/container_segments.lua:39
--   deaths = combat:GetDeaths()                     Details/API.txt:174
--   name, class, deathTime, deathCombatTime, timeString, maxHealth, deathEvents, lastCooldown
--        = Details:UnpackDeathTable(t)              Details/API.txt:242-244, functions/util.lua:771
--   Eintrag in deathEvents (Details/core/parser.lua:1205-1230, Doku-Block :4772-4782):
--        [1] true = Schaden / false = Heilung / ZAHL = etwas anderes
--        [2] spellId   [3] Betrag   [4] Zeit   [5] Leben NACH dem Ereignis (0..1)
--        [6] Name der Quelle   [7] absorbiert   [8] Schule   [10] Overkill
--
--   REVIEW13, zwei Korrekturen an diesem Kommentar (der CODE war beide Male schon richtig,
--   der Kommentar nicht - und ein falscher Kommentar ist teuer, weil ihn glaubt, wer die
--   Stelle spaeter anfasst):
--     * [1] ist NICHT "true/false/String". Details legt in dieselbe Liste auch ZAHLEN:
--       2 = Kampfwiederbelebung (parser.lua:4573), 3 = letzter Verteidigungs-Cooldown
--       (parser.lua:4894, mit [3]=0 und [5]=0, ans ENDE angehaengt), 6 = Zauber des Gegners
--       (parser.lua:4875). Ein "if ev[1] then" haette alle drei als SCHADEN gezaehlt, mit
--       Betrag 0 und Leben 0 % - also "drei auf einmal", wo einer stand. W.auswerten fragt
--       ev[1] == true, und genau deshalb steht es so da.
--     * [4] ist NICHT die GetTime-Uhr, sondern die UNIX-Zeit aus CombatLogGetCurrentEventInfo
--       (parser.lua:7042/7051, Doku :4896). Das ist folgenlos, weil in dieser Datei NUR
--       Differenzen gerechnet werden und die zweite Zahl (todZeit = deathTable[2],
--       util.lua:772) aus derselben Uhr kommt. Wer hier je GetTime() gegenrechnet, bekommt
--       eine Differenz von 1,7 Milliarden Sekunden. Die Sekunden-in-den-Kampf-Zahl waere die
--       VIERTE Rueckgabe von UnpackDeathTable (dead_at), nicht diese.
--   Details.playername                              Details/core/parser.lua:6700-6707
--   Rarity.db.profile.groups[g][i].attempts/.found/.enabled/.session.attempts   Rarity/Core/GUI.lua:76-157
-- Blizzard-API (nur lesend): GetTime, UnitName, GetRealmName, UnitIsDeadOrGhost,
--   UnitAffectingCombat, IsInGroup/IsInRaid.
-- Events: PLAYER_DEAD, PLAYER_ALIVE, PLAYER_UNGHOST, PLAYER_ENTERING_WORLD,
--   PLAYER_REGEN_ENABLED, LOOT_CLOSED.
-- Speicher: ns.char.sammelMarken (Charakter) und das additive Feld .hergang im eigenen
--   Erbe-Eintrag (Konto). Kein neuer SavedVariables-Wurzelschluessel, Core/Init.lua bleibt
--   unberuehrt (beides lazy angelegt, Muster aus Sinne/Karte2.lua).
--
-- TOC: GANZ ZULETZT, hinter Sinne/Welle9.lua. Drei Gruende stehen im Bericht; der harte ist,
-- dass der PLAYER_DEAD-Handler dieser Datei NACH denen von Sinne/Chronik.lua und Sinne/Erbe.lua
-- laufen muss - sonst gibt es den Erbe-Eintrag noch nicht, in den geschrieben wird.
local ADDON, ns = ...
local W = {}
ns.Welle13c = W
ns.Sinne = ns.Sinne or {}
ns.Sinne.Welle13c = W

-- =============================================================================================
-- Schalter. Angehaengt an ns.DEFAULTS_ACCOUNT beim LADEN der Datei, also lange vor ns.initDB();
-- Core/Init.lua bleibt unberuehrt (Muster aus Sinne/Welle4.lua, Welle6.lua, Welle8.lua, Karte2).
-- Benannt nach dem, was sie tun, nicht nach dem Fremd-Addon: wer Details deinstalliert, soll
-- nicht nach einem Haekchen namens "Details" suchen muessen.
-- =============================================================================================
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.todHergang == nil then D.todHergang = true end
    if D.sammelAusdauer == nil then D.sammelAusdauer = true end
end

W.LESE_VERZUG  = 2.5    -- s nach dem Tod: dann ist Details' Segment abgeschlossen
W.SAG_AB       = 62     -- s nach dem Tod: 2 s hinter dem 60-s-Riegel, 3 s vor dem Nachruf
W.FENSTER      = 10     -- s: "die letzten Sekunden". Details schneidet selbst bei 10 (CutDeathEventsByTime)
W.SCHNELL_MAX  = 3      -- hoechstens so viele Treffer -> "so schnell ging das"
W.SCHNELL_VON  = 0.80   -- und vorher mindestens so viel Leben
W.MEHRERE_AB   = 3      -- ab so vielen verschiedenen Angreifern -> "auf einmal"
W.LANGE_SEK    = 8      -- so lange unter der Haelfte -> "das kam langsam"
W.HALB         = 0.5
W.MIN_EREIGNIS = 2      -- unter so vielen brauchbaren Eintraegen wird ueber den Verlauf nichts behauptet

W.MARKEN       = { 100, 250, 500 }
W.FRISCH       = 25     -- Versuche: so dicht muss der Zaehler noch an der Marke stehen
W.SCAN_ABSTAND = 60     -- s zwischen zwei Rarity-Durchlaeufen
W.MAX_PRUEF    = 4000   -- Notbremse gegen eine zerschossene Rarity-Tabelle

local function jetzt() return (GetTime and GetTime()) or 0 end
local function de() return ns.sprache() == "de" end
local function tot() return (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) and true or false end
local function imKampf() return (UnitAffectingCombat and UnitAffectingCombat("player")) and true or false end

local function zahl(v)
    v = tonumber(v)
    if not v or v ~= v then return nil end          -- v ~= v faengt NaN
    return v
end

-- =============================================================================================
-- 1  TOD_HERGANG
-- =============================================================================================

-- Existenzpruefung auf KONKRETE Felder, nie nur type(X) == "table" (Regel 4). Und selbst das
-- LESEN eines Feldes steht in pcall: ein Fremd-Addon mit einem __index-Metatable, das wirft,
-- ist kein Hirngespinst (der Pruefstand baut genau das nach) - und ein Lua-Fehler beim blossen
-- Nachsehen, ob der Nachbar da ist, waere der peinlichste Ausfall von allen.
local function detailsDa()
    local ok, da = pcall(function()
        local D = _G.Details
        return (type(D) == "table" and type(D.GetCurrentCombat) == "function"
                and type(D.UnpackDeathTable) == "function") and true or false
    end)
    return (ok and da) and true or false
end
W.detailsDa = detailsDa

-- Eigene Schreibweisen des eigenen Namens. Details haengt auf manchen Realms "-Realm" an
-- (parser.lua:6700) - dieselbe Loesung wie in Sinne/Details.lua.
local function eigeneNamen()
    local liste = {}
    local D = _G.Details
    if type(D) == "table" and type(D.playername) == "string" and D.playername ~= "" then
        liste[#liste + 1] = D.playername
    end
    local n = UnitName and UnitName("player")
    if type(n) == "string" and n ~= "" then
        liste[#liste + 1] = n
        local r = GetRealmName and GetRealmName()
        if type(r) == "string" and r ~= "" then liste[#liste + 1] = n .. "-" .. r end
    end
    return liste
end

local function istEigenerName(name)
    if type(name) ~= "string" or name == "" then return false end
    for _, n in ipairs(eigeneNamen()) do if n == name then return true end end
    -- "Held-Realm" gegen "Held": Details schreibt beides, je nach Realm-Lage.
    local ohne = name:match("^([^%-]+)%-") or name
    for _, n in ipairs(eigeneNamen()) do
        if n == ohne or (n:match("^([^%-]+)%-") or n) == ohne then return true end
    end
    return false
end

-- Der eigene Eintrag in der Erbe-Liste. NUR ueber ns.Erbe.liste() - die bestehende Schnittstelle.
local function eigenerErbeEintrag()
    if not (ns.Erbe and ns.Erbe.liste) then return nil end
    local ok, liste = pcall(ns.Erbe.liste)
    if not ok or type(liste) ~= "table" then return nil end
    local eigen = ns.charKey
    if type(eigen) ~= "string" then
        eigen = ((UnitName and UnitName("player")) or "?") .. "-" .. ((GetRealmName and GetRealmName()) or "?")
    end
    for i = #liste, 1, -1 do
        local e = liste[i]
        if type(e) == "table" and e.name and e.name ~= ""
           and (tostring(e.name) .. "-" .. tostring(e.realm or "?")) == eigen then
            return e
        end
    end
    return nil
end
W.erbeEintrag = eigenerErbeEintrag

-- POSITIVLISTE (Regel 6). Ein Name darf nur dann in eine Zeile, wenn er anderswo schon ueber
-- eine Creature-GUID bzw. die UnitIsPlayer-Sperre belegt ist. Alles andere bleibt namenlos.
-- KEIN Bindestrich-Filter. Das war der erste Entwurf ("Name-Realm heisst Spieler") und er war
-- falsch: die halbe deutsche Gegnerliste heisst so ("Gnoll-Wegelagerer", "Defias-Spaeher"). Ein
-- Name kommt ausschliesslich ueber die Positivliste durch - das ist die staerkere Zusage, weil
-- sie nicht raet, sondern einen Beleg verlangt.
local function nameFreigegeben(name)
    if type(name) ~= "string" or name == "" then return false end
    if istEigenerName(name) then return false end
    local c = LyraGestaltDB and ns.charKey and LyraGestaltDB.chronik and LyraGestaltDB.chronik[ns.charKey]
    if type(c) == "table" and type(c.bestiarium) == "table" then
        for _, e in pairs(c.bestiarium) do
            if type(e) == "table" and e.name == name then return true end
        end
    end
    local erbe = eigenerErbeEintrag()
    if erbe and erbe.gegner == name then return true end
    return false
end
W.nameFreigegeben = nameFreigegeben

-- Aus deathevents die Beobachtung rechnen. Reine Funktion, damit der Pruefstand sie einzeln
-- fahren kann. Rueckgabe: Befund-Tabelle oder nil (dann schweigt Lyra).
-- ereignisse ist deathevents, todZeit die Uhrzeit des Todes (beide aus UnpackDeathTable).
function W.auswerten(ereignisse, todZeit, maxLeben)
    if type(ereignisse) ~= "table" then return nil end
    todZeit = zahl(todZeit)
    if not todZeit then return nil end                         -- Muell: String statt Zahl
    maxLeben = zahl(maxLeben)
    if maxLeben and maxLeben <= 0 then maxLeben = nil end

    local treffer, quellen, angreifer = {}, {}, 0
    local letzteUeberHalb, erstesZeit, lebenBekannt = nil, nil, 0
    for _, ev in ipairs(ereignisse) do
        if type(ev) == "table" and ev[1] == true then          -- NUR Schaden, nie Heilung
            local zeitpunkt = zahl(ev[4])
            local betrag = zahl(ev[3])
            if zeitpunkt and betrag and betrag >= 0
               and zeitpunkt <= todZeit + 1 and zeitpunkt >= todZeit - W.FENSTER then
                local leben = zahl(ev[5])
                if leben and (leben < 0 or leben > 1.5) then leben = nil end
                local quelle = ev[6]
                if type(quelle) ~= "string" or quelle == "" then quelle = nil end
                -- Gezaehlt werden alle Quellen, die auf MICH eingeschlagen haben - GENANNT wird
                -- nur, was die Positivliste belegt. Die Zahl traegt keinen Namen und sagt ueber
                -- niemanden etwas aus ausser ueber den eigenen Tod.
                treffer[#treffer + 1] = { t = zeitpunkt, betrag = betrag, leben = leben, quelle = quelle }
                if quelle and not quellen[quelle] then quellen[quelle] = true; angreifer = angreifer + 1 end
                if leben then
                    lebenBekannt = lebenBekannt + 1
                    if leben > W.HALB then letzteUeberHalb = zeitpunkt end
                end
                if not erstesZeit or zeitpunkt < erstesZeit then erstesZeit = zeitpunkt end
            end
        end
    end
    if #treffer == 0 then return nil end                       -- leere Tabelle / nur Muell: still
    table.sort(treffer, function(a, b) if a.t ~= b.t then return a.t < b.t end return (a.betrag or 0) < (b.betrag or 0) end)

    local b = { treffer = #treffer, angreifer = angreifer, todZeit = todZeit }

    -- Leben VOR dem ersten Treffer: Leben danach plus der Betrag dieses Treffers. Nur mit einem
    -- brauchbaren maxLeben - sonst gibt es die Beobachtung "es ging schnell" eben nicht.
    local erster = treffer[1]
    if maxLeben and erster.leben then
        local davor = erster.leben + (erster.betrag / maxLeben)
        if davor > 1 then davor = 1 end
        b.lebenDavor = davor
    end
    -- Wie lange unter der Haelfte? Nur behaupten, wenn ueberhaupt Leben-Werte da waren.
    if lebenBekannt >= W.MIN_EREIGNIS then
        if letzteUeberHalb then
            b.unterHalb = todZeit - letzteUeberHalb
        elseif erstesZeit then
            b.unterHalb = todZeit - erstesZeit                 -- schon beim ersten Eintrag drunter
        end
    end
    b.letzterName = treffer[#treffer].quelle

    -- Die Rangfolge. Genau eine Beobachtung.
    if b.treffer <= W.SCHNELL_MAX and b.lebenDavor and b.lebenDavor >= W.SCHNELL_VON then
        b.art, b.n = "schnell", b.treffer
    elseif b.angreifer >= W.MEHRERE_AB then
        b.art, b.n = "mehrere", b.angreifer
    elseif b.unterHalb and b.unterHalb >= W.LANGE_SEK then
        b.art = "lange"
    elseif b.letzterName and nameFreigegeben(b.letzterName) then
        -- Regel 1: nur, wenn der Nachruf den Namen NICHT ohnehin schon hat.
        local erbe = eigenerErbeEintrag()
        if not (erbe and erbe.gegner and erbe.gegner ~= "") then
            b.art, b.gegner = "letzter", b.letzterName
        end
    end
    if not b.art then return nil end
    return b
end

-- Details lesen. Rueckgabe: Befund, Grund (Grund nur fuer /lyra status und den Pruefstand).
function W.lesen()
    if not detailsDa() then return nil, "fehlt" end
    local D = _G.Details
    local ok, combat = pcall(D.GetCurrentCombat, D)
    if not ok or type(combat) ~= "table" or type(combat.GetDeaths) ~= "function" then
        return nil, "kein Segment"
    end
    local ok2, tode = pcall(combat.GetDeaths, combat)
    if not ok2 or type(tode) ~= "table" or #tode == 0 then return nil, "keine Tode im Segment" end
    -- Von hinten: der letzte Tod des Segments ist der, um den es geht.
    for i = #tode, 1, -1 do
        local ok3, name, _, todZeit, _, _, maxLeben, ereignisse = pcall(D.UnpackDeathTable, D, tode[i])
        if ok3 and istEigenerName(name) then
            local b = W.auswerten(ereignisse, todZeit, maxLeben)
            if b then return b end
            return nil, "nichts zu sagen"
        end
    end
    return nil, "eigener Tod nicht im Segment"      -- in der Gruppe: es war jemand anderes
end

-- Ergebnis ins ERBE, damit der Nachfolger es sehen kann. Additiv, einmal, nur der eigene
-- Eintrag, nie ein Name ausserhalb der Positivliste.
-- W16B: schreibt nicht mehr selbst in die Liste, sondern ueber Sinne/Erbe.lua E.hergangSetzen()
-- (docs/welle13c-2026-09-21.md §3g) — dieselbe Zusicherung ("nur der eigene, juengste Eintrag,
-- nie ueberschreiben"), jetzt an EINER Stelle statt an zwei.
function W.insErbe(b)
    if type(b) ~= "table" then return false end
    if not (ns.Erbe and ns.Erbe.hergangSetzen) then return false end
    local ok = ns.Erbe.hergangSetzen({ v = 1, art = b.art, n = b.n, gegner = b.gegner })
    return ok and true or false
end

W.letzterBefund = nil
W.letzterGrund  = nil
local todGemerkt = false
local gesagt = false

local function anTod() return ns.Get("todHergang") ~= false end

local function sagen(b)
    if not anTod() then return false end
    if gesagt then return false end
    if imKampf() then return false end              -- als Geist im Kampf: die Regie wuerde warten, wir wollen das nicht
    local vars = nil
    if b.art == "schnell" then
        vars = { schlaege = b.n, nurPlatzhalter = true }
    elseif b.art == "mehrere" then
        vars = { n = b.n, nurPlatzhalter = true }
    elseif b.art == "letzter" then
        vars = { gegner = b.gegner, nurPlatzhalter = true }
    end
    -- "lange": keine vars - dann sind genau die drei platzhalterfreien Zeilen Kandidaten.
    if not (ns.melde and ns.melde("TOD_HERGANG", vars)) then return false end
    gesagt = true
    return true
end
W.sagen = sagen

local function nachTod()
    local b, grund = W.lesen()
    W.letzterBefund, W.letzterGrund = b, grund
    if not b then
        ns.debug("Welle13c: kein Hergang (" .. tostring(grund) .. ")")
        return
    end
    pcall(W.insErbe, b)
    ns.debug("Welle13c: Hergang " .. tostring(b.art))     -- kein Name, nie
    ns.Compat.After(math.max(1, W.SAG_AB - W.LESE_VERZUG), function()
        local ok, err = pcall(sagen, b)
        if not ok then ns.debug("Welle13c: " .. tostring(err)) end
    end)
end
W.nachTod = nachTod

ns.on("PLAYER_DEAD", function()
    if todGemerkt then return end
    todGemerkt = true
    gesagt = false
    if not anTod() then return end
    -- Erst lesen, wenn Details das Segment abgeschlossen hat - und nachdem Sinne/Erbe.lua
    -- seinen Eintrag angelegt hat (das tut es bei +0,5 s).
    ns.Compat.After(W.LESE_VERZUG, function()
        local ok, err = pcall(nachTod)
        if not ok then ns.debug("Welle13c: " .. tostring(err)) end
    end)
end)
ns.on("PLAYER_ALIVE", function() if not tot() then todGemerkt = false end end)
ns.on("PLAYER_UNGHOST", function() todGemerkt = false end)

-- =============================================================================================
-- 2  SAMMEL_AUSDAUER
-- =============================================================================================

local function rarityDa()
    local ok, da = pcall(function()
        local R = _G.Rarity
        return (type(R) == "table" and type(R.db) == "table" and type(R.db.profile) == "table"
                and type(R.db.profile.groups) == "table") and true or false
    end)
    return (ok and da) and true or false
end
W.rarityDa = rarityDa

local function anSammeln() return ns.Get("sammelAusdauer") ~= false end

-- Die schon gesagten Marken DIESES Charakters. Lazy angelegt: Core/Init.lua ist in dieser Welle
-- unantastbar, und ein Tabellen-Default in ns.DEFAULTS_CHAR waere ueber alle Charaktere dieselbe
-- Referenz (defaults() kopiert Tabellen nicht tief). Muster aus Sinne/Karte2.lua.
local function markenListe()
    local c = ns.char
    if type(c) ~= "table" then return nil end
    if type(c.sammelMarken) ~= "table" then c.sammelMarken = {} end
    return c.sammelMarken
end
W.markenListe = markenListe

W.letzteMarke = nil
W.verfolgt = 0
local letzterScan = 0

-- Ein Durchlauf. Rueckgabe: Kandidat { marke, key } oder nil.
-- Der Zugriff auf die fremde Tabelle steht komplett in EINEM pcall: eine Rarity-Tabelle mit
-- einem __index-Metatable, das wirft, darf hier nicht mehr als ein "nil" erzeugen.
function W.suchen()
    if not anSammeln() then return nil, "aus" end
    if not rarityDa() then return nil, "fehlt" end
    local gesagteMarken = markenListe()
    if not gesagteMarken then return nil, "vor initDB" end
    local kandidat, verfolgt = nil, 0
    local ok, err = pcall(function()
        local geprueft = 0
        for _, gruppe in pairs(_G.Rarity.db.profile.groups) do
            if type(gruppe) == "table" then
                for iname, item in pairs(gruppe) do
                    geprueft = geprueft + 1
                    if geprueft > W.MAX_PRUEF then return end
                    if type(item) == "table" and item.found ~= true and item.enabled ~= false
                       and type(iname) == "string" and iname ~= "" then
                        local a = zahl(item.attempts)
                        if a and a >= 0 and a < 1e7 and math.floor(a) == a then
                            verfolgt = verfolgt + 1
                            for _, m in ipairs(W.MARKEN) do
                                local key = iname .. ":" .. m
                                if a >= m and not gesagteMarken[key] then
                                    if a < m + W.FRISCH then
                                        -- Hoechste frische Marke gewinnt.
                                        if not kandidat or m > kandidat.marke then
                                            kandidat = { marke = m, key = key }
                                        end
                                    else
                                        -- Verpasst (Addon spaeter installiert): still abhaken.
                                        gesagteMarken[key] = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    W.verfolgt = verfolgt
    if not ok then return nil, "Rarity wirft" end
    if err ~= nil then return nil, "Rarity wirft" end
    return kandidat, kandidat and "ok" or "nichts faellig"
end

function W.sammelPuls()
    if imKampf() or tot() then return false end
    local t = jetzt()
    if t - letzterScan < W.SCAN_ABSTAND then return false end
    letzterScan = t
    local k = W.suchen()
    if not k then return false end
    -- Kein vars.key: die Drossel "3600" soll EIN Deckel je Stunde fuer das ganze Ereignis sein.
    if not (ns.melde and ns.melde("SAMMEL_AUSDAUER", { versuche = k.marke })) then
        ns.debug("Welle13c: Ausdauer-Zeile verworfen, Marke bleibt offen")
        return false
    end
    -- Erst jetzt gilt die Marke als gesagt (Lehre aus Sinne/Karte2.lua, ERBE_STERBEORT).
    local liste = markenListe()
    if liste then liste[k.key] = true end
    W.letzteMarke = k.marke
    return true
end

local function pulsSicher()
    local ok, err = pcall(W.sammelPuls)
    if not ok then ns.debug("Welle13c: " .. tostring(err)) end
end

ns.on("PLAYER_REGEN_ENABLED", function() ns.Compat.After(3, pulsSicher) end)
ns.on("LOOT_CLOSED", function() ns.Compat.After(1, pulsSicher) end)
ns.on("PLAYER_ENTERING_WORLD", function() letzterScan = 0 end)

-- =============================================================================================
-- /lyra status
-- =============================================================================================
local TEXT = {
    de = {
        tod_aus  = "Die letzten Sekunden: abgeschaltet.",
        tod_weg  = "Die letzten Sekunden: Details fehlt - ich sage dazu nichts.",
        tod_da   = "Die letzten Sekunden: bereit (Details da).",
        tod_letz = "  Zuletzt gelesen: %s.",
        tod_kein = "  Zuletzt gelesen: nichts (%s).",
        sam_aus  = "Ausdauer beim Sammeln: abgeschaltet.",
        sam_weg  = "Ausdauer beim Sammeln: Rarity fehlt - ich zaehle nichts mit.",
        sam_da   = "Ausdauer beim Sammeln: %d Stuecke verfolgt, Marken %s.",
        sam_letz = "  Zuletzt gesagt: %d Versuche.",
        privat   = "  Aus Details lese ich nur deinen eigenen Tod, und ich nenne keinen Spielernamen.",
    },
    en = {
        tod_aus  = "Your last seconds: switched off.",
        tod_weg  = "Your last seconds: Details isn't here - I say nothing about it.",
        tod_da   = "Your last seconds: ready (Details present).",
        tod_letz = "  Last read: %s.",
        tod_kein = "  Last read: nothing (%s).",
        sam_aus  = "Persistence while farming: switched off.",
        sam_weg  = "Persistence while farming: Rarity isn't here - I count nothing.",
        sam_da   = "Persistence while farming: %d items tracked, marks %s.",
        sam_letz = "  Last said: %d attempts.",
        privat   = "  From Details I read only your own death, and I never name a player.",
    },
}
local function T() return TEXT[ns.sprache()] or TEXT.en end

function W.status()
    local t = T()
    local out = {}
    if not anTod() then out[#out + 1] = t.tod_aus
    elseif not detailsDa() then out[#out + 1] = t.tod_weg
    else
        out[#out + 1] = t.tod_da
        if W.letzterBefund then out[#out + 1] = t.tod_letz:format(tostring(W.letzterBefund.art))
        elseif W.letzterGrund then out[#out + 1] = t.tod_kein:format(tostring(W.letzterGrund)) end
    end
    out[#out + 1] = t.privat
    if not anSammeln() then out[#out + 1] = t.sam_aus
    elseif not rarityDa() then out[#out + 1] = t.sam_weg
    else
        local m = {}
        for _, x in ipairs(W.MARKEN) do m[#m + 1] = tostring(x) end
        out[#out + 1] = t.sam_da:format(W.verfolgt or 0, table.concat(m, "/"))
        if W.letzteMarke then out[#out + 1] = t.sam_letz:format(W.letzteMarke) end
    end
    return out
end

function W.stand()
    return W.letzterBefund, W.letzterGrund, detailsDa(), rarityDa(), anTod(), anSammeln()
end
