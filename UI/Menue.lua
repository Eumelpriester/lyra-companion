-- UI/Menue.lua — Lyras Menue (design-v3 E). Eigenes Mini-Menue (kein UIDropDownMenu/
-- MenuUtil: in Era 1.15.9 nicht vorhanden bzw. Taint-Risiko). Eigene, nicht-secure Frames: auch im Kampf
-- per Maus bedienbar; Tasten 1-9 nur ausserhalb des Kampfes (SetPropagateKeyboardInput ist im Kampf gesperrt).
-- Wege hierher (FIX5): Shift+Rechtsklick auf die Gestalt, Rechtsklick auf den Minimap-Knopf, /lyra menue.
--   Der einfache Rechtsklick auf die Gestalt oeffnet seit 0.6.1 das Gespraech (UI/Dialog.lua).
-- Ort: am Mauszeiger (das Menue kann jetzt auch vom Minimap-Knopf kommen, also weit weg von Lyra),
--   SetClampedToScreen haelt es im Bild; ohne Cursorposition neben der Gestalt.
-- Schliesst bei Klick ausserhalb, ESC (UISpecialFrames), nach Auswahl und wenn der Spieler losläuft
--   (GetUnitSpeed-Ticker nur bei offenem Menue).
-- FIX5 (17.09.2026), der Fehler, der das Menue unbedienbar gemacht hat: die FontStrings werden ohne
--   Blizzard-Vorlage angelegt (Zeile 31/55/58) und bekamen ihre Schrift ERST NACH dem SetText.
--   Eine FontString ohne Schrift wirft bei SetText "FontString:SetText(): Font not set" - ein harter
--   Lua-Fehler, der M.oeffne mittendrin abbrach, bevor irgendetwas sichtbar wurde. Jetzt laeuft
--   jeder Text ueber ns.Optik.setzeText (erst Schrift, dann Text). Beleg: docs/fix5-2026-09-17.md.
-- Optik: ns.Optik (dieselbe wie Dialog/Blase). API: CreateFrame, GetCursorPosition, GetUnitSpeed,
--   UISpecialFrames. Nichts Fremdes.
local ADDON, ns = ...
local M = {}
ns.Menue = M

-- DESIGN-V3 Team B: B-3 weiche Oeffnung (Alpha 0,08 s, ns.Optik.einblenden), B-4 Fusszeile mit den
--   Tastenkuerzeln, B-1 Schriftgroesse aus ns.Optik.schriftgroesse() (kennt "auto").
local BREITE, ZEILE, RAND, KOPF = 210, 22, 8, 40
local FUSS = 20               -- B-4: Hoehe der Kuerzel-Zeile am Fuss

local fang = CreateFrame("Frame", nil, UIParent)
fang:SetAllPoints(UIParent)
fang:SetFrameStrata("DIALOG")
fang:SetFrameLevel(1)
fang:EnableMouse(true)
fang:Hide()

local f = CreateFrame("Frame", "LyraGestaltMenue", fang, BackdropTemplateMixin and "BackdropTemplate" or nil)
f:SetFrameStrata("DIALOG")
f:SetFrameLevel(5)
f:SetClampedToScreen(true)
f:EnableMouse(true)
f:Hide()
tinsert(UISpecialFrames, "LyraGestaltMenue")
M.frame = f

-- Kopf: kleines Portrait + Titel
local portrait
local titel = f:CreateFontString(nil, "OVERLAY")
-- FIX5: Schrift schon zur Ladezeit - danach kann kein SetText mehr "Font not set" werfen.
if ns.Optik then ns.Optik.schrift(titel) else pcall(titel.SetFont, titel, STANDARD_TEXT_FONT, 16, "") end
local linie
-- B-4: Die Ziffern stehen seit 0.6.0 neben jedem Eintrag - was fehlte, ist die Zeile, die sagt,
-- dass es sie gibt. Sie kostet 20 px und erspart die Entdeckung durch Zufall. Im Kampf greifen
-- die Tasten nicht (SetPropagateKeyboardInput ist dort gesperrt), deshalb dort auf Alpha 0,4.
local fuss = f:CreateFontString(nil, "OVERLAY")
if ns.Optik then ns.Optik.schrift(fuss) else pcall(fuss.SetFont, fuss, STANDARD_TEXT_FONT, 11, "") end
fuss:SetJustifyH("CENTER")
M.fuss = fuss
local function kopfBauen()
    if portrait or not ns.Optik then return end
    portrait = ns.Optik.portrait(f, 28)
    portrait.frame:SetPoint("TOPLEFT", RAND, -RAND)
    titel:SetPoint("LEFT", portrait.frame, "RIGHT", 6, 0)
    linie = ns.Optik.trennlinie(f)
    linie:SetPoint("TOPLEFT", RAND, -(RAND + 28 + 4))
    linie:SetPoint("TOPRIGHT", -RAND, -(RAND + 28 + 4))
