-- UI/Optik.lua — EINE Optik fuer Blase, Menue, Dialog, Tooltip, Untertitel (design-v3 A).
-- Dunkles Lila-Panel, heller Text, Lyras Violett #b48cff als Rand/Akzent, Gold fuer Ziffern.
-- Alle Werte WCAG-gerechnet (docs/fix3-2026-09-17.md, docs/design-v3.md): Text 15,7:1, Antwort 10,7:1.
-- Kontrast-Modus: reines Schwarz/Weiss. Dazu ein rundes Portrait (TexCoord + Blizzard-Maske + Ring)
-- als wiederverwendbarer Baustein fuer Dialogfenster und Menue.
-- FIX5 (17.09.2026): O.schrift faellt auf ein Blizzard-Schriftobjekt zurueck, und O.setzeText ist
-- ab jetzt der EINZIGE Weg, Text in eine vorlagenlose FontString zu schreiben - erst Schrift, dann
-- Text. Grund: eine FontString ohne Schrift wirft bei SetText einen harten Lua-Fehler und riss
-- damit das ganze Menue mit (docs/fix5-2026-09-17.md).
-- API: SetBackdrop (BackdropTemplate), CreateMaskTexture/AddMaskTexture (guarded), SetTexCoord.
-- DESIGN-V3 Team B (17.09.2026):
--   B-1  O.schriftgroesse() kennt schrift = "auto" -> clamp(round(22 / UIParent:GetEffectiveScale()), 10, 28).
--        Neu gerechnet bei UI_SCALE_CHANGED / DISPLAY_SIZE_CHANGED / CVAR_UPDATE(uiScale|useUiScale);
--        danach O.neuZeichnen(), das jede angemeldete Flaeche neu bemisst.
--   B-2  Menue-Titel #E8DCFF (7,21:1 -> 13,79:1), Panel deckend (0,96 -> 1,00),
--        O.TOOLTIP_HINWEIS 0,88 statt 0,82 (8,97:1 -> 10,41:1).
--   B-3  O.einblenden(frame): Alpha 0 -> 1 in 0,08 s. NUR Alpha - kein Scale, keine Translation.
--   B-7  O.freieSeite(breite, hoehe) prueft jetzt gegen echte Hindernisse (Questie, Minimap, Chat,
--        Details); O.positionVorschlag() liefert einen freien Platz fuer die Gestalt.
local ADDON, ns = ...
local O = {}
ns.Optik = O

O.LILA = { 0.706, 0.549, 1.0 }              -- #b48cff
O.GOLD = { 1.0, 0.82, 0.0 }
O.TOOLTIP_HINWEIS = { 0.88, 0.88, 0.88 }    -- B-2: Hinweiszeilen im Gestalt-Tooltip (war 0.82)
O.FARBEN = {
    normal = {
        panel    = { 0.07, 0.04, 0.13, 1.00 },   -- B-2: deckend. 0,96 liess das Spielbild durchscheinen.
        rand     = { 0.70, 0.55, 1.00, 0.90 },
        text     = { 0.95, 0.93, 1.00 },
        titel    = { 0.910, 0.863, 1.00 },       -- B-2: #E8DCFF - 13,79:1 statt 7,21:1
        knopf    = { 0.12, 0.08, 0.20, 1 },
        knopfH   = { 0.24, 0.17, 0.38, 1 },
        antwort  = { 0.85, 0.75, 1.00 },
        antwortH = { 1.00, 1.00, 1.00 },
        ziffer   = { 1.00, 0.82, 0.00 },
        zifferH  = { 1.00, 0.90, 0.40 },
        linie    = { 0.706, 0.549, 1.0, 0.35 },
        warn     = { 1.00, 0.55, 0.45 },         -- Stufe 2/3: Rand + Praefix
    },
    kontrast = {
        panel = { 0, 0, 0, 1 }, rand = { 1, 1, 1, 1 }, text = { 1, 1, 1 }, titel = { 1, 1, 1 },
        knopf = { 0, 0, 0, 1 }, knopfH = { 1, 1, 1, 1 }, antwort = { 1, 1, 1 }, antwortH = { 0, 0, 0 },
        ziffer = { 1, 1, 1 }, zifferH = { 0, 0, 0 }, linie = { 1, 1, 1, 0.6 }, warn = { 1, 0.7, 0.7 },
    },
}
function O.farben() return ns.Get("kontrast") and O.FARBEN.kontrast or O.FARBEN.normal end

