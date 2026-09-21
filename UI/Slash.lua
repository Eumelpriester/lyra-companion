-- UI/Slash.lua — /lyra und /lyragestalt. Alle Werte gehen ueber ns.Settings.setze (Panel bleibt synchron).
-- Ausgabe nur lokal ueber ns.print. Unbekannter Rest geht als Freitext an ns.Dialog.frage (lokaler
-- Intent-Parser, nie SendChatMessage). Ausserdem ns.klick (Linksklick auf die Gestalt).
-- API: SLASH_*/SlashCmdList, GetTime. Nichts Fremdes.
local ADDON, ns = ...

local function L(k) return ns.L[k] end
local function setze(key, value)
    if ns.Settings and ns.Settings.setze then ns.Settings.setze(key, value) else ns.Set(key, value) end
end
local function anAus(b) return b and L("yes") or L("no") end
local function zeigeWert(key) ns.print(key .. ": " .. tostring(ns.Get(key))) end
local function toggle(key) setze(key, not ns.Get(key)); zeigeWert(key) end
local function hilfe()
    for line in L("Help text"):gmatch("[^\n]+") do ns.print(line) end
    for line in L("Help text 2"):gmatch("[^\n]+") do ns.print(line) end
    for line in L("Help text 3"):gmatch("[^\n]+") do ns.print(line) end
    -- Bruecken-Zeilen liegen im Modul (Locales bleiben unangetastet)
    if ns.Bruecken and ns.Bruecken.hilfe then
        local ok, zeilen = pcall(ns.Bruecken.hilfe)
        if ok and type(zeilen) == "table" then for _, z in ipairs(zeilen) do ns.print(z) end end
    end
    -- W5: die drei Kartenzeilen liegen im Modul, wie die Bruecken-Zeilen. Die Locales bleiben
    -- damit frei von Befehlslisten, die sich mit jeder Welle aendern.
    if ns.Karte2 and ns.Karte2.hilfe then
        local ok, zeilen = pcall(ns.Karte2.hilfe)
        if ok and type(zeilen) == "table" then for _, z in ipairs(zeilen) do ns.print(z) end end
    end
    -- W10B: dieselbe Bauart, damit /lyra farbe nicht nur im Changelog steht.
    if ns.Farben and ns.Farben.hilfe then
        local ok, zeilen = pcall(ns.Farben.hilfe)
        if ok and type(zeilen) == "table" then for _, z in ipairs(zeilen) do ns.print(z) end end
    end
    -- W11B: die vier neuen Befehle. Eigener Locale-Schluessel statt einer Aenderung an
    -- "Help text 3" - die Locales werden in dieser Runde nur ERGAENZT, nie umgeschrieben.
    for line in L("Help text w11b"):gmatch("[^\n]+") do ns.print(line) end
    -- W10a: der Offenlegungssatz, als LETZTE Zeile der Hilfe (Freitext-Konzept §2.8).
    ns.print(L("Disclosure"))
end
ns.hilfe = hilfe
local function oeffnen() if ns.oeffneSettings then ns.oeffneSettings() else hilfe() end end

local SPRACHEN = { de = "de", deutsch = "de", german = "de", en = "en", englisch = "en", english = "en", auto = "auto" }
local ANREDEN = {
    m = "m", male = "m", mann = "m", maennlich = "m", ["männlich"] = "m",
    w = "f", f = "f", female = "f", frau = "f", weiblich = "f",
    keine = "keine", none = "keine", no = "keine", neutral = "keine",
    auto = "auto",
}
local PRESETS = { still = "still", silent = "still", wenig = "wenig", little = "wenig", normal = "normal", viel = "viel", chatty = "viel" }

