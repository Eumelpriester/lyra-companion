-- Core/Compat.lua — Client-Erkennung, Feature-Flags und API-Shims. Die EINZIGE Stelle im Addon,
-- die weiss, auf welchem Client sie laeuft. Alles andere fragt Flags, nie Versionsnummern.
--
-- Stand 18.09.2026, gepruefte Quellen (Blizzards eigene API-Doku, Branches von Gethe/wow-ui-source):
--   live                 12.1.0.69814   Retail "Midnight"      ## Interface 120100
--   classic_era          1.15.9.69722   Classic Era/Hardcore    ## Interface 11509
--   classic_anniversary  2.5.6.69795    Burning Crusade         ## Interface 20506
--   classic              5.5.4.69585    Mists of Pandaria       ## Interface 50504
--   forever              1.60.1.69913   WoW: Forever (Beta)     ## Interface 16001 (Beta-Nummer!)
--                        WOW_PROJECT_ID == 1, also DERSELBE Wert wie Retail (MAINLINE).
--                        Forever hat KEINE eigene Projekt-Konstante (Welle 12a, 21.09.2026,
--                        Beleg: docs/recherche/16-forever-2026-09-21.md §1.2/§1.3).
--
-- DIE DREI BEFUNDE, AUS DENEN DIESE DATEI BESTEHT:
--
-- 1. Forever ist ein MAINLINE-Client, kein Classic-Client. Der Branch `forever` hat
--    C_QuestLog.GetInfo, C_Secrets, C_UnitAuras, den Mainline-Combat-Log
--    (Blizzard_CombatLogBase/[Family] loest fuer camelot nach Mainline auf) und
--    C_CombatAudioAlert. Die alte Weiche "unbekannte WOW_PROJECT_ID => Classic-Pfad"
--    (Questie-Muster) haette dort COMBAT_LOG_EVENT_UNFILTERED registriert und dem Spieler
--    ADDON_ACTION_FORBIDDEN mit Lyras Namen darin gezeigt.
-- 2. Aber Forever hat C_GameRules.IsHardcoreActive (Retail hat es NICHT). Hardcore-Erbe,
--    Gedenktag und die HC-Strenge laufen dort also weiter — das ist mehr, als wir erwartet hatten.
-- 3. C_VoiceChat.SpeakText(voiceID, text, rate, volume [, overlap]) hat auf ALLEN FUENF
--    Clients dieselbe Signatur. Auf live/forever stehen die Argumente als NeverSecret bzw.
--    ConditionalSecret in der Doku, d. h. der Aufruf ist auch unter Secret Values erlaubt.
--
-- ERKENNUNG: FEATURE ZUERST, Zahl als Rueckfall, Projekt-ID erst danach — und die
-- gefaehrlichen Flags haengen am FEATURE, nicht an der Zahl. (W12A: hier stand bis zum
-- 21.09.2026 "Zahl zuerst, Feature als Rueckfall". Das war genau verkehrt herum; profilBestimmen()
-- fragt seit W6 als ERSTES C_QuestLog.GetInfo / C_RestrictedActions. Auf Forever ist das der
-- Unterschied, der zaehlt: dort meldet WOW_PROJECT_ID eine 1 — denselben Wert wie Retail —,
-- und wuerde die ID vor dem Feature-Test gefragt, landete Forever auf dem Retail-Profil.
-- Erreicht wird die ID-Stufe auf Forever nie, weil der Feature-Test vorher greift.)
-- `16001` ist die Beta-Nummer vom 17.09.2026; zum Launch am 04.11. wird sie hoeher sein. Eine
-- feste Gleichheit waere zum Launch falsch, ein Bereich (C.FOREVER_MIN..MAX = 16000-19999)
-- haelt eine Buildlinie 1.6x bis 1.9x durch, und wenn selbst der bricht, faengt
-- `C_QuestLog.GetInfo` den Client als "mainline-artig" ein. Der Fehler geht damit immer in die
-- sichere Richtung: kein Combat-Log, Secret-Wachen an.
--
-- API (nur lesend): GetBuildInfo, WOW_PROJECT_*-Konstanten, C_AddOns, C_GameRules, C_Container,
--   C_UnitAuras, C_QuestLog, C_Timer, C_VoiceChat, issecretvalue. Kein Schreibzugriff, nichts Fremdes.
local ADDON, ns = ...
ns.Compat = {}
local C = ns.Compat

-- ---------------------------------------------------------------- Rohdaten
local pid = WOW_PROJECT_ID or 0
C.version = select(4, GetBuildInfo()) or 0
local v = C.version

-- Mainline-Marker per FEATURE. C_QuestLog.GetInfo gibt es nur auf der Mainline-Codefamilie
-- (live UND forever); classic_era, classic_anniversary und classic haben statt dessen
-- C_QuestLog.GetQuestInfo und das globale GetQuestLogTitle. Das ist der einzige Test, der
-- eine neue Buildnummer ueberlebt.
local mainlineApi = (C_QuestLog and C_QuestLog.GetInfo) and true or false

