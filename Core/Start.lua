-- Core/Start.lua — Ladefolge: SavedVariables, Gestalt, Sprachpaket, Login-Gruss.
-- DESIGN-V2 6.3/7: Beim ALLERERSTEN Login (LyraGestaltDB.account.eingerichtet fehlt/false) kommt
-- statt des LOGIN-Grusses nach 3 s der Erst-Start-Assistent - vier Fragen im vorhandenen
-- Gespraechsbaum (dialog.lua, Knoten setup_*), kein blockierendes Popup. Danach: Minimap-Knopf
-- pulst dreimal, dann der normale LOGIN-Gruss.
local ADDON, ns = ...

-- DESIGN-V3 B-11 / G1 (17.09.2026): Der Assistent hing immer an "eingerichtet == false". Wer von
-- 0.2 kommt, hat die Datenbank schon - und hat ihn nie gesehen. Fuer genau diese Bestandsnutzer
-- gibt es ab 0.6.2 EINE Blasenzeile nach dem Login-Gruss, kein Popup, kein zweiter Versuch,
-- kein Zaehler. Wer sie ignoriert, hat sie ignoriert.
ns.ASSISTENT_NACH = 3     -- s nach dem Ladebildschirm
ns.ASSISTENT_MAX = 3      -- so oft wird der Assistent hoechstens angeboten, dann nie wieder
ns.GRUSS_NACH = 6         -- s, wie bisher
ns.EINLADUNG_NACH = 8     -- s NACH dem Login-Gruss (design-v3 g)

ns.on("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    -- Die Erkennung muss VOR ns.initDB() laufen: defaults() fuellt "eingerichtet" mit false auf,
    -- danach ist ein Bestandsnutzer von einer Neuinstallation nicht mehr zu unterscheiden.
    -- Bestandsnutzer = es gibt schon einen account-Block UND Charakterdaten, aber der Schluessel
    -- "eingerichtet" fehlt (den kannte 0.2 noch nicht).
    local db = LyraGestaltDB
    ns.bestandsnutzer = false
    if type(db) == "table" and type(db.account) == "table" and db.account.eingerichtet == nil
        and type(db.chars) == "table" and next(db.chars) ~= nil then
        ns.bestandsnutzer = true
    end
    ns.initDB()
    math.randomseed(math.floor(GetTime() * 1000))
end)
ns.on("PLAYER_LOGIN", function()
    if not ns.db then ns.initDB() end   -- REVIEW: Sicherheitsnetz, falls ADDON_LOADED verpasst wurde
    ns.sexCache = nil
    ns.Gestalt.start()
    ns.Blase.layout()
    if ns.Get("stimme") then ns.Stimme.paketLaden(ns.sprache()) end
    if ns.Settings and ns.Settings.start then ns.Settings.start() end
    ns.print(ns.VERSION .. " " .. ns.L["Loaded"])
end)

-- Assistent starten (auch ueber /lyra einrichten und den Panel-Knopf)
local assistentLaeuft = false
function ns.starteAssistent()
    if not (ns.Dialog and ns.Dialog.oeffne) then ns.print(ns.L["Dialog missing"]); return false end
    local ok = ns.Dialog.oeffne("setup_sprache")
    assistentLaeuft = ok and true or false
    return ok
end

-- Abbruch (ESC, Ausblenden, Klick daneben): nichts ist gesetzt, aber der Gruss soll trotzdem kommen -
-- sonst bleibt die Sitzung stumm, nur weil jemand das Fenster weggeklickt hat. Gefragt wird noch
-- hoechstens zweimal (setupGefragt), danach nie wieder - Nachfragen sind der Nervfaktor Nummer eins.
if ns.Dialog and ns.Dialog.frame and ns.Dialog.frame.HookScript then
    pcall(ns.Dialog.frame.HookScript, ns.Dialog.frame, "OnHide", function()
        if not assistentLaeuft then return end
        assistentLaeuft = false
        if ns.Get("eingerichtet") then return end   -- sauber zu Ende gegangen
        ns.Compat.After(1, function() if not ns.loginUnterdruecken then ns.melde("LOGIN") end end)
    end)
end

-- Vom letzten Assistenten-Knopf gerufen (UI/Dialog.lua, D.aktionen.setupFertig)
function ns.assistentFertig()
    assistentLaeuft = false
    if ns.Minimap and ns.Minimap.pulse then
        ns.Compat.After(1, function() pcall(ns.Minimap.pulse, 3) end)
    end
    -- Der LOGIN-Gruss wurde fuer den Assistenten uebersprungen: jetzt nachholen, sobald das
    -- Assistenten-Fenster zu ist (ENDE_DAUER = 4 s in UI/Dialog.lua).
    ns.Compat.After(5, function()
        if ns.loginUnterdruecken then return end
        if ns.Regie then ns.Regie.zuletztPlauder = 0 end
        if ns.melde then ns.melde("LOGIN") end
    end)
end

-- B-11: die eine Zeile. Sie geht ueber ns.Dialog.sage (Blase + Miene; ist Lyra ausgeblendet,
-- landet sie im lokalen Chat-Frame - nie SendChatMessage). Danach pulst der Minimap-Knopf dreimal
-- (Alpha, kein Scale) - "ich bin auch hier", ohne ein weiteres Wort.
-- Das Flag wird erst gesetzt, wenn die Zeile wirklich rausgeht: wer vorher ausloggt, bekommt sie
-- beim naechsten Mal. Genau einmal heisst genau einmal, nicht hoechstens einmal.
function ns.einladungZeigen()
    if ns.Get("einladungGezeigt") then return false end
    local txt = ns.L["Invite setup"]
    if not txt or txt == "" then return false end
    ns.Set("einladungGezeigt", true)
    if ns.Dialog and ns.Dialog.sage then ns.Dialog.sage(txt, "interested", 12)
    elseif ns.Blase and ns.Blase.zeige and not ns.Get("versteckt") then ns.Blase.zeige(txt, 12)
    else ns.print(txt) end
    if ns.Minimap and ns.Minimap.pulse then pcall(ns.Minimap.pulse, 3) end
    return true
end

local erster = true
ns.on("PLAYER_ENTERING_WORLD", function()
    if not erster then return end
    erster = false
    -- Bestandsnutzer: KEIN Assistent (sie haben eine eingerichtete Datenbank und wuerden ein
    -- Fragefenster beim Login als Fehler lesen), sondern die eine Einladung nach dem Gruss.
    if ns.bestandsnutzer and not ns.Get("einladungGezeigt") then
        ns.Set("eingerichtet", true)
        ns.Compat.After(ns.GRUSS_NACH, function() if not ns.loginUnterdruecken then ns.melde("LOGIN") end end)
        ns.Compat.After(ns.GRUSS_NACH + ns.EINLADUNG_NACH, function() ns.einladungZeigen() end)
        return
    end
    if not ns.Get("eingerichtet") then
        local n = tonumber(ns.Get("setupGefragt")) or 0
        if n < ns.ASSISTENT_MAX then
            ns.Set("setupGefragt", n + 1)
            ns.Compat.After(ns.ASSISTENT_NACH, function()
                if ns.Get("eingerichtet") then return end   -- inzwischen von Hand erledigt
                ns.starteAssistent()
            end)
            return
        end
        ns.Set("eingerichtet", true)   -- dreimal angeboten reicht; ab jetzt nur noch /lyra einrichten
    end
    ns.Compat.After(ns.GRUSS_NACH, function() if not ns.loginUnterdruecken then ns.melde("LOGIN") end end)
end)
