-- W8: Sinne/Welle8.lua — Feature-Welle 8: die praeventive Sturz- und Wasserwarnung (A2).
--
-- WAS HEUTE SCHON DA IST UND WAS FEHLT
-- ------------------------------------
-- Sinne/Umwelt.lua meldet GEOFENCE / GEOFENCE_WASSER / GEOFENCE_MOB, wenn der Spieler eine
-- Gefahrenzelle BETRITT (3-s-Puls, Flanke bei r, Re-Arm bei 2r). Das ist richtig und bleibt.
-- Es kommt nur zu spaet fuer die zwei haeufigsten Todesursachen in Hardcore: wer am Rand der
-- Klippe steht, ist schon in der Zelle; wer im tiefen Wasser ist, schwimmt schon.
--
-- Diese Datei ergaenzt genau das fehlende Stueck: VORAUSEILEND. Sie schaut, wohin sich der
-- Spieler bewegt, und meldet eine Sturz- oder Wasserzelle, die 20 bis 40 Yard VOR ihm liegt.
-- Der bestehende Geofence wird nicht angefasst, nicht ersetzt und nicht verdoppelt - er ist
-- die zweite Stufe derselben Warnung, und die Drosseln halten sie auseinander.
--
-- DIE RECHNUNG, EHRLICH AUFGESCHRIEBEN
-- ------------------------------------
--   1. Position je Sekunde ueber HereBeDragons (GetPlayerZonePosition, Kartenanteil 0..1) und
--      die Zonengroesse in Yard (GetZoneSize). Daraus die Bewegung in YARD, nicht in Anteilen:
--      ein Anteil ist in Durotar (5064 x 3376 yd) etwas voellig anderes als in Sturmwind
--      (1516 x 1011 yd). Das ist derselbe Fehler, den Welle 5 am Beinahe-Radius behoben hat.
--   2. Tempo = Strecke / Zeit. Zu langsam (< 2,5 yd/s) heisst "steht oder dreht sich" - dann
--      sagt die Richtung nichts. Zu schnell (> 20 yd/s) heisst Flug, Portal oder Ladefenster -
--      dann stimmt die Projektion nicht. Beides ist ein Riegel, kein Rueckfall.
--   3. GetPlayerFacing kommt NICHT in die Richtung. Das ist Absicht und der Punkt, an dem man
--      sich hier verrechnen kann: GetPlayerFacing gibt den Blickwinkel in der WELT (Bogenmass,
--      0 = Norden, gegen den Uhrzeigersinn), die Zellen liegen aber im KARTENRASTER, dessen
--      y-Achse nach Sueden zeigt und dessen Drehung gegen die Welt pro Karte anders sein kann.
--      Aus dem Winkel eine Kartenrichtung zu machen hiesse raten. Was der Winkel dagegen
--      zuverlaessig sagt, ohne jede Umrechnung, ist die AENDERUNG: wer sich seit der letzten
--      Sekunde um mehr als 0,6 rad gedreht hat, laeuft nicht geradeaus, und dann ist jede
--      Projektion wertlos. Genau dafuer wird er benutzt - als Riegel, nicht als Richtung.
--      (Die Richtung liefert die Positionsdifferenz, und die ist per Bauart im richtigen Raum.)
--   4. Kegel statt Strahl: die Zelle muss im Winkel von 30 Grad um die Laufrichtung liegen
--      (cos >= 0,866). Ein Strahl trifft eine 2-%-Zelle fast nie, ein Halbraum meldet alles,
--      was irgendwo vorn liegt.
--
-- DIE SCHWELLE: 10 TODE JE ZELLE, UND WARUM GENAU DIESE
-- ----------------------------------------------------
-- Gemessen am ausgelieferten Datenpaket (Lyra_Gestalt_Daten/gefahren.lua, Deathlog-Aggregat,
-- 1 440 470 Tode, 13 887 Zellen, 48 Karten) am 20.09.2026:
--
--   Sturz-Zellen (Einstufung wie Sinne/Gefahren_Daten.lua): 569, Median 9 Sturztode
--     >= 3 Tode: 569 Zellen (100 %)   -> haelt 28 208 Sturztode (100 %)
--     >= 10 Tode: 276 Zellen (48,5 %) -> haelt 26 746 Sturztode (94,8 %)
--   Wasser-Zellen: 418, Median 6 Ertrunkene
--     >= 10 Tode: 145 Zellen (34,7 %) -> haelt 4 434 von 5 761 Ertrunkenen (77,0 %)
--
-- Die Schwelle 10 wirft also gut die HAELFTE der Sturzzellen weg und verliert dabei 5,2 % der
-- Sturztode. Das ist der ganze Handel: eine Zelle mit drei Sturztoten ist in einer Datenbank
-- mit 1,4 Millionen Toden Rauschen, eine Zelle mit zehn ist eine Gelaendefalle. Fuer den
-- Geofence beim Betreten bleibt die alte Schwelle (3, Sinne/Gefahren_Daten.lua UMWELT_MIN) -
-- der darf weiter reden, er kostet weniger: wer schon drin steht, wird nicht unterbrochen,
-- sondern bestaetigt. Eine Warnung VOR dem Ereignis unterbricht jemanden, dem gerade nichts
-- passiert; die muss teurer eingekauft werden.
--
-- DIE FEHLALARM-RIEGEL (in der Reihenfolge, in der sie greifen)
-- ------------------------------------------------------------
--   * Schalter aus (vorwarnung), Gefahrenkarte aus, Hauptschalter karte aus
--   * Profil: nur Era-artige Clients (ns.Compat.F.gefahrenkarte) - auf Retail/Forever liegt
--     hinter derselben mapID eine andere Welt (REVIEW9, Core/Compat.lua)
--   * Selbsttest: Ortssinn oder HereBeDragons ausgefallen -> still (Core/Selbsttest.lua)
--   * tot, im Kampf, auf Taxi, im Flug, in einer Instanz
--   * in einer Ruhezone (IsResting) - das ist der Stadt-/Gasthaus-Riegel. In Sturmwind vor
--     dem Kanal gewarnt zu werden ist der schnellste Weg, dass jemand die Funktion abschaltet.
--   * Tempo ausserhalb 2,5 .. 20 yd/s, Drehung ueber 0,6 rad/s, Kartenwechsel im letzten Takt
--   * hoechstens EINE Warnung je Takt
--   * Drossel: 10 min je Zelle (Katalog, drossel "stelle-600" ueber vars.key) UND hoechstens
--     einmal je Zelle und Sitzung - die Sitzungssperre faellt erst bei einem Zonenwechsel.
--
-- SCHWIMMEN (das dritte Ereignis)
-- ------------------------------
-- TIEFES_WASSER ist der einzige Fall, in dem der Spieler schon DRIN ist. Bedingung: er
-- schwimmt, sein Atem steht unter 50 %, und er steht in einer Wasserzelle mit >= 10
-- Ertrunkenen. "Weiter weg vom Ufer" ist ehrlich gesagt nicht messbar - Lyra weiss nicht, wo
-- das Ufer ist. Sie weiss, wo Leute ertrunken sind, und das ist dieselbe Stelle, nur besser
-- belegt. Genau so steht es auch in der Zeile.
--
-- TAKT UND KONTRAKT
-- -----------------
-- EIN Ticker, 1 s, und er kehrt in der ersten Zeile um, sobald einer der Riegel greift
-- (Kontrakt: Abstands-/Richtungspruefung hoechstens 1x/s und nur ausserhalb des Kampfes).
-- Kein OnUpdate, kein SendChatMessage, keine geschuetzte Funktion, keine Fremddaten, kein Netz,
-- keine Animationsgruppe. Alles Fremde in pcall.
--
-- API (nur lesend): GetTime, UnitIsDeadOrGhost, UnitAffectingCombat, UnitOnTaxi, IsFlying,
--   IsResting, IsInInstance, IsSwimming, GetMirrorTimerInfo/GetMirrorTimerProgress,
--   GetPlayerFacing, ns.Karte2 (HereBeDragons), ns.Gefahren, LyraGestalt_Daten.
-- Events: PLAYER_ENTERING_WORLD (Ticker starten), ZONE_CHANGED_NEW_AREA (Sitzungssperre loesen).
-- Speicher: keiner. Kein eigener SavedVariables-Eintrag ausser dem Schalter im Account.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Sinne.Welle8 = W
ns.Welle8 = W