local function status()
    local R = ns.Regie or {}
    local sp = ns.Get("sprache")
    local eff = ns.sprache()
    local geladen = ns.Stimme and ns.Stimme.geladen[eff]
    ns.print(L("Status") .. " - " .. L("Version") .. " " .. ns.VERSION)
    -- W8 (A9): der Selbsttest steht GANZ OBEN. Wenn eine API-Flaeche weg ist, ist das die
    -- wichtigste Zeile der ganzen Uebersicht - alles darunter erklaert sich dann von selbst.
    -- Er steht auch im gruenen Fall da: "alle Flaechen in Ordnung" ist in einem Bugreport
    -- genauso viel wert wie die Liste der Ausfaelle.
    if ns.Selbsttest and ns.Selbsttest.status then
        local ok, zeilen = pcall(ns.Selbsttest.status)
        if ok and type(zeilen) == "table" then for _, z in ipairs(zeilen) do ns.print(z) end end
    end
    ns.print(L("Language") .. ": " .. tostring(sp) .. (sp == "auto" and (" (" .. eff .. ")") or ""))
    ns.print(L("Address") .. ": " .. tostring(ns.Get("anrede")) .. " (" .. tostring(ns.geschlecht and ns.geschlecht() or "?") .. ")")
    ns.print(L("Talkativeness") .. ": " .. tostring(ns.Get("gespraechig")))
    ns.print(L("Voice enabled") .. ": " .. anAus(ns.Get("stimme")) .. " - " .. L("Voice pack") .. " " .. eff .. ": "
        .. (geladen == nil and L("not loaded") or anAus(geladen)))
    ns.print(L("Combat") .. ": " .. anAus(R.imKampf) .. " - " .. L("Group") .. ": " .. anAus(R.inGruppe))
    -- W11B: Lautstaerke und die Zahl der stummgeschalteten Ereignisse. Beides sind Einstellungen,
    -- die ein Nutzer im Bugreport vergisst zu erwaehnen ("sie sagt nichts mehr").
    if ns.Stimme and ns.Stimme.lautstaerke then
        ns.print((L("Volume is")):format(ns.Stimme.lautstaerke()))
    end
    if R.stummListe then
        local n = 0
        for _ in pairs(R.stummListe()) do n = n + 1 end
        if n > 0 then ns.print((L("Muted count")):format(n)) end
    end
    local z = R.dropZaehler or { normal = 0, verlust = 0 }
    ns.print(("  " .. L("Why counters")):format(z.verlust or 0, z.normal or 0))
    -- Bruecken-Welle 1: erkannte Partner-Addons (Modul darf fehlen)
    if ns.Bruecken and ns.Bruecken.status then
        local ok, zeilen = pcall(ns.Bruecken.status)
        if ok and type(zeilen) == "table" then
            for _, z in ipairs(zeilen) do ns.print(z) end
        end
    end
    -- REVIEW6B: Bruecken-Welle 2 (WeakAuras/Pawn/Details). B2.status() war gebaut, aber nirgends gerufen.
    if ns.Bruecken2 and ns.Bruecken2.status then
        local ok, zeilen = pcall(ns.Bruecken2.status)
        if ok and type(zeilen) == "table" then
            for _, z in ipairs(zeilen) do ns.print(z) end
        end
    end
    -- REVIEW9: Gefahrenkarte. Sie haengt in ns.Sinne (nicht in ns) und faellt deshalb durch die
    -- Modul-Schleife unten durch — darum die eigene Zeile. Sie sagt jetzt auch, WARUM nichts
    -- kommt: auf Retail/FOREVER schaltet C.F.gefahrenkarte sie ab (Era-Daten).
    if ns.Sinne and ns.Sinne.GefahrenDaten and ns.Sinne.GefahrenDaten.status then
        local ok, zeilen = pcall(ns.Sinne.GefahrenDaten.status)
        if ok and type(zeilen) == "table" then
            for _, z in ipairs(zeilen) do ns.print(z) end
        end
    end
    -- Welle 3: Bedrohung, Questie-Tiefe, Person. Details und Bosse haben eigene Befehle
    -- (/lyra details, /lyra bosse) und stehen hier absichtlich nicht auch noch.
    -- W4: Welle 4 haengt sich in dieselbe Schleife (Beruf-API, Erste Hilfe, WeakAuras, GatherMate2).
    -- W5: Karte2 haengt in derselben Schleife (Pins je Kategorie, Zellen der Zone, HBD da?).
    -- W6: Welle 6 haengt in derselben Schleife und steht ZULETZT - ihre Zeilen (Speicher,
    -- Rechenzeit, Client-Weiche, Spielregeln) sind die Antwort auf "was kostet mich das",
    -- und die gehoert ans Ende einer Uebersicht, nicht zwischen zwei Sinne.
    -- W8: Welle8 (die praeventive Warnung) haengt in derselben Schleife und steht hinter Karte2,
    -- weil sie deren HereBeDragons-Anbindung und die Gefahrenkarte liest - erst die Quelle,
    -- dann die Auswertung. Welle6 bleibt Letzte (Speicher, Rechenzeit, Client-Weiche).
    -- W9: Welle9 (Leiste, Profil-Export, Questie-Meldeweg, Aussprache) steht hinter Welle8 und
    -- vor Welle6 - Welle6 bleibt die Letzte (Speicher, Rechenzeit, Client-Weiche).
    -- MERGE 0.16.0 (21.09.2026): die vier Module der Welle 13 "Andockstellen" haengen hinter
    -- Welle9 und in der Ladereihenfolge der TOC (13a, 13b, 13c, 13d). Welle6 bleibt die Letzte
    -- (Speicher, Rechenzeit, Client-Weiche). Alle vier haben ein eigenes status(), und alle
    -- vier sagen dort "fehlt" mit Namen, wenn ihre Quelle nicht da ist - das ist der halbe
    -- Zweck dieses Befehls.
    for _, mod in ipairs({ "Bedrohung", "Questie2", "Persoenlichkeit", "Welle4", "Karte2", "Welle8", "Welle9",
                           "Welle13a", "Welle13b", "Welle13c", "Welle13d", "Welle6" }) do
        local m = ns[mod]
        if m and m.status then
            local ok, zeilen = pcall(m.status)
            if ok and type(zeilen) == "table" then
                for _, z in ipairs(zeilen) do ns.print(z) end
            end
        end
    end
end

