-- Sinne/Umwelt.lua — Ortssinn und Umgebung: Zone, Atem, Erschoepfung, Rast, Taxi, Geofence.
-- Ereignisse: ZONE, ATEM30, ATEM10, ERSCHOEPFUNG, MUEDE, RAST_AN, TAXI_START, TAXI_ENDE, GEOFENCE.
-- API (nur lesend): GetRealZoneText/GetZoneText, GetMirrorTimerProgress/GetMirrorTimerInfo,
--   IsResting, GetXPExhaustion/GetRestState, UnitOnTaxi, TaxiNodeName (Post-Hook auf
--   TakeTaxiNode, nicht protected),
--   C_Map.GetBestMapForUnit/GetPlayerMapPosition, UnitAffectingCombat, UnitIsDeadOrGhost, GetTime.
-- Events: ZONE_CHANGED_NEW_AREA, MIRROR_TIMER_START/STOP, PLAYER_UPDATE_RESTING,
--   PLAYER_XP_UPDATE, UPDATE_EXHAUSTION, PLAYER_CONTROL_LOST/GAINED, PLAYER_ENTERING_WORLD.
-- Takt: ein 3-s-Ticker (Geofence + Flug-Flanken), eine 2-s-Tick-Kette NUR waehrend eines
--   Atem-/Erschoepfungs-Timers. Kein OnUpdate.
-- Grenzen: Instanzen liefern keine Kartenposition (Geofence still); Gefahren-Tabelle
--   ns.Gefahren ist in Phase 1 leer (siehe Sinne/Gefahren_Beispiel.lua); TAXI_START ohne
--   Ziel, wenn der Hook den Klick verpasst; Taxi-Ende wird ueber den 3-s-Ticker abgesichert.
-- Portiert aus LyraAuge zoneMarker/atemTick/muedeTick/rastMarker/flugBeginn/flugSchluss/gefahrPuls.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local U = {}
ns.Sinne.Umwelt = U

-- Gefahren-Stellen (Phase 2 fuellt sie): [mapID] = { {x=0.xx, y=0.yy, r=0.02, art="sturz|wasser", key="..."} }
ns.Gefahren = ns.Gefahren or {}

local function jetzt() return GetTime() end
local function tot() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false end
local function imKampf() return UnitAffectingCombat and UnitAffectingCombat("player") or false end
local function aufTaxi() return UnitOnTaxi and UnitOnTaxi("player") or false end

-- ---------------------------------------------------------------- ZONE
local letzteZone = nil          -- nil = Basislinie noch nicht gesetzt
local zoneBereit = false        -- erst nach dem Login-Ladebildschirm melden

local function zoneJetzt()
    local z = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
    return z
end

local function pruefeZone()
    local z = zoneJetzt()
    if z == "" then return end
    if not zoneBereit then letzteZone = z; return end       -- Login: still merken
    if z == letzteZone then return end
    -- FIX 0.19.1 (Spieltest Harald 22.09.): AUF DEM TAXI keine Zonenzeile. Ein Flug ueber vier
    -- Zonen brachte vier ZONE-Zeilen, jede setzte den Plauder-Abstand neu, und die Flugdauer
    -- (Sinne/Welle14b.lua) fiel mit "abstand" durch - dabei war sie die einzige Zeile, die zum
    -- Flug gehoert. Regel 1 (Recherche 18): den Zonennamen blendet der Client beim Ueberfliegen
    -- ohnehin ein. letzteZone bleibt UNVERAENDERT, damit die Zielzone nach der Landung ihre
    -- Zeile (und die W15-Erinnerungskette) bekommt: U.flugFlanken stoesst pruefeZone dann an.
    if aufTaxi() then return end
    -- Ladebildschirm der Regie noch aktiv (Portal, Schiff, Instanz): spaeter noch einmal.
    local riegel = ns.Regie and ns.Regie.ladeRiegelBis or 0
    if jetzt() < riegel then
        -- Nur mit echtem Timer nachlegen (der Compat-Fallback ruft sofort auf -> Endlosschleife).
        if C_Timer and C_Timer.After then ns.Compat.After(riegel - jetzt() + 0.5, pruefeZone) end
        return
    end
    letzteZone = z
    ns.melde("ZONE", { zone = z, key = z })
end

ns.on("ZONE_CHANGED_NEW_AREA", function()
    ns.Compat.After(1, pruefeZone)
end)

