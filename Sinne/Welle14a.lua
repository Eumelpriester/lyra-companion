-- Sinne/Welle14a.lua — Welle 14a "Verbuendete": WER steht da, statt WIE STARK ist er.
--
-- BEFUND (Spieltest Harald, 21.09.2026)
-- ------------------------------------
-- Die Dialog-Aktion "ziel" (UI/Dialog.lua) rechnet Zielstufe gegen eigene Stufe und sagt bei
-- einem Orgrimmar-Waechter (Stufe 65, Elite, freundlich) "Zu stark, {Held|Heldin}. Deine
-- Zauber verfehlen, seine nicht." Das ist kein Urteil, das ist Unsinn: auf diese Einheit kann
-- der Spieler gar nicht schlagen. Eine Staerke-Einschaetzung ohne die Frage "kann ich das
-- ueberhaupt angreifen?" ist die haeufigste Art, wie ein Begleiter unglaubwuerdig wird — sie
-- ist nicht falsch berechnet, sie ist die falsche AUSSAGE.
--
-- WAS DIESE DATEI TUT
-- -------------------
-- Sie beantwortet fuer ein NICHT ANGREIFBARES, nicht spielergesteuertes Ziel genau zwei Fragen
-- und gibt sonst nichts zurueck:
--   rolle  "haendler" | "lehrer" | "gastwirt" | "flugmeister" | "bankier" | "auktionator"
--          | "ruestmeister" | "stallmeister" | "reparatur" | "waechter" | nil
--   quest  "gibt" (der NPC haelt eine Quest bereit) | "nimmt" (eine fertige Quest wartet auf
--          Abgabe bei ihm) | nil
-- Die ZEILE baut UI/Dialog.lua daraus (Fragmente in dialog.lua, fragmente.verbuendet). Diese
-- Datei kennt keinen Satz und meldet nichts an die Regie.
--
-- KEIN EREIGNIS, KEINE UNGEFRAGTE ZEILE
-- -------------------------------------
-- Es haengt NICHTS an PLAYER_TARGET_CHANGED. Einen Gastwirt anzuklicken ist kein Anlass zu
-- reden; die Auskunft kommt ausschliesslich auf die Frage "Was weisst du ueber mein Ziel?"
-- bzw. /lyra wer ist das. Damit gibt es auch kein neues Katalog-Ereignis, keine neue Stimme
-- und keine Drossel: was nur auf Knopfdruck passiert, braucht keine Bremse.
--
-- DREI QUELLEN, IN DIESER REIHENFOLGE (jede darf fehlen)
-- -----------------------------------------------------
--   1. EIGENER SCAN-TOOLTIP. Ein unsichtbarer GameTooltip (SetOwner(UIParent, "ANCHOR_NONE"))
--      bekommt SetUnit("target"); Zeile 2 traegt bei einem NPC den Untertitel in spitzen
--      Klammern, z. B. "<Gastwirt>", "<Flugmeister>", "<Waffenhaendler>". NUR LESEN: der
--      Tooltip gehoert uns, der echte GameTooltip wird nicht angefasst (wer dem den Besitzer
--      wegnimmt, zerstoert dem Spieler die Tooltips der ganzen Sitzung).
--      Die spitzen Klammern sind PFLICHT: ohne Untertitel steht in Zeile 2 die Stufenzeile
--      ("Stufe 65 Elite"), und die darf nie als Beruf durchgehen.
--   2. QUESTIE npcFlags. Sprachunabhaengig und exakt — aber optional. Deckt genau die Rollen
--      ab, fuer die der Server ein Flag hat (Gastwirt, Flugmeister, Bankier, Auktionator,
--      Stallmeister, Lehrer, Reparatur, Haendler). Zweite Wahl, weil der TITEL das ist, was der
--      Spieler selbst sieht, und weil nur er den "Ruestmeister" vom schlichten Haendler trennt
--      (beide tragen VENDOR).
--      ABWEICHUNG VOM AUFTRAG, bewusst: der Auftrag nennt nur den Tooltip. Die Flags kosten
--      nichts, retten den Fall "Untertitel in einer dritten Sprache" und fallen ohne Questie
--      ersatzlos weg. Der Tooltip behaelt trotzdem den Vortritt.
--   3. WACHE. Fuer Waechter gibt es weder Flag noch verlaesslichen Untertitel, und am NAMEN
--      erkennt man sie nicht (ein deutscher Client hat "Orgrimmar-Grunzer", ein englischer
--      "Orgrimmar Grunt", dazu Kor'kron, Wache, Sentinel, Brave ...). Erkannt wird deshalb die
--      LAGE: nicht angreifbar + Elite + Hauptstadt. Passt das nicht, bleibt rolle = nil und die
--      Zeile faellt in den trockenen Rueckfall. Lieber keine Rolle als eine erfundene.
--
-- QUESTS: QUESTIE FUER DEN NPC, DAS EIGENE QUESTBUCH FUER DEN ZUSTAND
-- ------------------------------------------------------------------
--   QuestieDB:GetNPC(id).questStarts / .questEnds    Questie/Database/npcDB.lua:16-17
--   QuestieDB.QueryNPCSingle(id, "questStarts")      Questie/Database/QuestieDB.lua:2117-2118
--   QuestieDB.IsDoable(questId)                      Questie/Database/QuestieDB.lua:653 (Punkt!)
--   QuestieDB.npcFlags (Bitmaske, Era-Werte)         Questie/Database/npcDB.lua:58-79
-- "nimmt" schlaegt "gibt": eine fertige Quest im Buch ist die Handlung, die JETZT ansteht.
-- Ob eine Quest im Buch liegt und fertig ist, sagt ns.Compat.questLogEintrag — nicht Questie.
-- Das eigene Questbuch ist die verlaesslichste Quelle im Spiel und braucht kein Fremd-Addon.
-- "Schon abgeschlossen" prueft C_QuestLog.IsQuestFlaggedCompleted (in Era 1.15 vorhanden),
-- sonst QuestieDB.IsDoable, sonst gar nicht — dann sagt sie im Zweifel nichts.
--
-- DIE SECHS REGELN (Recherche 18 §3) auf diese Datei angewandt:
--   1. Keine Doppelung: die Quest-Ausrufezeichen malt Questie, den Beruf zeigt der Tooltip.
--      Lyra sagt es nur, wenn der Spieler FRAGT — dann ist es keine Doppelung, sondern Antwort.
--   2. Hoechstens eine Zahl je Zeile: diese Datei liefert gar keine Zahl.
--   3. Nur menschliche Beobachtung: Beruf und "hat was fuer dich", keine Quest-IDs, keine Liste.
--   4. Ausfall ist Schweigen: Existenzpruefung auf EIN FELD (ImportModule gibt fuer unbekannte
--      Namen einen LEEREN Stub, QuestieLoader.lua:172-177) und pcall um JEDEN Fremdzugriff,
--      auch um das Lesen eines Tabellenfeldes (eine fremde Metatabelle darf werfen).
--   5. Nie in ein fremdes Addon schreiben: diese Datei liest ausschliesslich.
--   6. Fremde Spieler bleiben draussen: UnitIsPlayer bricht sofort ab, GUIDs ausserhalb von
--      Creature/Vehicle ebenso. Der Name eines fremden Spielers kommt in keiner neuen Zeile vor.
--
-- Kontrakt: kein SendChatMessage, keine geschuetzte Funktion, kein Netz, kein OnUpdate, kein
-- Ticker, kein Ereignis. Eine neue Globale: der benannte Scan-Tooltip (Begruendung unten).
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Welle14a = W
ns.Sinne.Welle14a = W

-- ---------------------------------------------------------------------------------------------
-- Voreinstellung. Ein Haekchen, benannt nach dem, was es TUT. Core/Init.lua gehoert dieser Welle
-- nicht, also haengt der Schluessel hier an ns.DEFAULTS_ACCOUNT (Muster Sinne/Welle13b.lua:74).
-- AUS heisst: keine Rolle, keine Quest — NICHT "dann wieder Staerke-Urteil". Die Frage "kann ich
-- das angreifen?" stellt UI/Dialog.lua unabhaengig von diesem Schalter; der Befund von oben ist
-- ein Fehler und kein Feature, das man wieder einschalten koennen muss.
-- ---------------------------------------------------------------------------------------------
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.verbuendetAuskunft == nil then D.verbuendetAuskunft = true end
end

-- ---------------------------------------------------------------------------------------------
-- Stellschrauben
-- ---------------------------------------------------------------------------------------------
W.TIP_NAME    = "LyraGestaltZielTip"  -- benannter Scan-Tooltip (siehe tooltip())
W.MAX_TITEL   = 60    -- Zeichen: laenger ist kein Beruf, sondern ein Unfall
W.MAX_QUESTS  = 40    -- so viele questStarts/questEnds je NPC werden angesehen
W.MAX_LOG     = 100   -- Muell-Riegel fuer questAnzahl (wie Welle13a.QUEST_MAX)

W.stand = { rolle = nil, quest = nil, quelle = "nichts gefragt" }

-- ---------------------------------------------------------------------------------------------
-- Kleinkram
-- ---------------------------------------------------------------------------------------------
local function an(k) return ns.Get and ns.Get(k) ~= false end

-- Jeder Fremdaufruf geht hier durch: kein Wert ohne pcall, kein Fehler nach aussen.
local function frage(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

-- Ein Feld aus einer FREMDEN Tabelle lesen. Sieht ueberfluessig aus und ist es nicht: eine
-- fremde Tabelle darf eine Metatabelle mit einem __index haben, das wirft. Der Pruefstand faehrt
-- diesen Fall als Modus "kaputt".
local function feld(t, k)
    if type(t) ~= "table" or k == nil then return nil end
    local ok, v = pcall(function() return t[k] end)
    if not ok then return nil end
    return v
end

-- ASCII-Faltung wie in UI/Dialog.lua (normalisiere): klein, ohne Umlaute, ohne Doppelblank.
local function falte(s)
    s = tostring(s or ""):lower()
    s = s:gsub("ä", "ae"):gsub("ö", "oe"):gsub("ü", "ue"):gsub("ß", "ss")
    s = s:gsub("Ä", "ae"):gsub("Ö", "oe"):gsub("Ü", "ue")
    s = s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    return s
end
W.falte = falte

-- NPC-ID aus der GUID. Feld 6 ist die Kreaturen-ID (Muster Sinne/Welle13b.lua:455-461).
-- Alles, was nicht Creature/Vehicle ist, faellt hier heraus — also auch jeder Spieler.
local function npcIdVon(unit)
    local guid = frage(UnitGUID, unit)
    if type(guid) ~= "string" then return nil end
    local art, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if (art == "Creature" or art == "Vehicle") and id then return tonumber(id) end
    return nil
end
W.npcIdVon = npcIdVon

-- =============================================================================================
-- 1. ROLLE AUS DEM UNTERTITEL (eigener Scan-Tooltip)
-- =============================================================================================
-- WARUM DER TOOLTIP EINEN NAMEN HAT (und damit eine Globale anlegt)
-- Die Zeilen eines Tooltips sind nur ueber die benannten FontStrings <Name>TextLeftN
-- erreichbar; ein namenloser Tooltip laesst sich auf einem Era-Client nicht auslesen
-- (C_TooltipInfo.GetUnit gibt es dort nicht verlaesslich). Dieselbe Ausnahme gilt schon fuer
-- LyraGestaltDialog, LyraGestaltMenue und LyraGestaltFreitext; der Name traegt das Praefix und
-- kollidiert mit nichts. Der Tooltip entsteht ERST BEIM ERSTEN FRAGEN, nicht beim Laden.
local tip = nil          -- nil = noch nicht versucht, false = geht nicht, sonst der Frame
local function tooltip()
    if tip ~= nil then return tip or nil end
    if type(CreateFrame) ~= "function" then tip = false; return nil end
    local ok, f = pcall(CreateFrame, "GameTooltip", W.TIP_NAME, UIParent, "GameTooltipTemplate")
    if not ok or type(f) ~= "table" or type(f.SetOwner) ~= "function" or type(f.SetUnit) ~= "function" then
        tip = false
        return nil
    end
    tip = f
    return f
end
W.tooltip = tooltip

-- Untertitel der Einheit, ohne spitze Klammern, gefaltet. nil, wenn es keinen gibt.
function W.untertitel(unit)
    local f = tooltip()
    if not f then return nil end
    -- SetOwner setzt den Tooltip zurueck; ClearLines davor ist der Guertel zum Hosentraeger,
    -- falls ein Client SetUnit auf einen nicht geleerten Tooltip anhaengt statt zu ersetzen.
    pcall(f.ClearLines, f)
    if not pcall(f.SetOwner, f, UIParent, "ANCHOR_NONE") then return nil end
    if not pcall(f.SetUnit, f, unit) then pcall(f.Hide, f); return nil end
    if type(f.NumLines) == "function" then
        local n = tonumber(frage(f.NumLines, f))
        if n and n < 2 then pcall(f.Hide, f); return nil end
    end
    local zeile = _G[W.TIP_NAME .. "TextLeft2"]
    local roh = (type(zeile) == "table") and frage(zeile.GetText, zeile) or nil
    pcall(f.Hide, f)
    if type(roh) ~= "string" then return nil end
    -- Ohne spitze Klammern ist Zeile 2 die Stufenzeile und kein Beruf.
    local inhalt = roh:match("^%s*<(.-)>%s*$")
    if not inhalt or inhalt == "" or #inhalt > W.MAX_TITEL then return nil end
    return falte(inhalt)
end

-- Die Schluesselwoerter, gefaltet (ae/oe/ue/ss, klein). Reihenfolge = Vorrang: ein Gastwirt ist
-- auch Haendler, ein Flugmeister heisst manchmal "Windreitermeister", und "Stallmeister" darf
-- nicht ueber "meister" beim Lehrer landen. Deutsch und Englisch in EINER Liste je Rolle —
-- der Client liefert genau eine Sprache, ein Treffer in der falschen ist so gut wie keiner.
W.TITEL = {
    { rolle = "gastwirt",     woerter = { "gastwirt", "innkeeper", "schankwirt" } },
    { rolle = "flugmeister",  woerter = { "flugmeister", "flight master", "greifenmeister",
                                          "gryphon master", "windreiter", "wind rider",
                                          "fledermaus", "bat handler", "hippogryph" } },
    { rolle = "bankier",      woerter = { "bankier", "banker" } },
    { rolle = "auktionator",  woerter = { "auktionator", "auctioneer" } },
    { rolle = "stallmeister", woerter = { "stallmeister", "stable master" } },
    { rolle = "ruestmeister", woerter = { "ruestmeister", "quartermaster" } },
    { rolle = "reparatur",    woerter = { "reparatur", "repair" } },
    { rolle = "lehrer",       woerter = { "lehrer", "lehrmeister", "ausbilder", "trainer" } },
    { rolle = "haendler",     woerter = { "haendler", "verkaeufer", "kraemer", "vendor",
                                          "merchant", "waren", "goods", "supplies", "proviant",
                                          "provisioner", "reagenzien", "reagent", "barkeep",
                                          "bartender" } },
}

function W.titelRolle(unit)
    local t = W.untertitel(unit)
    if not t then return nil end
    for _, e in ipairs(W.TITEL) do
        for _, wort in ipairs(e.woerter) do
            if t:find(wort, 1, true) then return e.rolle end
        end
    end
    return nil
end

-- =============================================================================================
-- 2. ROLLE AUS QUESTIES npcFlags (sprachunabhaengig, optional)
-- =============================================================================================
-- ImportModule gibt fuer einen unbekannten Namen einen LEEREN Stub zurueck. Deshalb wird nie nur
-- die Tabelle geprueft, sondern immer EIN FELD, von dem der Rest abhaengt.
-- REVIEW17: Auch QuestieLoader.ImportModule wird ueber feld() geholt. Regel 4 dieser Datei sagt
-- "pcall um JEDEN Fremdzugriff, auch um das Lesen eines Tabellenfeldes (eine fremde Metatabelle
-- darf werfen)" - und genau hier stand der eine rohe Index auf eine fremde Tabelle. Der
-- Pruefstandsmodus "kaputt" faehrt diesen Fall fuer QuestieDB bereits; QuestieLoader war die
-- Luecke davor.
local function modul(name)
    local imp = feld(_G.QuestieLoader, "ImportModule")
    if type(imp) ~= "function" then return nil end
    local ok, m = pcall(imp, _G.QuestieLoader, name)
    if ok and type(m) == "table" then return m end
    return nil
end

local function questieDB()
    local db = modul("QuestieDB")
    if not db then return nil end
    -- Query*/Get* entstehen erst in QuestieDB:Initialize — vorher ist die Tabelle da und leer,
    -- genau der Fall, den type()=="table" nicht faengt.
    if type(db.QueryNPCSingle) ~= "function" and type(db.GetNPC) ~= "function" then return nil end
    return db
end
W.questieDB = questieDB

local function npcWert(db, id, key)
    if type(db.QueryNPCSingle) == "function" then
        local v = frage(db.QueryNPCSingle, id, key)
        if v ~= nil then return v end
    end
    if type(db.GetNPC) == "function" then          -- Doppelpunkt-Aufruf (QuestieDB.lua:1815)
        local t = frage(db.GetNPC, db, id)
        if type(t) == "table" then return feld(t, key) end
    end
    return nil
end

-- Era-Werte aus Questie/Database/npcDB.lua:58-79. Sie werden NUR benutzt, wenn Questie seine
-- eigene Tabelle nicht herausrueckt — die gelieferte schlaegt die abgeschriebene immer, sonst
-- rechnet Lyra nach einem Client-Wechsel mit Zahlen von gestern.
W.FLAGS_ERA = {
    VENDOR = 4, FLIGHT_MASTER = 8, TRAINER = 16, INNKEEPER = 128, BANKER = 256,
    AUCTIONEER = 4096, STABLEMASTER = 8192, REPAIR = 16384,
}
-- Vorrang wie oben beim Titel: das speziellere Flag zuerst, VENDOR ganz zuletzt.
W.FLAG_ORDNUNG = {
    { rolle = "gastwirt",     flag = "INNKEEPER" },
    { rolle = "flugmeister",  flag = "FLIGHT_MASTER" },
    { rolle = "bankier",      flag = "BANKER" },
    { rolle = "auktionator",  flag = "AUCTIONEER" },
    { rolle = "stallmeister", flag = "STABLEMASTER" },
    { rolle = "lehrer",       flag = "TRAINER" },
    { rolle = "reparatur",    flag = "REPAIR" },
    { rolle = "haendler",     flag = "VENDOR" },
}

-- Bit-Test ohne bit-Bibliothek: WoW liefert Lua 5.1, der Pruefstand LuaJIT, und beide rechnen
-- hier gleich. Nur ganze, nicht negative Zahlen — alles andere ist kein Bitfeld.
local function bitGesetzt(zahl, bit)
    if type(zahl) ~= "number" or type(bit) ~= "number" then return false end
    if zahl < 0 or bit < 1 or zahl ~= math.floor(zahl) or bit ~= math.floor(bit) then return false end
    if zahl >= 2 ^ 53 then return false end
    return math.floor(zahl / bit) % 2 == 1
end
W.bitGesetzt = bitGesetzt

function W.flagRolle(unit)
    local id = npcIdVon(unit)
    if not id then return nil end
    local db = questieDB()
    if not db then return nil end
    local flags = tonumber(npcWert(db, id, "npcFlags"))
    if not flags then return nil end
    local tabelle = feld(db, "npcFlags")
    for _, e in ipairs(W.FLAG_ORDNUNG) do
        local bit = tonumber(feld(tabelle, e.flag)) or W.FLAGS_ERA[e.flag]
        if bitGesetzt(flags, bit) then return e.rolle end
    end
    return nil
end

-- =============================================================================================
-- 3. WACHE AUS DER LAGE (nicht aus dem Namen)
-- =============================================================================================
-- Gefaltete Zonennamen der sechs Era-Hauptstaedte, deutsch und englisch.
W.HAUPTSTAEDTE = {
    ["orgrimmar"] = true,
    ["donnerfels"] = true, ["thunder bluff"] = true,
    ["unterstadt"] = true, ["undercity"] = true,
    ["sturmwind"] = true, ["stormwind city"] = true, ["stormwind"] = true,
    ["eisenschmiede"] = true, ["ironforge"] = true,
    ["darnassus"] = true,
}

function W.wirktWieWache(unit)
    local k = frage(UnitClassification, unit)
    if k ~= "elite" and k ~= "rareelite" and k ~= "worldboss" then return false end
    local zone = frage(GetRealZoneText)
    if type(zone) ~= "string" then return false end
    return W.HAUPTSTAEDTE[falte(zone)] and true or false
end

-- =============================================================================================
-- ROLLE: die drei Quellen in der festen Reihenfolge
-- =============================================================================================
function W.rolleVon(unit)
    local r = W.titelRolle(unit)
    if r then W.stand.quelle = "Untertitel"; return r end
    r = W.flagRolle(unit)
    if r then W.stand.quelle = "Questie npcFlags"; return r end
    if W.wirktWieWache(unit) then W.stand.quelle = "Lage (Elite in der Hauptstadt)"; return "waechter" end
    W.stand.quelle = "nichts erkannt"
    return nil
end

-- =============================================================================================
-- QUESTS
-- =============================================================================================
-- Das eigene Questbuch als Nachschlagewerk: questID -> true (im Buch) bzw. "fertig".
local function questbuch()
    local C = ns.Compat
    if not (C and type(C.questAnzahl) == "function" and type(C.questLogEintrag) == "function") then
        return nil
    end
    local n = tonumber(frage(C.questAnzahl)) or 0
    if n < 0 then return nil end
    if n > W.MAX_LOG then n = W.MAX_LOG end
    local buch = {}
    for i = 1, n do
        local e = frage(C.questLogEintrag, i)
        if type(e) == "table" and not e.header then
            local id = tonumber(e.questID)
            if id and id > 0 then buch[id] = e.complete and "fertig" or true end
        end
    end
    return buch
end
W.questbuch = questbuch

-- Schon abgegeben? Erst der Client (in Era 1.15 vorhanden), dann Questie, sonst "weiss nicht".
local function schonErledigt(qid)
    local f = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or _G.IsQuestFlaggedCompleted
    if type(f) == "function" then
        local v = frage(f, qid)
        if v ~= nil then return v and true or false end
    end
    return nil
end

-- Kann der Spieler die Quest ueberhaupt annehmen? Questie weiss es (Rasse, Klasse, Vorquest,
-- Ruf, Beruf); ohne Questie bleibt "weiss nicht", und dann entscheidet allein schonErledigt.
local function annehmbar(db, qid)
    if db and type(db.IsDoable) == "function" then
        local v = frage(db.IsDoable, qid)     -- Punkt-Aufruf (QuestieDB.lua:653)
        if v ~= nil then return v and true or false end
    end
    return nil
end

local function idListe(wert)
    if type(wert) ~= "table" then return nil end
    local out = {}
    for _, v in ipairs(wert) do
        local id = tonumber(v)
        if id and id > 0 then out[#out + 1] = id end
        if #out >= W.MAX_QUESTS then break end
    end
    if #out == 0 then return nil end
    return out
end

-- "nimmt" schlaegt "gibt": die fertige Quest ist die Handlung, die jetzt ansteht.
function W.questVon(unit)
    local id = npcIdVon(unit)
    if not id then return nil end
    local db = questieDB()
    if not db then return nil end
    local buch = questbuch()
    if not buch then return nil end

    local endet = idListe(npcWert(db, id, "questEnds"))
    for _, qid in ipairs(endet or {}) do
        if buch[qid] == "fertig" then return "nimmt" end
    end

    local startet = idListe(npcWert(db, id, "questStarts"))
    for _, qid in ipairs(startet or {}) do
        if not buch[qid] then
            local erledigt = schonErledigt(qid)
            local kann = annehmbar(db, qid)
            -- Nur wenn NICHTS dagegen spricht. Unbekannt ist kein Ja, aber auch kein Nein:
            -- ohne jede Auskunft (kein Questie, kein Client-Flag) bleibt Lyra still.
            if erledigt == false and kann ~= false then return "gibt" end
            if erledigt == nil and kann == true then return "gibt" end
        end
    end
    return nil
end

-- =============================================================================================
-- Die eine Funktion, die UI/Dialog.lua ruft
-- =============================================================================================
-- Rueckgabe IMMER eine Tabelle: { rolle = ...|nil, quest = ...|nil }. Nie nil, nie ein Fehler —
-- der Aufrufer soll keinen Sonderfall kennen muessen.
function W.verbuendet(unit)
    unit = unit or "target"
    local out = { rolle = nil, quest = nil }
    W.stand.rolle, W.stand.quest, W.stand.quelle = nil, nil, "nichts erkannt"
    if not frage(UnitExists, unit) then W.stand.quelle = "kein Ziel"; return out end
    -- Grenze B: ueber Spieler redet sie nicht, auch nicht ueber befreundete.
    if frage(UnitIsPlayer, unit) then W.stand.quelle = "Spieler"; return out end
    -- Diese Datei ist fuer VERBUENDETE da. Ein angreifbares Ziel beantwortet der alte Weg in
    -- UI/Dialog.lua; hier faengt der Riegel den Fall ab, dass jemand die Funktion anders ruft.
    local kann = frage(UnitCanAttack, "player", unit)
    if kann == nil or kann then W.stand.quelle = "angreifbar"; return out end
    if not an("verbuendetAuskunft") then W.stand.quelle = "abgeschaltet"; return out end
    out.rolle = W.rolleVon(unit)
    out.quest = W.questVon(unit)
    W.stand.rolle, W.stand.quest = out.rolle, out.quest
    return out
end

-- =============================================================================================
-- Status (/lyra status)
-- =============================================================================================
function W.status()
    local d = (ns.sprache and ns.sprache() == "de")
    local out = {}
    local quelle
    if not an("verbuendetAuskunft") then
        quelle = d and "abgeschaltet" or "switched off"
    elseif tip == false then
        quelle = d and "fehlt (kein Tooltip moeglich)" or "missing (no tooltip)"
    else
        quelle = d and "da" or "yes"
    end
    out[#out + 1] = (d and "Verbuendete: %s - zuletzt: %s"
                       or "Allies: %s - last: %s"):format(quelle, tostring(W.stand.quelle))
    out[#out + 1] = (d and "  zuletzt Rolle: %s, Quest: %s"
                        or "  last role: %s, quest: %s")
        :format(tostring(W.stand.rolle or (d and "keine" or "none")),
                tostring(W.stand.quest or (d and "keine" or "none")))
    local db = questieDB()
    out[#out + 1] = (d and "  Questie fuer Quests: %s" or "  Questie for quests: %s")
        :format(db and (d and "da" or "yes") or (d and "fehlt" or "missing"))
    return out
end

-- Fuer den Pruefstand und /lyra debug: den gemerkten Stand zuruecksetzen.
function W.vergiss()
    W.stand.rolle, W.stand.quest, W.stand.quelle = nil, nil, "nichts gefragt"
end
