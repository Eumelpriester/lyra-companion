-- Core/Init.lua — Namensraum, SavedVariables, Defaults, Get/Set (Account vs. Charakter).
-- Einziger globaler Wert des Addons: LyraGestaltDB (SavedVariables).
local ADDON, ns = ...
ns.ADDON = ADDON
ns.PFAD  = "Interface\\AddOns\\" .. ADDON .. "\\"
ns.VERSION = "0.15.0"

ns.DEFAULTS_ACCOUNT = {
    preset = "normal",         -- leise|normal|lebendig|streamer|eigen (UI/Settings.lua, setzt mehrere Schluessel)
    ansicht = "portrait",      -- portrait|figur (Gestalt/Gestalt.lua). Default portrait: klein, Gesicht sichtbar, T-tauglich.
    eingerichtet = false,      -- Erst-Start-Assistent gelaufen? (Core/Start.lua, dialog.lua setup_*)
    setupGefragt = 0,          -- wie oft der Assistent angeboten wurde; nach 3x fragt Lyra nie wieder
    einladungGezeigt = false,  -- B-11: die EINMALIGE Blasenzeile "/lyra einrichten" fuer Bestandsnutzer
                               -- (wer von 0.2 kommt, hat die Datenbank schon und sah den Assistenten nie).
                               -- Kein Zaehler, kein zweiter Versuch, kein Popup (Core/Start.lua).
    sprache = "auto",          -- auto|de|en
    stimme = true,
    kanal = "Dialog",          -- Master|SFX|Dialog|Ambience
    untertitel = true,
    gespraechig = "normal",    -- still|wenig|normal|viel
    kampfNurWarnungen = true,
    gruppeSchweigen = true,
    frech = true,
    blaseDauer = 6,
    mienenSet = "mage",
    -- DESIGN-V3 B-1/C1: "auto" oder eine Zahl 10-28. "auto" rechnet die UI-Einheiten aus
    -- ZIEL_PX / UIParent:GetEffectiveScale(), damit die Schrift auf JEDEM Bildschirm gleich gross
    -- ankommt (ein fester Wert 16 ist bei Scale 0,64 zehn und bei 1,9 dreissig Bildschirm-Pixel).
    -- Der Slider uebersteuert: jede Zahl gewinnt gegen "auto". ns.Optik.schriftgroesse() ist die
    -- einzige Stelle, die das aufloest. BESTANDSSCHUTZ: wer schon eine Zahl gespeichert hat,
    -- behaelt sie (defaults() fuellt nur fehlende Schluessel).
    schrift = "auto",
    -- REVIEW7: einmalige Wanderung der ALTEN Default-16 nach "auto" (siehe ns.initDB). Das Flag
    -- steht hier, damit es in jeder Datenbank existiert und die Wanderung genau einmal laeuft.
    schriftAutoMigriert = false,
    kontrast = false,
    cues = true,
    kampfAlpha = 1.0,          -- 0.4-1.0: Gestalt-Transparenz im Kampf (Gestalt.lua)
    glow = true,               -- Bildschirmrand-Puls bei HP20/HP35/ATEM10/ATEM30/STURZ (UI/Glow.lua)
    minimap = true,            -- Minimap-Knopf (UI/Minimap.lua)
    minimapWinkel = 220,       -- Grad, 0-360, Position des Knopfs am Minimap-Rand
    debug = false,
    animation = true,          -- Atmen/Nicken/Ruck (Schalter zur Fehlersuche, /lyra animation aus)
    -- DESIGN-V3 B-13 / Barrierefreiheit 6: voll | reduziert | aus.
    --   voll      alles wie bisher
    --   reduziert kein Atmen, kein Nicken, kein Ring-Puls, kein Halo-Puls; Ruck und Regungen bleiben,
    --             Mienenwechsel blendet in 0,1 s statt 0,25 s
    --   aus       zusaetzlich: keine Bewegung ueberhaupt (G.animationen(false)), keine Regungen,
    --             harte Mienenwechsel
    -- Angewandt wird der Wert in UI/Settings.lua (S.bewegungAnwenden) - Gestalt.lua bleibt unberuehrt.
    bewegung = "voll",
    -- DESIGN-V3 A-1: "maske" ist entfallen. Das Portrait ist eine vorgeschnittene runde Textur
    -- (bilder/rund/<miene>.png); es gibt keine MaskTexture mehr, also auch keinen Not-Schalter.
    -- Ein alter Eintrag in den SavedVariables schadet nicht, er wird nur nicht mehr gelesen.
    profil = true,             -- Spielstil-Profil (Welle 2)
    karte = true,              -- Karten-Pins (Welle 2, nur mit HereBeDragons)
    gefahrenkarte = true,     -- Deathlog-Daten-Addon nutzen
    fotos = true,              -- Erinnerungsfoto: Screenshot() bei Meilenstein / ueberlebt unter 20 % (Sinne/Extra.lua)
    ultra = false,             -- Ultra-Modus: Miene folgt im Kampf dem Leben (Sinne/Extra.lua)
    streamer = false,          -- Streamer-Modus: Chroma-Kachel, Anrede keine (UI/Streamer.lua)
    -- REVIEW7 / DESIGN-V3 B-8: Die Untertitel-Leiste haengt nicht mehr am Streamer-Schalter.
    --   aus   nie
    --   auto  wenn streamer laeuft ODER Lyra versteckt ist (dann kommt keine Blase) ODER die
    --         Schriftgroesse unter 12 liegt (sehr grosser UI-Scale, die Blase wird unlesbar klein)
    --   immer immer
    -- "streamer = true" setzt diesen Schluessel NICHT um; "auto" liest ihn nur mit.
    leiste = "auto",
    erbeImmer = false,         -- Vorgaenger-Erbe auch ausserhalb Hardcore (Sinne/Erbe.lua)
    ssf = false,               -- Solo Self-Found: keine Hinweise auf Handel/Auktion/Post (wenn-Tag "ssf")
    spielzeit = 0,             -- s, account-weit, ohne AFK (Sinne/Leben2.lua; legt das Feld sonst selbst an)
    -- WELLE 3 (0.8.0): Zusammenspiel mit Partner-Addons. Alle drei Default AN - sie machen Lyra
    -- persoenlicher, nicht lauter (die Drosseln liegen bei 10 min bzw. 1x je Boss/Sitzung).
    -- Die Stillhalte-Regel (Sinne/DBM.lua) hat bewusst KEINEN Schalter: sie kann Lyra nur
    -- leiser machen, nie lauter - dafuer braucht niemand ein Kaestchen.
    detailsKommentar = true,   -- Kommentar nach langen Kaempfen aus Details-Daten (Sinne/Details.lua)
    bossChronik = true,        -- Pulls/Kills/Wipes/beste Zeit je Boss merken (Sinne/DBM.lua)
    questieTief = true,        -- Zielzone, Queststufe, Kette aus Questie lesen (Sinne/Questie2.lua)
    klicks = 0,                -- Interaktions-Zaehler (Sinne/Persoenlichkeit.lua legt sie sonst selbst an)
    fragen = 0,
}
-- DESIGN-V3 D1: Default-Position. {"BOTTOMRIGHT", -40, 120} lag bei Standard- und bei
-- Bartender-artigen Layouts mitten in den Tasten. Links auf halber Hoehe ist der einzige Bereich,
-- den kaum jemand belegt - und Lyra guckt im Sprite nach rechts, also ins Bild hinein.
-- BESTANDSSCHUTZ: defaults() fuellt nur fehlende Schluessel. Wer schon eine "pos" hat, behaelt sie;
-- nur NEUE Nutzer (und "Position zuruecksetzen") bekommen den neuen Ort.
ns.POS_DEFAULT = { "LEFT", 24, 40 }
ns.DEFAULTS_CHAR = {
    anrede = "auto",           -- auto|m|f|keine
    -- groesse gehoert zu scale (dasselbe Mass, derselbe Charakter) und liegt deshalb hier, nicht im Account
    -- DESIGN-V3 A-2: groesse steuert im Portrait die KANTE (96|112|128, G.PORTRAIT_KANTE) und in
    -- der Figur ueber scale (0.35|0.5|0.7) die Hoehe. Das Portrait haengt nicht mehr an scale.
    groesse = "mittel",        -- klein|mittel|gross
    scale = 0.5,
    gesperrt = false,
    pos = { ns.POS_DEFAULT[1], ns.POS_DEFAULT[2], ns.POS_DEFAULT[3] },
    versteckt = false,
}