-- W6 (P2-5, Recherche 11 §3.1): ein ZWEITER Laufzeit-Marker. C_RestrictedActions ist der
-- Baum, ueber den Blizzard seit 12.x die Addon-Beschraenkungen meldet; Details fragt ihn auf
-- seinem Mainline-Pfad ab (Details/core/parser_nocleu1.lua:249-253,
-- C_RestrictedActions.GetAddOnRestrictionState(Enum.AddOnRestrictionType.Combat)). Auf
-- classic_era, classic_anniversary und classic gibt es ihn nicht.
-- WOZU, wenn C_QuestLog.GetInfo denselben Dienst tut: damit die Erkennung nicht an EINEM
-- Funktionsnamen haengt. Zum Forever-Launch am 04.11.2026 aendert sich die Interface-Nummer,
-- und eine Nummer ausserhalb von 16000-16999 haette den Client bisher nach Interface-Bereich
-- einsortiert (20000-29999 waere "tbc" gewesen - mit Combat-Log-Registrierung und ohne
-- Secret-Wachen). Zwei unabhaengige Feature-Tests sind dagegen die Versicherung.
local restrictedApi = (C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState)
                      and true or false

-- Spielmodus, falls der Client ihn hergibt. NUR fuer /lyra status und die Fehlersuche:
-- GetActiveGameMode liefert laut Doku den Typ "GameMode" (Enum, nicht garantiert ein String),
-- deshalb haengt hier KEINE Entscheidung daran.
C.spielmodus = nil
if C_GameRules and C_GameRules.GetActiveGameMode then
    local ok, m = pcall(C_GameRules.GetActiveGameMode)
    if ok then C.spielmodus = m end
end

-- ---------------------------------------------------------------- Forever-Vorbereitung (W10B)
-- ROADMAP 10-6: "Forever-TOC vorbereiten, aber nicht setzen." Die TOC-Zeile bleibt draussen
-- (Lyra_Gestalt.toc, Kommentarblock Zeile 14-24) - das hier ist die Seite, die schon stehen
-- muss, damit das EINTRAGEN DER ZEILE spaeter keine Codeaenderung mehr braucht.
--
-- DREI DINGE, DIE SICH ZUM LAUNCH AM 04.11.2026 AENDERN KOENNEN, UND WAS HIER DAGEGEN STEHT:
--
--  1. DIE BUILDNUMMER. 16001 ist die Beta vom 17.09.2026 (1.60.1.69913). Zum Launch steht dort
--     etwas anderes. Der Feature-Weg (C_QuestLog.GetInfo / C_RestrictedActions) faengt das
--     ohnehin - der Nummern-Weg ist der Rueckfall fuer einen Client, der BEIDE Marker verliert.
--     Bisher lief der Rueckfall von 16000 bis 16999, also genau ueber die Buildlinie 1.60.x.
--     Eine 1.7x-Linie waere 17000 gewesen und damit durch JEDES Fenster gefallen - und der
--     naechste Vergleich in der Kette (20000-29999) heisst "tbc", mit Combat-Log-Registrierung
--     und ohne Secret-Wachen. Der Bereich steht darum als BENANNTE KONSTANTE und reicht bis
--     19999: alles, was mit 1.6 bis 1.9 ausgeliefert werden kann. Wer ihn spaeter weiten muss,
--     aendert eine Zahl an einer Stelle, keine Logik.
--  2. DAS TOC-SUFFIX. ENTSCHIEDEN am 21.09.2026 (Welle 12a): `Camelot`, kein Kandidatenpaar
--     mehr. Der Beleg liegt auf diesem Rechner, im Quelltext des Packagers selbst:
--     release/release.sh Zeile 1992 schreibt fuer den Flavor forever "_Camelot.toc", und die
--     Suffix-Erkennung (Zeile 1175) kennt ebenfalls nur "Camelot". Die DIREKTIVE liest er in
--     beiden Schreibweisen ("## Interface-Camelot:" wie "## Interface-Forever:"), die DATEI
--     heisst aber immer _Camelot.toc. Wago akzeptiert vier Schreibweisen, der Packager eine —
--     also ist "Camelot" die, die ueberall traegt. Die Zeile steht seit heute in allen fuenf
--     TOCs; docs/toc-forever.muster ist auf diesen Stand eingedampft.
--     (Ehrlich dazu: "Camelot" ist der Codename aus dem UI-Branch und in KEINER
--     Blizzard-Quelle bestaetigt. Belegt ist, dass die Werkzeuge ihn benutzen.)
--  3. OB DIE TOC UEBERHAUPT ANKOMMT. Genau dafuer ist C.tocInterface da: der Client meldet ueber
--     GetAddOnMetadata die Interface-Zahl DER TOC, DIE ER GELADEN HAT. Laeuft Lyra auf Forever
--     und steht dort 11509, dann ist die suffixlose Basis-TOC geladen - die Flavor-Zeile fehlt
--     oder der Packager kennt den Flavor noch nicht (recherche/10 A1). Das ist der Wert, der
--     in einem Bugreport den Unterschied macht; er liegt in C.bericht() bereit. Die ANZEIGE
--     steht seit Welle 12a in /lyra status (Sinne/Welle6.lua, Zeile "Geladene TOC").
--
--  4. DIE PROJEKT-ID IST AUF FOREVER KEIN UNTERSCHEIDER. Der Client meldet WOW_PROJECT_ID == 1,
--     denselben Wert wie Retail; eine eigene Forever-Konstante gibt es nicht. Deshalb steht die
--     Projekt-ID in profilBestimmen() an DRITTER Stelle und wird auf Forever nie erreicht - der
--     Feature-Test entscheidet vorher. Wer die Reihenfolge je umdreht, schickt jeden
--     Forever-Spieler auf das Retail-Profil (Beleg: recherche/16 §1.3).
C.FOREVER_MIN, C.FOREVER_MAX = 16000, 19999
-- W12A: ein Suffix je Profil, kein Kandidatenpaar mehr (Begruendung Punkt 2 oben).
C.TOC_SUFFIX = { forever = "Camelot", era = "Vanilla", tbc = "TBC",
                 mists = "Mists", retail = "Mainline" }

