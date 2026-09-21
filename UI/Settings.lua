-- UI/Settings.lua — Einstellungspanel ueber die native Settings-API (Era 1.15.4+, Retail 11/12, TBC/MoP).
-- Alle Werte sind Proxy-Settings ueber ns.Get/ns.Set; Panel, Slash und Laufzeit teilen einen Pfad.
-- Fallback: InterfaceOptions_AddCategory (Uralt-Clients), sonst nur Slash.
-- API: Settings.*, CreateSettingsListSectionHeaderInitializer, CreateSettingsButtonInitializer,
--   Settings.RegisterVerticalLayoutSubcategory (guarded, Pruefpunkt 17). Nichts Fremdes.
-- DESIGN-V3 Team B (17.09.2026):
--   B-5  "Feineinstellung" ist eine eigene Unterkategorie. Oben stehen 13 Eintraege statt 33.
--        Faellt die API weg, bleibt die heutige lange Liste - also kein Risiko.
--   B-1  Schriftgroesse: Kaestchen "Automatisch (folgt der UI-Groesse)" ueber dem Slider.
--        Ist es an, steht in der Datenbank der String "auto"; der Slider uebersteuert mit einer Zahl.
--   B-13 Neue Einstellung "bewegung" (voll | reduziert | aus) - Barrierefreiheits-Punkt 6.
-- PORT (0.9.0): Die Settings-API ist auf ALLEN fuenf Clients dieselbe und wurde dafuer einzeln
--   geprueft - Settings.RegisterVerticalLayoutCategory/RegisterProxySetting/RegisterAddOnCategory
--   und CreateSettingsListSectionHeaderInitializer gibt es in Era 1.15.4+, TBC, MoP, Retail 12.x
--   und Forever. InterfaceOptions_AddCategory ist in Era seit 1.15.3 weg, auf Retail seit 10.0 -
--   der Legacy-Fallback unten wird darum auf keinem lebenden Client mehr erreicht und bleibt nur
--   als Notausgang stehen. ns.Compat.F.settingsApi haelt genau diese Pruefung fest.
--   NEU in dieser Runde: zwei Eintraege fuer Text-to-Speech ("tts", "ttsStimme") in der
--   Feineinstellung - das ist die einzige inhaltliche Aenderung an dieser Datei.
-- W11D (21.09.2026): zwei Kaestchen mehr im Karten-Abschnitt der Feineinstellung -
--   "sterbeort" (die Zeile am Sterbeort des Vorgaengers) und "pinSterbeort" (ihr Pin). Beide
--   waren seit Welle 11c nur ueber "/lyra karte sterbeort|sterbeortpin" erreichbar. Sie haengen
--   an DENSELBEN SavedVariables wie der Slash-Befehl - es gibt keinen zweiten Zustand -, und
--   S.anwenden zieht die Karte danach einmal nach (siehe unten).
local ADDON, ns = ...
local S = {}
ns.Settings = S

S.PREFIX = "LYRA_GESTALT_"
S.gestartet = false
S.category = nil        -- Settings-API-Kategorie (oben)
S.subcategory = nil     -- "Feineinstellung" (B-5), nil wenn die API fehlt
S.legacyPanel = nil     -- InterfaceOptions-Fallback
S.registriert = {}      -- key -> true, wenn ein Proxy-Setting dafuer existiert
S.i18n = {}             -- W7: { art, obj, keys } je beschriftetem Element (siehe baueNativ)
S.sprachGebaut = nil    -- W7: in welcher Sprache die Seite zuletzt beschriftet wurde

local function posDefault() return ns.POS_DEFAULT or { "LEFT", 24, 40 } end

-- ---------------------------------------------------------------------------------------------
-- Presets (design-v2.md 6.2): ein Eintrag setzt genau diese Schluessel, alles andere bleibt.
-- Das Preset ist KEIN Schloss: aendert man danach einen Einzelschalter, springt die Anzeige auf
-- "Eigene Einstellung". Presets, die Aenderungen zurueckdruecken, sind der Grund, warum Leute
-- Presets hassen.
-- ---------------------------------------------------------------------------------------------
S.PRESET_REIHE = { "gespraechig", "kampfNurWarnungen", "gruppeSchweigen", "cues", "frech", "glow", "streamer", "untertitel" }
S.PRESET_SCHLUESSEL = {}
for _, k in ipairs(S.PRESET_REIHE) do S.PRESET_SCHLUESSEL[k] = true end
S.PRESET_WERTE = {
    leise    = { gespraechig = "wenig",  kampfNurWarnungen = true,  gruppeSchweigen = true,  cues = false, frech = false, glow = true,  streamer = false },
    normal   = { gespraechig = "normal", kampfNurWarnungen = true,  gruppeSchweigen = true,  cues = true,  frech = true,  glow = true,  streamer = false },
    lebendig = { gespraechig = "viel",   kampfNurWarnungen = false, gruppeSchweigen = false, cues = true,  frech = true,  glow = true,  streamer = false },
    streamer = { gespraechig = "normal", kampfNurWarnungen = true,  gruppeSchweigen = true,  cues = true,  frech = true,  glow = false, streamer = true, untertitel = true },
}
S.presetLaeuft = false

function S.presetAnwenden(name)
    local w = S.PRESET_WERTE[name]
    if not w then return false end
    S.presetLaeuft = true
    for _, k in ipairs(S.PRESET_REIHE) do
        local v = w[k]
        if v ~= nil and ns.Get(k) ~= v then S.setze(k, v) end
    end
    S.presetLaeuft = false
    return true
end

function S.varName(key) return S.PREFIX .. key:upper() end

local function rundeAuf2(v) return math.floor(v * 100 + 0.5) / 100 end

-- Groessen-Preset <-> scale. Nur exakte Treffer, damit /lyra groesse 0.62 den Dropdown nicht verbiegt.
function S.groesseVonScale(sc)
    local G = ns.Gestalt
    local tab = (G and G.GROESSEN) or { klein = 0.35, mittel = 0.5, gross = 0.7 }
    for name, v in pairs(tab) do
        if math.abs((tonumber(sc) or 0) - v) < 0.001 then return name end
    end
    return nil
end

