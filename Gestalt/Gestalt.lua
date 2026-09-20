-- Gestalt/Gestalt.lua - Lyras Bild: PNG-Sheets 512x512 (ein Frame je Sheet, Figur zentriert, Fuesse y=500),
-- Miene mit Haltezeit, Pose davor, Grundstimmung (kampf/rast/sonst), Drag/Groesse/Sperre.
-- Zwei Ansichten (Einstellung "ansicht", Default portrait):
--   portrait - VORGESCHNITTENE runde Textur bilder/rund/<miene>.png (29 x 128x128, Anker der jeweiligen
--              Miene eingebacken, dunkle Scheibe und weicher Aussenschatten schon in der Datei).
--              Kein Masken-API, kein SetTexCoord, keine Geometrie-Skalierung - nur SetTexture.
--              Darunter bilder/portrait_scheibe.png, darueber bilder/portrait_ring2.png (Strich 10/256).
--   figur    - ganze Figur wie bisher aus den 512er-Sheets, dazu der Sockel-Schatten bilder/schatten.png.
-- DESIGN-V3 A-1 (17.09.2026): der ganze Masken-Zweig ist ersatzlos entfallen (G.MASKE_PFAD, maskeSetzen,
--   maskeErlaubt, maskeAktiv, Einstellung "maske", Masken-Selbsttest samt Not-Abschaltung, G.KOPF,
--   texCoord() im Portrait-Zweig, quadratischer Fallback). Begruendung: Maske und SetTexCoord vertragen
--   sich in Era nicht (docs/fix4), der Umweg ueber die Geometrie zog je Portrait ein 512er-Sheet auf das
--   Fuenffache. Die runden PNGs sind fertig geschnitten und loesen zugleich Befund 1 aus docs/design-v3.md
--   (bei 7 von 29 Mienen sass das feste Kopffenster falsch, bei 2 war der Kreis fast leer).
-- Groesse: DESIGN-V3 A-2 - das Portrait haengt NICHT mehr an "scale": G.PORTRAIT_KANTE
--   (klein 96 | mittel 112 | gross 128). "scale" bleibt allein die Rechengroesse der Ganzfigur
--   (512 * scale). /lyra groesse <zahl> wirkt weiter auf beides (Portrait = 160 * wert, 48..256).
-- Bewegung v3 (FIX4, 17.09.2026) - siehe DESIGN.md Abschnitt "Bewegung v3" und docs/fix4-2026-09-17.md:
--   Atmen und Nicken sind KEINE Translation-Animationen mehr, sondern ein ABSOLUT gesetzter
--   Anker-Versatz (ein C_Timer-Takt von 0.15 s setzt bewegt:SetPoint(... , 0, weg*sin(t))).
--   Absolut gesetzt heisst: der Wert wird nie fortgeschrieben, er kann sich also nicht aufschaukeln.
--   Nur der Warn-Ruck ist noch eine Translation - einmalig, Summe der Versaetze 0, und er wird
--   NIE mitten im Lauf gestoppt (ein zweiter Ruck haengt sich an, statt den ersten abzubrechen).
-- FIX1 (17.09.2026): Das Atmen lief als Scale-Gruppe mit SetLooping("REPEAT") -> die Gestalt wuchs
--   mit jedem Atemzug. Seitdem gilt fuer das ganze Addon: KEINE Scale-Animation mehr.
-- FIX3 (17.09.2026): Nicken und Warn-Ruck auf getrennte Ebenen, Neu-Verankerung im Not-Aus,
--   Drift-Waechter. Hat NICHT gereicht - siehe FIX4.
-- FIX4 (17.09.2026), Ursache des Hochschwebens: Haralds Screenshot zeigt den Ring rund 170 px ueber
--   dem GameTooltip, der per ANCHOR_TOP an G.frame haengt, und die Maus-Hitbox lag beim Tooltip,
--   nicht beim Ring. Der Rahmen stand also richtig, nur seine ZEICHNUNG war verschoben: der
--   Translation-Versatz einer abgebrochenen AnimationGroup ist ein Render-Versatz auf der Region.
--   Er ueberlebt Stop(), und ClearAllPoints/SetPoint fasst ihn nicht an (FIX3 verankerte deshalb
--   ins Leere), GetCenter() weist ihn nicht aus (der Drift-Waechter war blind). Weil Atmen und
--   Nicken beide ERST nach oben gingen, war jeder Rest >= 0 und summierte sich einseitig auf.
--   Konsequenz: die Dauerbewegung darf gar keine Translation mehr sein.
-- Frame-Baum: f (Maus, Position, Kampf-Alpha) > bewegt (EINE Animationsebene) >
--   schatten/grund/tex/tex2/ring. Genau EINE Animationsgruppe fuer Bewegung (der Ruck).
-- Regungen (G.regung): reine Optik ohne Regie, ohne Text, ohne Ton - Leerlauf-Mikrowechsel alle
--   45-90 s, Hover, Drag. Sie weichen jeder Ereignis-Miene (G.ticker), jeder stehenden Blase und
--   jedem offenen Fenster (Dialog, Menue) aus - eine Stelle: G.regungFrei() (REVIEW4).
--   Einzige Ausnahme: das Ziehen erzwingt "shocked", das ist eine direkte Maus-Aktion.
-- Jede Animations-API ist guarded; ohne sie: keine Animation, nie ein Fehler.
-- API: CreateFrame, Texture:SetTexture/SetTexCoord/SetBlendMode, AnimationGroup,
--   C_Timer, GameTooltip. Eigene Frames, nichts Fremdes.
local ADDON, ns = ...
local G = {}
ns.Gestalt = G

