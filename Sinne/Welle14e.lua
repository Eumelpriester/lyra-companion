-- Sinne/Welle14e.lua — Welle 14e "Weisst du noch?" (0.17.0, 21.09.2026).
-- Bauplan: docs/recherche/19-minispiele-flugzeit-2026-09-21.md §1.1, §1b.1 und §2 vollstaendig.
--
-- WAS DAS IST: Lyra fragt den Spieler ueber SEIN EIGENES LEBEN ab - aus Daten, die sie ohnehin
-- fuehrt (LyraGestaltDB.chronik[ns.charKey]). Eine Runde sind fuenf Fragen mit je vier
-- Antwortknoepfen, gespielt im BESTEHENDEN Gespraechsfenster (UI/Dialog.lua). Die Fragen sind
-- Daten, keine Fenster.
--
-- DIE SECHS SAETZE, DIE DIESE DATEI ZUSAMMENHALTEN:
--   1. KEIN NEUES FRAME. Kein CreateFrame, kein OnUpdate, kein Ticker, keine Animationsgruppe.
--      Die einzige Zeitfunktion im ganzen Spiel ist der ohnehin vorhandene ENDE_DAUER-Schluss
--      von UI/Dialog.lua. (§2.1, Pruefpunkt 4)
--   2. MAUS, NUR MAUS. Kein EditBox, kein SetFocus, kein SetAutoFocus, kein eigenes
--      EnableKeyboard(true). Solange ein Spiel laeuft und der Spieler NICHT auf dem Taxi sitzt,
--      wird die Tastatur des Gespraechsfensters sogar aktiv abgeschaltet (Abschnitt 6).
--      Grund: 1-4 sind bei fast jedem Spieler die ersten vier Aktionsleisten-Plaetze, und ein
--      Spiel dauert Minuten, kein Gespraech von Sekunden. (§2.2)
--   3. DAS SPIEL IST NIE "GEOEFFNET", ES IST NUR "NOCH NICHT GESCHLOSSEN". Zehn Ereignisse
--      schliessen das Fenster sofort - wortlos, ohne Rueckfrage, ohne "Willst du wirklich?".
--      Ein laufendes Spiel verzoegert KEINE Warnung. (§2.3, Pruefpunkt 10)
--   4. NIE VON SELBST. Das Angebot ist eine gewoehnliche Plauderzeile (SPIEL_ANGEBOT); das
--      Fenster geht nur auf Klick auf - Menueeintrag oder /lyra spiel. (§2.6)
--   5. NUR EIGENE DATEN. Zonen, Beinahe-Tode, Bestiarium, Sitzungen dieses Charakters. NIE ein
--      fremder Spielername, NIE Questie oder eine andere Fremddatenbank als Fragequelle, NIE
--      eine Frage ueber den gefallenen Vorgaenger (Sinne/Erbe.lua). (§2.4)
--   6. LOKAL. Serie und Rekord liegen in ns.char. Kein Byte verlaesst den Rechner: kein
--      SendAddonMessage, kein SendChatMessage, kein Upload, keine Bestenliste. (§1b.1)
--
-- KONTRAKT wie jede Sinn-Datei: kein SendChatMessage, kein RunMacro, kein CastSpell, keine
-- geschuetzte Funktion, kein Netz, keine neue Globale. Jeder Zugriff auf eine Spiel-API steht in
-- pcall und hinter einer Existenzpruefung auf EIN konkretes Feld; faellt eine API aus, ist diese
-- Datei still - und /lyra status sagt, was fehlt.
--
-- WO SIE IN DER TOC STEHT: hinter Sinne/Welle13d.lua und damit ganz zuletzt. Sie liest ns.Dialog
-- (Aktionen registrieren), ns.Regie (Riegel, Stufe einer Warnung) und die Chronik - alle drei
-- muessen fertig sein. spiel_dialog.lua steht dagegen zwischen welle2_dialog.lua und
-- UI/Dialog.lua, wie jede andere Dialog-Datendatei.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Welle14e = W
ns.Sinne.Welle14e = W

-- ---------------------------------------------------------------------------------------------
-- 0  Voreinstellung. Core/Init.lua gehoert in dieser Runde einem anderen Team, darum haengt der
-- Schluessel hier an ns.DEFAULTS_ACCOUNT (Muster Sinne/Welle13a.lua). Das laeuft auf DATEIEBENE,
-- also lange vor ADDON_LOADED - und genau dort ruft ns.initDB() defaults().
--
-- EIN Kaestchen, und es heisst nach dem, was es TUT: "Lyra darf mir Fragen stellen". Nicht
-- "Minispiel", nicht "Quiz" - wer das Spiel nicht will, will die Frage nicht, und wer die Frage
-- abstellt, hat damit auch das Angebot abgestellt (§2.6, letzter Punkt).
-- ---------------------------------------------------------------------------------------------
if type(ns.DEFAULTS_ACCOUNT) == "table" and ns.DEFAULTS_ACCOUNT.spielFragen == nil then
    ns.DEFAULTS_ACCOUNT.spielFragen = true
end

W.FRAGEN_PRO_RUNDE = 5       -- eine Runde (§2.4)
W.MAX_JE_TOPF      = 2       -- ein Topf hoechstens zweimal in derselben Runde (§2.4)
W.MIN_LEBEN        = 50      -- % - darunter nie ein Angebot, nie ein Spiel
W.HP_ABFALL        = 2       -- %-Punkte: so viel Verlust schliesst das Fenster wortlos
W.MIN_ZONEN        = 4       -- Mindestbestand der Zonen-Toepfe
W.MIN_BEINAHE_ZONEN = 3      -- Zonen mit mindestens einem Beinahe-Tod
W.MIN_BESTIEN      = 4       -- Bestiarium-Eintraege
W.MIN_SITZUNGEN    = 5       -- Sitzungen
W.MIN_ZONEN_ZAHL   = 6       -- fuer die Frage "wie viele Zonen hast du gesehen"

-- Feature-Weiche ZUERST, Interface-Nummer nie (Core/Compat.lua, Kopf). Gefragt wird nach der
-- FUNKTION: auf Forever/Camelot ist "gibt es UnitOnTaxi" die einzige Frage, die sich beantworten
-- laesst. Jede Lesefunktion prueft den Typ trotzdem noch einmal im Moment des Aufrufs - eine
-- Attrappe (und ein Fremd-Addon) kann eine Globale zur Laufzeit wegnehmen.
W.F = {
    taxi   = (type(_G.UnitOnTaxi) == "function") and true or false,
    rast   = (type(_G.IsResting) == "function") and true or false,
    leben  = (type(_G.UnitHealth) == "function" and type(_G.UnitHealthMax) == "function") and true or false,
    dialog = false,   -- faellt erst bei PLAYER_LOGIN: ns.Dialog entsteht spaeter in der TOC
}

W.selbsttest = { dialog = "?", chronik = "?", anlass = "?" }

