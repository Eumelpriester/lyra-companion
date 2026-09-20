-- Sinne/Details.lua — Bruecke zu Details! (Welle 3). NUR LESEND, nur der EIGENE Wert.
--
-- Lyra baut keinen zweiten Schadensmesser. Details zeigt Zahlen, laufend, sortiert, fuer alle -
-- das kann sie besser, und Lyra hat dazu nichts zu sagen. Was Details NICHT hat, ist ein
-- Gedaechtnis mit einer Meinung: "heute 30 % ueber deinem Schnitt", "du hast mehr eingesteckt
-- als sonst". Genau das ist diese Datei. Ein Satz nach einem langen Kampf, hoechstens einer,
-- hoechstens alle zehn Minuten.
--
-- Ereignisse: KAMPF_REKORD (existiert seit Welle 2, hier erweitert um {prozent}),
--   KAMPF_SCHNITT (mit {prozent}, optional {unterbrechungen}), SCHADEN_ERLITTEN_HOCH ({prozent}).
--   Alle plauder. Je Kampf hoechstens EINES, in dieser Rangfolge.
-- Schalter: "detailsKommentar" (Account, Default an). Aus = diese Datei rechnet nicht einmal.
-- Speicher: LyraGestaltDB.chronik[charKey].details (v, n, dpsSumme, dpsRekord, erlittenSumme,
--   unterbrechungen, letzteDps, letzteZeit). Nur eigene Zahlen, nie ein Name.
--
-- Fremd-API (Details, alles hinter Existenzpruefung + pcall; Belege aus dem installierten Addon):
--   Details:GetCurrentCombat()                  Details/classes/container_segments.lua:39
--   combat:GetActor(attribut, name)             Details/classes/class_combat.lua:900
--   combat:GetCombatTime()                      Details/classes/class_combat.lua:947 (min 0.1)
--   combat:GetTotal(1, nil, true)               Details/classes/class_combat.lua:1137 (Gruppensumme)
--   Details.playername                          Details/core/parser.lua:6700-6707 (ggf. mit Realm)
--   DETAILS_ATTRIBUTE_DAMAGE = 1, DETAILS_ATTRIBUTE_MISC = 4   Details/API.lua:103-106
--   Akteur-Felder: .total (Schaden), .damage_taken (Details/classes/class_damage.lua:453),
--   .interrupt (Misc-Akteur, Details/classes/class_utility.lua:2270)
--
-- PRIVATSPHAERE (Grenze B, hart): gelesen wird AUSSCHLIESSLICH der Akteur mit dem eigenen Namen
--   und die NAMENLOSE Gruppensumme. Es wird nie ueber die Akteursliste iteriert, nie ein fremder
--   Akteur geholt, nie ein fremder Wert gespeichert oder ausgegeben. Der eigene Anteil an der
--   Gruppensumme ist eine Prozentzahl ohne jeden Namen darin.
-- Blizzard-API (nur lesend): GetTime, UnitName, IsInGroup/IsInRaid.
-- Events: PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED, PLAYER_ENTERING_WORLD.
--
-- PORT (0.9.0): Diese Datei braucht auf Retail/Forever KEINE Zeile Aenderung, und der Grund ist
-- die Entscheidung von Welle 3: Lyra baut keinen zweiten Schadensmesser. Sie dockt an Details an
-- und liest ein fertiges Segment. Details liest den Combat-Log selbst — auf Retail ueber
-- C_CombatLog/den erlaubten Weg, und ob es das kann, ist Details' Problem, nicht unseres.
-- Lyra registriert hier NICHTS am Combat-Log und rechnet mit keinem Wert einer fremden Einheit;
-- die Zahlen, die hier ankommen, sind gewoehnliche Lua-Zahlen aus Details' eigener Tabelle und
-- damit keine Secret Values. Jeder Zugriff steht ohnehin hinter Existenzpruefung und pcall.
-- Praktisch heisst das: gibt es Details auf dem Client, sagt Lyra ihren Satz; gibt es Details
-- nicht, passiert nichts. Auf Retail hat Details eine eigene Mainline-Fassung — mehr muessen wir
-- nicht wissen. Dasselbe gilt fuer Sinne/DBM.lua.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local D = {}
ns.Sinne.Details = D
ns.DetailsSinn = D              -- Sinne/Bruecken2.lua liest das und laesst seinen Details-Block dann aus

