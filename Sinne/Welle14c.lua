-- Sinne/Welle14c.lua — Welle 14c "Vorräte und Selbstbuffs" (0.20.0, 22.09.2026).
--
-- Bauplan: docs/OFFEN-HARALD.md Zeile 142 (Harald, 21.09. abends). Drei Teile, alle NATIV —
-- keine Andockstelle an ein Fremd-Addon, kein Fremdwissen noetig.
--
--   A) SELBSTBUFF_FEHLT.  Beim Anvisieren eines angreifbaren, lebenden, nicht spielergesteuerten
--      Ziels AUSSERHALB des Kampfes: fehlt der klassentypische Selbstbuff? Klasse warn/Stufe 1,
--      EIGENE Drossel (5 min Mindestabstand, danach erst wieder frei, wenn der Buff zwischen-
--      zeitlich einmal da war ODER 10 min vergingen — Katalog-Drossel "buff", der Sinn drosselt
--      selbst, Core/Regie.lua drossel() laesst den Wert unveraendert durch).
--   B) WOHLGENAEHRT_FEHLT.  Vor einer Party-Instanz (eigene Basislinie, EIGENER Verzug — siehe
--      unten) oder vor einem angreifbaren Elite-Ziel ausserhalb des Kampfes: fehlt "Wohlgenaehrt"/
--      "Well Fed"? Klasse plauder/Stufe 0, Drossel "session" (einmal je Sitzung), ab Stufe 15.
--   C) VORRAT_KNAPP.  Wasser (nur Mana-Klassen) oder Essen (alle) auf drei oder weniger gefallen,
--      nachdem in dieser Sitzung schon einmal mehr als drei da waren (Flanke, Basislinie beim
--      Login/ersten Scan) — Klasse plauder/Stufe 0, Drossel "level" (einmal je Charakterstufe,
--      insgesamt, nicht je Sorte).
--
-- WARUM EIN GEMEINSAMES KAESTCHEN ("vorraete") FUER DREI TEILE: alle drei beantworten dieselbe
-- Hardcore-Frage — "bist du vorbereitet?" — und keiner der drei hat ein Gegenstueck in einem
-- Fremd-Addon, nach dem ein Spieler suchen wuerde. Drei Kaestchen fuer drei Zeilen, die alle
-- dasselbe Thema tragen, waeren die Unterscheidung ohne Unterschied, die Design-Deckel B-5 schon
-- bei Welle 13/14 abgelehnt hat (Muster: docs/welle14b-2026-09-21.md, UI/Settings.lua "Wave 14").
--
-- ns.Compat.aura AUS DEM AUFTRAG GIBT ES NICHT — die echte Funktion heisst ns.Compat.auraByIndex
-- (Core/Compat.lua:388, von Sinne/Alltag.lua und Sinne/Rituale.lua bereits so benutzt). Diese
-- Datei ruft sie unter ihrem echten Namen; siehe docs/welle14c-2026-09-22.md §3 fuer die
-- Begruendung, warum das keine Abweichung vom FACHLICHEN Auftrag ist.
--
-- EINE FALLE, DIE DIESE DATEI AUSDRUECKLICH UMGEHT: ns.Compat.auraByIndex ist ein FUNKTIONS-
-- WRAPPER und existiert IMMER, auch wenn weder C_UnitAuras noch UnitAura im Client vorhanden
-- sind — er liefert dann einfach immer nil zurueck. "type(ns.Compat.auraByIndex) == 'function'"
-- waere also NIE ein brauchbarer Test fuer den Prüfstand-Modus "fehlt" (keine Aura-API): jede
-- Abfrage saehe wie "kein Buff gefunden" aus und Lyra haette Regel 4 ("Ausfall ist Schweigen")
-- gebrochen — sie haette FAELSCHLICH gewarnt, der Buff fehle, obwohl sie ihn gar nicht lesen
-- konnte. Die Feature-Weiche W.F prueft darum wie in Sinne/Welle13a.lua/Welle14b.lua die
-- ROHEN Globalen (_G.C_UnitAuras/_G.UnitAura), nicht den Wrapper — genau das, was die anderen
-- Wellen-Dateien mit _G.UnitOnTaxi/_G.GetNumSkillLines auch tun.
--
-- KONTRAKT: kein SendChatMessage, kein SendAddonMessage, kein C_ChatInfo, kein RunMacro, kein
-- CastSpell, keine geschuetzte Funktion, kein Netz, keine Fremddaten, keine neue Globale, kein
-- OnUpdate, kein Tastaturfokus. Jeder API-Zugriff steht in pcall hinter einer Existenzpruefung
-- auf EIN konkretes Feld. Faellt eine Faehigkeit aus, ist NUR ihr Teil still — die anderen zwei
-- laufen unberuehrt weiter (drei unabhaengige W.F-Felder).
--
-- NIE IM KAMPF, NIE TOT, NIE IM LADEBILDSCHIRM (ns.Welle14b.imLadebildschirm(), existenzgeprueft
-- — Welle14b ist ein anderes Team und muss nicht geladen sein), NIE MIT OFFENEM PLATZHALTER.
local ADDON, ns = ...
ns.Sinne = ns.Sinne or {}
local W = {}
ns.Welle14c = W
ns.Sinne.Welle14c = W

-- ---------------------------------------------------------------------------------------------
-- Häkchen. EIN Kästchen für alle drei Teile, Voreinstellung AN. Core/Init.lua gehört einem
-- anderen Team — der Schlüssel hängt hier auf DATEIEBENE an ns.DEFAULTS_ACCOUNT (Muster
-- Sinne/Welle13a.lua/Welle14b.lua), also lange vor ns.initDB().
-- ---------------------------------------------------------------------------------------------
if type(ns.DEFAULTS_ACCOUNT) == "table" then
    local D = ns.DEFAULTS_ACCOUNT
    if D.vorraete == nil then D.vorraete = true end
