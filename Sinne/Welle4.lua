-- W4: Sinne/Welle4.lua — Feature-Welle 4 (0.9.x). Vier Bauteile aus companion-v3 D.2, in einer Datei.
--
--   1. Alltag II (W2-10): Berufs-Moment am Handwerksfenster, Erste-Hilfe-Waechter nach knappen
--      Kaempfen, Attunement-Antworten — Letztere NUR auf Zuruf ueber /lyra attunement.
--   2. HC-Modus-Wechsel-Zeile (companion-v3 B.4, Zeile 956): stimmt die Hardcore-Erkennung beim
--      Login nicht mit dem ueberein, was in der Chronik steht, sagt Lyra EINE Zeile.
--   3. WeakAuras als Signalquelle (W2-4): WeakAuras.ScanEvents("LYRA_EREIGNIS", id, klasse, stufe)
--      nach jeder Ausgabe. Doku fuer Bastler: Sinne/WELLE4.md.
--   4. GatherMate2 mitlesen (W2-12): neue Knoten zaehlen, sehr selten eine Zeile.
--
-- Ereignisse: BERUF_ERSTER, BERUF_GRENZE, ERSTE_HILFE, HC_MODUS_AN, HC_MODUS_AUS, GM2_KNOTEN.
--   Alle klasse "plauder", alle stufe 0 (Katalog-Regel design-v2: nur "warn" traegt Stufen 1-3). KEINE Warnung, keine Alarmstufe:
--   nichts davon ist zeitkritisch, und die Welle-3-Lehre lautet, dass der groesste Hebel das
--   Nicht-Sagen ist (docs/welle3-audit.md §0.2).
--
-- Schalter (Account, alle Default AN, UI/Settings.lua Abschnitt "Welle 4"):
--   berufMoment, ersteHilfe, knotenGatherMate, waSignal.
--   Die HC-Wechsel-Zeile hat bewusst KEINEN Schalter: sie kann hoechstens einmal je Modus-Wechsel
--   kommen, und wer den Modus wechselt, hat genau dazu etwas zu hoeren. Ein Kaestchen fuer ein
--   Ereignis, das ein Charakterleben lang ein- bis zweimal feuert, ist Ballast (dieselbe
--   Begruendung wie fuer die DBM-Stillhalte in Core/Init.lua).
--
-- Speicher: LyraGestaltDB.chronik[charKey].hc  (true|false — zuletzt gesehener Hardcore-Zustand).
--   Sonst nichts Dauerhaftes. Zaehler und Basislinien leben nur in der Sitzung.
--
-- Blizzard-API (nur lesend): GetTradeSkillLine und GetCraftName (Era-Craft-API) bzw.
--   C_TradeSkillUI.GetBaseProfessionInfo (Retail/Forever, unbelegt),
--   ns.Compat.Container (C_Container/GetContainerItemInfo mit Weiche), ns.Compat.unitHealthLesbar,
--   ns.Compat.istHardcore, GetTime, hooksecurefunc (nur als dritter Rueckfallweg auf eine
--   FREMDE, ungeschuetzte Tabelle — hooken ist kein Aufrufen).
-- Events: TRADE_SKILL_SHOW, TRADE_SKILL_UPDATE, CRAFT_SHOW, CRAFT_UPDATE,
--   PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED,
--   UNIT_HEALTH (player), PLAYER_LOGIN, PLAYER_ENTERING_WORLD + Hook ns.nachAusgabe.
--
-- Fremd-API:
--   WeakAuras.ScanEvents(event, ...)            WeakAuras/GenericTrigger.lua:916 (asynchron ueber
--                                               eine Queue, :266-282 — nie auf synchronen Lauf bauen)
--   GatherMate2:SendMessage("GatherMate2NodeAdded", zone, nodeType, id, name)
--                                               GatherMate2/GatherMate2.lua:242 (aus AddNode:232)
--   AceEvent-3.0 RegisterMessage / CallbackHandler-1.0 Dispatch(events[e], eventname, ...)
--                                               CallbackHandler-1.0.lua:54,80,121
--   GetCraftName / CRAFT_SHOW als Era-Weg fuer Verzauberkunst
--                                               AckisRecipeList/Core.lua:153-160,193-200
--   Alle drei installiert und im Code nachgelesen (~/Spiele/World of Warcraft/_classic_era_/…).
--
-- KONTRAKT: kein SendChatMessage, keine geschuetzte Funktion, keine Daten anderer Spieler, kein
--   Netzwerk. GatherMate2 liefert Zone, Knotentyp und Knotennamen — Kraeuter und Erz, keine
--   Personen; gespeichert wird davon ohnehin nichts, nur eine Zahl in der Sitzung. Die
--   Attunement-Tabelle ist statischer Text aus dieser Datei, keine Routenberatung und kein
--   Schritt-fuer-Schritt-Plan (companion-v3 E "Halde B").
--
-- PORT: Der Berufs-Moment haengt an GetTradeSkillLine bzw. GetCraftName (Era/TBC/Mists). Auf Retail/Forever gibt es
--   die Funktion nicht; der C_TradeSkillUI-Weg ist hier UNBELEGT (kein Client zum Nachsehen) und
--   steht darum komplett in pcall — schlaegt er fehl, schweigt der Sinn, statt zu raten.
--   Alles andere ist client-neutral: Taschen ueber ns.Compat.Container, HP nur vom SPIELER (unter
--   Secret Values garantiert lesbar), Hardcore ueber ns.Compat.istHardcore.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Sinne.Welle4 = W
ns.Welle4 = W