-- ---------------------------------------------------------------- ATEM / MUEDE
-- Spiegel-Timer: Rest in ms. GetMirrorTimerProgress(name) ist der direkte Weg;
-- Fallback ueber GetMirrorTimerInfo(1..3).
local function timerRest(name)
    if GetMirrorTimerProgress then
        local ok, ms = pcall(GetMirrorTimerProgress, name)
        if ok and type(ms) == "number" then return ms end
    end
    if GetMirrorTimerInfo then
        for i = 1, 3 do
            local ok, t, v = pcall(GetMirrorTimerInfo, i)
            if ok and t == name then return tonumber(v) or 0 end
        end
    end
    return 0
end

-- Atem: Tick-Kette NUR waehrend des BREATH-Timers. Re-Arm je Tauchgang.
local atem = { aktiv = false, ticker = nil, a30 = true, a10 = true }

local function atemStop()
    atem.aktiv = false
    if atem.ticker then atem.ticker:Cancel(); atem.ticker = nil end
end

local function atemTick()
    if not atem.aktiv then atemStop(); return end
    if tot() then return end
    local s = math.floor(timerRest("BREATH") / 1000)
    if s > 0 then
        if s <= 10 and atem.a10 then
            atem.a10 = false; atem.a30 = false
            ns.melde("ATEM10")
        elseif s <= 30 and atem.a30 then
            atem.a30 = false
            ns.melde("ATEM30")
        end
    end
end

local function atemStart()
    atem.aktiv = true
    atem.a30, atem.a10 = true, true
    if not atem.ticker then
        atem.ticker = ns.Compat.NewTicker(2, atemTick)
    end
end

-- =============================================================================================
-- ERSCHOEPFUNG (W11B-1) — und warum hier bis 0.14.0 das falsche Ereignis stand.
-- =============================================================================================
-- Der EXHAUSTION-Timer laeuft, sobald man im offenen Meer ist. Flanke am Start, eine Meldung je
-- Schwimmgang. Zwilling der Atem-Wache, aber ohne Tick-Kette: die Warnung ist beim Start am
-- meisten wert (Umkehren ist noch moeglich).
--
-- DER BEFUND (docs/abgleich-claudebuddy-2026-09-20.md §4.2, sicherheitsrelevant):
-- Dieser Handler war richtig verdrahtet und meldete das FALSCHE Ereignis. Er meldete MUEDE -
-- und MUEDE ist im Katalog der AUSGERUHT-BONUS: "Du bist müde. Ich auch. Einer von uns sollte
-- ins Gasthaus." · "Kein Ausgeruht-Bonus mehr." Ein Spieler, der beim Erscheinen des
-- Erschoepfungsbalkens "Gasthaus" hoert, dreht nicht um. Er taucht auf. Auftauchen hilft bei
-- Erschoepfung nicht - bei Erschoepfung muss man UMKEHREN, und Ertrinken ist Todesursache
-- Nr. 8 in Classic Hardcore.
-- Dazu kam die Klasse: MUEDE ist "plauder". Es wurde also im Kampf zurueckgehalten, in der
-- Gruppe verworfen und im Still-Modus geschluckt, waehrend der Charakter im offenen Meer trieb.
--
-- JETZT: ein eigenes Ereignis ERSCHOEPFUNG, Klasse "warn", Stufe 2 (docs/phrasen-w11b.json).
-- Damit laeuft es an Gruppen-Schweigen, Still-Modus und Kampf-Riegel vorbei, bekommt den
-- Bildschirmpuls der Stufe 2 (UI/Glow.lua haengt generisch an e.stufe) und sagt "kehr um".
-- Stufe 2 und nicht 3: der Balken laeuft ueber eine Minute, es ist eine Warnung und kein Alarm -
-- Stufe 3 sind die drei Faelle, in denen es um Sekunden geht (HP20, STURZ, ATEM10).
-- TIEFES_WASSER (Sinne/Welle8.lua) deckt einen verwandten, aber anderen Fall ab - tiefes Wasser
-- mit halbem Atem ueber einer Ertrinken-Zelle - und ersetzt diese Warnung nicht.
local erschoepfung = { aktiv = false, gemeldet = false }

local function erschoepfungStart()
    erschoepfung.aktiv = true
    if erschoepfung.gemeldet or tot() then return end
    erschoepfung.gemeldet = true
    ns.melde("ERSCHOEPFUNG")
end

local function erschoepfungStop()
    erschoepfung.aktiv = false
    erschoepfung.gemeldet = false
