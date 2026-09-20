-- Sinne/Rituale.lua — kleine Rituale: Abschied, AFK-Rueckkehr, spaete Stunde, Jahrestag,
--   Gedenken, In-Game-Feste, eigene Emotes, Lagerfeuer. Doku: Sinne/LEBENSECHT.md.
-- Ereignisse: ABSCHIED, RUECKKEHR, SPAET, JAHRESTAG, GEDENKEN, FEIERTAG, EMOTE, LAGERFEUER.
-- API (nur lesend): time, date, GetTime, UnitIsAFK, UnitGUID, UnitName, UnitOnTaxi,
--   UnitAffectingCombat, UnitIsDeadOrGhost, IsInGroup/IsInRaid, GetSpellInfo,
--   ns.Compat.auraByIndex/istHardcore/After/NewTicker, ns.Chronik.stand, ns.Stimmung.*.
--   Hooks (nur lesend, nie aufrufend): DoEmote, Logout, Quit - jeweils type()-geprueft.
-- Events: PLAYER_CAMPING, PLAYER_QUITING, CANCEL_LOGOUT, LOGOUT_CANCEL, PLAYER_FLAGS_CHANGED,
--   PLAYER_LOGIN, PLAYER_ENTERING_WORLD, PLAYER_LOGOUT, CHAT_MSG_TEXT_EMOTE, UNIT_AURA (player),
--   UNIT_SPELLCAST_SUCCEEDED (player).
-- Takt: EIN 60-s-Ticker (Tagwechsel, spaete Stunde, Lagerfeuer-Standzeit). Kein OnUpdate.
-- Privatsphaere (Grenze B): CHAT_MSG_TEXT_EMOTE wird NUR ausgewertet, wenn arg12 == UnitGUID("player").
--   Fremde Emotes fallen sofort durch, es wird nie ein Name gespeichert, geloggt oder ausgegeben.
-- Speicher (account-weit): LyraGestaltDB.account.rituale = { feste = {[id]="JJJJMMTT"},
--   jahrestag = {[charKey]="JJJJ"}, gedenken = {[name-t]="JJJJ"} }. Hier angelegt, nicht in Init.lua.
local ADDON, ns = ...
ns.Rituale = {}
local R = ns.Rituale

local TICK = 60
local AFK_MIN = 300                     -- s: erst ab 5 min AFK gibt es eine Rueckkehr
local EMOTE_MAX = 3                     -- Antworten je Sitzung
local EMOTE_FENSTER = 3                 -- s: so lange gilt ein DoEmote-Token als frisch
local LAGER_STAND = 20                  -- s am Feuer, bevor sie etwas sagt
local GEDENK_RUHE = 300                 -- s Funkstille nach einem Gedenksatz
local FEIER_VERZUG, JAHR_VERZUG, GEDENK_VERZUG = 55, 60, 75   -- s nach dem ersten PEW
local PLAN_VERZUG = 45                  -- s: hier faellt die Entscheidung, WELCHES Ritual laeuft
local TAG = 86400

local function jetzt() return GetTime() end
local function unix() return time() end
local function tot() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false end
local function imKampf() return UnitAffectingCombat and UnitAffectingCombat("player") or false end
local function afk() return UnitIsAFK and UnitIsAFK("player") and true or false end
local function inGruppe() return (IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid()) or false end
local function sprache() return ns.sprache() end
local function dat(f, t) if type(date) ~= "function" then return "" end
    local ok, v = pcall(date, f, t); return ok and v or "" end

-- ---------------------------------------------------------------- Speicher
local RIT = nil

local function ladeDB()
    if not (LyraGestaltDB and type(LyraGestaltDB.account) == "table") then
        if ns.initDB then pcall(ns.initDB) end
    end
    if not (LyraGestaltDB and type(LyraGestaltDB.account) == "table") then return end
    local a = LyraGestaltDB.account
    if type(a.rituale) ~= "table" then a.rituale = {} end
    a.rituale.feste = (type(a.rituale.feste) == "table") and a.rituale.feste or {}
    a.rituale.jahrestag = (type(a.rituale.jahrestag) == "table") and a.rituale.jahrestag or {}
    a.rituale.gedenken = (type(a.rituale.gedenken) == "table") and a.rituale.gedenken or {}
    RIT = a.rituale
end

local function chronik()
    if not (ns.Chronik and ns.Chronik.stand) then return nil, nil end
    local ok, db, sitz = pcall(ns.Chronik.stand)
    if not ok then return nil, nil end
    return (type(db) == "table") and db or nil, (type(sitz) == "table") and sitz or nil
