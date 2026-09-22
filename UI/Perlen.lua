-- UI/Perlen.lua — Hover-Leiste "Perlen" (W16v, 22.09.2026, docs/welle16v-2026-09-22.md).
-- Ersetzt die Belegungsliste im Tooltip der Gestalt (Gestalt/Gestalt.lua OnEnter): vier runde
-- Knoepfe, die dieselben vier Funktionen aufrufen wie heute Rechtsklick/Shift-Rechtsklick/Mitte
-- (Gespraech, Menue, Still-Modus) plus Einstellungen direkt (bisher nur ein Fallback-Zweig in
-- derselben Rechtsklick-Kette). Siehe G.aktionGespraech/aktionMenue/aktionEinstellungen/aktionStill
-- in Gestalt/Gestalt.lua - EINE Stelle entscheidet, was ein Klick bedeutet, diese Datei ruft nur.
--
-- OFFEN-HARALD.md 23:15/23:20 (Haralds Korrekturen):
--   * ANCHOR_TOP am Tooltip verdeckt Portrait/Figur; seitlich sitzt die Blase. Deshalb keine
--     eigene Leiste "neben" der Gestalt, sondern AUF ihr: im Portrait als vier Perlen auf dem
--     unteren Ringbogen, in der Figur als Reihe mittig unter den Fuessen (seit 0.19.1; vorher
--     "aussen neben dem Rahmen" - und damit am Bildschirmrand unsichtbar).
--   * Die Blase gewinnt IMMER: Gestalt/Blase.lua ruft ns.Perlen.blaseGewinnt() beim tatsaechlichen
--     Erscheinen einer Zeile (zeigeJetzt), die Leiste blendet dann sofort aus.
--   * Erst nach 0,3 s (kein Zucken bei einer durchquerenden Maus), verschwindet 0,5 s nach dem
--     Verlassen von Gestalt UND Leiste (wer von der Gestalt auf die Leiste wandert, verliert sie
--     nicht mittendrin).
--
-- Nie im Kampf (PLAYER_REGEN_DISABLED blendet sofort aus, erlaubt() prueft zusaetzlich bei jedem
-- Zeigen-Versuch), nie waehrend "versteckt", nie ohne das Haekchen "Hover-Leiste" (Default an,
-- DEFAULTS_ACCOUNT-Eintrag steht in Gestalt/Gestalt.lua - Core/Init.lua bleibt unberuehrt).
-- Kein GameTooltip fuer den Namen: ein eigener kleiner Text (design-v3-Hausregel A-4/Optik).
-- Kein neues Bild: Perlen bestehen aus den schon ausgelieferten bilder/portrait_scheibe.png und
-- bilder/portrait_ring2.png (dieselben Texturen wie der Gestalt-Ring). Keine Tastatur, kein
-- Mausrad - nur Klick, wie der Rest der Gestalt-Bedienung.
-- API: CreateFrame, Texture:SetTexture/SetVertexColor, C_Timer (ueber ns.Compat), GameFont-Text
-- ueber ns.Optik. Nichts Fremdes.
local ADDON, ns = ...
local P = {}
ns.Perlen = P

-- Vier Aktionen in fester Reihenfolge. name = ns.L-Schluessel fuer den Berühren-Text.
-- "Menu"/"Menü" ist ein NEUER Locale-Schluessel (Merge-Baustein im Bericht) - die drei anderen
-- bestehen schon (Ask me/Frag mich, Settings/Einstellungen, Quiet mode/Still-Modus) und werden
-- unveraendert wiederverwendet, damit derselbe Begriff ueberall im Addon dasselbe meint.
P.AKTIONEN = {
    { ziffer = "1", name = "Ask me",     tu = function() if ns.Gestalt and ns.Gestalt.aktionGespraech then ns.Gestalt.aktionGespraech() end end },
    { ziffer = "2", name = "Menu",       tu = function() if ns.Gestalt and ns.Gestalt.aktionMenue then ns.Gestalt.aktionMenue() end end },
    { ziffer = "3", name = "Settings",   tu = function() if ns.Gestalt and ns.Gestalt.aktionEinstellungen then ns.Gestalt.aktionEinstellungen() end end },
    { ziffer = "4", name = "Quiet mode", tu = function() if ns.Gestalt and ns.Gestalt.aktionStill then ns.Gestalt.aktionStill() end end },
}

P.PERLE_GROESSE = 22
P.PERLE_ABSTAND = 6
P.ZEIGEN_VERZUG = 0.3
P.VERSTECKEN_VERZUG = 0.5

