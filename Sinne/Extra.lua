-- Sinne/Extra.lua — Feature-Welle 1: Runner-Warner, Dungeon-Reisecheck, Ruhestein-Bereitschaft,
--   Erinnerungsfoto, Ultra-Modus (Miene = Lebensbalken), Test-Modus. Doku: Sinne/EXTRA.md.
-- Ereignisse: RUNNER, RUNNER_BEKANNT, REISECHECK, RUHESTEIN, FOTO, ULTRA_TIEF (still), TEST (nur /lyra test).
-- API (nur lesend): UnitGUID/UnitName/UnitExists/UnitIsPlayer/UnitPlayerControlled/UnitCanAttack,
--   UnitIsDeadOrGhost, UnitAffectingCombat, UnitHealth/UnitHealthMax, UnitClass, IsInInstance,
--   C_NamePlate.GetNamePlates, ns.Compat.Container (Taschen, Item-Cooldown), GetItemCooldown (Fallback),
--   GetInventoryItemDurability, GetInventoryItemCount, GetTime, time. Screenshot() (nicht protected).
-- Events: CHAT_MSG_MONSTER_EMOTE, PLAYER_TARGET_CHANGED, PLAYER_ENTERING_WORLD, PLAYER_REGEN_DISABLED/ENABLED,
--   UNIT_HEALTH (player), PLAYER_DEAD + Hook ns.nachAusgabe (Ruhestein, Foto).
-- PORT (0.9.0): IsInInstance ist auf allen fuenf Clients identisch (Rueckgabe drin, art) und
--   steht hier schon in pcall. Der Reisecheck selbst liest Taschen ueber ns.Compat.Container und
--   ist damit client-neutral; NUR Reagenzien und Munition sind Inhalts-, nicht API-Fragen und
--   haengen jetzt an ns.Compat.F.klassischeAusruestung (siehe X.reisecheckFehlt). Ultra-Modus
--   und Erinnerungsfoto lesen ausschliesslich Spieler-HP (unter Secret Values lesbar) bzw.
--   rufen Screenshot() — das ist keine protected function und geht ueberall.
-- Grenzen: Runner nur, wenn das Emote vom eigenen Ziel oder einem feindlichen Nameplate kommt (GUID-Vergleich,
--   UnitIsPlayer-Sperre zuerst); Bestiarium-Eintrag nur fuer Creature-GUIDs. Kein SendChatMessage, keine Namen
--   anderer Spieler. Der Test-Modus setzt nur Regie-Sperren zurueck, er umgeht keine Grenze.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local X = {}
ns.Sinne.Extra = X

-- REVIEW4: 12 s waren nur 5 s hinter INSTANZ_AN (Sinne/Chronik.lua, +7) - zwei Plauder-Zeilen so
-- dicht hintereinander schneiden sich gegenseitig ab. 16 s haelt den Mindestabstand von 8 s ein.
local REISE_VERZUG = 16           -- s nach PLAYER_ENTERING_WORLD in die Instanz (INSTANZ_AN kommt bei +7)
local REISE_TRAENKE, REISE_VERBAENDE, REISE_MUNITION, REISE_DURA = 3, 5, 200, 50
local RUHESTEIN_ID, RUHESTEIN_MIN_REST = 6948, 300
local RUHESTEIN_VERZUG = 4        -- s hinter der Warnung, sonst schneidet die Stimme die Warn-Zeile ab
local FOTO_VERZUG, FOTO_ABSTAND = 1.5, 120
local ULTRA_TIEF_ABSTAND = 5
local TEST_TAKT = 4
local NACHHOL = 35                -- s: zweiter Versuch fuer Plauder-Zeilen, die der Regie-Abstand frisst

local function jetzt() return GetTime() end
local function unix() return time() end
local function tot() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false end
local function imKampf() return UnitAffectingCombat and UnitAffectingCombat("player") or false end

-- NPC-Typ-ID aus einer GUID (Feld 6). Nur Kreaturen; Player-/Pet-/Vehicle-GUIDs -> nil.
local function npcIdAus(guid)
    if type(guid) ~= "string" then return nil end
    return guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
end