end

-- Melden, ohne dem Spieler ins Wort zu fallen: still-Modus und Gruppen-Schweigen gelten immer.
-- "direkt" gibt es nur fuer ABSCHIED - dort ist das Fenster ~20 s lang und kommt nie wieder.
local function meldeRitual(id, vars, direkt)
    if ns.stillModus then return false end
    if inGruppe() and ns.Get("gruppeSchweigen") then return false end
    if direkt then
        vars = vars or {}
        vars.direkt = true
    end
    return ns.melde(id, vars) and true or false
end

-- Melden mit EINEM Nachhol (Muster aus Sinne/Chronik.lua und Sinne/Erbe.lua): der Regie-Abstand
-- frisst sonst ein Ritual, das einmal im Jahr faellig ist. Nachgelegt wird NUR, wenn der Abstand
-- der Grund war - Drossel, Gruppe und Still-Modus sind endgueltig. `danach` laeuft bei Erfolg.
local NACHHOL_MAX = 180
local function meldeNachhol(id, vars, danach)
    if meldeRitual(id, vars) then
        if danach then danach() end
        return true
    end
    local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
    if not (d and d[2] == id and d[1] == "abstand") then return false end
    if not (C_Timer and C_Timer.After) then return false end
    local rest = (ns.Regie.abstandRest and ns.Regie.abstandRest()) or 30
    ns.Compat.After(math.min(rest + 1, NACHHOL_MAX), function()
        if meldeRitual(id, vars) and danach then danach() end
    end)
    return false
end

-- ---------------------------------------------------------------- Erinnerungs-Referenzen
-- companion-v3 A.6: die einzige Stelle, an der Lyra vage werden DARF. "vor 6,2 Tagen" waere
-- Telemetrie, "letzte Woche" ist Erinnerung. Hoechstens EINE Referenz je Sitzung.
local erinnerungVerbraucht = false

local WANN = {
    de = { [1] = "gestern", [3] = "neulich", [10] = "letzte Woche", [40] = "vor ein paar Wochen", damals = "damals" },
    en = { [1] = "yesterday", [3] = "the other day", [10] = "last week", [40] = "a few weeks ago", damals = "back then" },
}
local function wannText(tage, l)
    local W = WANN[l] or WANN.en
    if tage <= 1 then return W[1] end
    if tage <= 3 then return W[3] end
    if tage <= 10 then return W[10] end
    if tage <= 40 then return W[40] end
    return W.damals
end

local SATZ = {
    de = {
        beinahe = "%s in %s, als es knapp wurde",
        stufe   = "wie du Stufe %d erreicht hast",
        sitzung = "die %d Stunden am Stueck, die wir mal hatten",
        zone    = "%s in %s",
    },
    en = {
        beinahe = "%s in %s, when it got close",
        stufe   = "when you hit level %d",
        sitzung = "those %d hours in one go we once had",
        zone    = "%s in %s",
    },
}

-- ns.Rituale.erinnerung() -> Satzteil in der aktiven Sprache, oder nil.
-- Reihenfolge: Beinahe-Tod (2-30 Tage, andere Zone) > letzter Meilenstein > laengste Sitzung.
function R.erinnerung()
    if erinnerungVerbraucht then return nil end
    if not (ns.Stimmung and ns.Stimmung.vertraut and ns.Stimmung.vertraut() >= 1) then return nil end
    local db = chronik()
    if not db then return nil end
    local l = sprache()
    local S = SATZ[l] or SATZ.en
    local t = unix()
    local hier = ""
    if GetRealZoneText then local ok, z = pcall(GetRealZoneText); hier = (ok and z) or "" end

    -- 1) Beinahe-Tod, 2-30 Tage her, nicht in der aktuellen Zone
    local best = nil
    for i = #(db.beinahe or {}), 1, -1 do
        local b = db.beinahe[i]
        if type(b) == "table" and tonumber(b.t) and b.zone and b.zone ~= "" and b.zone ~= hier then
            local tage = math.floor((t - b.t) / TAG)
            if tage >= 2 and tage <= 30 then best = { zone = b.zone, tage = tage }; break end
        end
    end
    if best then return S.beinahe:format(wannText(best.tage, l), best.zone) end

    -- 2) letzter Stufen-Meilenstein aus den Sitzungen
    local hoechste = 0
    for _, s in ipairs(db.sitzungen or {}) do
        local lv = tonumber(s.level) or 0
        if lv > hoechste then hoechste = lv end
    end
    if hoechste >= 10 then
        local meilen = math.floor(hoechste / 10) * 10
        if meilen >= 10 then return S.stufe:format(meilen) end
    end

    -- 3) laengste Sitzung
    local laengste = 0
    for _, s in ipairs(db.sitzungen or {}) do
        local d = (tonumber(s.ende) or 0) - (tonumber(s.start) or 0)
        if d > laengste then laengste = d end
    end
    local std = math.floor(laengste / 3600)
    if std >= 3 then return S.sitzung:format(std) end
    return nil
