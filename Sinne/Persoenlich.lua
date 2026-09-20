-- Sinne/Persoenlich.lua — laedt das Datenpaket Lyra_Gestalt_Persoenlich und mischt dessen Zeilen
--   in die Auswahl der Regie. Doku: Sinne/PERSOENLICH.md, Konzept docs/redakteur-konzept.md 1.4-1.6.
-- MELDET NICHTS SELBST. Ohne Paket legt diese Datei keinen Wrapper und die Auswahl ist exakt die
--   von vorher - das ist die wichtigste Eigenschaft hier, nicht eine Randnotiz.
-- Ereignisse: keine eigenen. Sie borgt sich die vorhandenen (nur plauder/still, NIE warn).
-- API: keine WoW-API ausser time/date (ueber ns). Kein Netz, kein Dateizugriff - das kann ein
--   Addon auch nicht; das Paket liegt als gewoehnliche Lua-Datei im Addon-Ordner.
-- Events: ADDON_LOADED (das Paket, falls es als LoadOnDemand kommt), PLAYER_LOGIN (Regelfall).
-- Quelle: globale Tabelle LyraGestalt_Persoenlich (Lyra_Gestalt_Persoenlich/persoenlich.lua):
--   { version = 1, erzeugt = "JJJJ-MM-TT", quelle = "hand"|"vorlage"|"modell", charKey = "Name-Realm",
--     zeilen = { { ereignis = "ZONE_ERINNERUNG", key = "Undercity", de = "...", en = "...",
--                  wenn = { zeit = "tag" } }, ... } }
-- Grenzen (jede einzeln im Harness geprueft):
--   * NUR Ereignisse der Klasse plauder oder still. Eine warn-Zeile wird verworfen, mit Grund.
--     Persoenliche Zeilen haben keine vorgerenderte Stimme (Konzept 7.2); eine Warnung muss
--     sprechen, ein Zonengruss darf lesen.
--   * charKey des Pakets muss zu ns.charKey passen, sonst wird das ganze Paket ignoriert.
--     Ein Paket OHNE charKey gilt account-weit; eine Zeile darf einen eigenen charKey tragen.
--   * hoechstens 120 Zeichen, keine |-Escapes (also auch keine |cFarbcodes), keine
--     Steuerzeichen, keine {platzhalter}, keine URL. Anrede-Token {Held|Heldin} sind erlaubt.
--   * hoechstens 200 Eintraege werden ueberhaupt angesehen (Deckel gegen ein kaputtes Paket).
-- Zusammenspiel: der Wrapper um ns.melde liegt AUSSEN, also ueber dem von Sinne/Rituale.lua
--   ({erinnerung}) - Persoenlich.lua steht in der TOC NACH Rituale.lua, registriert seinen
--   PLAYER_LOGIN-Handler also spaeter und wrappt das schon gewrappte ns.melde. Beide Wrapper
--   legen nur etwas in vars ab und rufen dann weiter; die Reihenfolge ist trotzdem festgenagelt,
--   weil das Konzept sie als Risiko fuehrt (docs/redakteur-konzept.md 6, Risikotabelle W1).
local ADDON, ns = ...
local P = {}
ns.Persoenlich = P

P.PAKET       = "Lyra_Gestalt_Persoenlich"
P.SCHEMA      = 1            -- version, die dieser Loader versteht. Hoeher = ignorieren, nicht wischen.
P.GEWICHT     = 3            -- wie ein erfuellter wenn-Tag (companion-v3 A.3). Siehe Core/Regie.lua.
P.MAX_ZEICHEN = 120
P.MAX_EINTRAEGE = 200

-- [ereignis][key] = { {de=,en=,wenn=}, ... };  key "" = Zeile ohne Schluessel (gilt ueberall)
local zeilen = {}
local stand = {
    paketDa = false, geladen = false, gewrappt = false,
    grund = nil, n = 0, erzeugt = nil, quelle = nil, charKey = nil,
    modell = nil, ki = false,   -- REDAKTEUR: nur zur Anzeige in /lyra persoenlich
    verworfen = {},        -- { {nr=, id=, grund=}, ... }
    gezogen = 0,           -- wie oft eine persoenliche Zeile in die Auswahl gelegt wurde (Debug)
}

