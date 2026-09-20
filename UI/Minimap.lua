-- UI/Minimap.lua — Minimap-Knopf ohne Libs (LibDBIcon-Muster nachgebaut). Parent Minimap, Position per
-- Winkel (ns.db.minimapWinkel, Grad), Drag am Rand mit OnUpdate-Akkumulator NUR waehrend des Drags.
-- Linksklick: Lyra ein-/ausblenden (ns.Settings.setze("versteckt")), Rechtsklick: Lyras Menue
-- (FIX5, 0.6.1 - vorher direkt die Einstellungen; die stehen jetzt im Menue), Tooltip.
-- Icon: bilder/icon.png (64x64, rund maskiert, aus happy.png Frame 0 erzeugt). Einstellung "minimap" (Default true).
-- API: CreateFrame("Button"), Minimap:GetCenter/GetWidth/GetEffectiveScale, GetCursorPosition, GameTooltip. Nichts Fremdes.
local ADDON, ns = ...
local M = {}
ns.Minimap = M

M.RADIUS_RUND = 80
M.RADIUS_ECKIG = 110
M.DRAG_TAKT = 0.05    -- s, Akkumulator im OnUpdate waehrend des Drags

-- REVIEW: kein Frame-Name -> kein zusaetzlicher Global
local b = CreateFrame("Button", nil, Minimap)
b:SetSize(31, 31)
b:SetFrameStrata("MEDIUM")
b:SetFrameLevel(8)
b:EnableMouse(true)
b:SetMovable(false)
b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
b:RegisterForDrag("LeftButton")
if b.SetHighlightTexture then b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight") end

local hintergrund = b:CreateTexture(nil, "BACKGROUND")
hintergrund:SetSize(20, 20)
hintergrund:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
hintergrund:SetPoint("TOPLEFT", 7, -5)
-- DESIGN-V3 B-10 / H-1 (17.09.2026): 20 x 20 statt 18 x 18, buendig auf dem Grund bei (7, -5).
-- MiniMap-TrackingBorder traegt 20 - die 18 liessen einen dunklen Saum stehen und verschenkten
-- 23 % Flaeche. Das neue bilder/icon.png (64 x 64) ist aus demselben Fenster geschnitten wie das
-- Portrait und traegt den violetten Ring mit 5/64 - bei 20 px Anzeige rund 1,6 px, also gerade
-- noch als Ring lesbar. Das alte Icon (Gesicht links, rechts leere dunkle Flaeche) liegt als
-- bilder/icon_alt.png daneben.
local icon = b:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetTexture(ns.PFAD .. "bilder\\icon.png")
icon:SetPoint("TOPLEFT", 7, -5)
local rand = b:CreateTexture(nil, "OVERLAY")
rand:SetSize(53, 53)
rand:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
rand:SetPoint("TOPLEFT")
M.button, M.icon = b, icon

local function winkel()
    local w = tonumber(ns.Get("minimapWinkel")) or 220
    return w % 360
end

local function eckig()
    if GetMinimapShape then
        local ok, form = pcall(GetMinimapShape)
        return ok and form and form ~= "ROUND"
    end
    return false
end

-- Position aus dem Winkel; bei eckiger Minimap auf den Rand des Quadrats klemmen (LibDBIcon-Muster)
local function positioniere()
    local rad = math.rad(winkel())
    local x, y = math.cos(rad), math.sin(rad)
    if eckig() then
        local w = (Minimap:GetWidth() or 140) / 2 + 5
        local h = (Minimap:GetHeight() or 140) / 2 + 5
        x = math.max(-w, math.min(x * M.RADIUS_ECKIG, w))
        y = math.max(-h, math.min(y * M.RADIUS_ECKIG, h))
    else
        x, y = x * M.RADIUS_RUND, y * M.RADIUS_RUND
    end
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Drag: Winkel aus der Cursorposition relativ zur Minimap-Mitte; OnUpdate nur waehrend des Drags
local akku = 0
local function dragUpdate(self, elapsed)
    akku = akku + (elapsed or 0)
    if akku < M.DRAG_TAKT then return end
    akku = 0
    local mx, my = Minimap:GetCenter()
    if not mx then return end
    local cx, cy = GetCursorPosition()
    local s = Minimap:GetEffectiveScale()
    if not s or s == 0 then s = 1 end
    cx, cy = cx / s, cy / s
    local w = math.deg(math.atan2(cy - my, cx - mx))
    if ns.db then ns.db.minimapWinkel = w % 360 end   -- ohne ns.Set: kein onSetting je Tick
    positioniere()