end

-- Der Platzhalter {erinnerung}: ns.melde wird gewrappt (Muster aus Sinne/Erbe.lua und
-- Sinne/Bruecken.lua), damit Core/Regie.lua unangetastet bleibt. Zeilen ohne den Platzhalter
-- merken es nicht; Zeilen MIT dem Platzhalter sind nur dann Kandidaten, wenn es eine
-- Erinnerung gibt - waehle() wirft Platzhalter-Zeilen ohne passende Vars von selbst heraus.
local ERINNERUNGS_IDS = {
    LEERLAUF = true, RAST_AN = true, ZONE_ERINNERUNG = true,
    BEINAHE_NACHWIRKUNG = true, WIEDERKEHR = true, LAGERFEUER = true,
}
local gewrappt = false

local function meldeWrappen()
    if gewrappt or type(ns.melde) ~= "function" then return end
    gewrappt = true
    local original = ns.melde
    ns.melde = function(id, vars)
        if ERINNERUNGS_IDS[id] and not (vars and vars.erinnerung ~= nil) then
            local ok, e = pcall(R.erinnerung)
            if ok and e then
                vars = vars or {}
                vars.erinnerung = e
            end
        end
        return original(id, vars)
    end
end

-- Verbraucht ist die Erinnerung erst, wenn die gewaehlte Zeile sie wirklich getragen hat.
ns.nachAusgabe(function(id, e, vars, text)
    if not (text and vars and vars.erinnerung) then return end
    local s = (text.de or "") .. (text.en or "")
    if s:find("{erinnerung}", 1, true) then erinnerungVerbraucht = true end
end)

-- ---------------------------------------------------------------- Feste (Datumstabelle)
-- companion-v3 A.8: Questie benutzt auf Classic Era KEINE C_Calendar-Feiertagsabfrage, sondern
-- eine feste Datumstabelle (QuestieEvent.lua:506 ff.) - Grund ist ein Kommentar ueber private
-- Server ohne C_Calendar (:278). Wir machen es genauso. C_Calendar bleibt Welle 2.
-- era = false: laut Questies eventDateCorrections["CLASSIC"] in Classic Era NICHT vorhanden.
-- Sie stehen trotzdem in der Tabelle, weil dieselbe Datei spaeter Retail/Forever bedient.
local FESTE = {
    { id = "schlotternaechte", von = "1018", bis = "1101", era = true  },
    { id = "winterhauch",      von = "1215", bis = "0102", era = true  },   -- ueber den Jahreswechsel
    { id = "liebe",            von = "0203", bis = "0216", era = true  },
    { id = "sonnenwende",      von = "0621", bis = "0705", era = true  },
    { id = "braufest",         von = "0920", bis = "1006", era = false },
    { id = "pilgerfreuden",    von = "1122", bis = "1128", era = false },
}

local function heuteMMDD() return dat("%m%d") end

-- ns.Rituale.festJetzt() -> Fest-Schluessel oder nil. ns.Stimmung liest das fuer den Tag "fest".
function R.festJetzt()
    local h = heuteMMDD()
    if h == "" then return nil end
    -- PORT (0.9.0): war `not ns.Compat.istRetail`. Das ist keine API-Frage, sondern eine Frage
    -- des Spielinhalts: Braufest und Pilgerfreuden gibt es in Vanilla-Azeroth nicht.
    -- WoW: Forever ist Vanilla-Inhalt auf Mainline-API und gehoert damit zu "era" — mit der
    -- alten Zeile waere es zwar zufaellig auch richtig gelandet, aber aus dem falschen Grund.
    -- MoP Classic bekommt die modernen Feste jetzt richtig (dort GIBT es Braufest).
    local klassisch = not (ns.Compat and ns.Compat.F and ns.Compat.F.feste == "modern")
    for _, f in ipairs(FESTE) do
        if f.era or not klassisch then
            if f.von <= f.bis then
                if h >= f.von and h <= f.bis then return f.id end
            else
                if h >= f.von or h <= f.bis then return f.id end   -- Winterhauch
            end
        end
    end
    return nil