-- Interface-Zahl der geladenen TOC. nil heisst "der Client sagt es nicht" - nie geraten.
C.tocInterface = nil
do
    local hol = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if hol then
        local ok, v2 = pcall(hol, ADDON, "Interface")
        if ok then C.tocInterface = tonumber(v2) end
    end
end

-- ---------------------------------------------------------------- Profil
-- "era" | "tbc" | "mists" | "retail" | "forever"
C.weiche = nil          -- "feature" | "nummer" | "projekt" | "rueckfall" (nur fuer /lyra status)
local function profilBestimmen()
    -- 0. W6 (P2-5): LAUFZEIT-TEST ZUERST. Ein mainline-artiger Client darf NIE auf einem
    --    Classic-Profil landen, egal was die Interface-Nummer sagt - dort wuerde Lyra
    --    COMBAT_LOG_EVENT_UNFILTERED registrieren und dem Spieler ADDON_ACTION_FORBIDDEN
    --    mit ihrem Namen darin zeigen. Umgekehrt ist der Fehler harmlos (ein Feature weniger).
    --    Era, TBC und MoP haben weder C_QuestLog.GetInfo noch C_RestrictedActions; fuer sie
    --    ist dieser Block ein toter Vergleich und die Nummer entscheidet wie bisher.
    --    Retail und Forever trennt danach die Groessenordnung: Retail steht bei 120100,
    --    Forever bei 16001 (Beta) - eine Stelle, die auch eine unbekannte Forever-Nummer
    --    ueberlebt, solange sie unter 100000 bleibt.
    if mainlineApi or restrictedApi then
        C.weiche = "feature"
        if v >= 100000 then return "retail" end
        return "forever"
    end
    -- 1. Interface-Nummer. Eindeutig, solange die Bereiche gelten.
    C.weiche = "nummer"
    -- W10B: benannter Bereich statt 16000-16999 (Begruendung im Block oben, Punkt 1).
    if v >= C.FOREVER_MIN and v <= C.FOREVER_MAX then return "forever" end
    if v >= 100000              then return "retail"  end
    if v >= 50000 and v < 60000 then return "mists"   end
    if v >= 20000 and v < 30000 then return "tbc"     end
    if v >= 11000 and v < 12000 then return "era"     end
    -- 2. Projekt-ID, wenn die Nummer nichts hergibt (GetBuildInfo kaputt, Build 0).
    C.weiche = "projekt"
    if pid == (WOW_PROJECT_MAINLINE or 1) then return "retail" end
    if pid == (WOW_PROJECT_MISTS_CLASSIC or 19) then return "mists" end
    if pid == (WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5) then return "tbc" end
    if pid == (WOW_PROJECT_CLASSIC or 2) then return "era" end
    -- 3. Voellig unbekannter Client: die API entscheidet, und zwar in die sichere Richtung.
    C.weiche = "rueckfall"
    if mainlineApi then return "retail" end
    return "era"
end
C.profil = profilBestimmen()

-- Mainline-artig = Secret Values, gesperrter Combat-Log, Retail-Questlog. Alle Wege duerfen
-- es setzen; keiner darf es zuruecknehmen. Ein falsches "ja" kostet ein Feature, ein falsches
-- "nein" kostet eine Blizzard-Fehlermeldung mit unserem Namen darin.
C.istMainlineArtig = (C.profil == "retail") or (C.profil == "forever") or mainlineApi or restrictedApi
C.mainlineApi = mainlineApi
C.restrictedApi = restrictedApi   -- W6: der zweite Laufzeit-Marker, fuer /lyra status