-- Wert anwenden: Nebenwirkungen + ns.Set (loest ns.onSetting aus -> Gestalt/Blase layouten neu).
function S.anwenden(key, value)
    if key == "gefahrenkarte" and ns.Sinne and ns.Sinne.GefahrenDaten then ns.Compat.After(0, function() ns.Sinne.GefahrenDaten.neu(UnitLevel("player")) end) end
    if key == "scale" and type(value) == "number" then value = rundeAuf2(value) end
    ns.Set(key, value)
    -- Preset-Logik: Dropdown gewaehlt -> Schluessel setzen; Einzelschalter geaendert -> "eigen".
    if key == "preset" then
        if not S.presetLaeuft and value ~= "eigen" then S.presetAnwenden(value) end
    elseif S.PRESET_SCHLUESSEL[key] and not S.presetLaeuft then
        if ns.Get("preset") ~= "eigen" then S.setze("preset", "eigen") end
    end
    -- Groesse <-> scale koppeln (die Gestalt rechnet beides aus "scale")
    if key == "groesse" then
        local G = ns.Gestalt
        local sc = G and G.GROESSEN and G.GROESSEN[value]
        if sc and ns.Get("scale") ~= sc then S.setze("scale", sc) end
    elseif key == "scale" then
        local name = S.groesseVonScale(value)
        if name and ns.Get("groesse") ~= name then S.setze("groesse", name) end
    end
    if key == "sprache" then
        if ns.Stimme then
            ns.Stimme.geladen = {}
            if ns.Get("stimme") then ns.Stimme.paketLaden(ns.sprache()) end
        end
        -- W7: die Beschriftungen nachziehen (Einstellungsseite, Menue, Gespraech, Chronik) und
        -- ehrlich sagen, was davon erst nach /reload greift. Guarded: ein Fehler hier darf den
        -- Sprachwechsel selbst nicht kippen - der ist an dieser Stelle schon passiert.
        local ok, err = pcall(S.sprachAnwenden)
        if not ok then ns.debug("Settings sprachAnwenden: " .. tostring(err)) end
    elseif key == "stimme" then
        if value and ns.Stimme then ns.Stimme.paketLaden(ns.sprache())
        elseif ns.Stimme and ns.Stimme.handle and StopSound then   -- REVIEW: laufende Zeile beim Ausschalten stoppen
            pcall(StopSound, ns.Stimme.handle); ns.Stimme.laeuftBis = 0
        end
    elseif key == "tts" then
        -- PORT (0.9.0): "aus" soll SOFORT still sein, nicht erst nach dem laufenden Satz.
        if value == "aus" and ns.Stimme and ns.Stimme.ttsStop then pcall(ns.Stimme.ttsStop) end
    elseif key == "ttsStimme" then
        if ns.Stimme then ns.Stimme.ttsStimmeId = nil end
    elseif key == "anrede" then
        ns.sexCache = nil
    elseif key == "bewegung" then
        S.bewegungAnwenden(value)                       -- B-13
    elseif key == "schrift" then
        if ns.Optik and ns.Optik.neuZeichnen then ns.Optik.neuZeichnen() end   -- B-1
    elseif key == "sterbeort" or key == "pinSterbeort" then
        -- W11D: derselbe Nachlauf, den "/lyra karte sterbeort|sterbeortpin" schon hatte
        -- (Sinne/Karte2.lua, K2.befehl). Ohne ihn verschwaende der Pin erst beim naechsten
        -- Zeichenanlass - Zonenwechsel oder Oeffnen der Weltkarte -, und ein Haekchen, das
        -- sichtbar nichts tut, sieht aus wie ein kaputtes Haekchen. Es wird die VORHANDENE
        -- Funktion gerufen, keine zweite gebaut; pcall, weil ein Fehler beim Zeichnen die
        -- Einstellung selbst nicht kippen darf - die ist an dieser Stelle schon gespeichert.
        if ns.Karte2 and ns.Karte2.aktualisieren then
            local ok, err = pcall(ns.Karte2.aktualisieren)
            if not ok then ns.debug("Settings Karte2: " .. tostring(err)) end
        end
    end
end

-- Von aussen (Slash, Klick) setzen: ueber Settings.SetValue, damit ein offenes Panel synchron bleibt.
function S.setze(key, value)
    if key == "scale" and type(value) == "number" then value = rundeAuf2(value) end
    if S.registriert[key] and Settings and Settings.SetValue then
        pcall(Settings.SetValue, S.varName(key), value)
        if ns.Get(key) == value then return end   -- Proxy-Setter hat S.anwenden ausgefuehrt
    end
    S.anwenden(key, value)
end

-- Probe: Drossel fuer LEERLAUF loeschen und melden. Rueckgabe wie ns.melde.
function S.probe()
    if ns.Regie then
        ns.Regie.cool["LEERLAUF"] = nil
        ns.Regie.zuletztPlauder = 0
    end
    local ok = ns.melde and ns.melde("LEERLAUF", { direkt = true })
    if not ok then
        local d = ns.Regie and ns.Regie.dropLog[1]
        ns.print(ns.L["Test silent"] .. (d and d[1] or "?"))
    end
    return ok
end

function S.positionReset()
    local p = posDefault()
    S.anwenden("pos", { p[1], p[2], p[3] })
end

-- B-7: Ein freier Platz statt des festen Defaults. Nur auf Zuruf (/lyra position vorschlag) -
-- Lyra verschiebt sich NIE von selbst; wer sie hingezogen hat, wo sie steht, hat recht.
function S.positionVorschlag()
    local O = ns.Optik
    if not (O and O.positionVorschlag) then return nil end
    local ok, p = pcall(O.positionVorschlag)
    if not (ok and type(p) == "table") then return nil end
    S.anwenden("pos", { p[1], p[2], p[3] })
    return p
end

-- ---------------------------------------------------------------------------------------------
-- B-13  Bewegung: voll | reduziert | aus
-- Gestalt.lua wird dafuer NICHT angefasst. Alle drei Stufen lassen sich ueber die vorhandene
-- Schnittstelle fahren:
--   * "aus"       -> G.animationen(false). Das setzt G.animationenAus, und daran haengen Takt,
--                    Atmen, Nicken UND der Warn-Ruck. Dazu wird G.regung gesperrt (Wrapper, wie
--                    Sinne/Profil.lua es mit ns.Stimmung.tags macht) und G.FADE_DAUER auf 0
--                    gesetzt: harte Mienenwechsel statt Crossfade.
--   * "reduziert" -> die Amplituden der Dauerbewegung auf 0 (G.ATEM.weg, G.NICK.weg) bzw. der
--                    Ring-Puls auf einen festen Wert (PULS_*.von = .bis). Der Takt laeuft weiter,
--                    setzt aber immer denselben Wert - damit bleiben Ruck und Regungen erhalten,
--                    genau wie es die Prueflise verlangt. Crossfade 0,25 -> 0,1 s.
--   * "voll"      -> die gemerkten Ausgangswerte zurueck.
-- Der Halo-Puls aus A-3 gehoert Team A; die Patch-Anweisung steht in docs/design-v3-B-patches.md.
-- ---------------------------------------------------------------------------------------------
S.BEWEGUNG_WERTE = { voll = true, reduziert = true, aus = true }
local bewegungOrig          -- Ausgangswerte, einmal beim ersten Anwenden gemerkt
local regungOrig            -- Original von G.regung (Wrapper nur EINMAL legen)

local function regungWrappen()
    local G = ns.Gestalt
    if regungOrig or not (G and type(G.regung) == "function") then return end
    regungOrig = G.regung
    G.regung = function(...)
        if ns.Get("bewegung") == "aus" then return false end
        return regungOrig(...)
    end