-- Feindlicher NPC als Einheit? Grenze B: UnitIsPlayer als Erstes.
local function feindNpc(unit)
    if not (UnitExists and UnitExists(unit)) then return nil end
    if UnitIsPlayer and UnitIsPlayer(unit) then return nil end
    if UnitPlayerControlled and UnitPlayerControlled(unit) then return nil end
    if not (UnitCanAttack and UnitCanAttack("player", unit)) then return nil end
    local guid = UnitGUID and UnitGUID(unit)
    local id = npcIdAus(guid)
    if not id then return nil end
    local name = UnitName and UnitName(unit)
    if not name or name == "" then return nil end
    return id, name, guid
end

-- Chronik-Tabelle dieses Charakters (nur lesen/ergaenzen, nie anlegen ausser bestiarium-Untertabelle).
local function chronikDB()
    local c = LyraGestaltDB and LyraGestaltDB.chronik and ns.charKey and LyraGestaltDB.chronik[ns.charKey]
    return type(c) == "table" and c or nil
end

-- Plauder-Zeile mit EINEM Nachhol (Muster aus Chronik.lua): REISECHECK kommt 5 s nach INSTANZ_AN,
-- RUHESTEIN 4 s nach einer Warnung — beides faellt sonst dem Regie-Abstand zum Opfer.
local function meldeNachhol(id, vars, gilt)
    if ns.melde(id, vars) then return true end
    if not (C_Timer and C_Timer.After) then return false end
    -- Nur nachlegen, wenn der Abstand der Grund war (Drossel/Gruppe/Still-Modus sind endgueltig).
    local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
    if not (d and d[2] == id and d[1] == "abstand") then return false end
    local rest = (ns.Regie and ns.Regie.abstandRest and ns.Regie.abstandRest()) or 0
    ns.Compat.After(math.max(NACHHOL, math.min(rest + 1, 180)), function()
        if gilt and not gilt() then return end
        ns.melde(id, vars)
    end)
    return false
end

-- ---------------------------------------------------------------- Runner-Warner
-- Emote-Text: Classic liefert bei CHAT_MSG_MONSTER_EMOTE den Rohtext MIT "%s" (ChatFrame formatiert erst
-- spaeter mit dem Namen) — wir matchen daher nur auf den Kern des Satzes, in beiden Sprachen.
-- Eine globale Konstante fuer den Flucht-Emote gibt es nicht (Server-Text); CHAT_FLEE wird trotzdem
-- guarded gelesen, falls ein Client sie einfuehrt.
local RUNNER_MUSTER = {}
do
    local function hinzu(s)
        if type(s) ~= "string" or s == "" then return end
        s = s:lower():gsub("%%%d?%$?s", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("[!%.]+$", "")
        if s ~= "" then RUNNER_MUSTER[#RUNNER_MUSTER + 1] = s end
    end
    hinzu(_G.CHAT_FLEE)
    hinzu("attempts to run away in fear")
    hinzu("versucht, vor angst wegzulaufen")
    hinzu("versucht vor angst wegzulaufen")
end

local function istFluchtEmote(text)
    if type(text) ~= "string" then return false end
    local t = text:lower()
    for _, m in ipairs(RUNNER_MUSTER) do
        if t:find(m, 1, true) then return true end
    end
    return false
end

-- Bestiarium-Eintrag mit "runner = true". Chronik exportiert keinen Anleger, daher dasselbe Feldset wie dort
-- (Chronik rechnet spaeter mit treffer/schaden/... als Zahlen — ein Minimal-Eintrag wuerde dort knallen).
local function runnerMerken(id, name)
    local c = chronikDB()
    if not c or not id then return end
    c.bestiarium = c.bestiarium or {}
    local e = c.bestiarium[id]
    if not e then
        e = { name = name, treffer = 0, schaden = 0, maxHit = 0, kaempfe = 0, beinahe = 0, tode = 0, t = unix() }
        c.bestiarium[id] = e
    elseif name and not e.name then
        e.name = name
    end
    e.runner = true
end

-- Passt das Emote zu Ziel oder einem feindlichen Nameplate? Rueckgabe npcID, name (oder nil).
local function runnerQuelle(guid, monsterName)
    -- 1) eigenes Ziel
    local id, name, zg = feindNpc("target")
    if id then
        if guid and zg == guid then return id, name end
        if not guid and monsterName and name == monsterName then return id, name end
    end
    -- 2) Nameplates
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, liste = pcall(C_NamePlate.GetNamePlates)
        if ok and type(liste) == "table" then
            for _, np in ipairs(liste) do
                local u = np and (np.namePlateUnitToken or (np.UnitFrame and np.UnitFrame.unit))
                if u then
                    local nid, nname, ng = feindNpc(u)
                    if nid then
                        if guid and ng == guid then return nid, nname end
                        if not guid and monsterName and nname == monsterName then return nid, nname end
                    end
                end
            end
        end
    end
    return nil
