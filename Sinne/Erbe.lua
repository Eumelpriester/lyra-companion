-- Sinne/Erbe.lua — Vorgaenger-Erbe (account-weit) und Sitzungs-Debrief. Doku: Sinne/EXTRA.md.
-- Ereignisse: ERBE_TOD (still), ERBE_VORGAENGER, ERBE_WORTE, DEBRIEF,
--   W11A: ERBE_NACHRUF, ERBE_NACHRUF_WORTE (der Nachruf NACH dem 60-s-Riegel).
-- W11C: E.sterbeorte() gibt die Sterbeorte eigener Vorgaenger heraus (gefiltert, juengster
--   zuerst). Gemeldet wird ERBE_STERBEORT NICHT hier, sondern in Sinne/Karte2.lua - dort liegt
--   die Abstandsrechnung in Yard und der Vorrang gegen Beinahe-Punkt und Deathlog-Zelle.
-- Daten: LyraGestaltDB.erbe = Liste (max 20) eigener gefallener Charaktere dieses Accounts:
--   { name, realm, level, zone, mapID, x, y, gegner, npcID, t, klasse, worte, vorgestellt, quelle }.
--
-- ---------------------------------------------------------------------------------------------
-- W11A (20.09.2026) — DER TOD BEKOMMT EINE STIMME
-- ---------------------------------------------------------------------------------------------
-- Befund docs/review-bindung-2026-09-20.md §2.5: der emotionalste Moment, den dieses Spiel kennt,
-- wurde von einer Begleiterin begleitet, die dabei drei fest verdrahtete Saetze kennt und dann
-- eine Minute schweigt. GEFALLEN und ERBE_TOD haben null Zeilen.
--
-- DIE MINUTE SCHWEIGEN BLEIBT. Core/Regie.lua setzt bei PLAYER_DEAD R.todRiegelBis = jetzt() + 60
-- und laesst nur noch klasse "still" durch. Das ist richtig und wird hier nicht angefasst:
-- direkt nach dem Tod hat niemand Lust auf einen Kommentar. GEFALLEN und ERBE_TOD bleiben darum
-- "still" und bleiben ohne Zeilen (Begruendung ausfuehrlich in docs/phrasen-w11a.json).
--
-- GESPROCHEN WIRD DANACH. NACHRUF_AB Sekunden nach dem Tod - also sicher hinter dem Riegel -
-- meldet dieses Modul ERBE_NACHRUF mit den Fakten, die im Erbe-Eintrag und in der Chronik ohnehin
-- schon stehen: Name, Stufe, Zone, Toeter, gespielte Stunden, Beinahe-Tode, aergster Rivale.
-- Nichts davon wird neu erhoben und nichts davon wird gedeutet - es ist die Zahl, nicht ihr Grund.
-- Gibt es LETZTE WORTE, und zwar nur, wenn der Spieler sie SELBST eingegeben hat, folgt
-- NACHRUF_WORTE_AB Sekunden spaeter ERBE_NACHRUF_WORTE. Lyra erfindet nie letzte Worte.
--
-- Warum die zwei Ereignisse trotz klasse "plauder" durchkommen, wo der Spieler gerade als Geist
-- dasteht: gruppeOk = true in phrasen.json haengt sie am Gruppen-Schweigen vorbei (dieselbe
-- Loesung, die AGGRO und BOSS_PULL benutzen), im Kampf ist ein Geist nicht, und der Plauder-
-- Abstand ist nach einer Minute Totenstille ohnehin abgelaufen. Der Still-Modus (/lyra still)
-- gilt weiter, und das ist Absicht: wer Ruhe bestellt hat, bekommt auch hier Ruhe.
-- Es braucht dafuer KEINE Aenderung an Core/Regie.lua.
-- HARTE REGEL: Quelle ist NUR der eigene Charakter (UnitName("player")) bei PLAYER_DEAD. Nie Deathlog,
--   nie Daten anderer Spieler, nie ein Spielername als "gegner" (UnitIsPlayer-Sperre, Chronik-Bestiarium
--   enthaelt nur Creature-GUIDs).
-- API (nur lesend): UnitName/GetRealmName/UnitLevel/UnitClass/UnitGUID/UnitExists/UnitIsPlayer/
--   UnitPlayerControlled/UnitCanAttack, GetRealZoneText, C_Map.GetBestMapForUnit/GetPlayerMapPosition,
--   UnitIsDeadOrGhost, UnitAffectingCombat, GetTime, time, date. Nichts Fremdes.
-- Events: PLAYER_DEAD, PLAYER_ALIVE, PLAYER_UNGHOST, PLAYER_LOGIN, PLAYER_ENTERING_WORLD.
-- Hook: ns.Dialog.frage wird bei PLAYER_LOGIN gewrappt (Dialog.lua bleibt unangetastet): solange
--   ns.erbeWarteAufWorte gesetzt ist, nimmt /lyra <text> die letzten Worte (max 120 Zeichen).
local ADDON, ns = ...
local E = {}
ns.Erbe = E