-- Alt-Namen, die der Rest des Addons schon benutzt (Sinne/Rituale.lua, Sinne/Chronik.lua, ...).
C.istRetail  = (C.profil == "retail")
C.istForever = (C.profil == "forever")
C.istEra     = (C.profil == "era")
C.istTBC     = (C.profil == "tbc")
C.istMists   = (C.profil == "mists")
C.istClassic = not C.istMainlineArtig

-- W10B: Passt die geladene TOC zum laufenden Client? true | false | nil ("der Client sagt es
-- nicht"). NICHTS haengt daran - es ist eine Anzeige fuer /lyra status und fuer Bugreports.
-- Auf Forever heisst `false`: die Flavor-Zeile fehlt (oder der Packager kennt den Flavor noch
-- nicht), das Addon laeuft aus der suffixlosen Basis-TOC und der Client zeigt "veraltet".
-- Genau diesen Zustand nimmt Roadmap 10-6 bewusst in Kauf, solange die Nummer unbelegt ist.
C.TOC_BEREICH = {
    era     = { 11000,  11999  },
    tbc     = { 20000,  29999  },
    mists   = { 50000,  59999  },
    retail  = { 100000, 999999 },
    forever = { C.FOREVER_MIN, C.FOREVER_MAX },
}
function C.tocPasst()
    local t = C.tocInterface
    if not t then return nil end
    local b = C.TOC_BEREICH[C.profil]
    if not b then return nil end
    return (t >= b[1] and t <= b[2])
end

-- ---------------------------------------------------------------- Secret Values
-- issecretvalue(v) / canaccessvalue(v) sind Lua-Globale des Clients (Retail 12.0+, Forever).
-- Sie stehen NICHT in der generierten API-Doku, also nur per Existenzpruefung.
local secretApi = (type(issecretvalue) == "function")

-- Ist dieser Wert ein Secret? Ohne die API: nein (Classic hat keine Secrets).
function C.istSecret(wert)
    if not secretApi then return false end
    local ok, r = pcall(issecretvalue, wert)
    return (ok and r) and true or false
end

-- Eine Zahl, mit der man RECHNEN darf — oder nil. Drei Wachen, weil jede allein Luecken hat:
--   1. issecretvalue, wenn der Client sie hat (der saubere Weg)
--   2. type() == "number" (ein Secret ist kein number)
--   3. eine Probe-Rechnung in pcall (faengt einen Client, der Secrets als number ausgibt)
function C.zahl(wert)
    if wert == nil then return nil end
    if C.istSecret(wert) then return nil end
    if type(wert) ~= "number" then return nil end
    if secretApi then
        local ok = pcall(function() return wert + 0 end)
        if not ok then return nil end
    end
    return wert
end

-- Lohnt es sich ueberhaupt, Werte FREMDER Einheiten zu lesen? Auf Mainline-Clients sind sie
-- in Kampf, Instanz, M+ und PvP secret. Werte des SPIELERS (UnitHealth("player"),
-- UnitHealthMax, UnitPowerMax) bleiben dort ausdruecklich lesbar — die Lebenswarnung, der
-- Kern des Addons, ist also nirgends betroffen.
function C.fremdwerteLesbar()
    if not C.F.secretValues then return true end
    if UnitAffectingCombat then
        local ok, k = pcall(UnitAffectingCombat, "player")
        if ok and k then return false end
    end
    if IsInInstance then
        local ok, drin = pcall(IsInInstance)
        if ok and drin then return false end
    end
    return true
end

-- ---------------------------------------------------------------- Feature-Flags
-- Der Rest des Addons fragt AUSSCHLIESSLICH diese Tabelle. Keine Versionsnummern in Sinne/*.
C.F = {
    -- COMBAT_LOG_EVENT_UNFILTERED. Auf Retail 12.0+ und Forever feuert schon der
    -- RegisterEvent-Versuch ADDON_ACTION_FORBIDDEN — das ist keine Feldzensur, das ist eine Tuer.
    --
    -- WICHTIG: Der zweite Teil der Bedingung ist KEIN Schutz vor Mainline, sondern nur die
    -- Frage "gibt es die Lesefunktion ueberhaupt" (sehr alte Classic-Builds).
    --
    -- W12A-KORREKTUR (21.09.2026): Hier stand bis heute, CombatLogGetCurrentEventInfo
    -- EXISTIERE auf Retail/Forever weiterhin (ueber Blizzard_DeprecatedCombatLog). Ein
    -- eingefangener API-Abzug des Forever-Beta-Clients (6045 Globale, Build 1.60.1.69893)
    -- enthaelt die Funktion NICHT - siehe docs/recherche/16-forever-2026-09-21.md §3.3.
    -- Auf Forever ist die Bedingung damit DOPPELT falsch: der Riegel `not C.istMainlineArtig`
    -- greift, und die Funktion fehlt ohnehin. Folgenlos fuer das Verhalten, aber der Satz war
    -- falsch - und ein falscher Satz in dieser Datei ist teuer, weil ihn jeder glaubt, der
    -- spaeter die Weiche anfasst.
    -- Der Riegel bleibt `not C.istMainlineArtig`, sonst nichts: auf Retail, wo es die Funktion
    -- sehr wohl geben kann, feuert schon der RegisterEvent-Versuch ADDON_ACTION_FORBIDDEN.
    combatLog   = (not C.istMainlineArtig) and (CombatLogGetCurrentEventInfo ~= nil),
    secretValues = secretApi or C.istMainlineArtig,
    -- Questlog: Classic hat GetQuestLogTitle(i), Mainline C_QuestLog.GetInfo(i).
    quests      = mainlineApi and "retail" or "classic",
    container   = (C_Container and C_Container.GetContainerNumSlots) and "c_container"
                  or (GetContainerNumSlots and "legacy" or false),
    auren       = (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) and "c_unitauras"
                  or (UnitAura and "legacy" or false),
    settingsApi = (Settings and Settings.RegisterVerticalLayoutCategory
                   and Settings.RegisterProxySetting and Settings.RegisterAddOnCategory
                   and CreateSettingsListSectionHeaderInitializer) and true or false,
    -- C_GameRules.IsHardcoreActive: Era, TBC, MoP und FOREVER haben es, Retail nicht.
    hardcoreApi = (C_GameRules and C_GameRules.IsHardcoreActive) and true or false,
    mirrorTimer = (GetMirrorTimerProgress or GetMirrorTimerInfo) and true or false,
    tts         = (C_VoiceChat and C_VoiceChat.SpeakText) and true or false,
    -- Lagerfeuer: es gibt im ganzen Forever-Beta-UI (5058 Dateien) keinen Treffer fuer
    -- Camp*/Campfire/Bonfire — das angekuendigte Camping-System hat noch keine Addon-API.
    -- Erkannt wird darum weiter der KOCHFEUER-Buff (Sinne/Rituale.lua), und der braucht
    -- lesbare Spieler-Auren; die gibt es ueberall.
    campfire    = ((C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) or UnitAura) and true or false,
    -- Weltfeste: Braufest und Pilgerfreuden gibt es in Vanilla-Azeroth nicht. Forever ist
    -- Vanilla-Inhalt mit Mainline-API, gehoert hier also zu "era".
    feste       = (C.profil == "retail" or C.profil == "mists") and "modern" or "era",
    -- Munitionsplatz (Jaeger) und Rune der Teleportation (Magier) — das ist KEINE API-Frage,
    -- sondern eine Frage des Spielinhalts. Beides gibt es in Vanilla und TBC; mit Cataclysm
    -- 4.0.1 sind Munitionsplatz und Teleport-Reagenzien weggefallen, also auch in MoP und Retail.
    -- FOREVER steht hier bewusst auf false, obwohl es Vanilla-Inhalt ist: Blizzard hat Klassen
    -- und Berufe ueberarbeitet, und ein FALSCHER Hinweis ("dir fehlen Reagenzien") ist
    -- schlimmer als ein fehlender. Ein Beta-Test klaert das mit zwei Blicken ins Inventar —
    -- siehe docs/port-2026-09-18.md, Pruefliste Z-7.
    klassischeAusruestung = (C.profil == "era" or C.profil == "tbc"),
    -- REVIEW9: Gefahrenkarte (Paket Lyra_Gestalt_Daten). Das ist KEINE API-Frage: die Zellen sind
    -- aggregierte Hardcore-Tode aus der Deathlog-Datenbank, also Classic-Era-Material — dieselbe
    -- mapID, aber eine andere Welt. Auf Retail liegen hinter den Vanilla-mapIDs ueberarbeitete
    -- Zonen ohne Hardcore, auf FOREVER ueberarbeitete Klassen, Mobs und Wege. Bisher lief die
    -- Uebernahme dort einfach mit und fand meist nichts (docs/port-2026-09-18.md, §7 Punkt 7) —
    -- "meist" ist die Luecke: eine Zelle, die doch passt, ist dort eine FALSCHE Warnung, und die
    -- ist schlimmer als gar keine (dieselbe Begruendung wie bei klassischeAusruestung).
    -- MoP-Classic bleibt bewusst an: Vanilla-Azeroth ist dort dieselbe Welt (wenn auch Cata-Stand),
    -- und die Sturz-/Wasser-Zellen — die Mehrheit der Zellen — sind Gelaende, nicht Spielinhalt.
    gefahrenkarte = not (C.profil == "retail" or C.profil == "forever"),
}

