-- UI/Streamer.lua — Streamer-Modus: Chroma-Kachel (reines Gruen) hinter der Gestalt, grosse Untertitel-Leiste
-- am unteren Bildschirmrand, Anrede automatisch "keine" (ns.streamerAnrede -> Core/Anrede.lua).
-- Einstellung "streamer" (Default false). Doku: Sinne/EXTRA.md.
-- Anbindung ohne Kern-Aenderung: Wrapper um ns.Blase.zeige (fertiger Text der aktiven Sprache, nach Anrede
-- und Platzhaltern) und um ns.onSetting (Original wird gemerkt und zuerst gerufen).
-- API: CreateFrame, Texture:SetColorTexture (Fallback SetTexture rgba), FontString, HookScript. Nichts Fremdes.
local ADDON, ns = ...
local St = {}
ns.Streamer = St

-- REVIEW7 / DESIGN-V3 B-8, B-9 (17.09.2026):
--   B-8  Die Untertitel-Leiste haengt nicht mehr am Streamer-Schalter, sondern an der eigenen
--        Einstellung "leiste" = aus | auto | immer (Default auto). Bis 0.6.2 schaltete EIN Flag
--        Chroma-Kachel, Leiste, Anrede und Glow gemeinsam um - wer nur Untertitel wollte, musste
--        die gruene Kachel mitnehmen. "auto" schaltet sie ein, wenn streamer laeuft, wenn Lyra
--        versteckt ist (dann kommt keine Blase - Barrierefreiheit 9) oder wenn die Schrift unter
--        12 liegt (sehr grosser UI-Scale, die Blase wird unlesbar klein). "streamer = true" setzt
--        "leiste" NICHT um, sondern wird in "auto" nur mitgelesen - sonst ueberschreibt ein Preset
--        eine bewusste Entscheidung.
--   B-9  Im Portrait ist die Chroma-Kachel RUND (portrait_scheibe.png, gruen eingefaerbt). Eine
--        quadratische Kachel um einen Kreis laesst die Ecken gruen stehen und der Chroma-Key
--        frisst die weiche Ringkante. In der Ganzfigur bleibt das Quadrat richtig.
St.RAND = 16                    -- px: quadratische Kachel groesser als die Gestalt (Ganzfigur)
St.RAND_RUND = 6                -- px: runde Kachel groesser als der Ring (Portrait, B-9)
St.UNTERTITEL_DAUER = 8
-- B-8: Die Leisten-Schrift folgt der Einstellung statt fest 22 zu sein. St.SCHRIFT bleibt der
-- Rueckfall, wenn ns.Optik fehlt; St.SCHRIFT_MIN ist die Untergrenze (unter 18 ist eine
-- Untertitel-Leiste im Stream nicht mehr lesbar).
St.SCHRIFT = 22
St.SCHRIFT_MIN = 18
St.SCHRIFT_PLUS = 6
St.BREITE_ANTEIL = 0.6          -- B-8: 0,6 x Bildschirm statt fester 900 px (bei 3440 war 900 ein Streifen)
-- FIX3: 0.85 statt 0.6. Bei 60 % Deckung schlug ein helles Spielbild (Schnee, Feuer) so weit durch,
-- dass Weiss auf dem Balken nur noch 6,8:1 erreichte - unter dem Ziel 7:1. Mit 0.85 sind es 15,9:1.
St.BALKEN_ALPHA = 0.85

-- ---------------------------------------------------------------- Chroma-Kachel
-- Eigener Frame unter G.frame (gleiche Strata, Frame-Level darunter); haengt an der Gestalt, folgt ihr also
-- bei Drag/Scale. Kein Alpha (Kampf-Transparenz betrifft nur die Gestalt, die Kachel bleibt keybar).
local chroma = CreateFrame("Frame", nil, UIParent)
chroma:SetFrameStrata("MEDIUM")
chroma:EnableMouse(false)
chroma:Hide()
local gruen = chroma:CreateTexture(nil, "BACKGROUND")
gruen:SetAllPoints(chroma)
if gruen.SetColorTexture then gruen:SetColorTexture(0, 1, 0, 1)
else pcall(gruen.SetTexture, gruen, 0, 1, 0, 1) end
St.chroma = chroma