-- ---------------------------------------------------------------------------------------------
-- B-1  Schriftgroesse
-- Ein fester Wert in UI-Einheiten ist auf jedem Bildschirm eine andere Groesse: bei
-- GetEffectiveScale 0,64 sind 16 Einheiten 10 Bildschirm-Pixel, bei 1,9 sind es 30.
-- "auto" dreht die Rechnung um: ZIEL_PX Bildschirm-Pixel sind das Mass, die UI-Einheiten folgen.
-- Der Slider bleibt und uebersteuert (jeder Zahlenwert gewinnt gegen "auto").
-- ---------------------------------------------------------------------------------------------
O.ZIEL_PX = 22          -- Bildschirm-Pixel fuer den Fliesstext
O.MIN, O.MAX = 10, 28
local autoCache

function O.schriftAuto() return ns.Get("schrift") == "auto" end

-- W6 (Recherche 10, A3): Im Barrierefrei-Modus ist O.MIN keine sinnvolle Untergrenze mehr.
-- Sinne/Welle6.lua schreibt beim Einschalten eine Zahl in "schrift" - wer danach wieder auf
-- "auto" stellt, landete sonst bei einem sehr grossen UI-Scale wieder bei 10 Einheiten, und
-- genau das war der Grund, den Modus einzuschalten. Die Grenze wandert also mit, statt die
-- Entscheidung des Spielers ("auto") zu verbieten.
O.BF_MIN = 20
function O.untergrenze()
    local W6 = ns.Welle6
    if W6 and W6.an and W6.an("barrierefrei") then return O.BF_MIN end
    return O.MIN
end

-- Die eigentliche Formel. Unsinnige Skalierungen (0, nil, 12) werden auf 1 gezogen.
function O.autoGroesse()
    local e = 1
    if UIParent and UIParent.GetEffectiveScale then
        local ok, v = pcall(UIParent.GetEffectiveScale, UIParent)
        if ok and type(v) == "number" then e = v end
    end
    if not (e > 0.2 and e < 5) then e = 1 end
    local n = math.floor(O.ZIEL_PX / e + 0.5)
    local min = O.untergrenze()         -- W6
    return (n < min and min) or (n > O.MAX and O.MAX) or n
end

function O.schriftgroesse()
    local s = ns.Get("schrift")
    local min = O.untergrenze()         -- W6
    if s == "auto" then
        if not autoCache then autoCache = O.autoGroesse() end
        return (autoCache < min) and min or autoCache
    end
    local n = tonumber(s) or 16
    if n < min then n = min elseif n > O.MAX then n = O.MAX end
    return n
end