D.MIN_DAUER   = 20              -- s: kuerzere Kaempfe sind keine Nachricht wert (wie Sinne/Kampf.lua)
D.LESE_VERZUG = 2               -- s: Details schliesst das Segment erst nach dem Kampfende ab
D.MIN_DPS     = 5               -- unter diesem Wert ist jede Aussage Unsinn (Angeln, Dummy-Tick)
D.REKORD_PLUS = 1.10            -- neuer Rekord erst ab +10 % (wie Welle 2)
D.SCHNITT_AB  = 5               -- so viele gemessene Kaempfe, bevor von "Schnitt" geredet wird
D.SCHNITT_HOCH = 1.25           -- ab +25 % ueber dem Schnitt sagt sie etwas
D.ERLITTEN_HOCH = 1.60          -- ab +60 % ueber dem erlittenen Schnitt
D.UNTERBRECHUNG_AB = 2          -- ab so vielen Unterbrechungen darf die Zeile sie nennen

-- ---------------------------------------------------------------------------------------------
-- Kleinkram
-- ---------------------------------------------------------------------------------------------
local function jetzt() return (GetTime and GetTime()) or 0 end
local function an() return ns.Get("detailsKommentar") ~= false end

local function melde(id, vars)
    if not ns.melde then return false end
    local ok, v = pcall(ns.melde, id, vars)
    return (ok and v) and true or false
end

-- Details ist da UND benutzbar? Details und _detalhes sind dieselbe Tabelle (Details/boot.lua:9,12),
-- wir nehmen Details. GetCurrentCombat kann nil liefern (kein Segment) - das faengt lesen().
local function detailsDa()
    return (type(Details) == "table" and type(Details.GetCurrentCombat) == "function") and true or false
end
D.da = detailsDa