-- ---------------------------------------------------------------------------------------------
-- Rahmen: eine Leiste (unsichtbarer Traeger) mit vier Perlen-Buttons, plus ein eigener kleiner
-- Name-Text (kein GameTooltip). Alles einmal beim Laden gebaut, danach nur verschoben/gefaerbt.
-- ---------------------------------------------------------------------------------------------
-- WICHTIG: "leiste" selbst bleibt maus-UNBETEILIGT. Sie ist nur der Show/Hide-Behaelter fuer die
-- vier Perlen-Buttons (die haengen unten an SIE als Parent, werden aber per SetPoint einzeln auf
-- G.frame ausgerichtet - Parent und Position sind in WoW getrennte Dinge). Eine maus-aktive
-- Flaeche in der Groesse von G.frame, die UEBER ihr liegt (hoeherer FrameLevel, siehe unten),
-- wuerde G.frame jeden Klick/Drag/Rechtsklick wegschnappen, ueberall dort, wo sie ueberlappen -
-- also praktisch ueberall. Nur die vier kleinen Buttons unten sind maus-aktiv.
local leiste = CreateFrame("Frame", nil, UIParent)
leiste:SetFrameStrata("MEDIUM")
leiste:SetFrameLevel(15)
leiste:Hide()
P.frame = leiste

local nameFrame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
nameFrame:SetFrameStrata("TOOLTIP")
nameFrame:Hide()
local nameText = nameFrame:CreateFontString(nil, "OVERLAY")
nameText:SetPoint("CENTER", 0, 0)
P.nameFrame, P.nameText = nameFrame, nameText

local RING_PFAD = ns.PFAD .. "bilder\\portrait_ring2.png"
local SCHEIBE_PFAD = ns.PFAD .. "bilder\\portrait_scheibe.png"

local perlen = {}
for i, eintrag in ipairs(P.AKTIONEN) do
    local b = CreateFrame("Button", nil, leiste)
    b:SetSize(P.PERLE_GROESSE, P.PERLE_GROESSE)
    b:RegisterForClicks("LeftButtonUp")

    local scheibe = b:CreateTexture(nil, "ARTWORK")
    scheibe:SetAllPoints(b)
    pcall(scheibe.SetTexture, scheibe, SCHEIBE_PFAD)

    local ring = b:CreateTexture(nil, "OVERLAY")
    ring:SetAllPoints(b)
    pcall(ring.SetTexture, ring, RING_PFAD)

    local ziffer = b:CreateFontString(nil, "OVERLAY")
    ziffer:SetPoint("CENTER", 0, 0)

    b.scheibe, b.ring, b.ziffer, b.eintrag = scheibe, ring, ziffer, eintrag
    b:SetScript("OnClick", eintrag.tu)
    perlen[i] = b
end
P.perlen = perlen

-- Ring/Ziffer faerben: Ruhe = Lyras Violett (ns.Optik.LILA, Rueckfall auf den festen Wert aus
-- Gestalt.lua), Hover heller/weiss. Bei Stufe-4 (Still-Modus) zusaetzlich ein Hinweis, ob er
-- schon an ist - kein neues Bild, nur eine andere Faerbung.
local function farbeRuhe()
    if ns.Optik and ns.Optik.LILA then return ns.Optik.LILA end
    return { 0.706, 0.549, 1.0 }
end

local function perleFaerben(b, hover)
    local c = hover and { 1, 1, 1 } or farbeRuhe()
    pcall(b.ring.SetVertexColor, b.ring, c[1], c[2], c[3], 1)
    if ns.Optik and ns.Optik.setzeText then
        ns.Optik.setzeText(b.ziffer, b.eintrag.ziffer, 11, hover and { 1, 1, 1 } or (ns.Optik.farben and ns.Optik.farben().text))
    else
        pcall(b.ziffer.SetText, b.ziffer, b.eintrag.ziffer)
    end
    -- Aktiver Still-Modus: die vierte Perle bleibt voll deckend, auch ohne Hover - "es ist
    -- schon an" ist eine Auskunft ueber den Zustand, keine zweite Farbwahl.
    local aktiv = (b.eintrag.name == "Quiet mode") and ns.stillModus and not hover
    pcall(b.scheibe.SetVertexColor, b.scheibe, 1, 1, 1, aktiv and 1 or 0.9)
end

-- ---------------------------------------------------------------------------------------------
-- Name-Text ueber der beruehrten Perle. Eigener kleiner Text, kein GameTooltip.
-- ---------------------------------------------------------------------------------------------
local function nameZeigen(b)
    if not (ns.Optik and ns.Optik.setzeText) then return end
    local text = ns.L and ns.L[b.eintrag.name] or b.eintrag.name
    ns.Optik.setzeText(nameText, text, 11)
    local w = (nameText.GetStringWidth and nameText:GetStringWidth()) or 40
    nameFrame:SetSize(w + 16, 20)
    if ns.Optik.panel then ns.Optik.panel(nameFrame) end
    nameFrame:ClearAllPoints()
    nameFrame:SetPoint("BOTTOM", b, "TOP", 0, 4)
    nameFrame:Show()