local function gestalt() return ns.Gestalt and ns.Gestalt.frame end
local function istPortrait()
    return (ns.Gestalt and ns.Gestalt.istPortrait and ns.Gestalt.istPortrait()) and true or false
end

-- B-9: rund im Portrait, quadratisch in der Ganzfigur. Der Texturwechsel steht hier, damit
-- chromaLayout() ihn bei jedem Ansichtswechsel mitnimmt (ns.onSetting, key == "ansicht").
St.kachelRund = false
local function kachelForm(rund)
    if rund == St.kachelRund and St.kachelGesetzt then return end
    St.kachelRund, St.kachelGesetzt = rund, true
    if rund then
        local ok = pcall(gruen.SetTexture, gruen, ns.PFAD .. "bilder\\portrait_scheibe.png")
        if ok then
            pcall(gruen.SetVertexColor, gruen, 0, 1, 0, 1)
            if gruen.SetBlendMode then pcall(gruen.SetBlendMode, gruen, "BLEND") end
            return
        end
        St.kachelRund = false   -- Textur nicht ladbar: quadratisch weiter, nie ein Fehler
    end
    pcall(gruen.SetVertexColor, gruen, 1, 1, 1, 1)
    if gruen.SetColorTexture then gruen:SetColorTexture(0, 1, 0, 1)
    else pcall(gruen.SetTexture, gruen, 0, 1, 0, 1) end
end

local function chromaLayout()
    local g = gestalt()
    if not g then chroma:Hide(); return end
    local lvl = g:GetFrameLevel() or 0
    if lvl < 2 then pcall(g.SetFrameLevel, g, 2); lvl = 2 end
    pcall(chroma.SetFrameLevel, chroma, lvl - 1)
    local rund = istPortrait()
    kachelForm(rund)
    local rand = rund and St.RAND_RUND or St.RAND
    chroma:ClearAllPoints()
    chroma:SetPoint("CENTER", g, "CENTER", 0, 0)
    chroma:SetSize((g:GetWidth() or 0) + 2 * rand, (g:GetHeight() or 0) + 2 * rand)
    if ns.Get("streamer") and g:IsShown() and not ns.Get("versteckt") then chroma:Show() else chroma:Hide() end
end

-- ---------------------------------------------------------------- Untertitel-Leiste
local leiste = CreateFrame("Frame", nil, UIParent)
leiste:SetFrameStrata("HIGH")
leiste:EnableMouse(false)
leiste:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 60)
leiste:SetSize(900, 60)
leiste:Hide()
local balken = leiste:CreateTexture(nil, "BACKGROUND")
balken:SetAllPoints(leiste)
if balken.SetColorTexture then balken:SetColorTexture(0, 0, 0, St.BALKEN_ALPHA)
else pcall(balken.SetTexture, balken, 0, 0, 0, St.BALKEN_ALPHA) end
local text = leiste:CreateFontString(nil, "OVERLAY")
text:SetPoint("CENTER", leiste, "CENTER", 0, 0)
text:SetWidth(860)
text:SetJustifyH("CENTER")
text:SetWordWrap(true)
-- FIX5-Regel: Schrift IMMER vor dem ersten SetText. leisteLayout() bemisst sie danach neu.
text:SetFont(STANDARD_TEXT_FONT, St.SCHRIFT, "OUTLINE")
text:SetTextColor(1, 1, 1)
St.leiste, St.text = leiste, text