-- Flaechen, die sich nach einer Schriftaenderung neu bemessen muessen (Menue, Dialog, Leiste).
-- Die Blase haengt schon an ns.onSetting; sie wird hier zusaetzlich angestossen, weil ein
-- UI_SCALE_CHANGED kein Set ist.
O.schriftHooks = {}
function O.beiSchrift(fn)
    if type(fn) == "function" then O.schriftHooks[#O.schriftHooks + 1] = fn end
end
function O.neuZeichnen()
    autoCache = nil
    for i = 1, #O.schriftHooks do pcall(O.schriftHooks[i]) end
    if ns.Blase and ns.Blase.layout then pcall(ns.Blase.layout) end
end

if ns.on then
    ns.on("UI_SCALE_CHANGED", function() O.neuZeichnen() end)
    ns.on("DISPLAY_SIZE_CHANGED", function() O.neuZeichnen() end)
    -- CVAR_UPDATE feuert fuer JEDE CVar - nur die beiden Skalierungs-CVars zaehlen.
    ns.on("CVAR_UPDATE", function(name)
        local n = type(name) == "string" and name:lower() or ""
        if n == "uiscale" or n == "useuiscale" then O.neuZeichnen() end
    end)
end

-- Panel-Backdrop. DESIGN-V3 B-2 / A-4 / P1-7 (17.09.2026): dieselbe Kachel wie die Blase.
-- Bis 0.6.1 standen Menue und Dialog auf "UI-Tooltip-Border" - belegt und funktionierend, aber es
-- sah aus wie ein Tooltip und nicht wie Lyra, und die Blase sah wieder anders aus. Jetzt: ein Rand,
-- drei Fenster. bilder/blase_kachel.png ist 512 x 64 = acht Zellen a 64 (WoW liest eine edgeFile
-- als acht gleich breite Spalten ueber die volle Hoehe; bei 256 x 64 wuerde jede Ecke gequetscht).
-- Die Kachel bringt ihre Farbe und einen weichen dunklen Aussenschatten selbst mit - deshalb
-- bleibt SetBackdropBorderColor auf Weiss, und der Rand wird NICHT nach Warnstufe eingefaerbt
-- (design-v3 Befund 3: Farbe allein traegt die Stufe nicht, sie erreicht 1,01:1 gegen #b48cff).
-- edgeSize 14 / insets 5 sind aus Gestalt/Blase.lua (B.BACKDROP) abgeschrieben, damit es eine Zahl
-- und nicht zwei gibt. Prueffpunkt 20: laedt WoW eine eigene PNG als edgeFile sauber?
-- Wenn nicht, ist der Rueckfall ein Einzeiler (edgeFile auf UI-Tooltip-Border, insets 3).
O.BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = ns.PFAD .. "bilder\\blase_kachel.png",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
}
function O.panel(frame, warn)
    if not frame or not frame.SetBackdrop then return end
    local c = O.farben()
    pcall(frame.SetBackdrop, frame, O.BACKDROP)
    pcall(frame.SetBackdropColor, frame, c.panel[1], c.panel[2], c.panel[3], c.panel[4])
    -- Die eigene Kachel bringt ihre Randfarbe mit: im Normalfall Weiss darueber, damit sie
    -- unverfaelscht durchkommt. Nur der Kontrast-Modus faerbt weiter (dort ist Weiss die Ansage),
    -- und "warn" bleibt als Schalter erhalten, wird aber von Menue/Dialog nicht mehr benutzt -
    -- die Warnstufe geht ueber Icon, Ring und Halo (design-v3 Befund 3), nicht ueber den Rand.
    local r = warn and c.warn or (ns.Get("kontrast") and c.rand) or { 1, 1, 1, 1 }
    pcall(frame.SetBackdropBorderColor, frame, r[1], r[2], r[3], r[4] or 1)
end

-- Schrift: STANDARD_TEXT_FONT (Locale-sicher), Umriss nur im Kontrast-Modus, weicher Schatten sonst.
-- FIX5 (17.09.2026): Der Aufruf war mit pcall geschuetzt - und genau das war die Falle. Schlaegt
-- SetFont fehl, BLEIBT die FontString ohne Schrift, und der naechste SetText wirft dann einen
-- HARTEN Lua-Fehler "FontString:SetText(): Font not set", der die aufrufende Funktion abbricht.
-- Deshalb hier ein Netz: ohne gueltige Schrift wird ein Blizzard-Schriftobjekt gesetzt.
-- Rueckgabe: true, wenn die FontString danach nachweislich eine Schrift hat.
function O.schrift(fs, groesse, farbe)
    if not fs then return false end
    local flags = ns.Get("kontrast") and "OUTLINE" or ""
    pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, groesse or O.schriftgroesse(), flags)
    if not O.hatSchrift(fs) then
        -- Rueckfall 1: Blizzards eigene Schriftobjekte (existieren in Era immer)
        local vorlage = GameFontHighlightSmall or GameFontNormal or GameFontNormalSmall
        if fs.SetFontObject and vorlage then pcall(fs.SetFontObject, fs, vorlage) end
    end
    if not O.hatSchrift(fs) then
        -- Rueckfall 2: der Pfad hart, ohne Flags
        pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", groesse or O.schriftgroesse(), "")
    end
    if fs.SetShadowOffset then
        pcall(fs.SetShadowOffset, fs, ns.Get("kontrast") and 0 or 1, ns.Get("kontrast") and 0 or -1)
        if fs.SetShadowColor then pcall(fs.SetShadowColor, fs, 0, 0, 0, 0.6) end
    end
    local c = farbe or O.farben().text
    pcall(fs.SetTextColor, fs, c[1], c[2], c[3])
    return O.hatSchrift(fs)