end

-- ---------------------------------------------------------------------------------------------
-- Feature-Weiche. Rohe Globale, nicht der Compat-Wrapper (Begründung oben im Dateikopf).
-- ---------------------------------------------------------------------------------------------
local CC = ns.Compat and ns.Compat.Container
W.F = {
    aura = (type(_G.C_UnitAuras) == "table" and type(_G.C_UnitAuras.GetAuraDataByIndex) == "function")
           or type(_G.UnitAura) == "function",
    enchant = type(_G.GetWeaponEnchantInfo) == "function",
    container = (type(CC) == "table" and type(CC.GetContainerNumSlots) == "function"
                 and type(CC.GetContainerItemInfo) == "function") and true or false,
}

-- Schwellen und Zeiten, alle als benannte Konstanten (leichter zu pruefen, leichter zu aendern).
W.SELBSTBUFF_MIN      = 300   -- s, Mindestabstand zwischen zwei SELBSTBUFF_FEHLT-Meldungen
W.SELBSTBUFF_MAX      = 600   -- s, danach ist die Sperre auch OHNE gesehenen Buff wieder frei
W.MAGIER_STUFE        = 1
W.PRIESTER_STUFE      = 1
W.JAEGER_STUFE        = 4     -- Aspekt des Affen wird mit 4 gelernt
W.SCHURKE_STUFE       = 20    -- Giftquest
W.HEXER_RUESTUNG_STUFE = 20   -- ab hier Dämonenrüstung statt Dämonenhaut
W.HEXER_STUFE         = 1
W.DRUIDE_STUFE        = 1
W.SCHAMANE_STUFE      = 8
W.PALADIN_STUFE       = 4

W.WOHLGENAEHRT_STUFE  = 15
-- Kopie von Sinne/Extra.lua REISE_VERZUG (Zeile 26, Stand 22.09.2026: 16 s). Extra.lua gehört
-- einem anderen Team und wird von dieser Welle NICHT angefasst — der Wert ist darum von Hand
-- hier hinterlegt und muss nachgezogen werden, falls Extra.lua seinen REISE_VERZUG je ändert
-- (docs/welle14c-2026-09-22.md §3 nennt das als offenen Abstimmungspunkt für den Merge).
W.REISECHECK_VERZUG_KOPIE = 16
W.WOHLGENAEHRT_INSTANZ_VERZUG = W.REISECHECK_VERZUG_KOPIE + 8   -- "8 s NACH dem Reisecheck-Verzug"

W.VORRAT_SCHWELLE     = 3     -- "≤ 3" gilt als knapp
W.VORRAT_KAMPF_VERZUG = 3     -- s nach PLAYER_REGEN_ENABLED
W.VORRAT_BAG_DROSSEL  = 30    -- s Mindestabstand zwischen zwei BAG_UPDATE_DELAYED-Scans

local function jetzt() return (GetTime and GetTime()) or 0 end
-- nil zählt als AN: vor ns.initDB() gibt ns.Get die Vorgabe zurück, und die steht oben auf true.
local function an() return ns.Get and ns.Get("vorraete") ~= false end
local function tot() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false end
local function imKampf() return UnitAffectingCombat and UnitAffectingCombat("player") or false end

local function melde(id, vars)
    if not ns.melde then return false end
    local ok, v = pcall(ns.melde, id, vars)
    return (ok and v) and true or false
end

-- Plauder-Zeile mit EINEM Nachhol (Muster Sinne/Welle13a.lua/Welle14b.lua). NUR wenn der
-- Regie-ABSTAND der Grund war: Drossel, Gruppe, Still-Modus und Stummschaltung sind endgültige
-- Antworten. Gebraucht für WOHLGENAEHRT_FEHLT und VORRAT_KNAPP (beide plauder): beide fallen oft
-- unmittelbar NACH einer anderen plauder-Zeile eines fremden Teams (z. B. Sinne/Extra.lua
-- REISECHECK, 8 s vor unserem eigenen Instanz-Verzug) — ohne Nachhol würde der normale
-- Plauder-Mindestabstand (ab Werk 30 s) genau diese Kollision in Schweigen verwandeln.
-- MERGE20 (Merge 0.20.0, 22.09.2026): auf das 4x-Muster aus Sinne/Welle14b.lua (FIX 0.19.1)
-- angeglichen. EIN Nachhol reichte dort nicht, weil bei einer Landung/einem Instanz-Eintritt
-- mehrere plauder-Zeilen Schlange stehen (ZONE, REISECHECK, Chronik-Nachsatz) und jede den
-- Abstand neu setzt - genau die Lage von WOHLGENAEHRT_FEHLT. Gleiches Verhalten in allen Kopien.
W.NACHHOL_MAX = 4
local function meldeNachhol(id, vars, gilt, versuch)
    versuch = versuch or 1
    if melde(id, vars) then return true end
    if versuch >= W.NACHHOL_MAX then return false end
    local d = ns.Regie and ns.Regie.dropLog and ns.Regie.dropLog[1]
    if not (d and d[2] == id and d[1] == "abstand") then return false end
    local rest = 0
    if ns.Regie and ns.Regie.abstandRest then
        local ok, r = pcall(ns.Regie.abstandRest)
        if ok and type(r) == "number" then rest = r end
    end
    local verzug = math.max(2, math.min(rest + 1, 180))
    ns.Compat.After(verzug, function()
        if gilt and not gilt() then return end
        meldeNachhol(id, vars, gilt, versuch + 1)
    end)
    return false