-- ---------------------------------------------------------------- Pruefung einer Textzeile
-- Zeichen zaehlen, nicht Bytes: "Fuenf Besuche" mit Umlauten waere sonst je Umlaut ein Zeichen
-- zu lang. UTF-8-Folgebytes liegen zwischen 0x80 und 0xBF und zaehlen nicht mit.
local function zeichen(s)
    local n = 0
    for i = 1, #s do
        local b = s:byte(i)
        if b < 128 or b >= 192 then n = n + 1 end
    end
    return n
end

local function textOk(s)
    if type(s) ~= "string" then return false, "kein Text" end
    if s:find("^%s*$") then return false, "leer" end
    if zeichen(s) > P.MAX_ZEICHEN then return false, "zu lang" end
    if s:find("[\1-\31\127]") then return false, "steuerzeichen" end
    -- |c |r |T |H ... : WoW-Escapes. Der Anrede-Token {Held|Heldin} steht in Klammern und bleibt.
    if s:gsub("{[^{}]*}", ""):find("|", 1, true) then return false, "escape" end
    -- {zone}/{tage}/{level}: die Vars gibt es nur, wenn der Sinn sie mitschickt. Eine persoenliche
    -- Zeile hat ihre Zahlen ausgeschrieben - sonst stuende "{tage}" in der Blase.
    if s:find("{%a+}") then return false, "platzhalter" end
    local l = s:lower()
    if l:find("http", 1, true) or l:find("www.", 1, true) then return false, "url" end
    return true
end
P.textOk = textOk

-- ---------------------------------------------------------------- Paket lesen
local function klasseVon(id)
    local ph = LyraGestalt_Phrasen
    local e = ph and ph.ereignisse and ph.ereignisse[id]
    return e and e.klasse or nil
end