end

-- Hat die FontString eine Schrift? GetFont() liefert ohne Schrift nichts (Era 1.15.9).
function O.hatSchrift(fs)
    if not (fs and fs.GetFont) then return false end
    local ok, pfad = pcall(fs.GetFont, fs)
    return (ok and pfad ~= nil and pfad ~= "") and true or false
end

-- IMMER erst die Schrift, dann der Text. Das ist die einzige Stelle, an der Menue/Dialog Text in
-- eine FontString schreiben, die nicht aus einer Blizzard-Vorlage stammt (FIX5).
function O.setzeText(fs, str, groesse, farbe)
    if not fs then return false end
    O.schrift(fs, groesse, farbe)
    local ok = pcall(fs.SetText, fs, str or "")
    if not ok then ns.debug("Optik: SetText fehlgeschlagen (" .. tostring(str) .. ")") end
    return ok
end

-- ---------------------------------------------------------------------------------------------
-- B-3  Weiche Oeffnung: Alpha 0 -> 1 in 0,08 s. KEIN Scale, KEINE Translation (Hausregel seit FIX1:
-- eine Scale-Animation auf einem Frame, dessen Anker der Spieler zieht, driftet - docs/fix1).
-- Geschlossen wird weiterhin hart mit Hide(): "offen" ist im ganzen Addon (und im Pruefstand)
-- als frame:IsShown() definiert; ein Ausblenden ueber 0,12 s wuerde diesen Zustand fuer 0,12 s
-- zweideutig machen. Das ist bewusst nicht gebaut, siehe docs/design-v3-B-umsetzung.md.
-- Sicherheitsnetz: feuert OnFinished nicht (alter Client, fehlende API), zieht ein Timer die
-- Deckkraft 0,1 s spaeter von Hand auf 1 - ein unsichtbares Menue waere derselbe Fehlertyp
-- wie "Font not set" aus FIX5.
-- ---------------------------------------------------------------------------------------------
O.EIN_DAUER = 0.08

-- Die Gruppen liegen in einer eigenen Tabelle, NICHT als Feld auf dem Frame: ein fremdes
-- Frame-Metatable (oder ein anderes Addon) darf uns hier nicht dazwischenfunken, und ein
-- "frame.irgendwas ~= nil" ist auf einem fremden Objekt keine verlaessliche Aussage.
-- Schwache Schluessel, damit ein Frame nicht wegen uns am Leben bleibt.
O.einGruppen = setmetatable({}, { __mode = "k" })