-- Voreinstellung. Core/Init.lua ist in dieser Welle unantastbar (Version), darum haengt der
-- Schluessel hier an ns.DEFAULTS_ACCOUNT - beim LADEN, also lange vor ADDON_LOADED, und dort
-- ruft ns.initDB() defaults(). Muster aus Sinne/Welle4.lua und Sinne/Karte2.lua.
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.vorwarnung == nil then D.vorwarnung = true end
end

-- ---------------------------------------------------------------------------------------------
-- Stellschrauben. Alle an EINER Stelle, alle mit Einheit im Namen oder im Kommentar.
-- ---------------------------------------------------------------------------------------------
W.TAKT        = 1      -- s zwischen zwei Pruefungen (Kontrakt: hoechstens 1x/s)
W.VOR_MIN_YD  = 20     -- naeher als das: der Geofence in Sinne/Umwelt.lua ist zustaendig
W.VOR_MAX_YD  = 40     -- weiter als das: zu frueh, die Richtung haelt so lange nicht
W.TEMPO_MIN   = 2.5    -- yd/s - darunter steht man praktisch (Gehen ist ~2,5, Laufen 7)
W.TEMPO_MAX   = 20     -- yd/s - darueber: Flug, Portal, Ladefenster. 100-%-Reittier laeuft 14.
W.KEGEL_COS   = 0.866  -- cos(30 Grad)
W.DREH_MAX    = 0.6    -- rad/s - mehr heisst: er dreht sich, die Projektion ist wertlos
W.TODE_MIN    = 10     -- Tode der passenden Art je Zelle (Begruendung im Dateikopf)
W.ATEM_PCT    = 50     -- % Restluft, ab der TIEFES_WASSER ueberhaupt in Frage kommt
W.LUECKE_MAX  = 3      -- s: groessere Luecke zwischen zwei Takten -> Messung verwerfen
W.ATEM_MAX_MS = 60000  -- Classic-Atemleiste, falls der Client kein maxvalue liefert

