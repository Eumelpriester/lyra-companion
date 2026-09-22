-- Sinne/Leben2.lua — Innenleben: Laune, Vertrautheit, Tageszeit, Sitzung, Stress, Aufmerksamkeit.
-- MELDET NICHTS. Rechnet nur und stellt ns.Stimmung.* bereit. Doku: Sinne/LEBENSECHT.md.
--
-- Oeffentlich:
--   ns.Stimmung.zustand()        -> volle Zustandstabelle (2 s gecacht)
--   ns.Stimmung.tags()           -> { laune, vertraut, zeit, sitzung, stress, fest, hc, ssf, erste }
--   ns.Stimmung.passt(wenn)      -> Bool, Filter fuer Core/Regie.lua waehle()
--   ns.Stimmung.abstandFaktor()  -> 0.7 .. 1.4, Faktor fuer Core/Regie.lua preset() (Addition
--                                   plus Deckel 1,0; der alte multiplikative Weg steht als
--                                   ns.Stimmung.abstandFaktorAlt daneben, W9)
--   ns.Stimmung.grundstimmung()  -> Mienen-Name oder nil, fuer Gestalt/Gestalt.lua G.grundstimmung()
--   ns.Stimmung.status()         -> Zeilen fuer /lyra stimmung
--   ns.Stimmung.stunden()        -> Spielstunden account-weit
--   ns.Stimmung.vertraut()       -> 0..3
--   ns.Stimmung.fluechtig(t)     -> Tags nur fuer die naechste Meldung (Sinne/Rituale.lua: emote)
--
-- API (nur lesend): date, time, GetTime, UnitIsAFK, UnitOnTaxi, UnitHealth/UnitHealthMax,
--   UnitIsDeadOrGhost, UnitAffectingCombat, IsResting, IsInInstance, ns.Compat.istHardcore,
--   ns.Chronik.stand, ns.Sinne.Leben.pct, ns.Sinne.Alltag.stand. Nichts Fremdes, nie ein Spielername.
-- Events: PLAYER_LOGIN, PLAYER_ENTERING_WORLD, PLAYER_REGEN_DISABLED/ENABLED, PLAYER_FLAGS_CHANGED,
--   PLAYER_LOGOUT + Hook ns.nachAusgabe (Laune aus LEVELUP/LOOT/SKILL/HP20/STURZ/GEFALLEN).
-- Takt: EIN 60-s-Ticker (Spielzeit account-weit, AFK-Minuten zaehlen NICHT mit). Kein OnUpdate.
--
-- Speicher: LyraGestaltDB.account.spielzeit (Sekunden, account-weit). Das Feld wird HIER mit
--   `or 0` angelegt - Core/Init.lua bleibt unangetastet. LyraGestaltDB.account.ssf ebenso
--   (Solo Self-Found; UI/Settings.lua bekommt den Schalter per Patch nachgereicht).
local ADDON, ns = ...
ns.Stimmung = {}
local S = ns.Stimmung

local CACHE_S = 2                       -- s: zustand() rechnet hoechstens alle 2 s neu
local TICK = 60                         -- s: Spielzeit-Ticker
local STUFEN_H = { 10, 50, 100 }        -- Vertrautheit 1 / 2 / 3
local GUT_FRIST = 300                   -- s: LEVELUP/LOOT/SKILL/MEILENSTEIN faerben die Laune so lange
local BEINAHE_NACHWIRKUNG = 1200        -- s: wie Sinne/Chronik.lua NACHWIRKUNG_S
local RUHIG_S = 180                     -- s ohne Aktivitaetsmarke -> aufmerk "ruhig"
local KAMPF_RING = 8                    -- Eintraege im Kampf-Ringpuffer
local STRESS_TIEF_PCT = 40              -- % Leben, ab dem ein Kampf als "tief" gilt
local SITZUNG_MAX_H = 24                -- Kappe gegen kaputte SavedVariables