end

-- Die Ladebildschirm-Klammer aus Welle14b — existenzgeprüft, weil dieses Team nicht weiß, ob
-- Welle14b überhaupt geladen ist (anderes Team, eigene Datei, eigenes Los).
local function inLadebildschirm()
    if not (ns.Welle14b and type(ns.Welle14b.imLadebildschirm) == "function") then return false end
    local ok, v = pcall(ns.Welle14b.imLadebildschirm)
    return ok and v == true
end


-- MERGE 0.20.0 (22.09.2026): "EIN ZIELWECHSEL, HOECHSTENS EIN SATZ." Am selben
-- PLAYER_TARGET_CHANGED sprechen vor uns schon Sinne/Kampf.lua (GEFAHR_ELITE ist Stufe 2 und
-- NICHT von der Stufe-1-Bremse erfasst, GEFAHR_STUFEN Stufe 1), Sinne/Extra.lua (RUNNER_BEKANNT,
-- Stufe 2) und Sinne/Chronik.lua (BESTIARIUM/MOB_RIVALE_WARNUNG); Sinne/Welle13b.lua sagt 1,5 s
-- spaeter die Mechanik des Ziels. Ein Vorbereitungs-Hinweis obendrauf waere die Doppelung, die
-- Regel 1 verbietet (Blase ersetzt, Stimme schneidet ab). Also: hat dieser Zielwechsel schon
-- gesprochen (eine Nicht-still-Ausgabe in derselben Sekunde) ODER steht die Mechanik-Zeile an,
-- schweigt der Hinweis - OHNE seine Drossel zu verbrauchen; er kommt beim naechsten Zielwechsel.
-- Die Gefahr des Ziels selbst geht jedem Vorbereitungs-Hinweis vor.
W.ZIEL_RUHE = 1   -- s: "in derselben Sekunde" (ns.on ruft alle Haken eines Ereignisses im selben Frame)
local letzteSatzZeit = -1e9
if ns.nachAusgabe then
    ns.nachAusgabe(function(_, e) if not (e and e.klasse == "still") then letzteSatzZeit = jetzt() end end)
end
local function zielBelegt()
    if jetzt() - letzteSatzZeit < W.ZIEL_RUHE then return true end
    local w13b = ns.Welle13b
    if w13b and type(w13b.mechanikSteht) == "function" then
        local ok, v = pcall(w13b.mechanikSteht)
        if ok and v == true then return true end
    end
    return false
end
W.zielBelegt = zielBelegt   -- fuer den Pruefstand

-- =============================================================================================
-- 0  GEMEINSAME ZIEL-PRÜFUNG (Teil A und Teil B)
-- =============================================================================================
-- "angreifbar, lebend, nicht spielergesteuert" — dieselben drei Grenzen wie feindNpc() in
-- Sinne/Extra.lua, hier aber ohne GUID/Namen: wir brauchen nur ein Ja oder Nein.
local function zielTauglich()
    if not (UnitExists and UnitExists("target")) then return false end
    if UnitIsPlayer and UnitIsPlayer("target") then return false end
    if UnitPlayerControlled and UnitPlayerControlled("target") then return false end
    if not (UnitCanAttack and UnitCanAttack("player", "target")) then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("target") then return false end
    return true
end

-- =============================================================================================
-- 1  DIE AURA-LESUNG — gemeinsam für Teil A (Klassenbuff) und Teil B (Wohlgenährt)
-- =============================================================================================
local function auraApiDa()
    return (type(_G.C_UnitAuras) == "table" and type(_G.C_UnitAuras.GetAuraDataByIndex) == "function")
           or type(_G.UnitAura) == "function"
end

-- Eine Aura gilt nur dann als LESBAR, wenn ihre Felder die erwartete FORM haben (Regel 4:
-- Ausfall ist Schweigen — auch dann, wenn die API zwar antwortet, aber Unsinn liefert).
local function auraGueltig(aura)
    if type(aura) ~= "table" then return false end
    if aura.spellId ~= nil and type(aura.spellId) ~= "number" then return false end
    if aura.name ~= nil and type(aura.name) ~= "string" then return false end
    return true
end

W.AURA_MAX = 64   -- Muell-Riegel (Muster Sinne/Alltag.lua aurenLesen)

-- Rückgabe: true (Buff da), false (Buff nicht gefunden), nil (unlesbar — API fehlt/wirft/lügt).
local function spielerHatBuff(idSet, nameSet)
    if not auraApiDa() then return nil end
    for i = 1, W.AURA_MAX do
        local ok, aura = pcall(ns.Compat.auraByIndex, "player", i, "HELPFUL")
        if not ok then return nil end                    -- kaputt: die API wirft
        if aura == nil then return false end              -- Liste zu Ende, kein Treffer
        if not auraGueltig(aura) then return nil end       -- muell: Datenform stimmt nicht
        if aura.spellId and idSet[aura.spellId] then return true end
        if aura.name and nameSet[aura.name] then return true end
    end
    return false
end
W.spielerHatBuff = spielerHatBuff   -- für den Prüfstand