end

local function feiertagPruefen()
    if not RIT then return false end
    local f = R.festJetzt()
    if not f then return false end
    local heute = dat("%Y%m%d")
    if RIT.feste[f] == heute then return false end                 -- hoechstens 1x je Kalendertag
    return meldeNachhol("FEIERTAG", { key = f, fest = f }, function() RIT.feste[f] = heute end)
end

-- ---------------------------------------------------------------- Jahrestag
-- Es gibt KEINE API fuer das Erstelldatum eines Charakters (companion-v3 A.8). Wir nehmen die
-- Erstsichtung: das aelteste "erst" aus den Chronik-Zonen, sonst die aelteste Sitzung.
local function erstSicht()
    local db = chronik()
    if not db then return nil end
    local aeltest = nil
    for _, e in pairs(db.zonen or {}) do
        local t = tonumber(type(e) == "table" and e.erst)
        if t and t > 0 and (not aeltest or t < aeltest) then aeltest = t end
    end
    for _, s in ipairs(db.sitzungen or {}) do
        local t = tonumber(s.start)
        if t and t > 0 and (not aeltest or t < aeltest) then aeltest = t end
    end
    return aeltest
end

local function jahrestagFaellig()
    if not (RIT and ns.charKey) then return nil end
    local erst = erstSicht()
    if not erst then return nil end
    local t = unix()
    if t - erst < 300 * TAG then return nil end                    -- erst ab knapp einem Jahr
    if dat("%m%d", erst) ~= heuteMMDD() then return nil end
    local jahr = dat("%Y")
    if RIT.jahrestag[ns.charKey] == jahr then return nil end
    if not (ns.Stimmung and ns.Stimmung.vertraut() >= 1) then return nil end
    local tage = math.floor((t - erst) / TAG)
    return { key = jahr, tage = tage, jahre = math.floor(tage / 365) }
end

local function jahrestagPruefen()
    local d = jahrestagFaellig()
    if not d then return false end
    return meldeNachhol("JAHRESTAG", d, function() RIT.jahrestag[ns.charKey] = d.key end)
end

-- ---------------------------------------------------------------- Gedenken
-- Todestag eines eigenen Vorgaengers aus LyraGestaltDB.erbe. Gleiche Schranke wie Sinne/Erbe.lua:
-- Hardcore oder der Schalter erbeImmer. Es sind ausschliesslich EIGENE Charaktere.
local gedenkHeute = nil                 -- Name des Vorgaengers, wenn heute sein Todestag ist

local function erbeAktiv()
    if ns.Compat and ns.Compat.istHardcore and ns.Compat.istHardcore() then return true end
    return ns.Get("erbeImmer") and true or false
end

local function gedenkSuchen()
    gedenkHeute = nil
    if not erbeAktiv() then return nil end
    local liste = LyraGestaltDB and LyraGestaltDB.erbe
    if type(liste) ~= "table" then return nil end
    local h = heuteMMDD()
    local jetztJahr = tonumber(dat("%Y")) or 0
    local treffer = nil
    for _, e in ipairs(liste) do
        local t = tonumber(type(e) == "table" and e.t)
        if t and e.name and dat("%m%d", t) == h then
            local jahr = tonumber(dat("%Y", t)) or jetztJahr
            if jetztJahr > jahr then
                local kand = { name = e.name, t = t, jahre = jetztJahr - jahr }
                if not treffer or t < treffer.t then treffer = kand end
            end
        end
    end
    if treffer then gedenkHeute = treffer.name end
    return treffer
end

-- ns.Stimmung liest das: an einem Gedenktag ist die Laune "besorgt".
function R.gedenkenHeute() return gedenkHeute end

