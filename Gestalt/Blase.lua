-- Gestalt/Blase.lua — Sprechblase an der Gestalt. STANDARD_TEXT_FONT (Locale-sicher).
-- DESIGN-V3 A-4/A-5/A-6/A-7 (17.09.2026), Begruendung in docs/design-v3.md:
--   * A-4 Optik: EIGENE Kachel bilder/blase_kachel.png als edgeFile (512 x 64, acht Zellen a 64,
--     9-Slice), Grund Interface\Tooltips\UI-Tooltip-Background, Zipfel bilder/blase_zipfel.png.
--     Grund: ChatBubble-Background/-Tail sind in Era durch KEIN einziges der 97 installierten
--     Addons belegt - ein unbelegter Pfad ist ein leerer Rahmen, sobald Blizzard ihn umbenennt.
--     Deckung 1,00 (war 0,97): Kontrast gewinnt einen Punkt und kostet nichts.
--     Farben kommen aus ns.Optik.farben() - eine Palette fuer Blase, Menue und Dialog.
--     Der Rand wird NICHT mehr nach Warnstufe eingefaerbt (Befund 3: #ff7a5a gegen #b48cff = 1,01:1).
--   * A-5 Warnstufe: Icon-Textur links vom Text statt des Praefix "! ". Die Verzweigung haengt an
--     der STUFE, nicht an klasse == "warn" - eine Stufe-3-Zeile ohne die Klasse bekam bisher nichts.
--     Faellt die Textur aus, kommt das alte "! " zurueck (Fallback, nie ein leerer Platz).
--   * A-6 Sitz: im Portrait IMMER seitlich (rechts, wenn Platz; sonst links), Zipfel auf halber
--     Kreishoehe. In der Ganzfigur wie bisher oben, wenn Platz ist.
--   * A-7 Breite: 13 x schrift bis min(28 x schrift, 38 % Bildschirmbreite). 22 x waren 44 Zeichen
--     je Zeile - unter der typografischen Untergrenze von 45-75.
-- DESIGN-V2 (Lesbarkeit, design-v2.md 2.1/2.4):
--   * KEIN OUTLINE auf dem dunklen Grund; Umriss nur im Kontrast-Modus (weiss auf schwarz).
--   * Zeilenabstand SetSpacing(0.35 x Schriftgroesse), guarded.
--   * Standzeit = max(blaseDauer, 2 s + 0,06 s je Zeichen) - "Hm." steht kurz, ein langer Satz lange.
--   * Stufe 3 erscheint ohne Ein-Fade. Ein Alarm, der sanft aufgeht, ist keiner.
-- Ein-/Ausblenden per AnimationGroup (0.2 s / 0.4 s), Fallback Show/Hide.
-- Queue: warn ersetzt eine stehende Zeile sofort, plauder wartet bis zum Ende (max 1 wartende).
-- API: CreateFrame, Backdrop, FontString:SetSpacing (guarded), Texture:SetRotation (guarded),
--   AnimationGroup, C_Timer. Nichts Fremdes.
local ADDON, ns = ...
local B = {}
ns.Blase = B

B.BREITE_MIN, B.BREITE_MAX = 180, 320   -- Startwerte; B.layout() rechnet sie aus der Schriftgroesse neu
B.BREITE_JE_ZEICHEN_MIN, B.BREITE_JE_ZEICHEN_MAX = 13, 28   -- A-7: 22 -> 28 (44 -> ~56 Zeichen/Zeile)
B.BREITE_ANTEIL = 0.38                  -- A-7: hoechstens 38 % der Bildschirmbreite
B.RAND = 14          -- Innenabstand Text
B.SCHWANZ = 16       -- Groesse der Schwanz-Textur
B.ABSTAND = 6        -- Luft zwischen Gestalt und Blase (ohne Schwanz)
B.FADE_EIN, B.FADE_AUS = 0.2, 0.4
B.LESE_GRUND, B.LESE_JE_ZEICHEN, B.LESE_MAX = 2, 0.06, 24
B.stufe = 0          -- Warnstufe der stehenden Zeile (0 keine, 1 Hinweis, 2 Warnung, 3 Alarm)

-- Farben: seit A-4 kommen sie aus ns.Optik.farben(). Die Werte hier sind nur noch der Rueckfall,
-- falls UI/Optik.lua einmal nicht geladen ist (dann ist das Addon zwar ohnehin halb tot, aber die
-- Blase darf deswegen nicht unlesbar werden).
B.FARBE_TEXT = { 0.95, 0.93, 1.00 }        -- #F2EDFF
B.FARBE_GRUND = { 0.07, 0.04, 0.13 }       -- #120A21, deckend (A-4: Deckung 1,00)
B.FARBE_RAND = { 1, 1, 1 }                 -- die Kachel bringt ihre Randfarbe selbst mit
B.FARBE_WARN = { 1.0, 0.478, 0.353 }       -- #FF7A5A Stufe 2 (nur noch fuer das Icon)
B.FARBE_ALARM = { 1.0, 0.251, 0.251 }      -- #FF4040 Stufe 3 (nur noch fuer das Icon)
B.FARBE_HINWEIS = { 1.0, 0.82, 0.0 }       -- Gold, Stufe 1

-- A-5: Warn-Icon. Beide Pfade sind in Classic-Era-Addons belegt (docs/design-v3.md f.3):
-- AvailableQuestIcon in Details/core/network.lua:349, UI-Dialog-Icon-AlertNew in
-- AckisRecipeList/Core.lua:373 (Era-only). 16 x 16 bei TOPLEFT +10/-10, Text rueckt auf +30.
B.ICON_GROESSE = 16
B.ICON_PFAD = {
    [1] = "Interface\\GossipFrame\\AvailableQuestIcon",
    [2] = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew",
    [3] = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew",
}

-- Schriftgroesse: B-1 liefert ns.schriftgroesse() mit dem Wert "auto" nach. Bis dahin (und falls
-- es sie nie gibt) der eingestellte Wert. "auto" ist ein String -> tonumber faengt ihn ab.
function B.schriftgroesse()
    local s
    if ns.schriftgroesse then s = tonumber(ns.schriftgroesse()) end
    if not s and ns.Optik and ns.Optik.schriftgroesse then s = tonumber(ns.Optik.schriftgroesse()) end
    if not s then s = tonumber(ns.Get("schrift")) end
    if not s then s = 14 end
    if s < 10 then s = 10 elseif s > 28 then s = 28 end
    return s
end

-- Palette: ns.Optik ist die Quelle, die Tabelle oben der Rueckfall.
-- W10B (Roadmap 10-7): DAVOR steht seit Welle 10b die benannte Palette aus UI/Farben.lua.
-- Sie aendert am heutigen Bild nichts: die Palette "standard" traegt genau die Werte, die
-- ns.Optik unter FARBEN.normal fuehrt, und die Palette "kontrast" genau die aus FARBEN.kontrast.
-- Und das Haekchen "Hoher Kontrast" gewinnt in ns.Farben.name() ohnehin gegen jede Palettenwahl
-- - eine Farbwahl kann die Barrierefreiheit also nicht unterlaufen.
-- Ohne UI/Farben.lua (alte TOC, port-Pruefstand) faellt alles auf den bisherigen Weg zurueck.
local function farbe(name)
    if ns.Farben and ns.Farben.blase then
        local ok, c = pcall(ns.Farben.blase, name)
        if ok and type(c) == "table" and c[1] then return c end
    end
    if ns.Optik and ns.Optik.farben then
        local c = ns.Optik.farben()
        if c and c[name] then return c[name] end
    end
    if name == "text" then return B.FARBE_TEXT end
    if name == "panel" then return B.FARBE_GRUND end
    return B.FARBE_RAND
end

-- Standzeit aus Textlaenge; blaseDauer ist die Untergrenze.
function B.dauerFuer(str, basis)
    local n = (type(str) == "string") and #str or 0
    local d = B.LESE_GRUND + n * B.LESE_JE_ZEICHEN
    local min = tonumber(basis) or 6
    if d < min then d = min end
    if d > B.LESE_MAX then d = B.LESE_MAX end
    return d
end

-- REVIEW: kein Frame-Name -> kein zusaetzlicher Global
local f = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
f:SetFrameStrata("MEDIUM")
f:SetFrameLevel(20)
-- FIX 20.09.2026 (Harald, Screenshot-Runde): Die Blase haengt an der Gestalt; steht die am
-- Bildschirmrand, ragte die Blase hinaus und wurde abgeschnitten. Clamping haelt sie im Bild,
-- der Zipfel zeigt dann nicht mehr exakt auf die Gestalt - das ist der kleinere Schaden.
f:SetClampedToScreen(true)
f:SetSize(260, 60)
-- FIX 20.09.2026 (Screenshot-Befund "Leitermuster" am oberen/unteren Rand): Blizzard_SharedXML/
-- Backdrop.lua zeichnet TopEdge/BottomEdge mit GEDREHTEN Texturkoordinaten (Textur-x wird zur
-- Hoehe des Randstuecks, Textur-y laeuft wiederholt an der Kante entlang). Die Zellen 2 (oben)
-- und 3 (unten) muessen deshalb aussehen wie die Zellen 0 (links) bzw. 1 (rechts): Aussenseite
-- bei kleinem x fuer oben, bei grossem x fuer unten. Bisher lag die Linie dort horizontal, und
-- das Kacheln entlang der Kante machte daraus eine Leiter. Kachel neu gebaut, Code unveraendert.
-- A-4: eigene 9-Slice-Kachel. WoW liest eine edgeFile als ACHT gleich breite Spalten ueber die
-- volle Hoehe (links, rechts, oben, unten, dann die vier Ecken) - deshalb 512 x 64 und nicht
-- 256 x 64, sonst waere jede Zelle 32 x 64 und jede Ecke gequetscht. edgeSize 14: darunter wird
-- die 5-px-Linie sub-pixelig, darueber frisst der Rand bei kurzen Zeilen ("Hm.") die Flaeche.
-- Der weiche dunkle Aussenschatten steckt IN der PNG (kein zweiter Draw): er kostet damit keine
-- Laufzeit, kann nicht vergessen werden und traegt den violetten Rand auf Schnee (7,97:1).
B.BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = ns.PFAD .. "bilder\\blase_kachel.png",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
}
if f.SetBackdrop then pcall(f.SetBackdrop, f, B.BACKDROP) end
local text = f:CreateFontString(nil, "OVERLAY")
text:SetPoint("TOPLEFT", B.RAND, -14)   -- Breite setzt bemesse(); die HOEHE bleibt frei, s. u.
text:SetWidth(260 - 2 * B.RAND)
text:SetJustifyH("LEFT")
text:SetJustifyV("TOP")
text:SetWordWrap(true)
-- W7 (20.09.2026, Screenshot-Befund Bildschirmfoto_20260920_112946.png): Die Blase rechts vom
-- Portrait zeigte "Westfall. You nearly died here once. I haven't f…" - EINZEILIG gekuerzt,
-- waehrend derselbe Satz in der Lage "oben" sauber zweizeilig umbrach.
-- Die "…" kommen NICHT vom Umbruch (SetWordWrap ist an), sondern von der HOEHE: eine FontString
-- mit gesetzter Hoehe, in die der umgebrochene Text nicht passt, kuerzt die letzte sichtbare
-- Zeile mit Auslassungspunkten. bemesse() hat die Hoehe aus GetStringHeight() gesetzt - und
-- GetStringHeight meldet an einer bereits gekuerzten FontString die Hoehe der EINEN Zeile.
-- Damit hielt sich der Zustand selbst fest, sobald er einmal eingetreten war.
-- Seit W7 traegt die FontString GAR KEINE Hoehe mehr (0 = wachsen nach Inhalt); die Hoehe
-- rechnet bemesse() nur noch fuer den Rahmen aus. Eine FontString ohne Hoehenschranke kuerzt
-- nicht - es gibt nichts, wogegen gekuerzt werden koennte. SetMaxLines(0) sagt dasselbe noch
-- einmal ausdruecklich, falls ein Client von sich aus eine Grenze mitbringt (guarded: die
-- Methode gibt es in Era 1.15, belegt in WIM/Libs/LibDropDownMenu, Rarity, WeakAuras).
pcall(text.SetHeight, text, 0)
pcall(text.SetMaxLines, text, 0)
text:SetFont(STANDARD_TEXT_FONT, 14, "")   -- REVIEW: FontString ohne Template hat keine Schrift, bis layout() laeuft
-- Messlatte: gleiche Schrift, ohne Umbruch, unsichtbar -> GetStringWidth der ganzen Zeile
local mess = f:CreateFontString(nil, "OVERLAY")
mess:SetFont(STANDARD_TEXT_FONT, 14, "")
mess:SetWordWrap(false)
mess:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
mess:Hide()
-- Schwanz: eigene Textur (A-2 der Entscheidungstabelle), zeigt nach unten; fuer die seitliche
-- Lage wird sie gedreht (SetRotation, guarded).
local schwanz = f:CreateTexture(nil, "BORDER")
schwanz:SetSize(B.SCHWANZ, B.SCHWANZ)
schwanz:SetTexture(ns.PFAD .. "bilder\\blase_zipfel.png")
schwanz:SetPoint("TOP", f, "BOTTOM", 0, 4)
-- A-5: Warn-Icon links vom Text. Liegt fest bei TOPLEFT +10/-10; der Text rueckt bei Stufe >= 1
-- von +14 auf +30 und wird um 16 px schmaler. Im Ruhezustand versteckt.
local icon = f:CreateTexture(nil, "ARTWORK")
icon:SetSize(B.ICON_GROESSE, B.ICON_GROESSE)
icon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
icon:Hide()
-- W6 (Recherche 10, A5): Die Warnstufe traegt zusaetzlich eine FORM. Bis 0.10.0 unterschied sie
-- sich nur in Farbe (Icon, Ring, Glow) - und Farbe allein ist fuer rund 8 % der maennlichen
-- Spieler kein Traeger. Blizzards eigene 12.0.0-Loesung (Rahmenfarben) hilft dort auch nicht.
-- Stufe 1 ein Punkt, Stufe 2 ein Dreieck, Stufe 3 zwei Dreiecke - am Kopf der Blase, rechts.
--
-- REINES ASCII, mit derselben Begruendung wie das "! " der Untertitel-Leiste (UI/Streamer.lua):
-- gezeichnet wird mit STANDARD_TEXT_FONT (FRIZQT__.TTF bzw. ARIALN.TTF), und U+26A0 WARNING
-- SIGN, U+2022 BULLET und U+25B2 BLACK UP-POINTING TRIANGLE sind in diesen Blizzard-Schriften
-- nicht belegt. Ein leeres Kaestchen waere das Gegenteil einer Warnung. "o" und "^" sind in
-- jeder Schrift und in jedem Locale da.
B.SYMBOL = { [1] = "o", [2] = "^", [3] = "^^" }
B.SYMBOL_MINUS = 2      -- normal: so viel kleiner als der Fliesstext
B.SYMBOL_PLUS = 6       -- Barrierefrei-Modus: so viel groesser
local symbol = f:CreateFontString(nil, "OVERLAY")
symbol:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
symbol:SetJustifyH("RIGHT")
-- FIX5-Regel: Schrift IMMER vor dem ersten SetText, sonst wirft SetText hart.
symbol:SetFont(STANDARD_TEXT_FONT, 12, "")
symbol:Hide()
f:Hide()
B.frame, B.text, B.schwanz, B.icon, B.symbol = f, text, schwanz, icon, symbol
-- W7: die Messlatte nach aussen. /lyra debug und der Pruefstand konnten bis 0.10.0 nur raten,
-- welche Breite bemesse() gemessen hat - und genau daran hing der "…"-Befund.
B.mess = mess

