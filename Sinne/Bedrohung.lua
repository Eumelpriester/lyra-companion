-- Sinne/Bedrohung.lua — Bedrohungs-Flanken, nativ (Welle 3).
--
-- WARUM DIESE DATEI NICHT "Omen.lua" HEISST
-- Der Auftrag sah ein Modul `Sinne/Omen.lua` vor. Omen hat aber keine Schnittstelle: die
-- Bedrohungsdaten liegen in file-locals (`threatTable`, `sortTable`, `topthreat`, `tankGUID` -
-- Omen/Omen.lua:1765), von aussen nicht erreichbar. Andocken ginge nur ueber Omens Balken-Frames,
-- und ein Addon, das die Anzeige eines anderen Addons abliest, bricht beim naechsten Layout-
-- Wechsel still. Genau das steht auch in docs/companion-v3.md C.4: "Omen ignorieren, Threat
-- nativ nachbauen". Eine Datei nach einem Addon zu benennen, das sie bewusst nicht anfasst,
-- waere eine Luege im Dateinamen - deshalb Bedrohung.lua.
-- Die native API kann Era: Omen selbst cacht `UnitDetailedThreatSituation` ungeguarded beim Laden
-- (Omen/Omen.lua:65, :1782), Plater (Plater.lua:52) und Safeguard (Main.lua:452) ebenso.
--
-- WAS SIE ERGAENZT
-- `AGGRO` gibt es seit Welle 1 (Sinne/Bruecken.lua): du hast die hoechste Bedrohung, in Gruppe,
-- einmal je Kampf. Der Satz ist richtig - aber er ist derselbe, ob du als Einziger prueglst oder
-- ob du sie dem Tank gerade aus der Hand genommen hast. Das Zweite ist die gefaehrliche Lage und
-- verdient einen eigenen Satz. Dieses Modul uebernimmt die Flanke ganz: Bruecken.lua tritt
-- zurueck (dort eine Zeile `if ns.Bedrohung then return end`, markiert -- WELLE3:), damit es
-- nie zwei Warnungen zur selben Sekunde gibt.
--
-- Ereignisse: AGGRO (unveraendert, warn/2), AGGRO_TROTZ_TANK (warn/2, neu), AGGRO_VERLOREN (still).
--   Alle drei nur in Gruppe - solo hat man immer Aggro, da ist jede Zeile Unsinn.
--   Je Kampf hoechstens einmal AGGRO oder AGGRO_TROTZ_TANK (nie beide) und einmal AGGRO_VERLOREN.
--
-- KEINE SPIELERNAMEN (Grenze B). "Da ist ein Tank" wird ohne jeden Namen festgestellt: das Ziel
--   schlaegt auf eine Einheit ein, die ein Spieler und nicht wir und nicht unser Begleiter ist
--   (UnitIsUnit auf "targettarget"). Es wird kein Name gelesen, keine Rolle abgefragt, keine
--   Gruppenliste durchlaufen. `UnitGroupRolesAssigned` gibt es auf Era ohnehin nicht - und selbst
--   wenn: in Classic traegt niemand eine Rolle ein.
--
-- Blizzard-API (nur lesend): UnitDetailedThreatSituation (Rueckfall UnitThreatSituation),
--   UnitExists, UnitIsUnit, UnitIsPlayer, UnitAffectingCombat, UnitIsDeadOrGhost,
--   IsInGroup/IsInRaid, GetTime.
-- Events: UNIT_THREAT_SITUATION_UPDATE, UNIT_THREAT_LIST_UPDATE, PLAYER_TARGET_CHANGED,
--   PLAYER_REGEN_DISABLED/ENABLED, PLAYER_ENTERING_WORLD. Kein Ticker, kein OnUpdate.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local B = {}
ns.Sinne.Bedrohung = B
ns.Bedrohung = B

B.VERLOREN_FRIST = 3            -- s: so lange muss die Aggro weg sein, bevor "verloren" faellt

local hatteAggro = false        -- in DIESEM Kampf schon einmal Aggro gehabt
local gesagtAggro = false       -- AGGRO oder AGGRO_TROTZ_TANK in diesem Kampf gesagt
local gesagtVerloren = false
local fremderTank = false       -- in diesem Kampf hat das Ziel jemand anderen geschlagen
local verlorenSeit = 0

local function jetzt() return (GetTime and GetTime()) or 0 end
local function inGruppe()
    return ((IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid())) and true or false
end
local function tot() return (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) and true or false end

local function melde(id, vars)
    if not ns.melde then return false end
    local ok, v = pcall(ns.melde, id, vars)
    return (ok and v) and true or false
end

-- Eigene Bedrohungslage. Rueckgabe: isTanking (bool), status (0..3) - oder nil, wenn die API
-- nichts weiss (kein Ziel, Ziel nicht im Kampf mit uns).
local function lage()
    if type(UnitDetailedThreatSituation) == "function" then
        local ok, isTanking, status = pcall(UnitDetailedThreatSituation, "player", "target")
        if ok and status ~= nil then return isTanking and true or false, tonumber(status) or 0 end
        -- Ohne Ziel liefert die ausfuehrliche Variante nichts - dann die einfache.
    end
    if type(UnitThreatSituation) == "function" then
        local ok, st = pcall(UnitThreatSituation, "player")
        if ok and st ~= nil then
            st = tonumber(st) or 0
            return st == 3, st
        end
    end
    return nil