end

ns.on("MIRROR_TIMER_START", function(name)
    if name == "BREATH" then atemStart()
    elseif name == "EXHAUSTION" then erschoepfungStart() end
end)
ns.on("MIRROR_TIMER_STOP", function(name)
    if name == "BREATH" then atemStop()
    elseif name == "EXHAUSTION" then erschoepfungStop() end
end)

-- ---------------------------------------------------------------- MUEDE (Ausgeruht-Bonus)
-- MUEDE bleibt, was seine ZEILEN immer waren: die Bemerkung zum aufgebrauchten Ausgeruht-Bonus.
-- Es hatte bis heute nur keinen Auslöser dafuer - es hing am Erschoepfungs-Timer (siehe oben).
-- Geprueft und gefunden wurde der richtige: GetXPExhaustion() gibt die verbleibenden Bonus-EP
-- oder nil; UPDATE_EXHAUSTION und PLAYER_XP_UPDATE melden jede Aenderung. Die Flanke ist der
-- Uebergang "hatte Bonus" -> "kein Bonus mehr", und zwar nur ausserhalb der Rast: wer im
-- Gasthaus steht, BAUT den Bonus gerade auf und soll nicht ins Gasthaus geschickt werden.
--
-- Auf Stufe 60 (bzw. am Stufendeckel) gibt es keine Erfahrung mehr und GetXPExhaustion bleibt
-- dauerhaft nil - dann feuert die Flanke schlicht nie, und das ist richtig so.
-- Fehlt die API (Client ohne GetXPExhaustion), bleibt MUEDE stumm statt zu raten.
local ruhe = { hatte = nil }        -- nil = Basislinie noch nicht gesetzt

local function bonusRest()
    if not GetXPExhaustion then return nil end
    local ok, v = pcall(GetXPExhaustion)
    if not ok then return nil end
    return tonumber(v) or 0
end

local function pruefeBonus()
    local rest = bonusRest()
    if rest == nil then return end
    local hat = rest > 0
    if ruhe.hatte == nil then ruhe.hatte = hat; return end      -- Login: still merken
    if ruhe.hatte == hat then return end
    ruhe.hatte = hat
    if hat then return end                                      -- Bonus ist gewachsen: kein Anlass
    if IsResting and IsResting() then return end                -- im Gasthaus: er baut sich auf
    ns.melde("MUEDE")
end

ns.on("UPDATE_EXHAUSTION", pruefeBonus)
ns.on("PLAYER_XP_UPDATE", pruefeBonus)

-- ---------------------------------------------------------------- RAST
local letzteRast = nil          -- nil = Basislinie noch nicht gesetzt

local function pruefeRast()
    if not IsResting then return end
    local r = IsResting() and true or false
    if letzteRast == nil then letzteRast = r; return end     -- Login: still merken
    if r == letzteRast then return end
    letzteRast = r
    if r then ns.melde("RAST_AN") end
end

ns.on("PLAYER_UPDATE_RESTING", pruefeRast)

-- ---------------------------------------------------------------- TAXI
-- Post-Hook auf TakeTaxiNode (nicht protected) liest NUR den Knoten-Namen als Flugziel.
local flug = { drin = false, ziel = "", seit = 0 }

if hooksecurefunc and TaxiNodeName and TakeTaxiNode then
    pcall(hooksecurefunc, "TakeTaxiNode", function(idx)
        local ok, name = pcall(TaxiNodeName, idx)
        flug.ziel = (ok and type(name) == "string") and name or ""
        -- Der Flug beginnt kurz nach dem Klick; PLAYER_CONTROL_LOST kann VOR UnitOnTaxi feuern.
        ns.Compat.After(1, function() U.flugFlanken() end)
        ns.Compat.After(3, function() U.flugFlanken() end)
    end)
end