local ticker            -- Standzeit
local wartend           -- { str, dauer, klasse } (max 1)
local zustand = "aus"   -- aus | ein | steht | ausblenden
local lage = "oben"     -- oben | links | rechts (Blase relativ zur Gestalt)

-- ---------------------------------------------------------------------------------------------
-- Fade (AnimationGroup, guarded)
-- ---------------------------------------------------------------------------------------------
local einAG, ausAG
local function baueFade(dauer, von, bis)
    if not f.CreateAnimationGroup then return nil end
    local ok, ag = pcall(f.CreateAnimationGroup, f)
    if not ok or not ag or not ag.CreateAnimation then return nil end
    local ok2 = pcall(function()
        local a = ag:CreateAnimation("Alpha")
        if a.SetFromAlpha and a.SetToAlpha then a:SetFromAlpha(von); a:SetToAlpha(bis)
        elseif a.SetChange then a:SetChange(bis - von)
        else error("keine Alpha-API") end
        a:SetDuration(dauer)
        a:SetOrder(1)
        if ag.SetToFinalAlpha then ag:SetToFinalAlpha(true) end
        ag:SetLooping("NONE")
    end)
    if ok2 then return ag end
    return nil
end
einAG = baueFade(B.FADE_EIN, 0, 1)
ausAG = baueFade(B.FADE_AUS, 1, 0)