local MAX_ERBE = 20
local WORTE_MAX = 120
local WORTE_FRIST = 60             -- s: so lange nimmt /lyra <text> die letzten Worte
local WORTE_BLASE = 15             -- s Standzeit der Frage
local VORGAENGER_LEVEL_MAX = 5
-- REVIEW4: feste Sekundenzahlen sind nur noch WUENSCHE ("nicht vor ..."); den echten Zeitpunkt
-- vergibt ns.Regie.loginSlot, damit sich die Login-Zeilen aus Chronik, Erbe und Start nicht
-- gegenseitig aus dem Plauder-Abstand draengen (siehe Kommentar in Core/Regie.lua).
local VORGAENGER_AB, WORTE_AB, DEBRIEF_AB = 20, 4, 60
local function loginSlot(ab)
    if ns.Regie and ns.Regie.loginSlot then return ns.Regie.loginSlot(ab) end
    return ab
end
local NACHHOL = 35
-- W11A: der Nachruf. 65 > 60 (Core/Regie.lua todRiegelBis) mit fuenf Sekunden Luft, damit er
-- nicht auf der Kante liegt; die zweite Zeile noch einmal so weit dahinter, wie der Plauder-
-- Abstand bei Preset "normal" breit ist.
local NACHRUF_AB = 65
local NACHRUF_WORTE_AB = 34
local GEGNER_FRIST = 30            -- s: Bestiarium-Tod / Beinahe zaehlt als Toeter nur so lange
local SITZUNG_FRISCH = 120         -- s: aelterer Sitzungsstart beim Login = fortgesetzte Sitzung (/reload)

local function jetzt() return GetTime() end
local function unix() return time() end
local function tot() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false end
local function imKampf() return UnitAffectingCombat and UnitAffectingCombat("player") or false end
local function echterTimer() return C_Timer and C_Timer.After and true or false end
local function rund3(v) return math.floor(v * 1000 + 0.5) / 1000 end