-- =============================================================================================
-- 2  TEIL A — SELBSTBUFF_FEHLT
-- =============================================================================================
-- Rang-ID-Listen je Buff (Classic Era) PLUS Namensvergleich als Rückfall (verschiedene Ränge
-- haben verschiedene SpellIDs — der Namensvergleich fängt einen Rang, den diese Liste nicht
-- kennt). Quelle der Zahlen: Auftrag docs/OFFEN-HARALD.md Zeile 142; einzelne zusätzliche Ränge
-- (z. B. Arcane Brilliance, Prayer of Fortitude, Gift of the Wild, Greater Blessing-Varianten)
-- sind ergänzt, weil sie DIESELBE Wirkung tragen wie die im Auftrag genannten Basiszauber —
-- siehe docs/welle14c-2026-09-22.md §3.
local MAGIER_RUESTUNG_IDS = {
    [168]=true, [7300]=true, [7301]=true,                       -- Frost Armor
    [7302]=true, [7320]=true, [10219]=true, [10220]=true,        -- Ice Armor
    [6117]=true, [22782]=true, [22783]=true,                     -- Mage Armor
}
local MAGIER_RUESTUNG_NAMEN = {
    ["Frost Armor"]=true, ["Frostrüstung"]=true,
    ["Ice Armor"]=true, ["Eisrüstung"]=true,
    ["Mage Armor"]=true, ["Magierrüstung"]=true,
}
local MAGIER_INT_IDS = { [1459]=true, [1460]=true, [1461]=true, [10156]=true, [10157]=true, [23028]=true }
local MAGIER_INT_NAMEN = {
    ["Arcane Intellect"]=true, ["Arkane Intelligenz"]=true,
    ["Arcane Brilliance"]=true, ["Arkane Brillanz"]=true,
}

local PRIESTER_IDS = { [1243]=true, [1244]=true, [1245]=true, [2791]=true, [10937]=true, [10938]=true,
                        [21562]=true, [21564]=true }
local PRIESTER_NAMEN = {
    ["Power Word: Fortitude"]=true, ["Machtwort: Seelenstärke"]=true,
    ["Prayer of Fortitude"]=true, ["Gebet der Seelenstärke"]=true,
}

local JAEGER_IDS = { [13165]=true, [14318]=true, [14319]=true, [14320]=true, [14321]=true, [14322]=true,
                      [13163]=true, [5118]=true, [13159]=true, [20043]=true, [20190]=true, [13161]=true }
local JAEGER_NAMEN = {
    ["Aspect of the Hawk"]=true, ["Aspekt des Falken"]=true,
    ["Aspect of the Monkey"]=true, ["Aspekt des Affen"]=true,
    ["Aspect of the Cheetah"]=true, ["Aspekt des Geparden"]=true,
    ["Aspect of the Pack"]=true, ["Aspekt des Rudels"]=true,
    ["Aspect of the Wild"]=true, ["Aspekt der Wildnis"]=true,
    ["Aspect of the Beast"]=true, ["Aspekt der Bestie"]=true,
}

local HEXER_RUESTUNG_IDS = { [706]=true, [1086]=true, [11733]=true, [11734]=true, [11735]=true }
local HEXER_RUESTUNG_NAMEN = { ["Demon Armor"]=true, ["Dämonenrüstung"]=true }
local HEXER_HAUT_IDS = { [687]=true, [696]=true }
local HEXER_HAUT_NAMEN = { ["Demon Skin"]=true, ["Dämonenhaut"]=true }

local DRUIDE_IDS = { [1126]=true, [5232]=true, [6756]=true, [5234]=true, [8907]=true, [9884]=true,
                      [9885]=true, [21849]=true, [21850]=true }
local DRUIDE_NAMEN = {
    ["Mark of the Wild"]=true, ["Mal der Wildnis"]=true,
    ["Gift of the Wild"]=true, ["Geschenk der Wildnis"]=true,
}

local SCHAMANE_IDS = { [324]=true, [325]=true, [905]=true, [945]=true, [8134]=true, [10431]=true, [10432]=true }
local SCHAMANE_NAMEN = { ["Lightning Shield"]=true, ["Blitzschlagschild"]=true }

local PALADIN_IDS = {
    [19740]=true, [19834]=true, [19835]=true, [19836]=true, [19837]=true, [19838]=true, [25291]=true,
    [25782]=true, [25916]=true,                                            -- Segen der Macht (+ Größerer)
    [19742]=true, [19850]=true, [19852]=true, [19853]=true, [19854]=true, [25290]=true,
    [25894]=true, [25918]=true,                                            -- Segen der Weisheit (+ Größerer)
    [1038]=true,                                                           -- Segen der Rettung
    [19977]=true, [19978]=true, [19979]=true,                              -- Segen des Lichts
    [1022]=true,                                                           -- Segen des Schutzes
}
local PALADIN_NAMEN = {
    ["Blessing of Might"]=true, ["Segen der Macht"]=true,
    ["Greater Blessing of Might"]=true, ["Größerer Segen der Macht"]=true,
    ["Blessing of Wisdom"]=true, ["Segen der Weisheit"]=true,
    ["Greater Blessing of Wisdom"]=true, ["Größerer Segen der Weisheit"]=true,
    ["Blessing of Salvation"]=true, ["Segen der Rettung"]=true,
    ["Blessing of Light"]=true, ["Segen des Lichts"]=true,
    ["Blessing of Protection"]=true, ["Segen des Schutzes"]=true,
}

-- {buff}-Anzeige: eine kleine Locale-Tabelle im Sinn selbst (Auftrag verlangt genau das).
local BUFF_ANZEIGE = {
    ruestung         = { de = "Rüstung",         en = "Armor" },
    intelligenz      = { de = "Intelligenz",     en = "Intellect" },
    seelenstaerke    = { de = "Seelenstärke",    en = "Fortitude" },
    aspekt           = { de = "Aspekt",          en = "Aspect" },
    gift             = { de = "Gift",            en = "Poison" },
    daemonenruestung = { de = "Dämonenrüstung",  en = "Demon Armor" },
    daemonenhaut     = { de = "Dämonenhaut",     en = "Demon Skin" },
    maldeswildnis    = { de = "Mal der Wildnis", en = "Mark of the Wild" },
    schild           = { de = "Schild",          en = "Shield" },
    segen            = { de = "Segen",           en = "Blessing" },
}
local function buffAnzeige(schluessel)
    local e = BUFF_ANZEIGE[schluessel]
    if not e then return schluessel end
    local d = ns.sprache and ns.sprache() == "de"
    return d and e.de or e.en