local function defaults(t, d)
    for k, v in pairs(d) do
        if t[k] == nil then
            if type(v) == "table" then t[k] = {}; defaults(t[k], v) else t[k] = v end
        end
    end
end

-- REVIEW7 (Entscheidung 17.09.2026, docs/design-v3-B-umsetzung.md "Offen / Entscheidungen"):
-- Bestandsnutzer mit gespeicherter schrift == 16 haben den ALTEN Default in der Datenbank - nie
-- bewusst gewaehlt, denn es WAR der Default. Sie werden EINMALIG auf "auto" gezogen; jeder andere
-- Wert (auch eine bewusst getippte 16 nach dieser Runde) bleibt unveraendert, dafuer ist das Flag
-- da. Das ist die einzige Stelle, an der 0.6.2 eine bestehende Einstellung ueberschreibt.
-- Sie laeuft NACH defaults(): eine frische Datenbank steht da schon auf "auto" und wird nur
-- abgehakt, damit die Wanderung nie zweimal denkt, sie muesse noch etwas tun.
function ns.schriftWanderung(acc)
    if type(acc) ~= "table" then return false end
    if acc.schriftAutoMigriert then return false end
    local gewandert = false
    if acc.schrift == 16 or acc.schrift == "16" then
        acc.schrift = "auto"
        gewandert = true
    end
    acc.schriftAutoMigriert = true
    return gewandert