-- Tageszeit nach lokaler Uhr des Spielers (companion-v3 A.2 / A.8: "Es ist zwei Uhr" trifft nur,
-- wenn es BEIM SPIELER zwei Uhr ist). Realm-Zeit waere GetGameTime() - bewusst nicht.
--   5-9 frueh | 10-17 tag | 18-21 abend | 22-23,0 nacht | 1-4 spaet
local function zeitAus(h)
    if h >= 5 and h <= 9 then return "frueh" end
    if h >= 10 and h <= 17 then return "tag" end
    if h >= 18 and h <= 21 then return "abend" end
    if h >= 22 or h == 0 then return "nacht" end
    return "spaet"
end

local function jetzt() return GetTime() end
local function unix() return time() end
local function tot() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false end
local function imKampf() return UnitAffectingCombat and UnitAffectingCombat("player") or false end
local function afk() return UnitIsAFK and UnitIsAFK("player") and true or false end
local function taxi() return UnitOnTaxi and UnitOnTaxi("player") and true or false end
local function rast() return IsResting and IsResting() and true or false end

local function stunde()
    if type(date) ~= "function" then return 12 end
    local ok, t = pcall(date, "*t")
    if not ok or type(t) ~= "table" or type(t.hour) ~= "number" then return 12 end
    return t.hour
end
S.stunde = stunde

local function inInstanz()
    if not IsInInstance then return false end
    local ok, v = pcall(IsInInstance)
    return (ok and v) and true or false
end

local function lebenPct()
    local p = ns.Sinne and ns.Sinne.Leben and ns.Sinne.Leben.pct
    if type(p) == "number" then return p end
    if UnitHealth and UnitHealthMax then
        local max = UnitHealthMax("player")
        if max and max > 0 then return math.floor((UnitHealth("player") or 0) / max * 100 + 0.5) end
    end
    return 100
end

-- ---------------------------------------------------------------- Speicher (account-weit)
local acc = nil                         -- LyraGestaltDB.account, ab PLAYER_LOGIN

local function ladeDB()
    if not (LyraGestaltDB and LyraGestaltDB.account) then
        if ns.initDB then pcall(ns.initDB) end
    end
    if not (LyraGestaltDB and type(LyraGestaltDB.account) == "table") then return end
    acc = LyraGestaltDB.account
    -- Core/Init.lua gehoert in dieser Runde einem anderen Team: die Felder legen wir selbst an.
    acc.spielzeit = tonumber(acc.spielzeit) or 0
    if acc.ssf == nil then acc.ssf = false end
    if acc.erstSicht == nil then acc.erstSicht = unix() end
end

function S.stunden()
    if not acc then return 0 end
    return (tonumber(acc.spielzeit) or 0) / 3600
end

-- Die alte Rechnung, reine Stunden-Treppe. Bleibt unveraendert stehen und bekommt einen Namen
-- (S.vertrautAusStunden), weil Welle 16 (Sinne/Welle16.lua) sie als STUNDEN-BODEN braucht, ohne
-- sie zweimal zu schreiben: ns.Bindung.stufe() = max(Punkte-Stufe, S.vertrautAusStunden()).
local function vertrautAusStunden()
    local h = S.stunden()
    if h >= STUFEN_H[3] then return 3 end
    if h >= STUFEN_H[2] then return 2 end
    if h >= STUFEN_H[1] then return 1 end
    return 0
end
S.vertrautAusStunden = vertrautAusStunden

-- W16 (22.09.2026): die Bindung aus Ereignissen (Sinne/Welle16.lua) ersetzt diese Rechnung ALS
-- OBERFLAECHE — die 67 bestehenden "vertraut"-Stellen im Katalog und im Code greifen dadurch
-- automatisch auf Punkte statt nur auf Stunden zu. Ohne Welle 16 (oder wenn sie einen Fehler
-- wirft) bleibt es bei der alten Stunden-Treppe; pcall schuetzt davor, dass ein fremdes Modul
-- diese Kernfunktion zum Absturz bringt.
function S.vertraut()
    if ns.Bindung and ns.Bindung.stufe then
        local ok, s = pcall(ns.Bindung.stufe)
        if ok and type(s) == "number" then return s end
    end
    return vertrautAusStunden()