end
W.buffAnzeige = buffAnzeige

-- Schurke: kein Aura-Scan, sondern GetWeaponEnchantInfo() — hasMainHandEnchant.
-- Rückgabe: true (fehlt), false (da), nil (unlesbar).
local function schurkeGiftFehlt()
    if not W.F.enchant then return nil end
    local ok, hatEnchant = pcall(_G.GetWeaponEnchantInfo)
    if not ok then return nil end
    if type(hatEnchant) ~= "boolean" then return nil end   -- muell
    return not hatEnchant
end
W.schurkeGiftFehlt = schurkeGiftFehlt

-- Je Klasse: level -> buff-Schlüssel oder nil. "nil" heißt hier immer "alles gut ODER nicht
-- prüfbar" — W.selbstbuffFehlt() selbst unterscheidet nach außen nicht zwischen beidem, weil
-- in beiden Fällen dieselbe Antwort richtig ist: schweigen.
local KLASSEN = {
    MAGE = function(lvl)
        if lvl < W.MAGIER_STUFE then return nil end
        local ruestung = spielerHatBuff(MAGIER_RUESTUNG_IDS, MAGIER_RUESTUNG_NAMEN)
        if ruestung == false then return "ruestung" end
        if ruestung == nil then return nil end
        local intel = spielerHatBuff(MAGIER_INT_IDS, MAGIER_INT_NAMEN)
        if intel == false then return "intelligenz" end
        return nil
    end,
    PRIEST = function(lvl)
        if lvl < W.PRIESTER_STUFE then return nil end
        local s = spielerHatBuff(PRIESTER_IDS, PRIESTER_NAMEN)
        if s == false then return "seelenstaerke" end
        return nil
    end,
    HUNTER = function(lvl)
        if lvl < W.JAEGER_STUFE then return nil end
        local s = spielerHatBuff(JAEGER_IDS, JAEGER_NAMEN)
        if s == false then return "aspekt" end
        return nil
    end,
    -- Krieger: ABSICHTLICH IMMER nil. Kampfschrei braucht Wut, die man außerhalb des Kampfes
    -- nicht hat — eine Meldung vor dem Pull würde einen Ressourcenverbrauch verlangen, den es
    -- dort gar nicht geben kann. Siehe Auftrag: "Krieger ausnehmen".
    WARRIOR = function() return nil end,
    ROGUE = function(lvl)
        if lvl < W.SCHURKE_STUFE then return nil end
        if schurkeGiftFehlt() == true then return "gift" end
        return nil
    end,
    WARLOCK = function(lvl)
        if lvl >= W.HEXER_RUESTUNG_STUFE then
            local s = spielerHatBuff(HEXER_RUESTUNG_IDS, HEXER_RUESTUNG_NAMEN)
            if s == false then return "daemonenruestung" end
            return nil
        end
        if lvl < W.HEXER_STUFE then return nil end
        local s = spielerHatBuff(HEXER_HAUT_IDS, HEXER_HAUT_NAMEN)
        if s == false then return "daemonenhaut" end
        return nil
    end,
    DRUID = function(lvl)
        if lvl < W.DRUIDE_STUFE then return nil end
        local s = spielerHatBuff(DRUIDE_IDS, DRUIDE_NAMEN)
        if s == false then return "maldeswildnis" end
        return nil
    end,
    SHAMAN = function(lvl)
        if lvl < W.SCHAMANE_STUFE then return nil end
        local s = spielerHatBuff(SCHAMANE_IDS, SCHAMANE_NAMEN)
        if s == false then return "schild" end
        return nil
    end,
    PALADIN = function(lvl)
        if lvl < W.PALADIN_STUFE then return nil end
        local s = spielerHatBuff(PALADIN_IDS, PALADIN_NAMEN)
        if s == false then return "segen" end
        return nil
    end,
}

local function klasseToken()
    if type(_G.UnitClass) ~= "function" then return nil end
    local ok, _, k = pcall(_G.UnitClass, "player")
    if not (ok and type(k) == "string" and k ~= "") then return nil end
    return k
end

-- ÖFFENTLICH: buff-Schlüssel (siehe BUFF_ANZEIGE) oder nil. Für den Prüfstand UND eine
-- spätere Dialogfrage (Auftrag). Läuft UNABHÄNGIG vom Häkchen "vorraete" — abgeschaltet ist
-- die ZEILE, nicht die Auskunft (Muster W.fertigeQuests() in Sinne/Welle13a.lua).
function W.selbstbuffFehlt()
    if not (W.F.aura or W.F.enchant) then return nil end
    local lvl = ns.Compat and ns.Compat.unitLevelLesbar and ns.Compat.unitLevelLesbar("player")
    if type(lvl) ~= "number" then return nil end
    local k = klasseToken()
    if not k then return nil end
    local fn = KLASSEN[k]
    if not fn then return nil end          -- unbekannte Klasse -> still
    local ok, ergebnis = pcall(fn, lvl)
    if not ok then return nil end
    return ergebnis
end

-- Eigene Drossel: 5 min Mindestabstand, danach erst wieder frei, wenn der Buff zwischenzeitlich
-- einmal da war ODER 10 min vergingen. Katalog-Drossel = "buff" (Core/Regie.lua drossel() lässt
-- diesen Wert unverändert durch — "der Sinn drosselt selbst").
local selbstbuffLetzte = -1e9
local selbstbuffGesehenSeitLetzter = true   -- true = frei (noch nie gemeldet ODER schon entspannt)