-- Alt-Name, damit eine aeltere Kopie von Sinne/Chronik.lua (release/) nicht bricht.
C.combatLogErlaubt = C.F.combatLog

-- ---------------------------------------------------------------- Hardcore / Self-Found
-- W6 (P1-3, Recherche 11 §0.2): C_GameRules gibt es auf classic_era, classic_anniversary,
-- classic und forever - und genau NICHT auf live (Retail). docs/companion-v3.md B.2 sagte,
-- ein `C_GameRules.IsSelfFound*` existiere nicht; der Branch-Vergleich der generierten
-- Blizzard-Doku widerlegt das. Damit wird aus dem Handschalter `ssf` (UI/Slash.lua:314) eine
-- echte Erkennung - die den Schalter aber NICHT setzt (siehe unten).
--
-- Zwei Wege je Frage, beide in pcall:
--   1. die benannte Funktion (IsHardcoreActive / IsSelfFoundAllowed)
--   2. plattformneutral C_GameRules.IsGameRuleActive(Enum.GameRule.<X>)
--      (Enum.GameRule.SelfFoundAllowed = 22, HardcoreRuleset = 10 - die Zahlen stehen hier
--      NICHT hart im Code: wir fragen das Enum, und fehlt es, entfaellt der zweite Weg.)
-- C.hcQuelle / C.ssfQuelle halten fest, welcher gegriffen hat - /lyra status zeigt es.
C.hcQuelle, C.ssfQuelle = nil, nil