end
local function nameVerstecken()
    nameFrame:Hide()
end

-- ---------------------------------------------------------------------------------------------
-- Sichtbarkeits-Zustandsmaschine: "ueber Gestalt oder Leiste" -> nach 0,3 s zeigen; "ueber
-- keinem von beiden" -> nach 0,5 s verstecken. Blase/Kampf/Haekchen koennen jederzeit sofort
-- dazwischenfahren (blaseGewinnt, PLAYER_REGEN_DISABLED, ns.onSetting-Hook in Gestalt.lua).
-- ---------------------------------------------------------------------------------------------
local ueberGestalt, ueberLeiste = false, false
local sichtbar = false
local zeigenTimer, versteckenTimer

local function erlaubt()
    if ns.Get and ns.Get("hoverLeiste") == false then return false end
    if ns.Get and ns.Get("versteckt") then return false end
    if ns.Regie and ns.Regie.imKampf then return false end
    if ns.Blase and ns.Blase.sichtbar and ns.Blase.sichtbar() then return false end
    local G = ns.Gestalt
    if not (G and G.frame and G.frame.IsShown and G.frame:IsShown()) then return false end
    return true
end

-- Layout: Portrait -> vier Perlen auf dem unteren Ringbogen (Winkel -60/-20/20/60 Grad von der
-- Senkrechten, Radius = halbe Kante -> sie sitzen GENAU auf dem Ring, wie Perlen aufgefaedelt).
-- Figur -> eine waagrechte Reihe mittig unter den Fuessen, innerhalb des Rahmens (s. layoutFigur).
local function layoutPortrait(G)
    local kante = (G.portraitKante and G.portraitKante()) or G.frame:GetWidth() or 112
    local r = kante / 2
    local winkel = { -60, -20, 20, 60 }
    for i, b in ipairs(perlen) do
        local rad = math.rad(winkel[i])
        local x = r * math.sin(rad)
        local y = -r * math.cos(rad)
        b:ClearAllPoints()
        b:SetPoint("CENTER", G.frame, "CENTER", x, y)
    end
end

-- FIX 0.19.1 (Spieltest 22.09.): die Reihe lag NEBEN dem Rahmen (BOTTOMLEFT/BOTTOMRIGHT
-- nach aussen). Steht die Figur am Bildschirmrand - und dort steht sie fast immer, links oben
-- ist die Voreinstellung -, liegt "aussen" ausserhalb des Bildschirms: die Perlen kamen nie.
-- Jetzt sitzt die Reihe UNTER DEN FUESSEN, mittig auf der Unterkante des Rahmens (die Fussli-
-- nie liegt 12/512 der Hoehe darueber, Gestalt.lua optikNachfuehren) und damit INNERHALB des
-- geklemmten Rahmens - sichtbar an jedem Rand. Die Blase weicht in der Figur nach oben oder
-- auf halbe Hoehe zur Seite aus, nie auf die Fusslinie; die Kollision, vor der "aussen"
-- schuetzen sollte, gibt es dort nicht.
local function layoutFigur(G)
    local schritt = P.PERLE_GROESSE + P.PERLE_ABSTAND
    local n = #perlen
    for i, b in ipairs(perlen) do
        b:ClearAllPoints()
        local x = (i - (n + 1) / 2) * schritt
        b:SetPoint("CENTER", G.frame, "BOTTOM", x, P.PERLE_GROESSE / 2 - 4)
    end
end

local function layout()
    local G = ns.Gestalt
    if not (G and G.frame) then return end
    leiste:ClearAllPoints()
    leiste:SetAllPoints(G.frame)   -- reiner Traeger, die Perlen haengen selbst an G.frame
    if G.istPortrait and G.istPortrait() then layoutPortrait(G) else layoutFigur(G) end
    for _, b in ipairs(perlen) do perleFaerben(b, false) end
end

local function zeigenJetzt()
    if not erlaubt() then return end
    layout()
    leiste:Show()
    for _, b in ipairs(perlen) do b:Show() end
    sichtbar = true
end

local function verstecktJetzt()
    sichtbar = false
    leiste:Hide()
    nameVerstecken()
end

local function timerAbbrechen()
    if zeigenTimer then zeigenTimer:Cancel(); zeigenTimer = nil end
    if versteckenTimer then versteckenTimer:Cancel(); versteckenTimer = nil end