end
b:SetScript("OnDragStart", function(self)
    akku = 0
    self:SetScript("OnUpdate", dragUpdate)
    if GameTooltip then GameTooltip:Hide() end
end)
b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    ns.Set("minimapWinkel", winkel())   -- einmal sauber speichern (loest onSetting -> layout aus)
end)

local function setze(key, value)
    if ns.Settings and ns.Settings.setze then ns.Settings.setze(key, value) else ns.Set(key, value) end
end
-- FIX5 (0.6.1): Rechtsklick oeffnet jetzt LYRAS MENUE, nicht mehr direkt die Einstellungen -
-- die stehen als letzter Eintrag im Menue. Grund: seit der Rechtsklick auf die Gestalt das
-- Gespraech oeffnet, ist der Minimap-Knopf der Hauptweg zum Menue (dazu Shift+Rechtsklick auf
-- Lyra und /lyra menue). Ohne UI/Menue.lua bleibt der alte Weg als Rueckfall.
b:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        if GameTooltip then GameTooltip:Hide() end
        if ns.menue then ns.menue() elseif ns.oeffneSettings then ns.oeffneSettings() end
    else
        setze("versteckt", not ns.Get("versteckt"))
    end
end)

b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(ns.L["Lyra Gestalt"], 0.7, 0.55, 1)
    GameTooltip:AddLine(ns.L[ns.Get("versteckt") and "Lyra hidden" or "Lyra visible"], 1, 1, 1)
    GameTooltip:AddLine(ns.L["Minimap hint"], 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end)
b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

-- Einmaliges Pulsen beim allerersten Start (design-v2.md 7): "ich bin auch hier", ohne ein Wort.
-- Alpha 1 -> 0.4 -> 1, drei Runden a 0.5 s, danach hart auf Alpha 1. Kein Scale (Hausregel).
local pulsAG
local pulsTicker
function M.pulse(runden)
    runden = tonumber(runden) or 3
    if not b:IsShown() then return false end
    if not pulsAG then
        if not b.CreateAnimationGroup then return false end
        local ok, ag = pcall(b.CreateAnimationGroup, b)
        if not ok or not ag or not ag.CreateAnimation then return false end
        local ok2 = pcall(function()
            local a1, a2 = ag:CreateAnimation("Alpha"), ag:CreateAnimation("Alpha")
            if not (a1.SetFromAlpha and a1.SetToAlpha) then error("keine Alpha-API") end
            a1:SetFromAlpha(1); a1:SetToAlpha(0.4); a1:SetDuration(0.25); a1:SetOrder(1)
            a2:SetFromAlpha(0.4); a2:SetToAlpha(1); a2:SetDuration(0.25); a2:SetOrder(2)
            ag:SetLooping("REPEAT")
        end)
        if not ok2 then return false end
        pulsAG = ag
    end
    if pulsTicker then pulsTicker:Cancel(); pulsTicker = nil end
    pcall(function() if pulsAG:IsPlaying() then pulsAG:Stop() end; b:SetAlpha(1); pulsAG:Play() end)
    pulsTicker = ns.Compat.NewTicker(runden * 0.5 + 0.05, function()
        pulsTicker = nil
        pcall(function() if pulsAG:IsPlaying() then pulsAG:Stop() end end)
        b:SetAlpha(1)
    end, 1)
    return true
end

function M.layout()
    if not ns.db then return end
    if ns.Get("minimap") == false then b:Hide(); return end
    positioniere()
    b:Show()
end

b:Hide()
-- Nach Start.lua's PLAYER_LOGIN (DB steht sicher): einen Tick spaeter layouten
ns.on("PLAYER_LOGIN", function() ns.Compat.After(0, M.layout) end)