local function regel(name, enumName)
    if not C_GameRules then return nil, nil end
    if C_GameRules[name] then
        local ok, r = pcall(C_GameRules[name])
        if ok then return (r and true or false), "C_GameRules." .. name end
    end
    if C_GameRules.IsGameRuleActive and Enum and Enum.GameRule and Enum.GameRule[enumName] then
        local ok, r = pcall(C_GameRules.IsGameRuleActive, Enum.GameRule[enumName])
        if ok then return (r and true or false), "Enum.GameRule." .. enumName end
    end
    return nil, nil
end

function C.istHardcore()
    local r, quelle = regel("IsHardcoreActive", "HardcoreRuleset")
    C.hcQuelle = quelle or "-"
    -- Rueckfall auf die bisherige Erkennung: gab es die API noch nie, war die Antwort "false".
    -- Das bleibt so - eine Vermutung waere auf Hardcore der teuerste Fehler im ganzen Addon.
    if r == nil then return false end
    return r
end
C.isHardcore = C.istHardcore        -- Alias

-- true | false | nil. nil heisst "der Client sagt es nicht" - und DANN entscheidet der
-- Schalter, nicht die Vermutung.
--
-- ACHTUNG, das ist der feine Unterschied: IsSelfFoundAllowed heisst "auf diesem Realm
-- ERLAUBT", nicht "dieser Charakter spielt so". Lyra darf daraus also einen ANLASS zum Fragen
-- ableiten, nie eine Einstellung. Die Regel aus companion-v3 bleibt: Lyra fragt einmal, sie
-- setzt den Schalter nicht selbst. Spielweise ist keine Messung.
function C.istSelbstgefunden()
    local r, quelle = regel("IsSelfFoundAllowed", "SelfFoundAllowed")
    C.ssfQuelle = quelle or "-"
    return r
end

-- ---------------------------------------------------------------- Addons
-- LoadOnDemand-Addons laden (C_AddOns seit Era 1.15.0, globales LoadAddOn auf Retail entfernt).
function C.ladeAddon(name)
    if C_AddOns and C_AddOns.LoadAddOn then return C_AddOns.LoadAddOn(name) end
    if LoadAddOn then return LoadAddOn(name) end
    return false
end
function C.addonInstalliert(name)
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local ok, st = pcall(C_AddOns.GetAddOnEnableState, name)
        return ok and st and st > 0
    end
    if GetAddOnEnableState then
        local ok, st = pcall(GetAddOnEnableState, nil, name)
        return ok and st and st > 0
    end
    return false
end