end

local function aktualisieren()
    if ueberGestalt or ueberLeiste then
        if versteckenTimer then versteckenTimer:Cancel(); versteckenTimer = nil end
        if not sichtbar and not zeigenTimer then
            zeigenTimer = ns.Compat.NewTicker(P.ZEIGEN_VERZUG, function()
                zeigenTimer = nil
                if ueberGestalt or ueberLeiste then zeigenJetzt() end
            end, 1)
        end
    else
        if zeigenTimer then zeigenTimer:Cancel(); zeigenTimer = nil end
        if sichtbar and not versteckenTimer then
            versteckenTimer = ns.Compat.NewTicker(P.VERSTECKEN_VERZUG, function()
                versteckenTimer = nil
                if not (ueberGestalt or ueberLeiste) then verstecktJetzt() end
            end, 1)
        end
    end
end

-- Aufruf aus Gestalt/Gestalt.lua OnEnter/OnLeave (existenzgeprueft dort).
function P.ueberGestalt(an)
    ueberGestalt = an and true or false
    aktualisieren()
end

-- "Blase gewinnt immer": sofortiges Aus, keine 0,5-s-Gnadenfrist. Aufgerufen aus
-- Gestalt/Blase.lua zeigeJetzt() in dem Moment, in dem wirklich eine Zeile erscheint.
function P.blaseGewinnt()
    timerAbbrechen()
    if sichtbar then verstecktJetzt() end
end

-- Haekchen "Hover-Leiste" aus, waehrend sie steht: Gestalt/Gestalt.lua ruft das aus ns.onSetting.
function P.verstecken()
    timerAbbrechen()
    ueberGestalt, ueberLeiste = false, false
    if sichtbar then verstecktJetzt() end
end

-- Nie im Kampf: sofortiges Aus, kein Warten auf OnLeave (das Mausrad kann ja mitten im Kampf
-- ueber Lyra stehen bleiben, waehrend der Spieler kaempft).
if ns.on then
    ns.on("PLAYER_REGEN_DISABLED", function()
        timerAbbrechen()
        if sichtbar then verstecktJetzt() end
    end)
end

-- Jede Perle traegt "ueberLeiste" selbst: OnEnter setzt true, OnLeave setzt false. Wandert die
-- Maus von einer Perle zur naechsten, liegen dazwischen ein paar Millisekunden mit false - das
-- stoert nicht, weil aktualisieren() den Versteck-Timer erst nach 0,5 s wirklich feuert und die
-- naechste Perle ihn laengst wieder abgebrochen hat (Auftrag: "0,5 s nach OnLeave von Gestalt
-- UND Leiste" - der Timer, nicht ein Flag, traegt die 0,5 s).
-- FIX 0.20.0 (Spieltest Harald 22.09.): steht die Maus geometrisch auf einer sichtbaren Perle?
-- Gestalt/Gestalt.lua fragt das in seinem OnLeave, damit der Wechsel Figur -> Perle nicht als
-- "Maus weg" zaehlt (das Zittern der Figur beim Hovern ueber die Perlen). IsMouseOver ist eine
-- reine Rechteckpruefung gegen den Cursor und haengt nicht an der Reihenfolge der Maus-
-- Ereignisse; im Pruefstand fehlt sie - dann false, und alles verhaelt sich wie vor dem Fix.
function P.mausUeberPerle()
    if not sichtbar then return false end
    for _, b in ipairs(perlen) do
        local ok, drauf = pcall(function() return b:IsMouseOver() end)
        if ok and drauf then return true end
    end
    return false
end

for i, b in ipairs(perlen) do
    b:SetScript("OnEnter", function()
        ueberLeiste = true
        aktualisieren()
        perleFaerben(b, true)
        nameZeigen(b)
    end)
    b:SetScript("OnLeave", function()
        ueberLeiste = false
        aktualisieren()
        perleFaerben(b, false)
        nameVerstecken()
        -- FIX 0.20.0: von der Perle nach DRAUSSEN (nicht auf die Figur, nicht auf die naechste
        -- Perle) - dann ist der Hover der Gestalt wirklich zu Ende. Kurz verzoegert, damit die
        -- Rechteckpruefung den neuen Cursorstand sieht.
        ns.Compat.After(0.05, function()
            local G = ns.Gestalt
            if not (G and G.hoverEnde and G.hoverLaeuft and G.hoverLaeuft()) then return end
            local aufFigur = false
            pcall(function() aufFigur = G.frame:IsMouseOver() and true or false end)
            if not aufFigur and not P.mausUeberPerle() then G.hoverEnde() end
        end)
    end)
end