local naechste   -- forward
local function hartAus()
    if ticker then ticker:Cancel(); ticker = nil end
    if einAG and einAG:IsPlaying() then pcall(einAG.Stop, einAG) end
    if ausAG and ausAG:IsPlaying() then pcall(ausAG.Stop, ausAG) end
    f:Hide()
    f:SetAlpha(1)
    zustand = "aus"
end
if einAG then
    einAG:SetScript("OnFinished", function() f:SetAlpha(1); zustand = "steht" end)
end
if ausAG then
    ausAG:SetScript("OnFinished", function()
        f:Hide(); f:SetAlpha(1); zustand = "aus"
        naechste()
    end)
end

local function einblenden()
    if einAG then
        if ausAG and ausAG:IsPlaying() then pcall(ausAG.Stop, ausAG) end
        if einAG:IsPlaying() then pcall(einAG.Stop, einAG) end
        f:SetAlpha(0)
        f:Show()
        zustand = "ein"
        if not pcall(einAG.Play, einAG) then f:SetAlpha(1); zustand = "steht" end
    else
        f:SetAlpha(1); f:Show(); zustand = "steht"
    end
end

local function ausblenden()
    if ticker then ticker:Cancel(); ticker = nil end
    if not f:IsShown() then zustand = "aus"; naechste(); return end
    if ausAG then
        if einAG and einAG:IsPlaying() then pcall(einAG.Stop, einAG) end
        f:SetAlpha(1)
        zustand = "ausblenden"
        if not pcall(ausAG.Play, ausAG) then hartAus(); naechste() end
    else
        hartAus()
        naechste()
    end
