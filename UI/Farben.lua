-- UI/Farben.lua — Benannte Farbpaletten (Welle 10b, Roadmap 10-7).
--
-- VIER Paletten: standard | kontrast | warm | kalt. Sie faerben GENAU DREI Flaechen:
--   1. den Warnstufen-Puls am Bildschirmrand (UI/Glow.lua)
--   2. Grund, Text und Rand der Sprechblase (Gestalt/Blase.lua)
--   3. Balken und Text der Untertitel-Leiste (UI/Streamer.lua, ueber deren oeffentliche Felder)
-- Alles andere - Menue, Gespraechsfenster, Tooltip, Gestalt-Ring - bleibt unberuehrt. Eine
-- Palette ist ein Anstrich, kein zweites Design.
--
-- ---------------------------------------------------------------------------------------------
-- DIE REGEL, DIE UEBER ALLEM STEHT: BARRIEREFREIHEIT WIRD NICHT VERHANDELT
-- ---------------------------------------------------------------------------------------------
-- Das Haekchen "Hoher Kontrast" (ns.Get("kontrast")) GEWINNT gegen jede Palettenwahl. Wer es
-- setzt, bekommt Schwarz/Weiss - egal was in "farbe" steht. Sonst waere eine neue Einstellung
-- ein Weg, eine Barrierefreiheits-Zusage still abzuschalten, und genau das darf ein Farbthema
-- nicht koennen. Umgekehrt ist F.PALETTEN.kontrast Wert fuer Wert dieselbe Tabelle, die
-- UI/Optik.lua heute unter O.FARBEN.kontrast fuehrt - wer die Palette waehlt, sieht dasselbe
-- Bild wie mit dem Haekchen (ohne den Schrift-Umriss; der haengt weiter am Haekchen).
-- tests/pruefstand/w10b_harness.lua rechnet die Kontrastwerte JEDER Palette nach und laesst
-- keine unter 4,5:1 durch (WCAG 2.2 AA fuer Text). Gemessene Werte stehen unten je Palette.
--
-- ---------------------------------------------------------------------------------------------
-- WAS DIE PALETTE AM PULS NICHT AENDERT
-- ---------------------------------------------------------------------------------------------
-- Spitze, Dauer, Riegel und der Deckel W.SPITZE_MAX bleiben, wo Welle 7 sie hingelegt hat. Sie
-- sind KEINE Geschmacksfrage, sondern die Photosensibilitaets-Grenze aus Recherche 02 §2.3.
-- Eine Palette darf die FARBE wechseln, nie die Helligkeit und nie den Takt.
-- Zweite Zusage aus Welle 7, die hier zur pruefbaren Regel wird: Lyras Alarm ist NIE Blizzards
-- Rot (#FF0000). Der Client zeichnet dort seine eigene LowHealth-Vignette; wer beides in
-- derselben Farbe sieht, kann "das Spiel warnt" und "Lyra warnt" nicht mehr trennen.
--
-- ---------------------------------------------------------------------------------------------
-- WARUM DIE PULS-SLOTS lila/blau/rotlila HEISSEN
-- ---------------------------------------------------------------------------------------------
-- UI/Glow.lua kennt seit Welle 7 drei Farbnamen (W.FARBEN.lila, .blau, .rotlila), und
-- W.STUFEN verweist darauf. Diese Namen sind inzwischen SLOTS, keine Farben: "lila" heisst
-- "Stufe 1 und 2", "rotlila" heisst "Stufe 3", "blau" heisst "Atem/Wasser". Die Palette
-- benennt sie fachlich (warnung/alarm/atem) und F.PULS_SLOT uebersetzt. So bleibt die
-- Aenderung in UI/Glow.lua EINE Zeile, und kein Aufrufer muss umgeschrieben werden.
--
-- API: keine. Diese Datei rechnet nur und liest ns.Get. Sie faerbt die Untertitel-Leiste ueber
-- ns.Streamer.leiste/.text - oeffentliche Felder, die UI/Streamer.lua selbst setzt; die Datei
-- dort bleibt unangetastet.
local ADDON, ns = ...
local F = {}
ns.Farben = F

-- ---------------------------------------------------------------------------------------------
-- Die vier Paletten
--
-- Aufbau je Palette:
--   puls   = { warnung, alarm, atem }         -- {r,g,b}, Vertexfarbe der acht Puls-Zonen
--   blase  = { panel, text, rand }            -- panel/rand mit Alpha, text ohne
--   leiste = { balken, text }                 -- balken mit Alpha (Untertitel-Leiste)
--
-- Gemessene Kontraste (sRGB, WCAG 2.2; nachgerechnet in w10b_harness.lua, Szene 3):
--   Palette    Text/Grund   Leiste ueber hellstem Spielbild   Rand/Grund
--   standard     16,81:1              15,08:1                  19,23:1
--   kontrast     21,00:1              15,08:1                  21,00:1
--   warm         16,95:1              11,83:1                  12,12:1
--   kalt         17,03:1              11,89:1                  11,96:1
-- Die Leisten-Zahl ist der SCHLECHTESTE Fall: schwarzer Balken mit seinem Alpha ueber einem
-- reinweissen Spielbild (Schnee, Feuer) - dieselbe Rechnung wie in docs/fix3-2026-09-17.md.
-- ---------------------------------------------------------------------------------------------
F.PALETTEN = {
    -- Unveraendert der heutige Stand: Glow W.FARBEN, Blase B.FARBE_*, Streamer-Leiste.
    standard = {
        puls   = { warnung = { 0.706, 0.549, 1.000 },   -- #B48CFF Lyras Violett
                   alarm   = { 1.000, 0.357, 0.706 },   -- #FF5AB4 rot-violett, nicht Blizzards Rot
                   atem    = { 0.451, 0.702, 1.000 } }, -- #73B3FF Atem/Wasser
        blase  = { panel = { 0.07, 0.04, 0.13, 1.00 },  -- #120A21 deckend
                   text  = { 0.95, 0.93, 1.00 },        -- #F2EDFF
                   rand  = { 1.00, 1.00, 1.00, 1.00 } },
        leiste = { balken = { 0, 0, 0, 0.85 }, text = { 1, 1, 1 } },
    },
    -- Wert fuer Wert die heutige Kontrast-Einstellung (UI/Optik.lua O.FARBEN.kontrast,
    -- Gestalt/Blase.lua "if ns.Get('kontrast') then c = {1,1,1} end"). Der Puls ist dort heute
    -- NICHT eingefaerbt - er bleibt es auch hier, aus dem Photosensibilitaets-Grund oben.
    -- Die Leiste ist heute schon schwarz/weiss; ihr Alpha bleibt bei 0,85, weil eine Aenderung
    -- hier eine Aenderung waere und nicht eine Uebernahme.
    kontrast = {
        puls   = { warnung = { 0.706, 0.549, 1.000 },
                   alarm   = { 1.000, 0.357, 0.706 },
                   atem    = { 0.451, 0.702, 1.000 } },
        blase  = { panel = { 0, 0, 0, 1 }, text = { 1, 1, 1 }, rand = { 1, 1, 1, 1 } },
        leiste = { balken = { 0, 0, 0, 0.85 }, text = { 1, 1, 1 } },
    },
    -- Warm: Bernstein und Rose auf tiefem Braun.
    warm = {
        puls   = { warnung = { 1.000, 0.604, 0.235 },   -- #FF9A3C
                   alarm   = { 1.000, 0.353, 0.478 },   -- #FF5A7A warme Rose, Abstand zu #FF0000: 0,59
                   atem    = { 0.498, 0.851, 0.784 } }, -- #7FD9C8 - Atem bleibt in JEDER Palette kuehl,
                                                        -- weil die Farbe hier "Wasser/Luft" bedeutet
        blase  = { panel = { 0.102, 0.059, 0.027, 1.00 },  -- #1A0F07
                   text  = { 1.000, 0.945, 0.878 },        -- #FFF1E0
                   rand  = { 1.000, 0.769, 0.537, 1.00 } },-- #FFC489
        leiste = { balken = { 0.078, 0.039, 0.016, 0.85 }, text = { 1.000, 0.945, 0.878 } },
    },
    -- Kalt: Eisblau auf Nachtblau. Der Alarm bleibt das Rot-Violett der Standardpalette -
    -- Stufe 3 soll ueber alle Paletten hinweg dieselbe Farbe haben (Wiedererkennung im Ernstfall).
    kalt = {
        puls   = { warnung = { 0.239, 0.608, 1.000 },   -- #3D9BFF
                   alarm   = { 1.000, 0.357, 0.706 },   -- #FF5AB4 wie standard
                   atem    = { 0.373, 0.878, 0.847 } }, -- #5FE0D8
        blase  = { panel = { 0.024, 0.067, 0.110, 1.00 },  -- #06111C
                   text  = { 0.910, 0.957, 1.000 },        -- #E8F4FF
                   rand  = { 0.561, 0.839, 1.000, 1.00 } },-- #8FD6FF
        leiste = { balken = { 0.016, 0.047, 0.078, 0.85 }, text = { 0.910, 0.957, 1.000 } },
    },
}

F.REIHE = { "standard", "kontrast", "warm", "kalt" }
F.VORGABE = "standard"

-- Namen, die der Spieler tippen darf. Deutsch und Englisch, kleingeschrieben.
F.ALIAS = {
    standard = "standard", normal = "standard", default = "standard", lila = "standard",
    kontrast = "kontrast", contrast = "kontrast", sw = "kontrast", bw = "kontrast",
    warm = "warm", amber = "warm", bernstein = "warm",
    kalt = "kalt", cold = "kalt", cool = "kalt", blau = "kalt", eis = "kalt", ice = "kalt",
}

-- Der Schluessel haengt sich an die Vorgaben AN - Core/Init.lua bleibt unberuehrt (dasselbe
-- Muster wie Sinne/Welle4.lua, Sinne/Karte2.lua und Sinne/Welle8.lua).
ns.DEFAULTS_ACCOUNT = ns.DEFAULTS_ACCOUNT or {}
ns.DEFAULTS_ACCOUNT.farbe = F.VORGABE

-- ---------------------------------------------------------------------------------------------
-- Auswahl
-- ---------------------------------------------------------------------------------------------
-- Der gespeicherte Name, auf eine gueltige Palette gezogen. Kennt niemand den Wert (alte
-- Datenbank, vertippter Import), gilt die Vorgabe - nie ein Fehler, nie eine leere Blase.
function F.gewaehlt()
    local w = ns.Get("farbe")
    if type(w) == "string" and F.PALETTEN[w] then return w end
    return F.VORGABE
end

-- Der Name der Palette, die WIRKLICH gilt. Hier gewinnt das Kontrast-Haekchen.
function F.name()
    if ns.Get("kontrast") then return "kontrast" end
    return F.gewaehlt()
end

function F.aktiv() return F.PALETTEN[F.name()] or F.PALETTEN[F.VORGABE] end

-- UI/Glow.lua fragt mit seinem Slot-Namen. F.PULS_SLOT uebersetzt ihn in das fachliche Feld.
F.PULS_SLOT = { lila = "warnung", rotlila = "alarm", blau = "atem" }
function F.puls(slot)
    local p = F.aktiv().puls
    local feld = F.PULS_SLOT[slot]
    return (feld and p[feld]) or p.warnung
end

-- Gestalt/Blase.lua fragt mit "panel" | "text" | "rand".
function F.blase(feld)
    local b = F.aktiv().blase
    return b[feld]
end

function F.leiste() return F.aktiv().leiste end

-- ---------------------------------------------------------------------------------------------
-- Setzen
-- ---------------------------------------------------------------------------------------------
-- Rueckgabe: name | nil. nil heisst "so heisst keine Palette" - der Aufrufer sagt es dem
-- Spieler, geaendert wird nichts.
function F.setze(eingabe)
    if type(eingabe) ~= "string" then return nil end
    local key = F.ALIAS[eingabe:lower()]
    if not key then return nil end
    if ns.Settings and ns.Settings.setze then ns.Settings.setze("farbe", key)
    else ns.Set("farbe", key) end
    return key
end

-- ---------------------------------------------------------------------------------------------
-- Anwenden
-- ---------------------------------------------------------------------------------------------
-- Blase und Puls holen ihre Farbe bei jedem Zeichnen neu - dort ist nichts nachzuziehen (die
-- naechste Zeile kommt im neuen Anstrich; eine STEHENDE Blase bleibt, wie sie ist, und das ist
-- gewollt: eine Zeile, die sich unter dem Lesen umfaerbt, ist unruhiger als eine, die ausklingt).
-- Die Untertitel-Leiste dagegen ist EIN Frame mit EINER Textur, die UI/Streamer.lua beim Laden
-- einmal einfaerbt. Sie wird hier nachgezogen - ueber die oeffentlichen Felder St.leiste/St.text,
-- ohne eine Zeile in UI/Streamer.lua zu aendern.
-- Der Balken wird EINMAL gesucht und hier gemerkt. Nicht am Frame: ein Frame beantwortet jedes
-- unbekannte Feld mit etwas, und "nicht gefunden" waere dann nicht von "noch nicht gesucht" zu
-- unterscheiden. false heisst "gesucht und nichts gefunden", nil heisst "noch nicht gesucht".
local balkenTextur = nil
function F.anwenden()
    local St = ns.Streamer
    if not (St and St.leiste and St.text) then return false end
    local l = F.leiste()
    if balkenTextur == nil then
        balkenTextur = false
        if St.leiste.GetRegions then
            local ok, a, b2 = pcall(St.leiste.GetRegions, St.leiste)
            if ok then
                for _, r in ipairs({ a, b2 }) do
                    -- Die erste Region, die eine Farbflaeche sein KANN. Die FontString daneben
                    -- hat SetTextColor, aber kein SetColorTexture - das ist der Unterscheider.
                    if type(r) == "table" and balkenTextur == false then
                        local okm, m = pcall(function() return r.SetColorTexture end)
                        if okm and type(m) == "function" then balkenTextur = r end
                    end
                end
            end
        end
    end
    if balkenTextur then
        pcall(balkenTextur.SetColorTexture, balkenTextur,
              l.balken[1], l.balken[2], l.balken[3], l.balken[4])
    end
    pcall(St.text.SetTextColor, St.text, l.text[1], l.text[2], l.text[3])
    return true
end

-- ---------------------------------------------------------------------------------------------
-- Rechnung (WCAG 2.2). Steht hier und nicht im Pruefstand, damit der Nachweis mit DENSELBEN
-- Zahlen rechnet, die das Addon benutzt - eine Kopie im Drehbuch wuerde sich selbst pruefen.
-- Im Spiel ruft sie niemand; sie kostet nichts und ist der Beleg fuer /lyra debug.
-- ---------------------------------------------------------------------------------------------
local function kanal(c)
    if c <= 0.04045 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
end

function F.leuchtdichte(rgb)
    return 0.2126 * kanal(rgb[1]) + 0.7152 * kanal(rgb[2]) + 0.0722 * kanal(rgb[3])
end

function F.kontrastwert(a, b)
    local la, lb = F.leuchtdichte(a), F.leuchtdichte(b)
    if la < lb then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end

-- Eine halbdeckende Flaeche ueber einem Hintergrund. Fuer die Untertitel-Leiste ueber dem
-- hellsten denkbaren Spielbild (Weiss) - der Fall, an dem FIX3 den Balken auf 0,85 gezogen hat.
function F.ueber(vorn, alpha, hinten)
    return { vorn[1] * alpha + hinten[1] * (1 - alpha),
             vorn[2] * alpha + hinten[2] * (1 - alpha),
             vorn[3] * alpha + hinten[3] * (1 - alpha) }
end

-- ---------------------------------------------------------------------------------------------
-- Hilfe-Zeilen. Wie ns.Bruecken.hilfe und ns.Karte2.hilfe: die Befehlsliste lebt im Modul,
-- damit die Locales frei von Listen bleiben, die sich mit jeder Welle aendern.
-- ---------------------------------------------------------------------------------------------
function F.hilfe()
    local wort = (ns.L and ns.L["Colour theme"]) or "colour theme"
    return { "/lyra farbe " .. table.concat(F.REIHE, "|") .. " - " .. wort }
end

-- Palettenwechsel: Leiste nachziehen. Der Mantel ruft das Original ZUERST und gibt nichts
-- zurueck - er kann damit keinem anderen Mantel etwas wegnehmen (dieselbe Bauart wie der
-- Mantel in Sinne/Welle9.lua).
local origSetting = ns.onSetting
ns.onSetting = function(key, value, ...)
    if origSetting then origSetting(key, value, ...) end
    if key == "farbe" or key == "kontrast" then pcall(F.anwenden) end
end

if ns.on then
    ns.on("PLAYER_LOGIN", function() pcall(F.anwenden) end)
end