end

local knoepfe = {}
local function knopf(i)
    local b = CreateFrame("Button", nil, f)
    b:SetSize(BREITE - 2 * RAND, ZEILE)
    b:SetPoint("TOPLEFT", RAND, -(KOPF + RAND + (i - 1) * ZEILE))
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    b.bg = bg
    local balken = b:CreateTexture(nil, "ARTWORK")   -- Hover: 3 px violetter Balken links
    balken:SetPoint("TOPLEFT", 0, 0); balken:SetPoint("BOTTOMLEFT", 0, 0); balken:SetWidth(3)
    balken:Hide()
    b.balken = balken
    local nr = b:CreateFontString(nil, "OVERLAY")
    nr:SetPoint("LEFT", 8, 0); nr:SetWidth(16); nr:SetJustifyH("LEFT")
    b.nr = nr
    local t = b:CreateFontString(nil, "OVERLAY")
    t:SetPoint("LEFT", 26, 0); t:SetPoint("RIGHT", -6, 0); t:SetJustifyH("LEFT")
    b.text = t
    -- FIX5: Schrift sofort setzen, nicht erst beim Oeffnen. Eine FontString ohne Schrift ueberlebt
    -- kein SetText - und sie soll auch dann Text annehmen, wenn ns.Optik einmal fehlt.
    if ns.Optik then ns.Optik.schrift(nr); ns.Optik.schrift(t)
    else pcall(nr.SetFont, nr, STANDARD_TEXT_FONT, 14, ""); pcall(t.SetFont, t, STANDARD_TEXT_FONT, 14, "") end
    local function faerbe(drauf)
        local c = ns.Optik and ns.Optik.farben() or nil
        if not c then return end
        ns.Optik.flaeche(bg, drauf and c.knopfH or { 0, 0, 0, 0 })
        ns.Optik.flaeche(balken, ns.Optik.LILA)
        if drauf then balken:Show() else balken:Hide() end
        local tc = drauf and c.antwortH or c.antwort
        t:SetTextColor(tc[1], tc[2], tc[3])
        local z = drauf and c.zifferH or c.ziffer
        nr:SetTextColor(z[1], z[2], z[3])
    end
    b.faerbe = faerbe
    b:SetScript("OnEnter", function() faerbe(true) end)
    b:SetScript("OnLeave", function() faerbe(false) end)
    b:SetScript("OnClick", function(self)
        M.schliesse()
        if self.fn then self.fn() end
    end)
    knoepfe[i] = b
    return b
end

local laufTicker
function M.schliesse()
    if laufTicker then laufTicker:Cancel(); laufTicker = nil end
    pcall(f.EnableKeyboard, f, false)
    fang:Hide()
    f:Hide()
end
fang:SetScript("OnMouseDown", M.schliesse)
f:SetScript("OnHide", function() fang:Hide(); if laufTicker then laufTicker:Cancel(); laufTicker = nil end end)

-- Still-Modus: nur die Variable + Meldung. Die Regie (nur warn durchlassen) liegt beim Kern.
function ns.stillSetzen(an)
    ns.stillModus = an and true or false
    if ns.melde then ns.melde(ns.stillModus and "STILL_AN" or "STILL_AUS") end
    ns.print(ns.stillModus and ns.L["Quiet on"] or ns.L["Quiet off"])
end

local function setze(key, value)
    if ns.Settings and ns.Settings.setze then ns.Settings.setze(key, value) else ns.Set(key, value) end
end

-- Letzten Satz merken (Hook nach jeder Ausgabe) und auf Wunsch wiederholen
M.letzte = nil
if ns.nachAusgabe then
    ns.nachAusgabe(function(id, e, vars, text)
        if text and (text.de or text.en) then M.letzte = { text = text, vars = vars, klasse = e and e.klasse } end
    end)
end
function M.wiederholen()
    local l = M.letzte
    if not l then ns.print(ns.L["Nothing to repeat"]); return end
    local s = ns.sprache()
    local zeile = ns.fuelle(ns.Anrede(l.text[s] or l.text.en or ""), l.vars)
    if ns.Blase and ns.Blase.zeige then ns.Blase.zeige(zeile, ns.Get("blaseDauer"), l.klasse) else ns.print(zeile) end
end