local function gedenkenPruefen()
    if not RIT then return false end
    local g = gedenkSuchen()
    if not g then return false end
    local schluessel = tostring(g.name) .. "-" .. tostring(g.t)
    local jahr = dat("%Y")
    if RIT.gedenken[schluessel] == jahr then return false end
    return meldeNachhol("GEDENKEN", { key = schluessel, vorgaenger = g.name, jahre = g.jahre }, function()
        RIT.gedenken[schluessel] = jahr
        -- Wer nach einem Gedenksatz sofort ueber volle Taschen redet, ist keine Begleiterin.
        -- REVIEW5: ueber R.plauderRuheBis, NICHT ueber R.todRiegelBis. Der Tod-Riegel sperrt jede
        -- Klasse ausser "still" - also auch warn. Fuenf Minuten ohne HP20-Warnung auf Hardcore ist
        -- kein Respekt, das ist ein Fehler (im Harness reproduziert: drop-Grund "tod-ruhe").
        if ns.Regie then
            local bis = jetzt() + GEDENK_RUHE
            if bis > (ns.Regie.plauderRuheBis or 0) then ns.Regie.plauderRuheBis = bis end
        end
    end)
end

-- ---------------------------------------------------------------- Abschied (/camp, /logout, /quit)
local abschiedGesagt = false

local function abschied()
    if abschiedGesagt or tot() then return end
    abschiedGesagt = true
    local vars = { key = "abschied" }
    if ns.Stimmung then
        local h = ns.Stimmung.zustand().sitzung
        if h >= 1 then vars.stunden = math.floor(h + 0.5) end
    end
    meldeRitual("ABSCHIED", vars, true)
end

local function abschiedZurueck()
    abschiedGesagt = false
    if ns.Gestalt and ns.Gestalt.regung then pcall(ns.Gestalt.regung, "amused", 3) end
end

ns.on("PLAYER_CAMPING", abschied)       -- /camp und /logout (Era seit 1.0.0)
ns.on("PLAYER_QUITING", abschied)       -- /quit  (sic: ein "t")
ns.on("CANCEL_LOGOUT", abschiedZurueck)
ns.on("LOGOUT_CANCEL", abschiedZurueck)

-- ---------------------------------------------------------------- AFK / Rueckkehr
local afkSeit = 0
local warAfk = false

local function flaggenPruefen()
    local ist = afk()
    if ist and not warAfk then
        warAfk = true
        afkSeit = unix()
    elseif (not ist) and warAfk then
        warAfk = false
        local dauer = unix() - afkSeit
        afkSeit = 0
        if dauer < AFK_MIN then return end                          -- kurz weg ist kein Ereignis
        local vars = { key = "afk", minuten = math.floor(dauer / 60) }
        meldeRitual("RUECKKEHR", vars)
    end
end
ns.on("PLAYER_FLAGS_CHANGED", flaggenPruefen)

-- ---------------------------------------------------------------- Spaete Stunde
local spaetGesagt = false

local function spaetPruefen()
    if spaetGesagt or tot() or imKampf() or afk() then return false end
    local h = ns.Stimmung and ns.Stimmung.stunde() or 12
    if h > 4 then return false end                                  -- 0-4 Uhr lokaler Zeit
    -- REVIEW5: {stunden} mitgeben. Die Zeile mit "wenn": {"sitzung": 3} traegt den Platzhalter;
    -- ohne die Variable wirft waehle() sie IMMER heraus - die Zeile war schlicht tot (Harness:
    -- 4 von 5 SPAET-Zeilen erreichbar).
    local vars = { key = "spaet" }
    if ns.Stimmung and ns.Stimmung.zustand then
        local h2 = ns.Stimmung.zustand().sitzung
        if type(h2) == "number" then vars.stunden = math.floor(h2 + 0.5) end
    end
    if meldeRitual("SPAET", vars) then
        spaetGesagt = true
        return true
    end
    return false
end

-- ---------------------------------------------------------------- Eigene Emotes
-- Zwei Wege, ein Ergebnis: der DoEmote-Hook liefert das sprachunabhaengige TOKEN, das Ereignis
-- CHAT_MSG_TEXT_EMOTE die Bestaetigung, dass der Server es angenommen hat - und die Sicherheit,
-- dass es MEIN Emote war (arg12 == UnitGUID("player")). Fremde Emotes fallen immer durch.
local GRUPPEN = {
    WAVE = "wave", WINK = "wave", HELLO = "wave", GREET = "wave", GREETINGS = "wave", WELCOME = "wave",
    HUG = "hug", KISS = "hug", LOVE = "hug", CUDDLE = "hug",
    THANK = "thank", THANKS = "thank",
    DANCE = "dance", CHEER = "dance", LAUGH = "dance",
    CRY = "cry", SIGH = "cry",
    SLEEP = "sleep", YAWN = "sleep",
}
local MIENE = { wave = "happy", hug = "shy", thank = "overjoyed", dance = "amused",
                cry = "concerned", sleep = "hmm" }