function U.flugFlanken()
    local taxi = aufTaxi()
    if taxi and not flug.drin then
        flug.drin = true
        flug.seit = jetzt()
        local vars = {}
        if flug.ziel ~= "" then vars.ziel = flug.ziel end
        ns.melde("TAXI_START", vars)
    elseif not taxi and flug.drin then
        -- W14B: Waehrend eines Ladebildschirms MITTEN IM FLUG (Kontinent-/Faehrgrenze) liefert
        -- UnitOnTaxi("player") FALSCH, obwohl der Spieler fliegt - InFlight kommentiert genau
        -- diese Stelle im eigenen Code mit "event bug fix". Bisher kostete uns das nur eine
        -- stumme TAXI_ENDE-Meldung (null Zeilen) und fiel niemandem auf; mit der Messung aus
        -- Sinne/Welle14b.lua daran waere daraus "Da waeren wir" mitten ueber dem Meer plus eine
        -- kaputte Messung geworden (Recherche 19 §3.1).
        -- Die Klammer PLAYER_LEAVING_WORLD/PLAYER_ENTERING_WORLD fuehrt Welle14b, nicht diese
        -- Datei - fehlt sie, ist das Verhalten exakt wie vorher.
        local W14 = ns.Welle14b
        if W14 and type(W14.imLadebildschirm) == "function" then
            local ok, drin = pcall(W14.imLadebildschirm)
            if ok and drin then return end
        end
        flug.drin = false
        flug.ziel = ""
        flug.seit = 0
        ns.melde("TAXI_ENDE")
        -- FIX 0.19.1: die Zielzone nachtragen (pruefeZone hat sie auf dem Taxi uebersprungen).
        -- Erst nach TAXI_LANDUNG (Welle14b, +1 s) und dem dann laufenden Plauder-Abstand - sonst
        -- faellt sie genau so durch wie vorher die Flugdauer.
        if C_Timer and C_Timer.After then
            ns.Compat.After(3, function()
                local rest = 0
                if ns.Regie and ns.Regie.abstandRest then
                    local ok, r = pcall(ns.Regie.abstandRest)
                    if ok and type(r) == "number" then rest = r end
                end
                ns.Compat.After(math.min(rest, 180) + 1, pruefeZone)
            end)
        end
    end
end

ns.on("PLAYER_CONTROL_LOST", function()
    U.flugFlanken()
    ns.Compat.After(1, U.flugFlanken)
end)
ns.on("PLAYER_CONTROL_GAINED", function()
    U.flugFlanken()
    ns.Compat.After(1, U.flugFlanken)
end)