local GROESSEN = { "klein", "mittel", "gross" }
local function naechsteGroesse()
    local g = ns.Get("groesse") or "mittel"
    for i, n in ipairs(GROESSEN) do if n == g then return GROESSEN[(i % #GROESSEN) + 1] end end
    return "mittel"
end

local function eintraege()
    local L = ns.L
    local g = ns.Get("groesse") or "mittel"
    local gLabel = (g == "klein" and L["Size small"]) or (g == "gross" and L["Size large"]) or L["Size medium"]
    local liste = {
        { L["Say something"], function() if ns.melde then ns.melde("KLICK", { direkt = true }) end end },
        { L["Ask me"], function() if ns.Dialog and ns.Dialog.oeffne then ns.Dialog.oeffne() end end },
        { L["Repeat last"], M.wiederholen },
        { (ns.stillModus and "|cff88ff88+|r " or "") .. L["Quiet mode"], function() ns.stillSetzen(not ns.stillModus) end },
        { (ns.Get("ansicht") == "figur") and L["View portrait"] or L["View figure"], function()
            setze("ansicht", (ns.Get("ansicht") == "figur") and "portrait" or "figur") end },
        { L["Size preset"] .. ": " .. gLabel, function() setze("groesse", naechsteGroesse()) end },
        { ns.Get("gesperrt") and L["Unlock"] or L["Lock"], function() setze("gesperrt", not ns.Get("gesperrt")) end },
        { L["Hide"], function() setze("versteckt", true); ns.print(L["Hidden hint"]) end },
        { L["Settings"], function() if ns.oeffneSettings then ns.oeffneSettings() end end },
    }
    -- W14E: das Minispiel "Weisst du noch?" (Sinne/Welle14e.lua). EIN Eintrag, und er haengt
    -- HINTEN an - die Ziffern 1-9 der bestehenden neun Eintraege bleiben damit unveraendert.
    -- menueEintrag() gibt nil zurueck, solange nicht gespielt werden darf (Haekchen aus, Kampf,
    -- Instanz, unter 50 % Leben, tot) oder kein Anlass da ist (kein Taxi, keine Rast) - dann
    -- steht hier gar nichts, und das Menue ist die ueblichen neun Zeilen lang. Ein Menuepunkt,
    -- der beim Klick "nicht jetzt" sagt, waere ein Versprechen, das nicht gehalten wird.
    -- Der zehnte Eintrag hat keine Taste; fuer ein Spiel, dessen erste Regel "Maus, nur Maus"
    -- heisst, ist das kein Mangel (Recherche 19 §2.2, §2.6).
    if ns.Welle14e and type(ns.Welle14e.menueEintrag) == "function" then
        local ok, e = pcall(ns.Welle14e.menueEintrag)
        if ok and type(e) == "table" and e[1] and type(e[2]) == "function" then
            liste[#liste + 1] = e
        end
    end
    return liste
end

-- Tasten 1-9 nur ausserhalb des Kampfes
f:SetScript("OnKeyDown", function(self, key)
    local durch = true
    local n = tonumber(key) or tonumber((key or ""):match("^NUMPAD(%d)$"))
    if n and knoepfe[n] and knoepfe[n]:IsShown() then
        durch = false
        M.schliesse()
        if knoepfe[n].fn then knoepfe[n].fn() end
    end
    if not (InCombatLockdown and InCombatLockdown()) then pcall(self.SetPropagateKeyboardInput, self, durch) end
end)

-- FIX5: wieder AM CURSOR. Das Menue kam bis 0.6.0 immer neben die Gestalt - seit es auch ueber den
-- Minimap-Knopf zu oeffnen ist, waere das der falsche Ort (Knopf oben rechts, Lyra unten rechts).
-- Am Cursor steht es dort, wo der Spieler gerade hinsieht; SetClampedToScreen haelt es im Bild.
local function positioniere()
    f:ClearAllPoints()
    local x, y
    if GetCursorPosition then
        local ok, cx, cy = pcall(GetCursorPosition)
        if ok then x, y = cx, cy end
    end
    local s = UIParent:GetEffectiveScale()
    if x and y and s and s > 0 and (x ~= 0 or y ~= 0) then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
        return
    end
    local g = ns.Gestalt and ns.Gestalt.frame
    if g and g:IsShown() and not ns.Get("versteckt") then
        local seite = ns.Optik and ns.Optik.freieSeite() or "RIGHT"
        if seite == "RIGHT" then f:SetPoint("LEFT", g, "RIGHT", 6, 0) else f:SetPoint("RIGHT", g, "LEFT", -6, 0) end
        return
    end
    f:SetPoint("CENTER")
end

function M.oeffne()
    if f:IsShown() then M.schliesse(); return end
    if ns.Dialog and ns.Dialog.schliesse then ns.Dialog.schliesse() end
    kopfBauen()
    if ns.Optik then
        ns.Optik.panel(f)
        if portrait then
            local m = ns.Gestalt and ns.Gestalt.aktuell or "neutral"
            portrait:miene(m)
        end
    end
    -- FIX5: ns.Optik.setzeText setzt IMMER erst die Schrift und dann den Text. Vorher stand
    -- b.nr:SetText VOR ns.Optik.schrift - der harte Fehler "Font not set" brach M.oeffne genau hier
    -- ab, und zwar bevor fang:Show()/f:Show() liefen: fuer Harald "der Rechtsklick tut nichts".
    if ns.Optik then ns.Optik.setzeText(titel, ns.L["Lyra Gestalt"], ns.Optik.schriftgroesse(), ns.Optik.farben().titel)
    else titel:SetText(ns.L["Lyra Gestalt"]) end
    local liste = eintraege()
    local size = ns.Optik and (ns.Optik.schriftgroesse() - 1) or 14
    for i, e in ipairs(liste) do
        local b = knoepfe[i] or knopf(i)
        if ns.Optik then
            ns.Optik.setzeText(b.nr, tostring(i), size)
            ns.Optik.setzeText(b.text, e[1], size)
        else
            b.nr:SetText(tostring(i)); b.text:SetText(e[1])
        end
        b.fn = e[2]
        b.faerbe(false)
        b:SetHeight(math.max(ZEILE, size + 8))
        b:Show()
    end
    for i = #liste + 1, #knoepfe do knoepfe[i]:Hide() end
    local zeile = math.max(ZEILE, size + 8)
    for i = 1, #liste do knoepfe[i]:ClearAllPoints(); knoepfe[i]:SetPoint("TOPLEFT", RAND, -(KOPF + RAND + (i - 1) * zeile)); knoepfe[i]:SetPoint("RIGHT", -RAND, 0) end
    -- B-4: Fusszeile "1-9 · Esc schliesst". Die Zahl kommt aus der Liste, nicht aus dem Kopf -
    -- faellt ein Eintrag weg, stimmt die Zeile trotzdem.
    local kampf = (InCombatLockdown and InCombatLockdown()) and true or false
    local fussH = 0
    if ns.Optik then
        -- MERGE 0.17.0 (W14E §3g2): mit dem Eintrag des Minispiels kann die Liste zehn Zeilen
        -- lang werden - eine Taste "10" gibt es aber nicht (Ziffern 1-9, siehe OnKeyDown unten).
        -- Ohne den Deckel sagt die Fusszeile "1-10" und verspricht eine Taste, die es nie gab.
        local ft = (ns.L["Keys hint"] or "1-%d"):format(math.min(#liste, 9))
        ns.Optik.setzeText(fuss, ft, math.max(9, size - 3), ns.Optik.farben().linie)
        fuss:ClearAllPoints()
        fuss:SetPoint("BOTTOMLEFT", RAND, RAND - 2)
        fuss:SetPoint("BOTTOMRIGHT", -RAND, RAND - 2)
        pcall(fuss.SetAlpha, fuss, kampf and 0.4 or 1)
        fuss:Show()
        fussH = FUSS
    else
        fuss:Hide()
    end
    f:SetSize(BREITE, KOPF + RAND * 2 + #liste * zeile + fussH)
    positioniere()
    fang:Show()
    -- B-3: Alpha 0 -> 1 in 0,08 s. Kein Scale (Hausregel). Ohne Animations-API schlicht Show().
    if ns.Optik and ns.Optik.einblenden then ns.Optik.einblenden(f) else f:Show() end
    if not (InCombatLockdown and InCombatLockdown()) then
        pcall(f.SetPropagateKeyboardInput, f, true)
        pcall(f.EnableKeyboard, f, true)
    end
    -- Losgehen schliesst das Menue (Ticker nur solange offen)
    if GetUnitSpeed then
        laufTicker = ns.Compat.NewTicker(0.2, function()
            local ok, v = pcall(GetUnitSpeed, "player")
            if ok and v and v > 0 then M.schliesse() end
        end)
    end
end
ns.on("PLAYER_REGEN_DISABLED", function() pcall(f.EnableKeyboard, f, false) end)

function M.offen() return f:IsShown() and true or false end

-- B-1: Wechselt die UI-Groesse, waehrend das Menue offen steht, wird es einmal neu aufgebaut -
-- sonst stuenden die Knoepfe in der alten Hoehe und die Beschriftung in der neuen.
if ns.Optik and ns.Optik.beiSchrift then
    ns.Optik.beiSchrift(function()
        if not f:IsShown() then return end
        M.schliesse()
        M.oeffne()
    end)
end

ns.menue = M.oeffne