local function einGruppe(frame)
    -- P1-5: NIE vom Typ eines fremden Feldes abhaengen. Gueltig gecacht ist nur eine Tabelle
    -- (die Gruppe) oder genau false ("haben wir versucht, gibt es nicht"). Alles andere - auch
    -- eine Funktion, die ein fremdes Metatable fuer unbekannte Schluessel liefert - zaehlt als
    -- "noch nicht gebaut". Genau dieser Fehlertyp hat in 0.6.0 das Menue gekostet.
    local vorhanden = O.einGruppen[frame]
    if type(vorhanden) == "table" or vorhanden == false then return vorhanden end
    local ergebnis = false
    if frame.CreateAnimationGroup then
        local ok, g = pcall(frame.CreateAnimationGroup, frame)
        if ok and g and g.CreateAnimation then
            local ok2 = pcall(function()
                local a = g:CreateAnimation("Alpha")
                if not (a and a.SetFromAlpha and a.SetToAlpha and a.SetDuration) then error("keine Alpha-API") end
                a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(O.EIN_DAUER)
                if a.SetOrder then a:SetOrder(1) end
                if g.SetLooping then g:SetLooping("NONE") end
                if g.SetScript then
                    g:SetScript("OnFinished", function() pcall(frame.SetAlpha, frame, 1) end)
                    g:SetScript("OnStop", function() pcall(frame.SetAlpha, frame, 1) end)
                end
            end)
            if ok2 then ergebnis = g end
        end
    end
    O.einGruppen[frame] = ergebnis
    return ergebnis
end

function O.einblenden(frame)
    if not (frame and frame.Show) then return false end
    local g = einGruppe(frame)
    if type(g) ~= "table" then
        pcall(frame.SetAlpha, frame, 1)
        frame:Show()
        return false
    end
    pcall(function() if g.IsPlaying and g:IsPlaying() then g:Stop() end end)
    pcall(frame.SetAlpha, frame, 0)
    frame:Show()
    if not pcall(g.Play, g) then pcall(frame.SetAlpha, frame, 1); return false end
    if ns.Compat and ns.Compat.After then
        ns.Compat.After(O.EIN_DAUER + 0.1, function()
            if frame:IsShown() then pcall(frame.SetAlpha, frame, 1) end
        end)
    end
    return true
end

function O.flaeche(tex, c)
    if not tex or not c then return end
    if tex.SetColorTexture then tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    else pcall(tex.SetTexture, tex, c[1], c[2], c[3], c[4] or 1) end
end