end

-- ---------------------------------------------------------------- Spielzeit-Ticker
local ticker = nil
local letzterTick = 0                   -- GetTime des letzten gezaehlten Ticks

local function spielzeitTick()
    if not acc then return end
    local t = jetzt()
    local delta = (letzterTick > 0) and (t - letzterTick) or TICK
    letzterTick = t
    if afk() then return end            -- AFK-Minuten zaehlen zur Vertrautheit NICHT mit
    if delta <= 0 or delta > 4 * TICK then delta = TICK end   -- Ladebildschirm/Frost: kein Sprung
    acc.spielzeit = (tonumber(acc.spielzeit) or 0) + delta
end

local function tickerStart()
    if ticker then return end
    letzterTick = jetzt()
    ticker = ns.Compat.NewTicker(TICK, function()
        local ok, err = pcall(spielzeitTick)
        if not ok then ns.debug("Stimmung tick: " .. tostring(err)) end
    end)
end

-- ---------------------------------------------------------------- Kampfstress (nur Flanken)
local kaempfe = {}                      -- { {t = unix, tief = bool}, ... }, max KAMPF_RING
local kampfStart = 0
local kampfTief = false

local function stressJetzt()
    local t = unix()
    local n5, tief10 = 0, 0
    for _, k in ipairs(kaempfe) do
        if t - k.t <= 300 then n5 = n5 + 1 end
        if t - k.t <= 600 and k.tief then tief10 = tief10 + 1 end
    end
    if tief10 >= 2 then return 2 end
    if n5 >= 3 then return 1 end
    return 0
end

