-- Sinne/Welle9.lua — W9: Oekosystem und Export (Welle 9a, 20.09.2026).
--
-- Drei Dinge, die nichts miteinander zu tun haben ausser der Welle, und deshalb in drei klar
-- getrennten Abschnitten stehen:
--
--   1. LibDataBroker (Recherche 11 §3 P2-3). Lyra meldet ihren Zustand als Datenobjekt an.
--      Titan-Panel, Bartender4, ChocolateBar, Knopf-Sammler zeigen ihn dann an, ohne dass wir
--      irgendetwas ueber sie wissen muessen. UI/Minimap.lua bleibt UNVERAENDERT - LDB kommt
--      DAZU, es ersetzt nichts. Fehlt LibStub oder LDB, entsteht gar kein Objekt.
--
--   2. Profil-Export/-Import (P2-4). Eine Zeichenkette, die man einem Freund schickt oder in
--      ein zweites WoW-Verzeichnis traegt. NUR Einstellungen: keine Chronik, kein Name, kein
--      Realm, keine SavedVariables-Rohdaten. Was mit darf, steht in EINER Positivliste
--      (W.PROFIL), und der Import nimmt nur, was dort steht - und nur in dem Typ und
--      Wertebereich, der dort steht.
--
--   3. Questie ueber die OFFIZIELLE API (P2-1). Questie hat seit 11.x ein Public/-Verzeichnis
--      mit der ausdruecklichen Zusage "stable and safe to use" (Public/README.md:3). Sinne/
--      Questie2.lua ging bis 0.12.0 nur ueber QuestieLoader:ImportModule - also ueber Interna.
--      Diese Datei legt den offiziellen Weg darueber; der interne bleibt als Rueckfall.
--
-- Steht GANZ ZULETZT in der TOC, hinter Sinne/Welle8.lua:
--   * Sie liest ns.Questie2 (Sinne/Questie2.lua), ns.Stimme, ns.Settings, ns.Regie - alles muss
--     fertig sein.
--   * Ihr ns.onSetting-Mantel soll AUSSEN um den von Sinne/Welle6.lua und UI/Streamer.lua
--     liegen: er zeichnet nur den LDB-Text nach, und das soll als Letztes passieren.
--
-- Kontrakt: kein SendChatMessage, keine geschuetzte Funktion, keine Fremddaten, kein Netz.
-- Jede Fremd-API (LibStub, LDB, Questie.API) steht in pcall; faellt sie aus, ist diese Datei
-- still und alles andere laeuft weiter.
-- Neue Ereignisse: keine. Neue SavedVariables: keine (nur gelesen und geschrieben wird, was
-- Core/Init.lua und die anderen Wellen ohnehin anlegen).
local ADDON, ns = ...
local W = {}
ns.Welle9 = W
ns.Sinne = ns.Sinne or {}
ns.Sinne.Welle9 = W

W.VERSION = 1            -- Schema der Export-Zeichenkette
W.MARKE   = "LYRA1-"     -- Praefix; die Zahl ist W.VERSION
W.MAX_IMPORT = 4000      -- Zeichen: laenger ist kein Profil, sondern ein Unfall

local function de() return ns.sprache() == "de" end

-- =============================================================================================
-- 1  LibDataBroker
-- =============================================================================================
-- Der Text ist kurz, weil er in eine Leiste muss: "Lyra: normal" / "Lyra: still" /
-- "Lyra: barrierefrei". Der Tooltip traegt die Langfassung.
W.LDB_NAME = "Lyra_Gestalt"
W.ldb, W.ldbObjekt = nil, nil
W.ldbGrund = "nicht versucht"

local function ldbLib()
    if type(_G.LibStub) ~= "function" and type(_G.LibStub) ~= "table" then return nil, "kein LibStub" end
    local ok, lib = pcall(_G.LibStub, "LibDataBroker-1.1", true)
    if not ok or type(lib) ~= "table" then return nil, "kein LibDataBroker" end
    if type(lib.NewDataObject) ~= "function" then return nil, "LDB ohne NewDataObject" end
    return lib
end
W.ldbLib = ldbLib

-- Kurzform des Zustands. Reihenfolge = Wichtigkeit: wer barrierefrei eingeschaltet hat, will
-- das sehen; wer still gestellt hat, ebenso; sonst steht das Preset da.
function W.zustandKurz()
    local d = de()
    if ns.Get("barrierefrei") then return d and "barrierefrei" or "accessible" end
    if ns.Get("stimme") == false and ns.Get("gespraechig") == "still" then
        return d and "ganz still" or "fully silent"
    end
    if ns.Get("gespraechig") == "still" then return d and "still" or "silent" end
    if ns.Get("versteckt") then return d and "versteckt" or "hidden" end
    return tostring(ns.Get("preset") or "normal")
