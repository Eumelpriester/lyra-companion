-- UI/Glow.lua — Bildschirmrand-Puls bei Warnung. Vollbild-Frame (FULLSCREEN-Strata, keine Maus).
-- DESIGN-V2 5.4: W.TEXTUR_ROT war die Vollbild-Textur "LowHealth" - exakt die, die der Client
--   selbst ueber LowHealthFrame einblendet, sobald das Leben unter 20 % faellt. Bei HP20 lagen
--   also zwei identische rote Vignetten uebereinander; der Spieler konnte "das Spiel warnt" und
--   "Lyra warnt" nicht unterscheiden. Lyras Alarm ist seitdem VIOLETT und selbst gezeichnet.
-- REVIEW7 / DESIGN-V3 B-6 (17.09.2026): Ohne Gradient-API vier einfarbige Baender mit harter Kante.
--
-- W7 (20.09.2026): Der Gradient-Weg ist raus. Der Verlauf steckt seitdem in der Alpha-Ebene
--   einer eigenen PNG, die Stufenfarbe kommt ueber SetVertexColor - EIN Farbweg, der sich nicht
--   selbst ueberschreiben kann. Die drei Stufen, der Doppelschlag, die Standzeit <= 1 s, der
--   Streamer-Riegel und die Barrierefrei-Anhebung stammen aus dieser Welle und bleiben.
--
-- W9 (20.09.2026, Befund Harald "beim warn rahmen ... die ecken stechen raus, da sich immer 2
--   so zones ueberschneiden"):
--   BEFUND  Gemessen auf Bildschirmfoto_20260920_121326.png (Atem) und ..._120903.png (Stufe 3):
--           Zeile y = 960, Spalte x = 225 -> 240: harter Sprung von 59,72,95 auf 26,22,22.
--           Die Kante liegt bei x = 230 = 1920 * 0,12, also GENAU beim alten W.BAND_HART.
--           Spalte x = 150, Zeile y = 143 -> 146: Sprung von 141,130,170 auf 101,78,97; die
--           Kante liegt bei y = 144 = 1200 * 0,12. Zwischen x = 5 und x = 225 aendert sich
--           nichts - es ist kein Verlauf, sondern eine Flaeche.
--           ZWEI Folgerungen:
--             (1) Harald sieht NICHT die weiche Vignette, sondern den RUECKFALL. Im Spiel war
--                 W.weich also false - puls_rand.png ist dort nicht angekommen. Der Rueckfall
--                 ist damit kein Notnagel, sondern das, was ausgeliefert wirkt. Er muss genauso
--                 sauber sein wie der Hauptweg.
--             (2) Im Rueckfall ueberlappten sich Ober- und Linksband auf 230 x 144 Pixeln, und
--                 ADD addiert dort beide Alphas. Genau die "2 zones", die Harald nennt.
--           Dazu der zweite, stillere Fehler im HAUPTweg: puls_rand.png war eine VOLLBILD-Maske,
--           deren Ecken mit a = 1 - (1-ax)(1-ay) verrechnet waren. Gemessen in der Datei:
--           Alpha bei (32,128) = 163, bei (32,32) = 222. Auch dort war die Ecke heller als die
--           Kante - nur weicher. Und eine 256 x 256-Maske auf 1920 x 1080 gezogen ergibt einen
--           Verlauf von 480 px in der Breite und 270 px in der Hoehe: auf 21:9 waere das
--           640 px zu 270 px. Der Rand war nie gleich breit.
--   FIX     Ein einziger Geometrie-Grundsatz fuer BEIDE Wege: die Flaechen ueberlappen sich nie.
--           Acht Zonen (9-Slice ohne Mitte) - vier Kanten, die VOR der Ecke enden, und vier
--           Eck-Kacheln, die den Verlauf diagonal fortsetzen. Kein Pixel wird zweimal gezeichnet,
--           also kann ADD nichts mehr verdoppeln, egal ob eine Textur darauf liegt oder nicht.
--           * Die Randbreite haengt an der KURZEN Bildschirmseite (W.RAND_ANTEIL), nicht an
--             Breite und Hoehe getrennt. Auf 16:9, 16:10 und 21:9 ist der Rand damit ueberall
--             gleich breit - UIParent ist immer 768 hoch, also sind es immer dieselben Punkte.
--           * puls_rand.png ist jetzt eine ECK-KACHEL statt einer Vollbild-Maske: Alpha ueber
--             dem Abstand zur INNEREN Eckmitte, also ein abgerundetes Rechteck. Weil diese
--             Kachel in der letzten Zeile und der letzten Spalte exakt das 1-D-Randprofil
--             enthaelt, holen sich auch die vier Kanten ihren Verlauf ueber SetTexCoord aus
--             DERSELBEN Datei. Acht Vierecke, eine Textur, ein Stapel.
--           * Rueckfall ohne PNG: dieselben acht Zonen, flach mit WHITE8X8. Keine Ecke wird
--             doppelt beleuchtet. Und weil keine Zone mehr die Bildmitte beruehrt, kann eine
--             fehlgeschlagene Textur auch keine bildschirmfuellende weisse Flaeche mehr
--             hinterlassen - die Sorge aus W7 ist konstruktiv erledigt, nicht nur abgefragt.
--   STUFEN  unveraendert: 1 Hinweis violett dezent, 2 Warnung violett kraeftiger, 3 Alarm
--           rot-violett mit DOPPELSCHLAG. Standzeit <= 1 s, Ausklang weich.
-- Barrierefreiheit: Recherche 02 2.3 (Photosensibilitaet) ist die Obergrenze. Der Riegel
--   zwischen zwei Pulsen bleibt; der Barrierefrei-Modus HEBT die Spitze (W.BF_FAKTOR) und
--   verlaengert dafuer den Riegel.
-- Streamer-Modus: kein Puls. Nie im Ladebildschirm-Riegel, nie wenn tot. Einstellung "glow".
-- API: CreateFrame, Texture:SetTexture/SetColorTexture/SetVertexColor/SetBlendMode/SetTexCoord
--   (alles guarded), AnimationGroup (guarded, mit C_Timer-Rueckfall), UnitIsDeadOrGhost.
local ADDON, ns = ...
local W = {}
ns.Glow = W

W.DAUER = 0.9
W.SPITZE = 0.45
W.RIEGEL = 4          -- s zwischen zwei Pulsen
W.FARBEN = {
    lila  = { 0.706, 0.549, 1.0 },   -- #b48cff - Lyras Farbe, eindeutig NICHT Blizzards Rot
    blau  = { 0.451, 0.702, 1.0 },   -- #73B3FF - Atem/Wasser
    -- W7: Stufe 3. Rot-Violett, nicht Blizzards Rot (#ff0000) und nicht Lyras Lila - dazwischen.
    rotlila = { 1.0, 0.357, 0.706 },  -- #ff5ab4
}
-- W7: Die drei Warnstufen. dauer <= 1 s (Zusage aus dem Befund), schlaege = Doppelschlag.
W.STUFEN = {
    [1] = { farbe = "lila",    spitze = 0.22, dauer = 0.70, schlaege = 1 },
    [2] = { farbe = "lila",    spitze = 0.34, dauer = 0.85, schlaege = 1 },
    [3] = { farbe = "rotlila", spitze = 0.48, dauer = 1.00, schlaege = 2 },
}
W.TEXTUR = ns.PFAD .. "bilder\\puls_rand.png"
W.WEISS = "Interface\\Buttons\\WHITE8X8"
W.SPITZE_HART = 0.35
W.SPITZE_MAX = 0.58   -- W7: harte Obergrenze, egal was jemand hineinreicht (Photosensibilitaet)
W.weich = false        -- true = die Eck-Kachel liegt an; false = Rueckfall flach
W.hartesBand = false   -- /lyra debug zeigt, welcher Pfad laeuft (Rueckfall aktiv)
W.zuletzt = 0

-- W9: Randbreite. EIN Mass fuer alle vier Seiten, abgeleitet von der KURZEN Bildschirmseite.
-- UIParent ist im Client immer 768 Punkte hoch, egal welche Aufloesung darunter liegt; 0,15
-- davon sind 115,2 Punkte - auf 1920 x 1080 rund 162 echte Pixel, auf 1920 x 1200 rund 180,
-- auf 2560 x 1080 wieder 162. Genau das war beim alten Anteil-je-Achse nicht so.
W.RAND_ANTEIL = 0.15
W.RAND_MIN = 40
W.RAND_MAX = 260
W.TEX_EPS = 0.01      -- Breite des Streifens, aus dem die Kanten ihr 1-D-Profil holen

-- ---------------------------------------------------------------------------------------------
-- W9: Der Zonenplan. Reine Rechnung, keine WoW-API. Der Pruefstand und der Offline-Nachbau in
-- docs/puls/ rechnen mit GENAU dieser Funktion und nicht mit einer Kopie davon - sonst prueft
-- der Nachweis sich selbst.
--
-- Koordinaten: x nach rechts, y nach UNTEN, Ursprung oben links. Rueckgabe: acht Rechtecke in
-- fester Reihenfolge (W.ZONEN) mit ihrem TexCoord-Fenster {links, rechts, oben, unten}.
-- Zusicherung: die acht Rechtecke ueberschneiden sich paarweise NICHT.
-- ---------------------------------------------------------------------------------------------
W.ZONEN = { "ecke_ol", "ecke_or", "ecke_ul", "ecke_ur", "oben", "unten", "links", "rechts" }

function W.randbreite(breite, hoehe)
    breite = tonumber(breite) or 1920
    hoehe = tonumber(hoehe) or 1080
    local kurz = (breite < hoehe) and breite or hoehe
    local r = kurz * W.RAND_ANTEIL
    if r < W.RAND_MIN then r = W.RAND_MIN end
    if r > W.RAND_MAX then r = W.RAND_MAX end
    -- Zwei gegenueberliegende Baender duerfen sich nie in der Mitte treffen. Bei 0,15 ist das
    -- nie knapp; der Deckel steht trotzdem da, weil RAND_MIN sonst auf einem winzigen UIParent
    -- genau das anrichten koennte.
    local deckel = kurz * 0.4
    if r > deckel then r = deckel end
    return r
end

function W.zonenplan(breite, hoehe)
    breite = tonumber(breite) or 1920
    hoehe = tonumber(hoehe) or 1080
    local r = W.randbreite(breite, hoehe)
    local e = W.TEX_EPS
    local p = {
        -- Ecken: die Kachel liegt so, dass u = 0 / v = 0 am Bildschirmrand klebt.
        { name = "ecke_ol", x = 0,          y = 0,          b = r,             h = r,
          tex = { 0, 1, 0, 1 } },
        { name = "ecke_or", x = breite - r, y = 0,          b = r,             h = r,
          tex = { 1, 0, 0, 1 } },
        { name = "ecke_ul", x = 0,          y = hoehe - r,  b = r,             h = r,
          tex = { 0, 1, 1, 0 } },
        { name = "ecke_ur", x = breite - r, y = hoehe - r,  b = r,             h = r,
          tex = { 1, 0, 1, 0 } },
        -- Kanten: sie beginnen und enden BEI der Eckbreite. Kein gemeinsamer Pixel mit einer Ecke.
        -- Ihr Verlauf ist die letzte Spalte (u nahe 1) bzw. die letzte Zeile (v nahe 1) der
        -- Eck-Kachel - dort ist die Kachel per Konstruktion genau das 1-D-Randprofil.
        { name = "oben",    x = r,          y = 0,          b = breite - 2*r,  h = r,
          tex = { 1 - e, 1, 0, 1 } },
        { name = "unten",   x = r,          y = hoehe - r,  b = breite - 2*r,  h = r,
          tex = { 1 - e, 1, 1, 0 } },
        { name = "links",   x = 0,          y = r,          b = r,             h = hoehe - 2*r,
          tex = { 0, 1, 1 - e, 1 } },
        { name = "rechts",  x = breite - r, y = r,          b = r,             h = hoehe - 2*r,
          tex = { 1, 0, 1 - e, 1 } },
    }
    p.rand = r
    p.breite, p.hoehe = breite, hoehe
    return p
end

-- REVIEW: kein Frame-Name -> kein zusaetzlicher Global
local f = CreateFrame("Frame", nil, UIParent)
f:SetFrameStrata("FULLSCREEN")
f:SetAllPoints(UIParent)
f:EnableMouse(false)
f:SetAlpha(0)
f:Hide()
W.frame = f

-- ---------------------------------------------------------------------------------------------
-- W9: Die acht Zonen. Sie werden EINMAL angelegt; pro Puls werden nur Mass, TexCoord, Farbe und
-- Alpha nachgezogen. Keine Frames, kein OnUpdate, nichts, was pro Bild laeuft.
-- ---------------------------------------------------------------------------------------------
local zonen, zonenNach = {}, {}
for i = 1, 8 do
    local t = f:CreateTexture(nil, "BACKGROUND")
    if t.SetBlendMode then pcall(t.SetBlendMode, t, "ADD") end
    t:Hide()
    zonen[i] = t
    zonenNach[W.ZONEN[i]] = t
end
W.zonen = zonen
W.zonenNach = zonenNach
-- W7-Erbe: der Pruefstand und /lyra debug kennen diesen Namen. Er zeigt auf die erste Zone.
W.vignette = zonen[1]
-- W7-Erbe: "die vier Baender" sind jetzt die vier KANTEN-Zonen (oben, unten, links, rechts).
W.raender = { zonenNach.oben, zonenNach.unten, zonenNach.links, zonenNach.rechts }

-- Traegt die Eck-Kachel? Auf einem Client ohne die Datei gibt GetTexture nil, false oder ""
-- zurueck; manche Wege geben eine FileID (Zahl) zurueck, und die ist ein gueltiges Ergebnis.
-- W9: Der Test darf jetzt grosszuegiger sein als in W7. Damals haette ein falsch positives
-- Ergebnis eine deckende weisse Flaeche ueber den GANZEN Bildschirm gelegt; heute deckt keine
-- Zone die Bildmitte, der schlimmste Fall ist also genau das Bild des Rueckfalls.
do
    local ok = pcall(zonen[1].SetTexture, zonen[1], W.TEXTUR)
    local wert
    if ok and zonen[1].GetTexture then
        local o, v = pcall(zonen[1].GetTexture, zonen[1])
        wert = o and v or nil
    end
    local gut = (type(wert) == "string" and wert ~= "") or (type(wert) == "number" and wert > 0)
    W.weich = (ok and gut) and true or false
end
for i = 1, 8 do
    local t = zonen[i]
    if W.weich then
        if i > 1 then pcall(t.SetTexture, t, W.TEXTUR) end
    else
        local ok = pcall(t.SetTexture, t, W.WEISS)
        if not ok and t.SetColorTexture then pcall(t.SetColorTexture, t, 1, 1, 1, 1) end
        if t.SetTexCoord then pcall(t.SetTexCoord, t, 0, 1, 0, 1) end
    end
end

-- W9: Verankerung je Zone. Die Anker haengen am Frame, nicht an gerechneten Absolutpunkten -
-- damit stimmt die Geometrie auch dann noch, wenn jemand mitten im Spiel die Aufloesung oder
-- die UI-Skalierung wechselt und wir zwischen zwei Pulsen nichts davon mitbekommen.
local function anker(t, ...)
    pcall(t.ClearAllPoints, t)
    local n = select("#", ...)
    for i = 1, n, 4 do
        local mein, sein, dx, dy = select(i, ...)
        pcall(t.SetPoint, t, mein, f, sein, dx, dy)
    end
end
local legeAn = {
    ecke_ol = function(t, r) anker(t, "TOPLEFT", "TOPLEFT", 0, 0); t:SetWidth(r); t:SetHeight(r) end,
    ecke_or = function(t, r) anker(t, "TOPRIGHT", "TOPRIGHT", 0, 0); t:SetWidth(r); t:SetHeight(r) end,
    ecke_ul = function(t, r) anker(t, "BOTTOMLEFT", "BOTTOMLEFT", 0, 0); t:SetWidth(r); t:SetHeight(r) end,
    ecke_ur = function(t, r) anker(t, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0); t:SetWidth(r); t:SetHeight(r) end,
    oben    = function(t, r) anker(t, "TOPLEFT", "TOPLEFT", r, 0, "TOPRIGHT", "TOPRIGHT", -r, 0); t:SetHeight(r) end,
    unten   = function(t, r) anker(t, "BOTTOMLEFT", "BOTTOMLEFT", r, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", -r, 0); t:SetHeight(r) end,
    links   = function(t, r) anker(t, "TOPLEFT", "TOPLEFT", 0, -r, "BOTTOMLEFT", "BOTTOMLEFT", 0, r); t:SetWidth(r) end,
    rechts  = function(t, r) anker(t, "TOPRIGHT", "TOPRIGHT", 0, -r, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, r); t:SetWidth(r) end,
}

-- Farbe setzen. EINE API pro Textur (SetVertexColor) - genau der Fehler aus dem W7-Befund war,
-- zwei sich ueberschreibende Farbwege in einer Funktion zu haben.
-- W10B (Roadmap 10-7): die Farbe kommt aus der gewaehlten Palette (UI/Farben.lua), wenn es sie
-- gibt. W.FARBEN bleibt der Rueckfall und der Stand "standard" - ohne UI/Farben.lua (z. B. im
-- port-Pruefstand, der nur die TOC laedt) aendert sich damit kein einziger Wert.
-- Spitze, Dauer, Riegel und W.SPITZE_MAX ruehrt die Palette NICHT an: das ist die
-- Photosensibilitaets-Grenze aus Welle 7, keine Geschmacksfrage.
local function faerbe(farbe)
    local c
    if ns.Farben and ns.Farben.puls then
        local ok, p = pcall(ns.Farben.puls, farbe)
        if ok and type(p) == "table" and p[1] then c = p end
    end
    c = c or W.FARBEN[farbe] or W.FARBEN.lila
    local r, g, b = c[1], c[2], c[3]
    for i = 1, 8 do pcall(zonen[i].SetVertexColor, zonen[i], r, g, b, 1) end
    W.hartesBand = not W.weich
    W.farbeJetzt = farbe
    return not W.hartesBand
end
W.faerbe = faerbe

local function bemesse(spitze)
    local br = (UIParent.GetWidth and UIParent:GetWidth()) or 1920
    local ho = (UIParent.GetHeight and UIParent:GetHeight()) or 1080
    local plan = W.zonenplan(br, ho)
    W.planJetzt = plan
    W.randJetzt = plan.rand
    for i = 1, 8 do
        local z, t = plan[i], zonen[i]
        legeAn[z.name](t, plan.rand)
        if W.weich and t.SetTexCoord then
            pcall(t.SetTexCoord, t, z.tex[1], z.tex[2], z.tex[3], z.tex[4])
        end
        t:SetAlpha(spitze)
        t:Show()
    end
end
W.bemesse = bemesse

-- ---------------------------------------------------------------------------------------------
-- Puls-Kurve. Frame-Alpha 0 -> 1 -> 0; die Spitze steuert die Textur-Alpha (effektiv = Produkt).
-- Stufe 3 bekommt einen Doppelschlag: auf, halb zurueck, auf, weich aus. Das ist eine FORM und
-- damit ein zweiter Traeger neben der Farbe (Recherche 10, A5).
-- Keine AnimationGroup an der Gestalt (Bewegung v3) - dies ist der eigene Puls-Frame, und die
-- Gruppe ist guarded gebaut UND hat einen Rueckfall ohne Animation.
-- ---------------------------------------------------------------------------------------------
W.DOPPEL_TAL = 0.35    -- auf welchen Anteil der Puls zwischen den zwei Schlaegen zurueckgeht

local ag, stufen        -- stufen = { anim1, anim2, anim3, anim4 }
do
    if f.CreateAnimationGroup then
        local ok, g = pcall(f.CreateAnimationGroup, f)
        if ok and g and g.CreateAnimation then
            local ok2 = pcall(function()
                local a = {}
                for i = 1, 4 do
                    a[i] = g:CreateAnimation("Alpha")
                    if not (a[i].SetFromAlpha and a[i].SetToAlpha) then error("keine Alpha-API") end
                    a[i]:SetOrder(i)
                end
                if a[1].SetSmoothing then
                    a[1]:SetSmoothing("OUT"); a[2]:SetSmoothing("IN")
                    a[3]:SetSmoothing("OUT"); a[4]:SetSmoothing("IN")
                end
                g:SetLooping("NONE")
                g:SetScript("OnFinished", function() f:SetAlpha(0); f:Hide() end)
                stufen = a
                W.anim = a   -- W6-Erbe: die Dauer bleibt von aussen umstellbar
            end)
            if ok2 then ag = g end
        end
    end
end

-- Die vier Abschnitte auf eine Dauer und eine Schlagzahl setzen.
-- 1 Schlag: 0 -> 1 -> 0, die beiden hinteren Abschnitte auf 0 s.
-- 2 Schlaege: 0 -> 1 -> TAL -> 1 -> 0.
W.dauerJetzt, W.schlaegeJetzt = nil, nil
function W.kurveSetzen(sek, schlaege)
    sek = tonumber(sek) or W.DAUER
    if sek > 1 then sek = 1 end            -- Standzeit <= 1 s, harte Zusage
    schlaege = (tonumber(schlaege) == 2) and 2 or 1
    if sek == W.dauerJetzt and schlaege == W.schlaegeJetzt then return true end
    if not (stufen and stufen[1] and stufen[1].SetDuration) then return false end
    local ok = pcall(function()
        if schlaege == 2 then
            local t = W.DOPPEL_TAL
            local d = sek / 4
            stufen[1]:SetFromAlpha(0); stufen[1]:SetToAlpha(1); stufen[1]:SetDuration(d * 0.8)
            stufen[2]:SetFromAlpha(1); stufen[2]:SetToAlpha(t); stufen[2]:SetDuration(d * 0.7)
            stufen[3]:SetFromAlpha(t); stufen[3]:SetToAlpha(1); stufen[3]:SetDuration(d * 0.7)
            stufen[4]:SetFromAlpha(1); stufen[4]:SetToAlpha(0); stufen[4]:SetDuration(d * 1.8)
        else
            stufen[1]:SetFromAlpha(0); stufen[1]:SetToAlpha(1); stufen[1]:SetDuration(sek * 0.30)
            stufen[2]:SetFromAlpha(1); stufen[2]:SetToAlpha(0); stufen[2]:SetDuration(sek * 0.70)
            stufen[3]:SetFromAlpha(0); stufen[3]:SetToAlpha(0); stufen[3]:SetDuration(0)
            stufen[4]:SetFromAlpha(0); stufen[4]:SetToAlpha(0); stufen[4]:SetDuration(0)
        end
    end)
    if ok then W.dauerJetzt, W.schlaegeJetzt = sek, schlaege end
    return ok
end
-- W6-Erbe: die alte Schnittstelle bleibt, damit Sinne/Welle6.lua nichts wissen muss.
function W.dauerSetzen(sek) return W.kurveSetzen(sek, W.schlaegeJetzt or 1) end

-- Rueckfall ohne Animations-API: die Kurve in Schritten ueber ns.Compat.After. Kein OnUpdate,
-- kein Ticker mit 0 s - beides steht im Kontrakt.
W.SCHRITTE = 8
local function pulsOhneAnimation(sek, schlaege)
    local n = W.SCHRITTE
    local dt = sek / n
    f:SetAlpha(0)
    f:Show()
    W.lauf = (W.lauf or 0) + 1
    local meinLauf = W.lauf
    for i = 1, n do
        ns.Compat.After(dt * i, function()
            if W.lauf ~= meinLauf then return end
            local p = i / n
            local a
            if schlaege == 2 then
                -- zwei Buckel ueber die Gesamtdauer, der zweite etwas kuerzer
                a = (p < 0.4) and (p / 0.4)
                    or (p < 0.55) and (1 - (p - 0.4) / 0.15 * (1 - W.DOPPEL_TAL))
                    or (p < 0.7) and (W.DOPPEL_TAL + (p - 0.55) / 0.15 * (1 - W.DOPPEL_TAL))
                    or (1 - (p - 0.7) / 0.3)
            else
                a = (p < 0.3) and (p / 0.3) or (1 - (p - 0.3) / 0.7)
            end
            if a < 0 then a = 0 elseif a > 1 then a = 1 end
            f:SetAlpha(a)
            if i == n then f:SetAlpha(0); f:Hide() end
        end)
    end
    return true
end

-- W7: Der Barrierefrei-Modus HEBT die Spitze an (Faktor) und laesst den Puls etwas laenger
-- stehen. Der Riegel dazwischen wird dafuer haerter - das ist die Photosensibilitaets-Bremse.
W.BF_DAUER = 1.0
W.BF_FAKTOR = 1.25
W.BF_RIEGEL = 6
local function barrierefrei()
    local W6 = ns.Welle6
    return (W6 and W6.an and W6.an("barrierefrei")) and true or false
end
W.barrierefrei = barrierefrei

local function erlaubt()
    if not ns.Get("glow") then return false end
    -- W7: Streamer-Modus laesst das Gluehen aus. Ein Vollbild-Puls ist im Stream fuer die
    -- Zuschauer, nicht fuer den Spieler.
    if ns.Get("streamer") then return false end
    if ns.Regie and ns.Regie.ladeRiegelBis and GetTime() < ns.Regie.ladeRiegelBis then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
    local riegel = barrierefrei() and W.BF_RIEGEL or W.RIEGEL
    if GetTime() - (W.zuletzt or 0) < riegel then return false end   -- Photosensibilitaet
    return true
end
W.erlaubt = erlaubt

-- W.pulsStufe(stufe, farbe): der Weg, den ns.nachAusgabe geht. farbe uebersteuert die Stufenfarbe
-- (Atem bleibt blau). Rueckgabe true, wenn wirklich ein Puls losgelaufen ist.
function W.pulsStufe(stufe, farbe)
    stufe = tonumber(stufe) or 3
    if stufe < 1 then return false end
    if stufe > 3 then stufe = 3 end
    local s = W.STUFEN[stufe] or W.STUFEN[3]
    return W.puls(s.spitze, farbe or s.farbe, s.dauer, s.schlaege)
end

-- W.puls(spitze, farbe [, dauer, schlaege]): einmaliger Puls. Die alte Zwei-Argument-Form bleibt.
function W.puls(spitze, farbe, dauer, schlaege)
    if not erlaubt() then return false end
    spitze = tonumber(spitze) or W.SPITZE
    dauer = tonumber(dauer) or W.DAUER
    schlaege = (tonumber(schlaege) == 2) and 2 or 1
    if barrierefrei() then
        spitze = spitze * W.BF_FAKTOR
        if dauer < W.BF_DAUER then dauer = W.BF_DAUER end
    end
    if dauer > 1 then dauer = 1 end
    if spitze > W.SPITZE_MAX then spitze = W.SPITZE_MAX elseif spitze < 0 then spitze = 0 end
    faerbe(farbe)
    -- Rueckfall (flache Zonen): gedeckelt, weil eine harte Flaeche staerker wirkt als ein
    -- Verlauf - Photosensibilitaet, Recherche 02 2.3.
    if W.hartesBand and spitze > W.SPITZE_HART then spitze = W.SPITZE_HART end
    bemesse(spitze)
    W.spitzeJetzt, W.zuletzt = spitze, GetTime()
    if ag and W.kurveSetzen(dauer, schlaege) then
        local ok = pcall(function()
            if ag:IsPlaying() then ag:Stop() end
            f:SetAlpha(0)
            f:Show()
            ag:Play()
        end)
        if ok then W.wegJetzt = "anim"; return true end
    end
    W.wegJetzt = "schritte"
    return pulsOhneAnimation(dauer, schlaege)
end

function W.aus()
    W.lauf = (W.lauf or 0) + 1     -- laufende Schritt-Kette entwerten
    if ag and ag.IsPlaying and ag:IsPlaying() then pcall(ag.Stop, ag) end
    f:SetAlpha(0)
    f:Hide()
end

ns.nachAusgabe(function(id, e)
    if not e then return end
    -- DESIGN-V3 A-5: die Verzweigung haengt an der STUFE, nicht an der Klasse.
    local stufe = tonumber(e.stufe) or ((e.klasse == "warn") and 2 or 0)
    if stufe < 1 then return end
    -- W7: Stufe 1 und 2 pulsen jetzt ebenfalls - dezent. Bis 0.10.0 war der Bildschirmrand ein
    -- Ja/Nein-Kanal (nur Stufe 3); drei unterscheidbare Stufen tragen mehr und stoeren weniger,
    -- weil die unteren beiden deutlich schwaecher sind als der alte Einheitspuls.
    -- Atem-Alarm bleibt blau (Wasser ist blau, das ist gelernt).
    local farbe = (type(id) == "string" and id:find("^ATEM")) and "blau" or nil
    W.pulsStufe(stufe, farbe)
end)

-- Sicherheitsnetz: Tod/Ladebildschirm brechen einen laufenden Puls ab
ns.on("PLAYER_DEAD", W.aus)
ns.on("PLAYER_ENTERING_WORLD", W.aus)

function W.stand()
    return W.weich, W.hartesBand, W.wegJetzt, W.spitzeJetzt, W.farbeJetzt, W.dauerJetzt,
           W.schlaegeJetzt, W.randJetzt
end