local function selbstbuffFrei(t)
    if t - selbstbuffLetzte < W.SELBSTBUFF_MIN then return false end
    if selbstbuffGesehenSeitLetzter then return true end
    return t - selbstbuffLetzte >= W.SELBSTBUFF_MAX
end

local function selbstbuffBlick()
    if not (W.F.aura or W.F.enchant) then return end
    if tot() or imKampf() or inLadebildschirm() then return end
    if not zielTauglich() then return end
    local buff = W.selbstbuffFehlt()
    if not buff then
        selbstbuffGesehenSeitLetzter = true    -- Buff da (oder unlesbar) -> Sperre entspannt sich
        return
    end
    if not an() then return end
    local t = jetzt()
    if not selbstbuffFrei(t) then return end
    if zielBelegt() then return end   -- MERGE20: ein Zielwechsel, hoechstens ein Satz
    if melde("SELBSTBUFF_FEHLT", { buff = buffAnzeige(buff), key = buff }) then
        selbstbuffLetzte = t
        selbstbuffGesehenSeitLetzter = false
    end
end
W.selbstbuffBlick = selbstbuffBlick   -- für den Prüfstand

ns.on("PLAYER_TARGET_CHANGED", function() pcall(selbstbuffBlick) end)

-- =============================================================================================
-- 3  TEIL B — WOHLGENAEHRT_FEHLT
-- =============================================================================================
-- ns.Alltag als Export gibt es nicht (nur ns.Sinne.Alltag, ohne öffentliche Namensliste) —
-- Auftrag erlaubt ausdrücklich den Rückfall auf eine eigene kleine Namenstabelle.
local WOHLGENAEHRT_NAMEN = { ["Well Fed"] = true, ["Wohlgenaehrt"] = true, ["Wohlgenährt"] = true }

-- Rückgabe: true (fehlt), false (da), nil (unlesbar).
local function wohlgenaehrtFehlt()
    if not auraApiDa() then return nil end
    for i = 1, W.AURA_MAX do
        local ok, aura = pcall(ns.Compat.auraByIndex, "player", i, "HELPFUL")
        if not ok then return nil end
        if aura == nil then return true end
        if type(aura) ~= "table" or (aura.name ~= nil and type(aura.name) ~= "string") then return nil end
        if aura.name and WOHLGENAEHRT_NAMEN[aura.name] then return false end
    end
    return true
end
W.wohlgenaehrtFehlt = wohlgenaehrtFehlt

local ELITE_KLASSEN = { elite = true, rareelite = true, worldboss = true }
local function eliteZiel()
    if type(_G.UnitClassification) ~= "function" then return false end
    local ok, k = pcall(_G.UnitClassification, "target")
    return ok and type(k) == "string" and ELITE_KLASSEN[k] == true
end

local function wohlgenaehrtStufeOk()
    local lvl = ns.Compat and ns.Compat.unitLevelLesbar and ns.Compat.unitLevelLesbar("player")
    return type(lvl) == "number" and lvl >= W.WOHLGENAEHRT_STUFE
end

local function wohlgenaehrtPruefen()
    if not W.F.aura then return end
    if tot() or imKampf() or inLadebildschirm() then return end
    if not an() then return end
    if not wohlgenaehrtStufeOk() then return end
    -- MERGE20: schon gesagt in dieser Sitzung -> gar nicht erst fragen. Sonst fiel jedes weitere
    -- Elite-Ziel als "drossel" in den Debug-Chat (dasselbe Rauschen wie FRAGE_NACHKLANG, Hotfix
    -- 22.09.). Derselbe Schluessel, den W.vergiss() oben zuruecksetzt.
    if ns.Regie and type(ns.Regie.session) == "table" and ns.Regie.session["WOHLGENAEHRT_FEHLT"] then return end
    if wohlgenaehrtFehlt() == true then
        meldeNachhol("WOHLGENAEHRT_FEHLT", nil, function()
            return an() and wohlgenaehrtStufeOk() and wohlgenaehrtFehlt() == true
                   and not (tot() or imKampf() or inLadebildschirm())
        end)
    end
end
W.wohlgenaehrtPruefen = wohlgenaehrtPruefen

-- 3a: Anvisieren eines angreifbaren Elite-Ziels außerhalb des Kampfes.
ns.on("PLAYER_TARGET_CHANGED", function()
    if not zielTauglich() then return end
    if not eliteZiel() then return end
    if zielBelegt() then return end   -- MERGE20: ein Zielwechsel, hoechstens ein Satz
    pcall(wohlgenaehrtPruefen)
end)

-- 3b: Betreten einer Party-Instanz (Flanke wie Sinne/Extra.lua REISECHECK, eigene Basislinie —
-- Extra.lua bleibt unberührt, diese Welle merkt sich den Instanz-Zustand selbst). Verzug =
-- REISECHECK-Verzug + 8 s, damit die Reisecheck-Zeile aus Extra.lua zuerst kommt.
local wohlgenaehrtInstanzVorher = nil   -- nil = Basislinie fehlt
local wohlgenaehrtInstanzId = 0

ns.on("PLAYER_ENTERING_WORLD", function()
    local drin = false
    if type(_G.IsInInstance) == "function" then
        local ok, v, art = pcall(_G.IsInInstance)
        drin = (ok and v and art == "party") and true or false
    end
    if wohlgenaehrtInstanzVorher == nil then
        wohlgenaehrtInstanzVorher = drin
        return
    end
    if drin == wohlgenaehrtInstanzVorher then return end
    wohlgenaehrtInstanzVorher = drin
    if not drin then return end
    wohlgenaehrtInstanzId = wohlgenaehrtInstanzId + 1
    local meineId = wohlgenaehrtInstanzId
    ns.Compat.After(W.WOHLGENAEHRT_INSTANZ_VERZUG, function()
        if meineId ~= wohlgenaehrtInstanzId or not wohlgenaehrtInstanzVorher then return end
        pcall(wohlgenaehrtPruefen)
    end)
end)