-- B-8: Die Leisten-Schrift folgt ns.Optik.schriftgroesse() (die "auto" kennt), nicht mehr einer
-- festen 22. Untergrenze St.SCHRIFT_MIN, damit sie im Stream lesbar bleibt.
function St.schriftgroesse()
    local basis = ns.Optik and ns.Optik.schriftgroesse and ns.Optik.schriftgroesse()
    if type(basis) ~= "number" then return St.SCHRIFT end
    local g = basis + St.SCHRIFT_PLUS
    return (g < St.SCHRIFT_MIN) and St.SCHRIFT_MIN or g
end

-- Breite und Schrift neu bemessen. Bei ns.Optik.beiSchrift angemeldet, damit die Leiste bei einem
-- UI-Scale-Wechsel mitzieht (die Funktion gibt es seit 0.6.2).
function St.leisteLayout()
    local ui = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
    local b = math.floor(ui * St.BREITE_ANTEIL + 0.5)
    if b < 400 then b = 400 end
    leiste:SetWidth(b)
    text:SetWidth(b - 40)
    pcall(text.SetFont, text, STANDARD_TEXT_FONT, St.schriftgroesse(), "OUTLINE")
    if leiste:IsShown() then
        local h = (text:GetStringHeight() or St.SCHRIFT) + 20
        leiste:SetHeight(math.max(48, h))
    end
end

-- B-8: aus | auto | immer. "auto" liest streamer/versteckt/Schriftgroesse mit, aendert aber nichts
-- an der gespeicherten Einstellung - ein Preset darf keine bewusste Entscheidung ueberschreiben.
function St.leisteAn()
    local v = ns.Get("leiste")
    if v == "immer" then return true end
    if v == "aus" then return false end
    -- auto (auch bei unbekanntem/fehlendem Wert)
    if ns.Get("streamer") then return true end
    if ns.Get("versteckt") then return true end   -- keine Blase -> die Zeile braucht einen Ort
    local g = ns.Optik and ns.Optik.schriftgroesse and ns.Optik.schriftgroesse()
    if type(g) == "number" and g < 12 then return true end
    return false
end

-- DESIGN-V3 A-5: Die Blase setzt seit 0.6.2 kein "! " mehr in den Text, sondern eine Icon-Textur
-- links davon. Die Untertitel-Leiste behaelt das Textpraefix - OBS liest keine Textur, und ein
-- Zuschauer sieht nur das, was im Bild steht.
-- ENTSCHIEDEN: ASCII "! " statt Unicode "\226\154\160" (U+26A0 WARNING SIGN). Begruendung: die
-- Leiste zeichnet mit STANDARD_TEXT_FONT (FRIZQT__.TTF bzw. ARIALN.TTF in den westlichen Locales),
-- und U+26A0 ist in diesen Blizzard-Schriften nicht belegt - es kaeme ein leeres Kaestchen heraus,
-- also genau das Gegenteil einer Warnung. "!" ist in jeder Schrift und in jedem Locale da.
-- Die Verzweigung haengt wie in der Blase an der STUFE, nicht an klasse == "warn"; ohne Stufe
-- (alte Aufrufer) gilt wieder die Klasse. Stufe >= 1 bekommt das Praefix - genau die Zeilen, die
-- in der Blase ein Icon bekommen. Damit ist die alte Doppelung ("! " hier UND dort) weg.
local function untertitelPraefix(stufe, klasse)
    local s = tonumber(stufe)
    if not s then s = (klasse == "warn") and 2 or 0 end
    return (s >= 1) and "! " or ""