local function verwerfen(nr, id, grund)
    stand.verworfen[#stand.verworfen + 1] = { nr = nr, id = tostring(id or "?"), grund = grund }
end

function P.laden()
    zeilen = {}
    stand.geladen, stand.n, stand.verworfen = false, 0, {}
    stand.erzeugt, stand.quelle, stand.charKey = nil, nil, nil
    stand.modell, stand.ki = nil, false          -- REDAKTEUR
    stand.paketDa = type(LyraGestalt_Persoenlich) == "table"

    if ns.Get("persoenlich") == false then stand.grund = "abgeschaltet"; return false end
    local D = LyraGestalt_Persoenlich
    if type(D) ~= "table" then stand.grund = "kein Paket"; return false end
    if tonumber(D.version) ~= P.SCHEMA then
        stand.grund = "Schema " .. tostring(D.version)
        return false
    end
    if type(D.zeilen) ~= "table" then stand.grund = "keine Zeilen"; return false end

    if type(D.erzeugt) == "string" then stand.erzeugt = D.erzeugt end
    if type(D.quelle) == "string" then stand.quelle = D.quelle end
    if type(D.charKey) == "string" then stand.charKey = D.charKey end
    -- REDAKTEUR: Pakete vom Redakteur-Server tragen `modell` (Konzept 1.4) und `ki = true`
    -- (KI-Kennzeichnung, Konzept 4.4 Punkt 11). Beides ist optional; alte Pakete haben es
    -- nicht, und der Loader verlangt es nicht. Es wird nur in /lyra persoenlich angezeigt,
    -- damit die Kennzeichnung dort steht, wo der Spieler nachsieht - und nicht nur in einer
    -- Kommentarzeile der Datei. Sonst aendert dieser Block nichts.
    if type(D.modell) == "string" and #D.modell <= 40 then stand.modell = D.modell end
    stand.ki = (D.ki == true) or (stand.quelle == "modell")
    -- Fremder Charakter: das ganze Paket ignorieren. Nicht loeschen, nicht ueberschreiben - es
    -- gehoert jemand anderem auf diesem Account und wird beim Wechsel dorthin wieder gueltig.
    if stand.charKey and ns.charKey and stand.charKey ~= ns.charKey then
        stand.grund = "fremder charKey"
        return false
    end

    local sp = ns.sprache()
    for nr, z in ipairs(D.zeilen) do
        if nr > P.MAX_EINTRAEGE then verwerfen(nr, "?", "Deckel " .. P.MAX_EINTRAEGE); break end
        local grund = nil
        local id = (type(z) == "table") and z.ereignis or nil
        local klasse = (type(id) == "string") and klasseVon(id) or nil
        if type(z) ~= "table" then grund = "keine Tabelle"
        elseif type(id) ~= "string" then grund = "ohne ereignis"
        elseif not klasse then grund = "unbekanntes Ereignis"
        elseif klasse ~= "plauder" and klasse ~= "still" then grund = "Klasse " .. klasse
        elseif z.charKey ~= nil and (type(z.charKey) ~= "string"
               or (ns.charKey and z.charKey ~= ns.charKey)) then grund = "fremder charKey"
        elseif z.wenn ~= nil and type(z.wenn) ~= "table" then grund = "wenn ist keine Tabelle"
        elseif z.key ~= nil and type(z.key) ~= "string" and type(z.key) ~= "number" then grund = "key"
        else
            -- Pflicht ist die AKTIVE Sprache (ein Modell-Paket enthaelt laut Konzept 1.4 nur eine).
            -- Die andere wird geprueft, wenn sie da ist, und sonst mit der aktiven gefuellt -
            -- Core/Regie.lua faellt auf zeile.en zurueck, und das darf nie nil sein.
            local ok, g = textOk(z[sp])
            if not ok then grund = sp .. ": " .. g end
            if not grund then
                local andere = (sp == "de") and "en" or "de"
                if z[andere] ~= nil then
                    local ok2, g2 = textOk(z[andere])
                    if not ok2 then grund = andere .. ": " .. g2 end
                end
            end
        end
        if grund then
            verwerfen(nr, id, grund)
        else
            local k = (z.key ~= nil) and tostring(z.key) or ""
            zeilen[id] = zeilen[id] or {}
            zeilen[id][k] = zeilen[id][k] or {}
            -- Absichtlich OHNE stimme: persoenliche Zeilen sind stumm und erscheinen nur in der
            -- Blase (Core/Regie.lua ausgebenKern: gespielt bleibt false -> die Blase kommt immer).
            table.insert(zeilen[id][k], {
                de = z.de or z[sp], en = z.en or z[sp], wenn = z.wenn, persoenlich = true,
            })
            stand.n = stand.n + 1
        end
    end

    stand.geladen = true
    stand.grund = nil
    ns.debug(("Persoenlich: %d Zeilen, %d verworfen, erzeugt %s, Quelle %s"):format(
        stand.n, #stand.verworfen, tostring(stand.erzeugt), tostring(stand.quelle)))
    return true
end

-- ---------------------------------------------------------------- Auswahl
-- Passende persoenliche Zeile fuer id (+ vars.key) oder nil. Der wenn-Filter laeuft hier und
-- nicht in der Regie: eine Zeile mit unpassendem Tag soll die anderen nicht mitnehmen.
function P.zeileFuer(id, vars)
    local fuer = zeilen[id]
    if not fuer then return nil end
    local liste = nil
    local k = vars and vars.key
    if k ~= nil then liste = fuer[tostring(k)] end
    if not liste then liste = fuer[""] end
    if not liste or #liste == 0 then return nil end
    local kand = {}
    for _, z in ipairs(liste) do
        if not z.wenn then
            kand[#kand + 1] = z
        elseif ns.Stimmung and ns.Stimmung.passt and ns.Stimmung.passt(z.wenn) then
            kand[#kand + 1] = z
        end
    end
    if #kand == 0 then return nil end
    return kand[math.random(#kand)]
end

-- ---------------------------------------------------------------- Einmischen (Wrapper um ns.melde)
-- Muster aus Sinne/Rituale.lua ({erinnerung}) und Sinne/Erbe.lua (ns.Dialog.frage): nicht die
-- Phrasen-Tabelle anfassen, sondern etwas in vars legen und weiterrufen. Core/Regie.lua waehle()
-- nimmt vars.persoenlichText mit Gewicht P.GEWICHT in die Kandidaten auf (drei Zeilen dort,
-- gekennzeichnet mit "-- PERSOENLICH:"). Alles andere - Drossel, Abstand, Budget, Gruppe,
-- Kampf, Anrede, Platzhalter, Blase, Chronik-Hook - bleibt unberuehrt.
local function wrappen()
    if stand.gewrappt then return end
    if type(ns.melde) ~= "function" then return end
    stand.gewrappt = true
    local echt = ns.melde
    ns.melde = function(id, vars)
        local ok, z = pcall(P.zeileFuer, id, vars)
        if ok and z then
            vars = vars or {}
            vars.persoenlichText = z
            stand.gezogen = stand.gezogen + 1
        elseif vars and vars.persoenlichText ~= nil then
            vars.persoenlichText = nil      -- nie eine alte Zeile an einer wiederverwendeten vars-Tabelle
        end
        return echt(id, vars)
    end
end

-- ---------------------------------------------------------------- Ereignisse
local loginDurch = false

ns.on("ADDON_LOADED", function(name)
    if name ~= P.PAKET then return end
    stand.paketDa = type(LyraGestalt_Persoenlich) == "table"
    -- Regelfall: das Paket hat "## Dependencies: Lyra_Gestalt" und ist damit VOR dem Kern
    -- geladen; dieser Zweig greift nur, wenn es doch als LoadOnDemand nachkommt.
    if loginDurch then
        if P.laden() and stand.n > 0 then wrappen() end
    end
end)

ns.on("PLAYER_LOGIN", function()
    loginDurch = true
    if P.laden() and stand.n > 0 then wrappen() end
end)

-- ---------------------------------------------------------------- /lyra persoenlich
function P.stand() return stand end

function P.status()
    local L = ns.L
    local out = { L["Personal title"] }
    if not stand.paketDa then
        out[#out + 1] = "  " .. L["Personal missing"]
        out[#out + 1] = "  " .. L["Personal restart"]
        return out
    end
    if not stand.geladen then
        out[#out + 1] = "  " .. (L["Personal inactive"]):format(tostring(stand.grund or "?"))
    else
        out[#out + 1] = "  " .. (L["Personal active"]):format(stand.n, P.GEWICHT)
        local ids, n = {}, 0
        for id, nachKey in pairs(zeilen) do
            local m = 0
            for _, liste in pairs(nachKey) do m = m + #liste end
            n = n + 1
            ids[n] = id .. " (" .. m .. ")"
        end
        table.sort(ids)
        if n > 0 then out[#out + 1] = "  " .. (L["Personal events"]):format(table.concat(ids, ", ")) end
        out[#out + 1] = "  " .. (L["Personal voiceless"])
    end
    -- REDAKTEUR: Quelle "modell" heisst maschinell erzeugter, ungepruefter Text. Das Modell
    -- wird an dieselbe vorhandene Zeile gehaengt, damit kein neuer Locale-Schluessel noetig
    -- ist (und damit alte Uebersetzungen weiter passen).
    local quelle = tostring(stand.quelle or "?")
    if stand.ki then quelle = quelle .. " (KI" .. (stand.modell and (", " .. stand.modell) or "") .. ")" end
    out[#out + 1] = "  " .. (L["Personal origin"]):format(
        tostring(stand.erzeugt or "?"), quelle, tostring(stand.charKey or "-"))
    if #stand.verworfen == 0 then
        out[#out + 1] = "  " .. L["Personal clean"]
    else
        out[#out + 1] = "  " .. (L["Personal rejected"]):format(#stand.verworfen)
        for i = 1, math.min(10, #stand.verworfen) do
            local v = stand.verworfen[i]
            out[#out + 1] = ("    #%d %s - %s"):format(v.nr, v.id, v.grund)
        end
    end
    return out
end