end

-- REVIEW7: die aktuelle Lage nach aussen lesbar ("oben" | "links" | "rechts"). /lyra drift und der
-- Pruefstand hatten bisher nur die Ankerpunkte, um sie zu erraten.
function B.lageJetzt() return lage end

-- Steht die Blase (fuer das Nicken der Gestalt)? Ausblendend zaehlt nicht.
function B.sichtbar()
    return f:IsShown() and zustand ~= "ausblenden" and zustand ~= "aus"
end

-- ---------------------------------------------------------------------------------------------
-- Lage und Layout
-- ---------------------------------------------------------------------------------------------
local function drehe(rad)
    if schwanz.SetRotation then pcall(schwanz.SetRotation, schwanz, rad) end
end

-- Seite mit mehr Platz. ns.Optik.freieSeite() ist die gemeinsame Stelle (B-7 erweitert sie um die
-- Hindernis-Pruefung gegen Questie/Chat/Minimap); ohne sie die alte Bildschirmhaelften-Regel.
local function freieSeite(g)
    if ns.Optik and ns.Optik.freieSeite then
        -- B-7 nimmt Breite und Hoehe des Fensters, das dort stehen soll - ohne sie rechnet es mit
        -- einem Dialog-Mass, und die Blase ist deutlich flacher.
        local ok, s = pcall(ns.Optik.freieSeite, f:GetWidth(), f:GetHeight())
        if ok and s == "LEFT" then return "links" end
        if ok and s == "RIGHT" then return "rechts" end
    end
    local cx = g and g:GetCenter()
    local uw = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 0
    if cx and cx < uw / 2 then return "rechts" end
    return "links"
end

-- REVIEW7 / DESIGN-V3 B-7 (P2-4): dieselbe Hindernispruefung wie Menue und Dialog. freieSeite()
-- oben nimmt die andere Seite, wenn die Wunschseite belegt ist - sie kann aber nicht sagen, dass
-- BEIDE belegt sind. Dafuer ist ns.Optik.belegtAnteil() da:
--   beide Seiten belegt  -> oben (auch im Portrait; ein Schild auf dem Stecken ist besser als eine
--                           Blase im Questie-Tracker)
--   auch oben belegt     -> Wunschseite, aber drueberlegen (FrameLevel + 10)
-- Ohne ns.Optik faellt alles auf die alte Regel zurueck; im Prueflauf ohne Hindernis-Frames ist
-- belegtAnteil() ueberall 0, die Zusagen aus A-6 gelten also unveraendert.
-- 8, nicht 10: das Gespraechsfenster liegt auf MEDIUM/30, und zwei Fenster auf demselben Level
-- sind eine Zufallsentscheidung des Clients. 20 + 8 = 28 bleibt strikt darunter und trotzdem ueber
-- allem, was auf MEDIUM sonst herumsteht. Das Menue liegt auf Strata DIALOG und ist ohnehin oben.
B.UEBER_LEVEL = 8
local function anteil(l, b, w, h)
    if not (ns.Optik and ns.Optik.belegtAnteil) then return 0 end
    local ok, v = pcall(ns.Optik.belegtAnteil, l, b, w, h)
    return (ok and tonumber(v)) or 0
end
-- Legt die Blase ueber die Hindernisse, statt sie darunter verschwinden zu lassen. Nur ein
-- FrameLevel - keine Strata-Aenderung, damit sie nicht ueber Menue (30) oder Dialog steigt.
local basisLevel = 20
function B.ueberlagern(an)
    B.ueberlagert = an and true or false
    pcall(f.SetFrameLevel, f, basisLevel + (an and B.UEBER_LEVEL or 0))
end

-- Lage bestimmen.
-- A-6: im PORTRAIT immer seitlich. Der Kreis ist 112 px, die Blase 450 - ueber einem Kreis sieht
-- das aus wie ein Schild auf einem Stecken, und der Zipfel zeigt auf nichts Bestimmtes. Seitlich
-- sitzt er auf halber Kreishoehe und zeigt auf die Mitte des Gesichts.
-- In der Ganzfigur wie bisher: oben, wenn Platz ist; sonst seitlich.
local function passtOben(g)
    local top, ui = g:GetTop(), UIParent and UIParent:GetTop()
    if not (top and ui) then return false end
    return (top + f:GetHeight() + B.SCHWANZ + B.ABSTAND) <= ui