-- ---------------------------------------------------------------------------------------------
-- Voreinstellungen. Core/Init.lua ist in dieser Welle unantastbar (Version), darum haengen die
-- vier Schluessel hier an ns.DEFAULTS_ACCOUNT. Das laeuft beim LADEN der Datei, also lange vor
-- ADDON_LOADED — und genau dort ruft ns.initDB() defaults(). Reihenfolge stimmt.
-- ---------------------------------------------------------------------------------------------
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.berufMoment == nil then D.berufMoment = true end
    if D.ersteHilfe == nil then D.ersteHilfe = true end
    if D.knotenGatherMate == nil then D.knotenGatherMate = true end
    if D.waSignal == nil then D.waSignal = true end
end

W.GRENZEN = { [75] = true, [150] = true, [225] = true, [300] = true }   -- Lehrling/Geselle/Experte/Kuenstler
W.SKILL_ABSTAND = 10        -- s: so lange nach einer SKILL-Zeile (Sinne/Alltag.lua) schweigt BERUF_ERSTER
W.HP_SCHWELLE_HC = 50       -- % : Hardcore — ab hier gilt ein Kampf als knapp
W.HP_SCHWELLE_NORM = 35     -- % : ohne Hardcore strenger, sonst ist der Hinweis blosses Rauschen
W.ERSTE_HILFE_VERZUG = 3    -- s nach Kampfende (KAMPF_AUS aus Sinne/Kampf.lua liegt auf derselben Flanke)
W.GM2_AB = 10               -- so viele neue Knoten in der Sitzung, bevor ueberhaupt eine Zeile faellt
W.GM2_SCHRITT = 25          -- und danach je weitere 25 ein Versuch (die Regie-Drossel 1800 bremst zusaetzlich)
W.NACHHOL = 35              -- s: zweiter Versuch fuer Plauder-Zeilen, die der Regie-Abstand frisst

local VERBAND_IDS = {       -- dieselbe Liste wie Sinne/Extra.lua (Reisecheck); Leinen bis Runenstoff
    [1251] = true, [2581] = true, [3530] = true, [3531] = true, [6450] = true, [6451] = true,
    [8544] = true, [8545] = true, [14529] = true, [14530] = true,
}

local function jetzt() return (GetTime and GetTime()) or 0 end
local function an(key) return ns.Get(key) ~= false end
local function melde(id, vars)
    if not ns.melde then return false end
    local ok, v = pcall(ns.melde, id, vars)
    return (ok and v) and true or false
end

-- Plauder-Zeile mit EINEM Nachhol (Muster aus Sinne/Chronik.lua und Sinne/Extra.lua). Nur wenn
-- der Regie-ABSTAND der Grund war — Drossel, Gruppe und Still-Modus sind endgueltige Antworten.
local function meldeNachhol(id, vars, gilt)
    if melde(id, vars) then return true end
    local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
    if not (d and d[2] == id and d[1] == "abstand") then return false end
    local rest = 0
    if ns.Regie and ns.Regie.abstandRest then
        local ok, r = pcall(ns.Regie.abstandRest)
        if ok and type(r) == "number" then rest = r end
    end
    ns.Compat.After(math.max(W.NACHHOL, math.min(rest + 1, 180)), function()
        if gilt and not gilt() then return end
        melde(id, vars)
    end)
    return false
end

W.selbsttest = { weakauras = "?", gathermate = "?", berufApi = "?" }