-- ---------------------------------------------------------------- Auren
-- C_UnitAuras ueberall vorhanden (Era seit 1.15.1); Fallback auf UnitAura (auf Retail entfernt).
function C.auraByIndex(unit, i, filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        return C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
    end
    if UnitAura then
        local name, icon, count, dtype, duration, expires, source, _, _, spellId = UnitAura(unit, i, filter)
        if not name then return nil end
        return { name = name, icon = icon, applications = count, duration = duration, expirationTime = expires, spellId = spellId, sourceUnit = source }
    end
    return nil
end

-- ---------------------------------------------------------------- Container
C.Container = C_Container or {
    GetContainerNumSlots = GetContainerNumSlots,
    GetContainerNumFreeSlots = GetContainerNumFreeSlots,
    GetContainerItemInfo = function(bag, slot)
        local icon, count, locked, quality, readable, lootable, link, _, _, itemID = GetContainerItemInfo(bag, slot)
        if not icon then return nil end
        return { iconFileID = icon, stackCount = count, quality = quality, hyperlink = link, itemID = itemID }
    end,
}

-- ---------------------------------------------------------------- Timer
C.After = (C_Timer and C_Timer.After) or function(s, f) f() end
C.NewTicker = (C_Timer and C_Timer.NewTicker) or function() return { Cancel = function() end } end

-- ---------------------------------------------------------------- Leben (Secret-Values-Wache)
-- Rueckgabe: cur, max, prozent — oder nil, wenn der Wert nicht lesbar ist.
-- Fuer "player" ist das auf JEDEM Client lesbar (Blizzard-Zusage zu Secret Values).
-- Fuer fremde Einheiten kann es im Kampf/in der Instanz nil geben; das ist kein Fehler,
-- das ist die Antwort.
function C.unitHealthLesbar(unit)
    unit = unit or "player"
    if not (UnitHealth and UnitHealthMax) then return nil end
    if unit ~= "player" and not C.fremdwerteLesbar() then return nil end
    local ok, cur = pcall(UnitHealth, unit)
    if not ok then return nil end
    local ok2, max = pcall(UnitHealthMax, unit)
    if not ok2 then return nil end
    cur, max = C.zahl(cur), C.zahl(max)
    if not (cur and max) or max <= 0 then return nil end
    return cur, max, math.floor(cur / max * 100 + 0.5)
end

-- Stufe einer Einheit als RECHENBARE Zahl oder nil. Ziel-Level ist auf Mainline-Clients im
-- Kampf secret (Sinne/Kampf.lua GEFAHR_STUFEN haengt daran).
function C.unitLevelLesbar(unit)
    if not UnitLevel then return nil end
    if unit ~= "player" and not C.fremdwerteLesbar() then return nil end
    local ok, lvl = pcall(UnitLevel, unit)
    if not ok then return nil end
    return C.zahl(lvl)
end

-- ---------------------------------------------------------------- Questlog-Shim
-- Ein einheitlicher Eintrag fuer beide Welten:
--   { titel, level, header, complete, questID }
-- Classic: GetQuestLogTitle(i) -> title, level, suggestedGroup, isHeader, isCollapsed,
--          isComplete, frequency, questID, ...
-- Mainline: C_QuestLog.GetInfo(i) -> QuestInfo { title, level, isHeader, isComplete?, questID, ... }
-- ACHTUNG: In der QuestInfo-Struktur von 12.1.0 ist `isComplete` NICHT gelistet (nur
-- isHidden/isTask/isAutoComplete). Der belastbare Weg auf Mainline ist C_QuestLog.IsComplete(questID),
-- deshalb wird der Wert dort von dort geholt und q.isComplete nur als Zugabe gelesen.
local function complete(wert)
    return (wert == true or wert == 1) and true or false
end

function C.questAnzahl()
    if C.F.quests == "retail" then
        if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
            local ok, n = pcall(C_QuestLog.GetNumQuestLogEntries)
            if ok then return tonumber(n) or 0 end
        end
        return 0
    end
    if GetNumQuestLogEntries then
        local ok, n = pcall(GetNumQuestLogEntries)
        if ok then return tonumber(n) or 0 end
    end
    return 0
end

function C.questLogEintrag(i)
    if C.F.quests == "retail" then
        if not (C_QuestLog and C_QuestLog.GetInfo) then return nil end
        local ok, q = pcall(C_QuestLog.GetInfo, i)
        if not ok or type(q) ~= "table" or not q.title then return nil end
        local fertig = complete(q.isComplete)
        if not fertig and q.questID and C_QuestLog.IsComplete then
            local ok2, r = pcall(C_QuestLog.IsComplete, q.questID)
            fertig = (ok2 and r) and true or false
        end
        return {
            titel    = q.title,
            level    = tonumber(q.level),
            header   = q.isHeader and true or false,
            complete = fertig,
            questID  = tonumber(q.questID),
        }
    end
    if not GetQuestLogTitle then return nil end
    local ok, titel, level, _, isHeader, _, isComplete, _, questID = pcall(GetQuestLogTitle, i)
    if not ok or not titel then return nil end
    return {
        titel    = titel,
        level    = tonumber(level),
        header   = isHeader and true or false,
        complete = complete(isComplete),
        questID  = tonumber(questID),
    }
end

-- Ziele einer Quest: { { text, typ, fertig, haben, brauchen }, ... }
-- C_QuestLog.GetQuestObjectives(questID) gibt es auf ALLEN fuenf Clients (in classic_era
-- belegt), der Classic-Weg ueber GetQuestLogLeaderBoard(j, logIndex) bleibt aber der
-- getestete — deshalb auf Classic-Clients zuerst der alte Weg, auf Mainline zuerst der neue.
local function zieleKlassisch(logIndex)
    local out = {}
    if not (logIndex and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard) then return out end
    local ok, nz = pcall(GetNumQuestLeaderBoards, logIndex)
    for j = 1, (ok and tonumber(nz) or 0) do
        local ok2, text, typ, fertig = pcall(GetQuestLogLeaderBoard, j, logIndex)
        if ok2 and text then
            local haben, brauchen = tostring(text):match("(%d+)%s*/%s*(%d+)")
            out[#out + 1] = { text = text, typ = typ, fertig = fertig and true or false,
                              haben = tonumber(haben), brauchen = tonumber(brauchen) }
        end
    end
    return out
end

local function zieleModern(questID)
    local out = {}
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives and tonumber(questID)) then return out end
    local ok, liste = pcall(C_QuestLog.GetQuestObjectives, tonumber(questID))
    if not ok or type(liste) ~= "table" then return out end
    for j = 1, #liste do
        local z = liste[j]
        if type(z) == "table" then
            out[#out + 1] = { text = z.text, typ = z.type, fertig = z.finished and true or false,
                              haben = C.zahl(z.numFulfilled), brauchen = C.zahl(z.numRequired) }
        end
    end
    return out