G.SHEET = { w = 512, h = 512, fw = 512, fh = 512, cols = 1 }   -- neu gepackt: ein Frame je Sheet, Figur zentriert, Fuesse auf y=500
-- DESIGN-V3 A-2: Portraitkante je Preset, unabhaengig von "scale". Die drei Werte sind genau die
-- Groessen, fuer die bilder/rund/*.png gerendert ist (128 = native Kante, 112 und 96 saubere
-- Verkleinerungen). Default mittel = 112 (docs/design-v3.md b.3).
G.PORTRAIT_KANTE = { klein = 96, mittel = 112, gross = 128 }
G.PORTRAIT_STANDARD = 112   -- wenn weder Preset noch scale etwas Brauchbares hergeben
G.PORTRAIT_JE_SCALE = 160   -- /lyra groesse <zahl>: Portrait = 160 * wert
G.PORTRAIT_MIN, G.PORTRAIT_MAX = 48, 256
G.GROESSEN = { klein = 0.35, mittel = 0.5, gross = 0.7 }   -- scale der GANZFIGUR (512 * scale)
G.POSE_DAUER = 3
G.FADE_DAUER = 0.25
G.RING = { 0.706, 0.549, 1.0 }          -- #b48cff
G.RING_KONTRAST = { 1.0, 1.0, 1.0 }     -- Kontrast-Modus: die Grundfarbe ist Weiss
G.RING_WARN = { 1.0, 0.478, 0.353 }     -- #ff7a5a (Stufe 2)
G.RING_ALARM = { 1.0, 0.251, 0.251 }    -- #ff4040 (Stufe 3)
G.RING_DAUER = 4                        -- s, wie lange Ring/Halo nach einer Warnung stehen bleiben
-- DESIGN-V3 A-3: die Warnstufe geht ueber FORM, GROESSE und BEWEGUNG, nicht ueber Farbe.
-- Befund 3 aus docs/design-v3.md: #ff7a5a gegen #b48cff sind 1,01:1 - im Graustufenbild und im
-- Augenwinkel ist der Farbwechsel exakt nicht vorhanden. Farbe ist der vierte, redundante Kanal.
--   Stufe 0  nichts
--   Stufe 1  nur das Icon in der Blase (Gestalt/Blase.lua)
--   Stufe 2  Halo erscheint, ruhig, 1,15 x Kante
--   Stufe 3  Halo pulst (Alpha-Sinus im BESTEHENDEN Takt, keine Animationsgruppe - Hausregel fix4)
--            + Ring doppelt dick (zweite Ringtextur, 4 px groesser)
G.HALO = {
    [2] = { faktor = 1.15, alpha = 0.75, puls = false },
    [3] = { faktor = 1.30, alpha = 1.00, puls = true, von = 0.55, bis = 1.00, dauer = 0.9 },
}
G.RING_DOPPEL_PLUS = 4                  -- px, um die die zweite Ringtextur groesser verankert wird
-- Leicht violett statt neutralschwarz: passt zur Arkan-Farbwelt und verschwindet auf gruenem Gras
-- nicht als "Loch". Die Deckkraft steckt schon in bilder/schatten.png (Spitze 0,52) -> Alpha 1.
G.SCHATTEN_FARBE = { 0.35, 0.22, 0.55, 1 }
-- Leerlauf-Mikrowechsel (design-v2.md 3.2)
G.MIKRO = { "hmm", "thinking", "interested", "amused", "wonder", "smirk" }
G.MIKRO_MIN, G.MIKRO_MAX, G.MIKRO_DAUER = 45, 90, 2.5
G.aktuell, G.grund, G.bisWann, G.ticker = nil, "neutral", 0, nil

-- REVIEW: kein Frame-Name -> kein zusaetzlicher Global (Regel: nur LyraGestaltDB & Co.)
local f = CreateFrame("Frame", nil, UIParent)
f:SetFrameStrata("MEDIUM")
f:SetMovable(true)
f:EnableMouse(true)
-- FIX5: Mausrad ueber Lyra wechselt die Groesse (klein/mittel/gross). Eigener, nicht-secure Frame,
-- also auch im Kampf erlaubt. Das Rad wird nur ueber IHR geschluckt, ueberall sonst zoomt es weiter.
f:EnableMouseWheel(true)
f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")
local gezogen = false
G.frame = f

-- FIX4: EINE Bewegungsebene statt der drei verschachtelten atem > nick > ruck. Drei gleichzeitig
-- animierte Frames waren nicht zu beherrschen: jede Gruppe legt ihren Render-Versatz auf ihre
-- Region, die Kinder erben ihn, und ein Abbruch irgendwo in der Kette hinterlaesst einen Rest,
-- den man weder messen (GetCenter sieht ihn nicht) noch per Anker wegnehmen kann.
-- EIN Anker: Blizzards eigene Positions-Animation ScriptAnimationUtil.lua (classic_era) liest
-- region:GetPoint(1) und setzt je Tick absolut neu - das setzt genau einen Ankerpunkt voraus.
local bewegt = CreateFrame("Frame", nil, f)
bewegt:SetPoint("CENTER", f, "CENTER", 0, 0)
G.bewegtFrame = bewegt
-- Alte Namen bleiben als Verweis auf dieselbe Ebene (Harness, Diagnose, fremde Leser)
G.atemFrame, G.nickFrame, G.ruckFrame = bewegt, bewegt, bewegt
local ruckF = bewegt

-- Sockel-Schatten (nur Ansicht "figur"): liegt auf der Bewegungsebene, macht also
-- Atmen/Nicken/Ruck mit und klebt nicht am Bildschirm.
local schatten = ruckF:CreateTexture(nil, "BACKGROUND")
schatten:SetTexture(ns.PFAD .. "bilder\\schatten.png")
schatten:SetVertexColor(G.SCHATTEN_FARBE[1], G.SCHATTEN_FARBE[2], G.SCHATTEN_FARBE[3], G.SCHATTEN_FARBE[4])
schatten:Hide()
G.schatten = schatten

-- DESIGN-V3 A-3: Warn-Halo. Weicher, breiter Ring (bilder/portrait_glow.png, weiss -> einfaerbbar),
-- BlendMode ADD, liegt UNTER Scheibe und Gesicht und ragt ueber die Portraitkante hinaus
-- (1,15 x bei Stufe 2, 1,30 x bei Stufe 3). Im Ruhezustand Alpha 0 und versteckt.
-- Eigener Anker (CENTER auf bewegt) statt SetAllPoints - er ist absichtlich groesser als die Ebene.
local halo = ruckF:CreateTexture(nil, "BACKGROUND", nil, -1)
halo:SetPoint("CENTER", ruckF, "CENTER", 0, 0)
halo:SetTexture(ns.PFAD .. "bilder\\portrait_glow.png")
if halo.SetBlendMode then pcall(halo.SetBlendMode, halo, "ADD") end
halo:SetAlpha(0)
halo:Hide()
G.halo = halo

-- Portrait-Grund: dunkle Scheibe mit weichem Aussenschatten (bilder/portrait_scheibe.png).
-- DESIGN-V3 A-3/B5: ohne dunklen Grund verschwindet der Ring auf Schnee (1,26:1); gegen die
-- Scheibe sind es 7,31:1. Frueher eine quadratische SetColorTexture, die von der Maske rund
-- geschnitten wurde - ohne Maske waere das ein sichtbares Quadrat hinter dem runden Portrait.
-- Fallback, falls die Datei nicht laedt: wieder die Farbflaeche (dann eckig, aber nie ein Fehler).
local grund = ruckF:CreateTexture(nil, "BACKGROUND", nil, 1)
grund:SetAllPoints(ruckF)
G.SCHEIBE_PFAD = ns.PFAD .. "bilder\\portrait_scheibe.png"
do
    local ok = pcall(grund.SetTexture, grund, G.SCHEIBE_PFAD)
    local wert = ok and grund.GetTexture and select(2, pcall(grund.GetTexture, grund)) or nil
    if not ok or wert == nil or wert == "" then
        if grund.SetColorTexture then grund:SetColorTexture(0.078, 0.055, 0.125, 1)
        else pcall(grund.SetTexture, grund, 0.078, 0.055, 0.125, 1) end
    end
end
grund:Hide()
G.grundTex = grund

local tex = ruckF:CreateTexture(nil, "ARTWORK")
tex:SetAllPoints(ruckF)
G.tex = tex
-- Zweite Textur fuer den Crossfade: liegt ueber tex, normal unsichtbar
local tex2 = ruckF:CreateTexture(nil, "ARTWORK", nil, 1)
tex2:SetAllPoints(ruckF)
tex2:SetAlpha(0)
tex2:Hide()
G.tex2 = tex2

-- Ring um das Portrait. DESIGN-V3 B4: portrait_ring2.png, Strich 10 von 256 = 4,4 px bei Kante 112
-- (3,9 % des Durchmessers). Der alte portrait_ring.png (Strich 7 = 3,1 px) war zu duenn.
-- Weisser Kreisring -> per VertexColor eingefaerbt.
G.RING_PFAD = ns.PFAD .. "bilder\\portrait_ring2.png"
local ring = ruckF:CreateTexture(nil, "OVERLAY")
ring:SetAllPoints(ruckF)
ring:SetTexture(G.RING_PFAD)
ring:SetVertexColor(G.RING[1], G.RING[2], G.RING[3], 1)
ring:Hide()
G.ring = ring

-- Zweite Ringtextur: bei Stufe 3 liegt sie 4 px groesser darueber und macht den Ring optisch
-- doppelt so dick. Kein neues Asset, keine Skalierung (Hausregel fix4) - nur ein zweiter Anker.
local ring2 = ruckF:CreateTexture(nil, "OVERLAY", nil, 1)
ring2:SetPoint("CENTER", ruckF, "CENTER", 0, 0)
ring2:SetTexture(G.RING_PFAD)
ring2:SetVertexColor(G.RING_ALARM[1], G.RING_ALARM[2], G.RING_ALARM[3], 1)
ring2:Hide()
G.ring2 = ring2

-- DESIGN-V3 A-1: kein Masken-API mehr. Der runde Ausschnitt steckt in der Datei.
-- bilder/rund/<miene>.png: 29 Stueck, 128 x 128, erzeugt und geprueft von tools/mach-rund-portraits.py
-- (dort steht die Anker-Tabelle als einzige Quelle). Jede enthaelt fertig: weicher Aussenschatten,
-- dunkle Scheibe #140e20, Gesicht kreisrund freigestellt mit dem RICHTIGEN Anker der Miene.
-- G.RUND ist die Whitelist der wirklich ausgelieferten runden Dateien - SetTexture meldet eine
-- fehlende Datei nicht zuverlaessig, deshalb wird hier gefragt und nicht geraten.
-- Fehlt eine: Fallback auf "neutral" (lieber das falsche Gesicht als ein leerer Ring).
G.RUND_ORDNER = ns.PFAD .. "bilder\\rund\\"
G.RUND = { alert = true, amused = true, angry = true, anxious = true, aversion = true, concerned = true, defeated = true, depressed = true, grossedout = true, happy = true, hmm = true, hurt = true, interested = true, neutral = true, overjoyed = true, sad = true, scared = true, shocked = true, shy = true, smirk = true, smug = true, terrified = true, thinking = true, touched = true, upset = true, veryhappy = true, victory = true, whatever = true, wonder = true }

local function sheetPfad(miene)
    return ns.PFAD .. "bilder\\" .. miene .. ".png"
end
local function rundPfad(miene)
    if not (miene and G.RUND[miene]) then
        if miene then ns.debug("Rundes Portrait fehlt: " .. tostring(miene) .. " -> neutral") end
        miene = "neutral"
    end
    return G.RUND_ORDNER .. miene .. ".png"
end
-- Der einzige Ort, an dem entschieden wird, WELCHE Datei eine Miene bekommt.
local function mienenPfad(miene)
    if G.istPortrait() then return rundPfad(miene) end
    return sheetPfad(miene)
end
G.mienenPfad = mienenPfad

-- ---------------------------------------------------------------------------------------------
-- Ansicht und Groesse
-- ---------------------------------------------------------------------------------------------
function G.istPortrait()
    return ns.Get("ansicht") ~= "figur"     -- alles ausser "figur" ist Portrait (Default)
end

-- Kantenlaenge des Portraits in px. DESIGN-V3 A-2: normalerweise aus dem Preset (96/112/128),
-- NICHT aus scale. Nur wenn scale nicht (mehr) zum Preset passt - also nach /lyra groesse <zahl> -
-- rechnet die Kante wieder aus scale (160 * wert). Grund: UI/Settings.lua koppelt groesse -> scale
-- nur in eine Richtung; ein Zwischenwert laesst "groesse" auf dem alten Preset stehen, und dann
-- duerfte das Preset nicht mehr das letzte Wort haben.
function G.portraitKante()
    local sc = tonumber(ns.Get("scale")) or 0.5
    local name = ns.Get("groesse")
    local px
    local preset = name and G.PORTRAIT_KANTE[name]
    if preset and math.abs(sc - (G.GROESSEN[name] or -1)) < 0.001 then
        px = preset
    else
        px = math.floor(G.PORTRAIT_JE_SCALE * sc + 0.5)
    end
    if px ~= px or px <= 0 then px = G.PORTRAIT_STANDARD end   -- NaN/Unsinn abfangen
    if px < G.PORTRAIT_MIN then px = G.PORTRAIT_MIN elseif px > G.PORTRAIT_MAX then px = G.PORTRAIT_MAX end
    return px
end

-- ---------------------------------------------------------------------------------------------
-- Animations-Helfer (alles guarded; Rueckgabe nil = keine Animation)
-- ---------------------------------------------------------------------------------------------
local function neueGruppe(region)
    if not region or not region.CreateAnimationGroup then return nil end
    local ok, ag = pcall(region.CreateAnimationGroup, region)
    if not ok or not ag or not ag.CreateAnimation then return nil end
    return ag
end

local function neueAnim(ag, typ)
    local ok, a = pcall(ag.CreateAnimation, ag, typ)
    if ok and a then return a end
    return nil
end

local function verschiebe(a, dx, dy, dauer, order)
    if not a.SetOffset then return false end
    a:SetOffset(dx, dy)
    a:SetDuration(dauer)
    a:SetOrder(order)
    if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
    return true
end

local function blende(a, von, bis, dauer, order)
    if a.SetFromAlpha and a.SetToAlpha then
        a:SetFromAlpha(von); a:SetToAlpha(bis)
    elseif a.SetChange then
        a:SetChange(bis - von)
    else
        return false
    end
    a:SetDuration(dauer)
    a:SetOrder(order)
    return true
end

-- ---------------------------------------------------------------------------------------------
-- BEWEGUNG v3 (FIX4). Siehe Gestalt/DESIGN.md "Bewegung v3".
--
-- Dauerbewegung (Atmen, Nicken) ist KEINE Animation mehr, sondern ein absolut gesetzter
-- Anker-Versatz im C_Timer-Takt. Das ist genau das Muster, mit dem Blizzard selbst Frames
-- bewegt, wenn die echte Position stimmen muss (Blizzard_SharedXML/ScriptAnimationUtil.lua,
-- classic_era): einen Ankerpunkt merken und je Tick neu SETZEN statt zu addieren.
--   * absolut gesetzt  -> kann sich nicht aufschaukeln, egal was der Client mit Animationen tut
--   * kein Render-Versatz -> Zeichnung und Hitbox koennen nicht auseinanderlaufen
--   * GetCenter() weist die Bewegung aus -> der Drift-Waechter kann sie ueberhaupt messen
-- Einziges bewegtes AnimationGroup-Stueck bleibt der Warn-Ruck: einmalig, Summe der Versaetze 0,
-- und er wird NIE mitten im Lauf gestoppt (ein zweiter Ruck haengt sich hinten an).
-- ---------------------------------------------------------------------------------------------
G.TAKT = 0.15                 -- s, Bewegungstakt (C_Timer, kein OnUpdate)
G.ATEM = { dauer = 4.0, weg = 1 }        -- Figur: Atmen +-1 px in 4 s
G.NICK = { dauer = 1.2, weg = 1 }        -- Figur: Nicken +-1 px in 1.2 s (FIX4: war 2 px / 0.35 s)
G.PULS_ATEM = { dauer = 4.0, von = 0.90, bis = 1.00 }   -- Portrait: Ring-Puls statt Bewegung
G.PULS_NICK = { dauer = 1.5, von = 0.80, bis = 1.00 }   -- Portrait: Ring-Puls beim Sprechen
G.RUCK_FIGUR    = { [2] = 3, [3] = 5 }   -- px Ausschlag je Warnstufe
G.RUCK_PORTRAIT = { [2] = 2, [3] = 2 }   -- Portrait ist klein: 2 px reichen, dazu der Ring-Blitz
G.RUCK_TEIL = 0.1             -- s je Teilstueck, 3 Teile = 0.3 s
G.RING_BLITZ = 0.6            -- s Ring-Aufleuchten nach einer Warnung (Portrait)

local zustand = "atem"        -- atem | nick
local phase0 = 0              -- GetTime(), an dem der Zustand begann (jeder faengt bei Versatz 0 an)
local versatzY = 0            -- zuletzt GESETZTER Versatz (nicht aufaddiert!)
local ruckLaeuft = false
local ringBlitzBis = 0
local taktTicker, nickTicker

-- Der einzige Weg, auf dem die Bewegungsebene ihren Ort bekommt. Absolut, nie relativ.
local function setzeVersatz(dy)
    if versatzY == dy then return end
    versatzY = dy
    pcall(bewegt.SetPoint, bewegt, "CENTER", f, "CENTER", 0, dy)
end

-- Harte Nullstellung des Ankers (auch wenn versatzY schon 0 zu sein glaubt)
local function nullAnker()
    versatzY = nil
    pcall(function() bewegt:ClearAllPoints(); bewegt:SetPoint("CENTER", f, "CENTER", 0, 0) end)
    versatzY = 0
end

-- FIX1-Erbe: Not-Aus setzt jede Transformation der Bewegungsebene zurueck.
function G.notAus()
    if bewegt.SetScale then pcall(bewegt.SetScale, bewegt, 1) end
    nullAnker()
end

-- FIX4: letztes Mittel gegen einen reinen Render-Versatz, den weder Anker noch GetCenter fassen.
-- Eine Region, die aus- und wieder eingeblendet wird, wird neu ausgelegt; laufende Gruppen auf ihr
-- werden dabei beendet. Kostet ein Bild und ist mit blossem Auge nicht zu sehen.
function G.nullstellung()
    G.ruckRest = 0                 -- angehaengte Rucke fallen weg
    G.notAus()                     -- Anker in jedem Fall zurueck
    -- Einen LAUFENDEN Ruck nie abbrechen - auch nicht durch das Hide. Er ist in 0.3 s von selbst
    -- wieder bei Summe 0; ein Abbruch waere genau der Rest, den wir loswerden wollen.
    -- (Eine verborgene Region beendet ihre Animationsgruppen - das waere ein Abbruch mitten
    -- im Lauf.) Der naechste Waechter-Takt raeumt in 3 s nach, falls doch etwas liegen bleibt.
    if ruckLaeuft or (G.ruckAG and G.ruckAG.IsPlaying and G.ruckAG:IsPlaying()) then return end
    if f:IsShown() then pcall(function() bewegt:Hide(); bewegt:Show() end) end
    pcall(ring.SetAlpha, ring, 1)
end

-- ---------------------------------------------------------------------------------------------
-- DESIGN-V3 A-3: Warn-Optik im Portrait. Form, Groesse und Bewegung tragen die Stufe; die Farbe
-- ist der redundante vierte Kanal (Befund 3: #ff7a5a gegen #b48cff sind 1,01:1).
--   0 / 1  Ring in der Grundfarbe, kein Halo, kein Doppelring
--   2      Halo erscheint (1,15 x Kante, Alpha 0,75), Ring orange-rot
--   3      Halo pulst 0,55 <-> 1,00 in 0,9 s (1,30 x Kante), Ring rot UND doppelt dick
-- Nach G.RING_DAUER (4 s) faellt alles auf Stufe 0 zurueck.
-- Der Puls laeuft im bestehenden 0,15-s-Takt als Alpha-Sinus - KEINE Animationsgruppe, keine
-- Skalierung (Hausregeln Bewegung v3, docs/fix4-2026-09-17.md).
-- ---------------------------------------------------------------------------------------------
local ringTicker
local warnStufe = 0
local haloPhase0 = 0

-- Grundfarbe des Rings: Lila; im Kontrast-Modus Weiss (design-v3: der Kontrast-Modus ist fertig,
-- er faerbt alles auf reines Schwarz/Weiss).
local function ringGrund()
    return ns.Get("kontrast") and G.RING_KONTRAST or G.RING
end
local function ringFarbe(c)
    ring:SetVertexColor(c[1], c[2], c[3], 1)
    ring2:SetVertexColor(c[1], c[2], c[3], 1)
end

-- Darf sich etwas bewegen? B-13 liefert die Einstellung "bewegung" nach; bis dahin gilt "voll".
-- "reduziert"/"aus" schalten NUR den Puls ab - der Halo selbst bleibt (er ist die Stufe).
local function pulsErlaubt()
    if G.animationenAus then return false end
    local b = ns.Get("bewegung")
    if b == "reduziert" or b == "aus" then return false end
    return true
end

-- Halo/Doppelring auf den Stand von warnStufe bringen (Groesse, Sichtbarkeit, Ruhe-Alpha).
local function warnOptikNachfuehren()
    local kante = f:GetWidth()
    if not kante or kante <= 0 then kante = G.portraitKante() end
    local h = G.HALO[warnStufe]
    if not (h and G.istPortrait()) then
        halo:SetAlpha(0); halo:Hide()
        ring2:Hide()
        return
    end
    local k = kante * h.faktor
    halo:SetSize(k, k)
    halo:SetAlpha(h.puls and pulsErlaubt() and h.bis or h.alpha)
    halo:Show()
    if warnStufe >= 3 then
        ring2:SetSize(kante + G.RING_DOPPEL_PLUS, kante + G.RING_DOPPEL_PLUS)
        ring2:Show()
    else
        ring2:Hide()
    end
end

-- G.warnOptik(stufe): Ring-Farbe + Halo + Doppelring. Stufe 1 ist optisch Stufe 0 - der Hinweis
-- steht als Icon in der Blase (A-5), nicht am Ring: in der Graustufen-Probe waeren 1 und 2 ueber
-- die Halo-Farbe nicht zu trennen, ueber "Halo da / Halo nicht da" schon.
function G.warnOptik(stufe)
    stufe = tonumber(stufe) or 0
    if not G.istPortrait() then
        warnStufe = 0
        halo:SetAlpha(0); halo:Hide(); ring2:Hide()
        return
    end
    if ringTicker then ringTicker:Cancel(); ringTicker = nil end
    if stufe >= 3 then
        warnStufe = 3
        ringFarbe(G.RING_ALARM)
    elseif stufe == 2 then
        warnStufe = 2
        ringFarbe(G.RING_WARN)
    else
        warnStufe = 0
        ringFarbe(ringGrund())
        warnOptikNachfuehren()
        return
    end
    haloPhase0 = GetTime()
    warnOptikNachfuehren()
    ringTicker = ns.Compat.NewTicker(G.RING_DAUER, function()
        ringTicker = nil
        warnStufe = 0
        ringFarbe(ringGrund())
        warnOptikNachfuehren()
    end, 1)
end
-- Altlast-Name: bis 0.6.1 hiess das G.warnRing (nur Ringfarbe).
G.warnRing = G.warnOptik
function G.warnStufe() return warnStufe end

-- Ein Takt: Versatz (Figur) bzw. Ring-Alpha (Portrait) aus einer Sinuswelle, absolut gesetzt.
-- Halo-Puls (Stufe 3): Alpha-Sinus im selben Takt. Absolut gesetzt wie jeder andere Wert der
-- Bewegung v3 - kein Fortschreiben, keine Animationsgruppe, keine Skalierung.
-- Laeuft auch waehrend eines Rucks weiter (er blockiert nur die Position, nicht die Alpha).
local function haloSchritt()
    local h = G.HALO[warnStufe]
    if not (h and h.puls and halo:IsShown()) then return end
    if not pulsErlaubt() then halo:SetAlpha(h.bis); return end
    local s = math.sin(2 * math.pi * ((GetTime() - haloPhase0) % h.dauer) / h.dauer)
    local mitte, halb = (h.von + h.bis) / 2, (h.bis - h.von) / 2
    pcall(halo.SetAlpha, halo, mitte + halb * s)
end

local function bewegungSchritt()
    if G.animationenAus or not f:IsShown() then return end
    haloSchritt()
    if ruckLaeuft then return end      -- Atmen ODER Nicken ODER Ruck, nie parallel
    local portrait = G.istPortrait()
    local p = (zustand == "nick")
        and (portrait and G.PULS_NICK or G.NICK)
        or  (portrait and G.PULS_ATEM or G.ATEM)
    local s = math.sin(2 * math.pi * ((GetTime() - phase0) % p.dauer) / p.dauer)
    if portrait then
        setzeVersatz(0)                -- im Portrait bewegt sich das Bild nicht
        if ringBlitzBis > GetTime() then
            pcall(ring.SetAlpha, ring, 1)
        else
            local mitte, halb = (p.von + p.bis) / 2, (p.bis - p.von) / 2
            pcall(ring.SetAlpha, ring, mitte + halb * s)
        end
    else
        setzeVersatz(p.weg * s)
        pcall(ring.SetAlpha, ring, 1)
    end
end
G.bewegungSchritt = bewegungSchritt

local function taktStart()
    if taktTicker or G.animationenAus then return end
    if not f:IsShown() then return end
    taktTicker = ns.Compat.NewTicker(G.TAKT, bewegungSchritt)
end
local function taktStop()
    if taktTicker then taktTicker:Cancel(); taktTicker = nil end
end

-- Zustandswechsel: immer bei Versatz 0 beginnen (sin(0) = 0) - kein Sprung, kein Rest.
local function setzeZustand(z)
    if zustand == z then return end
    zustand = z
    phase0 = GetTime()
    setzeVersatz(0)
    bewegungSchritt()
end
G.zustand = function() return zustand end

-- Alte Namen: das "Atmen" ist jetzt der Grundzustand des Takts.
local function atmenStart()
    if G.animationenAus or not f:IsShown() then return end
    nullAnker()
    if zustand ~= "nick" then phase0 = GetTime() end
    taktStart()
end
local function atmenStop()
    taktStop()
    G.notAus()
end

-- ---------------------------------------------------------------------------------------------
-- Warn-Ruck: die einzige verbliebene Translation. x-Versatz +d / -2d / +d ueber 3 x 0.1 s,
-- Summe 0, SetLooping("NONE"). Er laeuft IMMER zu Ende: kommt waehrenddessen eine zweite Warnung,
-- wird sie angehaengt (G.ruckRest), nie wird mitten im Lauf gestoppt. Damit gibt es keinen
-- Abbruch-Rest mehr - der Mechanismus, der die Gestalt hat hochschweben lassen (docs/fix4).
-- Nach jedem Lauf: nullAnker(), wie Blizzard es macht (OnFinished setzt den Punkt hart neu,
-- z. B. BossBannerToast.xml: Translation -110, OnFinished Icon:SetPoint("LEFT", 14, 0)).
-- ---------------------------------------------------------------------------------------------
local ruckA = {}
local ruckStufeAktiv = 2
G.ruckRest = 0
local ruckStart   -- forward

do
    local ag = neueGruppe(bewegt)
    if ag then
        local ok = pcall(function()
            local a1, a2, a3 = neueAnim(ag, "Translation"), neueAnim(ag, "Translation"), neueAnim(ag, "Translation")
            if not (a1 and a2 and a3
                and verschiebe(a1, 3, 0, G.RUCK_TEIL, 1)
                and verschiebe(a2, -6, 0, G.RUCK_TEIL, 2)
                and verschiebe(a3, 3, 0, G.RUCK_TEIL, 3)) then
                error("keine Translation")
            end
            ruckA = { a1, a2, a3 }
            ag:SetLooping("NONE")
            ag:SetScript("OnFinished", function()
                ruckLaeuft = false
                nullAnker()
                if G.ruckRest > 0 then
                    G.ruckRest = G.ruckRest - 1
                    ruckStart(ruckStufeAktiv)
                else
                    phase0 = GetTime()     -- Dauerbewegung wieder bei 0 aufnehmen
                end
            end)
            pcall(ag.SetScript, ag, "OnStop", function() ruckLaeuft = false; nullAnker() end)
        end)
        if ok then G.ruckAG = ag end
    end
end

local function ruckStaerke(d)
    if not ruckA[1] then return end
    pcall(function()
        ruckA[1]:SetOffset(d, 0)
        ruckA[2]:SetOffset(-2 * d, 0)
        ruckA[3]:SetOffset(d, 0)
    end)
end

ruckStart = function(stufe)
    if not G.ruckAG then return end
    ruckStufeAktiv = (tonumber(stufe) or 2) >= 3 and 3 or 2
    local tab = G.istPortrait() and G.RUCK_PORTRAIT or G.RUCK_FIGUR
    ruckStaerke(tab[ruckStufeAktiv] or 3)
    ruckLaeuft = true
    nullAnker()
    if not pcall(G.ruckAG.Play, G.ruckAG) then ruckLaeuft = false; nullAnker() end
end

function G.ruckSpielt() return ruckLaeuft end

-- G.ruck(stufe): 2 = kurzer Ruck, 3 = staerker und zweimal. Ohne Stufe wie Stufe 2.
function G.ruck(stufe)
    if G.animationenAus then return end
    if not G.ruckAG or not f:IsShown() then return end
    stufe = tonumber(stufe) or 2
    if stufe < 2 then return end
    if G.istPortrait() then
        ringBlitzBis = GetTime() + G.RING_BLITZ
        pcall(ring.SetAlpha, ring, 1)
    end
    if ruckLaeuft or G.ruckAG:IsPlaying() then
        -- FIX4: NIE mitten im Lauf stoppen. Anhaengen statt abbrechen (hoechstens zwei Wiederholungen).
        ruckStufeAktiv = stufe >= 3 and 3 or 2
        if G.ruckRest < 2 then G.ruckRest = G.ruckRest + 1 end
        return
    end
    G.ruckRest = (stufe >= 3) and 1 or 0
    ruckStart(stufe)
end

-- Spricht Lyra gerade? Stimme laeuft oder Blase steht.
local function spricht()
    local S = ns.Stimme
    if S and (S.laeuftBis or 0) > GetTime() then return true end
    local B = ns.Blase
    if B and B.sichtbar and B.sichtbar() then return true end
    return false
end

-- Nicken beim Sprechen. Der Wechsel kostet jetzt nichts mehr: es wird nur die Sinus-Formel
-- umgestellt, kein Play/Stop, also auch kein Abbruch-Rest (das war FIX3s Kernproblem).
local function nickenStop()
    if nickTicker then nickTicker:Cancel(); nickTicker = nil end
    setzeZustand("atem")
end
local function nickenStart()
    if G.animationenAus or not f:IsShown() then return end
    setzeZustand("nick")
    taktStart()
    if nickTicker then return end
    nickTicker = ns.Compat.NewTicker(0.5, function()
        if not spricht() or not f:IsShown() then nickenStop() end
    end)
end
G.nickenStart, G.nickenStop = nickenStart, nickenStop

-- ---------------------------------------------------------------------------------------------
-- Drift-Waechter: alle 3 s messen, ob die Bewegungsebene von der Gestalt abgewandert ist.
-- Er misst IMMER (FIX4: vorher nur, wenn keine Gruppe spielte - das Atmen spielte aber dauernd,
-- der Waechter griff nie). Legale Ausschlaege: Atmen 1 px, Nicken 1 px, Ruck bis 5 px.
-- Ehrlich dazu: seit Bewegung v3 steckt die Bewegung im ANKER, den GetCenter() ausweist - der
-- Waechter kann also ueberhaupt etwas sehen. Bliebe trotzdem ein reiner Render-Versatz stehen
-- (der Fall aus fix4), saehe er ihn nicht; dagegen hilft nur G.nullstellung() an den Stellen,
-- an denen ein Bild Flackern nicht auffaellt (layout, OnShow, /lyra drift reset).
-- ---------------------------------------------------------------------------------------------
G.DRIFT_MAX = 6          -- px
G.DRIFT_TAKT = 3         -- s
function G.driftPruefen()
    if not f:IsShown() then return false end
    local fx, fy = f:GetCenter()
    if not (fx and fy) then return false end
    local x, y = bewegt:GetCenter()
    if not (x and y) then return false end
    local weit = math.max(math.abs(x - fx), math.abs(y - fy))
    if weit <= G.DRIFT_MAX then return false end
    G.driftZaehler = (G.driftZaehler or 0) + 1
    G.driftLetzter = string.format("%.1f px", weit)
    G.nullstellung()
    if not G.animationenAus then phase0 = GetTime(); taktStart() end
    ns.debug("Drift korrigiert: " .. G.driftLetzter)
    return true
end

-- Alle Animationen aus/an (Eingrenzung im Client)
function G.animationen(an)
    G.animationenAus = not an
    if G.animationenAus then
        taktStop()
        if nickTicker then nickTicker:Cancel(); nickTicker = nil end
        G.nullstellung()
    else
        G.nullstellung()
        zustand, phase0 = "atem", GetTime()
        taktStart()
    end
end

-- Selbsttest: laedt das Bild? DESIGN-V3 A-1: der MASKEN-Selbsttest samt Not-Abschaltung ist
-- entfallen (es gibt keine Maske mehr). Uebrig bleibt die Frage, die Harald im Spiel beantworten
-- muss (Pruefpunkt 21 aus docs/design-v3.md): laedt bilder/rund/<miene>.png ueberhaupt?
-- Wird bei G.start() einmal verzoegert gerufen und steht in jedem /lyra drift.
function G.selbsttest()
    local out = {}
    local ok, wert = pcall(tex.GetTexture, tex)
    local texOk = ok and wert ~= nil and wert ~= ""
    out[#out + 1] = "Bild: " .. (texOk and ("ok (" .. tostring(wert) .. ")") or "FEHLT")
    out[#out + 1] = "Ansicht: " .. (G.istPortrait() and ("portrait, runde Textur, Kante " .. G.portraitKante() .. " px")
        or ("figur, 512er-Sheet, scale " .. tostring(ns.Get("scale"))))
    out[#out + 1] = "Scheibe sichtbar: " .. tostring(grund:IsShown())
        .. "  Ring sichtbar: " .. tostring(ring:IsShown())
        .. "  Halo: " .. tostring(halo:IsShown()) .. string.format(" (Alpha %.2f)", halo:GetAlpha() or 0)
        .. "  Warnstufe " .. tostring(warnStufe)
        .. "  Alpha Ebene " .. string.format("%.2f", bewegt:GetAlpha() or 1)
    G.selbsttestOk = texOk
    local einmal = not G.selbsttestGelaufen
    G.selbsttestGelaufen = true
    if einmal and not texOk then
        ns.print("Lyras Bild laedt nicht (bilder/rund/*.png bzw. bilder/*.png). Bitte die Addon-Dateien pruefen.")
    end
    return out
end

function G.diagnose()
    local out = {}
    local function c(name, r)
        local x, y = r:GetCenter()
        local sc = r.GetScale and r:GetScale() or 1
        out[#out + 1] = string.format("%s: Mitte %s/%s  Scale %.3f  Alpha %.2f", name,
            x and string.format("%.1f", x) or "?", y and string.format("%.1f", y) or "?", sc, r:GetAlpha())
    end
    c("frame", f); c("bewegt", bewegt)
    local p, rel, rp, x, y = f:GetPoint(1)
    -- REVIEW: GetName() darf nil liefern (namenlose Frames) - tostring() ohne Wert wirft sonst,
    -- und dann faellt die ganze Diagnose aus, genau wenn man sie braucht.
    local relName = "-"
    if rel then
        local okn, nm = pcall(function() return rel.GetName and rel:GetName() end)
        relName = (okn and nm) and tostring(nm) or "(ohne Namen)"
    end
    out[#out + 1] = string.format("Anker: %s -> %s %s  x %.1f  y %.1f  (gespeichert: %s)", tostring(p),
        relName, tostring(rp), x or 0, y or 0,
        table.concat({ tostring((ns.Get("pos") or {})[1]), tostring((ns.Get("pos") or {})[2]), tostring((ns.Get("pos") or {})[3]) }, " "))
    out[#out + 1] = string.format("Bewegung: Zustand %s  Versatz y %.2f  Takt %s  Ruck %s (Rest %d)  animationenAus=%s",
        zustand, versatzY or 0, tostring(taktTicker ~= nil), tostring(ruckLaeuft), G.ruckRest or 0,
        tostring(G.animationenAus or false))
    out[#out + 1] = string.format("Drift korrigiert: %d (zuletzt %s)", G.driftZaehler or 0, G.driftLetzter or "-")
    out[#out + 1] = string.format("Groesse %.0fx%.0f  UIParent-Scale %.3f  Ansicht %s", f:GetWidth(), f:GetHeight(), UIParent:GetEffectiveScale(), tostring(ns.Get("ansicht")))
    for _, z in ipairs(G.selbsttest()) do out[#out + 1] = z end
    return out
end

local driftTicker
local function driftWacheStart()
    if driftTicker then return end
    driftTicker = ns.Compat.NewTicker(G.DRIFT_TAKT, function() G.driftPruefen() end)
end

-- Nach jeder Ausgabe: Nicken (nicht bei "still"), Ruck/Ring ab Warnstufe 2
ns.nachAusgabe(function(id, e)
    if not e or e.klasse == "still" then return end
    local stufe = tonumber(e.stufe)
    if not stufe then stufe = (e.klasse == "warn") and 2 or 0 end   -- Fallback fuer alte phrasen.lua
    if stufe >= 2 then G.ruck(stufe); G.warnOptik(stufe) end
    -- Blase/Stimme sind vor dem Hook schon gesetzt; der 0.5-s-Ticker beendet das Nicken, sobald beides vorbei ist
    nickenStart()
end)

-- Kind-Frames: Bewegung ruht, wenn die Gestalt verborgen ist.
-- OnShow ist die beste Stelle fuer die harte Nullstellung: das eine Bild, das sie kostet, faellt
-- beim Einblenden ohnehin nicht auf.
f:SetScript("OnShow", function() G.nullstellung(); atmenStart() end)
ns.on("PLAYER_LOGIN", function() if ns.Get("animation") == false then G.animationen(false) end end)
f:SetScript("OnHide", function() atmenStop(); nickenStop(); G.notAus() end)

-- ---------------------------------------------------------------------------------------------
-- Mienen (Crossfade tex -> tex2)
-- ---------------------------------------------------------------------------------------------
-- Whitelist der ausgelieferten Sheets (bilder/*.png). SetTexture meldet fehlende Dateien nicht zuverlaessig.
G.MIENEN = { alert = true, amused = true, angry = true, anxious = true, aversion = true, concerned = true, defeated = true, depressed = true, grossedout = true, happy = true, hmm = true, hurt = true, interested = true, neutral = true, overjoyed = true, sad = true, scared = true, shocked = true, shy = true, smirk = true, smug = true, terrified = true, thinking = true, touched = true, upset = true, veryhappy = true, victory = true, whatever = true, wonder = true }

-- DESIGN-V3 A-1: Die Geometrie ist in beiden Ansichten dieselbe - die Textur deckt die
-- Bewegungsebene ab, mehr nicht. Im Portrait ist die Datei schon rund und schon richtig
-- angeschnitten (bilder/rund/<miene>.png), in der Figur ist es das volle 512er-Sheet.
-- Entfallen: G.KOPF, der Teilausschnitt per SetTexCoord, die Geometrie-Skalierung des Sheets
-- auf das Fuenffache, der quadratische Fallback. Das war der ganze Masken-Umweg aus FIX4.
local function geometrie(t)
    local s = G.SHEET
    t:ClearAllPoints()
    t:SetAllPoints(bewegt)
    if G.istPortrait() then
        t:SetTexCoord(0, 1, 0, 1)
    else
        t:SetTexCoord(0, s.fw / s.w, 0, s.fh / s.h)
    end
end
G.geometrie = geometrie

local fadeAG, fadeZiel
local function fadeAbschluss()
    if fadeZiel then
        tex:SetTexture(mienenPfad(fadeZiel))
        geometrie(tex)
        fadeZiel = nil
    end
    tex2:SetAlpha(0)
    tex2:Hide()
end
do
    local ag = neueGruppe(tex2)
    if ag then
        local ok = pcall(function()
            local a = neueAnim(ag, "Alpha")
            if not (a and blende(a, 0, 1, G.FADE_DAUER, 1)) then error("keine Alpha") end
            if ag.SetToFinalAlpha then ag:SetToFinalAlpha(true) end
            ag:SetLooping("NONE")
            ag:SetScript("OnFinished", fadeAbschluss)
        end)
        if ok then fadeAG = ag end
    end
end

local function setzeMiene(miene)
    if not miene then return end
    if not G.MIENEN[miene] then
        ns.debug("Miene fehlt: " .. tostring(miene))
        if miene ~= "neutral" then return setzeMiene("neutral") end
        return
    end
    if miene == G.aktuell then return end   -- auch mitten im Fade: Ziel ist schon dasselbe
    if fadeAG and G.aktuell and f:IsShown() and f:IsVisible() then
        -- laufenden Wechsel hart abschliessen, dann neuen Fade starten
        if fadeAG:IsPlaying() then pcall(fadeAG.Stop, fadeAG) end
        fadeAbschluss()
        tex2:SetTexture(mienenPfad(miene))
        geometrie(tex2)
        tex2:SetAlpha(0)
        tex2:Show()
        fadeZiel = miene
        local ok = pcall(fadeAG.Play, fadeAG)
        if not ok then fadeAbschluss() end
    else
        if fadeAG and fadeAG:IsPlaying() then pcall(fadeAG.Stop, fadeAG) end
        fadeZiel = nil
        tex2:SetAlpha(0); tex2:Hide()
        tex:SetTexture(mienenPfad(miene))
        geometrie(tex)
    end
    G.aktuell = miene
end

-- Kampf-Transparenz: kampfAlpha (0.4-1.0) im Kampf, sonst 1.0
local function kampfAlpha()
    if ns.Get("streamer") then return 1 end   -- Chroma: keine Transparenz, sonst Gruen-Fransen
    local a = tonumber(ns.Get("kampfAlpha")) or 1
    if a < 0.4 then a = 0.4 elseif a > 1 then a = 1 end
    return a
end
function G.alphaNachfuehren()
    local imKampf = ns.Regie and ns.Regie.imKampf
    f:SetAlpha(imKampf and kampfAlpha() or 1)
end

-- Sichtbarkeit von Schatten/Scheibe/Ring/Halo nach Ansicht setzen und den Schatten bemessen.
local function optikNachfuehren(breite, hoehe)
    if G.istPortrait() then
        schatten:Hide()
        grund:Show()
        ring:Show()
        ringFarbe(warnStufe >= 3 and G.RING_ALARM or warnStufe == 2 and G.RING_WARN or ringGrund())
        warnOptikNachfuehren()   -- Halo/Doppelring auf die neue Kante umrechnen
    else
        grund:Hide()
        ring:Hide()
        ring2:Hide()
        halo:SetAlpha(0); halo:Hide()
        -- Sockel: 0.62 x Breite, 0.10 x Hoehe. Mittelpunkt auf die FUSSLINIE: die Fuesse liegen im
        -- neuen 512er-Sheet auf y = 500, der Frame endet bei 512 -> 12/512 der Hoehe darunter.
        schatten:ClearAllPoints()
        schatten:SetSize(breite * 0.62, hoehe * 0.10)
        schatten:SetPoint("CENTER", ruckF, "BOTTOM", 0, hoehe * (12 / 512))
        schatten:Show()
    end
end

function G.layout()
    local s = G.SHEET
    local sc = tonumber(ns.Get("scale")) or 0.5
    -- Bewegung kontrolliert anhalten und auf Null stellen, erst danach neu vermessen.
    atmenStop()
    G.nullstellung()
    local breite, hoehe
    if G.istPortrait() then
        breite = G.portraitKante()
        hoehe = breite
    else
        breite, hoehe = s.fw * sc, s.fh * sc
    end
    f:SetSize(breite, hoehe)
    bewegt:SetSize(breite, hoehe)   -- FIX4: Einzelanker braucht eigene Groesse
    f:ClearAllPoints()
    local pos = ns.Get("pos")
    -- REVIEW: kaputte SavedVariables (kein Punkt / keine Zahlen) nicht an SetPoint durchreichen
    if type(pos) ~= "table" or type(pos[1]) ~= "string" then pos = ns.POS_DEFAULT end
    f:SetPoint(pos[1], UIParent, pos[4] or pos[1], tonumber(pos[2]) or 0, tonumber(pos[3]) or 0)
    optikNachfuehren(breite, hoehe)
    geometrie(tex)
    geometrie(tex2)
    -- DESIGN-V3 A-1: Portrait und Figur ziehen ihr Bild aus VERSCHIEDENEN Dateien
    -- (bilder/rund/<miene>.png bzw. bilder/<miene>.png). Ein Ansichtswechsel muss die Textur
    -- also neu setzen, nicht nur die Geometrie - sonst bliebe nach /lyra portrait das eckige
    -- Sheet stehen. Ein laufender Crossfade wird dafuer hart abgeschlossen.
    if G.aktuell then
        if fadeAG and fadeAG.IsPlaying and fadeAG:IsPlaying() then pcall(fadeAG.Stop, fadeAG) end
        fadeZiel = nil
        tex2:SetAlpha(0); tex2:Hide()
        tex:SetTexture(mienenPfad(G.aktuell))
    end
    G.alphaNachfuehren()
    if ns.Get("versteckt") then f:Hide() else f:Show() end
    atmenStart()
end

-- Grundstimmung aus Zustand
function G.grundstimmung()
    local gs = LyraGestalt_Phrasen and LyraGestalt_Phrasen.grundstimmung or {}
    if ns.Regie and ns.Regie.imKampf then return gs.kampf or "alert" end
    -- W1 (Sinne/Leben2.lua): afk > taxi > tot > besorgt, danach Rast, dann gut > nacht > lange.
    -- Bei Rast gibt ns.Stimmung.grundstimmung() nil zurueck, die Zeile darunter greift wie bisher.
    if ns.Stimmung and ns.Stimmung.grundstimmung then
        local m = ns.Stimmung.grundstimmung(gs)
        if m then return m end
    end
    if IsResting and IsResting() then return gs.rast or "amused" end
    return gs.sonst or "neutral"
end

-- ---------------------------------------------------------------------------------------------
-- Regungen: Optik ohne Regie (Leerlauf, Hover, Drag). Weichen jeder Ereignis-Miene aus.
-- ---------------------------------------------------------------------------------------------
local regungTicker, regungAktiv = nil, false

function G.regungEnde()
    if regungTicker then regungTicker:Cancel(); regungTicker = nil end
    if not regungAktiv then return end
    regungAktiv = false
    if G.ticker then return end   -- inzwischen haelt ein Ereignis eine Miene
    setzeMiene(G.grundstimmung())
end

-- REVIEW4: Die Ausweich-Regeln lagen nur in G.mikroFaellig - der Hover-Pfad (OnEnter) setzte
-- "interested" auch, waehrend eine Blase stand oder das Gespraechsfenster offen war, und
-- ueberschrieb damit die Miene einer gerade gesprochenen Zeile ohne Haltezeit (halte = 0 setzt
-- keinen G.ticker, war also ungeschuetzt). Jetzt entscheidet EINE Stelle.
function G.regungFrei()
    if G.ticker then return false end                                              -- Ereignis-Miene haelt
    if ns.Blase and ns.Blase.sichtbar and ns.Blase.sichtbar() then return false end -- Lyra spricht
    if ns.Dialog and ns.Dialog.offen and ns.Dialog.offen() then return false end    -- Gespraechsfenster
    if ns.Menue and ns.Menue.frame and ns.Menue.frame:IsShown() then return false end
    return true
end

-- G.regung("interested", 2): Miene ohne Text, ohne Ton, ohne Budget. dauer 0 = bis G.regungEnde().
-- erzwingen = true nur fuer das Ziehen: wer Lyra am Kragen hat, soll sie auch erschrecken duerfen.
--
-- W8 (pruefstand-wiederaufbau §5 Punkt 2): "if G.ticker then return false end" stand VOR der
-- erzwingen-Abfrage - erzwingen hat also nie etwas erzwungen, sobald eine Ereignis-Miene hielt,
-- und seit Welle 2-5 haelt praktisch immer eine. Der Kommentar daneben war damit seit Review 4
-- falsch.
--
-- UND JA, DAS IST DIE RICHTIGE RICHTUNG - die Frage stand ausdruecklich im Auftrag. Begruendung:
-- es gibt genau EINEN Aufrufer mit erzwingen = true, den OnDragStart-Handler unten. Das ist
-- keine Meldung und kein Sinn, sondern eine direkte Handbewegung des Spielers an ihrer Figur.
-- Auf eine Handbewegung nicht zu reagieren ist der einzige Fall, in dem die Figur SICHER tot
-- wirkt; eine Ereignis-Miene, die zwei Sekunden lang vom Ziehen ueberschrieben wird, ist dagegen
-- nicht einmal ein Verlust (der Text steht ohnehin in der Blase, und die bleibt).
--
-- Der laufende Ereignis-Ticker wird dabei ABGEBROCHEN und nicht nur uebermalt: liesse man ihn
-- laufen, setzte er mitten im Ziehen die alte Miene zurueck - dasselbe Problem, nur zeitversetzt
-- und schwerer zu finden. Nach dem Loslassen ruft OnDragStop G.regungEnde(), und das setzt die
-- Grundstimmung. Die drei Gueltigkeitspruefungen stehen bewusst VOR dem Abbruch: ein Aufruf mit
-- unbekannter Miene oder bei versteckter Gestalt darf keine haltende Miene kosten.
function G.regung(miene, dauer, erzwingen)
    if G.ticker and not erzwingen then return false end   -- Ereignis-Miene hat Vorrang
    if not erzwingen and not G.regungFrei() then return false end
    if not miene or not G.MIENEN[miene] then return false end
    if ns.Get("versteckt") or not f:IsShown() then return false end
    if G.ticker then G.ticker:Cancel(); G.ticker = nil end   -- W8: erzwingen heisst erzwingen
    if regungTicker then regungTicker:Cancel(); regungTicker = nil end
    regungAktiv = true
    setzeMiene(miene)
    dauer = tonumber(dauer) or 0
    if dauer > 0 then
        regungTicker = ns.Compat.NewTicker(dauer, function() regungTicker = nil; G.regungEnde() end, 1)
    end
    return true
end
function G.regungLaeuft() return regungAktiv end

local function regungAbbrechen()
    if regungTicker then regungTicker:Cancel(); regungTicker = nil end
    regungAktiv = false
end

local function zurueck()
    if G.ticker then G.ticker:Cancel(); G.ticker = nil end
    setzeMiene(G.grundstimmung())
end

-- G.miene("scared", 15, "hurt"): Pose 3 s, dann Miene bis Haltezeit, dann Grundstimmung
function G.miene(miene, halte, pose)
    regungAbbrechen()   -- eine Regung darf ein Ereignis nie ueberschreiben
    if G.ticker then G.ticker:Cancel(); G.ticker = nil end
    halte = tonumber(halte) or 0
    if pose then
        setzeMiene(pose)
        G.ticker = ns.Compat.NewTicker(G.POSE_DAUER, function()
            if G.ticker then G.ticker:Cancel() end   -- REVIEW: nil-sicher
            G.ticker = nil
            setzeMiene(miene)
            if halte > 0 then G.ticker = ns.Compat.NewTicker(halte, function() zurueck() end, 1) end
        end, 1)
        return
    end
    setzeMiene(miene)
    if halte > 0 then
        G.ticker = ns.Compat.NewTicker(halte, function() zurueck() end, 1)
    end
end

-- Leerlauf-Mikrowechsel: alle 45-90 s (Zufall) 2,5 s eine andere Miene. Ein einziger schwebender
-- Timer, der sich selbst neu plant - kein OnUpdate, kein Dauer-Ticker.
local mikroGeplant = false
function G.mikroFaellig()
    if not f:IsShown() or ns.Get("versteckt") then return false end
    if ns.Regie and ns.Regie.imKampf then return false end
    if regungAktiv then return false end
    return G.regungFrei()   -- REVIEW4: Blase/Dialog/Menue/Ereignis-Miene stehen jetzt dort
end
local function mikroSchritt()
    if G.mikroFaellig() then
        -- W1: Pool nach Vertrautheit und Laune (Sinne/Leben2.lua). Ein Gesicht, das nach dem
        -- Beinahe-Tod weiter verschmitzt grinst, kostet die ganze Illusion.
        local pool = (ns.Stimmung and ns.Stimmung.mikroPool and ns.Stimmung.mikroPool()) or G.MIKRO
        if type(pool) ~= "table" or #pool == 0 then pool = G.MIKRO end
        G.regung(pool[math.random(#pool)], G.MIKRO_DAUER)
    end
end
G.mikroSchritt = mikroSchritt
local function mikroPlanen()
    local wartezeit = G.MIKRO_MIN + math.random() * (G.MIKRO_MAX - G.MIKRO_MIN)
    ns.Compat.After(wartezeit, function()
        mikroSchritt()
        mikroPlanen()
    end)
end
function G.mikroStart()
    if mikroGeplant then return end
    mikroGeplant = true
    mikroPlanen()
end

-- Grundstimmung nachfuehren, wenn Kampf/Rast wechselt und keine Miene gehalten wird
local function nachfuehren() if not G.ticker and not regungAktiv then setzeMiene(G.grundstimmung()) end end
ns.on("PLAYER_REGEN_DISABLED", function() G.alphaNachfuehren(); nachfuehren() end)
ns.on("PLAYER_REGEN_ENABLED", function() G.alphaNachfuehren(); ns.Compat.After(0.5, nachfuehren) end)
ns.on("PLAYER_UPDATE_RESTING", nachfuehren)
-- REVIEW: GEFALLEN (halte 0) laesst "depressed" stehen; nach Wiederbelebung/Ladebildschirm zurueck.
ns.on("PLAYER_ALIVE", function() ns.Compat.After(1, nachfuehren) end)
ns.on("PLAYER_UNGHOST", function() ns.Compat.After(1, nachfuehren) end)
ns.on("PLAYER_ENTERING_WORLD", function() ns.Compat.After(1, function() G.alphaNachfuehren(); nachfuehren() end) end)

-- ---------------------------------------------------------------------------------------------
-- Maus: Drag, Klick, Hover-Tooltip
-- ---------------------------------------------------------------------------------------------
f:SetScript("OnDragStart", function(self)
    if not ns.Get("gesperrt") then
        gezogen = true
        self:StartMoving()
        G.regung("shocked", 0, true)   -- haelt, bis OnDragStop (REVIEW4: erzwingen - direkte Maus-Aktion)
    end
end)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint(1)
    -- REVIEW: GetPoint kann nil liefern -> sonst SetPoint(nil) im naechsten layout()
    if p then ns.Set("pos", { p, x, y, rp }) end
    G.regungEnde()
end)
-- ---------------------------------------------------------------------------------------------
-- Klick-Belegung ab 0.6.1 (FIX5). Begruendung: das Menue war der einzige Weg, mit ihr zu REDEN,
-- lag aber hinter zwei Klicks (Rechtsklick -> "Frag mich"). Das Gespraech ist die Sache, die man
-- an ihr anklickt; das Menue ist Verwaltung und gehoert an den Minimap-Knopf und hinter Shift.
--
--   Links           kurze Reaktion (KLICK-Zeile, Drossel der Regie bleibt)
--   Links doppelt   Portrait <-> ganze Figur
--   Rechts          Gespraech - mit feindlichem NPC im Ziel direkt beim Ziel-Knoten
--   Shift+Rechts    Menue  (auch: Rechtsklick auf den Minimap-Knopf, /lyra menue)
--   Mitte           Still-Modus an/aus
--   Mausrad         Groesse klein <-> mittel <-> gross
--   Ziehen          verschieben (solange nicht gesperrt)
--
-- Alles nicht-secure, also auch im Kampf bedienbar. Jede Fremd-API ist geprueft (IsShiftKeyDown,
-- Mittel-Taste) - fehlt sie, faellt der Zweig einfach aus, nie ein Fehler.
-- ---------------------------------------------------------------------------------------------
G.DOPPEL_ZEIT = 0.4       -- s, Fenster fuer den Doppelklick links
local letzterLinks = 0

local function setzeUeberSettings(key, value)
    if ns.Settings and ns.Settings.setze then ns.Settings.setze(key, value) else ns.Set(key, value) end
end

-- Doppelklick links: Ansicht wechseln. Der erste Klick hat seine KLICK-Zeile schon abgesetzt -
-- das ist Absicht (sofortige Reaktion). Die Drossel der Regie verhindert eine zweite Zeile.
function G.ansichtWechseln()
    setzeUeberSettings("ansicht", G.istPortrait() and "figur" or "portrait")
    return ns.Get("ansicht")
end

-- Mausrad: ein Preset hoch/runter, ohne Umlauf (am Ende bleibt es stehen).
G.GROESSEN_FOLGE = { "klein", "mittel", "gross" }
function G.groesseStufe(delta)
    delta = (tonumber(delta) or 0) >= 0 and 1 or -1
    local jetzt = ns.Get("groesse") or "mittel"
    local i
    for k, n in ipairs(G.GROESSEN_FOLGE) do if n == jetzt then i = k end end
    if not i then i = 2 end
    local neu = i + delta
    if neu < 1 then neu = 1 elseif neu > #G.GROESSEN_FOLGE then neu = #G.GROESSEN_FOLGE end
    if G.GROESSEN_FOLGE[neu] == jetzt then return jetzt, false end
    setzeUeberSettings("groesse", G.GROESSEN_FOLGE[neu])
    return G.GROESSEN_FOLGE[neu], true
end

f:SetScript("OnMouseUp", function(self, button)
    -- REVIEW: OnMouseUp feuert auch nach einem Drag -> kein Klick (sonst LEERLAUF-Zeile je Verschieben)
    if gezogen then gezogen = false; return end
    if button == "RightButton" then
        if IsShiftKeyDown and IsShiftKeyDown() then
            if ns.menue then ns.menue() elseif ns.oeffneSettings then ns.oeffneSettings() end
        elseif ns.Dialog and ns.Dialog.oeffneKontext then ns.Dialog.oeffneKontext()
        elseif ns.Dialog and ns.Dialog.oeffne then ns.Dialog.oeffne()
        elseif ns.menue then ns.menue()
        elseif ns.oeffneSettings then ns.oeffneSettings() end
    elseif button == "MiddleButton" then
        if ns.stillSetzen then ns.stillSetzen(not ns.stillModus) end
    elseif button == "LeftButton" then
        local t = GetTime()
        if t - letzterLinks < G.DOPPEL_ZEIT then
            letzterLinks = 0
            G.ansichtWechseln()
            return
        end
        letzterLinks = t
        if ns.klick then ns.klick() end
    end
end)

f:SetScript("OnMouseWheel", function(self, delta)
    G.groesseStufe(delta)
end)

local ANREDE_L = { auto = "By character", m = "Male", f = "Female", keine = "No address" }
local PRESET_L = { still = "Silent", wenig = "Little", normal = "Normal", viel = "Chatty" }
local function tooltipZeile()
    local L = ns.L
    local sprache = (ns.sprache() == "de") and L["German"] or L["English"]
    local anrede = L[ANREDE_L[ns.Get("anrede")] or "By character"]
    local preset = L[PRESET_L[ns.Get("gespraechig")] or "Normal"]
    local z = sprache .. " \194\183 " .. anrede .. " \194\183 " .. preset
    if ns.stillModus then z = z .. " \194\183 " .. L["Quiet mode"] end
    return z
end
-- REVIEW7 / DESIGN-V3 c, Barrierefreiheit 7 ("Schrift wirkt auf ALLE Flaechen"): der Tooltip hing
-- an Blizzards Font und ignorierte die Schriftgroesse komplett. Die Zusatzzeilen folgen jetzt der
-- Einstellung (schriftgroesse() - 2, Untergrenze 9).
-- WICHTIG: GameTooltipTextLeftN gehoert BLIZZARD, nicht uns. Ein SetFont darauf bleibt stehen und
-- wuerde ab dem ersten Hover auf Lyra JEDEN anderen Tooltip im Spiel mitumstellen. Deshalb wird die
-- Ausgangsschrift beim ersten Mal gemerkt und in OnLeave wieder hergestellt - wir leihen sie uns
-- nur, solange unser eigener Tooltip steht. Alles guarded und per pcall: benennt Blizzard die
-- FontStrings um, passiert schlicht nichts.
local tooltipFontAlt = {}
local tooltipGeliehen = false
local function tooltipSchrift()
    if not (ns.Optik and GameTooltipTextLeft2) then return end
    local g = math.max(9, ns.Optik.schriftgroesse() - 2)
    for i = 2, 4 do
        local fs = _G["GameTooltipTextLeft" .. i]
        if fs and fs.SetFont and fs.GetFont then
            if tooltipFontAlt[i] == nil then
                local ok, pfad, groesse, flags = pcall(fs.GetFont, fs)
                tooltipFontAlt[i] = (ok and pfad) and { pfad, groesse, flags or "" } or false
            end
            pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, g, "")
            tooltipGeliehen = true
        end
    end
end
local function tooltipSchriftZurueck()
    if not tooltipGeliehen then return end
    tooltipGeliehen = false
    for i = 2, 4 do
        local fs, alt = _G["GameTooltipTextLeft" .. i], tooltipFontAlt[i]
        if fs and fs.SetFont and type(alt) == "table" then pcall(fs.SetFont, fs, alt[1], alt[2], alt[3]) end
    end
end

f:SetScript("OnEnter", function(self)
    -- FIX1: Hover raeumt nur auf. Kein G.layout() (das setzt SetSize waehrend die Bewegung laeuft)
    -- und kein Play()/Restart auf eine laufende Gruppe - genau das war der Ruck-und-Wachs-Pfad.
    -- FIX4: nur notAus (Anker), NICHT die harte Nullstellung - ein Hide/Show unter der Maus
    -- waere ein sichtbares Zucken, und noetig ist es hier nicht.
    G.notAus()
    G.regung("interested", 2)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    -- FIX3 (Kontrast): Blizzards Tooltip-Grund ist nur ~90 % deckend. Auf hellem Spielbild (Schnee)
    -- kam die alte Titelfarbe 0.70/0.55/1.00 auf 5,3:1, die Hinweiszeile 0.70/0.70/0.70 auf 6,5:1.
    -- Jetzt 7,96:1 bzw. 8,97:1 - siehe Kontrasttabelle in docs/fix3-2026-09-17.md.
    GameTooltip:AddLine("Lyra", 0.85, 0.72, 1)
    GameTooltip:AddLine(tooltipZeile(), 1, 1, 1, true)
    -- FIX5: zwei Zeilen statt einer - die Belegung ist laenger geworden (Doppelklick, Mitte, Rad).
    -- REVIEW7 / DESIGN-V3 B-2 (P1-2): 0,88 statt 0,82. Gemessen ueber fuenf Spielbild-Referenzen
    -- waren es 8,97-11,57:1, jetzt 10,41-13,4:1. Der Wert liegt in ns.Optik.TOOLTIP_HINWEIS -
    -- eine Tafel, nicht drei. Den Tooltip-GRUND besitzt Blizzard: dreht der Spieler die
    -- Tooltip-Deckkraft herunter, sinkt auch "Lyra" - das ist seine Einstellung, aber ein Grund,
    -- den Titel nicht zusaetzlich abzusenken.
    local h = (ns.Optik and ns.Optik.TOOLTIP_HINWEIS) or { 0.82, 0.82, 0.82 }
    GameTooltip:AddLine(ns.L["Tooltip hint"], h[1], h[2], h[3], true)
    GameTooltip:AddLine(ns.L["Tooltip hint 2"], h[1], h[2], h[3], true)
    GameTooltip:Show()
    tooltipSchrift()
end)
-- DESIGN-V3 A-8: OnLeave beendet die Hover-Regung. Bis 0.6.1 lief sie ihre 2 s zu Ende - wer
-- kurz ueber Lyra fuhr, bekam ein Gesicht, das an einer Stoppuhr klebte statt an der Maus.
f:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
    tooltipSchriftZurueck()   -- REVIEW7: Blizzards Tooltip-Schrift war nur geliehen
    G.regungEnde()
end)

function G.start()
    G.layout()
    setzeMiene(G.grundstimmung())
    atmenStart()
    G.mikroStart()
    driftWacheStart()   -- FIX3
    -- Nach dem ersten Layout einmal pruefen, ob das Bild wirklich geladen ist (Pruefpunkt 21:
    -- laedt bilder/rund/neutral.png?). 2 s Abstand, damit GetTexture() etwas zu melden hat.
    ns.Compat.After(2, function()
        local ok, zeilen = pcall(G.selbsttest)
        if ok and type(zeilen) == "table" then
            for _, z in ipairs(zeilen) do ns.debug(z) end
        end
    end)
end

ns.onSetting = function(key, value)
    -- DESIGN-V3 A-1: "maske" ist entfallen. A-2/A-3: "kontrast" faerbt den Ring (Grundfarbe Weiss).
    if key == "scale" or key == "pos" or key == "versteckt" or key == "ansicht" or key == "groesse"
        or key == "kontrast" then G.layout() end
    -- REVIEW2: Ausblenden nimmt Blase und Dialog mit (beide haengen an G.frame und schwebten sonst an der alten Stelle)
    if key == "versteckt" and value then
        if ns.Blase and ns.Blase.verstecke then ns.Blase.verstecke() end
        if ns.Dialog and ns.Dialog.offen and ns.Dialog.offen() then ns.Dialog.schliesse() end
    end
    if key == "kampfAlpha" or key == "streamer" then G.alphaNachfuehren() end
    if (key == "minimap" or key == "minimapWinkel") and ns.Minimap and ns.Minimap.layout then ns.Minimap.layout() end
    if ns.Blase and ns.Blase.layout then ns.Blase.layout() end
end