-- ---------------------------------------------------------------------------------------------
-- 1a. Berufs-Moment (W2-10)
--
-- Quelle ist das HANDWERKSFENSTER, nicht die Chat-Zeile: CHAT_MSG_SKILL gehoert seit Welle 1
-- Sinne/Alltag.lua (Ereignis SKILL, jeder 25. Punkt). Zwei Module auf derselben Fremd-Quelle war
-- genau der Fehler, den docs/welle3-audit.md §0.4 zweimal gefunden hat. Hier wird deshalb nur
-- gelesen, was im Fenster steht, und zusaetzlich geschwiegen, wenn SKILL gerade gesprochen hat.
--
-- EHRLICH: dadurch kommt BERUF_ERSTER nur, wenn das Handwerksfenster offen ist. Wer im Laufen
-- Erz abbaut, sieht die Zeile nicht. Das ist der Preis dafuer, Sinne/Alltag.lua nicht zu doppeln.
-- ---------------------------------------------------------------------------------------------
local letzteSkillAusgabe = -1000
local berufBasis = {}           -- [Berufsname] = zuletzt gesehener Rang (nur Sitzung)
local erstesSkillupGesagt = false
W.berufe = berufBasis

-- Die Craft-API. Auf Classic Era laufen Verzauberkunst (und Tierausbildung) NICHT ueber
-- TRADE_SKILL_*, sondern ueber CRAFT_SHOW/CRAFT_UPDATE und GetCraftName(). Belegt aus dem
-- installierten AckisRecipeList (Core.lua:153-160, 193-200): das Addon behandelt genau diesen
-- Fall mit Vorrang, wenn CraftFrame sichtbar ist. Ohne diesen Zweig waere der Berufs-Moment fuer
-- eine der meistgespielten Era-Kombinationen (Magier + Verzauberkunst) blind gewesen.
local function craftLesen()
    if type(_G.GetCraftName) ~= "function" then return nil end
    local ok, name, rank, maxRank = pcall(_G.GetCraftName)
    if not ok then return nil end
    if type(name) ~= "string" or name == "" or name == (_G.UNKNOWN or "Unknown") then return nil end
    rank, maxRank = tonumber(rank), tonumber(maxRank)
    if not (rank and maxRank) or maxRank <= 0 then return nil end
    return name, rank, maxRank
end

-- craftZuerst: nur, wenn das Craft-Fenster gerade der Anlass war. GetCraftName liefert sonst
-- den STAND VON VORHIN weiter (ARL nimmt es darum erst als vierte Wahl) - und eine Zeile ueber
-- einen Beruf, den man gar nicht offen hat, waere schlimmer als keine.
local function berufLesen(craftZuerst)
    if craftZuerst then
        local n, r, m = craftLesen()
        if n then return n, r, m end
    end
    -- C_TradeSkillUI.GetTradeSkillLine gibt es auf Era AUCH, aber mit einer anderen
    -- Argumentfolge als auf Mainline (AckisRecipeList/Core.lua:145-148 beschreibt die
    -- Zweideutigkeit woertlich). Wir nehmen die eindeutige alte Funktion.
    if type(GetTradeSkillLine) == "function" then
        local ok, name, rank, maxRank = pcall(GetTradeSkillLine)
        if not ok then return nil end
        if type(name) ~= "string" or name == "" or name == "UNKNOWN" then return nil end
        rank, maxRank = tonumber(rank), tonumber(maxRank)
        if not (rank and maxRank) or maxRank <= 0 then return nil end
        return name, rank, maxRank
    end
    -- Retail/Forever — UNBELEGT. Feldnamen aus der Doku, kein Client zum Nachmessen: alles in
    -- pcall, jeder Fehlschlag endet still. Lieber kein Satz als ein falscher.
    local U = _G.C_TradeSkillUI
    if type(U) == "table" and type(U.GetBaseProfessionInfo) == "function" then
        local ok, info = pcall(U.GetBaseProfessionInfo)
        if ok and type(info) == "table" then
            local name = info.professionName or info.parentProfessionName
            local rank = tonumber(info.skillLevel)
            local maxRank = tonumber(info.maxSkillLevel)
            if type(name) == "string" and name ~= "" and rank and maxRank and maxRank > 0 then
                return name, rank, maxRank
            end
        end
    end
    return nil
end
W.berufLesen = berufLesen