local function debug()
    setze("debug", not ns.Get("debug"))
    ns.print(ns.Get("debug") and L("Debug on") or L("Debug off"))
    local log = ns.Regie and ns.Regie.dropLog or {}
    ns.print(L("Drop log"))
    -- W11B (Abgleich §4.4): NORMALBETRIEB und VERLUST getrennt nennen. Von sechs gemeldeten
    -- "gescheiterten Aufrufen" waren bei ClaudeBuddy fuenf Normalbetrieb - das Blatt war formal
    -- korrekt und inhaltlich durchweg Fehlalarm. Hier steht die Einordnung jetzt an jeder Zeile.
    local z = (ns.Regie and ns.Regie.dropZaehler) or { normal = 0, verlust = 0 }
    ns.print(("  " .. L("Why counters")):format(z.verlust or 0, z.normal or 0))
    if #log == 0 then ns.print("  " .. L("Drop log empty")); return end
    for i = 1, math.min(10, #log) do
        local d = log[i]
        ns.print(("  %s  %s  %s  [%s]"):format(tostring(d[3]), tostring(d[2]), tostring(d[1]),
            d.verlust and L("loss") or L("by design")))
    end
end

local CMDS = {}
local function cmd(fn, ...) for _, name in ipairs({ ... }) do CMDS[name] = fn end end

cmd(oeffnen, "", "optionen", "options", "settings", "config", "einstellungen")
cmd(hilfe, "hilfe", "help", "?")
cmd(status, "status")
cmd(debug, "debug")
-- Welle 2
local function zeilenAus(mod, fn) if ns[mod] and ns[mod][fn] then for _, z in ipairs(ns[mod][fn]()) do ns.print(z) end else ns.print("-") end end
cmd(function() zeilenAus("Faehigkeiten", "status") end, "cooldowns", "cd", "notfall")
cmd(function() zeilenAus("Quests", "status") end, "quests", "questlog")
-- W9 (P2-4): "/lyra profil" bleibt, was es war - der Spielstil aus Welle 2. NEU sind die beiden
-- Unterbefehle davor: "/lyra profil export" und "/lyra profil import <Zeichenkette>". Die Weiche
-- steht VOR zeilenAus, sonst zeigte "/lyra profil export" einfach den Spielstil - dieselbe Falle
-- wie bei "/lyra punkt weg" (W5) und "/lyra mark skull" (REVIEW6B). Ohne Sinne/Welle9.lua bleibt
-- genau das alte Verhalten.
cmd(function(rest, roh)
    if ns.Welle9 and ns.Welle9.profilBefehl then
        local ok, gemacht = pcall(ns.Welle9.profilBefehl, rest, roh)
        if ok and gemacht then return end
    end
    zeilenAus("Profil", "status")
end, "profil", "spielstil", "profile")
-- W9 (A8): /lyra aussprache - das Lexikon fuer die Vorlese-Stimme. Ohne Argument die Liste,
-- "<Wort> = <Sprechform>" legt einen eigenen Eintrag an, "weg <Wort>" nimmt ihn zurueck.
-- Der ROHE Rest geht mit: eine Sprechform behaelt ihre Gross- und Kleinschreibung.
cmd(function(_, roh)
    if ns.Aussprache and ns.Aussprache.befehl then ns.Aussprache.befehl(roh or "")
    else ns.print(L("unknown command")) end
end, "aussprache", "pronunciation", "sprich", "lexikon")
cmd(function() if ns.Faehigkeiten then ns.print(ns.Faehigkeiten.rat()) end end, "rat", "tipp", "advice")
cmd(function(a) if ns.Karte then local ok = ns.Karte.mark(ns.Karte.markAusText(a)); if not ok then ns.print(ns.L["No mark target"]) end end end, "mark", "zeichen")
-- W5: "/lyra karte" war bis 0.10.0 ein Neuzeichnen mit einer Zahl dahinter. Jetzt ist es die
-- Uebersicht (Pins je Kategorie, Zellen der Zone, welche Schalter stehen wie) und gleichzeitig
-- der Schalter: "/lyra karte overlay an|aus", ebenso beinahe / notizen / nah. Ohne Karte2
-- (sehr alter Stand, Datei fehlt) bleibt genau das alte Verhalten stehen.
cmd(function(rest)
    if ns.Karte2 and ns.Karte2.befehl then
        local ok, err = pcall(ns.Karte2.befehl, rest or "")
        if ok then return end
        ns.debug("Karte2 befehl: " .. tostring(err))
    end
    if ns.Karte then local n = ns.Karte.aktualisieren(); ns.print((ns.L["Map pins"]):format(n)) end
end, "karte", "pins")
-- Welle 3: /lyra details, /lyra bosse, /lyra woran.
-- Ohne Argument zeigen die ersten beiden den Stand, mit "an"/"aus" schalten sie ihren Schluessel.
-- Das ist absichtlich EIN Befehl fuer beides: wer "/lyra details" tippt, will sehen, was Lyra
-- aus Details gelesen hat - und findet den Schalter in derselben Zeile erklaert.
local AN_AUS = { an = true, on = true, ein = true, ja = true, yes = true,
                 aus = false, off = false, nein = false, no = false }
local function schalter(key, mod, a)
    local v = AN_AUS[a or ""]
    if v ~= nil then
        setze(key, v)
        zeigeWert(key)
        if not v then return end
    end
    local m = ns[mod]
    if not (m and m.status) then ns.print(L("unknown command")); return end
    local ok, zeilen = pcall(m.status)
    if not (ok and type(zeilen) == "table") then ns.print(L("unknown command")); return end
    for _, z in ipairs(zeilen) do ns.print(z) end
end
-- W8: /lyra vorwarnung [an|aus] - die praeventive Sturz- und Wasserwarnung. Derselbe Bau wie
-- /lyra details: ohne Argument der Stand, mit an/aus der Schalter.
cmd(function(a) schalter("vorwarnung", "Welle8", a) end, "vorwarnung", "voraus", "prewarn")
-- W9B: /lyra freitext [an|aus] - das Eingabefeld unter dem Gespraechsfenster (UI/Freitext.lua).
-- Kein schalter()-Aufruf: das Modul hat keine status()-Liste, und ein Schalter, der ohne
-- Argument nichts zu zeigen hat, soll wenigstens sagen, wie er steht.
cmd(function(a)
    local v = AN_AUS[a or ""]
    if v ~= nil then
        setze("freitext", v)
        if not v and ns.Freitext and ns.Freitext.verstecke then pcall(ns.Freitext.verstecke) end
    end
    ns.print(ns.Get("freitext") and L("Freetext on") or L("Freetext off"))
end, "freitext", "freetext", "schreiben", "ask")
-- W8: /lyra selbsttest - der lange Bericht fuer den Bugreport. Acht Zeilen, eine je API-Flaeche,
-- mit Grund. Das ist die Zeile, um die man beim Patch-Tag bittet, statt "mach mal einen
-- Screenshot vom Fehler" zu sagen.
cmd(function()
    if not (ns.Selbsttest and ns.Selbsttest.bericht) then ns.print(L("unknown command")); return end
    local ok, zeilen = pcall(ns.Selbsttest.bericht)
    if not (ok and type(zeilen) == "table") then ns.print(L("unknown command")); return end
    for _, z in ipairs(zeilen) do ns.print(z) end
end, "selbsttest", "selftest", "diagnose")
cmd(function(a) schalter("detailsKommentar", "DetailsSinn", a) end, "details", "dps", "schaden")
cmd(function(a) schalter("bossChronik", "BossBruecke", a) end, "bosse", "boss", "bosses")
cmd(function(a) schalter("questieTief", "Questie2", a) end, "questie", "questietief")
cmd(function()
    if ns.Questie2 and ns.Questie2.frage then ns.Questie2.frage() else ns.print(L("unknown command")) end
end, "woran", "doing", "aktuell")
-- W4: /lyra attunement [onyxia|mc|bwl|naxx]. Geht bewusst NICHT ueber die Regie - es ist eine
-- Antwort auf eine Frage, kein Ereignis. Ohne Argument nennt sie die Stichworte, die sie kennt.
cmd(function(a)
    if not (ns.Welle4 and ns.Welle4.attunement) then ns.print(L("unknown command")); return end
    local ok, zeilen = pcall(ns.Welle4.attunement, a)
    if not (ok and type(zeilen) == "table") then ns.print(L("unknown command")); return end
    for _, z in ipairs(zeilen) do ns.print(z) end
end, "attunement", "attune", "einstimmung", "zugang")
cmd(function(a)
    local an = not (a == "aus" or a == "off")
    if a == "" then an = not (ns.Get("animation") ~= false) end
    setze("animation", an)
    if ns.Gestalt and ns.Gestalt.animationen then ns.Gestalt.animationen(an) end
    ns.print("Animation: " .. (an and "an" or "aus"))
end, "animation", "anim")
-- /lyra drift        -> Diagnose (Anker, Bewegungszustand, Selbsttest Gesicht/Maske)
-- /lyra drift reset   -> harte Nullstellung der Bewegungsebene (FIX4)
cmd(function(a)
    local G = ns.Gestalt
    if not G then return end
    if (a == "reset" or a == "zuruecksetzen" or a == "zurücksetzen") and G.nullstellung then
        G.nullstellung()
        ns.print("Bewegungsebene auf Null gestellt.")
        return
    end
    if G.diagnose then for _, z in ipairs(G.diagnose()) do ns.print(z) end end
end, "drift", "diag")
-- DESIGN-V3 A-1 / P1-1: "/lyra maske" hat seit 0.6.2 keine WIRKUNG mehr. Es gibt keine Maske,
-- die der Befehl abschalten koennte - das Portrait ist eine vorgeschnittene runde PNG
-- (bilder/rund/<miene>.png). Bis dahin setzte er einen Schluessel, den niemand mehr liest, und
-- meldete "Portrait-Maske: aus (quadratischer Ausschnitt)" - eine Zusage, die das Addon nicht
-- mehr einloest. Der ALIAS bleibt (alte Hilfetexte, fix4-Pruefpunkt 2, Gewohnheit) und sagt
-- jetzt, was gilt, statt still ins Leere zu laufen.
cmd(function()
    ns.print("Die Portrait-Maske ist seit 0.6.2 entfallen - das Portrait ist eine fertige runde "
        .. "Textur (bilder/rund/<miene>.png). Kein Gesicht zu sehen? /lyra drift zeigt, "
        .. "welche Datei geladen ist.")
end, "maske", "mask")
cmd(function(a)
    local v = SPRACHEN[a]
    if v then setze("sprache", v) end
    zeigeWert("sprache")
end, "sprache", "lang", "language")
cmd(function(a)
    local v = ANREDEN[a]
    if v then setze("anrede", v) end
    zeigeWert("anrede")
end, "anrede", "address")
-- W11B-4: "/lyra stumm" bleibt, was es seit 0.2 ist - der Schalter fuer die STIMME. Mit einem
-- Argument bekommt es die zweite Bedeutung: "/lyra stumm BAGS" schaltet EIN EREIGNIS ab.
-- Dieselbe Weiche wie bei "/lyra punkt weg" (W5) und "/lyra figur aus" (W6): ohne Argument das
-- alte Verhalten, unveraendert. Gegenstueck ist "/lyra laut <ID>".
local function stummBefehl(an)
    return function(a, roh)
        local id = (roh ~= nil and roh ~= "" and roh or a) or ""
        id = tostring(id):match("^%s*(%S*)") or ""
        if id == "" then
            if an then toggle("stimme") else zeigeWert("stimme") end
            return
        end
        local R = ns.Regie
        if not (R and R.stumm) then ns.print(L("unknown command")); return end
        local ok, grund = R.stumm(id, an)
        id = id:upper()
        if ok then
            ns.print((an and L("Event muted") or L("Event unmuted")):format(id))
        elseif grund == "alarm" then
            ns.print((L("Event is alarm")):format(id))
        else
            ns.print((L("Event unknown")):format(id))
        end
    end
end
cmd(stummBefehl(true), "stumm", "mute")
cmd(stummBefehl(false), "laut", "unmute", "anschalten")
-- W11B-4: die Liste. Ohne sie weiss niemand, WAS er abschalten koennte - genau der Punkt aus
-- docs/review-bindung-2026-09-20.md P-7 ("im Fenster die zuletzt gesagten IDs anzeigen").
local function gehoertBefehl()
    local R = ns.Regie
    if not (R and R.zuletztGehoert) then ns.print(L("unknown command")); return end
    local liste = R.zuletztGehoert(12)
    ns.print(L("Recently heard"))
    if #liste == 0 then ns.print("  " .. L("Recently heard empty")); return end
    for _, g in ipairs(liste) do
        ns.print(("  %s  %s%s"):format(tostring(g.zeit), tostring(g.id),
            g.stumm and ("  (" .. L("muted") .. ")") or ""))
    end
    ns.print("  " .. L("Mute hint"))
end
-- UI/Settings.lua haengt seinen Knopf "Zuletzt gehoert" hier ein. Die Datei liegt in der TOC
-- VOR dieser - beim BAUEN der Seite steht der Verweis also noch nicht, beim KLICKEN schon.
ns.CMDS_gehoert = gehoertBefehl
cmd(gehoertBefehl, "gehoert", "gehört", "zuletzt", "heard")
-- W11B-4: "Warum sagst du nichts?" - die naheliegendste Frage an eine Begleiterin, die bewusst
-- viel schweigt, und bis 0.14.0 die einzige, die sie nicht beantworten konnte. Die Regie fuehrt
-- dafuer ein Ringpuffer-Protokoll (Core/Regie.lua, R.verworfen) - nur Ereignis-IDs, Gruende und
-- Uhrzeiten, kein Text und kein Name eines Fremden.
cmd(function()
    local R = ns.Regie
    if not (R and R.verworfen) then ns.print(L("unknown command")); return end
    local liste = R.verworfen(5)
    ns.print(L("Why silent"))
    if #liste == 0 then ns.print("  " .. L("Why nothing dropped")) end
    for _, v in ipairs(liste) do
        local grund = L("Why " .. tostring(v.grund))
        if grund == "Why " .. tostring(v.grund) then grund = tostring(v.grund) end
        ns.print(("  %s  %s  %s"):format(tostring(v.zeit), tostring(v.id), grund))
    end
    -- §4.4 (Abgleich): BEIDE Zahlen nennen. "Ein Filter, der sich selbst versteckt, waere der
    -- naechste leise Ausfall" - und die Haelfte aller Drops ist Normalbetrieb, kein Verlust.
    local z = R.dropZaehler or { normal = 0, verlust = 0 }
    ns.print(("  " .. L("Why counters")):format(z.verlust or 0, z.normal or 0))
end, "warum", "why", "wieso")
-- W11B-6: Lyras eigene Lautstaerke, 0-100 %. Relativ zum gewaehlten Tonkanal; Blizzards Regler
-- bleibt, wo er steht (Gestalt/Stimme.lua, Block W11B-6).
cmd(function(a)
    local S = ns.Stimme
    if not (S and S.lautstaerke) then ns.print(L("unknown command")); return end
    local v = tonumber(a)
    if v then
        if v > 0 and v <= 1.0 and a:find("%.") then v = v * 100 end   -- "0.5" als Prozent tolerieren
        if v < 0 or v > 100 then ns.print(L("Volume range")); return end
        setze("lautstaerke", math.floor(v + 0.5))
    end
    ns.print((L("Volume is")):format(S.lautstaerke()))
    if S.lautstaerke() < 100 then ns.print("  " .. L("Volume alarm note")) end
end, "lautstaerke", "lautstärke", "volume")
for name, preset in pairs(PRESETS) do
    cmd(function() setze("gespraechig", preset); zeigeWert("gespraechig") end, name)
end
cmd(function() toggle("gruppeSchweigen") end, "gruppe", "group")
cmd(function(a)
    local v = tonumber(a)
    if v and v > 1.5 and v <= 150 then v = v / 100 end   -- "80" als Prozent tolerieren
    if not v or v < 0.2 or v > 1.5 then ns.print(L("Size range")); zeigeWert("scale"); return end
    setze("scale", v)
    zeigeWert("scale")
end, "groesse", "größe", "size", "scale")
-- Design v2: Ansicht (Portrait/Ganze Figur) und Groessen-Presets. "scale" bleibt intern und ueber
-- /lyra groesse <zahl> erreichbar; die Presets schreiben es mit.
cmd(function() setze("ansicht", "portrait"); zeigeWert("ansicht") end, "portrait", "kopf", "head")
-- W6: "/lyra figur" bleibt, was es war (Ansicht auf Ganzfigur). NEU ist nur das Argument:
-- "/lyra figur aus" schaltet Lyra auf "nur Stimme und Untertitel" - sie bleibt vollwertig,
-- sie ist nur nicht mehr zu sehen. "/lyra figur an" holt sie zurueck. Ohne Sinne/Welle6.lua
-- faellt beides auf das alte Verhalten zurueck.
local FIGUR_ARG = { an = true, on = true, aus = true, off = true, keine = true, none = true,
                    ein = true, ja = true, nein = true, yes = true, no = true }
cmd(function(a)
    if FIGUR_ARG[a or ""] and ns.Welle6 and ns.Welle6.figurBefehl then
        ns.Welle6.figurBefehl(a); return
    end
    setze("ansicht", "figur"); zeigeWert("ansicht")
end, "figur", "figure", "ganz", "full")
-- W6: /lyra barrierefrei [an|aus] - der Buendel-Schalter. Ohne Argument wird umgeschaltet und
-- danach steht da, was jetzt gilt: ein Schalter, der fuenf Dinge setzt, muss sie auch nennen.
cmd(function(a)
    if ns.Welle6 and ns.Welle6.barrierefreiBefehl then
        ns.Welle6.barrierefreiBefehl(a)
    else
        ns.print(L("unknown command"))
    end
end, "barrierefrei", "accessibility", "a11y", "barrierefreiheit")
cmd(function() setze("ansicht", ns.Get("ansicht") == "figur" and "portrait" or "figur"); zeigeWert("ansicht") end, "ansicht", "view")
for name, wert in pairs({ klein = "klein", small = "klein", mittel = "mittel", medium = "mittel", gross = "gross", ["groß"] = "gross", large = "gross", big = "gross" }) do
    cmd(function() setze("groesse", wert); zeigeWert("groesse"); zeigeWert("scale") end, name)
end
local PRESET_NAMEN = { leise = "leise", quiet = "leise", normal = "normal", lebendig = "lebendig", lively = "lebendig", streamer = "streamer" }
cmd(function(a)
    local v = PRESET_NAMEN[a]
    if v then setze("preset", v) end
    zeigeWert("preset")
-- REVIEW6B: Alias "profil" hier entfernt. cmd() ueberschreibt, der spaetere Eintrag gewinnt -
-- "/lyra profil" landete deshalb beim Preset statt beim Spielstil-Profil aus Welle 2 (oben).
end, "preset", "voreinstellung")
cmd(function()
    if ns.starteAssistent then ns.starteAssistent() else ns.print(L("Dialog missing")) end
end, "einrichten", "setup", "assistent", "wizard")
cmd(function() toggle("gesperrt") end, "sperren", "lock")
cmd(function() setze("gesperrt", false); zeigeWert("gesperrt") end, "entsperren", "unlock")
cmd(function() setze("versteckt", true); zeigeWert("versteckt") end, "verstecken", "hide")
cmd(function() setze("versteckt", false); zeigeWert("versteckt") end, "zeigen", "show")
-- /lyra position reset      -> Default-Ort (design-v3 D1: links auf halber Hoehe)
-- /lyra position vorschlag  -> B-7: den ersten Platz nehmen, der nicht unter Questie-Tracker,
--                              Minimap, Chat oder Details liegt. Nur auf Zuruf.
cmd(function(a)
    if a == "reset" or a == "zuruecksetzen" or a == "zurücksetzen" then
        if ns.Settings and ns.Settings.positionReset then ns.Settings.positionReset()
        else ns.Set("pos", ns.POS_DEFAULT or { "LEFT", 24, 40 }) end
        ns.print(L("Position reset"))
    elseif a == "vorschlag" or a == "frei" or a == "suggest" then
        local p = ns.Settings and ns.Settings.positionVorschlag and ns.Settings.positionVorschlag()
        if p then ns.print((L("Position suggested")):format(tostring(p[1]), tonumber(p[2]) or 0, tonumber(p[3]) or 0))
        else ns.print(L("unknown command")) end
    else
        ns.print("/lyra position reset | vorschlag")
    end
end, "position", "pos")
-- B-13: Bewegung voll | reduziert | aus (Barrierefreiheit). Ohne Argument wird der Stand gezeigt.
local BEWEGUNGEN = {
    voll = "voll", full = "voll", an = "voll", on = "voll",
    reduziert = "reduziert", reduced = "reduziert", wenig = "reduziert", less = "reduziert",
    aus = "aus", off = "aus", keine = "aus", none = "aus",
}
cmd(function(a)
    local v = BEWEGUNGEN[a]
    if v then setze("bewegung", v) end
    zeigeWert("bewegung")
end, "bewegung", "motion", "animationen")
-- REVIEW7 / B-8: Untertitel-Leiste aus | auto | immer. Sie haengt nicht mehr am Streamer-Modus.
local LEISTEN = {
    aus = "aus", off = "aus", nie = "aus", never = "aus",
    auto = "auto", automatisch = "auto", automatic = "auto",
    immer = "immer", always = "immer", an = "immer", on = "immer",
}
cmd(function(a)
    local v = LEISTEN[a]
    if v then setze("leiste", v) end
    zeigeWert("leiste")
end, "leiste", "subtitles", "bar")
-- W10B (Roadmap 10-7): /lyra farbe standard|kontrast|warm|kalt. Ohne Argument steht da, was
-- gilt - und WARUM, falls das Kontrast-Haekchen die Wahl gerade uebersteuert. Ein Befehl, der
-- eine Einstellung anzeigt, die nicht wirkt, ist schlimmer als gar keiner.
cmd(function(a)
    local F = ns.Farben
    if not F then ns.print(L("unknown command")); return end
    if a and a ~= "" then
        local v = F.setze(a)
        if not v then
            ns.print(L("Colour theme unknown") .. ": " .. table.concat(F.REIHE, ", "))
            return
        end
    end
    ns.print(L("Colour theme") .. ": " .. F.gewaehlt())
    if F.name() ~= F.gewaehlt() then ns.print(L("Colour theme overridden")) end
end, "farbe", "farben", "palette", "color", "colour", "theme")
-- B-1: Schriftgroesse. "auto" folgt UIParent:GetEffectiveScale(), eine Zahl uebersteuert.
cmd(function(a)
    if a == "auto" then setze("schrift", "auto")
    else
        local v = tonumber(a)
        if v then setze("schrift", math.max(10, math.min(28, math.floor(v + 0.5)))) end
    end
    local O = ns.Optik
    ns.print("schrift: " .. tostring(ns.Get("schrift"))
        .. (O and O.schriftAuto and O.schriftAuto() and (" (" .. tostring(O.schriftgroesse()) .. ")") or ""))
end, "schrift", "font", "schriftgroesse", "schriftgröße")
-- /lyra test            -> Probe (Leerlauf-Zeile)
-- /lyra test <ID>       -> Ereignis mit Beispiel-Vars, Regie-Sperren dieser ID geloest (Sinne/Extra.lua)
-- /lyra test alle|all   -> alle warn-IDs im 4-s-Takt; /lyra test stop bricht ab
cmd(function(a)
    local X = ns.Sinne and ns.Sinne.Extra
    if a == "" then
        if ns.Settings and ns.Settings.probe then ns.Settings.probe()
        elseif ns.melde then ns.melde("LEERLAUF") end
        return
    end
    if not X then ns.print(L("unknown command")); return end
    if a == "alle" or a == "all" then X.testAlle()
    elseif a == "stop" or a == "stopp" then X.testStop()
    else X.test(a) end
end, "probe", "test")
-- Feature-Welle 1: Schalter + Erbe-Liste
cmd(function() toggle("fotos") end, "foto", "fotos", "photo", "photos")
cmd(function() toggle("ultra") end, "ultra")
cmd(function() toggle("streamer") end, "streamer", "stream")
-- /lyra stimmung  -> Zustandsmodell (Sinne/Leben2.lua). Reines Debug-/Neugier-Kommando.
cmd(function()
    if ns.Stimmung and ns.Stimmung.status then
        for _, z in ipairs(ns.Stimmung.status()) do ns.print(z) end
    else
        ns.print(L("unknown command"))
    end
end, "stimmung", "mood", "laune")
cmd(function() toggle("ssf") end, "ssf", "selffound", "selbstgefunden")
cmd(function()
    if ns.Erbe and ns.Erbe.status then
        for _, z in ipairs(ns.Erbe.status()) do ns.print(z) end
    else
        ns.print(L("unknown command"))
    end
end, "erbe", "legacy", "vorgaenger", "vorgänger")
-- /lyra persoenlich -> Stand des Datenpakets Lyra_Gestalt_Persoenlich (Sinne/Persoenlich.lua):
-- geladen ja/nein, Zeilen je Ereignis, erzeugt am, Quelle, verworfene Zeilen mit Grund.
cmd(function()
    if ns.Persoenlich and ns.Persoenlich.status then
        for _, z in ipairs(ns.Persoenlich.status()) do ns.print(z) end
    else
        ns.print(L("unknown command"))
    end
end, "persoenlich", "persönlich", "personal", "meine")
-- Interaktion: Menue, Gespraechsbaum, Chronik
cmd(function() if ns.menue then ns.menue() else ns.print(L("unknown command")) end end, "menue", "menü", "menu")
cmd(function()
    if ns.Dialog and ns.Dialog.oeffne then ns.Dialog.oeffne() else ns.print(L("Dialog missing")) end
end, "frag", "fragen", "ask", "dialog", "talk", "reden")
cmd(function()
    if ns.Dialog and ns.Dialog.chronik then ns.Dialog.chronik() else ns.print(L("Chronicle missing")) end
end, "chronik", "chronicle", "tagebuch", "diary")

-- Bruecken-Welle 1 (Sinne/Bruecken.lua). Das Modul darf fehlen; dann sagt Lyra "unknown command".
-- Zweites Argument der Befehle ist der Rest in ORIGINAL-Schreibweise (Titel/Namen bleiben so,
-- wie getippt); das erste bleibt kleingeschrieben, weil alle alten Befehle darauf bauen.
local function bruecke(name, ...)
    local B = ns.Bruecken
    if not (B and type(B[name]) == "function") then ns.print(L("unknown command")); return end
    local ok, err = pcall(B[name], ...)
    if not ok then ns.debug("Bruecken " .. name .. ": " .. tostring(err)) end
end
-- /lyra punkt [titel]  -> Wegpunkt + Chronik-Notiz an der aktuellen Stelle
-- REVIEW6B: Alias "mark" hier entfernt - er ueberschrieb das Welle-2-Kommando "/lyra mark <zeichen>"
-- (Raid-Zeichen, weiter oben registriert), weil der spaetere cmd()-Eintrag gewinnt. "/lyra mark skull"
-- legte damit einen Wegpunkt namens "skull" an. Wegpunkt bleibt punkt/wegpunkt/waypoint/markier(e).
-- W5: "/lyra punkt weg [n]" loescht einen Punkt (ohne Zahl den zuletzt gesetzten). Die Weiche
-- steht VOR bruecke("punkt"), sonst legte "/lyra punkt weg" einen Wegpunkt namens "weg" an -
-- dieselbe Falle wie bei "/lyra mark skull" (REVIEW6B) und "/lyra markier das ziel".
-- "weg" ist als Notiztext verloren; wer wirklich einen Punkt "weg" nennen will, nimmt zwei Worte.
local PUNKT_WEG = { weg = true, loesch = true, ["lösch"] = true, loesche = true, ["lösche"] = true,
                    remove = true, delete = true, del = true }
cmd(function(a, roh)
    local wort, zahl = tostring(a or ""):match("^(%a*)%s*(%d*)$")
    if wort and PUNKT_WEG[wort] then
        if ns.Karte2 and ns.Karte2.punktWeg then
            ns.Karte2.punktWeg(tonumber(zahl))
        else
            ns.print(L("unknown command"))
        end
        return
    end
    bruecke("punkt", roh or "")
end, "punkt", "wegpunkt", "waypoint")
-- REVIEW6B: "markier"/"markiere" sind zweideutig. "/lyra markier Hier war es knapp" ist ein
-- Wegpunkt (Welle 1), "/lyra markier das ziel" meint das Raid-Zeichen (Welle 2). Ohne diese
-- Weiche legte die zweite Form einen Wegpunkt namens "das ziel" an - der Praefix-Intent in
-- welle2_dialog.lua wird vom Slash-Befehl nie erreicht.
cmd(function(a, roh)
    a = a or ""
    if a:find("^das ziel") or a:find("^the target") or a:find("^ziel") or a:find("^mein ziel") then
        if ns.Karte then
            local ok = ns.Karte.mark(ns.Karte.markAusText(a))
            if not ok then ns.print(ns.L["No mark target"]) end
        else
            ns.print(L("unknown command"))
        end
        return
    end
    bruecke("punkt", roh or "")
end, "markier", "markiere")
-- /lyra punkte         -> Liste;  /lyra punkte <n> -> Wegpunkt zu Notiz n
cmd(function(a)
    local n = tonumber(a)
    if n then bruecke("punktZeigen", n) else bruecke("punkte") end
end, "punkte", "wegpunkte", "waypoints", "markierungen")
-- /lyra such <name>    -> Questie-Namenssuche + Wegpunkt auf den naechsten Spawn
cmd(function(_, roh) bruecke("sucheNpc", roh or "") end, "such", "suche", "finde", "find", "search", "mob")
-- /lyra quest <titel>  -> Questgeber der Quest
cmd(function(_, roh) bruecke("sucheQuest", roh or "") end, "quest", "questgeber", "questgiver", "auftrag")
-- /lyra runen          -> letzte Fehler aus !BugGrabber, gekuerzt
cmd(function() bruecke("runen") end, "runen", "runes", "fehler", "bugs", "errors")

SLASH_LYRAGESTALT1 = "/lyra"
SLASH_LYRAGESTALT2 = "/lyragestalt"
SlashCmdList["LYRAGESTALT"] = function(msg)
    msg = tostring(msg or "")
    local c, rohRest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    c = (c or ""):lower()
    rohRest = rohRest or ""
    local rest = rohRest:lower()
    -- REVIEW3: Letzte Worte (Sinne/Erbe.lua): waehrend der 60-s-Frist geht jede mehrwortige Eingabe als Freitext
    -- durch - sonst frisst ein Befehlswort am Satzanfang ("Hilfe kommt nie.", "Still bleiben.") die Worte.
    if ns.erbeWarteAufWorte and rest ~= "" and ns.Dialog and ns.Dialog.frage then
        ns.Dialog.frage(msg:match("^%s*(.-)%s*$") or "")
        return
    end
    local fn = CMDS[c]
    if fn then fn(rest, rohRest); return end
    -- Kein Befehl: Freitext an Lyra (Original-Schreibweise, damit Notizen so bleiben, wie getippt)
    local frei = msg:match("^%s*(.-)%s*$") or ""
    if ns.Dialog and ns.Dialog.frage then ns.Dialog.frage(frei) else ns.print(L("unknown command")) end
end

-- Linksklick auf die Gestalt: eine Leerlauf-Zeile, sofern die Regie es erlaubt (Drossel bleibt).
-- FIX5 (17.09.2026): Der zweite Klick innerhalb von 2 s oeffnete bis 0.6.0 die Einstellungen.
-- Das ist weg. Grund: der Doppelklick links wechselt jetzt die Ansicht (Portrait <-> Figur,
-- Gestalt/Gestalt.lua), und zwei Bedeutungen fuer denselben Doppelklick waeren ein Wuerfelspiel.
-- Die Einstellungen stehen im Menue (Shift+Rechtsklick / Minimap-Rechtsklick) und unter /lyra.
ns.klick = function()
    if ns.melde then ns.melde("KLICK", { direkt = true }) end
end