end
B.lage = lage

-- Schlaegt unser Ziel gerade auf jemand anderen ein? Ohne Namen, ohne Gruppenliste.
-- "targettarget" ist das Ziel unseres Ziels; ist das ein Spieler und nicht wir und nicht unser
-- Begleiter, dann haelt da jemand anderes her - fuer unsere Zwecke: der Tank.
local function fremdesZielZiel()
    if not (UnitExists and UnitExists("target") and UnitExists("targettarget")) then return false end
    if not (UnitIsPlayer and UnitIsPlayer("targettarget")) then return false end
    if not UnitIsUnit then return false end
    local ok, ich = pcall(UnitIsUnit, "targettarget", "player")
    if not ok or ich then return false end
    local ok2, tier = pcall(UnitIsUnit, "targettarget", "pet")
    if ok2 and tier then return false end
    return true
end

-- Vor jeder Bewertung mitschreiben, ob da ein Tank ist. Das laeuft auch, wenn wir gar keine
-- Bedrohung haben - genau dann ist die Beobachtung ja etwas wert.
local function tankMerken()
    if fremderTank then return end
    if fremdesZielZiel() then fremderTank = true end
end

local function pruefen(unit)
    if unit ~= nil and unit ~= "player" then return end
    if not inGruppe() then return end           -- solo ist jede dieser Zeilen Unsinn
    if tot() then return end
    if not (UnitAffectingCombat and UnitAffectingCombat("player")) then return end
    tankMerken()
    local isTanking, status = lage()
    if status == nil then return end

    if isTanking or status == 3 then
        hatteAggro = true
        verlorenSeit = 0
        if gesagtAggro then return end
        gesagtAggro = true
        -- Die eine neue Aussage: du hast sie jemandem aus der Hand genommen.
        if fremderTank then melde("AGGRO_TROTZ_TANK") else melde("AGGRO") end
        return
    end

    -- Aggro wieder weg. Nicht sofort melden: ein Tankwechsel flackert ueber mehrere Updates.
    if not hatteAggro or gesagtVerloren then return end
    if verlorenSeit == 0 then verlorenSeit = jetzt(); return end
    if jetzt() - verlorenSeit < B.VERLOREN_FRIST then return end
    gesagtVerloren = true
    melde("AGGRO_VERLOREN")      -- klasse "still": nur die Miene, kein Wort. Absicht.
end

local function neuerKampf()
    hatteAggro, gesagtAggro, gesagtVerloren, fremderTank, verlorenSeit = false, false, false, false, 0
end

ns.on("PLAYER_REGEN_DISABLED", neuerKampf)
ns.on("PLAYER_REGEN_ENABLED", neuerKampf)
ns.on("PLAYER_ENTERING_WORLD", neuerKampf)
-- Zielwechsel: der neue Mob hat eine eigene Bedrohungslage, aber der Tank-Merker des Kampfes
-- bleibt stehen (wer einmal getankt hat, tankt in diesem Kampf).
ns.on("PLAYER_TARGET_CHANGED", function() tankMerken() end)

if type(UnitDetailedThreatSituation) == "function" or type(UnitThreatSituation) == "function" then
    ns.on("UNIT_THREAT_SITUATION_UPDATE", pruefen)
    -- UNIT_THREAT_LIST_UPDATE feuert auch, wenn sich die Liste um jemand anderen aendert - genau
    -- dann wollen wir den Tank-Merker nachziehen. Es kommt ohne verlaesslichen unit-Parameter
    -- fuer uns, darum mit nil in dieselbe Pruefung.
    ns.on("UNIT_THREAT_LIST_UPDATE", function() pruefen(nil) end)
end

function B.status()
    local de = ns.sprache() == "de"
    local isTanking, status = lage()
    -- REVIEW8: "ausfuehrlich"/"einfach" standen hier auch im englischen Satz ("Threat: API
    -- ausfuehrlich") - die beiden Woerter waren die einzigen in dieser Datei, die die
    -- Sprachweiche uebersprungen haben.
    local api = "-"
    if type(UnitDetailedThreatSituation) == "function" then api = de and "ausfuehrlich" or "detailed"
    elseif type(UnitThreatSituation) == "function" then api = de and "einfach" or "simple" end
    return {
        (de and "Bedrohung: API %s, in Gruppe %s." or "Threat: API %s, in group %s."):format(
            api,
            inGruppe() and (de and "ja" or "yes") or (de and "nein" or "no")),
        (de and "  Lage: Stufe %s, du haeltst her: %s, fremder Tank im Kampf: %s."
             or "  State: tier %s, you're tanking: %s, other tank this fight: %s."):format(
            tostring(status or "-"), tostring(isTanking and (de and "ja" or "yes") or (de and "nein" or "no")),
            fremderTank and (de and "ja" or "yes") or (de and "nein" or "no")),
    }
end

function B.stand() return hatteAggro, gesagtAggro, gesagtVerloren, fremderTank end