local function berufBlick(craftZuerst)
    if not an("berufMoment") then return end
    local name, rank, maxRank = berufLesen(craftZuerst)
    if not name then return end
    local vorher = berufBasis[name]
    berufBasis[name] = rank

    -- Berufsgrenze: der Rang steht auf dem Deckel eines Lehrer-Rangs. Drossel "session" mit
    -- key = Beruf + Wert, also je Beruf und je Grenze einmal pro Sitzung.
    if W.GRENZEN[maxRank] and rank >= maxRank then
        meldeNachhol("BERUF_GRENZE", { beruf = name, wert = rank, key = name .. ":" .. rank })
        return
    end
    if vorher == nil then return end            -- erste Sicht = Basislinie, kein Fortschritt
    if rank <= vorher then return end
    if erstesSkillupGesagt then return end
    -- Sinne/Alltag.lua hat gerade SKILL gesagt? Dann ist der Moment schon erzaehlt.
    if jetzt() - letzteSkillAusgabe < W.SKILL_ABSTAND then
        ns.debug("W4: BERUF_ERSTER ausgelassen, SKILL war gerade dran")
        return
    end
    erstesSkillupGesagt = true
    meldeNachhol("BERUF_ERSTER", { beruf = name, wert = rank })
end
W.berufBlick = berufBlick

local function craftBlick() berufBlick(true) end
ns.on("TRADE_SKILL_SHOW", berufBlick)
ns.on("TRADE_SKILL_UPDATE", berufBlick)
ns.on("CRAFT_SHOW", craftBlick)         -- Era: Verzauberkunst, Tierausbildung
ns.on("CRAFT_UPDATE", craftBlick)

-- ---------------------------------------------------------------------------------------------
-- 1b. Erste-Hilfe-Waechter (W2-10)
--
-- Nach einem Kampf, in dem das Leben unter die Schwelle gefallen ist: liegt kein Verband im
-- Beutel, kommt EINMAL je Sitzung ein Hinweis. Auf Hardcore ist die Schwelle grosszuegiger
-- (50 %), sonst strenger (35 %) — ohne ein Leben auf dem Spiel ist der Hinweis blosses Rauschen.
-- gruppeOk = true in den Phrasen: das ist der eine Satz, der auch im Schlachtzug gelten darf.
-- ---------------------------------------------------------------------------------------------
local Cont = ns.Compat.Container
local kampfTief = nil           -- niedrigster HP-Prozentwert im laufenden Kampf
local ersteHilfeGesagt = false

local function hpProzent()
    local _, _, pct = ns.Compat.unitHealthLesbar("player")
    return pct
end

-- Taschen lesbar? Auf einem frisch geladenen Client koennen alle Faecher 0 Plaetze melden —
-- dann ist "kein Verband" keine Aussage, sondern eine Wissensluecke, und Lyra schweigt.
local function taschenLesbar()
    if not (Cont and Cont.GetContainerNumSlots) then return false end
    for bag = 0, 4 do
        local ok, n = pcall(Cont.GetContainerNumSlots, bag)
        if ok and (tonumber(n) or 0) > 0 then return true end
    end
    return false
end

local function verbaendeZaehlen()
    local n = 0
    if not (Cont and Cont.GetContainerItemInfo) then return n end
    for bag = 0, 4 do
        local ok, slots = pcall(Cont.GetContainerNumSlots, bag)
        for slot = 1, (ok and tonumber(slots) or 0) do
            local ok2, info = pcall(Cont.GetContainerItemInfo, bag, slot)
            if ok2 and info and VERBAND_IDS[info.itemID] then n = n + (info.stackCount or 1) end
        end
    end
    return n
end
W.verbaendeZaehlen = verbaendeZaehlen

local function schwelle()
    local hc = ns.Compat and ns.Compat.istHardcore and ns.Compat.istHardcore()
    return hc and W.HP_SCHWELLE_HC or W.HP_SCHWELLE_NORM
end

local function ersteHilfePruefen()
    if ersteHilfeGesagt or not an("ersteHilfe") then return end
    local tief = kampfTief
    local jetztPct = hpProzent()
    if jetztPct and (not tief or jetztPct < tief) then tief = jetztPct end
    if not tief or tief >= schwelle() then return end
    if not taschenLesbar() then return end
    if verbaendeZaehlen() > 0 then return end
    ersteHilfeGesagt = true
    meldeNachhol("ERSTE_HILFE", nil, function()
        -- Beim Nachhol noch einmal nachsehen: wer in der Zwischenzeit Verbaende gekauft hat,
        -- bekommt die Zeile nicht mehr. Eine Erinnerung, die zu spaet falsch wird, ist schlimmer
        -- als gar keine.
        return verbaendeZaehlen() == 0
    end)
end
W.ersteHilfePruefen = ersteHilfePruefen