local emoteN = 0                        -- Antworten in dieser Sitzung
local letztesToken, letztesTokenT, letztesTokenFrei = nil, 0, false

local function emoteAntwort(gruppe)
    if emoteN >= EMOTE_MAX then return false end
    if imKampf() or (ns.Regie and ns.Regie.imKampf) then return false end
    if inGruppe() then return false end
    if tot() or afk() then return false end
    -- Der fluechtige Tag "emote" laesst die getaggten EMOTE-Zeilen greifen (wenn: {emote: "hug"}).
    if ns.Stimmung and ns.Stimmung.fluechtig then ns.Stimmung.fluechtig({ emote = gruppe }) end
    local ok = meldeRitual("EMOTE", { key = gruppe })
    if ns.Stimmung and ns.Stimmung.fluechtig then ns.Stimmung.fluechtig(nil) end
    if not ok then return false end
    emoteN = emoteN + 1
    -- Miene je Gruppe: das Ereignis hat nur EINE Miene in phrasen.lua, ein weinendes Emote
    -- braucht aber kein froehliches Gesicht.
    if ns.Gestalt and ns.Gestalt.miene and MIENE[gruppe] then
        pcall(ns.Gestalt.miene, MIENE[gruppe], 8)
    end
    return true
end

local function emoteToken(token, unit)
    -- IMMER zuerst loeschen: ein Token, das liegen bleibt, wuerde sonst ein spaeteres,
    -- gar nicht gemeintes Emote beantworten (gefunden im Harness).
    letztesToken = nil
    if unit then return end                                         -- galt jemand anderem
    local g = GRUPPEN[tostring(token or ""):upper()]
    if not g then return end
    letztesToken, letztesTokenT = g, jetzt()
    letztesTokenFrei = not (UnitExists and UnitExists("target"))
end
R.emote = emoteToken

-- CHAT_MSG_TEXT_EMOTE: arg2 = Absender, arg5 = Zielname, arg12 = GUID des Absenders.
ns.on("CHAT_MSG_TEXT_EMOTE", function(text, sender, _, _, ziel, _, _, _, _, _, _, guid)
    local meine = UnitGUID and UnitGUID("player")
    if not meine or guid ~= meine then return end                   -- nicht von mir: raus
    -- Ab hier ist es MEIN Emote: das gemerkte Token ist damit verbraucht, egal wie es ausgeht.
    local g = letztesToken
    letztesToken = nil
    if ziel and ziel ~= "" and sender and ziel ~= sender then return end  -- galt jemand anderem
    if not g then return end
    if jetzt() - letztesTokenT > EMOTE_FENSTER then return end
    if not letztesTokenFrei then return end
    emoteAntwort(g)
end)

-- ---------------------------------------------------------------- Lagerfeuer
-- Der Kochfeuer-Buff ist in Classic Era nicht sicher belegt (companion-v3 A.8 markiert die
-- Spell-ID ausdruecklich als [unsicher]). Darum drei Wege nebeneinander, alle billig:
--   1) Namensabgleich gegen eine kuratierte Liste (Muster aus Sinne/Alltag.lua BUFF_WEG),
--   2) Spell-IDs, soweit bekannt,
--   3) GetSpellInfo(818) ("Basic Campfire") holt den lokalisierten Namen zur Laufzeit,
--      und UNIT_SPELLCAST_SUCCEEDED auf den eigenen Zauber ist die Flanke, die in Era sicher kommt.
local FEUER_IDS = { [818] = true, [43286] = true, [43869] = true, [46163] = true }
local FEUER_NAMEN = {
    ["Cozy Fire"] = true, ["Cooking Fire"] = true, ["Basic Campfire"] = true, ["Campfire"] = true,
    ["Kochfeuer"] = true, ["Lagerfeuer"] = true, ["Einfaches Lagerfeuer"] = true,
    ["Gem\195\188tliches Feuer"] = true,
}

-- PORT (0.9.0): ueber ns.Compat.zauberName statt direkt GetSpellInfo. Auf Retail/Forever gibt
-- C_Spell.GetSpellInfo eine TABELLE zurueck — der alte type(name) == "string"-Test haette dort
-- nie gegriffen, der Lagerfeuer-Sinn haette sich also nur auf die fest verdrahtete Namensliste
-- verlassen (und auf einer franzoesischen oder russischen Fassung gar nichts gefunden).
-- Im Forever-Beta-UI gibt es uebrigens KEINE Camping-API (kein Treffer fuer Camp*/Bonfire in
-- 5058 Dateien) — der Kochfeuer-Buff bleibt also auch dort der Weg.
local function feuerNamenLernen()
    for id in pairs(FEUER_IDS) do
        local name = ns.Compat.zauberName(id)
        if name then FEUER_NAMEN[name] = true end
    end
