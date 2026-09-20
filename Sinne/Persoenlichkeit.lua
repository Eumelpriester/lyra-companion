-- Sinne/Persoenlichkeit.lua — Lyra weiss, mit WEM sie spricht (Welle 3).
--
-- Bis 0.7.0 kannte Lyra die Lage (Leben, Zone, Kampf) und die Chronik (Besuche, Beinahe-Tode),
-- aber nicht die Person: nicht die Klasse, nicht die Rasse, nicht die Uhrzeit beim Spieler,
-- nicht die Lieblingszone, nicht die Frage von vorhin. Das sind keine neuen Ereignisse - das
-- sind PLATZHALTER an bestehenden Zeilen. Genau dafuer ist der Weg da, den Sinne/Rituale.lua
-- mit {erinnerung} vorgemacht hat: ein Wrapper um ns.melde legt etwas in vars, und
-- Core/Regie.lua waehle() nimmt jede Zeile, deren Platzhalter erfuellt sind.
--
-- NEUE PLATZHALTER (global, an JEDEM Ereignis verfuegbar - eine Zeile ohne sie merkt nichts):
--   {klasse}  Klassenname in LYRAS Sprache    UnitClass("player") (Name + Token), P.KLASSEN
--   {rasse}   Rassenname in LYRAS Sprache     UnitRace("player")  (Name + Token), P.RASSEN
--   {stufe}   eigene Stufe                    UnitLevel("player")   (NICHT {level} - das ist
--             seit Welle 1 je Ereignis belegt, etwa als Queststufe)
--   {uhr}     echte Uhrzeit beim Spieler      date("%H:%M")
--   {heimat}  Zone mit der meisten Spielzeit  eigene Messung, siehe unten
--   {frage}   letzte Freitext-Frage, gekuerzt  nur 5 min bis 3 h nach der Frage
-- Die Namen sind absichtlich NEU: {zone} und {level} sind je Ereignis belegt; sie global zu
-- fuellen haette Zeilen fremder Ereignisse plausibel aussehen lassen und falsch gemacht.
--
-- NEUE EREIGNISSE:
--   SITZUNG_UEBER_SCHNITT  plauder, 1x je Sitzung: diese Sitzung ist deutlich laenger als deine
--                          eigenen im Schnitt ({stunden}, {schnitt})
--   LAUNE_GUT / LAUNE_BESORGT   still, beim Login: die Laune als MIENE, ohne ein Wort
--
-- VERTRAUTHEIT WAECHST AUCH DURCH INTERAKTION. Bisher zaehlte nur Spielzeit (Sinne/Leben2.lua,
-- 10/50/100 h). Wer Lyra anklickt und ihr Fragen stellt, ist ihr naeher als wer sie ignoriert -
-- also zaehlen Klicks und Fragen als Zeit mit: ein Klick eine Minute, eine Frage fuenf, gedeckelt
-- bei BONUS_MAX Stunden. Umgesetzt als Wrapper um ns.Stimmung.vertraut (Muster aus
-- Sinne/Profil.lua, das ns.Stimmung.tags umwickelt). /lyra stimmung zeigt weiter die ECHTEN
-- Stunden - gelogen wird nicht, nur die Stufe kommt frueher.
--
-- LIEBLINGSZONE: die Chronik zaehlt Besuche, nicht Zeit - und wer einmal durch Dun Morogh
-- durchreitet, hat dort einen Besuch wie jemand, der drei Abende dort spielt. Also eigene
-- Messung: ein 60-s-Ticker (derselbe fuer alles in dieser Datei) schreibt die Sekunden je Zone
-- nach LyraGestaltDB.chronik[charKey].zonenZeit. AFK-Minuten zaehlen nicht mit, genau wie bei
-- der Spielzeit in Sinne/Leben2.lua.
--
-- Blizzard-API (nur lesend): UnitClass, UnitRace, UnitLevel, UnitIsAFK, UnitIsDeadOrGhost,
--   GetRealZoneText/GetZoneText, GetLocale, date, time, GetTime.
-- Events: PLAYER_LOGIN, PLAYER_ENTERING_WORLD, PLAYER_LEVEL_UP, PLAYER_LOGOUT.
-- Takt: EIN 60-s-Ticker. Kein OnUpdate.
-- KEINE FREMD-ADDONS, kein Netz, keine Spielernamen. {frage} ist der eigene Tipptext des
--   Spielers, gekuerzt und von |-Escapes, Steuerzeichen und {} befreit (wie Sinne/Persoenlich.lua
--   es fuer das Datenpaket tut).
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local P = {}
ns.Sinne.Persoenlichkeit = P
ns.Persoenlichkeit = P