ns.on("PLAYER_REGEN_DISABLED", function() kampfTief = hpProzent() end)
ns.onUnit("UNIT_HEALTH", "player", function(unit)
    if unit and unit ~= "player" then return end
    if not (ns.Regie and ns.Regie.imKampf) then return end
    local p = hpProzent()
    if p and (not kampfTief or p < kampfTief) then kampfTief = p end
end)
ns.on("PLAYER_REGEN_ENABLED", function()
    ns.Compat.After(W.ERSTE_HILFE_VERZUG, function()
        ersteHilfePruefen()
        kampfTief = nil
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- 1c. Attunement-Antworten (W2-10) — NUR auf Zuruf, /lyra attunement [ziel]
--
-- Kein Ereignis, keine Regie, kein Budget: das hier ist eine Antwort auf eine Frage, und sie geht
-- wie /lyra quests ueber ns.print. Inhalt: die Voraussetzung, knapp. KEINE Route, keine
-- Schrittfolge, keine Gruppenempfehlung — Routenberatung ist "Halde B" (companion-v3 E).
-- Stand Classic Era 1.15.x; Retail hat diese Zugaenge laengst entfernt, darum sagt die Ausgabe
-- ausserhalb des klassischen Inhalts dazu, dass sie von Era spricht.
-- ---------------------------------------------------------------------------------------------
W.ATTUNEMENT = {
    {
        schluessel = "onyxia",
        worte = { "onyxia", "ony", "onyxias", "drachenschuppenumhang", "drakefire" },
        de = { "Onyxias Hort: Du brauchst das Drachenfeuer-Amulett aus der langen Kette um Rend und Nefarian.",
               "Allianz beginnt bei Marschall Windsor in den Brennenden Steppen, Horde mit dem Befehl des Kriegsherrn in Kargath.",
               "Stufe 55 aufwaerts, und ein Stueck davon fuehrt durch die Schwarzfelstiefen. Mehr sage ich nicht — den Weg suchst du dir selbst." },
        en = { "Onyxia's Lair: you need the Drakefire Amulet from the long chain around Rend and Nefarian.",
               "Alliance starts with Marshal Windsor in the Burning Steppes, Horde with Warlord's Command in Kargath.",
               "Level 55 and up, and part of it runs through Blackrock Depths. That's all — find the route yourself." },
    },
    {
        schluessel = "mc",
        worte = { "mc", "geschmolzener kern", "molten", "moltencore", "kern", "core", "ragnaros" },
        de = { "Geschmolzener Kern: Lothos Riftwaker am Schwarzfels gibt „Einstimmung auf den Kern“ ab Stufe 55.",
               "Vorher musst du selbst einmal bis zum Kern-Eingang tief in den Schwarzfelstiefen gewesen sein.",
               "Danach setzt Lothos dich direkt hinein. Einmal laufen, dann nie wieder." },
        en = { "Molten Core: Lothos Riftwaker at Blackrock Mountain gives \"Attunement to the Core\" from level 55.",
               "First you have to reach the Core entrance yourself, deep inside Blackrock Depths.",
               "After that Lothos ports you straight in. Walk it once, never again." },
    },
    {
        schluessel = "bwl",
        worte = { "bwl", "pechschwingenhort", "blackwing", "nefarian" },
        de = { "Pechschwingenhort: General Drakkisath in der Oberen Schwarzfelsspitze muss fallen.",
               "Danach die Befehlskugel in seiner Kammer anfassen — sie gibt „Schwarzhands Befehl“ und bringt dich spaeter hinein.",
               "Stufe 60. Und ja, das heisst UBRS, mit allem, was dazugehoert." },
        en = { "Blackwing Lair: General Drakkisath in Upper Blackrock Spire has to fall.",
               "Then touch the Orb of Command in his chamber — it gives \"Blackhand's Command\" and takes you in later.",
               "Level 60. And yes, that means UBRS, with everything that entails." },
    },
    {
        schluessel = "naxx",
        worte = { "naxx", "naxxramas", "kel'thuzad", "kelthuzad" },
        de = { "Naxxramas: keine Questkette, sondern Ruf. Wohlwollend bei der Argentumdaemmerung, Stufe 60.",
               "Die Einstimmung gibt Erzmagierin Angela Dosantos in der Kapelle des Hoffnungsvollen Lichts.",
               "Sie kostet Gold — weniger, je besser dein Ruf steht. Das ist der ganze Handel." },
        en = { "Naxxramas: no quest chain, reputation. Honored with the Argent Dawn, level 60.",
               "The attunement comes from Archmage Angela Dosantos at Light's Hope Chapel.",
               "It costs gold — less the better your standing. That's the whole deal." },
    },
}

-- Rueckgabe: Liste fertiger Zeilen fuer ns.print.
function W.attunement(arg)
    local sp = (ns.sprache and ns.sprache()) or "en"
    local de = (sp == "de")
    arg = tostring(arg or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if arg ~= "" then
        for _, e in ipairs(W.ATTUNEMENT) do
            for _, w in ipairs(e.worte) do
                if arg == w or arg:find(w, 1, true) then
                    local out = {}
                    for _, z in ipairs((de and e.de) or e.en) do out[#out + 1] = z end
                    out[#out + 1] = de and "(Classic Era. Ich zeige keine Route — nur, was du brauchst.)"
                                       or "(Classic Era. No route from me — only what you need.)"
                    return out
                end
            end
        end
    end
    local namen = {}
    for _, e in ipairs(W.ATTUNEMENT) do namen[#namen + 1] = e.schluessel end
    return {
        de and "Einstimmungen, die ich kenne: " .. table.concat(namen, ", ")
            or "Attunements I know: " .. table.concat(namen, ", "),
        de and "Frag mit /lyra attunement <name>. Ich nenne die Voraussetzung, nicht den Weg."
            or "Ask with /lyra attunement <name>. I name the requirement, not the route.",
    }
end

-- ---------------------------------------------------------------------------------------------
-- 2. HC-Modus-Wechsel-Zeile (companion-v3 B.4)
--
-- Der Zustand steht in der Chronik dieses Charakters. Fehlt er (erster Login mit Welle 4), wird
-- er nur GESETZT — eine bestehende Figur ist nicht gerade eben Hardcore geworden, und eine Zeile
-- darueber waere gelogen. Erst der zweite, abweichende Login redet.
-- ---------------------------------------------------------------------------------------------
local function chronikDB()
    if not (LyraGestaltDB and ns.charKey) then return nil end
    LyraGestaltDB.chronik = LyraGestaltDB.chronik or {}
    local c = LyraGestaltDB.chronik[ns.charKey]
    if type(c) ~= "table" then c = {}; LyraGestaltDB.chronik[ns.charKey] = c end
    return c
end

local hcGeprueft = false

-- Die Entscheidung als reine Funktion: kein Speicher, keine Uhr, keine Ausgabe. Das ist die
-- ganze Regel, und sie laesst sich so in allen vier Faellen pruefen, ohne einen Login zu spielen.
function W.hcEntscheidung(vorher, jetztHc)
    if type(vorher) ~= "boolean" then return nil end       -- Basislinie fehlt: nur setzen, nichts sagen
    if vorher == jetztHc then return nil end
    return jetztHc and "HC_MODUS_AN" or "HC_MODUS_AUS"
end

function W.hcPruefen()
    if hcGeprueft then return nil end
    local c = chronikDB()
    if not c then return nil end
    hcGeprueft = true
    local jetztHc = (ns.Compat and ns.Compat.istHardcore and ns.Compat.istHardcore()) and true or false
    local id = W.hcEntscheidung(c.hc, jetztHc)
    c.hc = jetztHc
    if not id then return nil end
    local verzug = 6
    if ns.Regie and ns.Regie.loginSlot then
        local ok, v = pcall(ns.Regie.loginSlot, 6)
        if ok and type(v) == "number" then verzug = v end
    end
    -- Mit Nachhol: der Login-Slot haelt den Plan der Regie ein, aber Welle 4 steht in der TOC
    -- ganz hinten und bekommt damit den LETZTEN Slot - und wenn ein Modul ohne Slot (Rituale:
    -- SPAET) kurz davor plaudert, frisst der Abstand die Zeile. Im Pruefstand reproduziert,
    -- Drop-Grund "abstand". Eine Zeile, die es ein- bis zweimal im Charakterleben gibt, darf
    -- daran nicht scheitern.
    ns.Compat.After(verzug, function() meldeNachhol(id, { key = id }) end)
    return id
end

-- ---------------------------------------------------------------------------------------------
-- 3. WeakAuras als Signalquelle (W2-4)
--
-- Sinne/Bruecken2.lua sendet seit Welle 2 "LYRA_GESTALT" (id, klasse, stufe). Das bleibt, damit
-- bestehende Auren weiterlaufen. Neu kommt "LYRA_EREIGNIS" mit derselben Nutzlast dazu — das ist
-- der Name, der in der Doku und auf der CurseForge-Seite steht (Sinne/WELLE4.md). Zwei Namen fuer
-- dasselbe Signal kosten nichts (ScanEvents ist eine Queue) und ersparen einen Bruch.
-- ---------------------------------------------------------------------------------------------
-- W6 (Recherche 11, P1-2): Ein Wort macht das Signal doppelt so brauchbar.
-- WeakAuras kennt neben ScanEvents auch ScanEventsByID(event, id, ...)
-- ($A/WeakAuras/GenericTrigger.lua:878 Private.ScanEventsByID, :888 WeakAuras.ScanEventsByID).
-- Das feuert BEIDES: "LYRA_EREIGNIS" und zusaetzlich "LYRA_EREIGNIS:HP20". Damit haengt eine
-- Aura an genau EINEM Lyra-Ereignis, ohne eine einzige Zeile Custom-Lua - vorher musste jede
-- Aura alle Lyra-Zeilen empfangen und selbst "if id == ..." schreiben.
-- Der Rueckfall auf ScanEvents ist Pflicht: aeltere WeakAuras kennen ScanEventsByID nicht.
-- W.waWeg haelt fest, welcher Weg gilt (/lyra status, Welle 6).
W.waWeg = nil
local waIdAus = false      -- ScanEventsByID hat einmal geworfen: ab jetzt nur noch ScanEvents.
                           -- Das Merken liegt HIER, nicht in WeakAuras' Tabelle - fremde
                           -- Zustaende schreiben wir grundsaetzlich nicht (Kontrakt).
local function waSenden(id, e)
    if not an("waSignal") then return false end
    local WA = _G.WeakAuras
    if type(WA) ~= "table" then W.waWeg = nil; return false end
    local fn, weg
    if not waIdAus and type(WA.ScanEventsByID) == "function" then
        fn, weg = WA.ScanEventsByID, "ScanEventsByID"
    elseif type(WA.ScanEvents) == "function" then
        fn, weg = WA.ScanEvents, "ScanEvents"
    else
        W.waWeg = nil; return false
    end
    local ok = pcall(fn, "LYRA_EREIGNIS", id, e and e.klasse, e and e.stufe)
    -- Wirft ScanEventsByID (andere Signatur in einer sehr alten Kopie), EINMAL der alte Weg -
    -- und ab dann bleibt es beim alten. Zwei pcalls je Zeile waeren Dauerkosten fuer nichts.
    if not ok and weg == "ScanEventsByID" and type(WA.ScanEvents) == "function" then
        waIdAus = true
        ok = pcall(WA.ScanEvents, "LYRA_EREIGNIS", id, e and e.klasse, e and e.stufe)
        if ok then weg = "ScanEvents (Rueckfall)" end
    end
    if ok then W.waWeg = weg end
    return ok
end
W.waSenden = waSenden

ns.nachAusgabe(function(id, e)
    if id == "SKILL" then letzteSkillAusgabe = jetzt() end
    waSenden(id, e)
end)

-- ---------------------------------------------------------------------------------------------
-- 4. GatherMate2 mitlesen (W2-12, XS)
--
-- GatherMate2 ist installiert und der Weg im Code nachgelesen: AddNode() feuert die AceEvent-
-- Message "GatherMate2NodeAdded" (GatherMate2.lua:242). Wir haengen einen EIGENEN Empfaenger an
-- die Message — nicht an GatherMate2 selbst. CallbackHandler haelt die Ziele getrennt, unser
-- Eintrag kann dort nichts von GatherMate2 ueberschreiben (CallbackHandler-1.0.lua:80-121).
--
-- Drei Wege, in dieser Reihenfolge, jeder in pcall:
--   1. eigener AceEvent-Empfaenger ueber LibStub("AceEvent-3.0")
--   2. dieselbe Methode von GatherMate2 geliehen (self = unsere Tabelle) — geht ohne LibStub
--   3. hooksecurefunc auf GatherMate2.AddNode — nur, wenn die Message ueberhaupt nicht erreichbar ist
-- Klappt keiner, bleibt es still. Der Selbsttest beim Login haelt fest, welcher gegriffen hat.
-- ---------------------------------------------------------------------------------------------
local gm2Empfaenger = { __lyra = "Lyra_Gestalt Welle 4" }
W.gm2Empfaenger = gm2Empfaenger
W.gm2Zaehler = 0
local gm2NaechsteMarke = nil
local gm2Gebunden = false

local function gm2Knoten(_, _, _, _, name)
    if not an("knotenGatherMate") then return end
    W.gm2Zaehler = W.gm2Zaehler + 1
    gm2NaechsteMarke = gm2NaechsteMarke or W.GM2_AB
    if W.gm2Zaehler < gm2NaechsteMarke then return end
    gm2NaechsteMarke = W.gm2Zaehler + W.GM2_SCHRITT
    -- Kein Nachhol: das ist die unwichtigste Zeile im ganzen Addon. Faellt sie am Abstand,
    -- faellt sie eben. Der Knotenname geht NICHT in die Zeile, er dient nur dem Debug.
    ns.debug("W4: GatherMate2-Knoten " .. tostring(W.gm2Zaehler) .. " (" .. tostring(name) .. ")")
    melde("GM2_KNOTEN", { anzahl = W.gm2Zaehler })
end
W.gm2Knoten = gm2Knoten

function W.gm2Binden()
    if gm2Gebunden then return "schon" end
    if not an("knotenGatherMate") then return "aus" end
    local gm = _G.GatherMate2
    if type(gm) ~= "table" then return "-" end

    -- Weg 1: eigener AceEvent-Empfaenger
    if type(_G.LibStub) == "function" then
        local ok, AE = pcall(_G.LibStub, "AceEvent-3.0", true)
        if ok and type(AE) == "table" and type(AE.Embed) == "function" then
            local ok2 = pcall(AE.Embed, AE, gm2Empfaenger)
            if ok2 and type(gm2Empfaenger.RegisterMessage) == "function" then
                local ok3 = pcall(gm2Empfaenger.RegisterMessage, gm2Empfaenger, "GatherMate2NodeAdded", gm2Knoten)
                if ok3 then gm2Gebunden = true; return "acevent" end
            end
        end
    end
    -- Weg 2: die Methode leihen. CallbackHandler nimmt das uebergebene self als Ziel, wir stehen
    -- damit als eigener Empfaenger in derselben Registry — ohne LibStub im eigenen Addon.
    if type(gm.RegisterMessage) == "function" then
        local ok = pcall(gm.RegisterMessage, gm2Empfaenger, "GatherMate2NodeAdded", gm2Knoten)
        if ok then gm2Gebunden = true; return "geliehen" end
    end
    -- Weg 3: Hook. hooksecurefunc haengt sich HINTER die fremde Funktion, ruft sie nicht auf und
    -- veraendert sie nicht. Signatur wie AddNode(self, zone, x, y, nodeType, name).
    if type(gm.AddNode) == "function" and type(hooksecurefunc) == "function" then
        local ok = pcall(hooksecurefunc, gm, "AddNode", function(_, zone, _, _, nodeType, name)
            gm2Knoten("GatherMate2NodeAdded", zone, nodeType, nil, name)
        end)
        if ok then gm2Gebunden = true; return "hook" end
    end
    return "fehlgeschlagen"
end

-- ---------------------------------------------------------------------------------------------
-- Login: Selbsttest + Bindungen. Alles hier ist Feature-Erkennung, nicht Vertrauen.
-- ---------------------------------------------------------------------------------------------
ns.on("PLAYER_LOGIN", function()
    W.selbsttest.berufApi = (type(GetTradeSkillLine) == "function")
        and ("GetTradeSkillLine" .. ((type(_G.GetCraftName) == "function") and "+Craft" or ""))
        or ((type(_G.C_TradeSkillUI) == "table") and "C_TradeSkillUI (unbelegt)" or "-")
    local WA = _G.WeakAuras
    W.selbsttest.weakauras = (type(WA) == "table" and type(WA.ScanEvents) == "function") and "ok" or "-"
    -- GatherMate2 laedt ueber AceAddon und ist bei PLAYER_LOGIN in aller Regel da; falls der
    -- LoadManager es spaeter nachzieht, versucht es PLAYER_ENTERING_WORLD noch einmal.
    W.selbsttest.gathermate = W.gm2Binden()
    ns.debug("W4 Selbsttest: Beruf=" .. W.selbsttest.berufApi
        .. " WeakAuras=" .. W.selbsttest.weakauras
        .. " GatherMate2=" .. tostring(W.selbsttest.gathermate))
end)

local pewGesehen = false
ns.on("PLAYER_ENTERING_WORLD", function()
    if not gm2Gebunden then W.selbsttest.gathermate = W.gm2Binden() end
    if pewGesehen then return end               -- nur der ERSTE Weltantritt ist der Login
    pewGesehen = true
    W.hcPruefen()
end)

-- ---------------------------------------------------------------------------------------------
-- /lyra status — eine Zeile, wie es Sinne/Bruecken2.lua und Sinne/Details.lua tun.
-- ---------------------------------------------------------------------------------------------
function W.status()
    return {
        ("Welle 4: Beruf %s (%s) · Erste Hilfe %s · WeakAuras %s · GatherMate2 %s (%d Knoten)"):format(
            an("berufMoment") and "an" or "aus", tostring(W.selbsttest.berufApi),
            an("ersteHilfe") and "an" or "aus",
            an("waSignal") and tostring(W.selbsttest.weakauras) or "aus",
            tostring(W.selbsttest.gathermate), W.gm2Zaehler),
    }
end