end

local feuerSeit = 0                     -- GetTime, ab wann das Feuer steht; 0 = keins
local lagerGesagt = false

local function feuerAktiv()
    if not (ns.Compat and ns.Compat.auraByIndex) then return false end
    for i = 1, 40 do
        local ok, a = pcall(ns.Compat.auraByIndex, "player", i, "HELPFUL")
        if not ok or not a then break end
        if (a.spellId and FEUER_IDS[a.spellId]) or (a.name and FEUER_NAMEN[a.name]) then return true end
    end
    return false
end

local function feuerFlanke()
    local da = feuerAktiv()
    if da and feuerSeit == 0 then
        feuerSeit = jetzt()
    elseif (not da) and feuerSeit > 0 then
        feuerSeit = 0
    end
end

local function lagerPruefen()
    if lagerGesagt or feuerSeit == 0 then return false end
    if jetzt() - feuerSeit < LAGER_STAND then return false end
    if imKampf() or tot() or afk() then return false end
    if meldeRitual("LAGERFEUER", { key = "feuer" }) then
        lagerGesagt = true
        return true
    end
    return false
end

ns.onUnit("UNIT_AURA", "player", function(unit)
    if unit and unit ~= "player" then return end
    feuerFlanke()
end)

-- Reserve: der eigene Zauber. In Era feuert das sicher, auch wenn es gar keinen Buff gibt.
ns.onUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(unit, _, spellId)
    if unit and unit ~= "player" then return end
    if spellId and FEUER_IDS[spellId] then feuerSeit = jetzt() end
end)

-- ---------------------------------------------------------------- Ticker
local ticker = nil

local function tick()
    -- Tagwechsel zuerst: an einem neuen Kalendertag koennen Fest, Jahrestag und Gedenken
    -- mitten in der Sitzung faellig werden. spaetGesagt bleibt stehen - SPAET ist 1x je SITZUNG.
    local heute = dat("%Y%m%d")
    local wechsel = R.tagMerker and R.tagMerker ~= heute
    R.tagMerker = heute
    if wechsel then
        if not gedenkenPruefen() then
            if not jahrestagPruefen() then feiertagPruefen() end
        end
    end
    spaetPruefen()
    lagerPruefen()
end

local function tickerStart()
    if ticker then return end
    R.tagMerker = dat("%Y%m%d")
    ticker = ns.Compat.NewTicker(TICK, function()
        local ok, err = pcall(tick)
        if not ok then ns.debug("Rituale tick: " .. tostring(err)) end
    end)
end

-- ---------------------------------------------------------------- Dialog-Aktionen
-- rituale_dialog.lua kennt nur Strings; die Aktionen haengen wir hier ein (Muster aus
-- Sinne/Bruecken.lua). UI/Dialog.lua bleibt unangetastet.
local function knotenVars()
    local z = ns.Stimmung and ns.Stimmung.zustand() or {}
    local h = ns.Stimmung and ns.Stimmung.stunde() or 12
    return {
        uhr = ("%02d:%02d"):format(h, tonumber(dat("%M")) or 0),
        stunden = ("%.0f"):format(z.stunden or 0),
        stufe = tostring(z.vertraut or 0),
        sitzung = ("%d"):format(math.floor((z.sitzung or 0) * 60)),
    }
end

local ZEIT_KNOTEN = { frueh = "rit_zeit_frueh", tag = "rit_zeit_tag", abend = "rit_zeit_abend",
                      nacht = "rit_zeit_nacht", spaet = "rit_zeit_spaet" }
local VERTRAUT_KNOTEN = { [0] = "rit_lange_0", [1] = "rit_lange_1", [2] = "rit_lange_2", [3] = "rit_lange_3" }
local LAUNE_KNOTEN = { gut = "rit_laune_gut", neutral = "rit_laune_neutral", besorgt = "rit_laune_besorgt" }