-- =============================================================================================
-- 4  TEIL C — VORRAT_KNAPP
-- =============================================================================================
-- REVIEW20 (Koordinator, 22.09.): die Listen kannten nur Haendlerware. Harald spielt Magier -
-- dessen Wasser und Brot sind HERBEIGEZAUBERT (Conjured Water/Bread, eigene IDs) und waeren
-- schlicht nicht gezaehlt worden: Wasser 0 von Anfang an (keine Flanke, nie eine Zeile), Essen
-- ebenso. Die herbeigezauberten Sorten aller Stufen stehen jetzt drin. Dazu ein Rueckfall fuer
-- alles Unbekannte der Unterklasse "Essen & Trinken" (classID 0, subClassID 5) - als ESSEN,
-- weil sich Trinken und Essen ohne Tooltip nicht trennen lassen und ein zu HOHER Essensstand
-- hoechstens eine Zeile kostet, ein zu niedriger aber eine falsche ("Regel 1: nur wenn knapp").
local WASSER_IDS = {
    [159]=true, [1179]=true, [1205]=true, [1708]=true, [1645]=true, [8766]=true,              -- Haendler
    [5350]=true, [2288]=true, [2136]=true, [3772]=true, [8077]=true, [8078]=true, [8079]=true, -- Conjured Water
}
local ESSEN_IDS = {
    [117]=true, [2287]=true, [4592]=true, [4593]=true, [4594]=true, [8952]=true, [4599]=true,
    [3770]=true, [3771]=true, [4536]=true, [4537]=true, [4538]=true, [4539]=true, [4540]=true,
    [4541]=true, [4542]=true, [4544]=true, [4601]=true, [8932]=true, [8950]=true, [8953]=true,
    [5349]=true, [1113]=true, [1114]=true, [1487]=true, [8075]=true, [8076]=true, [22895]=true, -- Conjured Bread
}
local function essenTrinkenUnterklasse(id)
    local fn = (type(_G.C_Item) == "table" and _G.C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    if type(fn) ~= "function" then return false end
    local ok, _, _, _, _, _, classID, subClassID = pcall(fn, id)
    return ok and tonumber(classID) == 0 and tonumber(subClassID) == 5
end
local MANA_KLASSEN = { MAGE=true, PRIEST=true, WARLOCK=true, DRUID=true, SHAMAN=true, PALADIN=true, HUNTER=true }

local function manaKlasse()
    local k = klasseToken()
    return k ~= nil and MANA_KLASSEN[k] == true
end

-- Eigener, kleiner Taschen-Leser mit pcall (Auftrag verbietet, Extra.lua anzufassen — dieselben
-- Existenzprüfungen wie X.taschenLesbar() dort, aber eine eigene Kopie).
local function taschenLesbar()
    if not W.F.container then return false end
    for bag = 0, 4 do
        local ok, n = pcall(CC.GetContainerNumSlots, bag)
        if ok and (tonumber(n) or 0) > 0 then return true end
    end
    return false
end

local function vorratZaehlen()
    local wasser, essen = 0, 0
    if not W.F.container then return wasser, essen end
    for bag = 0, 4 do
        local ok, slots = pcall(CC.GetContainerNumSlots, bag)
        for slot = 1, (ok and tonumber(slots) or 0) do
            local ok2, info = pcall(CC.GetContainerItemInfo, bag, slot)
            if ok2 and info then
                local id = tonumber(info.itemID)
                local n = tonumber(info.stackCount) or 1
                if id and WASSER_IDS[id] then wasser = wasser + n
                elseif id and ESSEN_IDS[id] then essen = essen + n
                elseif id and essenTrinkenUnterklasse(id) then essen = essen + n end   -- REVIEW20
            end
        end
    end
    return wasser, essen
end
W.vorratZaehlen = vorratZaehlen

local VORRAT_ANZEIGE = { wasser = { de = "Wasser", en = "Water" }, essen = { de = "Essen", en = "Food" } }
local function vorratAnzeige(schluessel)
    local e = VORRAT_ANZEIGE[schluessel]
    if not e then return schluessel end
    local d = ns.sprache and ns.sprache() == "de"
    return d and e.de or e.en
end

local wasserArmed, essenArmed = nil, nil   -- nil = Basislinie fehlt (Muster Sinne/Alltag.lua bagsArmed)

local function levelSchonGemeldet(lvl)
    if type(ns.char) ~= "table" then return true end   -- vor ns.initDB(): sicherheitshalber still
    ns.char.vorratStufen = ns.char.vorratStufen or {}
    return ns.char.vorratStufen[lvl] == true
end
local function levelAlsGemeldetMerken(lvl)
    if type(ns.char) ~= "table" then return end
    ns.char.vorratStufen = ns.char.vorratStufen or {}
    ns.char.vorratStufen[lvl] = true
end

local function vorratScan()
    if not an() then return end
    if tot() or imKampf() or inLadebildschirm() then return end   -- "Zeile nie im Kampf"
    if not taschenLesbar() then return end                        -- unbekannt ist kein Messwert
    local lvl = ns.Compat and ns.Compat.unitLevelLesbar and ns.Compat.unitLevelLesbar("player")
    if type(lvl) ~= "number" then return end

    local wasser, essen = vorratZaehlen()
    local wasserFlanke, essenFlanke = false, false

    if manaKlasse() then
        if wasserArmed == nil then wasserArmed = wasser > W.VORRAT_SCHWELLE
        elseif wasser > W.VORRAT_SCHWELLE then wasserArmed = true
        elseif wasserArmed then wasserArmed = false; wasserFlanke = true end
    end
    if essenArmed == nil then essenArmed = essen > W.VORRAT_SCHWELLE
    elseif essen > W.VORRAT_SCHWELLE then essenArmed = true
    elseif essenArmed then essenArmed = false; essenFlanke = true end

    if not (wasserFlanke or essenFlanke) then return end
    if levelSchonGemeldet(lvl) then return end

    -- Nur EINE Meldung je Stufe, insgesamt (nicht je Sorte). Fallen beide zugleich, gewinnt die
    -- Sorte mit dem knapperen Bestand (die dringlichere Beobachtung).
    local schluessel, n
    if wasserFlanke and essenFlanke then
        if wasser <= essen then schluessel, n = "wasser", wasser else schluessel, n = "essen", essen end
    elseif wasserFlanke then schluessel, n = "wasser", wasser
    else schluessel, n = "essen", essen end

    if n <= 0 then return end   -- "bei 0 keine eigene Zeile"

    -- Der Stufen-Merker wird VOR dem Versuch gesetzt, nicht erst nach Erfolg: meldeNachhol()
    -- kann den eigentlichen Satz Sekunden später über einen Timer nachreichen (Kollision mit
    -- Sinne/Extra.lua REISECHECK o. Ä.), und in der Zwischenzeit könnte ein zweiter Scan
    -- (BAG_UPDATE_DELAYED, PLAYER_REGEN_ENABLED) dieselbe Stufe ein zweites Mal für "frei"
    -- halten. "Einmal je Stufe" wiegt hier schwerer als "garantiert gesagt" — ein Moment, der
    -- durch Budget/Gruppen-Schweigen ganz verloren geht, bleibt für diese Stufe still, statt
    -- die Zusicherung zu brechen (dieselbe Abwägung wie Regel 1: Schweigen ist der sichere Fehler).
    levelAlsGemeldetMerken(lvl)
    meldeNachhol("VORRAT_KNAPP", { n = n, was = vorratAnzeige(schluessel) }, function()
        return an() and not (tot() or imKampf() or inLadebildschirm())
    end)
end
W.vorratScan = vorratScan

local vorratBagDrosselBis = 0
ns.on("BAG_UPDATE_DELAYED", function()
    local t = jetzt()
    if t < vorratBagDrosselBis then return end
    vorratBagDrosselBis = t + W.VORRAT_BAG_DROSSEL
    pcall(vorratScan)
end)

ns.on("PLAYER_REGEN_ENABLED", function()
    ns.Compat.After(W.VORRAT_KAMPF_VERZUG, function() pcall(vorratScan) end)
end)

-- =============================================================================================
-- /lyra vergiss vorraete  (Welle18 ruft W.vergiss() — Einbauabschnitt im Bericht §5)
-- =============================================================================================
function W.vergiss()
    selbstbuffLetzte = -1e9
    selbstbuffGesehenSeitLetzter = true
    wohlgenaehrtInstanzVorher = nil
    wasserArmed, essenArmed = nil, nil
    vorratBagDrosselBis = 0
    if ns.Regie and type(ns.Regie.session) == "table" then
        ns.Regie.session["WOHLGENAEHRT_FEHLT"] = nil
    end
    if type(ns.char) == "table" then
        ns.char.vorratStufen = {}
    end
end

-- =============================================================================================
-- /lyra status
-- =============================================================================================
function W.status()
    local d = (ns.sprache and ns.sprache() == "de")
    local out = {}

    out[#out + 1] = (d and "Vorräte und Selbstbuffs: %s" or "Supplies and self-buffs: %s"):format(
        an() and (d and "an" or "on") or (d and "aus" or "off"))

    out[#out + 1] = (d and "  Klassenbuff: %s" or "  Class buff: %s"):format(
        (not (W.F.aura or W.F.enchant)) and (d and "fehlt (keine Aura-API, kein Waffen-Enchant-Zugriff)"
                                                  or "missing (no aura API, no weapon-enchant access)")
        or (function()
            local k = klasseToken()
            if k == "WARRIOR" then return d and "Krieger ausgenommen (Kampfschrei braucht Wut)"
                                            or "warrior exempt (Battle Shout needs rage)" end
            local buff = W.selbstbuffFehlt()
            if buff then return (d and "fehlt gerade: %s" or "currently missing: %s"):format(buffAnzeige(buff)) end
            return d and "gerade nichts offen" or "nothing open right now"
        end)())

    out[#out + 1] = (d and "  Wohlgenährt vor Elite/Instanz: %s" or "  Well fed before elite/instance: %s"):format(
        (not W.F.aura) and (d and "fehlt (keine Aura-API)" or "missing (no aura API)")
        or (not wohlgenaehrtStufeOk()) and (d and "unter Stufe %d" or "under level %d"):format(W.WOHLGENAEHRT_STUFE)
        or (d and "bereit (einmal je Sitzung)" or "ready (once per session)"))

    out[#out + 1] = (d and "  Wasser/Essen-Zähler: %s" or "  Water/food counter: %s"):format(
        (not W.F.container) and (d and "fehlt (keine Taschen-API)" or "missing (no bag API)")
        or (function()
            local wasser, essen = vorratZaehlen()
            return (d and "Wasser %d, Essen %d (Schwelle %d)" or "water %d, food %d (threshold %d)")
                :format(wasser, essen, W.VORRAT_SCHWELLE)
        end)())

    return out
end