-- Trennlinie 1 px in Lyras Violett
function O.trennlinie(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    O.flaeche(t, O.farben().linie)
    return t
end

-- Rundes Portrait fuer Dialog und Menue.
-- DESIGN-V3 A-1/b.2 (17.09.2026): Der Masken-Umweg ist auch hier weg. Bis 0.6.1 lief das kleine
-- Portrait ueber SetTexCoord (Fenster 104x104 ab 216,0) plus Blizzards TempPortraitAlphaMask -
-- und Maske und SetTexCoord vertragen sich in WoW nicht. Jetzt dieselbe Quelle wie die Gestalt:
-- bilder/rund/<miene>.png, 29 Stueck, 128 x 128, Scheibe und weicher Aussenschatten eingebacken,
-- der richtige Kopfanker je Miene schon beim Rendern gesetzt (tools/mach-rund-portraits.py).
-- Eine Zeile statt eines Zweigs, und der leere Ring aus Haralds Screenshot kann nicht wiederkommen.
O.RUND_ORDNER = ns.PFAD .. "bilder\\rund\\"
function O.portrait(parent, groesse)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(groesse, groesse)
    local tex = p:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(p)
    local ring = p:CreateTexture(nil, "OVERLAY")
    ring:SetAllPoints(p)
    ring:SetTexture(ns.PFAD .. "bilder\\portrait_ring2.png")
    ring:SetVertexColor(O.LILA[1], O.LILA[2], O.LILA[3], 1)
    local obj = { frame = p, tex = tex, ring = ring }
    function obj:miene(name)
        -- G.RUND ist die Whitelist der wirklich ausgelieferten runden Dateien und liegt in
        -- Gestalt/Gestalt.lua - EINE Stelle entscheidet, welche Datei eine Miene bekommt
        -- (design-v3 h.4: ein Bild, ueberall). Fehlt die Gestalt, gilt die Liste eben nicht.
        local G = ns.Gestalt
        if G and G.RUND and not G.RUND[name] then name = "neutral" end
        name = name or "neutral"
        tex:SetTexture(O.RUND_ORDNER .. name .. ".png")
        if tex.SetTexCoord then pcall(tex.SetTexCoord, tex, 0, 1, 0, 1) end
    end
    function obj:ringFarbe(c) ring:SetVertexColor(c[1], c[2], c[3], 1) end
    obj:miene("neutral")
    return obj
end

-- ---------------------------------------------------------------------------------------------
-- B-7  Hindernisse. Bis 0.6.1 entschied die Seite allein die Bildschirmhaelfte - das Menue konnte
-- also mitten in den Questie-Tracker klappen. Jetzt wird das Rechteck, das das Fenster einnehmen
-- wuerde, gegen die Frames geprueft, die tatsaechlich im Weg stehen. Alles ueber _G[name] und
-- pcall: keine harte Abhaengigkeit auf irgendein Fremd-Addon, fehlt der Frame, faellt er weg.
-- ---------------------------------------------------------------------------------------------
O.HINDERNIS = {
    "QuestWatchFrame", "QuestieTrackerFrame", "QuestieFrame", "ObjectiveTrackerFrame",
    "MinimapCluster", "Minimap", "ChatFrame1", "DetailsBaseFrame1",
}
O.UEBERLAPP = 0.15      -- ab 15 % Flaechenanteil gilt ein Platz als belegt

-- Rechteck (links, unten, Breite, Hoehe) eines Frames, oder nil, wenn er nicht sichtbar/messbar ist
function O.rechteck(f)
    if type(f) ~= "table" then return nil end
    local ok, sichtbar = pcall(function() return f.IsVisible and f:IsVisible() end)
    if not (ok and sichtbar) then return nil end
    if f.GetRect then
        local ok2, l, b, w, h = pcall(f.GetRect, f)
        if ok2 and type(l) == "number" and type(w) == "number" and w > 0 and h > 0 then return l, b, w, h end
    end
    local ok3, l, b, w, h = pcall(function()
        return f:GetLeft(), f:GetBottom(), f:GetWidth(), f:GetHeight()
    end)
    if ok3 and type(l) == "number" and type(b) == "number" and type(w) == "number" and type(h) == "number"
        and w > 0 and h > 0 then return l, b, w, h end
    return nil
end

local function schnitt(l1, b1, w1, h1, l2, b2, w2, h2)
    local x = math.min(l1 + w1, l2 + w2) - math.max(l1, l2)
    local y = math.min(b1 + h1, b2 + h2) - math.max(b1, b2)
    if x <= 0 or y <= 0 then return 0 end
    return x * y
end

-- Wie viel des Rechtecks liegt unter einem sichtbaren Hindernis? (0 .. 1, Hindernisse ueberlappen
-- sich gegenseitig - die Summe ist bewusst eine Obergrenze, kein exaktes Mass.)
function O.belegtAnteil(l, b, w, h)
    if not (l and b and w and h) or w <= 0 or h <= 0 then return 0 end
    local eigen = (ns.Gestalt and ns.Gestalt.frame) or nil
    local summe = 0
    for i = 1, #O.HINDERNIS do
        local f = rawget(_G, O.HINDERNIS[i])
        if f and f ~= eigen then
            local hl, hb, hw, hh = O.rechteck(f)
            if hl then summe = summe + schnitt(l, b, w, h, hl, hb, hw, hh) end
        end
    end
    return math.min(1, summe / (w * h))
end
function O.belegt(l, b, w, h) return O.belegtAnteil(l, b, w, h) > O.UEBERLAPP end

-- Seite mit mehr Platz neben der Gestalt: "LEFT" oder "RIGHT" (fuer Menue/Dialog/Blase).
-- breite/hoehe = Mass des Fensters, das dort stehen soll; ohne Angabe ein Dialog-Mass.
-- Eine Funktion, drei Nutzer (design-v3 e.5).
function O.freieSeite(breite, hoehe)
    local g = ns.Gestalt and ns.Gestalt.frame
    local schirm = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
    if not (g and g.GetCenter) then return "RIGHT" end
    local ok, x, y = pcall(g.GetCenter, g)
    if not (ok and x) then return "RIGHT" end
    local wunsch = (x > schirm / 2) and "LEFT" or "RIGHT"
    local andere = (wunsch == "LEFT") and "RIGHT" or "LEFT"
    breite = tonumber(breite) or 380
    hoehe  = tonumber(hoehe) or 200
    local gl, gb, gw, gh = O.rechteck(g)
    if not gl then return wunsch end
    local function platz(seite)
        local b = (y or (gb + gh / 2)) - hoehe / 2
        if seite == "RIGHT" then return gl + gw + 8, b, breite, hoehe end
        return gl - 8 - breite, b, breite, hoehe
    end
    if O.belegt(platz(wunsch)) and not O.belegt(platz(andere)) then return andere end
    return wunsch
end

-- ---------------------------------------------------------------------------------------------
-- B-7 (zweiter Teil)  Ein freier Platz fuer die Gestalt selbst.
-- design-v3 d.1: der heutige Default {"BOTTOMRIGHT", -40, 120} liegt bei den meisten Aufbauten
-- mitten in den Aktionsleisten. Links auf halber Hoehe ist der einzige Bereich, den kaum jemand
-- belegt - und Lyra sieht im Sprite nach rechts, also ins Bild hinein statt heraus.
-- Der Default in Core/Init.lua gehoert Team A (A-2); hier steht nur der Vorschlag, den
-- "/lyra position vorschlag" anbietet. Nichts wird von selbst verschoben.
-- ---------------------------------------------------------------------------------------------
O.POS_KANDIDATEN = {
    { "LEFT", 24, 40 },
    { "RIGHT", -24, 40 },
    { "BOTTOMLEFT", 24, 260 },
    { "TOP", 0, -200 },
}
function O.positionVorschlag(breite, hoehe)
    breite = tonumber(breite) or 0
    hoehe  = tonumber(hoehe) or 0
    if breite <= 0 or hoehe <= 0 then
        local g = ns.Gestalt and ns.Gestalt.frame
        local _, _, gw, gh = O.rechteck(g)
        breite = (breite > 0 and breite) or gw or 112
        hoehe  = (hoehe > 0 and hoehe) or gh or 112
    end
    local W = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
    local H = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
    -- Die Blase steht seitlich daneben: fuer die Pruefung grosszuegig mitrechnen.
    local pb, ph = breite + 300, math.max(hoehe, 120)
    local bester, bestWert
    for i = 1, #O.POS_KANDIDATEN do
        local k = O.POS_KANDIDATEN[i]
        local cx, cy
        if k[1] == "LEFT" then cx, cy = k[2] + breite / 2, H / 2 + k[3]
        elseif k[1] == "RIGHT" then cx, cy = W + k[2] - breite / 2, H / 2 + k[3]
        elseif k[1] == "BOTTOMLEFT" then cx, cy = k[2] + breite / 2, k[3]
        else cx, cy = W / 2 + k[2], H + k[3] end
        local wert = O.belegtAnteil(cx - pb / 2, cy - ph / 2, pb, ph)
        if not bestWert or wert < bestWert then bester, bestWert = k, wert end
        if wert <= 0 then break end
    end
    bester = bester or O.POS_KANDIDATEN[1]
    return { bester[1], bester[2], bester[3] }, bestWert or 0
end