-- Eigener Akteursname. Details haengt auf manchen Realms "-Realm" an (parser.lua:6700) und
-- entschaerft das dann selbst mit Ambiguate - wir probieren beide Schreibweisen.
local function eigeneNamen()
    local liste = {}
    if type(Details) == "table" and type(Details.playername) == "string" and Details.playername ~= "" then
        liste[#liste + 1] = Details.playername
    end
    local n = UnitName and UnitName("player")
    if type(n) == "string" and n ~= "" then liste[#liste + 1] = n end
    return liste
end

-- Akteur aus einem Container holen. NUR mit dem eigenen Namen - es gibt hier keinen Weg,
-- an einen fremden Akteur zu kommen, auch nicht versehentlich.
local function eigenerAkteur(combat, attribut)
    if type(combat) ~= "table" or type(combat.GetActor) ~= "function" then return nil end
    for _, name in ipairs(eigeneNamen()) do
        local ok, a = pcall(combat.GetActor, combat, attribut, name)
        if ok and type(a) == "table" then return a end
    end
    return nil
end

local function zahl(v)
    v = tonumber(v)
    if not v or v ~= v or v < 0 then return nil end     -- v ~= v faengt NaN
    return v
end

local function prozent(ist, soll)
    if not (ist and soll) or soll <= 0 then return nil end
    return math.floor((ist / soll - 1) * 100 + 0.5)
end

-- ---------------------------------------------------------------------------------------------
-- Speicher
-- ---------------------------------------------------------------------------------------------
local function speicher(anlegen)
    local c = LyraGestaltDB and ns.charKey and LyraGestaltDB.chronik and LyraGestaltDB.chronik[ns.charKey]
    if type(c) ~= "table" then return nil end
    if type(c.details) ~= "table" then
        if not anlegen then return nil end
        c.details = { v = 1, n = 0, dpsSumme = 0, dpsRekord = 0, erlittenSumme = 0, unterbrechungen = 0 }
    end
    local s = c.details
    -- Ein Feld, das jemand von Hand kaputtgemacht hat, darf die Rechnung nicht vergiften.
    s.n = tonumber(s.n) or 0
    s.dpsSumme = tonumber(s.dpsSumme) or 0
    s.dpsRekord = tonumber(s.dpsRekord) or 0
    s.erlittenSumme = tonumber(s.erlittenSumme) or 0
    s.unterbrechungen = tonumber(s.unterbrechungen) or 0
    -- Welle 2 (Sinne/Bruecken2.lua) hat den Rekord in c.rekordDps geschrieben. Uebernehmen,
    -- damit der erste Kampf nach dem Update nicht faelschlich "neuer Rekord" ruft.
    local alt = tonumber(c.rekordDps)
    if alt and alt > s.dpsRekord then s.dpsRekord = alt end
    return s
end
D.speicher = speicher

-- ---------------------------------------------------------------------------------------------
-- Messen
-- ---------------------------------------------------------------------------------------------
local kampfStart = nil
D.letzte = nil                  -- letzte Messung (fuer /lyra details), rein lesend

-- Kampfdauer: Details' eigene Zeit ist genauer als unsere Uhr (sie zieht die Leerlaufzeit ab),
-- aber sie kann 0.1 sein, wenn das Segment nicht zu uns gehoert. Dann unsere Uhr.
local function dauerVon(combat, eigen)
    if type(combat) == "table" and type(combat.GetCombatTime) == "function" then
        local ok, t = pcall(combat.GetCombatTime, combat)
        t = zahl(ok and t)
        if t and t >= D.MIN_DAUER then return t end
    end
    return eigen
end

local function lesen(eigenDauer)
    if not detailsDa() then return nil end
    local ok, combat = pcall(Details.GetCurrentCombat, Details)
    if not ok or type(combat) ~= "table" then return nil end
    local schaden = eigenerAkteur(combat, DETAILS_ATTRIBUTE_DAMAGE or 1)
    if not schaden then return nil end
    local total = zahl(schaden.total)
    if not total then return nil end
    local dauer = dauerVon(combat, eigenDauer)
    if not dauer or dauer < D.MIN_DAUER then return nil end
    local m = {
        dauer = dauer,
        dps = total / dauer,
        erlitten = zahl(schaden.damage_taken) or 0,
    }
    -- Unterbrechungen liegen am Misc-Akteur (derselbe Name, derselbe Weg).
    local misc = eigenerAkteur(combat, DETAILS_ATTRIBUTE_MISC or 4)
    m.unterbrechungen = misc and (zahl(misc.interrupt) or 0) or 0
    -- Anteil an der Gruppensumme: eine NAMENLOSE Summe. Nur in Gruppe ueberhaupt interessant.
    if type(combat.GetTotal) == "function" and ((IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid())) then
        local ok2, gruppe = pcall(combat.GetTotal, combat, DETAILS_ATTRIBUTE_DAMAGE or 1, nil, true)
        gruppe = zahl(ok2 and gruppe)
        if gruppe and gruppe > 0 and total <= gruppe then
            m.anteil = math.floor(total / gruppe * 100 + 0.5)
        end
    end
    if m.dps < D.MIN_DPS then return nil end
    return m
end
D.lesen = lesen

-- Der Satz. Genau einer, und die Rangfolge ist Absicht: ein Rekord schlaegt alles, ein
-- ungewoehnlich hoher Schaden am eigenen Leib schlaegt die Schnitt-Bemerkung.
local function bewerten(m, s)
    local schnittDps = (s.n >= D.SCHNITT_AB) and (s.dpsSumme / s.n) or nil
    local schnittErl = (s.n >= D.SCHNITT_AB) and (s.erlittenSumme / s.n) or nil
    local vars = { dps = math.floor(m.dps + 0.5) }
    if m.unterbrechungen >= D.UNTERBRECHUNG_AB then vars.unterbrechungen = m.unterbrechungen end
    if m.anteil then vars.anteil = m.anteil end

    if m.dps > s.dpsRekord * D.REKORD_PLUS then
        -- {prozent} = wie weit ueber dem ALTEN Rekord. Beim allerersten Rekord gibt es keinen
        -- Vergleich; dann bleibt der Platzhalter weg und die Regie waehlt eine Zeile ohne ihn.
        if s.dpsRekord > 0 then vars.prozent = prozent(m.dps, s.dpsRekord) end
        return "KAMPF_REKORD", vars
    end
    if schnittErl and m.erlitten > schnittErl * D.ERLITTEN_HOCH then
        vars.prozent = prozent(m.erlitten, schnittErl)
        return "SCHADEN_ERLITTEN_HOCH", vars
    end
    if schnittDps and m.dps > schnittDps * D.SCHNITT_HOCH then
        vars.prozent = prozent(m.dps, schnittDps)
        return "KAMPF_SCHNITT", vars
    end
    -- Nichts Besonderes: schweigen. Das ist der haeufigste Fall und der wichtigste.
    return nil
end
D.bewerten = bewerten

local function nachKampf(eigenDauer)
    local m = lesen(eigenDauer)
    if not m then return end
    local s = speicher(true)
    if not s then return end
    local id, vars = bewerten(m, s)
    -- Erst bewerten (der Vergleich braucht den Stand VOR diesem Kampf), dann fortschreiben.
    s.n = s.n + 1
    s.dpsSumme = s.dpsSumme + m.dps
    s.erlittenSumme = s.erlittenSumme + m.erlitten
    s.unterbrechungen = s.unterbrechungen + m.unterbrechungen
    if m.dps > s.dpsRekord then s.dpsRekord = m.dps end
    s.letzteDps = math.floor(m.dps + 0.5)
    s.letzteZeit = (time and time()) or 0
    D.letzte = m
    if not id then return end
    -- Wie Welle 2 (Sinne/Bruecken2.lua, REVIEW6B): KAMPF_AUS steht zu diesem Zeitpunkt schon in
    -- der Blase, der Plauder-Abstand haette diese Zeile sonst gefressen. Also den Rest des
    -- Abstands abwarten - und zum Sprechzeitpunkt noch einmal pruefen, ob die Lage passt.
    local verzug = 1
    if ns.Regie and ns.Regie.abstandRest then
        local ok, rest = pcall(ns.Regie.abstandRest)
        if ok and type(rest) == "number" then verzug = rest + 2 end
    end
    -- Und die Stillhalte-Regel abwarten (Sinne/DBM.lua): nach einem Bosskampf laeuft die
    -- nachgelegte Ruhe noch ein paar Sekunden. Ohne das plant sich diese Zeile selbst weg.
    if ns.BossBruecke and ns.BossBruecke.ruheRest then
        local ok, rest = pcall(ns.BossBruecke.ruheRest)
        if ok and type(rest) == "number" and rest + 1 > verzug then verzug = rest + 1 end
    end
    ns.Compat.After(math.max(1, verzug), function()
        if ns.Regie and ns.Regie.imKampf then return end                      -- schon wieder im Kampf
        if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end  -- tot: die Regie schweigt ohnehin
        melde(id, vars)
    end)
end

ns.on("PLAYER_REGEN_DISABLED", function()
    if not an() then kampfStart = nil; return end
    kampfStart = jetzt()
end)

ns.on("PLAYER_REGEN_ENABLED", function()
    local start = kampfStart
    kampfStart = nil
    if not start or not an() then return end
    local dauer = jetzt() - start
    if dauer < D.MIN_DAUER then return end
    ns.Compat.After(D.LESE_VERZUG, function()
        local ok, err = pcall(nachKampf, dauer)
        if not ok then ns.debug("Details: " .. tostring(err)) end
    end)
end)

ns.on("PLAYER_ENTERING_WORLD", function() kampfStart = nil end)

-- ---------------------------------------------------------------------------------------------
-- /lyra details
-- ---------------------------------------------------------------------------------------------
local TEXT = {
    de = {
        kopf   = "Details:",
        weg    = "  Details ist nicht da. Ohne das Addon rechne ich hier nichts.",
        aus    = "  Kommentar abgeschaltet (/lyra details an).",
        leer   = "  Noch kein Kampf ueber %d Sekunden gemessen.",
        n      = "  %d gemessene Kaempfe.",
        schnitt= "  Schaden pro Sekunde: Schnitt %d, Rekord %d.",
        erl    = "  Erlittener Schaden im Schnitt: %d je Kampf.",
        unt    = "  Unterbrechungen insgesamt: %d.",
        letzte = "  Letzter Kampf: %d Schaden pro Sekunde.",
        anteil = "  Dein Anteil am Gruppenschaden im letzten Kampf: %d %%.",
        privat = "  Ich lese aus Details nur deinen eigenen Wert und die namenlose Gruppensumme.",
    },
    en = {
        kopf   = "Details:",
        weg    = "  Details isn't here. Without the addon I compute nothing.",
        aus    = "  Comment switched off (/lyra details on).",
        leer   = "  No fight longer than %d seconds measured yet.",
        n      = "  %d fights measured.",
        schnitt= "  Damage per second: average %d, record %d.",
        erl    = "  Damage taken on average: %d per fight.",
        unt    = "  Interrupts in total: %d.",
        letzte = "  Last fight: %d damage per second.",
        anteil = "  Your share of group damage last fight: %d%%.",
        privat = "  From Details I read only your own value and the nameless group total.",
    },
}
local function T() return TEXT[ns.sprache()] or TEXT.en end

function D.status()
    local t = T()
    local out = { t.kopf }
    if not detailsDa() then out[#out + 1] = t.weg end
    if not an() then out[#out + 1] = t.aus end
    local s = speicher(false)
    if not s or s.n == 0 then
        out[#out + 1] = t.leer:format(D.MIN_DAUER)
        out[#out + 1] = t.privat
        return out
    end
    out[#out + 1] = t.n:format(s.n)
    out[#out + 1] = t.schnitt:format(math.floor(s.dpsSumme / s.n + 0.5), math.floor(s.dpsRekord + 0.5))
    out[#out + 1] = t.erl:format(math.floor(s.erlittenSumme / s.n + 0.5))
    if s.unterbrechungen > 0 then out[#out + 1] = t.unt:format(s.unterbrechungen) end
    if s.letzteDps then out[#out + 1] = t.letzte:format(s.letzteDps) end
    if D.letzte and D.letzte.anteil then out[#out + 1] = t.anteil:format(D.letzte.anteil) end
    out[#out + 1] = t.privat
    return out
end

function D.stand() return speicher(false), D.letzte, detailsDa(), an() end