end

function S.bewegungAnwenden(wert)
    local G = ns.Gestalt
    if not G then return false end
    regungWrappen()
    if not bewegungOrig then
        bewegungOrig = {
            atem = G.ATEM and G.ATEM.weg,
            nick = G.NICK and G.NICK.weg,
            pulsAtem = G.PULS_ATEM and G.PULS_ATEM.von,
            pulsNick = G.PULS_NICK and G.PULS_NICK.von,
            fade = G.FADE_DAUER,
        }
    end
    local o = bewegungOrig
    if not S.BEWEGUNG_WERTE[wert] then wert = "voll" end
    -- Erst immer die Ausgangswerte herstellen, dann die Stufe darauf anwenden. Sonst haengt das
    -- Ergebnis davon ab, aus welcher Stufe man kommt.
    if G.ATEM and o.atem then G.ATEM.weg = o.atem end
    if G.NICK and o.nick then G.NICK.weg = o.nick end
    if G.PULS_ATEM and o.pulsAtem then G.PULS_ATEM.von = o.pulsAtem end
    if G.PULS_NICK and o.pulsNick then G.PULS_NICK.von = o.pulsNick end
    G.FADE_DAUER = o.fade or 0.25
    if wert == "aus" then
        if G.animationen then pcall(G.animationen, false) end
        if G.regungEnde then pcall(G.regungEnde) end
        G.FADE_DAUER = 0
    else
        -- "animation" bleibt der Not-Schalter zur Fehlersuche und hat Vorrang.
        if G.animationen then pcall(G.animationen, ns.Get("animation") ~= false) end
        if wert == "reduziert" then
            if G.ATEM then G.ATEM.weg = 0 end
            if G.NICK then G.NICK.weg = 0 end
            if G.PULS_ATEM then G.PULS_ATEM.von = G.PULS_ATEM.bis end
            if G.PULS_NICK then G.PULS_NICK.von = G.PULS_NICK.bis end
            G.FADE_DAUER = 0.1
        end
    end
    if G.nullstellung then pcall(G.nullstellung) end
    return true
end

-- Erst-Start-Assistent erneut starten (Menue, Panel-Knopf, /lyra einrichten)
function S.assistent()
    if ns.starteAssistent then return ns.starteAssistent() end
    if ns.Dialog and ns.Dialog.oeffne then return ns.Dialog.oeffne("setup_sprache") end
    return false
end