end
St.untertitelPraefix = untertitelPraefix
-- W7 (offener Punkt 4 aus docs/welle6-2026-09-20.md): untertitel() rief bis 0.10.0 die LOKALE
-- Funktion - St.untertitelPraefix zu ersetzen hat deshalb nichts bewirkt, und die Leiste blieb
-- beim alten "! ", waehrend die Blase seit Welle 6 "o"/"^"/"^^" traegt. Der Umweg ueber diese
-- Bruecke ist die ganze Aenderung: wer das Feld setzt, aendert die Leiste; wirft der Ersatz oder
-- gibt er keinen String zurueck, gilt wieder das Original. Eine Leiste ohne Praefix waere
-- schlimmer als ein altmodisches.
local function praefix(stufe, klasse)
    local fn = St.untertitelPraefix
    if type(fn) == "function" and fn ~= untertitelPraefix then
        local ok, p = pcall(fn, stufe, klasse)
        if ok and type(p) == "string" then return p end
    end
    return untertitelPraefix(stufe, klasse)
end

local leisteTicker
local function untertitel(str, stufe, klasse)
    if not str or str == "" then return end
    St.leisteLayout()
    text:SetText(praefix(stufe, klasse) .. str)   -- W7: ueber St.untertitelPraefix ersetzbar
    local h = (text:GetStringHeight() or St.SCHRIFT) + 20
    leiste:SetHeight(math.max(48, h))
    leiste:Show()
    if leisteTicker then leisteTicker:Cancel() end
    leisteTicker = ns.Compat.NewTicker(St.UNTERTITEL_DAUER, function() leisteTicker = nil; leiste:Hide() end, 1)
end
St.untertitel = untertitel

local function leisteAus()
    if leisteTicker then leisteTicker:Cancel(); leisteTicker = nil end
    leiste:Hide()
end

-- ---------------------------------------------------------------- Schalter
local function anwenden()
    local an = ns.Get("streamer") and true or false
    ns.streamerAnrede = an or nil
    ns.sexCache = nil
    chromaLayout()
    -- B-8: die Leiste haengt jetzt an "leiste", nicht mehr am Streamer-Schalter. Sie wird nur noch
    -- weggeraeumt, wenn sie gerade gar nicht laufen darf.
    if not St.leisteAn() then leisteAus() end
end
St.anwenden = anwenden

-- Wrapper: Blase (fertiger String) und onSetting (Layout nachziehen). Original wird gemerkt.
local gewrappt = false
local function wrappen()
    if gewrappt then return end
    gewrappt = true
    if ns.Blase and type(ns.Blase.zeige) == "function" then
        local origZeige = ns.Blase.zeige
        ns.Blase.zeige = function(str, dauer, klasse, stufe, ...)
            if St.leisteAn() and type(str) == "string" then
                pcall(untertitel, str, stufe, klasse)
            end
            return origZeige(str, dauer, klasse, stufe, ...)
        end
    end
    local origSetting = ns.onSetting
    ns.onSetting = function(key, value, ...)
        if origSetting then origSetting(key, value, ...) end
        if key == "streamer" or key == "leiste" then anwenden()
        elseif key == "scale" or key == "pos" or key == "versteckt" or key == "ansicht" or key == "groesse" then chromaLayout() end
    end
    -- B-8: bei einem UI-Scale-Wechsel zieht die Leiste mit (Breite 0,6 x Bildschirm, Schrift + 6).
    if ns.Optik and ns.Optik.beiSchrift then
        ns.Optik.beiSchrift(function()
            St.leisteLayout()
            if not St.leisteAn() then leisteAus() end
        end)
    end
    local g = gestalt()
    if g and g.HookScript then
        pcall(g.HookScript, g, "OnShow", chromaLayout)
        pcall(g.HookScript, g, "OnHide", function() chroma:Hide() end)
    end
end

ns.on("PLAYER_LOGIN", function()
    wrappen()
    St.leisteLayout()
    anwenden()
end)
ns.on("PLAYER_ENTERING_WORLD", function() ns.Compat.After(1.5, chromaLayout) end)
ns.on("DISPLAY_SIZE_CHANGED", function() St.leisteLayout() end)

function St.stand()
    return ns.Get("streamer"), chroma:IsShown(), leiste:IsShown(), gewrappt, St.leisteAn(), St.kachelRund
end