local TICK = 60
P.BONUS_KLICK   = 60           -- s "Zeit" je Klick auf Lyra
P.BONUS_FRAGE   = 300          -- s "Zeit" je Freitext-Frage
P.BONUS_MAX_H   = 20           -- h: Deckel des Interaktions-Bonus
P.HEIMAT_MIN    = 1800         -- s in einer Zone, bevor sie "Heimat" heissen darf
P.HEIMAT_BESUCHE = 5           -- Rueckfall ohne Zeitmessung: so viele Besuche
P.FRAGE_AB      = 300          -- s: so lange nach der Frage ist sie "vorhin"
P.FRAGE_BIS     = 10800        -- s: danach ist sie vergessen
P.FRAGE_KUERZE  = 40           -- Zeichen
P.SITZUNG_MIN_H = 2            -- h: kuerzere Sitzungen sind nie "lang"
P.SITZUNG_FAKTOR = 1.5         -- x eigener Schnitt
P.LAUNE_NACH    = 5            -- s: frueheste Wunschzeit der Laune-Miene. Der echte Zeitpunkt
                               -- kommt aus ns.Regie.loginSlot() - siehe PLAYER_ENTERING_WORLD.

local acc = nil                -- LyraGestaltDB.account
local ticker = nil
local letzterTick = 0
local letzteFrage = nil        -- { text = ..., t = GetTime }, nur Sitzung, nie gespeichert
local sitzungGesagt = false
local gewrappt = { melde = false, vertraut = false, dialog = false }