-- ---------------------------------------------------------------------------------------------
-- Kleinkram
-- ---------------------------------------------------------------------------------------------
local function jetzt() return (GetTime and GetTime()) or 0 end
local function de() return (ns.sprache and ns.sprache() == "de") and true or false end
local function Get(k) return ns.Get and ns.Get(k) end
local function an(k) return Get(k) ~= false end

local function frage(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if not ok then return nil end
    return r
end

local function tot()      return frage(UnitIsDeadOrGhost, "player") and true or false end
local function imKampf()  return frage(UnitAffectingCombat, "player") and true or false end
local function aufTaxi()  return frage(UnitOnTaxi, "player") and true or false end
local function fliegt()   return frage(IsFlying) and true or false end
local function ruht()     return frage(IsResting) and true or false end
local function inInstanz() return frage(IsInInstance) and true or false end

-- IsSwimming gibt es auf allen fuenf Clients, ist aber nicht der einzige Beleg: laeuft die
-- Atemleiste, ist der Kopf unter Wasser - und genau darum geht es.
local function schwimmt()
    if frage(IsSwimming) then return true end
    return W.atemProzent() ~= nil
end

-- Restluft in Prozent, oder nil, wenn gerade keine Atemleiste laeuft.
-- GetMirrorTimerInfo(i) -> name, value, maxvalue, scale, paused, label. Nur dieser Weg kennt
-- das Maximum; GetMirrorTimerProgress(name) gibt nur den Rest in ms und braucht eine Annahme.
function W.atemProzent()
    if GetMirrorTimerInfo then
        for i = 1, 3 do
            local ok, name, value, maxvalue = pcall(GetMirrorTimerInfo, i)
            if ok and name == "BREATH" then
                value, maxvalue = tonumber(value), tonumber(maxvalue)
                if value and value > 0 then
                    if not maxvalue or maxvalue <= 0 then maxvalue = W.ATEM_MAX_MS end
                    return math.max(0, math.min(100, value / maxvalue * 100))
                end
                return nil
            end
        end
    end
    if GetMirrorTimerProgress then
        local ok, ms = pcall(GetMirrorTimerProgress, "BREATH")
        ms = ok and tonumber(ms) or nil
        if ms and ms > 0 then
            return math.max(0, math.min(100, ms / W.ATEM_MAX_MS * 100))
        end
    end
    return nil
end

-- Winkeldifferenz auf [-pi, pi]. Ohne das springt die Drehung bei jedem Nulldurchgang auf 2pi
-- und der Riegel wuerde bei jedem Blick nach Norden greifen.
local function winkelDiff(a, b)
    local d = (a or 0) - (b or 0)
    local zwei = math.pi * 2
    d = d % zwei
    if d > math.pi then d = d - zwei end
    return d
end

-- ---------------------------------------------------------------------------------------------
-- Karte: Zonengroesse in Yard. Ueber ns.Karte2, damit es genau EINE HereBeDragons-Anbindung im
-- Addon gibt. K2.ydZuAnteil() taugt hier NICHT: die Funktion deckelt ihr Ergebnis auf
-- R_MIN/R_MAX (das ist fuer einen Warnradius richtig und fuer eine Umrechnung falsch).
-- ---------------------------------------------------------------------------------------------
local function zonenGroesse(mapID)
    local K2 = ns.Karte2
    if not (K2 and K2.hbd and mapID) then return nil end
    local h = K2.hbd()
    if not (h and h.GetZoneSize) then return nil end
    local ok, breite, hoehe = pcall(h.GetZoneSize, h, mapID)
    if not ok then return nil end
    breite, hoehe = tonumber(breite) or 0, tonumber(hoehe) or 0
    if breite <= 0 or hoehe <= 0 then return nil end
    return breite, hoehe
end
W.zonenGroesse = zonenGroesse

local function spielerOrt()
    local K2 = ns.Karte2
    if K2 and K2.spielerOrt then
        local mapID, x, y = K2.spielerOrt()
        if mapID then return mapID, x, y end
    end
    return nil
end

-- ---------------------------------------------------------------------------------------------
-- Tode je Zelle. Der Index wird je Karte EINMAL gebaut und dann behalten - er aendert sich nur,
-- wenn das Datenpaket wechselt, und das passiert nicht im Spiel.
-- Gezaehlt wird die Todesart, die zum Ereignis passt: fuer eine Sturzzelle die Sturztode, fuer
-- eine Wasserzelle die Ertrunkenen. NICHT z.n (die Gesamtzahl) - in einer Zelle mit 300 Toten,
-- von denen drei gefallen sind, ist der Sturz nicht das Problem.
-- ---------------------------------------------------------------------------------------------
local todesIndex = {}       -- [mapID] = { [key] = { sturz = n, wasser = n } } | false

local function indexFuer(mapID)
    local i = todesIndex[mapID]
    if i ~= nil then return i or nil end
    local D = LyraGestalt_Daten
    if type(D) ~= "table" or type(D.zellen) ~= "table" or type(D.zellen[mapID]) ~= "table" then
        todesIndex[mapID] = false
        return nil
    end
    local idx = {}
    for _, z in ipairs(D.zellen[mapID]) do
        if type(z) == "table" and z.x and z.y then
            idx["d" .. mapID .. "_" .. z.x .. "_" .. z.y] =
                { sturz = tonumber(z.sturz) or 0, wasser = tonumber(z.wasser) or 0 }
        end
    end
    todesIndex[mapID] = idx
    return idx
end

local function todeVon(mapID, key, art)
    local idx = indexFuer(mapID)
    if not idx then return nil end
    local e = idx[key]
    if not e then return nil end
    return e[art]
end
W.todeVon = todeVon

-- ---------------------------------------------------------------------------------------------
-- Zustand
-- ---------------------------------------------------------------------------------------------
local letzte = { map = nil, x = nil, y = nil, t = 0, blick = nil }
local gesagt = {}           -- [key] = true: in DIESER Zone-Sitzung schon gewarnt
local ticker = nil

W.stand = { pruefungen = 0, warnungen = 0, verworfen = {}, tempo = 0, letzterGrund = "-" }

local function verwirf(grund)
    W.stand.letzterGrund = grund
    W.stand.verworfen[grund] = (W.stand.verworfen[grund] or 0) + 1
    return false
end

local function messungVerwerfen(mapID, x, y, blick)
    letzte.map, letzte.x, letzte.y, letzte.t, letzte.blick = mapID, x, y, jetzt(), blick
end

-- ---------------------------------------------------------------------------------------------
-- Die Riegel, die nicht von der Bewegung abhaengen. Getrennt, damit der Pruefstand sie einzeln
-- fragen kann - und damit man sie lesen kann, ohne die Rechnung zu lesen.
-- ---------------------------------------------------------------------------------------------
function W.darfWarnen()
    if not an("vorwarnung") then return verwirf("schalter") end
    if Get("gefahrenkarte") == false then return verwirf("gefahrenkarte-aus") end
    if Get("karte") == false then return verwirf("karte-aus") end
    local C = ns.Compat
    if C and C.F and C.F.gefahrenkarte == false then return verwirf("profil") end
    local ST = ns.Selbsttest
    if ST then
        if not ST.ok("karte") then return verwirf("selbsttest-karte") end
        if not ST.ok("hbd") then return verwirf("selbsttest-hbd") end
    end
    if tot() then return verwirf("tot") end
    if imKampf() then return verwirf("kampf") end
    if aufTaxi() then return verwirf("taxi") end
    if fliegt() then return verwirf("flug") end
    if inInstanz() then return verwirf("instanz") end
    if ruht() then return verwirf("ruhezone") end
    return true
end

-- ---------------------------------------------------------------------------------------------
-- Ein Takt. Oeffentlich, damit der Pruefstand ihn ohne Ticker fahren kann.
-- ---------------------------------------------------------------------------------------------
function W.puls()
    if not W.darfWarnen() then return false end

    local mapID, px, py = spielerOrt()
    if not mapID then return verwirf("keine-position") end
    local breite, hoehe = zonenGroesse(mapID)
    if not breite then return verwirf("keine-zonengroesse") end

    local blick = tonumber(frage(GetPlayerFacing))
    local t = jetzt()
    local dt = t - (letzte.t or 0)

    -- Erster Takt, Kartenwechsel oder zu grosse Luecke: nur merken, nichts behaupten.
    if letzte.map ~= mapID or letzte.x == nil or dt <= 0 or dt > W.LUECKE_MAX then
        messungVerwerfen(mapID, px, py, blick)
        return verwirf("erster-takt")
    end

    W.stand.pruefungen = W.stand.pruefungen + 1

    local dxYd = (px - letzte.x) * breite
    local dyYd = (py - letzte.y) * hoehe
    local strecke = math.sqrt(dxYd * dxYd + dyYd * dyYd)
    local tempo = strecke / dt
    W.stand.tempo = tempo

    -- Drehung zuerst: wer sich dreht, laeuft nicht dorthin, wo er vor einer Sekunde hinlief.
    if blick and letzte.blick then
        local dreh = math.abs(winkelDiff(blick, letzte.blick)) / dt
        if dreh > W.DREH_MAX then
            messungVerwerfen(mapID, px, py, blick)
            return verwirf("dreht")
        end
    end

    messungVerwerfen(mapID, px, py, blick)

    -- Schwimmen wird VOR dem Tempo-Riegel geprueft: unter Wasser ist man langsam, und die
    -- Warnung gilt dem Ort, an dem man schon ist - nicht dem, auf den man zulaeuft.
    if W.schwimmPruefen(mapID, px, py, breite, hoehe) then return true end

    if tempo < W.TEMPO_MIN then return verwirf("zu-langsam") end
    if tempo > W.TEMPO_MAX then return verwirf("zu-schnell") end

    local ux, uy = dxYd / strecke, dyYd / strecke

    local stellen = ns.Gefahren and ns.Gefahren[mapID]
    if type(stellen) ~= "table" then return verwirf("keine-zellen") end

    for _, s in ipairs(stellen) do
        local art = s.art
        if type(s) == "table" and (art == "sturz" or art == "wasser")
           and s.key and tostring(s.key):sub(1, 1) == "d" then
            local cx = ((s.x or 0) - px) * breite
            local cy = ((s.y or 0) - py) * hoehe
            local d = math.sqrt(cx * cx + cy * cy)
            if d >= W.VOR_MIN_YD and d <= W.VOR_MAX_YD then
                local cos = (cx * ux + cy * uy) / d
                if cos >= W.KEGEL_COS then
                    local tode = todeVon(mapID, s.key, art)
                    -- W11B-3: "Dein eigener Punkt schlaegt jede Statistik." Hat Sinne/Umwelt.lua
                    -- gerade GEOFENCE_BEINAHE gemeldet, schweigt die Vorwarnung 30 s lang - sie
                    -- ist die REINE Statistik (nur Zellen mit Schluessel "d...", also
                    -- Deathlog-Material), und die tritt hinter die eigene Erinnerung zurueck.
                    -- Die Flanke wird hier NICHT verbraucht: anders als beim Geofence warnt
                    -- diese Stelle vor etwas, auf das der Spieler erst ZULAEUFT - fuer sie ist
                    -- Zurueckstellen richtig und Wegwerfen falsch.
                    -- W.schwimmPruefen (TIEFES_WASSER) ist ausdruecklich NICHT gesperrt: dort ist
                    -- der Spieler schon drin und hat weniger als halbe Luft. Das ist keine
                    -- Statistik mehr, das ist die Lage.
                    local U = ns.Sinne and ns.Sinne.Umwelt
                    if U and U.eigenerVorrang and U.eigenerVorrang() then
                        return verwirf("eigener-punkt")
                    end
                    if tode and tode >= W.TODE_MIN then
                        if not gesagt[s.key] then
                            gesagt[s.key] = true
                            W.stand.warnungen = W.stand.warnungen + 1
                            W.stand.letzterGrund = "gewarnt"
                            local id = (art == "wasser") and "WASSER_VORAUS" or "STURZ_VORAUS"
                            pcall(ns.melde, id, { key = s.key, tode = tode,
                                                  yd = math.floor(d + 0.5), art = art })
                            return true          -- hoechstens EINE Warnung je Takt
                        else
                            verwirf("sitzung")
                        end
                    else
                        verwirf("zu-wenige-tode")
                    end
                end
            end
        end
    end
    return verwirf("nichts-voraus")
end

-- ---------------------------------------------------------------------------------------------
-- TIEFES_WASSER: der eine Fall, in dem der Spieler schon drin ist.
-- ---------------------------------------------------------------------------------------------
function W.schwimmPruefen(mapID, px, py, breite, hoehe)
    if not schwimmt() then return false end
    local pct = W.atemProzent()
    if not pct or pct >= W.ATEM_PCT then return false end

    local stellen = ns.Gefahren and ns.Gefahren[mapID]
    if type(stellen) ~= "table" then return false end
    for _, s in ipairs(stellen) do
        if type(s) == "table" and s.art == "wasser" and s.key
           and tostring(s.key):sub(1, 1) == "d" then
            local cx = ((s.x or 0) - px) * breite
            local cy = ((s.y or 0) - py) * hoehe
            local d = math.sqrt(cx * cx + cy * cy)
            -- DRIN, nicht davor: naeher als die Untergrenze der Vorwarnung. Das ist genau die
            -- Luecke, die der Kegel oben auslaesst, und sie ist hier die Bedingung.
            if d < W.VOR_MIN_YD then
                local tode = todeVon(mapID, s.key, "wasser")
                if tode and tode >= W.TODE_MIN and not gesagt[s.key] then
                    gesagt[s.key] = true
                    W.stand.warnungen = W.stand.warnungen + 1
                    W.stand.letzterGrund = "gewarnt-wasser"
                    pcall(ns.melde, "TIEFES_WASSER", { key = s.key, tode = tode,
                                                       yd = math.floor(d + 0.5),
                                                       atem = math.floor(pct + 0.5) })
                    return true
                end
            end
        end
    end
    return false
end

-- ---------------------------------------------------------------------------------------------
-- Ticker und Ereignisse
-- ---------------------------------------------------------------------------------------------
local function tickerStart()
    if ticker then return end
    ticker = ns.Compat.NewTicker(W.TAKT, function()
        local ok, err = pcall(W.puls)
        if not ok then ns.debug("Welle8 puls: " .. tostring(err)) end
    end)
    W.ticker = ticker      -- nach aussen sichtbar: /lyra debug und der Pruefstand
end
W.tickerStart = tickerStart

-- Die Sitzungssperre faellt beim Zonenwechsel. Begruendung: "einmal je Zelle und Sitzung" soll
-- verhindern, dass ein Hin und Her an derselben Klippe zur Salve wird - nicht, dass Lyra beim
-- zweiten Besuch derselben Zone in vier Stunden schweigt. Der Katalog drosselt obendrauf
-- 10 Minuten je Zelle, die Sperre ist also nie die einzige Bremse.
ns.on("ZONE_CHANGED_NEW_AREA", function()
    gesagt = {}
    letzte.map = nil
end)

ns.on("PLAYER_ENTERING_WORLD", function()
    gesagt = {}
    letzte.map = nil
    tickerStart()
end)

-- ---------------------------------------------------------------------------------------------
-- /lyra status
-- ---------------------------------------------------------------------------------------------
function W.status()
    local z = {}
    local d = de()
    if not an("vorwarnung") then
        z[1] = d and "Vorwarnung: aus." or "Pre-warning: off."
        return z
    end
    local C = ns.Compat
    if C and C.F and C.F.gefahrenkarte == false then
        z[1] = (d and "Vorwarnung: auf Profil %s aus (Era-Daten)."
                  or "Pre-warning: off on profile %s (Era data)."):format(tostring(C.profil))
        return z
    end
    local mapID = spielerOrt()
    local breite, hoehe = zonenGroesse(mapID)
    local zellen = 0
    if mapID and ns.Gefahren and type(ns.Gefahren[mapID]) == "table" then
        for _, s in ipairs(ns.Gefahren[mapID]) do
            if (s.art == "sturz" or s.art == "wasser") and s.key and tostring(s.key):sub(1, 1) == "d" then
                local tode = todeVon(mapID, s.key, s.art)
                if tode and tode >= W.TODE_MIN then zellen = zellen + 1 end
            end
        end
    end
    z[#z + 1] = (d and "Vorwarnung: an, %d Zellen ab %d Toden in dieser Zone, %d-%d yd voraus."
                   or "Pre-warning: on, %d cells from %d deaths in this zone, %d-%d yd ahead."
                ):format(zellen, W.TODE_MIN, W.VOR_MIN_YD, W.VOR_MAX_YD)
    z[#z + 1] = (d and "  Zonengroesse: %s - %d Pruefungen, %d Warnungen, zuletzt: %s"
                   or "  Zone size: %s - %d checks, %d warnings, last: %s"
                ):format(breite and ("%d x %d yd"):format(breite, hoehe) or (d and "unbekannt" or "unknown"),
                         W.stand.pruefungen, W.stand.warnungen, tostring(W.stand.letzterGrund))
    return z
end

-- ---------------------------------------------------------------------------------------------
-- W9 §3 (20.09.2026): DER ABSTANDSFAKTOR IST UMGEZOGEN.
--
-- Hier stand bis 0.12.0 die ganze Rechnung (Addition statt Multiplikation, Deckel 1,0) und
-- darunter ein Block, der ns.Stimmung.abstandFaktor ABLOESTE. Beides hatte denselben einen
-- Grund: Sinne/Leben2.lua gehoerte in Welle 8 einem anderen Team. Der Welle-8-Bericht hat das
-- als offenen Punkt notiert - "fachlich gehoert die Aenderung dort hin und sollte beim
-- naechsten Anfassen von Leben2.lua dorthin wandern" (docs/welle8-2026-09-20.md §5).
--
-- Jetzt steht sie dort, Zahl fuer Zahl unveraendert: ns.Stimmung.abstandFaktor rechnet die
-- Addition selbst, ns.Stimmung.abstandFaktorAlt ist der alte multiplikative Weg. Die Ablose
-- ist ersatzlos entfallen - es gibt nichts mehr abzuloesen.
--
-- WAS HIER BLEIBT, ist nur der NAME. W.abstandFaktor und W.ZUSCHLAG zeigen auf dieselbe
-- Funktion und dieselbe Tabelle wie vorher; das kostet nichts und haelt jeden Aufruf am Leben,
-- der die Rechnung unter dem Welle-8-Namen kennt (der Pruefstand tut das, und er soll genau
-- das weiter tun: "ns.Stimmung.abstandFaktor == W.abstandFaktor" ist jetzt wahr, weil es
-- DIESELBE Funktion ist - nicht, weil Welle 8 sie ueberschrieben hat).
if ns.Stimmung then
    W.abstandFaktor = ns.Stimmung.abstandFaktor
    W.ZUSCHLAG      = ns.Stimmung.ZUSCHLAG
    W.FAKTOR_MIN    = ns.Stimmung.FAKTOR_MIN
    W.FAKTOR_MAX    = ns.Stimmung.FAKTOR_MAX
end