local function zoneJetzt()
    return (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
end

local function position()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local ok, karte = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not karte then return nil end
    local ok2, pos = pcall(C_Map.GetPlayerMapPosition, karte, "player")
    if not ok2 or not pos then return nil end
    local x, y
    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    if not x or not y then return nil end
    return karte, x, y
end

local function npcIdAus(guid)
    if type(guid) ~= "string" then return nil end
    return guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
end

-- Feindlicher NPC als Einheit? Grenze B: UnitIsPlayer als Erstes.
local function feindNpc(unit)
    if not (UnitExists and UnitExists(unit)) then return nil end
    if UnitIsPlayer and UnitIsPlayer(unit) then return nil end
    if UnitPlayerControlled and UnitPlayerControlled(unit) then return nil end
    if not (UnitCanAttack and UnitCanAttack("player", unit)) then return nil end
    local id = npcIdAus(UnitGUID and UnitGUID(unit))
    if not id then return nil end
    local name = UnitName and UnitName(unit)
    if not name or name == "" then return nil end
    return id, name
end

local function chronikDB()
    local c = LyraGestaltDB and LyraGestaltDB.chronik and ns.charKey and LyraGestaltDB.chronik[ns.charKey]
    return type(c) == "table" and c or nil
end

local function erbeListe()
    if not LyraGestaltDB then return nil end
    if type(LyraGestaltDB.erbe) ~= "table" then LyraGestaltDB.erbe = {} end
    return LyraGestaltDB.erbe
end
E.liste = erbeListe

local function erbeAktiv()
    if ns.Compat and ns.Compat.istHardcore and ns.Compat.istHardcore() then return true end
    return ns.Get("erbeImmer") and true or false
end

-- Melden mit EINEM Nachhol (Muster aus Chronik.lua): der Regie-Abstand frisst sonst Zeilen kurz nach LOGIN.
local function meldeNachhol(id, vars, verzug, gilt, danach)
    ns.Compat.After(verzug, function()
        if gilt and not gilt() then return end
        if ns.melde(id, vars) then if danach then danach() end return end
        if not echterTimer() then return end
        -- Nur nachlegen, wenn der Abstand der Grund war (Drossel/Gruppe/Still-Modus sind endgueltig).
        local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
        if not (d and d[2] == id and d[1] == "abstand") then return end
        local rest = (ns.Regie and ns.Regie.abstandRest and ns.Regie.abstandRest()) or 0
        ns.Compat.After(math.max(NACHHOL, math.min(rest + 1, 180)), function()
            if gilt and not gilt() then return end
            if ns.melde(id, vars) and danach then danach() end
        end)
    end)
end

-- ---------------------------------------------------------------- Tod: Eintrag + Frage nach letzten Worten
-- Toeter: 1) aktuelles Ziel (NPC), 2) Bestiarium-Eintrag mit frischem Tod (Chronik zaehlt tode++ vor uns),
-- 3) juengster Beinahe-Eintrag der Chronik. Nie ein Spieler.
local function gegnerErmitteln()
    local id, name = feindNpc("target")
    if id then return name, id end
    local c = chronikDB()
    if not c then return nil end
    local t = unix()
    local bestId, bestE = nil, nil
    for nid, e in pairs(c.bestiarium or {}) do
        if type(e) == "table" and (e.tode or 0) >= 1 and (e.t or 0) >= t - GEGNER_FRIST then
            if not bestE or (e.t or 0) > (bestE.t or 0) then bestId, bestE = nid, e end
        end
    end
    if bestE and bestE.name then return bestE.name, bestId end
    local b = c.beinahe and c.beinahe[#c.beinahe]
    if type(b) == "table" and b.gegner and (b.t or 0) >= t - 120 then return b.gegner, b.npcID end
    return nil
end

local todGemerkt = false
local worteBis = 0
local letzterEintrag = nil

-- W11A: die Frage nach den letzten Worten hatte genau EINEN Wortlaut (Locales/deDE.lua:102),
-- und das an der Stelle, an der ein Spieler in seinem ganzen Hardcore-Leben vielleicht fuenfmal
-- hinhoert. Jetzt sind es vier, die Bestaetigung hat drei.
-- Sie bleiben ausdruecklich in den LOCALES und nicht im Katalog: der Quelltext von Core/Regie.lua
-- sagt selbst, dass diese zwei Saetze absichtlich NICHT ueber die Regie laufen, weil der
-- Tod-Riegel sie sonst verschlucken wuerde. Ein Katalogtext waere genau dieser Weg.
local FRAGE_SCHLUESSEL = { "Last words prompt", "Last words prompt 2",
                           "Last words prompt 3", "Last words prompt 4" }
local DANK_SCHLUESSEL  = { "Last words saved", "Last words saved 2", "Last words saved 3" }

-- Nimmt den Schluessel, wenn die Locale ihn kennt; sonst den ersten. Eine Sprache, die nur die
-- alten Schluessel hat (eine Fremduebersetzung), faellt damit sauber auf den alten Satz zurueck.
local function locVariante(liste)
    local frei = {}
    for _, k in ipairs(liste) do
        local s = ns.L[k]
        if type(s) == "string" and s ~= "" and s ~= k then frei[#frei + 1] = s end
    end
    if #frei == 0 then return ns.L[liste[1]] end
    return frei[math.random(#frei)]
end

local function worteFrage()
    ns.erbeWarteAufWorte = true
    worteBis = jetzt() + WORTE_FRIST
    local satz = locVariante(FRAGE_SCHLUESSEL)
    if ns.Blase and ns.Blase.zeige and not ns.Get("versteckt") then
        ns.Blase.zeige(satz, WORTE_BLASE, "plauder")
    end
    ns.print(satz)
    ns.Compat.After(WORTE_FRIST, function()
        if jetzt() >= worteBis then ns.erbeWarteAufWorte = nil end
    end)
end

-- ---------------------------------------------------------------- W11A: der Nachruf
-- Alle Zutaten liegen seit 0.9 da und wurden nie benutzt (review-bindung §2.5, letzter Absatz).
-- Gerechnet wird ausschliesslich aus dem Erbe-Eintrag und aus der Chronik DIESES Charakters.
-- Kein Platzhalter wird geraten: was nicht da ist, steht nicht in vars, und Core/Regie.lua
-- waehle() wirft die Zeilen, die ihn brauchen, dann von selbst aus der Auswahl.
local function stundenGespielt()
    local c = chronikDB()
    if not (c and type(c.sitzungen) == "table") then return nil end
    local sek = 0
    for _, s in ipairs(c.sitzungen) do
        local a, b = tonumber(s.start) or 0, tonumber(s.ende) or 0
        if b > a then sek = sek + (b - a) end
    end
    if sek < 600 then return nil end            -- unter zehn Minuten ist "0,1 Stunden" keine Aussage
    return string.format("%.1f", sek / 3600)
end

local function beinaheZahl()
    local c = chronikDB()
    if not (c and type(c.beinahe) == "table") then return nil end
    local n = #c.beinahe
    if n <= 0 then return nil end               -- "0 Mal knapp" waere eine Floskel, keine Zahl
    return n
end

-- Der aergste Gegner: Rang wie im Bestiarium (erst beinahe + tode, dann Schaden). Es ist ein
-- NPC-Name - das Bestiarium enthaelt ausschliesslich Creature-GUIDs (Sinne/Chronik.lua).
local function aergsterGegner()
    local c = chronikDB()
    if not (c and type(c.bestiarium) == "table") then return nil end
    local best, rangBest = nil, 0
    for _, e in pairs(c.bestiarium) do
        if type(e) == "table" and e.name and e.name ~= "" then
            local rang = (tonumber(e.beinahe) or 0) + (tonumber(e.tode) or 0)
            if rang > rangBest then best, rangBest = e.name, rang end
        end
    end
    if rangBest < 1 then return nil end
    return best
end

local function nachrufPlanen(e)
    if not (e and e.name) then return end
    local vars = { name = e.name, level = tonumber(e.level) or 0,
                   zone = (e.zone and e.zone ~= "") and e.zone or nil }
    if e.gegner and e.gegner ~= "" then vars.gegner = e.gegner end
    local std = stundenGespielt();      if std then vars.stunden = std end
    local bn  = beinaheZahl();          if bn  then vars.beinahe = bn end
    local ag  = aergsterGegner();       if ag  then vars.aergster = ag end
    -- gilt(): der Eintrag muss noch der letzte sein. Wer in der Minute dazwischen /reload macht
    -- oder ein zweites Mal stirbt (Geist-Tod auf manchen Servern), bekommt keinen doppelten.
    local gilt = function() return letzterEintrag == e end
    meldeNachhol("ERBE_NACHRUF", vars, NACHRUF_AB, gilt, function()
        -- Letzte Worte nur, wenn der SPIELER sie selbst eingegeben hat. Es gibt keinen Weg,
        -- auf dem hier etwas anderes stehen koennte: E.worte() ist die einzige Schreibstelle.
        if not (e.worte and e.worte ~= "") then return end
        meldeNachhol("ERBE_NACHRUF_WORTE", { name = e.name, worte = e.worte },
            NACHRUF_WORTE_AB, gilt)
    end)
end

local function todEintragen()
    local liste = erbeListe()
    if not liste then return end
    local name = UnitName and UnitName("player") or nil      -- EIGENER Charakter
    if not name or name == "" then return end
    local _, klasse = nil, nil
    if UnitClass then _, klasse = UnitClass("player") end
    local e = {
        name = name,
        realm = (GetRealmName and GetRealmName()) or "?",
        level = (UnitLevel and UnitLevel("player")) or 0,
        zone = zoneJetzt(),
        t = unix(),
        klasse = klasse,
        vorgestellt = false,
        -- W11A: Herkunftsmarke. Die Liste kennt seit 0.9 nur EINE Quelle - UnitName("player")
        -- bei PLAYER_DEAD - und das soll so bleiben ("Erbe aus Deathlog-Daten: nie",
        -- Sinne/EXTRA.md:107). Seit die Halle der Gefallenen die Liste ANZEIGT, ist das keine
        -- Doku-Zusage mehr, sondern eine Anzeigefrage: was hier auf dem Bildschirm steht, geht
        -- unter Umstaenden als Screenshot ins Netz. Die Halle zeigt darum nur Eintraege mit
        -- quelle == "selbst" (und, fuer Eintraege von vor Welle 11a, ohne quelle).
        quelle = "selbst",
    }
    local karte, x, y = position()
    if karte and x and y then e.mapID, e.x, e.y = karte, rund3(x), rund3(y) end
    local gegner, npcID = gegnerErmitteln()
    if gegner then e.gegner = gegner; e.npcID = npcID end
    liste[#liste + 1] = e
    while #liste > MAX_ERBE do table.remove(liste, 1) end
    letzterEintrag = e
    ns.melde("ERBE_TOD")
    worteFrage()
    nachrufPlanen(e)
end

ns.on("PLAYER_DEAD", function()
    if todGemerkt then return end
    todGemerkt = true
    if not erbeAktiv() then return end
    -- Chronik (PLAYER_DEAD davor registriert) hat tode++ gesetzt; kurz warten, damit auch spaete Handler durch sind.
    ns.Compat.After(0.5, function() pcall(todEintragen) end)
end)
ns.on("PLAYER_ALIVE", function() if not tot() then todGemerkt = false end end)
ns.on("PLAYER_UNGHOST", function() todGemerkt = false end)

-- Letzte Worte speichern (max 120 Zeichen). Rueckgabe true, wenn angenommen.
function E.worte(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return false end
    local e = letzterEintrag
    if not e then
        local liste = erbeListe()
        e = liste and liste[#liste]
    end
    if not e then return false end
    if #text > WORTE_MAX then
        local n = WORTE_MAX
        -- UTF-8: nicht mitten in einer Mehrbyte-Folge schneiden (Folgebytes sind 0x80-0xBF)
        while n > 1 and text:byte(n + 1) and text:byte(n + 1) >= 128 and text:byte(n + 1) < 192 do n = n - 1 end
        text = text:sub(1, n)
    end
    e.worte = text
    ns.erbeWarteAufWorte = nil
    worteBis = 0
    local dank = locVariante(DANK_SCHLUESSEL)
    if ns.Blase and ns.Blase.zeige and not ns.Get("versteckt") then
        ns.Blase.zeige(dank, 8, "plauder")
    end
    ns.print(dank)
    if ns.Gestalt and ns.Gestalt.miene then ns.Gestalt.miene("touched", 10) end
    return true
end

-- Wrapper um ns.Dialog.frage (Dialog.lua bleibt unveraendert): waehrend der Frist nimmt /lyra <text> die Worte.
local gewrappt = false
local function dialogWrappen()
    if gewrappt or not (ns.Dialog and type(ns.Dialog.frage) == "function") then return end
    gewrappt = true
    local original = ns.Dialog.frage
    ns.Dialog.frage = function(roh, ...)
        if ns.erbeWarteAufWorte and jetzt() < worteBis then
            local text = tostring(roh or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if text ~= "" then return E.worte(text) end
        end
        return original(roh, ...)
    end
end

-- ---------------------------------------------------------------- Login: Vorgaenger vorstellen, Debrief
-- Juengster Erbe-Eintrag eines ANDEREN Charakters, der noch nicht vorgestellt wurde.
local function vorgaengerFinden()
    local liste = erbeListe()
    if not liste then return nil end
    -- REVIEW3: Name-Realm statt nur Name (gleicher Name auf anderem Realm ist ein anderer Charakter)
    local eigen = ns.charKey or ((UnitName and UnitName("player") or "") .. "-" .. ((GetRealmName and GetRealmName()) or "?"))
    for i = #liste, 1, -1 do
        local e = liste[i]
        if type(e) == "table" and e.name and (tostring(e.name) .. "-" .. tostring(e.realm or "?")) ~= eigen and not e.vorgestellt then return e end
    end
    return nil
end

local function vorgaengerPlanen()
    local lvl = (UnitLevel and UnitLevel("player")) or 0
    if lvl > VORGAENGER_LEVEL_MAX then return end
    local e = vorgaengerFinden()
    if not e then return end
    local vars = { name = e.name, level = e.level or 0, zone = (e.zone and e.zone ~= "") and e.zone or "?" }
    -- REVIEW4: Beide Slots werden JETZT geholt, nicht erst nach dem Erfolg der ersten Zeile - sonst
    -- draengt sich DEBRIEF (das seinen Slot gleich danach holt) zwischen Vorgaenger und letzte Worte.
    -- Ob es letzte Worte gibt, steht hier schon fest.
    local verzugV = loginSlot(VORGAENGER_AB)
    local hatWorte = e.worte and e.worte ~= ""
    local verzugW = hatWorte and loginSlot(WORTE_AB) or nil
    meldeNachhol("ERBE_VORGAENGER", vars, verzugV, function() return not tot() end, function()
        e.vorgestellt = true
        if hatWorte then
            -- verzugW ist ab dem Slot-Zeitpunkt gerechnet; der Rest ab jetzt ist die Differenz.
            local rest = math.max(1, verzugW - verzugV)
            meldeNachhol("ERBE_WORTE", { name = e.name, worte = e.worte }, rest, function() return not tot() end)
        end
    end)
end

-- Debrief der letzten Sitzung: sitzungen[n] ist die eben von Chronik begonnene, sitzungen[n-1] die letzte.
local function debriefPlanen()
    local c = chronikDB()
    local s = c and c.sitzungen
    if type(s) ~= "table" or #s < 2 then return end
    local aktuell, letzte = s[#s], s[#s - 1]
    if type(aktuell) ~= "table" or type(letzte) ~= "table" then return end
    local t = unix()
    if (aktuell.start or 0) < t - SITZUNG_FRISCH then return end    -- fortgesetzte Sitzung (/reload): kein Debrief
    local start, ende = letzte.start or 0, letzte.ende or letzte.start or 0
    if start <= 0 or ende <= start then return end
    local stunden = (ende - start) / 3600
    -- Level-Start: Ende der vorletzten Sitzung (= Stand beim Start der letzten); sonst der gespeicherte Wert.
    local vorletzte = s[#s - 2]
    local von = (type(vorletzte) == "table" and vorletzte.level) or letzte.level or 0
    local bis = letzte.level or (UnitLevel and UnitLevel("player")) or von
    if von > bis then von = bis end
    local beinahe = 0
    for _, b in ipairs(c.beinahe or {}) do
        if type(b) == "table" and (b.t or 0) >= start and (b.t or 0) <= ende then beinahe = beinahe + 1 end
    end
    local vars = { stunden = string.format("%.1f", stunden), von = von, bis = bis, beinahe = beinahe }
    meldeNachhol("DEBRIEF", vars, loginSlot(DEBRIEF_AB), function() return not tot() and not imKampf() end)
end

local ersterPEW = true
ns.on("PLAYER_LOGIN", function()
    dialogWrappen()
    -- W11A: UI/Dialog.lua steht in der TOC HINTER Sinne/Erbe.lua - beim Laden gibt es
    -- ns.Dialog.chronikZeilen noch nicht. Beim Login gibt es sie. Gleiches Muster wie oben.
    -- Ueber E. und nicht ueber den lokalen Namen: die Halle steht weiter unten in dieser Datei,
    -- der lokale Upvalue waere hier oben noch nil (im Harness reproduziert - der Fehler fiel
    -- still in den pcall des Ereignisrahmens und verschluckte gleich noch erbeListe()).
    if E.halleWrappen then E.halleWrappen() end
    erbeListe()
end)
ns.on("PLAYER_ENTERING_WORLD", function()
    if not ersterPEW then return end
    ersterPEW = false
    pcall(vorgaengerPlanen)
    pcall(debriefPlanen)
end)

-- ---------------------------------------------------------------- Export (/lyra erbe)
function E.status()
    local out = {}
    local liste = erbeListe() or {}
    local L = ns.L
    if #liste == 0 then out[1] = L["Legacy empty"]; return out end
    out[1] = L["Legacy list"]
    for i = #liste, 1, -1 do
        local e = liste[i]
        if type(e) == "table" then
            local zeile = ("  %s (%d) - %s - %s"):format(tostring(e.name or "?"), tonumber(e.level) or 0,
                tostring((e.zone and e.zone ~= "") and e.zone or "?"), date("%d.%m.%Y %H:%M", e.t or 0))
            if e.gegner then zeile = zeile .. " - " .. tostring(e.gegner) end
            out[#out + 1] = zeile
            if e.worte and e.worte ~= "" then out[#out + 1] = "    \"" .. e.worte .. "\"" end
        end
    end
    return out
end

-- ---------------------------------------------------------------- W11A: Halle der Gefallenen
-- docs/abgleich-claudebuddy-2026-09-20.md §3 Nr. 7 und §5 W11-11: "Lyra hat die Daten bereits
-- vollstaendig ... Was fehlt, ist der Ort." Der Ort ist ein weiterer Abschnitt im Chronik-Fenster.
--
-- UI/Dialog.lua WIRD DAFUER NICHT ANGEFASST. Sie gehoert in Welle 11 einem anderen Team, und sie
-- muss auch gar nicht: D.chronikZeilen() gibt eine reine Datenliste { {art, text}, ... } zurueck,
-- die das Fenster generisch zeichnet. Dieses Modul legt - nach demselben Muster, mit dem es seit
-- 0.9 ns.Dialog.frage umwickelt - einen Wrapper darum und haengt seinen Abschnitt ans Ende.
-- Faellt der Wrapper aus (kein UI/Dialog.lua, Fehler beim Wrappen), sieht das Fenster aus wie
-- vorher; die Halle ist ein Zusatz, kein Umbau.
--
-- NUR EIGENE CHARAKTERE. LyraGestaltDB.erbe wird ausschliesslich aus UnitName("player") bei
-- PLAYER_DEAD geschrieben. Die Halle verlaesst sich nicht darauf, sondern prueft zweimal:
--   1. quelle: Eintraege mit einer anderen Herkunft als "selbst" fallen heraus. Eintraege ganz
--      ohne Feld sind von vor Welle 11a und damit ebenfalls eigene.
--   2. ns.Dialog.chronikSicher: streicht Charakter-, Realm- und Gildennamen des AKTUELLEN
--      Charakters aus jeder Zeile, bevor sie gesetzt wird - dieselbe Behandlung wie fuer Zonen
--      und Bestiarium. Ein Screenshot soll nicht sagen, wer ihn gemacht hat.
-- Die letzten Worte stehen darunter, eingerueckt und in Anfuehrungszeichen: sie sind das, was in
-- der Hardcore-Szene am meisten gelobt wird, und sie sind das Einzige an diesem Fenster, das ein
-- Mensch geschrieben hat.
E.HALLE_MAX = 6

function E.halleZeilen()
    local z = {}
    local liste = erbeListe()
    if type(liste) ~= "table" or #liste == 0 then return z end
    local sicher = (ns.Dialog and ns.Dialog.chronikSicher) or function(s) return tostring(s or "") end
    local L = ns.L
    local eigene = {}
    for i = #liste, 1, -1 do
        local e = liste[i]
        if type(e) == "table" and e.name and e.name ~= ""
           and (e.quelle == nil or e.quelle == "selbst") then
            eigene[#eigene + 1] = e
        end
    end
    if #eigene == 0 then return z end
    z[#z + 1] = { art = "kopf", text = sicher(L["Hall of the fallen"] .. " (" .. #eigene .. ")") }
    for i = 1, math.min(E.HALLE_MAX, #eigene) do
        local e = eigene[i]
        local zeile = ("%s (%d)  -  %s  -  %s"):format(
            tostring(e.name), tonumber(e.level) or 0,
            tostring((e.zone and e.zone ~= "") and e.zone or "?"),
            date("%d.%m.%Y", e.t or 0))
        if e.gegner and e.gegner ~= "" then zeile = zeile .. "  -  " .. tostring(e.gegner) end
        z[#z + 1] = { art = "zeile", text = sicher(zeile) }
        if e.worte and e.worte ~= "" then
            z[#z + 1] = { art = "zeile", text = sicher("\"" .. e.worte .. "\"") }
        end
    end
    if #eigene > E.HALLE_MAX then
        local mehr = L["Chronicle more"]
        z[#z + 1] = { art = "zeile", text = sicher(
            (type(mehr) == "string" and mehr:find("%%d")) and mehr:format(#eigene - E.HALLE_MAX)
            or ("+" .. (#eigene - E.HALLE_MAX))) }
    end
    return z
end

local halleGewrappt = false
local function halleWrappen()
    if halleGewrappt or not (ns.Dialog and type(ns.Dialog.chronikZeilen) == "function") then return end
    halleGewrappt = true
    local original = ns.Dialog.chronikZeilen
    ns.Dialog.chronikZeilen = function(...)
        local z = original(...)
        if type(z) ~= "table" then return z end
        local ok, halle = pcall(E.halleZeilen)
        if ok and type(halle) == "table" then
            for _, eintrag in ipairs(halle) do z[#z + 1] = eintrag end
        end
        return z
    end
end
E.halleWrappen = halleWrappen

-- ---------------------------------------------------------------- W11C: die Zeile am Sterbeort
-- docs/abgleich-claudebuddy-2026-09-20.md §3 Nr. 7 (zweite Haelfte) und Planpunkt W11-14:
-- "Sinne/Erbe.lua schreibt mapID, x und y seit 0.9 mit (Zeile 287) - und KEIN EINZIGER KONSUMENT
-- LIEST SIE." Das ist ab hier nicht mehr wahr. Diese Datei LIEST die Sterbeorte nur; wer sie
-- benutzt (Abstand, Vorrang, Pin, Zeile), ist Sinne/Karte2.lua.
--
-- WARUM DIE LISTE KONTOWEIT LIEGT UND DAS SO BLEIBEN MUSS: ClaudeBuddy hat es woertlich
-- aufgeschrieben - "sonst sieht der Nachfolger ihn nie". LyraGestaltDB.erbe haengt seit 0.9 am
-- Konto und nicht am Charakter; genau deshalb kann der NACHFOLGER den Ort des VORGAENGERS
-- ueberhaupt kennen. Was dagegen je Charakter liegt, ist die Liste der schon gesagten Orte
-- (ns.char, Sinne/Karte2.lua) - sonst bekaeme der zweite Nachfolger die Zeile nie zu hoeren.
--
-- DREI FILTER, UND JEDER EINZELNE IST EINE ZUSAGE:
--   1. quelle: nur "selbst" (oder gar kein Feld = vor Welle 11a geschrieben, also ebenfalls
--      eigen). Ein untergeschobener Deathlog-Eintrag kommt hier nicht durch. Dieselbe Pruefung
--      wie in E.halleZeilen, und aus demselben Grund.
--   2. Der GERADE GESPIELTE Charakter faellt heraus (Name-Realm wie in vorgaengerFinden).
--      "Hier bist du gefallen" ist keine Vorgaenger-Zeile, und in Hardcore kommt der Fall
--      ohnehin nur ueber /lyra erbeImmer vor.
--   3. Ohne Koordinaten kein Ort. Eintraege von vor 0.9 (und jeder Tod in einer Instanz, in der
--      C_Map nichts lieferte) tragen kein mapID/x/y - sie werden UEBERSPRUNGEN, nicht geraten.
-- Rueckgabe: juengster zuerst, und zwar NACH ZEITSTEMPEL sortiert und nicht nach Listenplatz.
-- Die Liste wird zwar angehaengt und ist damit normalerweise schon zeitlich geordnet - aber
-- "normalerweise" ist keine Zusage: MAX_ERBE schneidet vorne ab, und eine von Hand editierte
-- SavedVariables-Datei kann jede Reihenfolge haben. Karte2 waehlt daraus den juengsten, wenn
-- an einer Stelle mehrere liegen; das darf nicht vom Listenplatz abhaengen.
local function sterbeortKey(e)
    return ("s%s_%d_%d_%d"):format(tostring(e.mapID),
        math.floor((e.x or 0) * 1000 + 0.5), math.floor((e.y or 0) * 1000 + 0.5),
        math.floor(tonumber(e.t) or 0))
end
E.sterbeortKey = sterbeortKey

function E.sterbeorte(mapID)
    local out = {}
    local liste = erbeListe()
    if type(liste) ~= "table" then return out end
    local eigen = ns.charKey or ((UnitName and UnitName("player") or "?") .. "-"
                                 .. ((GetRealmName and GetRealmName()) or "?"))
    for i = #liste, 1, -1 do                       -- juengster zuerst
        local e = liste[i]
        if type(e) == "table" and e.name and e.name ~= ""
           and (e.quelle == nil or e.quelle == "selbst")
           and (tostring(e.name) .. "-" .. tostring(e.realm or "?")) ~= eigen
           and type(e.mapID) == "number" and type(e.x) == "number" and type(e.y) == "number"
           and (mapID == nil or e.mapID == mapID) then
            out[#out + 1] = {
                name  = e.name,
                level = tonumber(e.level) or 0,
                zone  = (e.zone and e.zone ~= "") and e.zone or nil,
                mapID = e.mapID, x = e.x, y = e.y,
                t     = tonumber(e.t) or 0,
                key   = sterbeortKey(e),
            }
        end
    end
    table.sort(out, function(a, b)
        if a.t ~= b.t then return a.t > b.t end
        return tostring(a.key) < tostring(b.key)   -- stabil bei gleichem Zeitstempel
    end)
    return out
end

function E.stand()
    return letzterEintrag, ns.erbeWarteAufWorte, worteBis, gewrappt, halleGewrappt
end

-- ---------------------------------------------------------------- W16B: Setzer/Leser fuer e.hergang
-- docs/welle13c-2026-09-21.md §3g ("Offene Schnittstellen, nicht in dieser Runde gebaut"): ein
-- additives Feld auf dem EIGENEN, juengsten Erbe-Eintrag, damit Sinne/Welle13c.lua nicht selbst in
-- diese Liste schreibt. Wortlaut wie dort vorgeschlagen, unveraendert uebernommen.
function E.hergangSetzen(tab)   -- nur der EIGENE, juengste Eintrag; nie ueberschreiben
    local e = letzterEintrag
    if not (e and type(tab) == "table") then return false end
    if type(e.hergang) == "table" then return false end
    e.hergang = tab
    return true
end
function E.hergangVon(eintrag) return type(eintrag) == "table" and eintrag.hergang or nil end