end
-- true, wenn links UND rechts neben der Gestalt ein Hindernis steht
local function beideSeitenBelegt(g)
    if not (ns.Optik and ns.Optik.rechteck and ns.Optik.belegtAnteil) then return false end
    local gl, gb, gw, gh = ns.Optik.rechteck(g)
    if not gl then return false end
    local w, h = f:GetWidth() or 0, f:GetHeight() or 0
    if w <= 0 or h <= 0 then return false end
    local grenze = ns.Optik.UEBERLAPP or 0.15
    local y = gb + gh / 2 - h / 2
    local luft = B.ABSTAND + B.SCHWANZ
    return anteil(gl + gw + luft, y, w, h) > grenze and anteil(gl - luft - w, y, w, h) > grenze
end
-- W7 (20.09.2026, Screenshot-Befund "Blase kuerzt mit …"): Passt die Blase in ihrer vollen
-- Breite ueberhaupt noch neben die Gestalt? Bis 0.10.0 hat das niemand gefragt: freieSeite()
-- vergleicht nur Bildschirmhaelften und Hindernisse, nicht die BREITE der Blase. Stand die
-- Gestalt links, ging die Blase nach rechts - auch wenn dort nur noch 200 px frei waren.
-- SetClampedToScreen (seit heute) hat sie dann zurueckgeschoben, und weil sie dabei auf der
-- Gestalt lag, sah es aus, als spraenge sie. Jetzt wird vorher gemessen.
-- Rueckgabe: true, wenn auf dieser Seite die volle Blasenbreite plus Luft in den Bildschirm passt.
local function passtSeitlich(g, seite)
    local w = f:GetWidth() or 0
    if w <= 0 then return true end
    local luft = B.ABSTAND + B.SCHWANZ
    local ul = (UIParent and UIParent.GetLeft and UIParent:GetLeft()) or 0
    local ur = (UIParent and UIParent.GetRight and UIParent:GetRight())
    if not ur then return true end
    if seite == "rechts" then
        local gr = g.GetRight and g:GetRight()
        if not gr then return true end
        return (gr + luft + w) <= ur
    end
    local gl = g.GetLeft and g:GetLeft()
    if not gl then return true end
    return (gl - luft - w) >= ul
end
B.passtSeitlich = passtSeitlich

-- W7: die Wunschseite, aber nur wenn die Blase dort auch hinpasst; sonst die andere Seite;
-- passt keine von beiden, gibt die Funktion nil zurueck und der Aufrufer weicht nach OBEN aus.
local function seiteMitPlatz(g)
    local wunsch = freieSeite(g)
    if passtSeitlich(g, wunsch) then return wunsch end
    local andere = (wunsch == "rechts") and "links" or "rechts"
    if passtSeitlich(g, andere) then return andere end
    return nil
end

local function bestimmeLage(g)
    if not g then B.ueberlagern(false); return "oben" end
    local portrait = ns.Gestalt and ns.Gestalt.istPortrait and ns.Gestalt.istPortrait()
    if beideSeitenBelegt(g) then
        local gl, gb, gw, gh = ns.Optik.rechteck(g)
        local w, h = f:GetWidth(), f:GetHeight()
        local obenFrei = passtOben(g)
            and anteil((gl or 0) + (gw or 0) / 2 - w / 2, (gb or 0) + (gh or 0) + B.ABSTAND + B.SCHWANZ, w, h)
                <= (ns.Optik.UEBERLAPP or 0.15)
        if obenFrei then B.ueberlagern(false); return "oben" end
        B.ueberlagern(true)
        return seiteMitPlatz(g) or freieSeite(g)
    end
    B.ueberlagern(false)
    if portrait then
        -- A-6 bleibt: im Portrait seitlich. W7: ausser es passt seitlich nirgends mehr - dann
        -- ist "oben" das kleinere Uebel (ein Schild auf dem Stecken ist besser als eine Blase,
        -- die entweder abgeschnitten wird oder auf dem Gesicht liegt).
        local s = seiteMitPlatz(g)
        if s then return s end
        return "oben"
    end
    if passtOben(g) then return "oben" end
    if not (g:GetTop() and UIParent and UIParent:GetTop()) then return "oben" end
    return seiteMitPlatz(g) or freieSeite(g)
end

-- FIX4-Regel (DESIGN.md 1.6): Die Blase haengt AUSSCHLIESSLICH an ns.Gestalt.frame, nie an
-- ns.Gestalt.bewegtFrame. Sonst machte sie das Atmen mit - und im Fehlerfall die Drift.
-- G.frame ist der Rahmen, der die gespeicherte Position und das Mausfeld traegt; die
-- Bewegungsebene darunter darf sich bewegen, ohne dass irgendetwas anderes mitgeht.
-- W6 (Recherche 10, A6): "keine Figur". Lyra laeuft dann VOLLWERTIG weiter - dieselben
-- Ereignisse, dieselbe Stimme, dasselbe Gedaechtnis -, sie hat nur kein Portrait mehr. Die
-- Blase haengt in dem Fall an keiner Gestalt, sondern am Bildschirmrand, und zeigt auf nichts
-- (kein Zipfel - ein Zipfel, der ins Leere zeigt, ist ein Fehler, der wie ein Fehler aussieht).
B.RAND_FREI = 150       -- px ueber dem unteren Rand: ueber der Untertitel-Leiste (die sitzt bei 60)
local function ohneFigur()
    local W6 = ns.Welle6
    return (W6 and W6.figurAus and W6.figurAus()) and true or false
end
B.ohneFigur = ohneFigur

-- Traegt die Untertitel-Leiste die Zeile ohnehin? Dann braucht es keine zweite Anzeige
-- derselben Worte - das ist die alte Doppelung aus A-5, nur eine Etage hoeher.
local function leisteTraegt()
    local St = ns.Streamer
    if not (St and St.leisteAn) then return false end
    local ok, an = pcall(St.leisteAn)
    return (ok and an) and true or false
end