end

function ns.initDB()
    LyraGestaltDB = LyraGestaltDB or {}
    LyraGestaltDB.account = LyraGestaltDB.account or {}
    LyraGestaltDB.chars = LyraGestaltDB.chars or {}
    defaults(LyraGestaltDB.account, ns.DEFAULTS_ACCOUNT)
    ns.schriftWanderung(LyraGestaltDB.account)
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    LyraGestaltDB.chars[key] = LyraGestaltDB.chars[key] or {}
    defaults(LyraGestaltDB.chars[key], ns.DEFAULTS_CHAR)
    ns.db = LyraGestaltDB.account
    ns.char = LyraGestaltDB.chars[key]
    ns.charKey = key
    LyraGestaltDB.chronik = LyraGestaltDB.chronik or {}   -- Phase 2
end

-- Get/Set entscheiden den Scope; Settings-Panel und Slash gehen NUR hierueber.
local CHAR_KEYS = { anrede = true, groesse = true, scale = true, gesperrt = true, pos = true, versteckt = true }
-- REVIEW6B: ns.Get muss VOR ns.initDB() halten. Die SavedVariables stehen erst bei ADDON_LOADED
-- bereit, also NACHDEM alle TOC-Dateien durchgelaufen sind - und seit design-v3 fragt UI/Optik.lua
-- (O.farben -> ns.Get("kontrast")) schon auf Dateiebene, gerufen aus UI/Dialog.lua beim Anlegen
-- der Trennlinie. Ohne diese Wache bricht UI/Dialog.lua beim Laden mittendrin ab: ns.Dialog.frage,
-- .zeigeKnoten, .antwort und .oeffne entstehen gar nicht mehr, und damit ist jeder Freitext-Intent
-- tot (auch alle w2_*). Vor initDB gilt jetzt schlicht die Voreinstellung.
function ns.Get(key)
    if CHAR_KEYS[key] then
        if not ns.char then return ns.DEFAULTS_CHAR[key] end
        return ns.char[key]
    end
    if not ns.db then return ns.DEFAULTS_ACCOUNT[key] end
    return ns.db[key]
end
function ns.Set(key, value)
    -- REVIEW6B: Schreiben vor initDB ginge ins Leere (und wuerde von ADDON_LOADED ueberschrieben).
    if not (ns.db and ns.char) then ns.debug("Set vor initDB verworfen: " .. tostring(key)); return end
    if CHAR_KEYS[key] then ns.char[key] = value else ns.db[key] = value end
    if ns.onSetting then ns.onSetting(key, value) end
end

-- Aktive Sprache
function ns.sprache()
    local s = ns.db and ns.db.sprache or "auto"
    if s == "auto" then
        local l = GetLocale()
        return (l == "deDE") and "de" or "en"
    end
    return s
end

-- Debug-/Meldungsausgabe (nur lokaler Chat-Frame, nie SendChatMessage)
function ns.print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffb48cffLyra|r " .. tostring(msg))
end
function ns.debug(msg)
    if ns.db and ns.db.debug then ns.print("|cff888888" .. tostring(msg) .. "|r") end
end

-- Event-Verteiler: ein Frame, Module abonnieren mit ns.on(event, fn)
local frame = CreateFrame("Frame")
local handlers = {}
ns.eventFrame = frame
function ns.on(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        pcall(frame.RegisterEvent, frame, event)
    end
    table.insert(handlers[event], fn)
end
function ns.onUnit(event, unit, fn)
    if not handlers[event] then
        handlers[event] = {}
        if frame.RegisterUnitEvent then pcall(frame.RegisterUnitEvent, frame, event, unit)
        else pcall(frame.RegisterEvent, frame, event) end
    end
    table.insert(handlers[event], fn)
end
frame:SetScript("OnEvent", function(_, event, ...)
    local hs = handlers[event]
    if not hs then return end
    for i = 1, #hs do
        local ok, err = pcall(hs[i], ...)
        if not ok then ns.debug(event .. ": " .. tostring(err)) end
    end
end)
