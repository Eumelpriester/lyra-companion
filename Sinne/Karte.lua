-- Sinne/Karte.lua — Karte und Marks (Welle 2). Pins fuer eigene Beinahe-Stellen und Notizen auf
-- Weltkarte/Minimap ueber HereBeDragons-Pins-2.0 (nur wenn ein anderes Addon die Lib liefert;
-- nichts eingebettet), Raid-Marks per SetRaidTarget (nicht protected; in Schlachtzuegen nur mit Assist).
-- API: LibStub, HereBeDragons-Pins-2.0, SetRaidTarget, UnitExists/UnitIsPlayer/UnitCanAttack, C_Map.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local K = {}
ns.Sinne.Karte = K
ns.Karte = K

local function hbd()
    if not LibStub then return nil end
    local ok, lib = pcall(LibStub, "HereBeDragons-Pins-2.0", true)
    if ok and lib and lib.AddWorldMapIconMap then return lib end
    return nil
end
-- REVIEW6B: Frames legt WoW an und gibt sie NIE wieder frei. Vorher entstand bei jedem Aufruf von
-- K.aktualisieren() ein frischer Satz Frames - und der Aufruf kommt beim Login, nach jedem HP20 und
-- nach jedem gesetzten Punkt. Eine lange Sitzung haette so hunderte tote Frames hinterlassen.
-- Jetzt ein Pool: je Platz ein Frame, Text und Farbe werden nur umgesetzt.
local POOL = {}
local function pin(schluessel, text, art)
    local f = POOL[schluessel]
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(14, 14)
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints(f)
        t:SetTexture(ns.PFAD .. "bilder\\icon.png")
        f.tex = t
        f:EnableMouse(true)
        f:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Lyra", 0.75, 0.55, 1)
            GameTooltip:AddLine(self.lyraText or "", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        POOL[schluessel] = f
    end
    f.lyraText = text
    if art == "beinahe" then f.tex:SetVertexColor(1, 0.45, 0.45)
    elseif art == "rivale" then f.tex:SetVertexColor(1, 0.3, 0.2)
    else f.tex:SetVertexColor(0.8, 0.6, 1) end
    return f
end

function K.aktualisieren()
    local lib = hbd()
    if not lib then return 0 end
    -- REVIEW6B: erst abraeumen, DANN den Schalter pruefen - sonst bleiben die alten Pins liegen,
    -- wenn man "Karten-Pins" in den Einstellungen ausschaltet.
    pcall(lib.RemoveAllWorldMapIcons, lib, K)
    pcall(lib.RemoveAllMinimapIcons, lib, K)
    if ns.Get("karte") == false then K.anzahl = 0; return 0 end
    local c = LyraGestaltDB and LyraGestaltDB.chronik and LyraGestaltDB.chronik[ns.charKey]
    if not c then K.anzahl = 0; return 0 end
    local n = 0
    local de = ns.sprache() == "de"
    for _, b in ipairs(c.beinahe or {}) do
        if b.mapID and b.x and b.y then
            n = n + 1
            local txt = (de and "Hier war es knapp: %s%%%s" or "Close call here: %s%%%s"):format(tostring(b.hp or "?"), b.gegner and (" – " .. b.gegner) or "")
            pcall(lib.AddWorldMapIconMap, lib, K, pin("w" .. n, txt, "beinahe"), b.mapID, b.x, b.y, 3)
        end
    end
    local m = 0
    for _, z in ipairs(c.notizen or {}) do
        if z.mapID and z.x and z.y then
            n = n + 1; m = m + 1
            local txt = tostring(z.text or "")
            pcall(lib.AddWorldMapIconMap, lib, K, pin("w" .. n, txt, "notiz"), z.mapID, z.x, z.y, 3)
            pcall(lib.AddMinimapIconMap, lib, K, pin("m" .. m, txt, "notiz"), z.mapID, z.x, z.y, false, true)
        end
    end
    K.anzahl = n
    return n
end

ns.on("PLAYER_LOGIN", function()
    ns.Compat.After(12, function() pcall(K.aktualisieren) end)
    if ns.nachAusgabe then
        ns.nachAusgabe(function(id)
            if id == "HP20" or id == "PUNKT_GESETZT" then ns.Compat.After(35, function() pcall(K.aktualisieren) end) end
        end)
    end
    if ns.Dialog and type(ns.Dialog.aktionen) == "table" then
        -- REVIEW6B: fn(inhalt, roh) - bei einem Wort-Intent ist "inhalt" leer, dann traegt der
        -- Rohtext das gewuenschte Zeichen ("setz ein zeichen auf den mond").
        ns.Dialog.aktionen.w2_mark = function(inhalt, roh)
            local i = K.markAusText((inhalt and inhalt ~= "") and inhalt or roh)
            local ok = K.mark(i)
            if ok then return nil end            -- MARK_GESETZT kommt schon ueber ns.melde
            return "w2_mark_nein", { name = K.zielName() }
        end
        ns.Dialog.aktionen.w2_karte = function()
            local n = K.aktualisieren()
            return "w2_karte", { n = n }
        end
    end
end)

-- Marks
K.MARKS = { totenkopf = 8, skull = 8, kreuz = 7, cross = 7, x = 7, quadrat = 6, square = 6, mond = 5, moon = 5,
            dreieck = 4, triangle = 4, diamant = 3, diamond = 3, kreis = 2, circle = 2, stern = 1, star = 1 }
function K.markAusText(s)
    s = tostring(s or ""):lower()
    local n = tonumber(s:match("(%d)"))
    if n and n >= 1 and n <= 8 then return n end
    -- REVIEW6B: ganze Woerter von links nach rechts. Vorher lief eine Teilstring-Suche ueber
    -- pairs(K.MARKS) - die Reihenfolge von pairs ist nicht festgelegt (bei "kreuz oder mond" gewann
    -- mal das eine, mal das andere), und der Schluessel "x" traf jedes Wort mit einem x darin.
    for wort in s:gmatch("[%a]+") do
        local i = K.MARKS[wort]
        if i then return i end
    end
    return 8
end
function K.zielName()
    if UnitExists and UnitExists("target") and not (UnitIsPlayer and UnitIsPlayer("target")) then return UnitName("target") end
    return nil
end
-- REVIEW6B: SetRaidTarget traegt in der Era-Doku (RaidMarkersDocumentation.lua, 1.15.9)
-- HasRestrictions = true, warcraft.wiki fuehrt es als #protected. In der Praxis ruft unitscan
-- (unitscan.lua:15) es auf Era direkt aus einem Event-Handler - es geht dort also. Verlassen wollen
-- wir uns nicht darauf: ein geblockter Aufruf wirft KEINEN Lua-Fehler, pcall meldet brav Erfolg und
-- Lyra haette "Zeichen sitzt" gesagt, ohne dass etwas passiert ist. Deshalb wird das Ergebnis mit
-- GetRaidTargetIndex (nicht eingeschraenkt) nachgelesen. Aufgerufen wird ausschliesslich aus
-- Hardware-Kontext (Slash-Eingabe / Dialog-Freitext), nie aus einem ns.melde-Hook oder Timer.
function K.mark(i)
    i = tonumber(i) or 8
    if not (UnitExists and UnitExists("target")) then return false end
    if UnitIsPlayer and UnitIsPlayer("target") then return false end   -- Grenze B: nie auf Spieler
    if CanBeRaidTarget then
        local okC, darf = pcall(CanBeRaidTarget, "target")
        if okC and darf == false then return false end
    end
    -- Im Schlachtzug darf nur Leiter/Assistent setzen (Muster unitscan.lua:15).
    if IsInRaid and IsInRaid() then
        local leiter = (UnitIsGroupLeader and UnitIsGroupLeader("player")) or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
        if not leiter then return false end
    end
    if not SetRaidTarget then return false end
    pcall(SetRaidTarget, "target", i)
    local ok = true
    if GetRaidTargetIndex then
        local okG, jetzt = pcall(GetRaidTargetIndex, "target")
        ok = okG and jetzt == i
    end
    if ok then ns.melde("MARK_GESETZT", { name = UnitName("target") or "?", direkt = true }) end
    return ok
end