end

-- Args (Classic): text, monsterName, language, channelName, playerName2, specialFlags, zoneChannelID,
-- channelIndex, channelBaseName, unused, lineID, guid
ns.on("CHAT_MSG_MONSTER_EMOTE", function(text, monsterName, _, _, _, _, _, _, _, _, _, guid)
    if tot() then return end
    if not istFluchtEmote(text) then return end
    if type(guid) ~= "string" or guid == "" then guid = nil end
    local id, name = runnerQuelle(guid, monsterName)
    if not id then return end
    runnerMerken(id, name)
    ns.melde("RUNNER", { name = name, key = id })
end)

-- Anvisieren ausserhalb des Kampfs: bekannter Runner-Typ -> Vorwarnung.
ns.on("PLAYER_TARGET_CHANGED", function()
    if tot() or imKampf() then return end
    local id, name = feindNpc("target")
    if not id then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("target") then return end
    local c = chronikDB()
    local e = c and c.bestiarium and c.bestiarium[id]
    -- REVIEW3: Chronik.zielPruefe spricht zum selben Ziel (BESTIARIUM/RIVALE bei beinahe/tode >= 1) - dann
    -- nicht noch eine zweite Warn-Zeile obendrauf (Blase ersetzt, Stimme schneidet ab).
    if e and e.runner and (e.tode or 0) == 0 and (e.beinahe or 0) == 0 then
        ns.melde("RUNNER_BEKANNT", { name = name, key = id })
    end
end)

-- ---------------------------------------------------------------- Dungeon-Reisecheck
-- Heiltrank-Kette wie Alltag.lua (Minor bis Major); Verbaende Classic (Leinen bis Runenstoff, je normal/schwer).
local TRANK_IDS = { [118] = true, [858] = true, [929] = true, [1710] = true, [3928] = true, [13446] = true }
local VERBAND_IDS = {
    [1251] = true, [2581] = true, [3530] = true, [3531] = true, [6450] = true, [6451] = true,
    [8544] = true, [8545] = true, [14529] = true, [14530] = true,
}
-- MERGE 0.16.0 (21.09.2026, Welle 13d §5 Punkt 1): die zwei Listen werden herausgereicht.
-- Sinne/Welle13d.lua fuehrte sie bis zum Merge als Abschrift, weil Extra.lua einem anderen
-- Team gehoerte - und eine Abschrift driftet, sobald jemand hier eine Item-ID nachtraegt.
-- Herausgereicht werden NUR die IDs. Die SCHWELLEN ("ab wann fehlt etwas") bleiben hier und
-- kommen weiterhin allein aus X.reisecheckFehlt(); wer woanders nachschlaegt, darf wissen
-- WONACH, aber nicht selbst entscheiden, ob etwas fehlt.
-- Die Tabellen sind Mengen ([id] = true), nicht Listen - wer sie durchlaeuft, nimmt pairs().
X.TRANK_IDS   = TRANK_IDS
X.VERBAND_IDS = VERBAND_IDS
local RUNE_TELEPORT = 17031
local C = ns.Compat.Container

local function taschenLesbar()
    if not (C and C.GetContainerNumSlots) then return false end
    for bag = 0, 4 do
        local ok, n = pcall(C.GetContainerNumSlots, bag)
        if ok and (tonumber(n) or 0) > 0 then return true end
    end
    return false
end

-- Zaehlt in einem Durchgang: Traenke, Verbaende, Runen der Teleportation.
local function taschenZaehlen()
    local traenke, verbaende, runen = 0, 0, 0
    if not (C and C.GetContainerItemInfo) then return traenke, verbaende, runen end
    for bag = 0, 4 do
        local ok, slots = pcall(C.GetContainerNumSlots, bag)
        for slot = 1, (ok and tonumber(slots) or 0) do
            local ok2, info = pcall(C.GetContainerItemInfo, bag, slot)
            if ok2 and info and info.itemID then
                local n = info.stackCount or 1
                if TRANK_IDS[info.itemID] then traenke = traenke + n
                elseif VERBAND_IDS[info.itemID] then verbaende = verbaende + n
                elseif info.itemID == RUNE_TELEPORT then runen = runen + n end
            end
        end
    end
    return traenke, verbaende, runen
