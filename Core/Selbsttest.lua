-- W8: Core/Selbsttest.lua — Patch-Tag-Bereitschaft (Roadmap 9-2 / A9).
--
-- WARUM ES DIESE DATEI GIBT
-- -------------------------
-- Ein Addon, das an zwanzig API-Flaechen haengt, bricht am Patch-Tag nicht *ganz*, sondern an
-- EINER Stelle - und zeigt dem Spieler dann einen Lua-Fehler mit Lyras Namen darin. Der
-- Beta-Befund vom 19.09.2026 ("SavedVariables never load in the beta - all addon settings reset
-- on login", WoW: Forever) ist genau dieser Fall: nicht kaputt, sondern EIN Stueck weg.
--
-- Der Selbsttest fragt beim Laden und beim Login die Flaechen ab, an denen Lyra wirklich haengt,
-- schaltet den betroffenen Sinn ab und sagt EINE ehrliche Zeile im Chat. Keine Fehlermeldung,
-- kein Totalausfall, kein Schweigen.
--
-- WARUM SIE DIREKT HINTER Core/Compat.lua STEHT
-- ---------------------------------------------
-- Weil die teuerste Entscheidung eine REGISTRIERUNG ist und die beim LADEN faellt. Sinne/Chronik.lua
-- registriert COMBAT_LOG_EVENT_UNFILTERED auf Dateiebene; auf einem Client, der das nicht mehr
-- erlaubt, feuert schon der Versuch ADDON_ACTION_FORBIDDEN - und das faengt kein pcall, das ist
-- ein Blizzard-Fenster mit unserem Namen darin. Ein Selbsttest, der erst bei PLAYER_LOGIN laeuft,
-- kommt dafuer eine Sekunde zu spaet.
--
-- Der Preis dieser Position: hier gibt es NOCH KEIN ns.print, ns.debug, ns.Get, ns.L, ns.on.
-- Die kommen alle aus Core/Init.lua bzw. Core/Locale.lua, und die stehen dahinter. Diese Datei
-- benutzt darum beim Laden ausschliesslich ns.Compat und rohe WoW-Globale, haengt sich mit einem
-- EIGENEN Frame an PLAYER_LOGIN (nicht ueber ns.on) und rechnet erst dort mit ns.*.
--
-- ZWEI PHASEN
-- -----------
--   "laden"  Flaechen, an denen eine REGISTRIERUNG haengt. Ergebnis steht, bevor die erste
--            Sinne-Datei geladen wird. Die Sinne fragen ns.Selbsttest.ok("<flaeche>").
--   "login"  Flaechen, die erst in der Welt eine Antwort haben (Leben lesbar? Karte da? Ton?).
--            Ergebnis steht bei PLAYER_LOGIN; die Sinne fragen zur Laufzeit.
--
-- HART UND WEICH
-- --------------
--   hart   der betroffene Sinn wird abgeschaltet und steht in der Chat-Zeile.
--   weich  nur Befund. Entweder faengt der Sinn den Ausfall schon selbst ab (Sinne/Alltag.lua
--          pcallt jeden Taschen-Zugriff seit Welle 1), oder es gibt gar nichts abzuschalten
--          (TOC-Nummer). Ein weicher Befund steht in /lyra status und sonst nirgends - eine
--          Chat-Zeile fuer etwas, das ohnehin funktioniert, ist Laerm.
--
-- UND DIE DRITTE LAGE: "normal"
-- ----------------------------
-- Eine Flaeche kann fehlen, ohne dass etwas kaputt ist. Der Combat-Log ist auf Retail und
-- Forever fuer Addons zu - das ist kein Patch-Schaden, das ist der dokumentierte Zustand dieses
-- Clients (Core/Compat.lua C.F.combatLog). Eine Probe darf darum ein drittes Ergebnis liefern:
-- nicht benutzbar, aber ERWARTET. Dann gilt weiterhin ST.ok() == false (der Sinn registriert
-- nichts, genau wie bisher), aber es gibt KEINE Chat-Zeile. Ohne diese Lage haette jeder
-- Retail-Login "Patch erkannt - Kampfsinne aus" gemeldet, und eine Warnung, die immer kommt,
-- liest nach drei Tagen niemand mehr.
--
-- API (nur lesend): GetBuildInfo, CreateFrame, C_AddOns.GetAddOnMetadata, CombatLogGetCurrentEventInfo,
--   C_Container/GetContainerNumSlots, UnitHealth/UnitHealthMax (ueber ns.Compat), C_Map,
--   PlaySoundFile, Settings, LibStub. Nichts Fremdes, kein Schreibzugriff, kein Netz.
-- KONTRAKT: kein SendChatMessage, keine geschuetzte Funktion, alles Fremde in pcall.
local ADDON, ns = ...
local ST = {}
ns.Selbsttest = ST

local C = ns.Compat

ST.ergebnis = {}        -- [key] = { ok = bool, grund = "...", phase = "laden"|"login", hart = bool }
ST.gelaufen = { laden = false, login = false }
ST.gemeldet = false     -- die EINE Chat-Zeile ist raus
ST.zeileText = nil      -- was drinstand (fuer /lyra selbsttest und den Pruefstand)

-- Namen der Sinne, in beiden Sprachen. ns.L gibt es beim Laden noch nicht, und eine Zeile,
-- die dem Spieler erklaert, was ausgefallen ist, darf nicht an der Ladereihenfolge haengen.
local NAME = {
    cleu      = { de = "Kampfsinne",     en = "combat senses" },
    leben     = { de = "Lebenswarnung",  en = "health warnings" },
    karte     = { de = "Ortssinn",       en = "location sense" },
    hbd       = { de = "Kartenpunkte",   en = "map pins" },
    ton       = { de = "Toene",          en = "sounds" },
    taschen   = { de = "Taschen",        en = "bags" },
    settings  = { de = "Einstellungsseite", en = "settings page" },
    toc       = { de = "TOC-Nummer",     en = "TOC number" },
}

local function de()
    -- ns.sprache() gibt es erst nach Core/Init.lua. Vor dem Login (Fehlerfall) reicht GetLocale.
    if ns.sprache then
        local ok, s = pcall(ns.sprache)
        if ok then return s == "de" end
    end
    return (type(GetLocale) == "function" and GetLocale() == "deDE") and true or false
end
local function name(key)
    local n = NAME[key]
    if not n then return tostring(key) end
    return de() and n.de or n.en
end
ST.name = name

-- ---------------------------------------------------------------------------------------------
-- Die Flaechen
-- ---------------------------------------------------------------------------------------------
-- Jede Probe gibt zurueck: ok (bool), grund (string), normal (bool, optional - "fehlt, aber so
-- ist dieser Client gebaut"). Sie WIRFT NIE - das ist die eine Regel, an der ein Selbsttest
-- sonst selbst zum Fehler wird. Deshalb laeuft jede Probe in pcall, und wirft sie trotzdem,
-- gilt die Flaeche als ausgefallen (mit dem Fehlertext als Grund).
ST.FLAECHEN = {
    -- 1 Combat-Log. Die teuerste Flaeche: hier haengt eine REGISTRIERUNG dran.
    { key = "cleu", phase = "laden", hart = true, pruef = function()
        if not (C and C.F) then return false, "kein Compat" end
        if not C.F.combatLog then
            -- Auf Retail und Forever ist das der VORGESEHENE Zustand, kein Ausfall: Blizzard hat
            -- COMBAT_LOG_EVENT_UNFILTERED fuer Addons zugemacht, und Sinne/Chronik.lua hat dafuer
            -- seit 0.9.0 einen eigenen Ersatzpfad. Kein Grund, jemanden damit zu behelligen.
            if C.istMainlineArtig then
                return false, "auf " .. tostring(C.profil) .. " fuer Addons zu (vorgesehen)", true
            end
            return false, "Client sperrt den Combat-Log (" .. tostring(C.profil) .. ")"
        end
        if type(CombatLogGetCurrentEventInfo) ~= "function" then
            return false, "CombatLogGetCurrentEventInfo fehlt"
        end
        -- Der eigentliche Test: laesst sich das Ereignis ueberhaupt registrieren? Er laeuft NUR,
        -- wenn C.F.combatLog schon ja gesagt hat - auf einem Mainline-Client waere genau dieser
        -- Versuch der Fehler, den wir vermeiden wollen.
        if type(CreateFrame) ~= "function" then return true, "CreateFrame fehlt (ungeprueft)" end
        local ok, f = pcall(CreateFrame, "Frame")
        if not ok or type(f) ~= "table" then return true, "kein Probe-Frame (ungeprueft)" end
        local ok2, err = pcall(f.RegisterEvent, f, "COMBAT_LOG_EVENT_UNFILTERED")
        if not ok2 then return false, "RegisterEvent wirft: " .. tostring(err) end
        pcall(f.UnregisterAllEvents, f)
        return true, "registrierbar"
    end },

    -- 2 Taschen. Weich: Sinne/Alltag.lua pcallt jeden Zugriff seit Welle 1, ein Ausfall ist dort
    --   still. Der Selbsttest macht ihn SICHTBAR - das ist der ganze Zweck.
    { key = "taschen", phase = "laden", hart = false, pruef = function()
        local K = C and C.Container
        if type(K) ~= "table" or type(K.GetContainerNumSlots) ~= "function" then
            return false, "weder C_Container noch GetContainerNumSlots"
        end
        local ok, n = pcall(K.GetContainerNumSlots, 0)
        if not ok then return false, "GetContainerNumSlots wirft" end
        if type(n) ~= "number" then return false, "GetContainerNumSlots gibt keine Zahl" end
        if type(K.GetContainerItemInfo) ~= "function" then
            return false, "GetContainerItemInfo fehlt"
        end
        local ok2 = pcall(K.GetContainerItemInfo, 0, 1)
        if not ok2 then return false, "GetContainerItemInfo wirft" end
        return true, (C.F and C.F.container or "?")
    end },

    -- 3 Einstellungsseite. Weich: UI/Settings.lua hat seit 0.6 einen Rueckfall auf die alte
    --   Panel-API und faellt sonst auf /lyra zurueck. Niemand verliert einen Sinn.
    { key = "settings", phase = "laden", hart = false, pruef = function()
        if not (C and C.F and C.F.settingsApi) then
            return false, "Settings-API unvollstaendig - Rueckfall auf die alte Optionsseite"
        end
        return true, "Settings-API"
    end },

    -- 4 TOC-Nummer gegen Client. Weich, und zwar mit Absicht: die suffixlose Lyra_Gestalt.toc ist
    --   der dokumentierte RUECKFALL fuer unbekannte Clients (WoW: Forever laedt sie heute mit
    --   11509 gegen 16001). Das ist ein bekannter Zustand, kein Ausfall - aber er gehoert in
    --   jeden Bugreport, weil er genau der Stand ist, an dem ein Patch-Tag sichtbar wird.
    { key = "toc", phase = "laden", hart = false, pruef = function()
        local client = C and tonumber(C.version) or nil
        local toc = nil
        local hol = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        if hol then
            local ok, v = pcall(hol, ADDON, "Interface")
            if ok then toc = tonumber(v) end
        end
        if not (client and toc) then return true, "nicht ablesbar" end
        ST.tocNummer, ST.clientNummer = toc, client
        if toc == client then return true, tostring(toc) end
        return false, ("TOC %d, Client %d"):format(toc, client)
    end },

    -- 5 Leben lesbar. Der Kern des Addons. Blizzard sagt zu, dass die Werte des SPIELERS auf
    --   jedem Client lesbar bleiben (auch unter Secret Values) - genau diese Zusage wird hier
    --   nachgemessen statt geglaubt.
    { key = "leben", phase = "login", hart = true, pruef = function()
        if not (C and C.unitHealthLesbar) then return false, "kein Compat" end
        local cur, max = C.unitHealthLesbar("player")
        if not (cur and max) then return false, "UnitHealth('player') ist nicht rechenbar" end
        if max <= 0 then return false, "UnitHealthMax = 0" end
        return true, ("%d/%d"):format(cur, max)
    end },

    -- 6 Karte. Der Ortssinn (Zone, Geofence, Vorwarnung) haengt daran. KEINE Position zu bekommen
    --   ist in einer Instanz die richtige Antwort und kein Ausfall - geprueft wird darum, ob die
    --   Funktionen da sind und ob sie ohne Fehler antworten.
    { key = "karte", phase = "login", hart = true, pruef = function()
        if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
            return false, "C_Map fehlt"
        end
        local ok, karte = pcall(C_Map.GetBestMapForUnit, "player")
        if not ok then return false, "GetBestMapForUnit wirft" end
        if not karte then return true, "keine Karte (Instanz?)" end
        local ok2, pos = pcall(C_Map.GetPlayerMapPosition, karte, "player")
        if not ok2 then return false, "GetPlayerMapPosition wirft" end
        if pos == nil then return true, "Karte " .. tostring(karte) .. ", keine Position" end
        local x, y
        if type(pos) == "table" and pos.GetXY then
            local ok3, a, b = pcall(pos.GetXY, pos)
            if ok3 then x, y = a, b end
        elseif type(pos) == "table" then
            x, y = pos.x, pos.y
        end
        if type(x) ~= "number" or type(y) ~= "number" then
            return false, "GetPlayerMapPosition gibt kein x/y"
        end
        return true, ("Karte %s"):format(tostring(karte))
    end },

    -- 7 Ton. PlaySoundFile gibt im echten Client "willPlay, soundHandle" zurueck, und Lyra haengt
    --   ZWEI Dinge daran: StopSound (Gestalt/Stimme.lua S.handle) und den Riegel, der den
    --   TTS-Rueckfall stumm haelt, waehrend eine Aufnahme laeuft (S.letzterErfolgT). Ein Client,
    --   der nichts zurueckgibt, laesst Lyra doppelt sprechen - das war am 20.09. im Pruefstand
    --   zu sehen, damals als Attrappen-Fehler. Geprobt wird mit einem Pfad, den es NICHT gibt:
    --   der Client antwortet mit willPlay = false und spielt garantiert nichts.
    { key = "ton", phase = "login", hart = true, pruef = function()
        if type(PlaySoundFile) ~= "function" then return false, "PlaySoundFile fehlt" end
        local pfad = (ns.PFAD or "Interface\\AddOns\\Lyra_Gestalt\\") .. "laute\\__selbsttest.ogg"
        local ok, will, handle = pcall(PlaySoundFile, pfad, "Master")
        if not ok then return false, "PlaySoundFile wirft" end
        ST.tonRueckgabe = tostring(will)
        if will == nil then
            return false, "PlaySoundFile gibt nichts zurueck - StopSound und TTS-Riegel blind"
        end
        if will and handle and StopSound then pcall(StopSound, handle) end
        return true, "willPlay=" .. tostring(will)
    end },

    -- 8 HereBeDragons. Yard-Rechnung, Kartenpunkte, PUNKT_NAH und die Welle-8-Vorwarnung haengen
    --   daran. Die Bibliothek ist eingebettet, aber LibStub laesst die HOEHERE Revision gewinnen -
    --   es kann also die eines fremden Addons sein, und die kann fuer diesen Client leere
    --   Kartendaten haben. Dann ist jede Yard-Zahl geraten.
    { key = "hbd", phase = "login", hart = true, pruef = function()
        if type(LibStub) ~= "function" and type(LibStub) ~= "table" then
            return false, "kein LibStub"
        end
        local ok, lib = pcall(LibStub, "HereBeDragons-2.0", true)
        if not ok or type(lib) ~= "table" or type(lib.GetZoneSize) ~= "function" then
            return false, "HereBeDragons-2.0 nicht da"
        end
        -- 37 Wald von Elwynn, 1519 Sturmwind, 1411 Durotar - auf allen fuenf Clients dieselben IDs.
        for _, id in ipairs({ 37, 1519, 1411 }) do
            local ok2, w = pcall(lib.GetZoneSize, lib, id)
            if ok2 and type(w) == "number" and w > 0 then
                return true, ("Zonengroessen da (%d yd)"):format(math.floor(w))
            end
        end
        return false, "HereBeDragons kennt keine Zonengroessen"
    end },
}

-- ---------------------------------------------------------------------------------------------
-- Laufen lassen
-- ---------------------------------------------------------------------------------------------
local function einePruefen(f)
    local ok, a, b, c = pcall(f.pruef)
    if not ok then
        ST.ergebnis[f.key] = { ok = false, grund = "Probe wirft: " .. tostring(a),
                               phase = f.phase, hart = f.hart, normal = false }
        return
    end
    ST.ergebnis[f.key] = { ok = (a and true or false), grund = tostring(b or ""),
                           phase = f.phase, hart = f.hart, normal = (c and true or false) }
end

function ST.laufen(phase)
    for _, f in ipairs(ST.FLAECHEN) do
        if f.phase == phase then einePruefen(f) end
    end
    ST.gelaufen[phase] = true
end

-- Die Frage, die jeder Sinn stellt. FAIL-SAFE: eine Flaeche, die noch nicht geprueft wurde,
-- gilt als in Ordnung. Ein Selbsttest, der aus Unwissen abschaltet, waere schlimmer als der
-- Ausfall, vor dem er schuetzen soll.
function ST.ok(key)
    local e = ST.ergebnis[key]
    if not e then return true end
    return e.ok
end

function ST.grund(key)
    local e = ST.ergebnis[key]
    return e and e.grund or nil
end

-- Liste der Ausfaelle. nurHart = true -> nur die, die einen Sinn gekostet haben.
-- "normal" (fehlt, aber so ist dieser Client gebaut) zaehlt NIE als Ausfall - das ist genau die
-- Lage, in der ein Selbsttest sonst zum Dauerlaerm wird.
function ST.ausfaelle(nurHart)
    local out = {}
    for _, f in ipairs(ST.FLAECHEN) do
        local e = ST.ergebnis[f.key]
        if e and not e.ok and not e.normal and (not nurHart or f.hart) then
            out[#out + 1] = { key = f.key, grund = e.grund, hart = f.hart }
        end
    end
    return out
end

-- Flaechen, die auf diesem Client vorgesehen fehlen. Nur fuer /lyra selbsttest.
function ST.vorgesehen()
    local out = {}
    for _, f in ipairs(ST.FLAECHEN) do
        local e = ST.ergebnis[f.key]
        if e and not e.ok and e.normal then out[#out + 1] = { key = f.key, grund = e.grund } end
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- Die EINE Zeile
-- ---------------------------------------------------------------------------------------------
-- Sie kommt nicht ueber die Regie. Begruendung wie bei /lyra status (companion-v3 E): das ist
-- eine Auskunft ueber das Addon, keine Zeile von Lyra - sie hat keine Miene, keine Stimme und
-- keinen Platz im Budget. Sie kommt genau EINMAL je Sitzung und nur, wenn etwas HARTES fehlt.
function ST.zeile()
    local harte = ST.ausfaelle(true)
    if #harte == 0 then return nil end
    local teile = {}
    for _, a in ipairs(harte) do teile[#teile + 1] = name(a.key) end
    local liste = table.concat(teile, ", ")
    if de() then
        return ("Patch erkannt - %s aus, der Rest laeuft. /lyra selbsttest sagt, was fehlt."):format(liste)
    end
    return ("Patch detected - %s off, everything else runs. /lyra selbsttest says what is missing."):format(liste)
end

function ST.melden()
    if ST.gemeldet then return false end
    local z = ST.zeile()
    ST.gemeldet = true
    ST.zeileText = z
    if not z then return false end
    if ns.print then ns.print(z) end
    return true
end

-- ---------------------------------------------------------------------------------------------
-- /lyra status und /lyra selbsttest
-- ---------------------------------------------------------------------------------------------
local function jaNein(b)
    if ns.L then return b and ns.L["yes"] or ns.L["no"] end
    return b and "ja" or "nein"
end

function ST.status()
    local harte, weiche = ST.ausfaelle(true), {}
    for _, a in ipairs(ST.ausfaelle(false)) do if not a.hart then weiche[#weiche + 1] = a end end
    local z = {}
    if #harte == 0 and #weiche == 0 then
        local vor = #ST.vorgesehen()
        z[1] = (de() and "Selbsttest: alle %d Flaechen in Ordnung%s."
                      or "Self-test: all %d surfaces fine%s."
               ):format(#ST.FLAECHEN,
                        vor > 0 and ((de() and " (%d auf diesem Client vorgesehen aus)"
                                            or " (%d switched off by design on this client)"):format(vor)) or "")
        return z
    end
    local teile = {}
    for _, a in ipairs(harte) do teile[#teile + 1] = name(a.key) .. " (" .. a.grund .. ")" end
    if #harte > 0 then
        z[#z + 1] = (de() and "Selbsttest: AUS - " or "Self-test: OFF - ") .. table.concat(teile, "; ")
    end
    local t2 = {}
    for _, a in ipairs(weiche) do t2[#t2 + 1] = name(a.key) .. " (" .. a.grund .. ")" end
    if #t2 > 0 then
        z[#z + 1] = (de() and "Selbsttest: Hinweis - " or "Self-test: note - ") .. table.concat(t2, "; ")
    end
    return z
end

-- Der lange Bericht fuer den Bugreport. Jede Flaeche, eine Zeile, mit Grund.
function ST.bericht()
    local z = {}
    z[#z + 1] = (de() and "Selbsttest " or "Self-test ") .. tostring(ns.VERSION or "?")
        .. " - " .. tostring(C and C.profil or "?") .. " " .. tostring(C and C.version or "?")
    for _, f in ipairs(ST.FLAECHEN) do
        local e = ST.ergebnis[f.key]
        local marke = "?"
        if e then
            if e.ok then marke = "ok"
            elseif e.normal then marke = "--"      -- vorgesehen aus, kein Befund
            elseif f.hart then marke = "AUS"
            else marke = "!" end
        end
        z[#z + 1] = ("  [%s] %-9s %s"):format(marke, f.key, e and e.grund or "-")
    end
    if ST.zeileText then z[#z + 1] = "  -> " .. ST.zeileText end
    return z
end

-- ---------------------------------------------------------------------------------------------
-- Phase 1 laeuft SOFORT. Der eigene Frame haengt an PLAYER_LOGIN - ns.on gibt es hier noch nicht,
-- und auf die Reihenfolge zweier Frames verlassen wir uns bewusst nicht: diese Zeile kommt aus
-- ihrem eigenen Frame und ist damit von Core/Init.lua unabhaengig.
-- ---------------------------------------------------------------------------------------------
ST.laufen("laden")

do
    local ok, f = pcall(CreateFrame, "Frame")
    if ok and type(f) == "table" and f.RegisterEvent then
        ST.frame = f
        pcall(f.RegisterEvent, f, "PLAYER_LOGIN")
        f:SetScript("OnEvent", function()
            local ok2, err = pcall(function()
                ST.laufen("login")
                ST.melden()
            end)
            if not ok2 and ns.debug then ns.debug("Selbsttest: " .. tostring(err)) end
        end)
    end
end