end

function C.questObjectives(questID, logIndex)
    if C.F.quests == "classic" then
        local out = zieleKlassisch(logIndex)
        if #out > 0 then return out end
        return zieleModern(questID)
    end
    local out = zieleModern(questID)
    if #out > 0 then return out end
    return zieleKlassisch(logIndex)
end

-- QUEST_ACCEPTED traegt auf Classic (questLogIndex, questID), auf Mainline nur (questID).
-- QUEST_TURNED_IN traegt ueberall (questID, xp, money).
function C.questAcceptedID(a, b)
    if C.F.quests == "retail" then return tonumber(a) end
    return tonumber(b) or tonumber(a)
end

-- ---------------------------------------------------------------- Zauber
-- Lokalisierter Zaubername zu einer Spell-ID. Auf Retail/Forever gibt C_Spell.GetSpellInfo eine
-- TABELLE zurueck; das globale GetSpellInfo liefert dort (soweit es noch existiert) andere
-- Rueckgaben als auf Classic. Beide Wege, das erste brauchbare Ergebnis gewinnt.
function C.zauberName(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end
    if GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok and type(n) == "string" and n ~= "" then return n end
        if ok and type(n) == "table" and type(n.name) == "string" and n.name ~= "" then return n.name end
    end
    return nil
end

-- ---------------------------------------------------------------- Text-to-Speech
-- C_VoiceChat.SpeakText(voiceID, text, rate, volume [, overlap]) — identisch auf allen fuenf
-- Clients. Die Stimmen kommen vom BETRIEBSSYSTEM (Windows SAPI / macOS); unter Wine ist mit
-- einer LEEREN Liste zu rechnen, und dann ist TTS schlicht aus.
function C.ttsStimmen()
    if not (C_VoiceChat and C_VoiceChat.GetTtsVoices) then return {} end
    local ok, liste = pcall(C_VoiceChat.GetTtsVoices)
    if not ok or type(liste) ~= "table" then return {} end
    return liste
end

-- Im Spiel eingestellte Stimme, wenn der Client sie kennt.
function C.ttsStimmeVorgabe()
    if C_TTSSettings and C_TTSSettings.GetVoiceOptionID then
        local ok, id = pcall(C_TTSSettings.GetVoiceOptionID, 1)
        if ok and tonumber(id) then return tonumber(id) end
        local ok2, id2 = pcall(C_TTSSettings.GetVoiceOptionID)
        if ok2 and tonumber(id2) then return tonumber(id2) end
    end
    local liste = C.ttsStimmen()
    local erste = liste[1]
    if type(erste) == "table" and tonumber(erste.voiceID) then return tonumber(erste.voiceID) end
    return nil
end

-- ---------------------------------------------------------------- Bericht (/lyra status)
function C.bericht()
    local F = C.F
    return {
        profil = C.profil,
        version = C.version,
        projekt = pid,
        mainline = C.istMainlineArtig,
        combatLog = F.combatLog,
        secret = F.secretValues,
        quests = F.quests,
        container = F.container,
        auren = F.auren,
        settings = F.settingsApi,
        hardcore = F.hardcoreApi,
        mirror = F.mirrorTimer,
        tts = F.tts,
        gefahrenkarte = F.gefahrenkarte,   -- REVIEW9
        stimmen = #C.ttsStimmen(),
        -- W6: woran die Client-Weiche gefallen ist, und was die Spielregeln sagen.
        weiche = C.weiche,
        restricted = C.restrictedApi,
        -- W10B (10-6): welche TOC der Client geladen hat und ob sie zu ihm passt.
        tocInterface = C.tocInterface,
        tocPasst = C.tocPasst(),
        hcAktiv = C.istHardcore(),
        hcQuelle = C.hcQuelle,
        selbstgefunden = C.istSelbstgefunden(),
        ssfQuelle = C.ssfQuelle,
    }
end