-- true = die Blase bleibt weg.
--   /lyra verstecken (versteckt, ohne "keine Figur")  -> wie bisher: keine Blase.
--   "keine Figur"                                     -> Blase JA, ausser die Leiste zeigt schon.
function B.unterdrueckt()
    if not ns.Get("versteckt") then return false end
    if not ohneFigur() then return true end
    return leisteTraegt()
end

local function positioniere()
    local g = ns.Gestalt and ns.Gestalt.frame
    f:ClearAllPoints()
    schwanz:ClearAllPoints()
    if ohneFigur() then
        f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, B.RAND_FREI)
        schwanz:Hide(); lage = "frei"; B.ueberlagern(false); return
    end
    if not g then
        f:SetPoint("CENTER"); schwanz:Hide(); lage = "oben"; return
    end
    lage = bestimmeLage(g)
    schwanz:Show()
    local portrait = ns.Gestalt and ns.Gestalt.istPortrait and ns.Gestalt.istPortrait()
    if lage == "oben" then
        f:SetPoint("BOTTOM", g, "TOP", 0, B.ABSTAND + B.SCHWANZ - 4)
        schwanz:SetPoint("TOP", f, "BOTTOM", 0, 4)
        drehe(0)
    elseif lage == "rechts" then   -- Blase rechts neben der Gestalt, Schwanz links zeigt nach links
        if portrait then
            -- A-6: auf Kreismitte. Die Mitte von G.frame liegt genau bei TOP - 0,5 x Kante, der
            -- Zipfel sitzt also auf halber Kreishoehe, ohne dass die Kante hier gerechnet wird.
            f:SetPoint("LEFT", g, "RIGHT", B.ABSTAND + B.SCHWANZ - 4, 0)
            schwanz:SetPoint("RIGHT", f, "LEFT", 4, 0)
        else
            f:SetPoint("BOTTOMLEFT", g, "RIGHT", B.ABSTAND + B.SCHWANZ - 4, 0)
            schwanz:SetPoint("RIGHT", f, "BOTTOMLEFT", 4, 20)
        end
        if schwanz.SetRotation then drehe(-math.pi / 2) else schwanz:Hide() end
    else                            -- Blase links neben der Gestalt, Schwanz rechts zeigt nach rechts
        if portrait then
            f:SetPoint("RIGHT", g, "LEFT", -(B.ABSTAND + B.SCHWANZ - 4), 0)
            schwanz:SetPoint("LEFT", f, "RIGHT", -4, 0)
        else
            f:SetPoint("BOTTOMRIGHT", g, "LEFT", -(B.ABSTAND + B.SCHWANZ - 4), 0)
            schwanz:SetPoint("LEFT", f, "BOTTOMRIGHT", -4, 20)
        end
        if schwanz.SetRotation then drehe(math.pi / 2) else schwanz:Hide() end
    end
end

-- A-5: Icon setzen. Rueckgabe true, wenn wirklich eine Textur sitzt - nur dann darf das "! " im
-- Text entfallen. B.iconOk merkt sich das Ergebnis fuer B.zeige().
local function setzeIcon(stufe)
    if stufe < 1 then icon:Hide(); B.iconOk = false; return false end
    local pfad = B.ICON_PFAD[stufe] or B.ICON_PFAD[3]
    local ok = pcall(icon.SetTexture, icon, pfad)
    local wert
    if ok and icon.GetTexture then local o, w = pcall(icon.GetTexture, icon); wert = o and w or nil end
    if not ok or wert == nil or wert == "" then
        icon:Hide(); B.iconOk = false; return false
    end
    local c = B.FARBE_HINWEIS
    if stufe >= 3 then c = B.FARBE_ALARM elseif stufe == 2 then c = B.FARBE_WARN end
    if ns.Get("kontrast") then c = { 1, 1, 1 } end   -- Kontrast-Modus: reines Weiss, wie alles andere
    pcall(icon.SetVertexColor, icon, c[1], c[2], c[3], 1)
    icon:Show()
    B.iconOk = true
    return true
end

-- W6: Das Formsymbol setzen. Rueckgabe true, wenn eines steht. B.symbolBreite ist der Platz,
-- den bemesse() rechts frei lassen muss - sonst laeuft die erste Textzeile darunter durch.
-- Die Farbe folgt dem Icon, TRAEGT aber nichts: die Aussage steckt in der Form.
function B.setzeSymbol(stufe)
    stufe = tonumber(stufe) or 0
    local zeichen = (ns.Get("warnSymbol") ~= false) and B.SYMBOL[stufe] or nil
    if not zeichen then
        symbol:Hide(); B.symbolZeichen, B.symbolBreite = nil, 0; return false
    end
    local basis = B.schriftgroesse()
    local gross = (ns.Welle6 and ns.Welle6.an and ns.Welle6.an("barrierefrei")) and true or false
    local groesse = gross and (basis + B.SYMBOL_PLUS) or (basis - B.SYMBOL_MINUS)
    if groesse < 8 then groesse = 8 end
    pcall(symbol.SetFont, symbol, STANDARD_TEXT_FONT, groesse, ns.Get("kontrast") and "OUTLINE" or "")
    local ok = pcall(symbol.SetText, symbol, zeichen)
    if not ok then
        symbol:Hide(); B.symbolZeichen, B.symbolBreite = nil, 0; return false
    end
    local c = B.FARBE_HINWEIS
    if stufe >= 3 then c = B.FARBE_ALARM elseif stufe == 2 then c = B.FARBE_WARN end
    if ns.Get("kontrast") then c = { 1, 1, 1 } end
    pcall(symbol.SetTextColor, symbol, c[1], c[2], c[3])
    symbol:Show()
    B.symbolZeichen = zeichen
    local br = (symbol.GetStringWidth and symbol:GetStringWidth()) or groesse
    B.symbolBreite = (tonumber(br) or groesse) + 10
    return true
end