-- ---------------------------------------------------------------------------------------------
-- Native Settings-API
-- ---------------------------------------------------------------------------------------------
local function baueNativ()
    local L = ns.L
    S.i18n = {}
    local VT = Settings.VarType
    -- W8: der Kategorie- und Seitentitel ist der ANZEIGENAME aus den Locales, und der heisst
    -- seit dem 20.09.2026 "Lyra Companion" (de wie en) statt "Lyra Gestalt" - so wie das Addon
    -- ueberall sonst heisst (TOC-Title, Website, CurseForge). Der SCHLUESSEL bleibt
    -- "Lyra Gestalt": er ist ein interner Name, und der Ordner, LyraGestaltDB und alle
    -- LyraGestalt_*-Globalen heissen unveraendert so.
    local category, layout = Settings.RegisterVerticalLayoutCategory(L["Lyra Gestalt"])
    S.category = category

    -- B-5: Die Unterkategorie. Pruefpunkt 17 ("gibt es die API in Era?") ist im Spiel offen -
    -- deshalb guarded: fehlt sie, zeigen fein/feinLayout auf die Hauptliste und alles steht
    -- wie bisher untereinander. Kein Risiko, nur ein Gewinn, wenn es sie gibt.
    local fein, feinLayout = category, layout
    if Settings.RegisterVerticalLayoutSubcategory then
        local ok, sub, subLayout = pcall(Settings.RegisterVerticalLayoutSubcategory, category, L["Fine tuning"])
        if ok and sub and subLayout then
            S.subcategory = sub
            fein, feinLayout = sub, subLayout
        else
            ns.debug("Settings: Unterkategorie nicht angelegt (" .. tostring(sub) .. ")")
        end
    end

    local function default(key)
        local v = ns.DEFAULTS_CHAR[key]
        if v == nil then v = ns.DEFAULTS_ACCOUNT[key] end
        return v
    end
    -- kat = category (oben) oder fein (Unterkategorie). get/set/default sind optional und werden
    -- nur fuer die beiden Schrift-Bedienelemente gebraucht (B-1).
    -- W7 (Screenshot-Befund 4, Bildschirmfoto_20260920_112806.png): Nach "/lyra sprache en" stand
    -- die Einstellungsseite weiter auf Deutsch - "Sprache: Englisch" im Dropdown, aber "Wie soll
    -- Lyra sein?" als Ueberschrift. Grund: baueNativ() laeuft EINMAL beim Login und loest dabei
    -- jede Beschriftung ueber ns.L auf; der aufgeloeste String liegt danach in der Settings-API
    -- und weiss nichts mehr von seinem Schluessel.
    -- Seit W7 reichen die Helfer unten SCHLUESSEL herum ("Language") statt Strings ("Sprache").
    -- Aufgeloest wird erst hier - und ein zweites Mal in S.sprachNeu(), das dieselben Objekte
    -- noch einmal beschriftet. Die Dropdown-EINTRAEGE brauchen gar nichts: ihre Generator-
    -- Funktion laeuft bei jedem Oeffnen der Liste, sie loest die Schluessel also von selbst neu auf.
    -- Was NICHT geht, steht ehrlich in S.sprachNeu().
    local function T(k) return (k ~= nil) and ns.L[k] or nil end
    local function merke(art, obj, ...)
        if not obj then return obj end
        S.i18n[#S.i18n + 1] = { art = art, obj = obj, keys = { ... } }
        return obj
    end

    local function proxy(kat, key, typ, nameKey, opt)
        opt = opt or {}
        local vorgabe = opt.default
        if vorgabe == nil then vorgabe = default(key) end
        local setting = Settings.RegisterProxySetting(kat, S.varName(key), typ, T(nameKey), vorgabe,
            opt.get or function() return ns.Get(key) end,
            opt.set or function(v) S.anwenden(key, v) end)
        if not opt.virtuell then S.registriert[key] = true end
        merke("setting", setting, nameKey)
        return setting
    end
    local function header(kat, textKey)
        local l = (kat == category) and layout or feinLayout
        local init = CreateSettingsListSectionHeaderInitializer(T(textKey))
        l:AddInitializer(init)
        return merke("header", init, textKey)
    end
    local function checkbox(kat, key, nameKey, tipKey, opt)
        return merke("init", Settings.CreateCheckbox(kat, proxy(kat, key, VT.Boolean, nameKey, opt), T(tipKey)),
            nameKey, tipKey)
    end
    local function dropdown(kat, key, nameKey, eintraege, tipKey)   -- eintraege = { {wert, labelKey}, ... }
        local setting = proxy(kat, key, VT.String, nameKey)
        return merke("init", Settings.CreateDropdown(kat, setting, function()
            local c = Settings.CreateControlTextContainer()
            -- Erst HIER wird der Schluessel aufgeloest. ns.L faellt auf den Schluessel selbst
            -- zurueck, wenn es ihn nicht gibt - die TTS-Stimmennamen gehen also unveraendert durch.
            for _, e in ipairs(eintraege) do c:Add(e[1], T(e[2])) end
            return c:GetData()
        end, T(tipKey)), nameKey, tipKey)
    end
    local function sliderOptionen(min, max, step, fmt)
        local o = Settings.CreateSliderOptions(min, max, step)
        if fmt and o.SetLabelFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
            o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, fmt)
        end
        return o
    end
    local function slider(kat, key, nameKey, min, max, step, fmt, tipKey, opt)
        return merke("init", Settings.CreateSlider(kat, proxy(kat, key, VT.Number, nameKey, opt),
            sliderOptionen(min, max, step, fmt), T(tipKey)), nameKey, tipKey)
    end
    local function button(kat, nameKey, textKey, fn, tipKey)
        local l = (kat == category) and layout or feinLayout
        local init = CreateSettingsButtonInitializer(T(nameKey), T(textKey), fn, T(tipKey), false)
        l:AddInitializer(init)
        return merke("knopf", init, nameKey, tipKey, textKey)
    end
    local prozent = function(v) return ("%d %%"):format(math.floor(v * 100 + 0.5)) end
    local sekunden = function(v) return ("%d s"):format(v) end
    local ganz = function(v) return ("%d"):format(v) end

    -- =====================================================================================
    -- OBEN: 13 Eintraege. Die Entscheidungen, die jeder einmal trifft (design-v3 e.6).
    -- =====================================================================================
    -- 1  Preset: eine Entscheidung statt 25 (design-v2.md 6.2)
    header(category, "How should Lyra be?")
    dropdown(category, "preset", "Preset", {
        { "leise", "Preset quiet" }, { "normal", "Preset normal" },
        { "lebendig", "Preset lively" }, { "streamer", "Preset streamer" },
        { "eigen", "Preset custom" },
    }, "Preset tip")

    -- 2, 3  Sprache und Anrede
    header(category, "Language and address")
    dropdown(category, "sprache", "Language", { { "auto", "Auto" }, { "de", "German" }, { "en", "English" } })
    dropdown(category, "anrede", "Address", { { "auto", "By character" }, { "m", "Male" }, { "f", "Female" }, { "keine", "No address" } })

    -- 4, 5  Stimme und Gespraechigkeit
    header(category, "Voice")
    checkbox(category, "stimme", "Voice enabled")
    dropdown(category, "gespraechig", "Talkativeness", { { "still", "Silent" }, { "wenig", "Little" }, { "normal", "Normal" }, { "viel", "Chatty" } })

    -- 6, 7  Ansicht und Groesse (design-v2.md 1.3/1.4; "scale" bleibt intern und ueber
    --       /lyra groesse <zahl> erreichbar)
    header(category, "Figure")
    dropdown(category, "ansicht", "View", { { "portrait", "View portrait" }, { "figur", "View figure" } }, "View tip")
    dropdown(category, "groesse", "Size preset", { { "klein", "Size small" }, { "mittel", "Size medium" }, { "gross", "Size large" } }, "Size preset tip")

    -- 8, 9  B-1: Schriftgroesse. Das Kaestchen schreibt den String "auto" in die Datenbank, der
    --       Slider eine Zahl - beide auf denselben Schluessel, deshalb zwei Bedienelemente und
    --       nicht zwei Werte. Der Slider ZEIGT bei "auto" den errechneten Wert (der Getter geht
    --       ueber ns.Optik.schriftgroesse()) und uebersteuert, sobald man ihn anfasst.
    header(category, "Readability")
    local cbAuto = checkbox(category, "schriftAuto", "Font size auto", "Font size auto tip", {
        virtuell = true,
        default = (ns.DEFAULTS_ACCOUNT.schrift == "auto"),
        get = function() return ns.Get("schrift") == "auto" end,
        set = function(v)
            if v then S.anwenden("schrift", "auto")
            else S.anwenden("schrift", ns.Optik and ns.Optik.schriftgroesse() or 16) end
        end,
    })
    local slSchrift = slider(category, "schrift", "Font size", 10, 28, 1, ganz, "Font size tip", {
        default = 16,
        get = function() return (ns.Optik and ns.Optik.schriftgroesse()) or 16 end,
        -- "auto" muss durch: S.setze("schrift", "auto") laeuft ueber Settings.SetValue und landet
        -- genau hier. Ein blindes tonumber() haette daraus 16 gemacht und die Automatik
        -- ausgeschaltet, sobald sie jemand ueber Slash oder Menue einschaltet.
        set = function(v)
            if v == "auto" then S.anwenden("schrift", "auto")
            else S.anwenden("schrift", tonumber(v) or 16) end
        end,
    })
    -- Slider ausblenden, solange "Automatisch" an ist. Nur, wenn die API es hergibt.
    if slSchrift and cbAuto and slSchrift.SetParentInitializer then
        pcall(slSchrift.SetParentInitializer, slSchrift, cbAuto, function() return ns.Get("schrift") ~= "auto" end)
    end

    -- 10  B-13: Bewegung (Barrierefreiheits-Punkt 6)
    dropdown(category, "bewegung", "Motion", {
        { "voll", "Motion full" }, { "reduziert", "Motion reduced" }, { "aus", "Motion off" },
    }, "Motion tip")

    -- 11  Der Bildschirm-Puls bleibt oben: das ist der Lichtempfindlichkeits-Schalter, und der
    --     gehoert nicht zwei Klicks tief (Barrierefreiheits-Punkt 5/14).
    checkbox(category, "glow", "Screen glow on warnings", "Screen glow tip")

    -- W6  Barrierefreiheit. OBEN, nicht in der Feineinstellung - und das ist keine Geschmacks-
    --     frage: Recherche 10 §1 nennt "Optionen zu tief vergraben" als einen der am haeufigsten
    --     belegten Kritikpunkte an Nachbar-Addons (vier Nutzer suchten gemeinsam nach Deathlogs
    --     Level-Filter). Ein Schalter, den nur findet, wer ihn nicht braucht, ist keiner.
    header(category, "Accessibility")
    checkbox(category, "barrierefrei", "Accessibility mode", "Accessibility mode tip")
    checkbox(category, "figur", "Figure visible", "Figure visible tip")
    -- W8 (Design-Deckel B-5, pruefstand-wiederaufbau §5 Punkt 3): "warnSymbol" ist nach unten
    -- in die Feineinstellung gewandert. Damit stehen oben wieder 13 Einstellungen statt 14.
    --
    -- Warum ausgerechnet dieses Kaestchen und keines der anderen drei aus dem Abschnitt:
    -- "barrierefrei" ist der Hauptschalter (der muss oben stehen, sonst findet ihn nur, wer ihn
    -- nicht braucht - genau das Argument aus Recherche 10 §1), "figur" nimmt die Figur ganz weg
    -- und ist damit eine der groessten Entscheidungen ueberhaupt. "warnSymbol" ist dagegen eine
    -- DARSTELLUNGSFRAGE zu etwas, das ohnehin laeuft: das Formsymbol steht per Vorgabe an, der
    -- Barrierefreiheits-Modus macht es groesser, und wer es abschalten will, will genau eine
    -- Kleinigkeit anders - das ist die Definition der Feineinstellung. Der Schalter liegt unten
    -- im Abschnitt "Lesbarkeit", neben "Hoher Kontrast", wo er sachlich hingehoert.

    -- 12, 13  Ausprobieren und Einrichten
    header(category, "Try it")
    button(category, "Test", "Test", S.probe, "Test tip")
    button(category, "Setup wizard", "Setup wizard", S.assistent, "Setup wizard tip")

    -- =====================================================================================
    -- FEINEINSTELLUNG: alles, was man einmal einstellt und dann nie wieder anfasst.
    -- =====================================================================================
    header(fein, "Voice")
    dropdown(fein, "kanal", "Sound channel", { { "Master", "Master" }, { "SFX", "SFX" }, { "Dialog", "Dialog" }, { "Ambience", "Ambience" } }, "Sound channel tip")
    -- W11B-6: LYRAS EIGENER REGLER, und er steht bewusst UEBER Blizzards Dialog-Regler.
    -- Befund docs/review-bindung-2026-09-20.md §6.1: bis 0.14.0 war der einzige "Lautstaerke"-
    -- Schieber auf dieser Seite Blizzards Sound_DialogVolume - also alle Questgeber mit. Wer
    -- Lyra leiser wollte, machte das ganze Spiel leiser. Der neue Regler ist relativ zu dem
    -- Kanal darueber und stellt Blizzards Wert nach jeder Zeile exakt zurueck
    -- (Gestalt/Stimme.lua, Block W11B-6). Alarme der Stufe 3 bleiben voll laut - das steht im
    -- Hinweistext, denn ein Regler, der bei einem Wert heimlich nicht gilt, ist eine Falle.
    slider(fein, "lautstaerke", "Lyra volume", 0, 100, 5, ganz, "Lyra volume tip", { default = 100 })
    -- HOTFIX 0.16.1 (21.09.2026, Spieltest Harald): Bis 0.16.0 stand hier zusaetzlich Blizzards
    -- Dialog-Regler, angemeldet ueber Settings.RegisterCVarSetting(fein, "Sound_DialogVolume").
    -- Blizzards eigene Audio-Seite meldet DIESELBE Variable an, und der Settings-Registrar
    -- erlaubt jeden Variablennamen nur einmal: 13x "Setting variable 'Sound_DialogVolume' was
    -- previously registered" (Blizzard_SettingsPanel.lua:711) beim Login, rotes Fehlerfenster.
    -- Seit W11B-6 hat Lyra ihren eigenen Regler darueber; der Blizzard-Regler ist ueberfluessig
    -- und faellt weg. Wer den Dialog-Kanal insgesamt leiser will, findet ihn bei Blizzard unter
    -- Ton, und der Hinweistext des Kanal-Dropdowns sagt das.
    -- PORT (0.9.0): Text-to-Speech. Standard "aus" — die Stimmen kommen vom Betriebssystem, und
    -- unter Linux/Wine ist die Liste voraussichtlich leer. Die Stimmen-Auswahl steht NUR da, wenn
    -- der Client ueberhaupt eine Stimme meldet; sonst waere es ein Dropdown mit einem Eintrag,
    -- das nichts tut. Der Hinweistext sagt in dem Fall, warum.
    if ns.Compat.F.tts then
        local stimmen = (ns.Stimme and ns.Stimme.ttsStimmen and ns.Stimme.ttsStimmen()) or {}
        dropdown(fein, "tts", "TTS mode", {
            { "aus", "TTS off" }, { "fallback", "TTS fallback" }, { "immer", "TTS always" },
        }, (#stimmen > 0) and "TTS tip" or "TTS no voices")
        if #stimmen > 0 then
            local eintraege = { { "auto", "Auto" } }
            for i = 1, #stimmen do
                local st = stimmen[i]
                if st and st.voiceID then
                    eintraege[#eintraege + 1] = { tostring(st.voiceID), tostring(st.name or st.voiceID) }
                end
            end
            dropdown(fein, "ttsStimme", "TTS voice", eintraege, "TTS voice tip")
        end
        -- W9a (KI-Audit L2): "Auch persoenliche Zeilen vorlesen", Standard AUS. Er steht
        -- INNERHALB des tts-Blocks und damit nur auf Clients mit Vorlese-API: ein Schalter fuer
        -- eine Schicht, die es hier gar nicht gibt, ist eine Frage ohne Antwort. Was er tut,
        -- steht in Gestalt/Stimme.lua am ns.nachAusgabe-Hook.
        checkbox(fein, "ttsPersoenlich", "TTS personal", "TTS personal tip")
    end
    checkbox(fein, "untertitel", "Subtitles")
    -- REVIEW7 / DESIGN-V3 B-8: die Untertitel-Leiste haengt nicht mehr am Streamer-Schalter.
    dropdown(fein, "leiste", "Subtitle bar", {
        { "aus", "Subtitle bar off" }, { "auto", "Subtitle bar auto" }, { "immer", "Subtitle bar always" },
    }, "Subtitle bar tip")
    checkbox(fein, "cues", "Sound cues")

    header(fein, "Readability")
    checkbox(fein, "kontrast", "High contrast")
    checkbox(fein, "warnSymbol", "Warning symbol", "Warning symbol tip")   -- W8: von Seite 1 hierher (B-5)
    slider(fein, "blaseDauer", "Bubble duration", 3, 15, 1, sekunden)
    slider(fein, "kampfAlpha", "Combat transparency", 0.4, 1.0, 0.1, prozent, "Combat transparency tip")   -- REVIEW2: Tooltips lagen ungenutzt in den Locales

    header(fein, "Behavior")
    checkbox(fein, "kampfNurWarnungen", "Combat: warnings only")
    checkbox(fein, "gruppeSchweigen", "Quiet in groups")
    checkbox(fein, "frech", "Cheeky humor")
    -- Feature-Welle 1 (Sinne/Extra.lua, Sinne/Erbe.lua, UI/Streamer.lua)
    checkbox(fein, "fotos", "Photos", "Photos tip")
    checkbox(fein, "ultra", "Ultra mode", "Ultra mode tip")
    checkbox(fein, "streamer", "Streamer mode", "Streamer mode tip")
    checkbox(fein, "erbeImmer", "Legacy also outside Hardcore", "Legacy tip")
    checkbox(fein, "ssf", "Self-found", "Self-found tip")

    header(fein, "Figure")
    checkbox(fein, "gesperrt", "Locked")
    checkbox(fein, "versteckt", "Hidden")
    button(fein, "Reset position", "Reset position", S.positionReset, "Reset position tip")
    checkbox(fein, "minimap", "Minimap button")

    header(fein, "Data sources")
    checkbox(fein, "gefahrenkarte", "Danger map")
    -- W8: die praeventive Warnung (Sinne/Welle8.lua). Steht direkt unter der Gefahrenkarte, weil
    -- sie deren Zellen liest und mit ihr zusammen aus ist. Eigener Schalter, weil sie das einzige
    -- ist, was Lyra sagt, BEVOR etwas passiert - und wer das nicht will, soll den Rest der
    -- Gefahrenkarte behalten duerfen (Overlay, Warnung beim Betreten).
    checkbox(fein, "vorwarnung", "Pre-warning", "Pre-warning tip")
    checkbox(fein, "profil", "Playstyle profile")
    checkbox(fein, "karte", "Map pins setting")
    -- WELLE 3 (0.8.0). Die Stillhalte-Regel aus Sinne/DBM.lua steht hier bewusst NICHT: sie
    -- macht Lyra nur leiser und braucht keinen Schalter (Begruendung in Core/Init.lua).
    checkbox(fein, "detailsKommentar", "Details comment", "Details comment tip")
    checkbox(fein, "bossChronik", "Boss chronicle", "Boss chronicle tip")
    checkbox(fein, "questieTief", "Questie deep", "Questie deep tip")

    -- W4: Welle 4 (0.9.x). Eigener Abschnitt, damit die Datenquellen-Liste nicht auf acht
    -- Kaestchen anwaechst. Die HC-Wechsel-Zeile steht hier bewusst NICHT - sie feuert ein
    -- Charakterleben lang ein- bis zweimal, dafuer braucht niemand einen Schalter
    -- (dieselbe Begruendung wie fuer die DBM-Stillhalte in Welle 3).
    header(fein, "Wave 4")
    checkbox(fein, "berufMoment", "Profession moment", "Profession moment tip")
    checkbox(fein, "ersteHilfe", "First aid", "First aid tip")
    checkbox(fein, "knotenGatherMate", "GatherMate nodes", "GatherMate nodes tip")
    checkbox(fein, "waSignal", "WA signal", "WA signal tip")

    -- W5: Feature-Welle 5 "Karte" (Sinne/Karte2.lua). Der Hauptschalter "karte" steht weiter
    -- oben unter "Datenquellen" und bleibt der Hauptschalter: ist er aus, liegt kein Pin auf
    -- der Karte, egal was hier steht. Diese vier sind die Feinheiten darunter.
    header(fein, "Wave 5")
    checkbox(fein, "pinBeinahe", "Pin close calls", "Pin close calls tip")
    checkbox(fein, "pinNotiz", "Pin notes", "Pin notes tip")
    checkbox(fein, "pinGefahr", "Danger overlay", "Danger overlay tip")
    checkbox(fein, "punktNah", "Waypoint proximity", "Waypoint proximity tip")
    -- W11D (21.09.2026): die zwei Schalter aus Welle 11c, die bisher NUR ueber Slash erreichbar
    -- waren (docs/welle11c-2026-09-20.md §7 Punkt 2). Sie stehen hier und nicht in einem eigenen
    -- Abschnitt "Welle 11c": beide gehoeren zu Sinne/Karte2.lua, haengen wie die vier darueber am
    -- Hauptschalter "karte" und werden in derselben Sekunde gesucht wie "Beinahe-Pins". Ein
    -- eigener Abschnitt fuer zwei Kaestchen waere eine Ueberschrift mehr auf einer Seite, die der
    -- Design-Deckel B-5 gerade erst kurz gemacht hat. Sechs Eintraege sind hier die Obergrenze -
    -- wer eine siebte Karten-Feinheit baut, teilt den Abschnitt (so wie Welle 4 die
    -- Datenquellen-Liste geteilt hat, statt sie auf acht anwachsen zu lassen).
    -- Der Deckel selbst ist unberuehrt: die erste Seite behaelt ihre 14 Eintraege, beide
    -- Kaestchen liegen zwei Klicks tief in der Feineinstellung.
    checkbox(fein, "sterbeort", "Death spot line", "Death spot line tip")
    checkbox(fein, "pinSterbeort", "Pin death spots", "Pin death spots tip")

    -- W6: Feature-Welle 6 (Sinne/Welle6.lua). Der Buendel-Schalter steht OBEN; hier stehen die
    -- drei Feinheiten, die man einmal entscheidet. Die GTFO-Stillhalte hat wie die von
    -- DBM/BigWigs bewusst KEIN Kaestchen - eine Regel, die Lyra nur leiser machen kann,
    -- braucht keins (Begruendung in Core/Init.lua).
    header(fein, "Wave 6")
    checkbox(fein, "sprecher", "Speaker name", "Speaker name tip")
    checkbox(fein, "ttsKoexistenz", "Coexistence", "Coexistence tip")
    checkbox(fein, "oggZurueckhalten", "Hold own voice", "Hold own voice tip")

    -- W9B: Freitext (UI/Freitext.lua). Zwei Kaestchen, mehr braucht es nicht. "Freitext" ist
    -- der Hauptschalter fuer Eingabefeld UND Absichts-Bank; ist er aus, gibt es kein Feld und
    -- keinen zusaetzlichen Rueckfall in UI/Dialog.lua. "Fragen merken" ist der EINZIGE Weg,
    -- auf dem getippter Text dieses Addons je auf die Festplatte kommt - er steht darum
    -- ausdruecklich hier und ausdruecklich auf AUS.
    header(fein, "Wave 9b")
    checkbox(fein, "freitext", "Freetext", "Freetext tip")
    checkbox(fein, "fragenMerken", "Remember questions", "Remember questions tip")

    -- W11B-4: die zuletzt gehoerten Ereignisse.
    --
    -- DER AUFTRAG WOLLTE HIER EINE LISTE MIT HAEKCHEN, UND DIE GIBT ES NICHT. Grund, geprueft
    -- und nicht geraten: diese Seite wird EINMAL gebaut - baueNativ() laeuft beim Login (bzw.
    -- beim ersten Oeffnen), und jedes Bedienelement entsteht dabei aus einem Initializer, den
    -- Settings.RegisterAddOnCategory in dem Moment einsammelt. Welche Ereignisse der Spieler
    -- "zuletzt gehoert" hat, weiss zu diesem Zeitpunkt niemand: der Ringpuffer ist leer. Eine
    -- feste Liste ALLER 124 Katalog-IDs waere die Alternative - 124 Kaestchen in einer
    -- Feineinstellung sind keine Bedienung, sondern eine Strafe, und sie widersprechen dem
    -- Design-Deckel B-5, der diese Seite ueberhaupt erst erträglich gemacht hat.
    -- Also ein KNOPF: er schreibt die Liste mit IDs in den Chat, zusammen mit der Zeile, die
    -- eines davon abschaltet. Das ist ein Klick mehr und eine ehrliche Loesung.
    -- Wenn Welle 12 das gebuendelte Fenster baut (review-bindung P-15/W12-13), gehoert die
    -- Liste mit Haekchen dorthin und nicht hierher.
    header(fein, "Wave 11b")
    button(fein, "Recently heard button", "Recently heard button", function()
        if ns.CMDS_gehoert then ns.CMDS_gehoert() end
    end, "Recently heard button tip")

    -- MERGE 0.16.0 (21.09.2026): Welle 13 "Andockstellen" — EIN Abschnitt fuer alle acht
    -- Kaestchen der vier Bauteams, nicht vier.
    --
    -- Jedes der vier Teams hat einen eigenen Abschnitt vorgeschlagen ("Wave 13a", "Wave 13",
    -- "Wave 13c"), und 13d wollte sein einzelnes Kaestchen unter "Data sources" zu "karte"
    -- stellen. Beides ist hier abgelehnt, und zwar aus derselben Richtung, aus der Welle 4
    -- seinerzeit die Datenquellen-Liste geteilt hat: entschieden wird nach der Zahl der
    -- Ueberschriften, die ein Spieler ueberfliegen muss.
    --   * Vier Ueberschriften fuer EINE Welle waeren vier Zeilen Navigation fuer acht Kaestchen.
    --     Die Wellen-Nummer ist ausserdem eine Bau-Information; fuer den Spieler ist "13a" von
    --     "13c" nicht unterscheidbar. Genau die Begruendung, mit der W11D zwei Kaestchen NICHT
    --     in einen Abschnitt "Welle 11c" gesteckt hat.
    --   * "lagerAnderswo" oben unter "Data sources" waere das neunte Kaestchen in einem
    --     Abschnitt, der bei sechs schon voll war — und es haette das eine Kaestchen der Welle
    --     von den anderen sieben getrennt, die dieselbe Frage stellen: welche fremde Quelle
    --     darf Lyra lesen? Genau das ist der gemeinsame Abschnitt.
    -- Der Name folgt der Reihe der bestehenden Abschnitte (Locale-Schluessel "Wave NN", Text
    -- beschreibend): de "Andockstellen", en "Further data sources". NICHT "Data sources" - die
    -- Ueberschrift gibt es oben schon einmal, zweimal derselbe Wortlaut auf einer Seite ist
    -- keine Gliederung.
    -- Alle acht stehen ab Werk auf AN; die Voreinstellungen haengen in den vier Sinne-Dateien
    -- an ns.DEFAULTS_ACCOUNT, Core/Init.lua bleibt unberuehrt.
    -- Die erste Seite bleibt unberuehrt (Design-Deckel B-5): acht Kaestchen, zwei Klicks tief.
    header(fein, "Wave 13")
    -- 13a: vier Bauteile, drei Kaestchen. "Reittier" und "hundert Gold" sind derselbe Gedanke
    -- (der eine Meilenstein, den ein Charakter genau einmal erreicht) und teilen eins.
    checkbox(fein, "questStapel", "Quest pile", "Quest pile tip")
    checkbox(fein, "berufRangNativ", "Profession rank native", "Profession rank native tip")
    checkbox(fein, "meilensteine", "Milestones", "Milestones tip")
    -- 13b, 13c, 13d: benannt nach dem, was sie TUN, nicht nach dem Fremd-Addon (Recherche 18
    -- §3) - wer Questie, NpcAbilities, Details, Rarity oder BagBrother deinstalliert, soll hier
    -- keine tote Zeile suchen muessen.
    checkbox(fein, "abgabeweg", "Turn-in way", "Turn-in way tip")
    checkbox(fein, "gegnerMechanik", "Enemy mechanic", "Enemy mechanic tip")
    checkbox(fein, "todHergang", "Death course", "Death course tip")
    checkbox(fein, "sammelAusdauer", "Farm persistence", "Farm persistence tip")
    checkbox(fein, "lagerAnderswo", "Stored elsewhere", "Stored elsewhere tip")

    Settings.RegisterAddOnCategory(category)
end

-- ---------------------------------------------------------------------------------------------
-- Legacy-Fallback (InterfaceOptions_AddCategory; auf 1.15.4+/10.0+ nie erreicht)
-- ---------------------------------------------------------------------------------------------
local function baueLegacy()
    local panel = CreateFrame("Frame")
    panel.name = ns.L["Lyra Gestalt"]
    local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText(ns.L["Lyra Gestalt"] .. " " .. ns.VERSION .. "  -  /lyra")
    InterfaceOptions_AddCategory(panel)
    S.legacyPanel = panel
end

-- =============================================================================================
-- W7 (20.09.2026) — SPRACHWECHSEL OHNE /reload
--
-- BEFUND (Bildschirmfoto_20260920_112806.png): nach "/lyra sprache en" blieb die Einstellungs-
--   seite deutsch. Im Chat stand "Lyra sprache: en" - und sonst passierte sichtbar nichts.
-- URSACHE: baueNativ() laeuft einmal beim Login. ns.L loest bei jedem Zugriff neu auf, aber
--   die Settings-API bekommt fertige Strings und legt sie ab.
-- FIX: die Beschriftungen werden nachgezogen. Drei Wege, absteigend nach Zuverlaessigkeit:
--   1. Dropdown-EINTRAEGE: ihre Generator-Funktion laeuft bei jedem Oeffnen der Liste. Sie
--      loesen ihre Schluessel seit W7 selbst auf - da ist nichts nachzuziehen, das ist schon
--      richtig. Der sicherste der drei Wege.
--   2. Namen und Hinweise von Kaestchen, Schiebereglern, Dropdowns, Ueberschriften, Knoepfen:
--      das Setting-Objekt (.name) und die Daten des Initializers (.name/.tooltip/.buttonText)
--      bekommen den neuen Text, danach wird die Liste einmal neu gezeichnet. Das ist eine
--      Annahme ueber Blizzards Datenstruktur, also VOLLSTAENDIG guarded und gezaehlt: was nicht
--      geschrieben werden konnte, steht in S.sprachOffen.
--   3. Was gar nicht geht, sagt Lyra im Chat - siehe unten. Eine Kategorie laesst sich nicht
--      neu registrieren; der Eintrag "Lyra Companion" in der Addon-Liste links ist allerdings
--      in beiden Sprachen derselbe (W8: Anzeigename, siehe Locales/enUS.lua), und
--      "Feineinstellung" wird ueber .name mitgenommen.
-- =============================================================================================
local function datenVon(init)
    if type(init) ~= "table" then return nil end
    if type(init.data) == "table" then return init.data end
    if init.GetData then
        local ok, d = pcall(init.GetData, init)
        if ok and type(d) == "table" then return d end
    end
    return nil
end

-- Ein Feld setzen. Rueckgabe true, wenn der Wert danach wirklich drinsteht.
local function setzeFeld(tab, feld, wert)
    if type(tab) ~= "table" or wert == nil then return false end
    local ok = pcall(function() tab[feld] = wert end)
    return (ok and tab[feld] == wert) and true or false
end

-- Die sichtbare Liste einmal neu zeichnen, damit die geaenderten Daten ankommen.
function S.panelNeuZeichnen()
    if not (SettingsPanel and S.category) then return false end
    local ok = pcall(function()
        local aktuell = SettingsPanel.GetCurrentCategory and SettingsPanel:GetCurrentCategory()
        if aktuell ~= S.category and aktuell ~= S.subcategory then return end
        if SettingsPanel.DisplayCategory then SettingsPanel:DisplayCategory(aktuell) end
    end)
    return ok and true or false
end

-- Alle Beschriftungen neu setzen. Rueckgabe: geschrieben, offen (Anzahl).
function S.sprachNeu()
    local geschrieben, offen = 0, 0
    S.sprachOffen = {}
    for _, e in ipairs(S.i18n or {}) do
        local k = e.keys or {}
        if e.art == "setting" then
            if k[1] then
                if setzeFeld(e.obj, "name", ns.L[k[1]]) then geschrieben = geschrieben + 1
                else offen = offen + 1; S.sprachOffen[#S.sprachOffen + 1] = tostring(k[1]) end
            end
        else
            local d = datenVon(e.obj)
            if not d then
                if k[1] or k[2] then offen = offen + 1; S.sprachOffen[#S.sprachOffen + 1] = tostring(k[1] or k[2]) end
            else
                if k[1] and setzeFeld(d, "name", ns.L[k[1]]) then geschrieben = geschrieben + 1 end
                if k[2] and setzeFeld(d, "tooltip", ns.L[k[2]]) then geschrieben = geschrieben + 1 end
                if k[3] and setzeFeld(d, "buttonText", ns.L[k[3]]) then geschrieben = geschrieben + 1 end
            end
        end
    end
    -- B-5: die Unterkategorie traegt ihren Namen selbst.
    if S.subcategory then setzeFeld(S.subcategory, "name", ns.L["Fine tuning"]) end
    S.panelNeuZeichnen()
    S.sprachGebaut = ns.sprache()
    return geschrieben, offen
end

-- Der Weg, den /lyra sprache und der Dropdown gemeinsam gehen. Ausser der Einstellungsseite
-- haengen daran das Menue (baut seine Eintraege beim Oeffnen, muss also nur neu geoeffnet
-- werden, wenn es gerade offen steht) und das Chronik-Fenster (dasselbe).
function S.sprachAnwenden()
    local geschrieben, offen = 0, 0
    if S.category then
        local ok, g, o = pcall(S.sprachNeu)
        if ok then geschrieben, offen = g or 0, o or 0 else offen = -1 end
    end
    -- Menue: eintraege() liest ns.L beim Oeffnen. Steht es offen, einmal neu aufbauen.
    if ns.Menue and ns.Menue.offen and ns.Menue.offen() then
        pcall(ns.Menue.schliesse); pcall(ns.Menue.oeffne)
    end
    -- Gespraech: zeigeKnoten() holt den Text ueber txt() -> sprache(). Offenen Knoten neu zeigen.
    if ns.Dialog and ns.Dialog.offen and ns.Dialog.offen() then
        local k = ns.Dialog.aktuell
        if k and k.id then pcall(ns.Dialog.zeigeKnoten, k.id, ns.Dialog.aktuellVars) end
    end
    -- Chronik-Fenster: baut seine Beschriftung beim Fuellen.
    if ns.Dialog and ns.Dialog.chronikOffen and ns.Dialog.chronikOffen() then
        pcall(ns.Dialog.chronikFenster)
    end
    -- Blase und Leiste tragen keinen festen Text, aber ihre Masse haengen an der Schrift.
    if ns.Blase and ns.Blase.layout then pcall(ns.Blase.layout) end
    -- Ehrlich melden. "Sprache: en" allein war der Befund - es sagt nicht, WAS jetzt umgestellt
    -- ist und was nicht. Drei Faelle, drei Saetze.
    local sp = tostring(ns.sprache())
    if not S.category then
        ns.print(ns.L["Language switched simple"]:format(sp))
    elseif offen == 0 then
        ns.print(ns.L["Language switched"]:format(sp))
    else
        local liste = table.concat(S.sprachOffen or {}, ", ")
        if liste == "" then liste = "?" end
        if #liste > 120 then liste = liste:sub(1, 117) .. "..." end
        ns.print(ns.L["Language partial"]:format(sp, liste))
    end
    return geschrieben, offen
end

-- Nach einem Update koennen die Einzelschalter laengst nicht mehr zum gespeicherten Preset-Namen
-- passen (0.2.x kannte gar keine Presets). Dann zeigt der Dropdown ehrlich "Eigene Einstellung",
-- statt eine Voreinstellung zu behaupten, die nicht gilt. ns.Set statt S.setze: nichts anwenden.
function S.presetPruefen()
    local w = S.PRESET_WERTE[ns.Get("preset")]
    if not w then return end
    for k, v in pairs(w) do
        if ns.Get(k) ~= v then ns.Set("preset", "eigen"); return end
    end
end

function S.start()
    if S.gestartet then return end
    S.gestartet = true
    S.presetPruefen()
    S.bewegungAnwenden(ns.Get("bewegung"))   -- B-13: der gespeicherte Wert gilt ab dem Login
    if Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting
        and Settings.RegisterAddOnCategory and CreateSettingsListSectionHeaderInitializer then
        local ok, err = pcall(baueNativ)
        if not ok then
            S.category = nil
            S.registriert = {}
            ns.debug("Settings: " .. tostring(err))
        end
    elseif InterfaceOptions_AddCategory then
        local ok, err = pcall(baueLegacy)
        if not ok then S.legacyPanel = nil; ns.debug("Settings (legacy): " .. tostring(err)) end
    end
end

function ns.oeffneSettings()
    if S.category and Settings and Settings.OpenToCategory then
        local id = (S.category.GetID and S.category:GetID()) or S.category.ID
        if id then
            local ok = pcall(Settings.OpenToCategory, id)
            if ok then return true end
        end
    end
    if S.legacyPanel and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(S.legacyPanel)
        InterfaceOptionsFrame_OpenToCategory(S.legacyPanel)   -- alter Blizzard-Bug: erst der 2. Aufruf scrollt hin
        return true
    end
    for line in ns.L["Help text"]:gmatch("[^\n]+") do ns.print(line) end
    return false
end