-- ---------------------------------------------------------------- GEOFENCE
-- =============================================================================================
-- W11B-3: DEIN EIGENER PUNKT SCHLAEGT JEDE STATISTIK.
-- =============================================================================================
-- Befund docs/abgleich-claudebuddy-2026-09-20.md §4.3. ClaudeBuddy hatte beim Bau der Todeskarte
-- zwei Regeln, und dem Autor war diese die erste: "In Hillsbrad steht dein Beinahe-Tod (n=1) vor
-- einem Fremdpunkt mit 562 Toten. Du warst dort, es war dein Charakter."
-- Die ZWEITE Regel - Fremdwissen muss anders klingen - ist bei Lyra sauber umgesetzt
-- (GEOFENCE_BEINAHE "Hier war's knapp, weißt du noch? Ich schon." gegen GEOFENCE_MOB "Hier sind
-- viele gefallen. Nicht dich, bitte."). Die ERSTE fehlte: die Sperre lag je Art getrennt
-- (geofenceZuletzt[art]), und an einer gefaehrlichen Ecke - wo ein eigener Beinahe-Punkt und
-- eine fremde Deathlog-Zelle uebereinanderliegen, also im wahrscheinlichen Fall - feuerten
-- BEIDE. Aus einer Erinnerung wurde damit eine Statistik mit Nachschlag.
--
-- JETZT: der Puls sammelt erst alle Treffer eines Durchlaufs ein und entscheidet dann. Ist ein
-- eigener Beinahe-Punkt dabei, kommt NUR der - die fremden Treffer desselben Durchlaufs werden
-- stumm verbraucht (ihre Flanke ist weg, sie schreien also nicht drei Sekunden spaeter nach).
-- Zusaetzlich schweigen die fremden Arten 30 s lang, ueber alle Arten hinweg. Umgekehrt gilt
-- das NICHT: eine fremde Zelle hindert den eigenen Punkt an gar nichts.
--
-- W11C (20.09.2026) setzt eine Stufe darueber: den eigenen STERBEORT. Die zwoelf Zeilen dafuer
-- stehen unten in gefahrPuls, ausfuehrlich begruendet. U.vorrangBis wird von Sinne/Karte2.lua
-- dabei mit ANGEHOBEN (nie gesenkt) - die Sperre gilt dann fuer die fremden Arten genauso.
U.VORRANG_SEK = 30
U.vorrangBis = 0                -- absoluter Zeitpunkt, bis zu dem fremde Arten schweigen

-- Oeffentlich, weil Sinne/Welle8.lua dieselbe Frage stellt (die praeventive Warnung liest
-- dieselben Deathlog-Zellen). Ohne diese Datei antwortet die Abfrage dort fail-safe mit false.
function U.eigenerVorrang()
    return jetzt() < (U.vorrangBis or 0)
end

local geofenceZuletzt = {}
-- 3-s-Puls: Naehe zu bekannten Gefahren-Stellen der aktuellen Karte. Flanke innerhalb r,
-- Re-Arm erst ausserhalb 2r. Im Kampf, im Flug, tot: still (Warnung waere wertlos).
local gefahrArmed = {}          -- [key] = false (verbraucht) | true/nil (scharf)

local function position()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local ok, karte = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not karte then return nil end
    local ok2, pos = pcall(C_Map.GetPlayerMapPosition, karte, "player")
    if not ok2 or not pos then return nil end
    local x, y
    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    if not x or not y then return nil end
    return karte, x, y
end

local function gefahrPuls()
    -- W8 (A9): der Ortssinn haengt an C_Map. Hat der Selbsttest (Core/Selbsttest.lua) dort einen
    -- Ausfall gemessen, kehrt der Puls in der ersten Zeile um, statt jede Sekunde in denselben
    -- kaputten Aufruf zu laufen. Ohne Selbsttest antwortet ST.ok() fail-safe mit true.
    if ns.Selbsttest and not ns.Selbsttest.ok("karte") then return end
    local tab = ns.Gefahren
    if type(tab) ~= "table" or next(tab) == nil then return end
    if tot() or aufTaxi() or imKampf() then return end
    local karte, px, py = position()
    if not karte then return end
    local stellen = tab[karte]
    if type(stellen) ~= "table" then return end
    -- W11B-3: ERST SAMMELN, DANN ENTSCHEIDEN. Vorher wurde im Schleifendurchlauf sofort
    -- gemeldet - und damit konnte der eigene Punkt gar keinen Vorrang haben, weil die fremde
    -- Zelle je nach Reihenfolge in der Tabelle schon heraus war.
    local treffer = {}
    local eigener = nil
    for i, s in ipairs(stellen) do
        local r = s.r or 0.02
        local k = s.key or (tostring(karte) .. ":" .. i)
        local dx, dy = px - (s.x or 0), py - (s.y or 0)
        local d2 = dx * dx + dy * dy
        if d2 <= r * r then
            if gefahrArmed[k] ~= false then
                local art = s.art or "sturz"
                local eintrag = { k = k, art = art }
                if art == "beinahe" then
                    -- Der eigene Punkt: hoechstens einer je Durchlauf, der naechstgelegene.
                    if not eigener or d2 < eigener.d2 then
                        eintrag.d2 = d2
                        eigener = eintrag
                    end
                else
                    treffer[#treffer + 1] = eintrag
                end
            end
        elseif d2 >= 4 * r * r then
            gefahrArmed[k] = true
        end
    end

    local jetztT = GetTime()
    local function feuere(k, art)
        gefahrArmed[k] = false                        -- Flanke verbraucht
        local id = (art == "beinahe" and "GEOFENCE_BEINAHE") or (art == "wasser" and "GEOFENCE_WASSER")
                or (art == "mob" and "GEOFENCE_MOB") or "GEOFENCE"
        -- globale Bremse je Art: Mob-Lager 90 s, Rest 45 s (sonst Warnsalve beim Durchqueren)
        local pause = (art == "mob") and 90 or 45
        if jetztT - (geofenceZuletzt[art] or 0) >= pause then
            geofenceZuletzt[art] = jetztT
            ns.melde(id, { key = k, art = art })
        end
    end

    -- =========================================================================================
    -- W11C: UND UEBER DEM EIGENEN PUNKT STEHT DER EIGENE STERBEORT.
    -- =========================================================================================
    -- docs/abgleich-claudebuddy-2026-09-20.md §3 Nr. 7 (zweite Haelfte), Planpunkt W11-14:
    -- liegt an dieser Stelle ein eigener VORGAENGER, hat seine Zeile Vorrang vor allem hier -
    -- auch vor dem eigenen Beinahe-Punkt. Die Kette ist damit vollstaendig:
    --     eigener Sterbeort  >  eigener Beinahe-Punkt  >  fremde Deathlog-Zelle.
    --
    -- Gefragt wird HIER und nicht im eigenen Takt von Sinne/Karte2.lua, und das ist der ganze
    -- Punkt dieser zwoelf Zeilen: drei Ticker sehen dieselbe Gegend (Welle8 1 s, dieser 3 s,
    -- Karte2 2 s). Wer zuerst drankommt, wenn der Spieler um die Ecke biegt, ist Zufall - und
    -- "meistens der richtige" ist bei einem Satz, den ein Spieler ein einziges Mal hoert, keine
    -- Zusage. K2.sterbeortJetzt() fuehrt den Sterbeort-Puls sofort aus und gibt true zurueck,
    -- wenn die Vorgaenger-Zeile GERADE gekommen ist (sie kommt hoechstens einmal je Ort und
    -- Charakter - danach ist die Antwort fuer immer false und diese Abfrage kostet einen
    -- Tabellenzugriff). Ohne Sinne/Karte2.lua antwortet sie gar nicht, und alles bleibt wie
    -- vor Welle 11c.
    --
    -- Die Flanken werden verbraucht wie beim Vorrang des eigenen Punktes darunter: EIN Ort,
    -- EINE Zeile. Sie sollen nicht drei Sekunden spaeter nachtragen, was gerade bewusst
    -- zurueckgestellt wurde.
    if eigener or #treffer > 0 then
        local K2 = ns.Karte2
        if K2 and K2.sterbeortJetzt and K2.sterbeortJetzt() then
            if eigener then
                gefahrArmed[eigener.k] = false
                ns.debug("Geofence: beinahe weicht dem eigenen Sterbeort")
            end
            for _, tr in ipairs(treffer) do
                gefahrArmed[tr.k] = false
                ns.debug("Geofence: " .. tr.art .. " weicht dem eigenen Sterbeort")
            end
            return
        end
    end

    if eigener then
        feuere(eigener.k, "beinahe")
        U.vorrangBis = jetztT + U.VORRANG_SEK
        -- Die fremden Treffer desselben Durchlaufs sind damit erledigt. Ihre Flanke wird
        -- VERBRAUCHT und nicht nur zurueckgestellt: sonst kaeme dieselbe Stelle drei Sekunden
        -- spaeter (oder nach Ablauf der Sperre) doch noch als Statistik hinterher, und der
        -- Spieler bekaeme fuer EINEN Ort zwei Zeilen - genau das, was hier abgestellt wird.
        for _, tr in ipairs(treffer) do
            gefahrArmed[tr.k] = false
            ns.debug("Geofence: " .. tr.art .. " weicht dem eigenen Punkt")
        end
        return
    end

    -- Kein eigener Punkt hier - aber vielleicht gerade eben einer nebenan.
    if U.eigenerVorrang() then
        for _, tr in ipairs(treffer) do
            gefahrArmed[tr.k] = false
            ns.debug("Geofence: " .. tr.art .. " unterdrueckt (Vorrang eigener Punkt)")
        end
        return
    end

    for _, tr in ipairs(treffer) do feuere(tr.k, tr.art) end
end

-- Ein Ticker fuer Geofence und Flug-Flanken (faengt fehlende/zu fruehe Control-Events).
local puls = nil
local function pulsStart()
    if puls then return end
    puls = ns.Compat.NewTicker(3, function()
        local ok, err = pcall(function()
            U.flugFlanken()
            gefahrPuls()
        end)
        if not ok then ns.debug("Umwelt puls: " .. tostring(err)) end
    end)
end

-- ---------------------------------------------------------------- Ladebildschirm
ns.on("PLAYER_ENTERING_WORLD", function()
    atemStop()
    erschoepfungStop()
    ruhe.hatte = nil
    letzteRast = nil
    -- Zonen-Basislinie: beim Login still setzen, danach (Portal/Instanz) echter Wechsel.
    if not zoneBereit then
        ns.Compat.After(5, function()
            letzteZone = zoneJetzt()
            zoneBereit = true
        end)
    else
        ns.Compat.After(1, pruefeZone)
    end
    ns.Compat.After(2, pruefeRast)
    -- Flugzustand nachfuehren ohne Meldung, wenn wir MITTEN im Flug laden (selten, aber moeglich).
    if aufTaxi() and not flug.drin then flug.drin = true; flug.seit = jetzt() end
    pulsStart()
end)

function U.stand()
    return letzteZone, atem.aktiv, erschoepfung.aktiv, letzteRast, flug.drin, flug.ziel
end