local function faerbe(stufe)
    stufe = tonumber(stufe) or 0
    local kontrast = ns.Get("kontrast")
    local ct, cg = farbe("text"), farbe("panel")
    if kontrast then
        -- DESIGN-V2 9: im Kontrast-Modus voll deckend (halbtransparenter Text ueber bewegtem Bild
        -- ist der Lesekiller). ns.Optik liefert dort ohnehin Schwarz/Weiss.
        text:SetTextColor(ct[1], ct[2], ct[3])
        if f.SetBackdropColor then f:SetBackdropColor(cg[1], cg[2], cg[3], 1) end
    else
        text:SetTextColor(ct[1], ct[2], ct[3])
        -- A-4: Deckung 1,00. Die Kachel bringt Linie und Aussenschatten selbst mit.
        if f.SetBackdropColor then f:SetBackdropColor(cg[1], cg[2], cg[3], 1) end
    end
    -- A-4: Der Rand wird NICHT mehr nach Warnstufe eingefaerbt - Farbe traegt die Stufe nicht
    -- (#ff7a5a gegen #b48cff sind 1,01:1). Die Stufe steht im Icon und am Ring der Gestalt.
    -- W10B: die Randfarbe kommt aus der Palette - und NUR aus ihr. Der Umweg ueber ns.Optik
    -- wird hier bewusst ausgelassen: O.FARBEN.normal.rand ist Lyras Violett mit Alpha 0,90, und
    -- A-4 hat den Blasenrand gerade deshalb auf hartes Weiss gelegt (die Kachel bringt ihre
    -- eigene Linie mit). Ohne UI/Farben.lua bleibt B.FARBE_RAND = Weiss, also Zeichen fuer
    -- Zeichen das bisherige SetBackdropBorderColor(1, 1, 1, 1).
    local cr = B.FARBE_RAND
    if ns.Farben and ns.Farben.blase then
        local ok, c = pcall(ns.Farben.blase, "rand")
        if ok and type(c) == "table" and c[1] then cr = c end
    end
    if f.SetBackdropBorderColor then f:SetBackdropBorderColor(cr[1], cr[2], cr[3], cr[4] or 1) end
    -- Der Zipfel gehoert zur Fuellung, nicht zum Rand: gleiche Farbe wie der Grund, deckend.
    schwanz:SetVertexColor(cg[1], cg[2], cg[3], 1)
    setzeIcon(stufe)
    B.setzeSymbol(stufe)    -- W6: Form zusaetzlich zur Farbe
end

-- Schrift setzen: Umriss NUR im Kontrast-Modus (design-v2.md 2.1), Zeilenabstand 0.35 x Groesse.
local function schriftSetzen(size)
    local flags = ns.Get("kontrast") and "OUTLINE" or ""
    text:SetFont(STANDARD_TEXT_FONT, size, flags)
    mess:SetFont(STANDARD_TEXT_FONT, size, flags)
    if text.SetShadowOffset and not ns.Get("kontrast") then
        pcall(text.SetShadowOffset, text, 1, -1)
        if text.SetShadowColor then pcall(text.SetShadowColor, text, 0, 0, 0, 0.25) end
    elseif text.SetShadowOffset then
        pcall(text.SetShadowOffset, text, 0, 0)
    end
    if text.SetSpacing then pcall(text.SetSpacing, text, math.floor(size * 0.35)) end
end

-- B.layout([ohnePosition]) — Schrift, Farben, Masse. W7: zeigeJetzt() ruft sie mit ohnePosition,
-- weil die Blase zu diesem Zeitpunkt noch die GROESSE des vorigen Satzes hat. Bis 0.10.0 lief
-- positioniere() hier einmal mit dem alten Mass und gleich danach noch einmal mit dem neuen -
-- die Blase sass also fuer einen Moment falsch und sprang dann. Einmal setzen, richtig setzen.
function B.layout(ohnePosition)
    local size = B.schriftgroesse()
    -- Breite skaliert mit der Schrift: bei 14 px 182-392, bei 20 px 260-560 (gedeckelt, s. u.)
    local maxUI = (UIParent and UIParent.GetWidth and (UIParent:GetWidth() or 0) or 0) * B.BREITE_ANTEIL
    B.BREITE_MIN = B.BREITE_JE_ZEICHEN_MIN * size
    B.BREITE_MAX = B.BREITE_JE_ZEICHEN_MAX * size
    if maxUI > 120 and B.BREITE_MAX > maxUI then B.BREITE_MAX = maxUI end
    if B.BREITE_MAX < B.BREITE_MIN then B.BREITE_MAX = B.BREITE_MIN end
    schriftSetzen(size)
    faerbe(B.stufe)
    if not ohnePosition then positioniere() end
end

-- Groesse nach Text: Breite BREITE_MIN..BREITE_MAX, Hoehe aus dem umgebrochenen Text.
-- A-5: steht ein Icon, rueckt der Text um die Icon-Breite ein (TOPLEFT +30 statt +14) und wird
-- entsprechend schmaler. Das Icon wandert beim Zeilenumbruch NICHT mit - genau der Punkt.
-- W7: Obergrenze fuer die geschaetzte Zeilenzahl. Sie ist eine Notbremse gegen eine kaputte
-- Messung (GetStringWidth = 0 oder absurd gross), nicht eine Grenze fuer den Text: die Blase
-- ist bei BREITE_MAX rund 56 Zeichen breit, sechs Zeilen sind 330 Zeichen - mehr sagt Lyra nie.
B.ZEILEN_MAX = 6

local function bemesse(str)
    local einzug = (B.iconOk and B.stufe >= 1) and B.ICON_GROESSE or 0
    -- W6: das Formsymbol sitzt rechts oben AUSSERHALB des Textflusses. Seine Breite muss hier
    -- abgezogen werden, sonst schiebt sich die erste Zeile darunter - genau der Fehler, den
    -- A-5 beim Icon links schon einmal hatte.
    local rechts = tonumber(B.symbolBreite) or 0
    local size = B.schriftgroesse()
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", f, "TOPLEFT", B.RAND + einzug, -14)
    -- W7: vor JEDER Messung die Schranken loesen. Steht hier eine Hoehe aus dem vorigen Satz,
    -- misst der Client gegen sie - und meldet die gekuerzte Hoehe zurueck (siehe Kopf).
    pcall(text.SetHeight, text, 0)
    pcall(text.SetWordWrap, text, true)
    pcall(text.SetMaxLines, text, 0)
    mess:SetText(str)
    local voll = tonumber(mess:GetStringWidth()) or 0
    local w
    if voll > 0 then
        w = voll + 2 * B.RAND + einzug + rechts + 4
        if w < B.BREITE_MIN then w = B.BREITE_MIN elseif w > B.BREITE_MAX then w = B.BREITE_MAX end
    else
        -- Messlatte stumm (kommt vor, solange der Rahmen noch nie gezeichnet wurde): dann die
        -- BREITESTE Blase nehmen. Zu breit ist haesslich, zu schmal kuerzt - das ist nicht
        -- dieselbe Art von Fehler.
        w = B.BREITE_MAX
    end
    f:SetWidth(w)
    local innen = w - 2 * B.RAND - einzug - rechts
    if innen < 40 then innen = 40 end
    text:SetWidth(innen)
    text:SetText(str)
    -- Zeilenzahl aus der ungebrochenen Breite. Das ist die UNTERGRENZE: an Wortgrenzen braucht
    -- der Umbruch oft eine Zeile mehr, nie eine weniger. Meldet GetStringHeight weniger, ist die
    -- Messung gekuerzt oder veraltet - dann gilt die Schaetzung.
    local zeilen = (voll > 0) and math.ceil(voll / innen) or 1
    if zeilen < 1 then zeilen = 1 elseif zeilen > B.ZEILEN_MAX then zeilen = B.ZEILEN_MAX end
    local zeilenH = size + math.floor(size * 0.35)
    local th = tonumber(text:GetStringHeight()) or 0
    local mindest = zeilen * zeilenH
    if th < mindest then th = mindest end
    B.zeilenJetzt, B.textHoehe, B.breiteJetzt = zeilen, th, w
    -- KEIN text:SetHeight hier. Die FontString waechst nach Inhalt; nur der Rahmen bekommt ein Mass.
    f:SetHeight(math.max(48, th + 28))
end

-- ---------------------------------------------------------------------------------------------
-- Zeigen / Queue
-- ---------------------------------------------------------------------------------------------
local function zeigeJetzt(str, dauer, klasse, stufe)
    stufe = tonumber(stufe) or ((klasse == "warn") and 2 or 0)
    B.stufe = stufe
    B.warnAktiv = (klasse == "warn")
    B.layout(true)      -- setzt ueber faerbe() auch B.iconOk - bemesse() braucht das (W7: ohne Position)
    -- A-5 Fallback: laedt die Icon-Textur nicht, kommt das alte Praefix zurueck. Es steht hier und
    -- nicht in B.zeige, damit eine wartende Zeile es nicht zweimal bekommt.
    if stufe >= 1 and not B.iconOk and str:sub(1, 2) ~= "! " then str = "! " .. str end
    bemesse(str)
    positioniere()   -- Hoehe ist jetzt bekannt -> Lage (oben/seitlich) endgueltig
    if ticker then ticker:Cancel() end
    ticker = ns.Compat.NewTicker(B.dauerFuer(str, dauer), function() ticker = nil; ausblenden() end, 1)
    if zustand == "steht" or zustand == "ein" then return end   -- Text ersetzt, Blase bleibt stehen
    -- Stufe 3: kein Ein-Fade. Ein Alarm, der sanft erscheint, ist keiner (design-v2.md 2.4).
    if stufe >= 3 then
        if ausAG and ausAG:IsPlaying() then pcall(ausAG.Stop, ausAG) end
        if einAG and einAG:IsPlaying() then pcall(einAG.Stop, einAG) end
        f:SetAlpha(1); f:Show(); zustand = "steht"
        return
    end
    einblenden()
end

naechste = function()
    local w = wartend
    wartend = nil
    if not w then return end
    if B.unterdrueckt() then return end   -- W6: "keine Figur" laesst die Blase stehen
    zeigeJetzt(w[1], w[2], w[3], w[4])
end

-- B.zeige(text, blaseDauer, klasse, stufe). stufe 1 Hinweis, 2 Warnung, 3 Alarm (phrasen.lua).
function B.zeige(str, dauer, klasse, stufe)
    if not str or str == "" then return end
    -- Gestalt ausgeblendet: keine Blase (Stimme bleibt, /lyra stumm ist getrennt).
    -- W6: ausser im Modus "keine Figur" - dort ist die Blase (oder die Leiste) der Kanal.
    if B.unterdrueckt() then return end
    -- A-5: kein "! " mehr im Text. Die Stufe zeigt das Icon (zeigeJetzt), und der Untertitel in
    -- UI/Streamer.lua setzt sein eigenes Praefix - damit ist auch die alte Doppelung weg.
    local steht = (zustand == "steht" or zustand == "ein")
    if steht and klasse ~= "warn" then
        wartend = { str, dauer, klasse, stufe }   -- max 1 wartende: die neuere ersetzt die aeltere
        return
    end
    -- warn ersetzt die stehende Zeile sofort; eine wartende plauder-Zeile bleibt in der Queue
    zeigeJetzt(str, dauer, klasse, stufe)
end

function B.verstecke()
    wartend = nil
    B.stufe = 0
    B.iconOk = false
    icon:Hide()
    symbol:Hide()               -- W6
    B.symbolZeichen, B.symbolBreite = nil, 0
    hartAus()
end