local function jetzt() return (GetTime and GetTime()) or 0 end
local function unix() return (time and time()) or 0 end
local function afk() return (UnitIsAFK and UnitIsAFK("player")) and true or false end
local function zoneJetzt()
    return (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
end

-- ---------------------------------------------------------------------------------------------
-- Speicher
-- ---------------------------------------------------------------------------------------------
local function ladeAcc()
    if not (LyraGestaltDB and type(LyraGestaltDB.account) == "table") then
        if ns.initDB then pcall(ns.initDB) end
    end
    if not (LyraGestaltDB and type(LyraGestaltDB.account) == "table") then return end
    acc = LyraGestaltDB.account
    acc.klicks = tonumber(acc.klicks) or 0
    acc.fragen = tonumber(acc.fragen) or 0
end

local function charDB(anlegen)
    local c = LyraGestaltDB and ns.charKey and LyraGestaltDB.chronik and LyraGestaltDB.chronik[ns.charKey]
    if type(c) ~= "table" then
        if not (anlegen and LyraGestaltDB and ns.charKey) then return nil end
        LyraGestaltDB.chronik = LyraGestaltDB.chronik or {}
        c = {}
        LyraGestaltDB.chronik[ns.charKey] = c
    end
    return c
end

local function zonenZeit(anlegen)
    local c = charDB(anlegen)
    if not c then return nil end
    if type(c.zonenZeit) ~= "table" then
        if not anlegen then return nil end
        c.zonenZeit = {}
    end
    return c.zonenZeit
end

-- ---------------------------------------------------------------------------------------------
-- Person
-- ---------------------------------------------------------------------------------------------
-- REVIEW8 (ENTSCHIEDEN, war der offene Punkt aus Sinne/WELLE3.md):
-- Der Client liefert den lokalisierten Namen in SEINER Sprache, nicht in Lyras. Deutscher
-- Client + Lyra auf Englisch ergab "There's my Magierin." - in SECHS Zeilen (LOGIN 19/21,
-- LEERLAUF 14, KAMPF_REKORD 6 und Gegenstuecke), also nicht in einer Ecke, sondern in der
-- allerersten Zeile nach dem Login.
--
-- Zwei Wege standen zur Wahl: die englischen Zeilen ohne die Platzhalter schreiben (dann fehlt
-- der Effekt genau der Sprache, in der das Addon veroeffentlicht wird), oder eine eigene
-- Tabelle. Gebaut ist die Tabelle - 9 Klassen und 8 Rassen, das ist Classic Era vollstaendig
-- und seit 2004 unveraendert. Der Schluessel ist das TOKEN aus dem ZWEITEN Rueckgabewert von
-- UnitClass/UnitRace ("MAGE", "NightElf"); das ist sprachunabhaengig und genau dafuer da.
--
-- VORRANG (wichtig): passt die Client-Sprache zu Lyras Sprache, gewinnt der CLIENT-Name. Er ist
-- immer richtig geschrieben und richtig gebeugt, auch dort, wo diese Tabelle irren koennte
-- (und bei einer Sprache, die es hier nie geben wird - frFR-Client + Lyra "en" bekommt dann
-- Englisch aus der Tabelle statt Franzoesisch aus dem Client, und das ist das Gewuenschte).
-- Kennt die Tabelle das Token nicht (neue Rasse, Fremdsprachen-Rueckfall), bleibt der
-- Client-Name stehen - lieber die falsche Sprache als ein fehlender Satz.
--
-- Deutsch ist gebeugt: de = maennlich/neutral, deF = weiblich. Genommen wird ns.geschlecht()
-- (dieselbe Quelle wie der Anrede-Token). Ein Token im WERT waere hier wirkungslos, denn
-- Core/Regie.lua ruft ns.fuelle NACH ns.Anrede - der Platzhalter-Inhalt wird nicht mehr
-- nach {m|f} durchsucht.
P.KLASSEN = {
    WARRIOR = { de = "Krieger",       deF = "Kriegerin",      en = "Warrior" },
    PALADIN = { de = "Paladin",       deF = "Paladin",        en = "Paladin" },
    HUNTER  = { de = "Jäger",         deF = "Jägerin",        en = "Hunter"  },
    ROGUE   = { de = "Schurke",       deF = "Schurkin",       en = "Rogue"   },
    PRIEST  = { de = "Priester",      deF = "Priesterin",     en = "Priest"  },
    SHAMAN  = { de = "Schamane",      deF = "Schamanin",      en = "Shaman"  },
    MAGE    = { de = "Magier",        deF = "Magierin",       en = "Mage"    },
    WARLOCK = { de = "Hexenmeister",  deF = "Hexenmeisterin", en = "Warlock" },
    DRUID   = { de = "Druide",        deF = "Druidin",        en = "Druid"   },
}
P.RASSEN = {
    Human    = { de = "Mensch",   deF = "Mensch",    en = "Human"     },
    Dwarf    = { de = "Zwerg",    deF = "Zwergin",   en = "Dwarf"     },
    NightElf = { de = "Nachtelf", deF = "Nachtelfe", en = "Night Elf" },
    Gnome    = { de = "Gnom",     deF = "Gnomin",    en = "Gnome"     },
    Orc      = { de = "Orc",      deF = "Orc",       en = "Orc"       },
    Tauren   = { de = "Taure",    deF = "Taurin",    en = "Tauren"    },
    Troll    = { de = "Troll",    deF = "Troll",     en = "Troll"     },
    -- UnitRace gibt fuer Untote "Scourge" zurueck, nicht "Undead". Beide Schreibweisen, weil
    -- aeltere Staende und manche Emulatoren "Undead" liefern.
    Scourge  = { de = "Untoter",  deF = "Untote",    en = "Undead"    },
    Undead   = { de = "Untoter",  deF = "Untote",    en = "Undead"    },
}

-- Spricht der Client dieselbe Sprache wie Lyra? Dann ist sein Name der bessere.
local function clientPasst()
    local l = (GetLocale and GetLocale()) or "enUS"
    local s = ns.sprache()
    if s == "de" then return l == "deDE" end
    return l ~= "deDE"        -- alles andere ist fuer uns "nicht deutsch" -> en passt
end

local function nameAus(tab, token, lokal)
    if clientPasst() and type(lokal) == "string" and lokal ~= "" then return lokal end
    local e = type(token) == "string" and tab[token] or nil
    if not e then
        -- Token unbekannt: der Client-Name ist immer noch besser als nichts.
        if type(lokal) == "string" and lokal ~= "" then return lokal end
        return nil
    end
    if ns.sprache() == "de" then
        local g = ns.geschlecht and ns.geschlecht() or "m"
        return (g == "f" and e.deF) or e.de
    end
    return e.en
end
P.nameAus = nameAus

function P.klasse()
    if not UnitClass then return nil end
    local ok, lokal, token = pcall(UnitClass, "player")
    if not ok then return nil end
    return nameAus(P.KLASSEN, token, lokal)
end

function P.rasse()
    if not UnitRace then return nil end
    local ok, lokal, token = pcall(UnitRace, "player")
    if not ok then return nil end
    return nameAus(P.RASSEN, token, lokal)
end

function P.uhr()
    if type(date) ~= "function" then return nil end
    local ok, s = pcall(date, "%H:%M")
    if ok and type(s) == "string" and s ~= "" then return s end
    return nil
end

-- Zone mit der meisten gemessenen Zeit. Ohne genug Messung: die mit den meisten Besuchen.
-- 30 s gecacht: der ns.melde-Wrapper fragt bei JEDER Meldung, und die Antwort aendert sich
-- hoechstens minuetlich (der Ticker schreibt im 60-s-Takt).
local heimatCache, heimatBis, heimatMin = nil, 0, nil

local function heimatRechnen()
    local zz = zonenZeit(false)
    if zz then
        local bestZ, bestS = nil, 0
        for z, s in pairs(zz) do
            s = tonumber(s) or 0
            if type(z) == "string" and z ~= "" and s > bestS then bestZ, bestS = z, s end
        end
        if bestZ and bestS >= P.HEIMAT_MIN then return bestZ, math.floor(bestS / 60) end
    end
    local c = charDB(false)
    local zonen = type(c) == "table" and c.zonen
    if type(zonen) ~= "table" then return nil end
    local bestZ, bestN = nil, 0
    for z, e in pairs(zonen) do
        local n = (type(e) == "table" and tonumber(e.besuche)) or 0
        if type(z) == "string" and z ~= "" and n > bestN then bestZ, bestN = z, n end
    end
    if bestZ and bestN >= P.HEIMAT_BESUCHE then return bestZ, nil end
    return nil
end

function P.heimat()
    local t = jetzt()
    if t < heimatBis then return heimatCache, heimatMin end
    local ok, z, m = pcall(heimatRechnen)
    heimatCache, heimatMin = (ok and z) or nil, (ok and m) or nil
    heimatBis = t + 30
    return heimatCache, heimatMin
end

-- ---------------------------------------------------------------------------------------------
-- Interaktion -> Vertrautheit
-- ---------------------------------------------------------------------------------------------
function P.bonusStunden()
    if not acc then return 0 end
    local s = (tonumber(acc.klicks) or 0) * P.BONUS_KLICK + (tonumber(acc.fragen) or 0) * P.BONUS_FRAGE
    local h = s / 3600
    if h > P.BONUS_MAX_H then h = P.BONUS_MAX_H end
    return h
end

-- Wrapper um ns.Stimmung.vertraut. Leben2.lua rechnet die Stufe aus S.stunden(); wir rechnen
-- dieselbe Treppe aus (Stunden + Bonus). Die Grenzen stehen dort als STUFEN_H = {10, 50, 100} -
-- hier noch einmal, weil sie dort lokal sind und Leben2.lua einem anderen Team gehoert.
P.STUFEN_H = { 10, 50, 100 }

local function vertrautWrappen()
    if gewrappt.vertraut then return end
    local S = ns.Stimmung
    if not (S and type(S.vertraut) == "function" and type(S.stunden) == "function") then return end
    gewrappt.vertraut = true
    local orig = S.vertraut
    S.vertraut = function(...)
        local roh = orig(...)
        local ok, h = pcall(S.stunden)
        if not ok or type(h) ~= "number" then return roh end
        local ges = h + P.bonusStunden()
        local stufe = 0
        if ges >= P.STUFEN_H[3] then stufe = 3
        elseif ges >= P.STUFEN_H[2] then stufe = 2
        elseif ges >= P.STUFEN_H[1] then stufe = 1 end
        if type(roh) == "number" and roh > stufe then return roh end   -- nie nach unten
        return stufe
    end
end

-- ---------------------------------------------------------------------------------------------
-- Die letzte Freitext-Frage
-- ---------------------------------------------------------------------------------------------
-- Es ist der eigene Tipptext des Spielers. Er geht in eine Sprechblase, also durch dieselbe
-- Wache wie eine persoenliche Zeile (Sinne/Persoenlich.lua textOk): keine |-Escapes (sonst
-- koennte ein getipptes |cff... die Blase umfaerben), keine Steuerzeichen, keine {Platzhalter}
-- (die wuerde ns.fuelle sonst ein zweites Mal ansehen), gekuerzt.
local FUELL_FRAGE = {
    ["wo"] = true, ["ist"] = true, ["wer"] = true, ["was"] = true, ["der"] = true, ["die"] = true,
    ["das"] = true, ["den"] = true, ["dem"] = true, ["ein"] = true, ["eine"] = true, ["mir"] = true,
    ["mal"] = true, ["bitte"] = true, ["such"] = true, ["suche"] = true, ["finde"] = true,
    ["where"] = true, ["who"] = true, ["what"] = true, ["the"] = true, ["a"] = true, ["an"] = true,
    ["is"] = true, ["find"] = true, ["me"] = true, ["please"] = true, ["show"] = true, ["zeig"] = true,
}

function P.frageSaeubern(roh)
    local s = tostring(roh or "")
    s = s:gsub("[\1-\31\127]", " ")           -- Steuerzeichen
    s = s:gsub("|", " ")                      -- WoW-Escapes, restlos
    s = s:gsub("[{}]", " ")                   -- Platzhalter-Klammern
    s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return nil end
    -- Fuellwoerter vorn weg ("wo ist Hogger" -> "Hogger"), wie Sinne/Bruecken.lua entfuellen()
    local w = {}
    for wort in s:gmatch("%S+") do w[#w + 1] = wort end
    while #w > 0 and FUELL_FRAGE[w[1]:lower()] do table.remove(w, 1) end
    s = table.concat(w, " ")
    if s == "" then return nil end
    -- Gesamtlaenge, nicht Laenge-plus-Punkte: FRAGE_KUERZE ist eine Obergrenze und keine Absicht.
    if #s > P.FRAGE_KUERZE then s = s:sub(1, P.FRAGE_KUERZE - 3) .. "..." end
    return s
end

function P.frage()
    if not letzteFrage then return nil end
    local alt = jetzt() - letzteFrage.t
    if alt < P.FRAGE_AB or alt > P.FRAGE_BIS then return nil end
    return letzteFrage.text
end

-- Wrapper um ns.Dialog.frage (UI/Dialog.lua bleibt unangetastet; Muster aus Sinne/Erbe.lua).
-- Er zaehlt die Frage und merkt sich das Thema. Er entscheidet NICHTS und antwortet NICHTS.
local function dialogWrappen()
    if gewrappt.dialog then return end
    if not (ns.Dialog and type(ns.Dialog.frage) == "function") then return end
    gewrappt.dialog = true
    local orig = ns.Dialog.frage
    ns.Dialog.frage = function(roh, ...)
        local ok, t = pcall(P.frageSaeubern, roh)
        if ok and t then letzteFrage = { text = t, t = jetzt() } end
        if acc then acc.fragen = (tonumber(acc.fragen) or 0) + 1 end
        return orig(roh, ...)
    end
end

-- ---------------------------------------------------------------------------------------------
-- Der Wrapper um ns.melde: Platzhalter nachlegen und Klicks zaehlen
-- ---------------------------------------------------------------------------------------------
-- Aussen um alle anderen (Sinne/Rituale.lua {erinnerung}, Sinne/Persoenlich.lua persoenlichText),
-- weil diese Datei in der TOC nach beiden steht und ihren PLAYER_LOGIN-Handler also spaeter
-- registriert. Wichtig: es wird nur GESETZT, was noch nicht da ist - ein Sinn, der {stufe}
-- selbst mitschickt, gewinnt.
local function meldeWrappen()
    if gewrappt.melde then return end
    if type(ns.melde) ~= "function" then return end
    gewrappt.melde = true
    local echt = ns.melde
    ns.melde = function(id, vars)
        if id == "KLICK" and acc then acc.klicks = (tonumber(acc.klicks) or 0) + 1 end
        vars = vars or {}
        if vars.klasse == nil then vars.klasse = P.klasse() end
        if vars.rasse == nil then vars.rasse = P.rasse() end
        if vars.stufe == nil then
            local lvl = (UnitLevel and UnitLevel("player")) or 0
            if lvl > 0 then vars.stufe = lvl end
        end
        if vars.uhr == nil then vars.uhr = P.uhr() end
        if vars.heimat == nil then
            local h = P.heimat()
            -- Die Heimat nur nennen, wenn wir NICHT gerade dort stehen - sonst ist der Satz
            -- "Dun Morogh. Immer noch dein Lieblingsplatz." eine Binsenwahrheit.
            if h and h ~= zoneJetzt() then vars.heimat = h end
        end
        if vars.frage == nil then vars.frage = P.frage() end
        return echt(id, vars)
    end
end

-- ---------------------------------------------------------------------------------------------
-- Sitzungslaenge gegen den eigenen Schnitt
-- ---------------------------------------------------------------------------------------------
-- Die Sitzungsliste gehoert Sinne/Chronik.lua (DB.sitzungen, Ringpuffer 30). Wir lesen sie
-- ueber ns.Chronik.stand() - kein zweiter Zaehler, keine zweite Wahrheit.
function P.sitzungSchnitt()
    if not (ns.Chronik and ns.Chronik.stand) then return nil end
    local ok, db, aktuell = pcall(ns.Chronik.stand)
    if not ok or type(db) ~= "table" or type(db.sitzungen) ~= "table" then return nil end
    local summe, n = 0, 0
    for _, s in ipairs(db.sitzungen) do
        if type(s) == "table" and s ~= aktuell then
            local d = (tonumber(s.ende) or 0) - (tonumber(s.start) or 0)
            if d > 300 and d < 24 * 3600 then summe = summe + d; n = n + 1 end
        end
    end
    if n < 3 then return nil end
    return summe / n / 3600, n
end

local function sitzungPruefen()
    if sitzungGesagt then return end
    if not (ns.Stimmung and ns.Stimmung.zustand) then return end
    local ok, z = pcall(ns.Stimmung.zustand)
    if not ok or type(z) ~= "table" then return end
    local jetztH = tonumber(z.sitzung) or 0
    if jetztH < P.SITZUNG_MIN_H then return end
    local schnitt = P.sitzungSchnitt()
    if not schnitt or schnitt <= 0 then return end
    if jetztH < schnitt * P.SITZUNG_FAKTOR then return end
    if z.tot or (ns.Regie and ns.Regie.imKampf) then return end     -- naechster Tick versucht es wieder
    sitzungGesagt = ns.melde("SITZUNG_UEBER_SCHNITT", {
        stunden = math.floor(jetztH * 10 + 0.5) / 10,
        schnitt = math.floor(schnitt * 10 + 0.5) / 10,
    }) and true or false
end

-- ---------------------------------------------------------------------------------------------
-- Takt: Zonenzeit + Sitzungslaenge. Ein Ticker fuer beides.
-- ---------------------------------------------------------------------------------------------
local function tick()
    local t = jetzt()
    local delta = (letzterTick > 0) and (t - letzterTick) or TICK
    letzterTick = t
    if delta <= 0 or delta > 4 * TICK then delta = TICK end     -- Ladebildschirm: kein Sprung
    if not afk() then
        local z = zoneJetzt()
        if z ~= "" then
            local zz = zonenZeit(true)
            if zz then zz[z] = (tonumber(zz[z]) or 0) + delta end
        end
    end
    sitzungPruefen()
end

local function tickerStart()
    letzterTick = jetzt()
    if ticker then return end
    ticker = ns.Compat.NewTicker(TICK, function()
        local ok, err = pcall(tick)
        if not ok then ns.debug("Persoenlichkeit tick: " .. tostring(err)) end
    end)
end

-- ---------------------------------------------------------------------------------------------
-- Ereignisse
-- ---------------------------------------------------------------------------------------------
ns.on("PLAYER_LOGIN", function()
    ladeAcc()
    meldeWrappen()
    vertrautWrappen()
    dialogWrappen()
    tickerStart()
end)

local ersterPEW = true
ns.on("PLAYER_ENTERING_WORLD", function()
    if not acc then ladeAcc() end
    tickerStart()
    letzterTick = jetzt()
    if not ersterPEW then return end
    ersterPEW = false
    -- Die Laune als MIENE nach dem Login. Klasse "still": kein Wort, kein Abstand, kein Budget -
    -- nur das Gesicht. Wer ein besorgtes Gesicht sieht, weiss, dass da etwas nachhaengt, und
    -- kann /lyra stimmung fragen.
    --
    -- REVIEW8: Das lief auf P.LAUNE_NACH = 5 s - und ns.GRUSS_NACH (Core/Start.lua) liegt auf
    -- R.LOGIN_GRUSS = 6 s. Die Laune-Miene stand also GENAU EINE SEKUNDE, dann hat die Miene des
    -- Login-Grusses sie ersetzt. Im Prueftstand review5.lua (Modus login2/kollision/plan3/plan4)
    -- als "1.0 s (LAUNE_GUT -> WIEDERKEHR)" sichtbar; das Versprechen aus Sinne/WELLE3.md
    -- Pruefpunkt 16 ("macht beim Login ein besorgtes Gesicht") war damit nicht eingehalten.
    --
    -- Gebaut ist jetzt derselbe Weg, den Review 4 fuer genau dieses Problem gebaut hat:
    -- ns.Regie.loginSlot() gibt den fruehesten Zeitpunkt, der einen vollen Plauder-Abstand hinter
    -- der zuletzt vergebenen Login-Zeile liegt. Diese Datei steht in der TOC als LETZTE der Sinne,
    -- bekommt also den Slot NACH LOGIN/WIEDERKEHR, TAG_ERSTER, ERBE_* und DEBRIEF. Das ist auch
    -- inhaltlich der richtige Ort: die Laune-Miene ist kein Ereignis, sondern der Zustand, in dem
    -- Lyra stehen bleibt, wenn das Begruessen durch ist - vorher wird sie ohnehin ueberschrieben.
    local verzug = P.LAUNE_NACH
    if ns.Regie and ns.Regie.loginSlot then
        local okS, v = pcall(ns.Regie.loginSlot, P.LAUNE_NACH)
        if okS and type(v) == "number" and v > 0 then verzug = v end
    end
    ns.Compat.After(verzug, function()
        if not (ns.Stimmung and ns.Stimmung.zustand) then return end
        local ok, z = pcall(ns.Stimmung.zustand)
        if not ok or type(z) ~= "table" then return end
        if z.laune == "besorgt" then ns.melde("LAUNE_BESORGT")
        elseif z.laune == "gut" then ns.melde("LAUNE_GUT") end
    end)
end)

ns.on("PLAYER_LOGOUT", function()
    -- Angefangene Minute Zonenzeit sichern (wie Sinne/Leben2.lua es fuer die Spielzeit tut).
    if afk() then return end
    local delta = jetzt() - letzterTick
    if delta <= 0 or delta > TICK then return end
    local z = zoneJetzt()
    if z == "" then return end
    local zz = zonenZeit(true)
    if zz then zz[z] = (tonumber(zz[z]) or 0) + delta end
end)

-- ---------------------------------------------------------------------------------------------
-- Status (haengt an /lyra status)
-- ---------------------------------------------------------------------------------------------
function P.status()
    local de = ns.sprache() == "de"
    local h, min = P.heimat()
    local schnitt, n = P.sitzungSchnitt()
    local out = {
        (de and "Person: %s, %s, Stufe %s, bei dir ist es %s."
             or "Person: %s, %s, level %s, your clock says %s."):format(
            tostring(P.klasse() or "?"), tostring(P.rasse() or "?"),
            tostring((UnitLevel and UnitLevel("player")) or "?"), tostring(P.uhr() or "?")),
        (de and "  Klicks: %d, Fragen: %d - das sind %.1f h Vertrautheits-Bonus."
             or "  Clicks: %d, questions: %d - that is %.1f h familiarity bonus."):format(
            (acc and tonumber(acc.klicks)) or 0, (acc and tonumber(acc.fragen)) or 0, P.bonusStunden()),
    }
    if h then
        out[#out + 1] = (de and "  Lieblingszone: %s%s" or "  Favourite zone: %s%s"):format(
            tostring(h), min and ((de and " (%d Minuten gemessen)" or " (%d minutes measured)"):format(min)) or "")
    end
    if schnitt then
        out[#out + 1] = (de and "  Sitzungen im Schnitt: %.1f h (aus %d)." or "  Sessions average %.1f h (of %d)."):format(schnitt, n)
    end
    local f = P.frage()
    if f then out[#out + 1] = (de and "  Letzte Frage: %s" or "  Last question: %s"):format(f) end
    return out
end

function P.stand() return acc, letzteFrage, sitzungGesagt, gewrappt, zonenZeit(false) end