-- ---------------------------------------------------------------------------------------------
-- 1  Kleinkram. Jede Spiel-API hinter Existenzpruefung UND pcall; Ausfall = false, nie ein Wurf.
-- ---------------------------------------------------------------------------------------------
local function ruf(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

local function sprache() return (ns.sprache and ns.sprache()) or "de" end
local function an() return ns.Get("spielFragen") ~= false end   -- nil zaehlt als AN (vor initDB)

local function imKampf()
    if ruf(_G.UnitAffectingCombat, "player") then return true end
    if ruf(_G.InCombatLockdown) then return true end
    return (ns.Regie and ns.Regie.imKampf) and true or false
end
local function tot() return ruf(_G.UnitIsDeadOrGhost, "player") and true or false end
local function inInstanz() return ruf(_G.IsInInstance) and true or false end
local function aufTaxi() return ruf(_G.UnitOnTaxi, "player") and true or false end
local function rastet() return ruf(_G.IsResting) and true or false end
local function inGruppe() return (ruf(_G.IsInGroup) or ruf(_G.IsInRaid)) and true or false end

-- Leben in Prozent. Ohne lesbare Werte: nil - und nil heisst NICHT "gesund", sondern
-- "kein Spiel" (Abschnitt 5). Lieber kein Angebot als eines bei 12 % Leben.
local function lebenPct()
    local hp = ruf(_G.UnitHealth, "player")
    local max = ruf(_G.UnitHealthMax, "player")
    if type(hp) ~= "number" or type(max) ~= "number" or max <= 0 then return nil end
    return math.floor(hp / max * 100 + 0.5)
end

local function zufall(n)
    if n <= 1 then return 1 end
    if type(math.random) == "function" then return math.random(n) end
    return 1
end

-- Fisher-Yates. Eigene Umsetzung, damit die Reihenfolge der vier Antworten je Frage NEU
-- gemischt wird und die richtige nicht immer auf demselben Knopf sitzt (§2.4).
local function mischen(liste)
    for i = #liste, 2, -1 do
        local j = zufall(i)
        liste[i], liste[j] = liste[j], liste[i]
    end
    return liste
end

-- Zweisprachiger Textbaustein. S("Westfall") ist in beiden Sprachen derselbe Eigenname.
local function S(s) return { de = s, en = s } end
local function txt(t)
    if type(t) ~= "table" then return tostring(t or "") end
    return t[sprache()] or t.en or t.de or ""
end

-- ---------------------------------------------------------------------------------------------
-- 2  Die Chronik - NUR LESEND, und mit zwei harten Sperren.
-- ---------------------------------------------------------------------------------------------
-- SPERRE 1 (fremde Spielernamen): Die Chronik enthaelt nach Bauart keinen Spielernamen -
-- Sinne/Chronik.lua setzt die UnitIsPlayer-Sperre als Erstes und nimmt aus dem Combat-Log nur
-- Creature-GUIDs. Dieses Spiel verlaesst sich darauf NICHT. Ein Bestiarium-Schluessel ist die
-- NPC-Typ-ID als Ziffernkette (Sinne/CHRONIK.md, Datenschema); alles andere - eine Player-GUID,
-- ein Name, ein Rest aus einer aelteren Version - faellt hier durch und wird nie zur Frage.
-- Das kostet eine Zeile und faengt den einen Fall, in dem eine fremde Datenbank versehentlich
-- in unsere Toepfe laeuft.
--
-- SPERRE 2 (Erbe): Ueber den gefallenen Vorgaenger (Sinne/Erbe.lua) wird NIE gefragt. Das Erbe
-- ist die ernsteste Stelle im ganzen Addon; wer daraus eine Quizfrage macht, hat die Figur nicht
-- verstanden (§2.4). Diese Datei liest ns.Erbe nirgends - nicht einmal lesend, damit auch eine
-- spaetere Erweiterung erst an diesem Kommentar vorbeimuss.
--
-- SPERRE 3 (Fremddaten): Questie, Ackis, AtlasLoot, ATT und jede andere fremde Datenbank sind
-- als Fragequelle ausgeschlossen (§1.4: Lizenz und Fragequalitaet). Ein Fremd-Addon ist nie
-- Voraussetzung, und hier ist es nicht einmal Zutat.
local function npcSchluessel(k)
    return type(k) == "string" and k:match("^%d+$") ~= nil
end
W.npcSchluessel = npcSchluessel

function W.chronik()
    if type(LyraGestaltDB) ~= "table" or not ns.charKey then return nil end
    local c = LyraGestaltDB.chronik
    if type(c) ~= "table" then return nil end
    local d = c[ns.charKey]
    if type(d) ~= "table" then return nil end
    return d
end

-- Zonenliste als sortierbares Feld. Schluessel ist der Zonenname (GetRealZoneText).
local function zonenListe(DB)
    local out = {}
    for name, e in pairs(DB.zonen or {}) do
        if type(name) == "string" and name ~= "" and type(e) == "table" then
            out[#out + 1] = { name = name, besuche = tonumber(e.besuche) or 0,
                              beinahe = tonumber(e.beinahe) or 0,
                              zuletzt = tonumber(e.zuletzt) or 0, erst = tonumber(e.erst) or 0 }
        end
    end
    return out
end

-- Bestiarium als Feld - mit Sperre 1. Eintraege ohne Namen fliegen ebenfalls raus: eine Frage
-- mit nil im Text gibt es nicht (Pruefpunkt 5).
local function bestienListe(DB)
    local out = {}
    for id, e in pairs(DB.bestiarium or {}) do
        if npcSchluessel(id) and type(e) == "table" and type(e.name) == "string" and e.name ~= "" then
            out[#out + 1] = { name = e.name, maxHit = tonumber(e.maxHit) or 0,
                              kaempfe = tonumber(e.kaempfe) or 0, treffer = tonumber(e.treffer) or 0 }
        end
    end
    return out
end

local function sitzungenListe(DB)
    local out = {}
    for _, s in ipairs(DB.sitzungen or {}) do
        if type(s) == "table" then
            local dauer = (tonumber(s.ende) or 0) - (tonumber(s.start) or 0)
            if dauer > 0 then out[#out + 1] = dauer end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- 3  Die Fragetoepfe.
-- ---------------------------------------------------------------------------------------------
-- Ein Topf ist eine Funktion (DB) -> nil (zu wenig Daten) oder
--   { frage = {de=,en=}, richtig = {de=,en=}, ablenker = { a, b, c }, schluessel = "..." }
-- Drei Regeln, die in JEDEM Topf gelten:
--   * Ablenker kommen aus DERSELBEN Tabelle, nie erfunden. Eine Zone, in der der Spieler nie
--     war, ist billig durchschaubar; eine, in der er war, ist eine echte Frage (§2.4).
--   * Bei Zahlen KLASSEN statt Werten ("unter einer Stunde / ein bis zwei / ..."). Das ist
--     nebenbei Andockstellen-Regel 2: hoechstens eine Zahl je Zeile.
--   * "schluessel" identifiziert die Frage, damit dieselbe Frage nicht zweimal in einer Runde
--     kommt - auch dann nicht, wenn zwei Toepfe zufaellig auf dieselbe Antwort laufen.
local function drei(kandidaten, ausser)
    local topf, gesehen = {}, {}
    for _, k in ipairs(kandidaten) do
        -- REVIEW17: doppelte Namen fliegen raus. Das Bestiarium ist nach NPC-TYP-ID
        -- geschluesselt, und zwei IDs koennen denselben Namen tragen ("Flussmaehne-Gnoll" gibt
        -- es mehrfach). Ohne diese Zeile stehen unter derselben Frage zwei WORTGLEICHE Knoepfe -
        -- der Spieler kann sie nicht unterscheiden, und einer von beiden ist zwangslaeufig falsch.
        if k ~= ausser and not gesehen[k] then
            gesehen[k] = true
            topf[#topf + 1] = k
        end
    end
    if #topf < 3 then return nil end
    mischen(topf)
    return { topf[1], topf[2], topf[3] }
end

-- Sortierhilfe: absteigend nach feld, stabil ueber den Namen (sonst wackelt die "richtige"
-- Antwort zwischen zwei gleichwertigen Eintraegen und die Aufloesung waere Glueckssache).
local function sortiere(liste, feld)
    table.sort(liste, function(a, b)
        if a[feld] == b[feld] then return tostring(a.name) < tostring(b.name) end
        return a[feld] > b[feld]
    end)
end

local TOEPFE = {}

-- zone_beinahe: "Wo waer's am haeufigsten schiefgegangen?"
TOEPFE.zone_beinahe = function(DB)
    local z = zonenListe(DB)
    local mit = {}
    for _, e in ipairs(z) do if e.beinahe > 0 then mit[#mit + 1] = e end end
    if #mit < W.MIN_BEINAHE_ZONEN then return nil end
    sortiere(mit, "beinahe")
    if mit[1].beinahe == (mit[2] or {}).beinahe then return nil end   -- kein eindeutiges Ergebnis
    local namen = {}
    for _, e in ipairs(z) do namen[#namen + 1] = e.name end
    local abl = drei(namen, mit[1].name)
    if not abl then return nil end
    return { schluessel = "zone_beinahe",
             frage = { de = "Wo wär's am häufigsten schiefgegangen?",
                       en = "Where did it nearly go wrong most often?" },
             richtig = S(mit[1].name), ablenker = { S(abl[1]), S(abl[2]), S(abl[3]) } }
end

-- rivale: "Wer hat dich am haertesten erwischt?" (Bestiarium maxHit)
TOEPFE.rivale = function(DB)
    local b = bestienListe(DB)
    if #b < W.MIN_BESTIEN then return nil end
    sortiere(b, "maxHit")
    if b[1].maxHit <= 0 or b[1].maxHit == b[2].maxHit then return nil end
    local namen = {}
    for _, e in ipairs(b) do namen[#namen + 1] = e.name end
    local abl = drei(namen, b[1].name)
    if not abl then return nil end
    return { schluessel = "rivale",
             frage = { de = "Wer hat dich am härtesten erwischt?",
                       en = "Who hit you hardest?" },
             richtig = S(b[1].name), ablenker = { S(abl[1]), S(abl[2]), S(abl[3]) } }
end

-- bestiarium_oft: "Wovon hast du am meisten umgelegt?" (Kaempfe)
TOEPFE.bestiarium_oft = function(DB)
    local b = bestienListe(DB)
    if #b < W.MIN_BESTIEN then return nil end
    sortiere(b, "kaempfe")
    if b[1].kaempfe <= 0 or b[1].kaempfe == b[2].kaempfe then return nil end
    local namen = {}
    for _, e in ipairs(b) do namen[#namen + 1] = e.name end
    local abl = drei(namen, b[1].name)
    if not abl then return nil end
    return { schluessel = "bestiarium_oft",
             frage = { de = "Wovon hast du am meisten umgelegt?",
                       en = "What did you cut down the most?" },
             richtig = S(b[1].name), ablenker = { S(abl[1]), S(abl[2]), S(abl[3]) } }
end

-- heimat: "Wo warst du am haeufigsten?" (Besuche). Die Recherche nennt Zonenzeit; die fuehrt
-- die Chronik nicht (Sinne/CHRONIK.md kennt erst/zuletzt/besuche/beinahe). Besuche sind das
-- ehrliche Mass, das wirklich dasteht - eine Zahl zu erfinden waere das Gegenteil davon.
TOEPFE.heimat = function(DB)
    local z = zonenListe(DB)
    if #z < W.MIN_ZONEN then return nil end
    sortiere(z, "besuche")
    if z[1].besuche <= 0 or z[1].besuche == z[2].besuche then return nil end
    local namen = {}
    for _, e in ipairs(z) do namen[#namen + 1] = e.name end
    local abl = drei(namen, z[1].name)
    if not abl then return nil end
    return { schluessel = "heimat",
             frage = { de = "In welcher Gegend bist du am häufigsten aufgetaucht?",
                       en = "Which part of the world did you turn up in most often?" },
             richtig = S(z[1].name), ablenker = { S(abl[1]), S(abl[2]), S(abl[3]) } }
end

-- zone_erst: "Welche davon hast du zuerst gesehen?"
TOEPFE.zone_erst = function(DB)
    local z = zonenListe(DB)
    local mit = {}
    for _, e in ipairs(z) do if e.erst > 0 then mit[#mit + 1] = e end end
    if #mit < W.MIN_ZONEN then return nil end
    table.sort(mit, function(a, b)
        if a.erst == b.erst then return a.name < b.name end
        return a.erst < b.erst
    end)
    if mit[1].erst == mit[2].erst then return nil end
    local namen = {}
    for _, e in ipairs(mit) do namen[#namen + 1] = e.name end
    local abl = drei(namen, mit[1].name)
    if not abl then return nil end
    return { schluessel = "zone_erst",
             frage = { de = "Welche dieser Gegenden hast du zuerst gesehen?",
                       en = "Which of these did you see first?" },
             richtig = S(mit[1].name), ablenker = { S(abl[1]), S(abl[2]), S(abl[3]) } }
end

-- zone_zuletzt: "In welcher davon warst du zuletzt?"
TOEPFE.zone_zuletzt = function(DB)
    local z = zonenListe(DB)
    local mit = {}
    for _, e in ipairs(z) do if e.zuletzt > 0 then mit[#mit + 1] = e end end
    if #mit < W.MIN_ZONEN then return nil end
    sortiere(mit, "zuletzt")
    if mit[1].zuletzt == mit[2].zuletzt then return nil end
    local namen = {}
    for _, e in ipairs(mit) do namen[#namen + 1] = e.name end
    local abl = drei(namen, mit[1].name)
    if not abl then return nil end
    return { schluessel = "zone_zuletzt",
             frage = { de = "In welcher dieser Gegenden warst du zuletzt?",
                       en = "Which of these were you in most recently?" },
             richtig = S(mit[1].name), ablenker = { S(abl[1]), S(abl[2]), S(abl[3]) } }
end

-- sitzung_lang: "Unser laengster Abend - wie lang ungefaehr?" KLASSEN, keine Minutenzahl.
local DAUER_KLASSEN = {
    { bis = 3600,   de = "unter einer Stunde",  en = "under an hour" },
    { bis = 7200,   de = "ein bis zwei Stunden", en = "one to two hours" },
    { bis = 14400,  de = "zwei bis vier Stunden", en = "two to four hours" },
    { bis = nil,    de = "mehr als vier Stunden", en = "more than four hours" },
}
local function dauerKlasse(sek)
    for i, k in ipairs(DAUER_KLASSEN) do
        if not k.bis or sek < k.bis then return i end
    end
    return #DAUER_KLASSEN
end
TOEPFE.sitzung_lang = function(DB)
    local s = sitzungenListe(DB)
    if #s < W.MIN_SITZUNGEN then return nil end
    local max = 0
    for _, d in ipairs(s) do if d > max then max = d end end
    if max <= 0 then return nil end
    local i = dauerKlasse(max)
    local abl = {}
    for j = 1, #DAUER_KLASSEN do
        if j ~= i then abl[#abl + 1] = { de = DAUER_KLASSEN[j].de, en = DAUER_KLASSEN[j].en } end
    end
    if #abl < 3 then return nil end
    return { schluessel = "sitzung_lang",
             frage = { de = "Unser längster Abend — wie lang ungefähr?",
                       en = "Our longest evening — roughly how long?" },
             richtig = { de = DAUER_KLASSEN[i].de, en = DAUER_KLASSEN[i].en },
             ablenker = { abl[1], abl[2], abl[3] } }
end

-- zonen_zahl: "Wie viele Gegenden hast du gesehen?" Auch hier KLASSEN - eine exakte Zahl waere
-- geraten statt erinnert, und Regel 2 will die Zahl nur dort, wo sie die Beobachtung ist.
local ZAHL_KLASSEN = {
    { bis = 8,   de = "eine Handvoll",        en = "a handful" },
    { bis = 15,  de = "unter fünfzehn",       en = "under fifteen" },
    { bis = 25,  de = "fünfzehn bis fünfundzwanzig", en = "fifteen to twenty-five" },
    { bis = nil, de = "mehr als fünfundzwanzig", en = "more than twenty-five" },
}
TOEPFE.zonen_zahl = function(DB)
    local z = zonenListe(DB)
    if #z < W.MIN_ZONEN_ZAHL then return nil end
    local i = #ZAHL_KLASSEN
    for j, k in ipairs(ZAHL_KLASSEN) do
        if k.bis and #z <= k.bis then i = j; break end
    end
    local abl = {}
    for j = 1, #ZAHL_KLASSEN do
        if j ~= i then abl[#abl + 1] = { de = ZAHL_KLASSEN[j].de, en = ZAHL_KLASSEN[j].en } end
    end
    if #abl < 3 then return nil end
    return { schluessel = "zonen_zahl",
             frage = { de = "Wie viele Gegenden hast du bisher gesehen?",
                       en = "How many parts of the world have you seen so far?" },
             richtig = { de = ZAHL_KLASSEN[i].de, en = ZAHL_KLASSEN[i].en },
             ablenker = { abl[1], abl[2], abl[3] } }
end

-- Reihenfolge = Ziehungsreihenfolge des Vorrats. Fest, nicht zufaellig: so ist der Vorrat einer
-- Chronik reproduzierbar, und der Pruefstand kann ihn pruefen.
W.TOPF_NAMEN = { "zone_beinahe", "rivale", "bestiarium_oft", "heimat",
                 "zone_erst", "zone_zuletzt", "sitzung_lang", "zonen_zahl" }
W.TOEPFE = TOEPFE

-- ---------------------------------------------------------------------------------------------
-- 4  Eine Runde bauen. Fuenf Fragen, jede Frage genau einmal, ein Topf hoechstens zweimal.
-- Reicht der Vorrat nicht, gibt es KEINE halbe Runde, sondern die Leer-Absage (§2.6).
-- ---------------------------------------------------------------------------------------------
-- Jeder Topf wird mehrfach gezogen; weil die Toepfe deterministisch das Maximum liefern, kaeme
-- zweimal dieselbe Frage. Darum: EIN Zug je Topf in den Vorrat, und die Rundenlaenge kommt aus
-- der Zahl der Toepfe, die ueberhaupt etwas hergeben. Acht Toepfe, fuenf Fragen - das geht auf,
-- sobald fuenf Toepfe Daten haben. MAX_JE_TOPF bleibt als Deckel stehen, falls ein Topf spaeter
-- mehrere verschiedene Fragen liefert.
function W.vorrat()
    local DB = W.chronik()
    if not DB then return {} end
    local out, gezaehlt = {}, {}
    for _, name in ipairs(W.TOPF_NAMEN) do
        local fn = TOEPFE[name]
        local ok, f = pcall(fn, DB)
        if ok and type(f) == "table" and type(f.richtig) == "table" and type(f.ablenker) == "table"
           and #f.ablenker == 3 and (gezaehlt[name] or 0) < W.MAX_JE_TOPF then
            f.topf = name
            gezaehlt[name] = (gezaehlt[name] or 0) + 1
            out[#out + 1] = f
        end
    end
    return out
end

function W.genugDaten()
    return #W.vorrat() >= W.FRAGEN_PRO_RUNDE
end

local function baueRunde()
    local v = W.vorrat()
    if #v < W.FRAGEN_PRO_RUNDE then return nil end
    mischen(v)
    local runde, gesehen = {}, {}
    for _, f in ipairs(v) do
        if not gesehen[f.schluessel] and #runde < W.FRAGEN_PRO_RUNDE then
            gesehen[f.schluessel] = true
            runde[#runde + 1] = f
        end
    end
    if #runde < W.FRAGEN_PRO_RUNDE then return nil end
    return runde
end

-- ---------------------------------------------------------------------------------------------
-- 5  Anlass und Riegel - wann ueberhaupt gespielt werden darf.
-- ---------------------------------------------------------------------------------------------
-- darfSpielen(): die Liste, die IMMER gilt - fuer den Menueeintrag, fuer /lyra spiel und fuer
-- jede einzelne Frage waehrend der Runde. Nichts davon ist Geschmack:
--   Haekchen aus            der Spieler hat gesagt, dass er nicht gefragt werden will
--   im Kampf                das Fenster ist im Kampf zu, Punkt (§2.3, eigener Modus-Merker)
--   tot / Geist             auf Hardcore ist das der eine Moment, in dem ein Spiel obszoen waere
--   in einer Instanz        dort wartet niemand, dort stirbt man
--   unter 50 % Leben        wer sich hochheilt, spielt nicht Quiz
--   Leben unlesbar          nil heisst "kein Spiel", nicht "gesund"
--   Still-Modus             wer Ruhe wollte, hat sie
function W.darfSpielen()
    if not an() then return false, "aus" end
    if ns.stillModus then return false, "still" end
    if imKampf() then return false, "kampf" end
    if tot() then return false, "tot" end
    if inInstanz() then return false, "instanz" end
    local hp = lebenPct()
    if hp == nil then return false, "leben?" end
    if hp < W.MIN_LEBEN then return false, "leben" end
    return true, nil
end

-- anlass(): Wartezeit. Taxi oder Rast - sonst nichts. "Warten auf die Gruppe" hat kein
-- verlaessliches Signal (Gruppe ist nicht Warten), also gibt es dafuer kein Angebot (§2.6).
function W.anlass()
    if aufTaxi() then return "taxi" end
    if rastet() then return "rast" end
    return nil
end

-- ---------------------------------------------------------------------------------------------
-- 6  Zustand der laufenden Runde und die Abbruch-Riegel.
-- ---------------------------------------------------------------------------------------------
W.lauf = nil            -- nil = kein Spiel. Sonst { fragen, i, richtig, serie, akt, hp }
W.angebotSitzung = false
W.letzterGrund = nil    -- fuer /lyra status und den Pruefstand

function W.laeuft() return W.lauf ~= nil end

-- REVIEW17 (21.09.2026): DAS FENSTER KANN AUCH OHNE UNS ZUGEHEN - und dann muss das Spiel enden.
-- W.zu() war bis hierher die einzige Stelle, die W.lauf loescht. Das Gespraechsfenster schliesst
-- sich aber auf vier weiteren Wegen, die an W.zu VORBEIGEHEN: ESC (UISpecialFrames), Rechtsklick
-- auf die Gestalt (UI/Dialog.lua:707), das Oeffnen des Menues (UI/Menue.lua M.oeffne ruft
-- ns.Dialog.schliesse) und ns.Freitext.verstecke. Danach war W.lauf() dauerhaft wahr, obwohl kein
-- Spiel mehr zu sehen war - mit zwei echten Folgen:
--   1. Der Ziffern-Riegel in UI/Dialog.lua (OnKeyDown) blieb abseits des Taxis fuer den REST DER
--      SITZUNG scharf: die Tasten 1-4 waren in JEDEM spaeteren Gespraech tot, waehrend die
--      Fusszeile sie weiter versprach.
--   2. Beim naechsten Landen haette Lyra "Wir sind da. Spiel aus." zu einem Spiel gesagt, das der
--      Spieler eine Stunde vorher verlassen hat - eine Falschaussage aus dem Nichts.
-- Diese Funktion ist der Gegenhaken: wortlos, ohne Rueckfrage, ohne das Fenster noch einmal
-- zuzumachen (es ist ja schon zu). UI/Dialog.lua ruft sie in D.schliesse UND im OnHide.
-- Re-entrant sicher: W.zu setzt W.lauf ZUERST auf nil und ruft erst dann ns.Dialog.schliesse.
function W.fensterZu()
    if not W.lauf then return false end
    W.lauf = nil
    W.letzterGrund = "fenster"
    ns.debug("Spiel beendet: fenster")
    return true
end

-- MERGE 0.17.0 (21.09.2026): DER TASTATUR-RIEGEL STEHT JETZT IN UI/Dialog.lua.
-- Bis zur Auslieferung lag er als Mantel um ns.Dialog.zeigeKnoten hier (Bericht 14e §3g1 nannte
-- das selbst den zweitbesten Ort). Der Koordinator hat den Diff-Vorschlag eingebaut: der
-- vorhandene OnKeyDown-Riegel in UI/Dialog.lua fragt ns.Welle14e.laeuft() und UnitOnTaxi ab und
-- laesst nur die vier Ziffern durchfallen, statt die Tastatur des ganzen Fensters abzuschalten.
-- Der Mantel und der kleine Fensterhelfer davor sind deshalb ersatzlos entfallen - der Mantel
-- war die empfindlichste Stelle der Welle (Risiko 3 des Berichts: ein zweiter Mantel eines
-- spaeteren Teams haette eine unbestimmte Reihenfolge ergeben). W.laeuft() oben ist die
-- Schnittstelle dorthin und bleibt.

-- STILL-MODUS-MANTEL. ns.stillSetzen (UI/Menue.lua) meldet STILL_AN ueber die Regie - und eine
-- Meldung, die am Abstand oder an der Drossel scheitert, erreicht den nachAusgabe-Haken nie.
-- Der Riegel darf aber nicht davon abhaengen, ob eine ZEILE durchkam: wer Ruhe wollte, hat sie
-- sofort. Der Mantel liest nur, reicht weiter und schaltet nichts ein.
local stillMantelLiegt = false
local function stillMantel()
    if stillMantelLiegt then return end
    if type(ns.stillSetzen) ~= "function" then return end
    local orig = ns.stillSetzen
    ns.stillSetzen = function(a)
        pcall(orig, a)
        if a and W.lauf then W.zu("still") end
    end
    stillMantelLiegt = true
end

-- Die einzige Stelle, an der ein Spiel endet. "zeile" ist die AUSNAHME, nicht die Regel:
-- wortlos ist der Normalfall (§2.3). Nie eine Rueckfrage, nie ein "Willst du wirklich?".
function W.zu(grund, zeile)
    if not W.lauf then return false end
    W.lauf = nil
    W.letzterGrund = grund
    if ns.Dialog and type(ns.Dialog.schliesse) == "function" then pcall(ns.Dialog.schliesse) end
    if zeile and ns.melde then pcall(ns.melde, zeile) end
    ns.debug("Spiel beendet: " .. tostring(grund))
    return true
end

-- Die zehn Riegel aus §2.3. Sie haengen fest an ns.on - registriert wird EINMAL beim Laden,
-- gearbeitet wird nur, wenn W.lauf steht. Kein Ticker, kein OnUpdate, kein GetUnitSpeed-Takt:
-- PLAYER_STARTED_MOVING ist das Ereignis, das UI/Menue.lua sich per Ticker selbst baut.
local function riegel(event, grund, zeileFn)
    ns.on(event, function()
        if not W.lauf then return end
        local zeile = zeileFn and zeileFn() or nil
        W.zu(grund, zeile)
    end)
end

riegel("PLAYER_REGEN_DISABLED", "kampf")            -- Kampf beginnt: wortlos, die Warnung spricht
riegel("PLAYER_DEAD", "tod")
riegel("PLAYER_ENTERING_WORLD", "ladebildschirm")
riegel("PARTY_INVITE_REQUEST", "einladung")
riegel("DUEL_REQUESTED", "duell")

-- Landung. PLAYER_CONTROL_GAINED kommt auch nach jedem Wurzeln/Betaeuben, darum zusaetzlich die
-- Frage, ob das Taxi noch traegt. Nur HIER faellt ein Wort - und nur, wenn gerade keine Warnung
-- ansteht (kein Kampf, nicht tot): ein Spielende darf nie vor einer Warnung stehen.
ns.on("PLAYER_CONTROL_GAINED", function()
    if not W.lauf then return end
    if aufTaxi() then return end
    -- REVIEW17: Die Zeile heisst "Wir sind da. Spiel aus." / "Gelandet." - sie darf NUR fallen,
    -- wenn es wirklich eine Landung war. PLAYER_CONTROL_GAINED kommt auch nach jedem Betaeuben,
    -- Wurzeln, Fuerchten und nach jedem Fahrzeug; wer beim RASTEN spielt und kurz betaeubt wird,
    -- haette "Wir sind da" fuer einen Flug bekommen, den es nie gab. Also: nur, wenn diese Runde
    -- auf dem Greifen angefangen hat. Das Fenster geht in beiden Faellen zu - nur wortlos.
    local zeile = (W.lauf.anlass == "taxi" and not imKampf() and not tot()) and "SPIEL_ABBRUCH" or nil
    W.zu("landung", zeile)
end)

-- Der Spieler laeuft los - aber nicht auf dem Greifen, dort "laeuft" er die ganze Zeit.
ns.on("PLAYER_STARTED_MOVING", function()
    if not W.lauf then return end
    if aufTaxi() then return end
    W.zu("bewegung")
end)

-- Schaden ohne Kampfflagge (Sturz, Feuer, Ertrinken): das Fenster geht wortlos zu, bevor
-- irgendjemand nachdenkt. Die Prozentzahl steht in W.lauf.hp und wird bei jedem Knoten
-- nachgefuehrt - hier zaehlt nur der ABFALL, nicht der Absolutwert.
ns.onUnit("UNIT_HEALTH", "player", function()
    if not W.lauf then return end
    local hp = lebenPct()
    if hp == nil then W.zu("leben?"); return end
    local vor = W.lauf.hp or hp
    if hp < vor - W.HP_ABFALL or hp < W.MIN_LEBEN then W.zu("schaden"); return end
    W.lauf.hp = math.max(vor, hp)
end)

-- Jede Warnung ab Stufe 2 und jedes Einschalten des Still-Modus schliessen das Fenster.
-- DAS IST PRUEFPUNKT 10: das Spiel verzoegert die Warnung nicht - es weicht ihr aus. Der Haken
-- laeuft NACH der Ausgabe, die Warnung ist also schon draussen, wenn hier geschlossen wird.
-- Proben (vars.test) laufen durch, ohne etwas zu schliessen - dieselbe Regel wie in Chronik.lua.
if ns.nachAusgabe then
    ns.nachAusgabe(function(id, e, vars)
        if not W.lauf then return end
        if vars and vars.test then return end
        if id == "STILL_AN" then W.zu("still"); return end
        if type(e) ~= "table" then return end
        local stufe = (ns.Regie and ns.Regie.stufeVon) and ns.Regie.stufeVon(e)
                      or (tonumber(e.stufe) or ((e.klasse == "warn") and 2 or 0))
        if (tonumber(stufe) or 0) >= 2 then W.zu("warnung") end
    end)
end

-- ---------------------------------------------------------------------------------------------
-- 7  Rekord und Geisterduell - lokal, je Charakter, in ns.char.
-- ---------------------------------------------------------------------------------------------
-- WARUM ns.char UND NICHT ns.Set: ns.Set entscheidet den Scope ueber eine feste Liste in
-- Core/Init.lua (CHAR_KEYS), und die gehoert in dieser Runde einem anderen Team. Ein neuer
-- Schluessel liefe dort ins Konto statt auf den Charakter. Direkt geschrieben wird darum genau
-- EIN Feld, ns.char.spiel - dasselbe Muster wie ns.char.reittierErstes in Sinne/Welle13a.lua.
--
-- WAS DRINSTEHT: beste (beste Runde), serie (laengste Serie richtiger Antworten), runden,
-- letzte (letzte Runde) und verlauf (der Punktestand der BESTEN Runde nach jeder Frage) - das
-- ist der Geist, gegen den gespielt wird. Kein Zeitstempel eines anderen, kein fremder Name,
-- kein Bit, das den Rechner verlaesst (§1b.1).
local function rekord()
    if type(ns.char) ~= "table" then return nil end
    if type(ns.char.spiel) ~= "table" then
        ns.char.spiel = { beste = 0, serie = 0, runden = 0, letzte = 0, verlauf = {} }
    end
    local r = ns.char.spiel
    r.beste = tonumber(r.beste) or 0
    r.serie = tonumber(r.serie) or 0
    r.runden = tonumber(r.runden) or 0
    r.letzte = tonumber(r.letzte) or 0
    if type(r.verlauf) ~= "table" then r.verlauf = {} end
    return r
end
W.rekord = rekord

-- Der Geist: hatte die beste Runde nach derselben Zahl Fragen mehr Punkte? Dann sagt Lyra es.
-- Nur MEHR, nie weniger - "du bist besser als beim letzten Mal" ist Lob und gehoert in die
-- Ergebniszeile, nicht mitten in die Runde.
local function geisterZeile(i, stand)
    local r = rekord()
    if not r then return nil end
    local v = tonumber(r.verlauf[i])
    if not v or v <= stand then return nil end
    if sprache() == "en" then
        return ("Last time you were already at %d here."):format(v)
    end
    return ("Beim letzten Mal hattest du hier schon %d."):format(v)
end

-- ---------------------------------------------------------------------------------------------
-- 8  Die Texte, die diese Datei selbst baut. Core/Locale.lua und Locales/ gehoeren einem
-- anderen Team, darum steht das Wenige hier - so wie Sinne/Chronik.lua seine Statuszeilen.
-- ---------------------------------------------------------------------------------------------
local T = {
    de = {
        menue      = "Spiel: Weißt du noch?",
        ergebnis   = "%d von %d.",
        rekordNeu  = "Das ist dein bester Lauf.",
        rekordGleich = "Genau so gut wie dein bester Lauf.",
        rekordAlt  = "Dein bester Lauf steht bei %d.",
        serie      = "Längste Serie: %d.",
        statusAn   = "Spiel „Weißt du noch?“: an",
        statusAus  = "Spiel „Weißt du noch?“: aus",
        statusVorrat = "  Fragen im Vorrat: %d (nötig: %d)",
        statusRekord = "  Beste Runde: %d von %d, längste Serie %d, Runden %d",
        statusLage = "  Lage: %s",
        keinDialog = "  Gesprächsfenster fehlt — kein Spiel",
    },
    en = {
        menue      = "Game: Remember?",
        ergebnis   = "%d out of %d.",
        rekordNeu  = "That's your best run.",
        rekordGleich = "Exactly as good as your best run.",
        rekordAlt  = "Your best run stands at %d.",
        serie      = "Longest streak: %d.",
        statusAn   = "Game \"Remember?\": on",
        statusAus  = "Game \"Remember?\": off",
        statusVorrat = "  Questions available: %d (needed: %d)",
        statusRekord = "  Best round: %d of %d, longest streak %d, rounds %d",
        statusLage = "  State: %s",
        keinDialog = "  Dialogue window missing — no game",
    },
}
local function L(k) return (T[sprache()] or T.de)[k] or (T.de[k] or "") end

-- ---------------------------------------------------------------------------------------------
-- 9  Die Dialog-Aktionen. Von hier aus laeuft das Spiel - und NUR von hier aus.
-- ---------------------------------------------------------------------------------------------
local function knotenDaten(id)
    local d = _G.LyraGestalt_Dialog
    if type(d) ~= "table" or type(d.knoten) ~= "table" then return nil end
    for _, k in ipairs(d.knoten) do
        if k.id == id then return k end
    end
    return nil
end

-- Die vier Knopftexte des Frageknotens setzen (siehe Kopf von spiel_dialog.lua).
local function frageZeigen()
    local lauf = W.lauf
    if not lauf then return "spiel_nicht_jetzt" end
    local f = lauf.fragen[lauf.i]
    if not f then return "spiel_nicht_jetzt" end
    local k = knotenDaten("spiel_frage")
    if not (k and type(k.antworten) == "table" and #k.antworten == 4) then
        return "spiel_nicht_jetzt"
    end
    -- Vier Antworten, genau eine richtige, Reihenfolge je Frage neu gemischt.
    local auswahl = { { t = f.richtig, ok = true },
                      { t = f.ablenker[1] }, { t = f.ablenker[2] }, { t = f.ablenker[3] } }
    mischen(auswahl)
    lauf.richtigNr = 0
    for i = 1, 4 do
        local a = auswahl[i]
        k.antworten[i].text.de = a.t.de or a.t.en or "?"
        k.antworten[i].text.en = a.t.en or a.t.de or "?"
        if a.ok then lauf.richtigNr = i end
    end
    lauf.akt = f
    lauf.hp = lebenPct() or lauf.hp
    local frage = txt(f.frage)
    local geist = geisterZeile(lauf.i - 1, lauf.richtig)
    if geist then frage = frage .. " " .. geist end
    return "spiel_frage", { frage = frage }
end

-- Runde beginnen. Rueckgabe ist IMMER eine Knoten-ID - das Gespraechsfenster bekommt nie nil
-- und steht nie leer da.
local function starten()
    W.letzterGrund = nil
    -- REVIEW17: EIN Aufruf statt zwei. darfSpielen() liest UnitHealth, UnitAffectingCombat und
    -- IsInInstance; zweimal hintereinander gefragt kann es zwei VERSCHIEDENE Antworten geben
    -- (der Kampf beginnt genau dazwischen), und dann stuende "aus" im Grund, obwohl "kampf" gilt.
    local ok, grund = W.darfSpielen()
    if not ok then
        W.lauf = nil
        W.letzterGrund = grund
        return "spiel_nicht_jetzt"
    end
    local runde = baueRunde()
    if not runde then
        W.lauf = nil
        W.letzterGrund = "leer"
        return (zufall(2) == 1) and "spiel_leer_1" or "spiel_leer_2"
    end
    -- REVIEW17: "anlass" merkt sich, WO diese Runde angefangen hat (taxi oder rast). Nur eine
    -- Runde vom Greifen bekommt beim Schliessen die Landezeile (siehe PLAYER_CONTROL_GAINED).
    W.lauf = { fragen = runde, i = 1, richtig = 0, serie = 0, beste = 0, anlass = W.anlass(),
               verlauf = {}, hp = lebenPct() or 100 }
    return frageZeigen()
end

local function antwort(nr)
    local lauf = W.lauf
    if not lauf then return "spiel_nicht_jetzt" end
    -- Auch mitten in der Runde gelten alle Riegel. Wer zwischen zwei Fragen in den Kampf
    -- geraet, spielt nicht weiter - er bekommt das Fenster zugemacht.
    local darf, grund = W.darfSpielen()   -- REVIEW17: ein Aufruf, ein Grund (siehe starten())
    if not darf then
        W.zu(grund or "riegel")
        return nil
    end
    local treffer = (nr == lauf.richtigNr)
    if treffer then
        lauf.richtig = lauf.richtig + 1
        lauf.serie = lauf.serie + 1
        if lauf.serie > lauf.beste then lauf.beste = lauf.serie end
    else
        lauf.serie = 0
    end
    lauf.verlauf[lauf.i] = lauf.richtig
    if treffer then
        return "spiel_richtig_" .. zufall(5)
    end
    return "spiel_falsch_" .. zufall(5)
end

local function aufloesung()
    local lauf = W.lauf
    if not (lauf and lauf.akt) then return "spiel_nicht_jetzt" end
    return "spiel_aufloesung", { antwort = txt(lauf.akt.richtig) }
end

local function weiter()
    local lauf = W.lauf
    if not lauf then return "spiel_nicht_jetzt" end
    if lauf.i >= #lauf.fragen then return W.ergebnis() end
    lauf.i = lauf.i + 1
    return frageZeigen()
end

-- Ergebnis: die Zahl, der Rekordvergleich, die laengste Serie. Danach wird der Rekord
-- fortgeschrieben - und zwar NUR nach oben: eine schlechte Runde loescht keinen Geist.
function W.ergebnis()
    local lauf = W.lauf
    if not lauf then return "spiel_nicht_jetzt" end
    local teile = { (L("ergebnis")):format(lauf.richtig, #lauf.fragen) }
    local r = rekord()
    if r then
        if lauf.richtig > r.beste then teile[#teile + 1] = L("rekordNeu")
        elseif lauf.richtig == r.beste and r.runden > 0 then teile[#teile + 1] = L("rekordGleich")
        elseif r.runden > 0 then teile[#teile + 1] = (L("rekordAlt")):format(r.beste) end
        if lauf.beste >= 3 then teile[#teile + 1] = (L("serie")):format(lauf.beste) end
        if lauf.richtig > r.beste then
            r.beste = lauf.richtig
            r.verlauf = {}
            for i, v in ipairs(lauf.verlauf) do r.verlauf[i] = v end
        end
        if lauf.beste > r.serie then r.serie = lauf.beste end
        r.letzte = lauf.richtig
        r.runden = r.runden + 1
    end
    W.letzteRunde = { richtig = lauf.richtig, serie = lauf.beste, fragen = #lauf.fragen }
    return "spiel_ergebnis", { ergebnis = table.concat(teile, " ") }
end

-- Der Schlussknoten ist ein Ende-Knoten: UI/Dialog.lua schliesst das Fenster nach ENDE_DAUER
-- von selbst. Hier faellt nur noch der Laufzustand weg - kein Timer, kein Nachklapp.
local function schluss()
    W.lauf = nil
    W.letzterGrund = "fertig"
    return "spiel_schluss_" .. zufall(4)
end

local function aktionenRegistrieren()
    if not (ns.Dialog and type(ns.Dialog.aktionen) == "table") then return false end
    local A = ns.Dialog.aktionen
    A.spiel_start = starten
    A.spiel_a1 = function() return antwort(1) end
    A.spiel_a2 = function() return antwort(2) end
    A.spiel_a3 = function() return antwort(3) end
    A.spiel_a4 = function() return antwort(4) end
    A.spiel_aufloesung = aufloesung
    A.spiel_weiter = weiter
    A.spiel_schluss = schluss
    W.F.dialog = true
    ns.debug("Welle14e: Dialog-Aktionen registriert")
    return true
end
W.aktionenRegistrieren = aktionenRegistrieren

-- Einstieg von aussen (Menue, /lyra spiel ueber den Intent laeuft direkt ueber A.spiel_start).
function W.oeffne()
    if not (ns.Dialog and type(ns.Dialog.zeigeKnoten) == "function") then return false end
    aktionenRegistrieren()
    local id, vars = starten()
    if not id then return false end
    local ok = pcall(ns.Dialog.zeigeKnoten, id, vars)
    return ok and true or false
end

-- ---------------------------------------------------------------------------------------------
-- 10  Menueeintrag. UI/Menue.lua bekommt GENAU EINEN Eintrag dazu und ruft diese Funktion.
-- nil = der Eintrag erscheint gar nicht erst. Das ist Absicht: ein Menuepunkt, der beim Klick
-- "nicht jetzt" sagt, ist ein Versprechen, das nicht gehalten wird. Und weil er nur bei Taxi
-- oder Rast dasteht, ist das Menue die ueblichen neun Eintraege lang - die Ziffern 1-9 bleiben
-- also unveraendert; der zehnte Eintrag ist der einzige, den man klicken MUSS. Fuer ein Spiel,
-- dessen erste Regel "Maus, nur Maus" heisst, ist das kein Mangel.
-- ---------------------------------------------------------------------------------------------
function W.menueEintrag()
    if not W.darfSpielen() then return nil end
    if not W.anlass() then return nil end
    if not (ns.Dialog and type(ns.Dialog.zeigeKnoten) == "function") then return nil end
    return { L("menue"), function() W.oeffne() end }
end

-- ---------------------------------------------------------------------------------------------
-- 11  Das Angebot. EINE Plauderzeile, hoechstens einmal je Sitzung, nie von selbst ein Fenster.
-- ---------------------------------------------------------------------------------------------
-- Ausgeloest wird es vom Aufsitzen auf den Greifen. Ein eigener Ticker fuer "Leerlauf beim
-- Rasten" wird BEWUSST nicht gebaut (Zusage 4: kein OnUpdate, kein neuer Ticker) - beim Rasten
-- findet der Spieler das Spiel ueber das Menue, und das genuegt fuer 0.17.
--
-- Preset still/wenig bekommt es nie: die Regie wuerde eine Plauderzeile bei "still" ohnehin
-- verwerfen, "wenig" nicht zuverlaessig - also steht die Pruefung hier, sichtbar, statt sich
-- auf eine Drossel zu verlassen (Pruefpunkt 9).
local PRESETS_OHNE_ANGEBOT = { still = true, wenig = true }

-- REVIEW17: Kein Angebot auf einem kurzen Huepfer. Die drei Zeilen heissen "Das dauert.",
-- "Langer Flug." und "Zeit totschlagen" - auf einem Neunzig-Sekunden-Sprung nach Sentinel Hill
-- ist jede davon falsch, und die Runde waere nach einer Frage von der Landung abgeschnitten.
-- Gelesen wird NUR, mit Existenzpruefung und pcall; fehlt Sinne/Welle14b.lua oder kennt es die
-- Strecke noch nicht, bleibt es beim Angebot (Ausfall ist nie strenger als vorher).
local function kurzerFlug()
    local F = ns.Welle14b
    if type(F) ~= "table" then return false end
    local ok, klasse = pcall(function()
        local f = F.flug
        return (type(f) == "table" and f.drin) and f.klasse or nil
    end)
    return (ok and klasse == "kurz") and true or false
end

-- REVIEW17: DAS ANGEBOT DARF NICHT AM ABSTAND VERBRENNEN.
-- Bis hierher setzte W.angebot() das Sitzungs-Flag VOR dem Melden. In der Praxis hiess das: das
-- Angebot kam nie. Die Reihenfolge auf jedem Flug ist TAXI_START (Sinne/Umwelt.lua, bei
-- PLAYER_CONTROL_LOST) und dann SECHS SEKUNDEN SPAETER dieses Angebot - der Plauder-Mindest-
-- abstand steht ab Werk auf 30 s (Preset "viel": 15 s). Core/Regie.lua verwirft die zweite Zeile
-- also IMMER mit Grund "abstand", ohne Warteliste und ohne Nachklang, und das Flag war da schon
-- gesetzt: kein zweiter Versuch, die ganze Sitzung nicht. Das einzige ungefragte Tor zum
-- Minispiel war damit zu.
-- Jetzt: Flag NUR bei Erfolg. Ein Drop mit Grund "abstand" bekommt genau EINEN Nachhol, sobald
-- der Abstand abgelaufen ist (Muster meldeNachhol aus Sinne/Welle14b.lua). Jede andere Antwort -
-- Drossel, Gruppe, Still-Modus, Stummschaltung - ist endgueltig und verbraucht die Sitzung, so
-- wie es gedacht war. "Hoechstens einmal je Sitzung" haelt doppelt: hier und ueber die
-- Katalog-Drossel "session", die bei einem Abstands-Drop nicht verbraucht wird.
W.angebotNachhol = false

function W.angebot()
    if W.angebotSitzung then return false end
    if not an() then return false end
    if PRESETS_OHNE_ANGEBOT[ns.Get("gespraechig")] then return false end
    if not W.darfSpielen() then return false end
    if inGruppe() and ns.Get("gruppeSchweigen") ~= false then return false end
    if not W.genugDaten() then return false end
    if kurzerFlug() then return false end
    if not ns.melde then return false end
    local ok, durch = pcall(ns.melde, "SPIEL_ANGEBOT")
    if ok and durch then
        W.angebotSitzung = true
        return true
    end
    -- Nur der Abstand bekommt einen zweiten Versuch, und nur einen.
    local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
    local nurAbstand = d and d[2] == "SPIEL_ANGEBOT" and d[1] == "abstand"
    if not nurAbstand or W.angebotNachhol
       or not (ns.Compat and type(ns.Compat.After) == "function") then
        W.angebotSitzung = true
        return false
    end
    W.angebotNachhol = true
    local rest = 0
    if ns.Regie and ns.Regie.abstandRest then
        local okR, r = pcall(ns.Regie.abstandRest)
        if okR and type(r) == "number" then rest = r end
    end
    ns.Compat.After(math.max(2, math.min(rest + 1, 180)), function()
        -- Beim Nachhol gelten ALLE Riegel noch einmal (W.angebot prueft sie selbst) - und der
        -- Anlass muss noch stehen: wer inzwischen unten ist, bekommt kein "Langer Flug".
        if not W.anlass() then W.angebotSitzung = true; return end
        pcall(W.angebot)
    end)
    return false
end

-- TAXIMAP_OPENED gibt es nicht als "Abflug"; der Abflug ist das Uebernehmen der Kontrolle durch
-- das Taxi. PLAYER_CONTROL_LOST kommt auch beim Betaeuben - darum wird gefragt, ob das Taxi
-- traegt, und der Rest ist Schweigen.
ns.on("PLAYER_CONTROL_LOST", function()
    if not aufTaxi() then return end
    if not ns.Compat or type(ns.Compat.After) ~= "function" then return end
    -- 6 s Ruhe nach dem Aufsitzen: erst die Flugmeister-Zeilen der anderen Sinne, dann wir.
    ns.Compat.After(6, function()
        if not aufTaxi() then return end
        pcall(W.angebot)
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- 12  Login, Status.
-- ---------------------------------------------------------------------------------------------
ns.on("PLAYER_LOGIN", function()
    aktionenRegistrieren()
    stillMantel()
    rekord()
    W.angebotSitzung = false
    W.angebotNachhol = false   -- REVIEW17
end)

ns.on("PLAYER_ENTERING_WORLD", function()
    if not W.F.dialog then aktionenRegistrieren() end
    stillMantel()
end)

-- /lyra status. Sagt, was fehlt - das ist der halbe Zweck des Befehls.
function W.status()
    local out = {}
    out[#out + 1] = an() and L("statusAn") or L("statusAus")
    if not (ns.Dialog and type(ns.Dialog.zeigeKnoten) == "function") then
        out[#out + 1] = L("keinDialog")
        return out
    end
    local v = #W.vorrat()
    out[#out + 1] = (L("statusVorrat")):format(v, W.FRAGEN_PRO_RUNDE)
    local r = rekord()
    if r then
        out[#out + 1] = (L("statusRekord")):format(r.beste, W.FRAGEN_PRO_RUNDE, r.serie, r.runden)
    end
    local ok, grund = W.darfSpielen()
    local lage = ok and (W.anlass() or "-") or tostring(grund)
    out[#out + 1] = (L("statusLage")):format(lage)
    W.selbsttest.dialog = "ok"
    W.selbsttest.chronik = (v >= W.FRAGEN_PRO_RUNDE) and "ok" or "zu wenig"
    W.selbsttest.anlass = W.anlass() or "-"
    return out
end