end

local function minHaltbarkeit()
    if not GetInventoryItemDurability then return -1 end
    local minPct = -1
    for slot = 1, 18 do
        local ok, cur, max = pcall(GetInventoryItemDurability, slot)
        if ok and cur and max and max > 0 then
            local pct = math.floor(cur / max * 100)
            if minPct < 0 or pct < minPct then minPct = pct end
        end
    end
    return minPct
end

local function klasse()
    if not UnitClass then return nil end
    local _, k = UnitClass("player")
    return k
end

local function munition()
    if not GetInventoryItemCount then return nil end
    local ok, n = pcall(GetInventoryItemCount, "player", 0)   -- Slot 0 = Munition (Classic)
    if ok and tonumber(n) then return tonumber(n) end
    return nil
end

local inInstanz = nil                                -- nil = Basislinie fehlt (Login in Instanz: still)

-- Rueckgabe: Liste fehlender Dinge (Locale-Schluessel) oder leer.
function X.reisecheckFehlt()
    local fehlt = {}
    if taschenLesbar() then
        local traenke, verbaende, runen = taschenZaehlen()
        if traenke < REISE_TRAENKE then fehlt[#fehlt + 1] = "potions" end
        if verbaende < REISE_VERBAENDE then fehlt[#fehlt + 1] = "bandages" end
        -- REVIEW3: Teleport gibt es erst ab Stufe 20 - vorher keine "Reagenzien"-Meldung (Todesminen/RFC-Magier)
        -- PORT (0.9.0): Reagenzien nur auf Clients, die sie ueberhaupt kennen. Seit Cataclysm
        -- 4.0.1 braucht der Magier keine Rune der Teleportation mehr — auf MoP, Retail und (bis
        -- ein Beta-Test es widerlegt) Forever waere der Hinweis falsch, nicht nur nutzlos.
        if ns.Compat.F.klassischeAusruestung
           and klasse() == "MAGE" and runen == 0
           and ((ns.Compat.unitLevelLesbar("player")) or 0) >= 20 then
            fehlt[#fehlt + 1] = "reagents"
        end
    end
    local dura = minHaltbarkeit()
    if dura >= 0 and dura < REISE_DURA then fehlt[#fehlt + 1] = "repair" end
    -- PORT: derselbe Grund wie oben — den Munitionsplatz (Inventar-Slot 0) gibt es seit 4.0.1
    -- nicht mehr. Die Existenzpruefung unten faengt das zwar ohnehin ab (GetInventoryItemCount
    -- liefert dort nichts Brauchbares), aber die Absicht soll lesbar im Code stehen.
    if ns.Compat.F.klassischeAusruestung and klasse() == "HUNTER" then
        local m = munition()
        if m ~= nil and m < REISE_MUNITION then fehlt[#fehlt + 1] = "ammo" end
    end
    return fehlt
end

local function reisecheck()
    if tot() or imKampf() then return end
    local fehlt = X.reisecheckFehlt()
    local gilt = function() return inInstanz and not tot() and not imKampf() end
    if #fehlt == 0 then
        meldeNachhol("REISECHECK", nil, gilt)         -- Regie waehlt die Zeile ohne Platzhalter
        return
    end
    local namen = {}
    for i, k in ipairs(fehlt) do namen[i] = ns.L[k] end
    -- REVIEW3: nurPlatzhalter, sonst nimmt die Regie auch die "Alles dabei"-Zeile (Harness: 1 von 3)
    meldeNachhol("REISECHECK", { fehlt = table.concat(namen, ", "), nurPlatzhalter = true }, gilt)
end

ns.on("PLAYER_ENTERING_WORLD", function()
    local drin, art = false, nil
    if IsInInstance then
        local ok, v, a = pcall(IsInInstance)
        drin = ok and v and true or false
        art = ok and a or nil
    end
    local relevant = drin and (art == "party" or art == "raid")
    if inInstanz == nil then
        inInstanz = relevant
        return
    end
    if relevant == inInstanz then return end
    inInstanz = relevant
    if relevant then
        ns.Compat.After(REISE_VERZUG, function()
            if inInstanz then pcall(reisecheck) end
        end)
    end
end)

-- ---------------------------------------------------------------- Ruhestein-Bereitschaft
local RUHESTEIN_ANLAESSE = { GEOFENCE_MOB = true, ZONE_BEINAHE = true, GEFAHR_ELITE = true }

-- Restzeit des Ruhestein-Cooldowns in Sekunden (0 = bereit oder unbekannt).
function X.ruhesteinRest()
    local start, dauer, enable
    if C and C.GetItemCooldown then
        local ok, s, d, e = pcall(C.GetItemCooldown, RUHESTEIN_ID)
        if ok then start, dauer, enable = s, d, e end
    elseif GetItemCooldown then
        local ok, s, d, e = pcall(GetItemCooldown, RUHESTEIN_ID)
        if ok then start, dauer, enable = s, d, e end
    end
    start, dauer = tonumber(start) or 0, tonumber(dauer) or 0
    if start <= 0 or dauer <= 0 then return 0 end
    if enable ~= nil and enable ~= 1 and enable ~= true then return 0 end
    local rest = start + dauer - jetzt()
    -- REVIEW-Muster: GetItemCooldown liefert bei globalem CD (1.5 s) auch "dauer" -> nur echte Ruhestein-Dauern zaehlen
    if rest <= 0 or dauer < 60 then return 0 end
    return rest
end

ns.nachAusgabe(function(id)
    if not RUHESTEIN_ANLAESSE[id] then return end
    ns.Compat.After(RUHESTEIN_VERZUG, function()
        if tot() then return end
        local rest = X.ruhesteinRest()
        if rest > RUHESTEIN_MIN_REST then
            meldeNachhol("RUHESTEIN", { min = math.ceil(rest / 60) }, function()
                return not tot() and X.ruhesteinRest() > RUHESTEIN_MIN_REST
            end)
        end
    end)
end)

-- ---------------------------------------------------------------- Erinnerungsfoto
local fotoZuletzt = 0
local hp20ImKampf = false

local function foto(pose)
    if not ns.Get("fotos") then return end
    if tot() then return end
    local t = jetzt()
    if t - fotoZuletzt < FOTO_ABSTAND then return end
    fotoZuletzt = t
    if pose and ns.Gestalt and ns.Gestalt.miene then ns.Gestalt.miene(pose, FOTO_VERZUG + 8) end
    ns.Compat.After(FOTO_VERZUG, function()
        if tot() then return end
        if Screenshot then pcall(Screenshot) end
        ns.melde("FOTO")
    end)
end
X.foto = foto

ns.nachAusgabe(function(id, _, vars)
    if vars and vars.test then return end   -- HOTFIX 0.16.1: keine Foto- und Kampf-Marke aus Proben
    if id == "HP20" then hp20ImKampf = true end
    if id == "STUFE_MEILENSTEIN" then foto(nil) end   -- Miene kommt schon von der Meilenstein-Zeile
end)
ns.on("PLAYER_REGEN_DISABLED", function() hp20ImKampf = false end)
ns.on("PLAYER_REGEN_ENABLED", function()
    if hp20ImKampf then
        hp20ImKampf = false
        if not tot() then foto("victory") end          -- ueberlebt unter 20 %
    end
end)
ns.on("PLAYER_DEAD", function() hp20ImKampf = false end)

-- ---------------------------------------------------------------- Ultra-Modus
-- Miene folgt im Kampf dem Leben. Warn-Mienen (HP35/ADDS/...) duerfen ihre Haltezeit ausspielen;
-- danach nimmt der naechste UNIT_HEALTH-Tick den Lebens-Ausdruck wieder auf.
local ultraStufe = nil            -- aktuelle Stufe (Miene) oder nil
local ultraTiefZuletzt = 0

local function ultraMiene(pct)
    if pct >= 70 then return "alert" end
    if pct >= 50 then return "concerned" end
    if pct >= 30 then return "scared" end
    return "terrified"
end

local function ultraScan()
    if not ns.Get("ultra") then return end
    if tot() or not imKampf() then return end
    local max = UnitHealthMax and UnitHealthMax("player") or 0
    if not max or max <= 0 then return end
    local cur = UnitHealth and UnitHealth("player") or 0
    local pct = math.floor(cur / max * 100 + 0.5)
    if pct <= 0 then return end                       -- Lade-Artefakt
    local m = ultraMiene(pct)
    local G = ns.Gestalt
    if not (G and G.miene) then return end
    local wechsel = (m ~= ultraStufe)
    ultraStufe = m
    -- Nur nachziehen, wenn keine gehaltene Miene (Ticker) laeuft oder die Stufe wirklich wechselt.
    if wechsel or (not G.ticker and G.aktuell ~= m) then
        G.miene(m, 0)
    end
    if pct < 30 and jetzt() - ultraTiefZuletzt >= ULTRA_TIEF_ABSTAND then
        ultraTiefZuletzt = jetzt()
        ns.melde("ULTRA_TIEF")
    end
end

ns.onUnit("UNIT_HEALTH", "player", function(unit)
    if unit and unit ~= "player" then return end
    ultraScan()
end)
ns.on("PLAYER_REGEN_DISABLED", function()
    ultraStufe = nil
    ns.Compat.After(0.2, ultraScan)
end)
-- Kampfende: Stufe vergessen; Gestalt.lua fuehrt die Grundstimmung selbst nach (halte 0 = kein Ticker).
ns.on("PLAYER_REGEN_ENABLED", function() ultraStufe = nil end)
ns.on("PLAYER_ENTERING_WORLD", function() ultraStufe = nil; hp20ImKampf = false end)

-- ---------------------------------------------------------------- Test-Modus
local BEISPIEL = {
    zone = "Westfall", name = "Defias Trapper", level = 20, buff = "Wohlgenährt", tage = 4, n = 3,
    fehlt = "Tränke, Verbände", min = 12, stunden = 2, von = 18, bis = 20, beinahe = 1,
    worte = "Nicht in die Mine.", beruf = "Kochkunst", wert = 150, ziel = "Sturmwind",
    -- REVIEW5: Welle 1 (Sinne/Rituale.lua). Ohne diese vier war /lyra test GEDENKEN komplett stumm
    -- (beide Zeilen tragen {vorgaenger}) und RUECKKEHR/JAHRESTAG/LAGERFEUER verloren ihre Zeilen.
    minuten = 12, vorgaenger = "Kestra", jahre = 1,
    erinnerung = "letzte Woche in Westfall, als es knapp wurde",
    -- WELLE3 (0.8.0): ohne diese waeren die neuen Ereignisse unter /lyra test stumm - genau die
    -- Falle, die REVIEW5 fuer GEDENKEN/RUECKKEHR schon einmal aufgeraeumt hat. Die globalen
    -- Platzhalter aus Sinne/Persoenlichkeit.lua ({klasse} {rasse} {stufe} {uhr} {heimat} {frage})
    -- legt der ns.melde-Wrapper selbst nach und stehen darum NICHT hier.
    boss = "Lucifron", dps = 143, prozent = 30, schnitt = 2.4, anteil = 22,
    unterbrechungen = 3, dauer = 74,
    -- REVIEW8: drei Platzhalter, die es im Katalog gibt und hier NIE gab. Folge war nicht
    -- "stumm", sondern etwas Schlimmeres: /lyra test zeigte eine ANDERE Zeile als die, die im
    -- Spiel kommt. QUEST_KETTE_WEITER und QUEST_WORAN haben je vier Zeilen, drei davon tragen
    -- {quest} - unter /lyra test war also immer nur die vierte zu sehen, und die Zeile, die man
    -- pruefen wollte, nie. Dasselbe fuer {titel} (PUNKT_GESETZT, PUNKT_OHNE_TOMTOM,
    -- QUEST_GEBER_GEFUNDEN) und {sek} (BOSS_ENRAGE_BALD, NOTFALL_CD).
    quest = "Die Todesminen", titel = "Hier war es knapp", sek = 20,
    -- MERGE 0.16.0 (21.09.2026, Welle 13c Baustein 3g): drei Werte, ohne die /lyra test die
    -- Platzhalter-Zeilen der neuen Ereignisse NICHT zeigen wuerde - dieselbe Falle wie bei
    -- REVIEW5 (GEDENKEN) und REVIEW8 ({quest}/{titel}/{sek}).
    --   schlaege  TOD_HERGANG, Fall "schnell" ("Zwei Schlaege. Mehr war es nicht.")
    --   versuche  SAMMEL_AUSDAUER (die MARKE, nicht der Zaehlerstand - darum 250 und nicht 263)
    --   gegner    TOD_HERGANG, Fall "letzter" - und ERBE_NACHRUF, wo der Platzhalter seit
    --             Welle 11a existiert und hier fehlte. {n} steht schon oben (n = 3) und passt
    --             auf "{n} auf einmal".
    schlaege = 2, versuche = 250, gegner = "Defias Trapper",
    -- REVIEW13 (0.16.0): SIEBEN weitere Platzhalter der Welle 13, die beim Merge fehlten - und
    -- damit ZUM VIERTEN MAL dieselbe Falle (REVIEW5: GEDENKEN, REVIEW8: {quest}/{titel}/{sek},
    -- MERGE 0.16.0: {schlaege}/{versuche}/{gegner}). Ohne sie waere der Spieltest heute Abend
    -- blind gewesen, im schlimmsten Fall der ganzen Liste:
    --   mechanik   GEGNER_MECHANIK - ALLE FUENF Zeilen tragen ihn. Ohne den Wert hat
    --              Core/Regie.lua waehle() KEINEN Kandidaten, gibt nil zurueck, und
    --              ausgebenKern() macht dann nur die Miene: "/lyra test GEGNER_MECHANIK" haette
    --              geguckt und geschwiegen. Kein Lua-Fehler, also auch kein Hinweis darauf.
    --   schritt    QUEST_ABGABE_NAH, die beiden NEUEN Zeilen. Ohne sie zeigt der Test nur die
    --   richtung   drei alten - also genau nicht das, was man pruefen will (REVIEW8-Muster).
    --   gold       GOLD_MEILENSTEIN. Als STRING, weil Sinne/Welle13a.lua stufe.name meldet
    --              ("100"/"1000") und nicht den Kontostand.
    --   charakter  LAGER_ANDERSWO. "Testheld" und kein erfundener Name: in diesem Projekt
    --   anzahl     heisst die Testfigur so. {anzahl} fehlte ausserdem SEIT WELLE 5 auch
    --              ERBE_STERBEORT und GM2_KNOTEN - die beiden zeigen ab jetzt ebenfalls ihre
    --              Platzhalter-Zeilen.
    --   lager      REISECHECK, die beiden neuen Zeilen. Der Wortlaut ist derselbe, den
    --              Sinne/Welle13d.lua im Spiel einsetzt (T("bank")).
    -- Wie die ganze Tabelle sind die Werte deutsch; auf einem englischen Client sieht der Test
    -- damit einen deutschen Platzhalter in einem englischen Satz. Das ist seit Welle 1 so
    -- (zone = "Westfall", beruf = "Kochkunst") und hier bewusst nicht anders gemacht.
    mechanik = "Betäubt", schritt = "zweihundert", richtung = "Norden", gold = "100",
    charakter = "Testheld", anzahl = 12, lager = "Deine Bank",
    -- MERGE19 (MERGE 0.19.0, 22.09.2026, Welle 17): drei Platzhalter, und einer davon faellt
    -- ZUM FUENFTEN MAL in dieselbe Falle (REVIEW5, REVIEW8, MERGE 0.16.0, REVIEW13):
    --   haustier        PERSON_HAUSTIER_DA - BEIDE Zeilen tragen ihn. Ohne den Wert findet
    --                   Core/Regie.lua waehle() keinen Kandidaten, und "/lyra test
    --                   PERSON_HAUSTIER_DA" haette geguckt und geschwiegen. Genau der
    --                   GEGNER_MECHANIK-Fall. Gefunden vom Pruefstand (r5 totezeilen), nicht
    --                   von Hand - die Pruefung taugt.
    --   lieblingszone   ZONE_ERINNERUNG, die neue Platzhalter-Zeile. Ohne den Wert zeigt der
    --   lieblingsberuf  LEERLAUF, dieselbe Lage - also genau nicht die Zeile, die man pruefen
    --                   will (REVIEW8-Muster).
    -- Im Spiel kommen alle drei aus dem ns.melde-Mantel in Sinne/Welle17.lua (Abschnitt 4) und
    -- sind dort nie leer, wenn die Zeile faellt. Hier stehen Beispielwerte, deutsch wie die
    -- ganze Tabelle. "Wuschel" ist ein Name, kein echter Spielername.
    haustier = "Wuschel", lieblingszone = "Westfall", lieblingsberuf = "Kochkunst",
}

local function sperrenLoesen(id)
    local R = ns.Regie
    if not R then return end
    R.cool[id] = nil
    for k in pairs(R.cool) do
        if type(k) == "string" and k:sub(1, #id + 1) == id .. ":" then R.cool[k] = nil end
    end
    for k in pairs(R.session) do
        if k == id or (type(k) == "string" and k:sub(1, #id + 1) == id .. ":") then R.session[k] = nil end
    end
    R.zuletztPlauder = 0
end

-- X.test("HP20"): Sperren dieser ID loesen und mit Beispiel-Vars melden. Rueckgabe wie ns.melde.
function X.test(id)
    id = tostring(id or ""):upper()
    local e = LyraGestalt_Phrasen and LyraGestalt_Phrasen.ereignisse and LyraGestalt_Phrasen.ereignisse[id]
    if not e then ns.print(ns.L["unknown event"] .. " " .. id); return false end
    sperrenLoesen(id)
    local vars = {}
    for k, v in pairs(BEISPIEL) do vars[k] = v end
    -- W7-Nachtrag (20.09.2026, Screenshot-Runde): {zone} aus dem echten Spiel statt "Westfall",
    -- sonst behauptet die Probe vor dem Orgrimmar-Tor, man stehe in Westfall. Der Rest bleibt
    -- Beispiel - es ist und bleibt eine Probe.
    local echteZone = GetZoneText and GetZoneText()
    if type(echteZone) == "string" and echteZone ~= "" then vars.zone = echteZone end
    vars.key = "test"
    -- PRUEF (20.09.2026, Wiederaufbau-Befund 4): /lyra test lief bis hierher ueber den normalen
    -- Plauder-Pfad und hing damit an Abstand und Stundenbudget - nach 15 Proben in einer Stunde
    -- war der Testbefehl stumm ("budget"). Eine Probe ist eine Frage des Spielers; sie geht wie
    -- Klick und "Sag was" direkt (Core/Regie.lua: nur Lade- und Tod-Riegel gelten weiter).
    vars.direkt = true
    -- HOTFIX 0.16.1 (21.09.2026, Spieltest Harald): eine Probe ist KEIN Erlebnis. Bis 0.16.0 lief
    -- /lyra test HP20 durch dieselben ns.nachAusgabe-Haken wie ein echter Beinahe-Tod: die
    -- Chronik schrieb "hier war es knapp: 100 %" mit Pin auf die Minimap, die Laune wurde fuer
    -- zwanzig Minuten "besorgt", das Profil zaehlte mit. Die lernenden Haken pruefen jetzt
    -- vars.test und lassen Proben durch, ohne sich etwas zu merken.
    vars.test = true
    local ok = ns.melde(id, vars)
    if not ok then
        local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
        ns.print(ns.L["Test silent"] .. (d and d[1] or "?"))
    end
    return ok
end

local testTicker, testListe, testIndex = nil, nil, 0

function X.testStop()
    if not testTicker then return end
    testTicker:Cancel(); testTicker = nil
    testListe, testIndex = nil, 0
    ns.print(ns.L["Test stopped"])
end

-- Alle warn-IDs im 4-s-Takt (alphabetisch). Abbruch: X.testStop().
function X.testAlle()
    if testTicker then X.testStop() end
    local liste = {}
    local er = LyraGestalt_Phrasen and LyraGestalt_Phrasen.ereignisse or {}
    for id, e in pairs(er) do
        if e.klasse == "warn" then liste[#liste + 1] = id end
    end
    table.sort(liste)
    if #liste == 0 then return end
    testListe, testIndex = liste, 0
    ns.print(ns.L["Test running"] .. " (" .. #liste .. ")")
    local function schritt()
        testIndex = testIndex + 1
        local id = testListe and testListe[testIndex]
        if not id then X.testStop(); return end
        ns.print("  " .. id)
        X.test(id)
    end
    schritt()
    testTicker = ns.Compat.NewTicker(TEST_TAKT, function()
        local ok, err = pcall(schritt)
        if not ok then ns.debug("Extra test: " .. tostring(err)); X.testStop() end
    end)
end

function X.stand()
    return inInstanz, ultraStufe, hp20ImKampf, fotoZuletzt, testTicker ~= nil
end