local function aktionenRegistrieren()
    if not (ns.Dialog and type(ns.Dialog.aktionen) == "table") then return end
    local A = ns.Dialog.aktionen
    A.rit_zeit = function()
        local z = ns.Stimmung and ns.Stimmung.zustand()
        return ZEIT_KNOTEN[z and z.zeit or "tag"] or "rit_zeit_tag", knotenVars()
    end
    A.rit_wielange = function()
        local v = ns.Stimmung and ns.Stimmung.vertraut() or 0
        return VERTRAUT_KNOTEN[v] or "rit_lange_0", knotenVars()
    end
    A.rit_erinnerst = function()
        local ok, e = pcall(R.erinnerung)
        if not (ok and e) then return "rit_erinnert_nichts", knotenVars() end
        local v = knotenVars()
        v.erinnerung = e
        erinnerungVerbraucht = true
        return "rit_erinnert", v
    end
    A.rit_stimmung = function()
        local z = ns.Stimmung and ns.Stimmung.zustand()
        return LAUNE_KNOTEN[z and z.laune or "neutral"] or "rit_laune_neutral", knotenVars()
    end
    ns.debug("Rituale: Dialog-Aktionen registriert")
end

-- ---------------------------------------------------------------- Ereignisse
ns.on("PLAYER_LOGIN", function()
    ladeDB()
    meldeWrappen()
    aktionenRegistrieren()
    feuerNamenLernen()
    warAfk = afk()
    -- DoEmote ist in Era regulaer hookbar (kein Hardware-Event-Schutz); auf Retail 12.0.0 ist es
    -- deprecated. type()-Pruefung statt Annahme - der CHAT_MSG-Weg traegt auch ohne Hook.
    if type(DoEmote) == "function" and type(hooksecurefunc) == "function" then
        pcall(hooksecurefunc, "DoEmote", function(token, unit) pcall(emoteToken, token, unit) end)
    end
    if type(hooksecurefunc) == "function" then
        if type(Logout) == "function" then pcall(hooksecurefunc, "Logout", function() pcall(abschied) end) end
        if type(Quit) == "function" then pcall(hooksecurefunc, "Quit", function() pcall(abschied) end) end
    end
end)

local ersterPEW = true
ns.on("PLAYER_ENTERING_WORLD", function()
    if not RIT then ladeDB() end
    meldeWrappen()
    aktionenRegistrieren()
    tickerStart()
    feuerSeit = 0
    if not ersterPEW then return end
    ersterPEW = false
    -- Hoechstens EIN Ritual je Login (alle drei sind "plauder", der Regie-Abstand wuerde die
    -- anderen ohnehin schlucken - wir planen darum gleich nur eines).
    -- Priorisiert: Gedenken > Jahrestag > Fest (companion-v3 D.1 W1-5).
    ns.Compat.After(PLAN_VERZUG, function()
        local fn, wann = nil, nil
        pcall(gedenkSuchen)
        if gedenkHeute then fn, wann = gedenkenPruefen, GEDENK_VERZUG
        elseif jahrestagFaellig() then fn, wann = jahrestagPruefen, JAHR_VERZUG
        elseif R.festJetzt() then fn, wann = feiertagPruefen, FEIER_VERZUG end
        if not fn then return end
        -- REVIEW5: den Platz von der Regie holen statt eine feste Sekundenzahl zu nehmen. Review 4
        -- hat genau dafuer ns.Regie.loginSlot gebaut: LOGIN/WIEDERKEHR, TAG_ERSTER, ERBE_VORGAENGER,
        -- ERBE_WORTE und DEBRIEF haben ihre Plaetze schon gebucht, als dieser Code laeuft (PEW +45 s).
        -- Vorher landete FEIERTAG fest bei +55 s, 24 s hinter TAG_ERSTER, und schob ERBE_VORGAENGER
        -- in den Nachhol (im Harness reproduziert). Der Wunsch bleibt "nicht vor ...".
        local ab = math.max(1, wann - PLAN_VERZUG)
        local verzug = ab
        if ns.Regie and ns.Regie.loginSlot then
            local ok, v = pcall(ns.Regie.loginSlot, ab)
            if ok and type(v) == "number" then verzug = v end
        end
        ns.Compat.After(math.max(1, verzug), function() pcall(fn) end)
    end)
end)

ns.on("PLAYER_LOGOUT", function()
    if not RIT then return end
    RIT.letzteSitzung = unix()
end)

function R.stand()
    return RIT, R.festJetzt(), gedenkHeute, emoteN, spaetGesagt, lagerGesagt, erinnerungVerbraucht
end