end

function W.ldbText()
    return "Lyra: " .. W.zustandKurz()
end

-- Die Langfassung fuer den Tooltip. Drei Zeilen, mehr nicht - ein Broker-Tooltip ist kein
-- Statusbericht, den gibt es unter /lyra status.
function W.ldbZeilen()
    local d = de()
    local out = {}
    out[#out + 1] = { ns.L and ns.L["Lyra Gestalt"] or "Lyra", W.zustandKurz() }
    out[#out + 1] = { d and "Gespraechigkeit" or "Talkativeness", tostring(ns.Get("gespraechig")) }
    out[#out + 1] = { d and "Stimme" or "Voice", ns.Get("stimme") and (d and "an" or "on") or (d and "aus" or "off") }
    local S = ns.Stimme
    if S and S.ttsModus and S.ttsModus() ~= "aus" then
        out[#out + 1] = { d and "Vorlesen" or "Reading aloud", tostring(S.ttsModus()) }
    end
    return out
end

local function ldbKlick(_, knopf)
    if knopf == "RightButton" then
        if ns.oeffneSettings then ns.oeffneSettings(); return end
    end
    if ns.menue then ns.menue()
    elseif ns.oeffneSettings then ns.oeffneSettings()
    elseif ns.hilfe then ns.hilfe() end
end

local function ldbTooltip(tt)
    if not (tt and tt.AddLine) then return end
    local d = de()
    pcall(function()
        tt:AddLine(ns.L and ns.L["Lyra Gestalt"] or "Lyra", 0.7, 0.55, 1)
        for _, z in ipairs(W.ldbZeilen()) do
            if tt.AddDoubleLine then tt:AddDoubleLine(z[1], z[2], 1, 1, 1, 0.8, 0.8, 0.8)
            else tt:AddLine(z[1] .. ": " .. z[2], 1, 1, 1) end
        end
        tt:AddLine(d and "Klick: Menue  -  Rechtsklick: Einstellungen"
                     or "Click: menu  -  Right-click: settings", 0.7, 0.7, 0.7)
    end)
end

function W.ldbAnlegen()
    if W.ldbObjekt then return W.ldbObjekt end
    local lib, grund = ldbLib()
    if not lib then W.ldbGrund = grund; return nil end
    -- Liegt schon ein Objekt dieses Namens (zweite Kopie des Addons, /reload-Reste), nicht
    -- noch eins anlegen: NewDataObject gibt dann nil zurueck, und wir nehmen das vorhandene.
    local ok, obj = pcall(lib.GetDataObjectByName, lib, W.LDB_NAME)
    if ok and type(obj) == "table" then
        W.ldb, W.ldbObjekt, W.ldbGrund = lib, obj, "vorhanden"
        W.ldbNachziehen()
        return obj
    end
    local ok2, neu = pcall(lib.NewDataObject, lib, W.LDB_NAME, {
        type    = "data source",
        label   = "Lyra",
        text    = W.ldbText(),
        icon    = (ns.PFAD or "") .. "bilder\\icon.png",
        OnClick = ldbKlick,
        OnTooltipShow = ldbTooltip,
    })
    if not ok2 or type(neu) ~= "table" then W.ldbGrund = "NewDataObject wirft"; return nil end
    W.ldb, W.ldbObjekt, W.ldbGrund = lib, neu, "angelegt"
    return neu
end

function W.ldbNachziehen()
    local o = W.ldbObjekt
    if not o then return false end
    -- Das Datenobjekt hat eine __newindex-Metatabelle (LDB feuert daraus die Callbacks an die
    -- Anzeige-Addons). Ein Schreibzugriff kann also fremden Code ausloesen - darum pcall.
    local ok = pcall(function()
        o.text = W.ldbText()
        o.value = W.zustandKurz()
    end)
    return ok
end

-- =============================================================================================
-- 2  Profil-Export / -Import
-- =============================================================================================
-- WARUM OHNE LibDeflate UND LibSerialize (Recherche 11 nannte beide):
-- Die beiden zusammen sind rund 100 KB Fremdcode mit eigenem Lizenz- und Pflegeaufwand. Das
-- steht gegen eine GEMESSENE Groesse: ein vollstaendiges Profil mit allen 51 Schluesseln der
-- Positivliste misst roh 710 Zeichen und kodiert 953 (Messung vom 20.09.2026, Prueftstand
-- w9a Szene 4 haelt die Zahl fest). Eine Chat-Zeile fasst 255 Zeichen, ein Forum-Beitrag,
-- ein Discord-Block und eine Makro-Datei fassen das Vielfache - der Weg, den eine solche
-- Kette wirklich geht, ist Kopieren und Einfuegen, nicht /say.
-- LibDeflate wuerde daraus vielleicht 500 machen. 450 gesparte Zeichen sind den Zuwachs an
-- Abhaengigkeiten nicht wert, und sie waeren es auch bei 255 nicht: dann waere die richtige
-- Antwort, die Positivliste zu teilen, nicht eine zlib einzubetten.
-- Ein eigenes Format kostet dafuer fuenfzig Zeilen, hat keine Lizenzfrage und ist lesbar,
-- wenn jemand nachsehen will, was er da verschickt.
--
-- AUFBAU
--   roh       = "1|0.12.0|blaseDauer=n6|glow=b1|preset=snormal|...|#a1b2c3d4"
--   Zeichen   = "LYRA1-" .. Lyra64(roh)
-- Feld 1 ist das Schema, Feld 2 die Addon-Version (nur zur Anzeige - ein Profil aus 0.11.0
-- wird angenommen, seine Schluessel sind eine Teilmenge). Das letzte Feld ist die Pruefsumme
-- ueber alles davor; sie faengt Tippfehler und abgeschnittene Zeilen. Sie ist KEIN Schutz gegen
-- Absicht und will es nicht sein - dafuer ist die Positivliste da, und die prueft jeden
-- einzelnen Wert.

-- Positivliste. Alles, was NICHT hier steht, wird beim Export weggelassen und beim Import
-- abgelehnt. Drinstehen darf nur, was eine GESCHMACKSENTSCHEIDUNG ist.
-- Ausdruecklich NICHT drin, und jedes aus einem eigenen Grund:
--   pos, minimapWinkel  - haengen am Bildschirm des Spielers, nicht an seinem Geschmack
--   versteckt           - ein Zustand von gerade eben, keine Einstellung
--   ttsStimme           - eine voiceID des Betriebssystems; auf einem anderen Rechner zeigt
--                         dieselbe Zahl auf eine andere Stimme
--   spielzeit, klicks, fragen, eingerichtet, setupGefragt, einladungGezeigt,
--   schriftAutoMigriert, barrierefreiVorher  - Zaehler und Merker, keine Einstellungen
--   aussprache          - eigene Eintraege sind FREITEXT des Spielers. Freitext kann einen
--                         Namen enthalten, und dieser Export traegt keine Namen. Punkt.
--   chronik, chars, account-Rohdaten - gar nicht erst in der Naehe
W.PROFIL = {
    -- Seite 1
    preset       = { typ = "s", werte = { leise = 1, normal = 1, lebendig = 1, streamer = 1, eigen = 1 } },
    ansicht      = { typ = "s", werte = { portrait = 1, figur = 1 } },
    sprache      = { typ = "s", werte = { auto = 1, de = 1, en = 1 } },
    anrede       = { typ = "s", werte = { auto = 1, m = 1, f = 1, keine = 1 } },
    gespraechig  = { typ = "s", werte = { still = 1, wenig = 1, normal = 1, viel = 1 } },
    groesse      = { typ = "s", werte = { klein = 1, mittel = 1, gross = 1 } },
    bewegung     = { typ = "s", werte = { voll = 1, reduziert = 1, aus = 1 } },
    scale        = { typ = "n", min = 0.2,  max = 1.5 },
    stimme       = { typ = "b" },
    glow         = { typ = "b" },
    minimap      = { typ = "b" },
    barrierefrei = { typ = "b" },
    figur        = { typ = "b" },
    gesperrt     = { typ = "b" },
    -- Feineinstellung: Stimme
    kanal        = { typ = "s", werte = { Master = 1, SFX = 1, Dialog = 1, Ambience = 1 } },
    tts          = { typ = "s", werte = { aus = 1, fallback = 1, immer = 1 } },
    ttsPersoenlich = { typ = "b" },
    ttsKoexistenz  = { typ = "b" },
    oggZurueckhalten = { typ = "b" },
    untertitel   = { typ = "b" },
    leiste       = { typ = "s", werte = { aus = 1, auto = 1, immer = 1 } },
    cues         = { typ = "b" },
    sprecher     = { typ = "b" },
    -- Feineinstellung: Lesbarkeit
    kontrast     = { typ = "b" },
    warnSymbol   = { typ = "b" },
    blaseDauer   = { typ = "n", min = 3,    max = 15 },
    kampfAlpha   = { typ = "n", min = 0.4,  max = 1.0 },
    -- schrift ist der einzige Schluessel mit zwei Gestalten: "auto" ODER eine Zahl 10..28.
    schrift      = { typ = "sn", werte = { auto = 1 }, min = 10, max = 28 },
    -- Feineinstellung: Verhalten
    kampfNurWarnungen = { typ = "b" },
    gruppeSchweigen   = { typ = "b" },
    frech        = { typ = "b" },
    fotos        = { typ = "b" },
    ultra        = { typ = "b" },
    streamer     = { typ = "b" },
    erbeImmer    = { typ = "b" },
    ssf          = { typ = "b" },
    persoenlich  = { typ = "b" },
    -- Feineinstellung: Datenquellen und Wellen
    gefahrenkarte     = { typ = "b" },
    vorwarnung        = { typ = "b" },
    profil            = { typ = "b" },
    karte             = { typ = "b" },
    detailsKommentar  = { typ = "b" },
    bossChronik       = { typ = "b" },
    questieTief       = { typ = "b" },
    berufMoment       = { typ = "b" },
    ersteHilfe        = { typ = "b" },
    knotenGatherMate  = { typ = "b" },
    waSignal          = { typ = "b" },
    pinBeinahe        = { typ = "b" },
    pinNotiz          = { typ = "b" },
    pinGefahr         = { typ = "b" },
    punktNah          = { typ = "b" },
}

-- ---------------------------------------------------------------- Lyra64
-- Base64 mit dem URL-sicheren Alphabet und OHNE Fuellzeichen. Grund fuer "-_" statt "+/":
-- die Zeichenkette landet in einem EditBox, wird per Strg+C kopiert und oft durch ein Forum,
-- einen Discord-Code-Block oder eine URL geschleift. "+" und "/" ueberleben das nicht immer,
-- "-" und "_" schon. Ohne Fuellzeichen, weil "=" das Trennzeichen mancher Werkzeuge ist.
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local B64R = {}
for i = 1, #B64 do B64R[B64:sub(i, i)] = i - 1 end

function W.kodiere(s)
    s = tostring(s or "")
    local out, i, n = {}, 1, #s
    while i <= n do
        local a, b, c = s:byte(i), s:byte(i + 1), s:byte(i + 2)
        local z = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(z / 262144) % 64
        local c2 = math.floor(z / 4096) % 64
        local c3 = math.floor(z / 64) % 64
        local c4 = z % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1)
        out[#out + 1] = B64:sub(c2 + 1, c2 + 1)
        if b then out[#out + 1] = B64:sub(c3 + 1, c3 + 1) end
        if c then out[#out + 1] = B64:sub(c4 + 1, c4 + 1) end
        i = i + 3
    end
    return table.concat(out)
end

function W.dekodiere(s)
    s = tostring(s or "")
    local n = #s
    if n % 4 == 1 then return nil end          -- diese Laenge kann keine Kodierung haben
    local out, i = {}, 1
    while i <= n do
        local c1, c2 = B64R[s:sub(i, i)], B64R[s:sub(i + 1, i + 1)]
        if not c1 or not c2 then return nil end
        local c3 = (i + 2 <= n) and B64R[s:sub(i + 2, i + 2)] or nil
        local c4 = (i + 3 <= n) and B64R[s:sub(i + 3, i + 3)] or nil
        if i + 2 <= n and not c3 then return nil end
        if i + 3 <= n and not c4 then return nil end
        local z = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
        out[#out + 1] = string.char(math.floor(z / 65536) % 256)
        if c3 then out[#out + 1] = string.char(math.floor(z / 256) % 256) end
        if c4 then out[#out + 1] = string.char(z % 256) end
        i = i + 4
    end
    return table.concat(out)
end

-- djb2. Acht Hexstellen, und sie liegen sicher unter 2^53 - Lua 5.1 rechnet mit Doubles,
-- ein Ueberlauf waere hier eine stille Fehlerquelle.
function W.pruefsumme(s)
    local h = 5381
    for i = 1, #tostring(s or "") do
        h = (h * 33 + s:byte(i)) % 4294967296
    end
    return ("%08x"):format(h)
end

-- ---------------------------------------------------------------- Werte hin und zurueck
local function schreibWert(regel, v)
    local t = type(v)
    if regel.typ == "b" then
        if t ~= "boolean" then return nil end
        return "b" .. (v and "1" or "0")
    elseif regel.typ == "n" then
        if t ~= "number" then return nil end
        return "n" .. tostring(v)
    elseif regel.typ == "s" then
        if t ~= "string" then return nil end
        return "s" .. v
    elseif regel.typ == "sn" then
        if t == "number" then return "n" .. tostring(v) end
        if t == "string" then return "s" .. v end
    end
    return nil
end

-- Rueckgabe: Wert, oder nil + Grund. Hier faellt JEDE Pruefung: Typ, Wertebereich, Wertemenge.
local function lesWert(regel, roh)
    local marke, rest = roh:sub(1, 1), roh:sub(2)
    if regel.typ == "b" then
        if marke ~= "b" then return nil, "Typ" end
        if rest == "1" then return true end
        if rest == "0" then return false end
        return nil, "kein Bool"
    end
    if regel.typ == "n" or (regel.typ == "sn" and marke == "n") then
        if marke ~= "n" then return nil, "Typ" end
        local z = tonumber(rest)
        if not z then return nil, "keine Zahl" end
        if regel.min and z < regel.min then return nil, "unter Grenze" end
        if regel.max and z > regel.max then return nil, "ueber Grenze" end
        return z
    end
    if regel.typ == "s" or regel.typ == "sn" then
        if marke ~= "s" then return nil, "Typ" end
        if regel.werte and not regel.werte[rest] then return nil, "unbekannter Wert" end
        if not regel.werte and #rest > 40 then return nil, "zu lang" end
        return rest
    end
    return nil, "Regel"
end

-- ---------------------------------------------------------------- Export
-- Rueckgabe: Zeichenkette, Zahl der Schluessel.
function W.export()
    local namen = {}
    for k in pairs(W.PROFIL) do namen[#namen + 1] = k end
    table.sort(namen)                       -- feste Reihenfolge: zweimal exportiert = gleich
    local teile = { tostring(W.VERSION), tostring(ns.VERSION or "?") }
    local n = 0
    for _, k in ipairs(namen) do
        local v = ns.Get(k)
        if v ~= nil then
            local s = schreibWert(W.PROFIL[k], v)
            if s then
                -- Weder Schluessel noch Wert duerfen ein Trennzeichen tragen. Die Positivliste
                -- laesst nur Werte aus festen Mengen und Zahlen zu, hier kann also nichts
                -- durchrutschen - die Wache steht trotzdem, weil sie nichts kostet.
                if not (k:find("|", 1, true) or s:find("|", 1, true)) then
                    teile[#teile + 1] = k .. "=" .. s
                    n = n + 1
                end
            end
        end
    end
    local roh = table.concat(teile, "|")
    roh = roh .. "|#" .. W.pruefsumme(roh)
    return W.MARKE .. W.kodiere(roh), n
end

-- ---------------------------------------------------------------- Import
-- Rueckgabe: true, Zahl uebernommener Schluessel, Liste der abgelehnten
--        oder false, Grund
function W.pruefe(text)
    text = tostring(text or ""):gsub("%s+", "")
    if text == "" then return false, de() and "leer" or "empty" end
    if #text > W.MAX_IMPORT then return false, de() and "zu lang" or "too long" end
    if text:sub(1, #W.MARKE) ~= W.MARKE then
        return false, de() and "kein Lyra-Profil (Praefix fehlt)" or "not a Lyra profile (prefix missing)"
    end
    local roh = W.dekodiere(text:sub(#W.MARKE + 1))
    if not roh then return false, de() and "unlesbar" or "undecodable" end
    local kopf, summe = roh:match("^(.*)|#(%x+)$")
    if not kopf then return false, de() and "Pruefsumme fehlt" or "checksum missing" end
    if W.pruefsumme(kopf) ~= summe then
        return false, de() and "Pruefsumme stimmt nicht" or "checksum mismatch"
    end
    local felder = {}
    for teil in (kopf .. "|"):gmatch("([^|]*)|") do felder[#felder + 1] = teil end
    if tonumber(felder[1]) ~= W.VERSION then
        return false, (de() and "Schema %s, erwartet %d" or "schema %s, expected %d"):format(
            tostring(felder[1]), W.VERSION)
    end
    local werte, abgelehnt = {}, {}
    for i = 3, #felder do
        local k, v = felder[i]:match("^([%w_]+)=(.+)$")
        local regel = k and W.PROFIL[k] or nil
        if not k then
            abgelehnt[#abgelehnt + 1] = { key = tostring(felder[i]):sub(1, 20), grund = "Form" }
        elseif not regel then
            abgelehnt[#abgelehnt + 1] = { key = k, grund = de() and "nicht in der Liste" or "not listed" }
        else
            local wert, grund = lesWert(regel, v)
            if wert == nil then
                abgelehnt[#abgelehnt + 1] = { key = k, grund = grund or "?" }
            else
                werte[k] = wert
            end
        end
    end
    local n = 0
    for _ in pairs(werte) do n = n + 1 end
    if n == 0 then return false, de() and "nichts Gueltiges darin" or "nothing valid inside" end
    return true, werte, abgelehnt, tostring(felder[2])
end

function W.importieren(text)
    local ok, a, b, quelle = W.pruefe(text)
    if not ok then return false, a end
    local werte, abgelehnt = a, b
    local setze = (ns.Settings and ns.Settings.setze) or ns.Set
    local n = 0
    for k, v in pairs(werte) do
        local got = pcall(setze, k, v)
        if got then n = n + 1 end
    end
    -- Preset auf "eigen" ziehen waere falsch: das Profil bringt sein eigenes Preset mit, und
    -- UI/Settings.lua hat die Nebenwirkungen beim Setzen schon angewandt.
    if ns.Settings and ns.Settings.nachImport then pcall(ns.Settings.nachImport) end
    return true, n, abgelehnt, quelle
end

-- ---------------------------------------------------------------- Kopierfenster
-- Ein Frame, eine EditBox, Strg+C. Kein Backdrop-Template, kein Fremd-Frame, kein Name im _G
-- ausser dem einen, der in UISpecialFrames stehen muss (nur benannte Frames schliessen mit Esc).
local fenster
local function fensterBauen()
    if fenster then return fenster end
    if type(CreateFrame) ~= "function" then return nil end
    local ok, f = pcall(CreateFrame, "Frame", "LyraGestaltProfilFenster", UIParent)
    if not ok or type(f) ~= "table" then return nil end
    pcall(function()
        f:SetSize(460, 170)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.85)
        local titel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titel:SetPoint("TOP", 0, -10)
        f.titel = titel
        local hinweis = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        hinweis:SetPoint("BOTTOM", 0, 12)
        f.hinweis = hinweis
        local box = CreateFrame("EditBox", nil, f)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFontObject("GameFontHighlight")
        box:SetPoint("TOPLEFT", 16, -34)
        box:SetPoint("BOTTOMRIGHT", -16, 34)
        box:SetScript("OnEscapePressed", function() f:Hide() end)
        f.box = box
    end)
    if _G.UISpecialFrames then
        table.insert(_G.UISpecialFrames, "LyraGestaltProfilFenster")
    end
    f:Hide()
    fenster = f
    return f
end
W.fensterBauen = fensterBauen

function W.zeige(titel, text, hinweis)
    local f = fensterBauen()
    if not f then return false end
    pcall(function()
        if f.titel then f.titel:SetText(tostring(titel or "")) end
        if f.hinweis then f.hinweis:SetText(tostring(hinweis or "")) end
        if f.box then
            f.box:SetText(tostring(text or ""))
            f.box:HighlightText()
            f.box:SetFocus()
        end
        f:Show()
    end)
    return true
end

-- ---------------------------------------------------------------- /lyra profil export|import
function W.profilBefehl(rest, roh)
    local d = de()
    rest = tostring(rest or ""):gsub("^%s+", "")
    local wort = rest:match("^(%S+)") or ""
    wort = wort:lower()
    if wort == "export" or wort == "exportieren" then
        local text, n = W.export()
        ns.print((d and "Profil exportiert: %d Einstellungen, %d Zeichen. Strg+C im Fenster."
                    or "Profile exported: %d settings, %d characters. Ctrl+C in the window."):format(n, #text))
        if not W.zeige(d and "Lyra - Profil exportieren" or "Lyra - export profile", text,
                d and "Strg+C kopiert, Esc schliesst." or "Ctrl+C copies, Esc closes.") then
            ns.print(text)      -- ohne Fenster (sehr alter Client): wenigstens in den Chat
        end
        return true
    end
    if wort == "import" or wort == "importieren" then
        local kette = tostring(roh or rest):gsub("^%s*%S+%s*", "")
        if kette == "" then
            ns.print(d and "So geht es: /lyra profil import <Zeichenkette>"
                        or "Usage: /lyra profil import <string>")
            return false
        end
        local ok, a, abgelehnt, quelle = W.importieren(kette)
        if not ok then
            ns.print((d and "Profil NICHT uebernommen: %s." or "Profile NOT applied: %s."):format(tostring(a)))
            return false
        end
        ns.print((d and "Profil uebernommen: %d Einstellungen (aus Version %s)."
                     or "Profile applied: %d settings (from version %s)."):format(a, tostring(quelle)))
        if abgelehnt and #abgelehnt > 0 then
            ns.print((d and "  %d Eintrag/Eintraege abgelehnt:" or "  %d entry/entries rejected:"):format(#abgelehnt))
            for i = 1, math.min(8, #abgelehnt) do
                ns.print(("    %s - %s"):format(tostring(abgelehnt[i].key), tostring(abgelehnt[i].grund)))
            end
        end
        return true
    end
    return false      -- kein Export/Import: der Aufrufer macht sein altes Ding weiter
end

-- =============================================================================================
-- 3  Questie ueber die offizielle API (P2-1)
-- =============================================================================================
-- BELEG (installiertes Questie, 20.09.2026):
--   Public/README.md:3        "Everything that is exposed via Questie.API should be considered
--                              stable and safe to use."
--   Public/RegisterOnReady.lua:10          Questie.API.RegisterOnReady(callback)
--   Public/RegisterForQuestUpdates.lua:10  Questie.API.RegisterForQuestUpdates(cb)
--                                          cb(questId, objectiveIndex, triggerReason)
--   Public/Enums.lua:6-11     QuestUpdateTriggerReason = { QUEST_ACCEPTED = 1, QUEST_UPDATED = 2,
--                                          QUEST_TURNED_IN = 3, QUEST_ABANDONED = 4 }
--   Modules/QuestieInit.lua:354            Questie.API.isReady = true, dann PropagateOnReady()
--   Modules/EventHandler/QuestEventHandler.lua:255/312  ruft PropagateQuestUpdate mit
--                                          QUEST_ACCEPTED bzw. QUEST_TURNED_IN
--
-- WAS DAS BRINGT. Zwei Dinge, und beide zaehlen erst am Patch-Tag:
--   1. Die ID kommt von Questie selbst. Sinne/Questie2.lua musste sie bisher aus den beiden
--      Argumenten von QUEST_ACCEPTED ERRATEN (questIdAus prueft beide gegen die Datenbank) -
--      weil die Signatur je Client anders ist. Ueber die API steht sie einfach da.
--   2. Der Zeitpunkt stimmt. Questie feuert erst, wenn seine Datenbank steht. Der eigene
--      QUEST_ACCEPTED-Handler kann sechs Sekunden vor Questie dran sein; heute rettet ihn der
--      Nachhol-Versuch in meldeSpaeter.
-- Was es NICHT bringt: Questdaten. Questie.API hat keine Datenbank-Funktion - Zielzone,
-- Queststufe und Kette kommen weiter aus QuestieDB ueber QuestieLoader. Das ist der Rest, der
-- intern bleiben MUSS, und Sinne/Questie2.lua pcallt ihn seit Welle 3 vollstaendig.
W.questie = { api = false, bereit = false, angemeldet = false, rufe = 0, grund = "nicht versucht" }

function W.questieApi()
    local Q = _G.Questie
    if type(Q) ~= "table" then return nil, "kein Questie" end
    local api = Q.API
    if type(api) ~= "table" then return nil, "kein Questie.API" end
    if type(api.RegisterOnReady) ~= "function" then return nil, "kein RegisterOnReady" end
    return api
end

-- Die Uebersetzung: Questies Grund -> Lyras vorhandener Weg. Sinne/Questie2.lua behaelt seine
-- beiden Funktionen, sie werden hier nur mit einer SICHEREN ID gerufen.
local function questUpdate(questId, _, grund)
    local Q2 = ns.Questie2
    if not Q2 then return end
    local id = tonumber(questId)
    if not id or id <= 0 then return end
    local api = W.questieApi()
    local E = api and api.Enums and api.Enums.QuestUpdateTriggerReason
    local angenommen = E and E.QUEST_ACCEPTED or 1
    local abgegeben  = E and E.QUEST_TURNED_IN or 3
    W.questie.rufe = W.questie.rufe + 1
    if grund == angenommen and type(Q2.angenommen) == "function" then
        pcall(Q2.angenommen, id, nil)
    elseif grund == abgegeben and type(Q2.abgegeben) == "function" then
        pcall(Q2.abgegeben, id, nil)
    end
end

function W.questieAnmelden()
    local api, grund = W.questieApi()
    if not api then W.questie.grund = grund; return false end
    W.questie.api = true
    local ok = pcall(api.RegisterOnReady, function()
        W.questie.bereit = true
        if type(api.RegisterForQuestUpdates) == "function" then
            local ok2 = pcall(api.RegisterForQuestUpdates, questUpdate)
            if ok2 then
                W.questie.angemeldet = true
                W.questie.grund = "API"
                -- Erst JETZT den internen Weg stilllegen. Nicht frueher: waere
                -- RegisterForQuestUpdates durchgefallen, haette Lyra gar keine Quelle mehr.
                if ns.Questie2 then ns.Questie2.apiWeg = true end
                return
            end
        end
        W.questie.grund = "bereit, aber kein RegisterForQuestUpdates"
    end)
    if not ok then W.questie.grund = "RegisterOnReady wirft"; return false end
    if W.questie.grund == "nicht versucht" then W.questie.grund = "angemeldet, wartet" end
    return true
end

-- =============================================================================================
-- Selbsttest, Ereignisse, Status
-- =============================================================================================
-- Eigener kleiner Login-Selbsttest statt einer neunten Flaeche in Core/Selbsttest.lua. Grund:
-- ST.FLAECHEN ist eine geschlossene Liste mit acht Eintraegen, an der /lyra selbsttest, die
-- Chat-Zeile bei Ausfaellen und der Pruefstand haengen - eine Welle, die dort etwas anhaengt,
-- aendert eine Zusage, nicht nur eine Zahl. Was hier geprueft wird, kostet ausserdem keinen
-- SINN, wenn es ausfaellt: ohne LDB fehlt eine Anzeige, ohne Questie.API laeuft der alte Weg.
-- Das Ergebnis steht in /lyra status; STILL bei Fehlschlag, wie der Kontrakt es verlangt.
W.selbst = { ldb = nil, profil = nil, questie = nil }

function W.selbsttest()
    -- 1 LDB
    W.selbst.ldb = (W.ldbObjekt ~= nil)
    -- 2 Profil: ein Roundtrip mit den EIGENEN Einstellungen. Er schreibt nichts - pruefe()
    --   liest nur und gibt die Werte zurueck.
    local ok, text = pcall(W.export)
    if ok and type(text) == "string" then
        local gut, werte = W.pruefe(text)
        W.selbst.profil = (gut and type(werte) == "table") and true or false
    else
        W.selbst.profil = false
    end
    -- 3 Questie: nur, ob der Weg steht. "Kein Questie installiert" ist kein Fehlschlag.
    W.selbst.questie = W.questie.api and W.questie.angemeldet or nil
    return W.selbst
end

ns.on("PLAYER_LOGIN", function()
    ns.Compat.After(0, function()
        pcall(W.ldbAnlegen)
        pcall(W.ldbNachziehen)
        pcall(W.questieAnmelden)
        pcall(W.selbsttest)
    end)
end)

-- Der LDB-Text muss sich aendern, wenn sich der Zustand aendert. Derselbe Mantel wie in
-- Sinne/Welle6.lua und UI/Streamer.lua: Original merken, Original ZUERST rufen, danach das
-- Eigene - und alles in pcall, damit ein Fehler hier nie die Kette darunter kostet.
--
-- WO ER IN DER KETTE LIEGT: Sinne/Welle6.lua und UI/Streamer.lua wickeln sich bei PLAYER_LOGIN
-- ein, dieser hier beim LADEN. Er liegt also INNEN, direkt ueber dem Original aus
-- Gestalt/Gestalt.lua, und die beiden anderen legen sich spaeter darum. Das ist kein Mangel,
-- sondern egal: er ruft das Original zuerst und gibt nichts zurueck, was jemand auswerten
-- koennte. Wichtig ist nur die Richtung - erst der Rest der Kette, dann der Leisten-Text.
do
    local orig = ns.onSetting
    local wichtig = { preset = 1, gespraechig = 1, stimme = 1, barrierefrei = 1, versteckt = 1, tts = 1 }
    ns.onSetting = function(key, value, ...)
        if orig then pcall(orig, key, value, ...) end
        if W.ldbObjekt and wichtig[key] then pcall(W.ldbNachziehen) end
    end
end

function W.status()
    local d = de()
    local out = {}
    out[#out + 1] = (d and "Leiste (LibDataBroker): %s" or "Broker (LibDataBroker): %s"):format(
        W.ldbObjekt and ((d and "angemeldet als \"%s\", Text \"%s\"" or "registered as \"%s\", text \"%s\"")
            :format(W.LDB_NAME, W.ldbText()))
        or ((d and "nicht angemeldet (%s)" or "not registered (%s)"):format(tostring(W.ldbGrund))))
    local ok, text, n = pcall(function() local t, k = W.export(); return t, k end)
    if ok and type(text) == "string" then
        out[#out + 1] = (d and "  Profil-Export: %d Einstellungen, %d Zeichen (/lyra profil export)"
                            or "  Profile export: %d settings, %d characters (/lyra profil export)")
            :format(tonumber(n) or 0, #text)
    end
    out[#out + 1] = (d and "  Questie-Anbindung: %s" or "  Questie hook: %s"):format(
        W.questie.angemeldet and ((d and "offizielle Questie.API (%d Meldungen)" or "official Questie.API (%d updates)")
            :format(W.questie.rufe))
        or ((d and "eigener Ereignis-Weg (%s)" or "own event path (%s)"):format(tostring(W.questie.grund))))
    if ns.Aussprache and ns.Aussprache.status then
        local ok2, zeilen = pcall(ns.Aussprache.status)
        if ok2 and type(zeilen) == "table" then
            for _, z in ipairs(zeilen) do out[#out + 1] = "  " .. z end
        end
    end
    return out
end