ns.on("PLAYER_REGEN_DISABLED", function()
    kampfStart = unix()
    kampfTief = false
end)
ns.on("PLAYER_REGEN_ENABLED", function()
    if lebenPct() < STRESS_TIEF_PCT then kampfTief = true end
    kaempfe[#kaempfe + 1] = { t = unix(), tief = kampfTief }
    while #kaempfe > KAMPF_RING do table.remove(kaempfe, 1) end
    kampfStart, kampfTief = 0, false
end)
-- Waehrend des Kampfs tief: HP20/STURZ melden das (Hook unten setzt kampfTief zusaetzlich).

-- ---------------------------------------------------------------- Laune-Marken (Hook, kein Event)
local gutBis = 0                        -- GetTime, bis wann eine gute Marke nachwirkt
local letzterBeinahe = 0                -- unix, 0 = keiner in dieser Sitzung

local GUT_IDS = { LEVELUP = true, LOOT = true, SKILL = true, STUFE_MEILENSTEIN = true,
                  QUEST_AB = true, FOTO = true, BOSS_KILL = true }
local BEINAHE_IDS = { HP20 = true, STURZ = true }

ns.nachAusgabe(function(id, _, vars)
    if vars and vars.test then return end   -- HOTFIX 0.16.1: Proben aendern die Laune nicht
    if GUT_IDS[id] then
        gutBis = jetzt() + GUT_FRIST
    elseif BEINAHE_IDS[id] then
        letzterBeinahe = unix()
        kampfTief = true
        gutBis = 0                      -- eine gute Marke ueberlebt einen Beinahe-Tod nicht
    end
end)
ns.on("PLAYER_DEAD", function() gutBis = 0; letzterBeinahe = 0 end)

-- Beinahe-Nachwirkung: eigene Marke ODER die der Chronik (dort steht der Endzeitpunkt).
local function nachwirkung()
    if letzterBeinahe > 0 and unix() - letzterBeinahe < BEINAHE_NACHWIRKUNG then return true end
    if ns.Chronik and ns.Chronik.stand then
        local ok, _, _, _, nachAb = pcall(ns.Chronik.stand)
        if ok and type(nachAb) == "number" and nachAb > 0 and unix() < nachAb then return true end
    end
    return false
end

-- ---------------------------------------------------------------- Sitzung
local function sitzungStunden()
    if ns.Chronik and ns.Chronik.stand then
        local ok, _, sitz = pcall(ns.Chronik.stand)
        if ok and type(sitz) == "table" and tonumber(sitz.start) then
            local h = (unix() - sitz.start) / 3600
            if h >= 0 and h < SITZUNG_MAX_H then return h end
        end
    end
    -- Ohne Chronik: seit dem Laden dieses Moduls.
    return math.max(0, (jetzt() - (S.geladen or 0)) / 3600)
end
S.geladen = jetzt()

-- Erste Sitzung ueberhaupt mit diesem Charakter?
local function ersteSitzung()
    if ns.Chronik and ns.Chronik.stand then
        local ok, db = pcall(ns.Chronik.stand)
        if ok and type(db) == "table" and type(db.sitzungen) == "table" then
            return #db.sitzungen <= 1
        end
    end
    return false
end

-- ---------------------------------------------------------------- Aufmerksamkeit
local function aufmerkJetzt()
    if afk() then return "weg" end
    if taxi() then return "taxi" end
    if imKampf() or (ns.Regie and ns.Regie.imKampf) then return "angespannt" end
    if ns.Sinne and ns.Sinne.Alltag and ns.Sinne.Alltag.stand then
        local ok, _, _, _, _, ruhe = pcall(ns.Sinne.Alltag.stand)
        if ok and type(ruhe) == "number" and ruhe >= RUHIG_S then return "ruhig" end
    end
    return "wach"
end

-- ---------------------------------------------------------------- Zustand
local cache, cacheBis = nil, 0

local function rechne()
    local z = {}
    z.stunden  = S.stunden()
    z.vertraut = S.vertraut()
    z.zeit     = zeitAus(stunde())
    z.sitzung  = sitzungStunden()
    z.stress   = stressJetzt()
    z.afk      = afk()
    z.taxi     = taxi()
    z.tot      = tot()
    z.rast     = rast()
    z.instanz  = inInstanz()
    z.aufmerk  = aufmerkJetzt()
    z.nachwirkung = nachwirkung()
    z.hp       = lebenPct()
    z.erste    = ersteSitzung()
    z.hc       = (ns.Compat and ns.Compat.istHardcore and ns.Compat.istHardcore()) and true or false
    z.ssf      = (acc and acc.ssf) and true or false
    z.fest     = (ns.Rituale and ns.Rituale.festJetzt and ns.Rituale.festJetzt()) or nil
    z.gedenken = (ns.Rituale and ns.Rituale.gedenkenHeute and ns.Rituale.gedenkenHeute()) and true or false

    -- Laune ist abgeleitet, nie zufaellig - und darum immer erklaerbar (companion-v3 A.2).
    if z.nachwirkung or z.stress == 2 or z.tot or z.gedenken
       or (z.hp < 50 and not imKampf()) then
        z.laune = "besorgt"
        z.grund = z.nachwirkung and "beinahe" or (z.gedenken and "gedenken")
            or (z.tot and "tot") or (z.stress == 2 and "stress") or "hp"
    elseif jetzt() < gutBis or (z.rast and z.stress == 0) or z.sitzung < 0.2 then
        z.laune = "gut"
        z.grund = (jetzt() < gutBis) and "erfolg" or (z.rast and "rast") or "frisch"
    else
        z.laune = "neutral"
        z.grund = nil
    end
    return z
end

function S.zustand()
    local t = jetzt()
    if cache and t < cacheBis then return cache end
    cache = rechne()
    cacheBis = t + CACHE_S
    return cache
end

-- ---------------------------------------------------------------- Tags und Filter
-- Fluechtige Tags gelten nur fuer die naechste Meldung (Sinne/Rituale.lua setzt "emote").
local fluechtig = nil
function S.fluechtig(t)
    fluechtig = (type(t) == "table") and t or nil
    cacheBis = 0
end

function S.tags()
    local z = S.zustand()
    local t = {
        laune    = z.laune,
        vertraut = z.vertraut,
        zeit     = z.zeit,
        sitzung  = z.sitzung,
        -- REVIEW5: "stunden" steht in MIN_KEYS und BEKANNT und in der Schluesseltabelle in
        -- LEBENSECHT.md - fehlte hier aber. Eine Zeile mit "wenn": {"stunden": 50} waere damit
        -- stumm gewesen, ohne Debug-Zeile (der Wert ist nil, also "kein Treffer"). Heute nutzt
        -- keine Zeile den Schluessel; die Falle stellt man trotzdem besser jetzt ab.
        stunden  = z.stunden,
        stress   = z.stress,
        fest     = z.fest,
        hc       = z.hc,
        ssf      = z.ssf,
        erste    = z.erste,
    }
    if fluechtig then for k, v in pairs(fluechtig) do t[k] = v end end
    return t
end

-- Numerische Schluessel sind MINDESTwerte (>=), alle anderen exakt. Unbekannte Schluessel
-- gelten als nicht erfuellt: eine Zeile mit einem Tag, den wir nicht verstehen, schweigt lieber.
local MIN_KEYS = { vertraut = true, sitzung = true, stress = true, stunden = true }
-- REVIEW6B: "stil" kommt aus Sinne/Profil.lua (Welle 2), das ns.Stimmung.tags umwickelt und den
-- Spielstil dazulegt. Ohne Eintrag hier wies S.passt jede Zeile mit "wenn": {"stil": ...} ab -
-- inklusive Debug-Zeile "unbekannter wenn-Schluessel stil". Der Wrapper war damit wirkungslos.
local BEKANNT = { laune = true, vertraut = true, zeit = true, sitzung = true, stress = true,
                  fest = true, hc = true, ssf = true, erste = true, emote = true, stunden = true,
                  stil = true }

function S.passt(wenn)
    if type(wenn) ~= "table" then return true end
    local tags = S.tags()
    for k, v in pairs(wenn) do
        if not BEKANNT[k] then
            ns.debug("Stimmung: unbekannter wenn-Schluessel " .. tostring(k))
            return false
        end
        local ist = tags[k]
        if MIN_KEYS[k] then
            if type(ist) ~= "number" or type(v) ~= "number" or ist < v then return false end
        elseif ist ~= v then
            return false
        end
    end
    return true
end

-- ---------------------------------------------------------------- Abstandsfaktor (nur plauder!)
-- Gedeckelt auf 0.7 .. 1.4. Beruehrt NIE die Warnungen: warn laeuft in R.melde vor dem Abstand.
-- Eine besorgte Lyra verschluckt keine HP20-Warnung.
--
-- W9 (20.09.2026): DIESE RECHNUNG STAND BIS 0.12.0 IN Sinne/Welle8.lua und hat von dort
-- ns.Stimmung.abstandFaktor abgeloest. Der Umweg hatte einen einzigen Grund - Leben2.lua
-- gehoerte in Welle 8 einem anderen Team -, und der Welle-8-Bericht hat ihn als offenen Punkt
-- notiert ("fachlich gehoert die Aenderung dort hin und sollte beim naechsten Anfassen von
-- Leben2.lua dorthin wandern", docs/welle8-2026-09-20.md §5). Das ist jetzt passiert: die
-- Zahlen, die Reihenfolge und der Deckel sind unveraendert uebernommen, der Ablose-Block in
-- Welle8.lua ist ersatzlos weg, und W.abstandFaktor dort zeigt nur noch hierher.
--
-- DER BEFUND, der zur Addition gefuehrt hat (pruefstand-wiederaufbau §5 Punkt 5): die Faktoren
-- multiplizierten sich. "erste 5 Minuten" x0,7 mal "besorgt" x1,25 ergab 0,875 - nach einem
-- Beinahe-Tod in Minute 3 redete Lyra also MEHR als im Normalfall (1,0). Genau verkehrt herum:
-- "besorgt" heisst konzentriert, und konzentriert heisst weniger Geplauder.
--
-- DIE RECHNUNG, die stattdessen gilt - Addition plus EIN Deckel:
--   1. f = 1 + Summe der Zuschlaege. Aus x0,7 wird -0,30, aus x1,25 wird +0,25. Damit heben
--      sich Gegensaetze auf, statt sich zu verduennen: -0,30 + 0,25 = 0,95 statt 0,875.
--      Addition ist ausserdem das, was die Kommentare hier ohnehin behaupten - vier
--      multiplizierte Faktoren sind kein Tuning mehr, sondern ein Produkt, das niemand im
--      Kopf hat.
--   2. Der Deckel: greift ein DAEMPFENDER Grund (besorgt, angespannt/weg, spaete Stunde in
--      langer Sitzung, lange Sitzung), faellt der Faktor nicht mehr unter 1,0. Wer konzentriert
--      ist, wird nicht dadurch gespraechiger, dass Lyra sich freut, ihn zu sehen. Das ist die
--      eigentliche Antwort auf den Befund - die Addition allein haette aus 0,875 nur 0,95
--      gemacht, und 0,95 ist immer noch "mehr als normal".
local FAKTOR_MIN, FAKTOR_MAX = 0.7, 1.4
S.FAKTOR_MIN, S.FAKTOR_MAX = FAKTOR_MIN, FAKTOR_MAX
S.ZUSCHLAG = {
    ersteMinuten  = -0.30,   -- war x0,7
    ruhig         = -0.15,   -- war x0,85
    vertrautGut   = -0.15,   -- war x0,85
    sitzungLang   =  0.40,   -- war x1,4   (> 5 h)
    sitzungMittel =  0.25,   -- war x1,25  (> 3 h)
    besorgt       =  0.25,   -- war x1,25
    nachts        =  0.20,   -- war x1,2
    angespannt    =  0.40,   -- war x1,4
}

function S.abstandFaktor()
    if not S.zustand then return 1 end
    local ok, z = pcall(S.zustand)
    if not ok or type(z) ~= "table" then return 1 end
    local Z = S.ZUSCHLAG
    local f, daempfer = 1, false
    if z.sitzung and z.sitzung < 0.084 then f = f + Z.ersteMinuten end   -- erste 5 min: Wiedersehen
    if z.aufmerk == "ruhig" then f = f + Z.ruhig end                     -- Leerlauf: da darf sie plaudern
    if (z.vertraut or 0) >= 2 and z.laune == "gut" then f = f + Z.vertrautGut end
    if (z.sitzung or 0) > 5 then f = f + Z.sitzungLang; daempfer = true
    elseif (z.sitzung or 0) > 3 then f = f + Z.sitzungMittel; daempfer = true end
    if z.laune == "besorgt" then f = f + Z.besorgt; daempfer = true end  -- konzentriert, nicht gespraechig
    if (z.zeit == "nacht" or z.zeit == "spaet") and (z.sitzung or 0) > 2 then
        f = f + Z.nachts; daempfer = true
    end
    if z.aufmerk == "angespannt" or z.aufmerk == "weg" then f = f + Z.angespannt; daempfer = true end
    if daempfer and f < 1 then f = 1 end
    if f < FAKTOR_MIN then f = FAKTOR_MIN end
    if f > FAKTOR_MAX then f = FAKTOR_MAX end
    return f
end

-- Der ALTE, multiplikative Weg. Er bleibt stehen, weil der Pruefstand beide gegeneinander misst
-- (w8_harness Szene 12: "der alte Weg gab nach dem Beinahe-Tod in Minute 3 den Faktor 0,875") -
-- und weil, wer das Tuning zurueckdrehen will, dafuer eine Zeile braucht und kein Archiv.
-- Er wird von Lyra selbst NIRGENDS gerufen.
function S.abstandFaktorAlt()
    local z = S.zustand()
    local f = 1
    if z.sitzung < 0.084 then f = f * 0.7 end
    if z.aufmerk == "ruhig" then f = f * 0.85 end
    if z.vertraut >= 2 and z.laune == "gut" then f = f * 0.85 end
    if z.sitzung > 5 then f = f * 1.4
    elseif z.sitzung > 3 then f = f * 1.25 end
    if z.laune == "besorgt" then f = f * 1.25 end
    if (z.zeit == "nacht" or z.zeit == "spaet") and z.sitzung > 2 then f = f * 1.2 end
    if z.aufmerk == "angespannt" or z.aufmerk == "weg" then f = f * 1.4 end
    if f < FAKTOR_MIN then f = FAKTOR_MIN end
    if f > FAKTOR_MAX then f = FAKTOR_MAX end
    return f
end

-- ---------------------------------------------------------------- Grundstimmung (Mienen-Vorschlag)
-- Reihenfolge = Prioritaet. "kampf" bleibt in Gestalt.lua VOR diesem Aufruf, "rast" dahinter:
-- bei Rast geben wir nil zurueck und der alte Pfad liefert gs.rast.
function S.grundstimmung(gs)
    gs = gs or (LyraGestalt_Phrasen and LyraGestalt_Phrasen.grundstimmung) or {}
    local z = S.zustand()
    if z.afk then return gs.afk or "sad" end
    if z.taxi then return gs.taxi or "whatever" end
    if z.tot then return gs.tot or "depressed" end
    if z.laune == "besorgt" then return gs.besorgt or "concerned" end
    if z.rast then return nil end                                   -- der alte Pfad liefert gs.rast
    if z.laune == "gut" then return gs.gut or "happy" end
    if (z.zeit == "nacht" or z.zeit == "spaet") and z.sitzung > 2 then return gs.nacht or "hmm" end
    if z.sitzung > 4 then return gs.lange or "thinking" end
    return nil
end

-- Mikrowechsel-Pool nach Vertrautheit und Laune (companion-v3 A.7). Gestalt.lua darf das lesen.
local MIKRO = {
    [0] = { "hmm", "thinking", "interested", "wonder", "shy" },
    [1] = { "hmm", "thinking", "interested", "wonder", "amused", "smirk" },
    [2] = { "thinking", "interested", "wonder", "amused", "smirk", "smug", "touched" },
    [3] = { "interested", "wonder", "amused", "smirk", "smug", "touched", "happy" },
}
local MIKRO_BESORGT = { "hmm", "thinking", "concerned", "anxious" }

function S.mikroPool()
    local z = S.zustand()
    if z.laune == "besorgt" then return MIKRO_BESORGT end
    return MIKRO[z.vertraut] or MIKRO[0]
end

-- ---------------------------------------------------------------- Status (/lyra stimmung)
local TEXT = {
    de = {
        kopf   = "Stimmung:",
        laune  = "  Laune: %s%s",
        vert   = "  Vertrautheit: Stufe %d (%s) - %.1f h mit dir",
        zeit   = "  Tageszeit: %s (%02d Uhr), Sitzung %s",
        stress = "  Stress: %d, Aufmerksamkeit: %s",
        fest   = "  Fest: %s",
        modus  = "  Hardcore: %s, Self-Found: %s",
        takt   = "  Redeabstand x%.2f",
        std    = "%dh%02d",
        ja = "ja", nein = "nein",
        launen = { gut = "gut", neutral = "neutral", besorgt = "besorgt" },
        gruende = { beinahe = " (der Beinahe-Tod sitzt noch)", gedenken = " (Gedenktag)",
                    tot = " (du bist tot)", stress = " (zu viele Kaempfe)", hp = " (du blutest)",
                    erfolg = " (gerade lief etwas gut)", rast = " (Rast)", frisch = " (frisch eingeloggt)" },
        stufen = { [0] = "fremd", [1] = "bekannt", [2] = "vertraut", [3] = "verbunden" },
        zeiten = { frueh = "frueh", tag = "Tag", abend = "Abend", nacht = "Nacht", spaet = "spaet" },
        aufmerk = { weg = "weg", taxi = "unterwegs", angespannt = "angespannt", ruhig = "ruhig", wach = "wach" },
    },
    en = {
        kopf   = "Mood:",
        laune  = "  Mood: %s%s",
        vert   = "  Familiarity: tier %d (%s) - %.1f h with you",
        zeit   = "  Time of day: %s (%02d:00), session %s",
        stress = "  Stress: %d, attention: %s",
        fest   = "  Holiday: %s",
        modus  = "  Hardcore: %s, self-found: %s",
        takt   = "  Talk spacing x%.2f",
        std    = "%dh%02d",
        ja = "yes", nein = "no",
        launen = { gut = "good", neutral = "neutral", besorgt = "worried" },
        gruende = { beinahe = " (that near-death still stings)", gedenken = " (day of remembrance)",
                    tot = " (you are dead)", stress = " (too many fights)", hp = " (you're bleeding)",
                    erfolg = " (something just went well)", rast = " (resting)", frisch = " (just logged in)" },
        stufen = { [0] = "stranger", [1] = "acquainted", [2] = "familiar", [3] = "bonded" },
        zeiten = { frueh = "early", tag = "day", abend = "evening", nacht = "night", spaet = "small hours" },
        aufmerk = { weg = "away", taxi = "travelling", angespannt = "tense", ruhig = "quiet", wach = "alert" },
    },
}

function S.status()
    local T = TEXT[ns.sprache()] or TEXT.en
    local z = S.zustand()
    local out = { T.kopf }
    out[#out + 1] = T.laune:format(T.launen[z.laune] or z.laune, (z.grund and T.gruende[z.grund]) or "")
    out[#out + 1] = T.vert:format(z.vertraut, T.stufen[z.vertraut] or "?", z.stunden)
    local sek = math.floor(z.sitzung * 3600)
    out[#out + 1] = T.zeit:format(T.zeiten[z.zeit] or z.zeit, stunde(),
        T.std:format(math.floor(sek / 3600), math.floor(sek % 3600 / 60)))
    out[#out + 1] = T.stress:format(z.stress, T.aufmerk[z.aufmerk] or z.aufmerk)
    if z.fest then out[#out + 1] = T.fest:format(tostring(z.fest)) end
    out[#out + 1] = T.modus:format(z.hc and T.ja or T.nein, z.ssf and T.ja or T.nein)
    out[#out + 1] = T.takt:format(S.abstandFaktor())
    return out
end

-- ---------------------------------------------------------------- Ereignisse
ns.on("PLAYER_LOGIN", function()
    ladeDB()
    tickerStart()
end)

ns.on("PLAYER_ENTERING_WORLD", function()
    if not acc then ladeDB() end
    tickerStart()
    letzterTick = jetzt()                -- Ladebildschirm zaehlt nicht als Spielzeit
    cacheBis = 0
end)

-- AFK-Flanke: Cache sofort verwerfen, damit die Miene ohne Verzug folgt.
ns.on("PLAYER_FLAGS_CHANGED", function() cacheBis = 0 end)

ns.on("PLAYER_LOGOUT", function()
    -- Angefangene Minute sichern (Alt+F4 und Verbindungsabbruch kosten hoechstens diese Minute).
    if not acc then return end
    if afk() then return end
    local delta = jetzt() - letzterTick
    if delta > 0 and delta <= TICK then acc.spielzeit = (tonumber(acc.spielzeit) or 0) + delta end
end)

function S.stand() return acc, ticker ~= nil, #kaempfe, gutBis, letzterBeinahe end
