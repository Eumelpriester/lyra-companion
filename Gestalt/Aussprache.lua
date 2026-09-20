-- Gestalt/Aussprache.lua — W9: Aussprache-Lexikon fuer die Vorlese-Schicht (Recherche 10 §5 A8).
--
-- WOZU. Lyras eigene Stimme ist vorgerendert und klingt, wie sie klingen soll. Die Zeilen OHNE
-- Aufnahme - die mit {zone}, {n}, {name} - liest seit 0.9.0 die Stimme des Betriebssystems vor
-- (Gestalt/Stimme.lua). Und genau diese Zeilen tragen die Lore-Namen: der Zonenname kommt aus
-- GetRealZoneText, der Bossname aus der Chronik. Eine deutsche SAPI-Stimme liest "Azeroth" als
-- "A-tse-roth" und "Onyxia" als "On-ue-xia", eine englische "Kel'Thuzad" als "Kel-Apostroph-...".
-- Falsche Aussprache ist laut Recherche 10 der meistgenannte INHALTLICHE Kritikpunkt an
-- Vertonungs-Addons - und der billigste zu beheben.
--
-- DIE EINE REGEL: das Lexikon wirkt AUSSCHLIESSLICH auf den TTS-Text.
--   Untertitel, Sprechblase, Chat, Chronik-Fenster: unberuehrt.
--   Angewendet wird es an genau EINER Stelle - Gestalt/Stimme.lua S.ttsText(), also hinter der
--   Markup-Saeuberung und vor der Laengenkappe. Die Blase laeuft ueber Core/Regie.lua
--   ausgebenKern() und kommt hier nie vorbei. Das ist keine Vorsicht, das ist Bauart: eine
--   Sprechform ist eine LAUTSCHRIFT ("Silwanas"), und die will niemand lesen.
--
-- WAS DRINSTEHT. Nur Namen, bei denen die Vorgabe-Stimme nachweislich etwas anderes sagt, als
-- gemeint ist. Ein Eintrag, der nichts aendert, ist Rauschen: "Orgrimmar", "Durotar",
-- "Tanaris", "Teldrassil", "Darnassus", "Westfall" liest eine deutsche Stimme bereits richtig
-- und stehen deshalb NICHT hier. Ebenso weggelassen, weil die richtige Sprechform strittig ist:
-- Scholomance, Desolace, Lordaeron, Hyjal, Alexstrasza. Im Zweifel: weglassen. Ein falscher
-- Eintrag ist schlimmer als keiner, weil er den Fehler festschreibt.
--
-- ERWEITERBAR OHNE PATCH. /lyra aussprache <wort> = <sprechform> legt einen eigenen Eintrag in
-- die SavedVariables; er schlaegt das eingebaute Lexikon. /lyra aussprache liste zeigt beides,
-- /lyra aussprache weg <wort> nimmt den eigenen wieder heraus.
--
-- API: keine. Reine Stringarbeit, kein Ereignis, kein Timer, kein Frame, nichts Fremdes.
local ADDON, ns = ...
local A = {}
ns.Aussprache = A

A.MAX_WORT   = 40       -- Zeichen: laenger ist kein Wort mehr
A.MAX_FORM   = 60
A.MAX_EIGENE = 100      -- Deckel je Sprache gegen eine davongelaufene Liste

-- Core/Init.lua gehoert nicht zu dieser Welle - der Schluessel wird hier an DEFAULTS_ACCOUNT
-- gehaengt, auf Dateiebene und damit vor ns.initDB(). defaults() kopiert Tabellen tief, jede
-- Datenbank bekommt also ihre eigenen beiden Unter-Tabellen.
if type(ns.DEFAULTS_ACCOUNT) == "table" and ns.DEFAULTS_ACCOUNT.aussprache == nil then
    ns.DEFAULTS_ACCOUNT.aussprache = { de = {}, en = {} }
end

-- =============================================================================================
-- Das Lexikon
-- =============================================================================================
-- Schreibweise der Sprechform: in der ORTHOGRAFIE DER JEWEILIGEN SPRACHE, nicht in IPA. SAPI
-- und die macOS-Stimmen lesen Buchstaben, keine Lautschrift-Zeichen; "Silwanas" funktioniert,
-- "sɪlˈvɑːnəs" wird buchstabiert.
A.LEXIKON = {
    -- -----------------------------------------------------------------------------------------
    -- Deutsch. Die deutsche Stimme liest nach deutschen Regeln: z = "ts", y = "ue", th = "t",
    -- Endsilben-e wird gesprochen. Das trifft bei englischen und Kunstnamen daneben.
    -- -----------------------------------------------------------------------------------------
    de = {
        -- Welt und Zonen
        ["Azeroth"]        = "Asseroth",          -- sonst "A-tse-roth"
        ["Azshara"]        = "Asch-Schara",       -- sonst "Ats-chara"
        ["Zul'Farrak"]     = "Sul-Farrak",        -- sonst "Tsul-Apostroph-Farrak"
        ["Zul'Gurub"]      = "Sul-Gurub",
        ["Ahn'Qiraj"]      = "An-Kiradsch",
        ["Un'Goro"]        = "Un-Goro",           -- nur der Apostroph muss weg
        ["Eldre'Thalas"]   = "Eldre-Talas",
        ["Dire Maul"]      = "Dair Mahl",
        ["Blackrock"]      = "Bläckrock",
        ["Molten Core"]    = "Molten Kor",        -- sonst mit gesprochenem End-e
        ["Stratholme"]     = "Stratholm",         -- ebenso
        ["Thunder Bluff"]  = "Thander Blaff",
        ["Undercity"]      = "Anderssitti",
        ["Stranglethorn"]  = "Strängel-Thorn",
        ["Elwynn"]         = "Elwinn",
        ["Mulgore"]        = "Mulgor",            -- sonst mit gesprochenem End-e
        -- Namen
        ["Onyxia"]         = "Onixia",            -- sonst "On-ue-xia"
        ["Sylvanas"]       = "Silwanas",          -- sonst "Suel-wanas"
        ["Ysera"]          = "Issera",            -- sonst "Ue-sera"
        ["Malygos"]        = "Maligos",           -- sonst "Mal-ue-gos"
        ["Azuregos"]       = "Asuregos",          -- sonst "A-tsu-regos"
        ["Kel'Thuzad"]     = "Kel-Tusad",
        -- Spielbegriffe, die in Lyras deutschen Zeilen wirklich vorkommen (gezaehlt in
        -- phrasen.lua, dialog.lua und den Locales - was dort nicht auftaucht, steht nicht hier)
        ["Hardcore"]       = "Hardkor",
        ["Questie"]        = "Kwessti",
        ["WeakAuras"]      = "Wiek Auras",
        ["Cooldown"]       = "Kuhldaun",
        ["Level"]          = "Lewwel",
        ["Loot"]           = "Luut",
        ["Addon"]          = "Äddon",
        ["Raid"]           = "Räid",
        ["Dungeon"]        = "Dandschen",
        ["Tank"]           = "Tänk",
        ["Buff"]           = "Baff",
        ["Wipe"]           = "Waip",
    },
    -- -----------------------------------------------------------------------------------------
    -- Englisch. Die englische Stimme kommt mit englischen Woertern klar; sie scheitert an den
    -- Kunstnamen - vor allem an denen mit Apostroph, die sie als Abkuerzung liest.
    -- -----------------------------------------------------------------------------------------
    en = {
        -- Welt und Zonen
        ["Azeroth"]        = "Az-uh-roth",
        ["Azshara"]        = "Ash-ar-uh",
        ["Zul'Farrak"]     = "Zool Fa-rak",
        ["Zul'Gurub"]      = "Zool Goo-roob",
        ["Ahn'Qiraj"]      = "Ahn Kee-rahzh",
        ["Un'Goro"]        = "Un Gor-oh",
        ["Eldre'Thalas"]   = "El-dreh Thah-las",
        ["Gnomeregan"]     = "Nome-reh-gan",
        ["Stratholme"]     = "Strath-ohm",
        ["Teldrassil"]     = "Tel-drass-il",
        ["Darnassus"]      = "Dar-nass-us",
        ["Elwynn"]         = "El-win",
        ["Durotar"]        = "Dur-oh-tar",
        ["Mulgore"]        = "Mul-gore",
        ["Feralas"]        = "Fair-uh-las",
        ["Silithus"]       = "Sil-ith-us",
        ["Maraudon"]       = "Muh-raw-don",
        ["Uldaman"]        = "Ull-duh-man",
        ["Tanaris"]        = "Tuh-nar-is",
        ["Alterac"]        = "Al-ter-ack",
        ["Arathi"]         = "Uh-rah-thee",
        ["Tirisfal"]       = "Teer-is-fal",
        -- Namen
        ["Kel'Thuzad"]     = "Kel Thoo-zad",
        ["Naxxramas"]      = "Nax-rah-mus",
        ["Sylvanas"]       = "Sil-vah-nus",
        ["Ysera"]          = "Ih-sair-uh",
        ["Onyxia"]         = "Oh-nik-see-uh",
        ["Ragnaros"]       = "Rag-nah-ros",
        ["Nefarian"]       = "Nuh-fair-ee-an",
        ["Cenarius"]       = "Suh-nair-ee-us",
        ["Hakkar"]         = "Hah-kar",
        ["Drakkisath"]     = "Drak-ih-sath",
        ["Gurubashi"]      = "Goo-roo-bah-shee",
        -- Spielbegriffe
        ["Questie"]        = "Kwes-tee",
    },
}

-- =============================================================================================
-- Eigene Eintraege (SavedVariables)
-- =============================================================================================
local function eigeneTabelle(sprache, anlegen)
    local d = ns.db and ns.db.aussprache
    if type(d) ~= "table" then
        if not anlegen or not ns.db then return nil end
        d = { de = {}, en = {} }
        ns.db.aussprache = d
    end
    if type(d[sprache]) ~= "table" then
        if not anlegen then return nil end
        d[sprache] = {}
    end
    return d[sprache]
end

local function spracheOk(s)
    if s == "de" or s == "en" then return s end
    local ok, akt = pcall(ns.sprache)
    if ok and (akt == "de" or akt == "en") then return akt end
    return "en"
end
A.sprache = spracheOk

-- =============================================================================================
-- Der Ersatz
-- =============================================================================================
-- Ein Wortzeichen ist alles, was in einem Namen stehen kann: ASCII-Buchstaben, Ziffern und
-- JEDES Byte >= 128. Das letzte ist der Umlaut-Griff: "Suesser" ist in UTF-8 mehrbytig, und ein
-- Treffer darf weder davor noch dahinter mitten in ein Wort schneiden. Der Apostroph zaehlt
-- bewusst NICHT mit - sonst waere "Zul'Farrak" ein einziges Wortzeichen-Feld und das Muster
-- muesste ihn selbst tragen (tut es: er steht im Schluessel).
local function istWortzeichen(b)
    if not b then return false end
    if b >= 48 and b <= 57 then return true end      -- 0-9
    if b >= 65 and b <= 90 then return true end      -- A-Z
    if b >= 97 and b <= 122 then return true end     -- a-z
    if b >= 128 then return true end                 -- UTF-8-Folge- und -Leitbytes
    return false
end
A.istWortzeichen = istWortzeichen

-- Suchindex: nach erstem (kleingeschriebenem) Byte gebuendelt, innerhalb des Buendels nach
-- Laenge absteigend. Damit gewinnt "Zul'Farrak" gegen ein hypothetisches "Zul", und der
-- Durchlauf kostet je Zeichen nur die Handvoll Eintraege mit demselben Anfangsbuchstaben.
local cache = {}          -- [sprache] = { stand = n, buendel = {...} }
A.stand = 0               -- hochgezaehlt bei jeder Aenderung; macht den Cache ungueltig

local function index(sprache)
    local c = cache[sprache]
    if c and c.stand == A.stand then return c.buendel end
    local flach = {}
    local lex = A.LEXIKON[sprache] or {}
    for wort, form in pairs(lex) do
        flach[#flach + 1] = { klein = tostring(wort):lower(), form = tostring(form), eigen = false }
    end
    local eig = eigeneTabelle(sprache, false)
    if eig then
        for wort, form in pairs(eig) do
            if type(wort) == "string" and type(form) == "string" then
                local k = wort:lower()
                local ersetzt = false
                for i = 1, #flach do
                    if flach[i].klein == k then flach[i] = { klein = k, form = form, eigen = true }; ersetzt = true; break end
                end
                if not ersetzt then flach[#flach + 1] = { klein = k, form = form, eigen = true } end
            end
        end
    end
    local buendel = {}
    for i = 1, #flach do
        local e = flach[i]
        local b = e.klein:byte(1)
        if b then
            buendel[b] = buendel[b] or {}
            local liste = buendel[b]
            liste[#liste + 1] = e
        end
    end
    for _, liste in pairs(buendel) do
        table.sort(liste, function(x, y)
            if #x.klein ~= #y.klein then return #x.klein > #y.klein end
            return x.klein < y.klein
        end)
    end
    cache[sprache] = { stand = A.stand, buendel = buendel }
    return buendel
end
A.index = index

-- Der eigentliche Lauf: EIN Durchgang durch den Text, an jeder Wortgrenze der laengste Treffer.
-- Ein Durchgang und nicht "je Eintrag ein gsub" - sonst liefe ein spaeterer Eintrag ueber eine
-- schon eingesetzte Sprechform und ersetzte in ihr weiter.
-- Rueckgabe: neuer Text, Zahl der Treffer.
function A.anwenden(roh, sprache)
    local t = tostring(roh or "")
    if t == "" then return t, 0 end
    sprache = spracheOk(sprache)
    local buendel = index(sprache)
    local klein = t:lower()          -- string.lower trifft nur ASCII, die Byte-Laenge bleibt gleich
    local out, i, n = {}, 1, 0
    local N = #t
    while i <= N do
        local treffer = nil
        if not istWortzeichen(t:byte(i - 1)) then
            local liste = buendel[klein:byte(i)]
            if liste then
                for k = 1, #liste do
                    local e = liste[k]
                    local len = #e.klein
                    if klein:sub(i, i + len - 1) == e.klein and not istWortzeichen(t:byte(i + len)) then
                        treffer = e
                        break
                    end
                end
            end
        end
        if treffer then
            out[#out + 1] = treffer.form
            i = i + #treffer.klein
            n = n + 1
        else
            out[#out + 1] = t:sub(i, i)
            i = i + 1
        end
    end
    if n == 0 then return t, 0 end
    return table.concat(out), n
end

-- Was wuerde fuer dieses Wort gesprochen? nil = nichts Eigenes und nichts im Lexikon.
-- Zweiter Rueckgabewert: true, wenn der Eintrag vom Spieler stammt.
function A.form(wort, sprache)
    sprache = spracheOk(sprache)
    local k = tostring(wort or ""):lower()
    if k == "" then return nil end
    local eig = eigeneTabelle(sprache, false)
    if eig then
        for w, f in pairs(eig) do
            if tostring(w):lower() == k then return f, true end
        end
    end
    local lex = A.LEXIKON[sprache] or {}
    for w, f in pairs(lex) do
        if tostring(w):lower() == k then return f, false end
    end
    return nil
end

-- =============================================================================================
-- Pflege
-- =============================================================================================
-- Ein Wort darf alles sein, was kein Steuerzeichen und kein WoW-Escape ist. Die Sprechform
-- ebenso - sie geht direkt an SpeakText, und ein "|" darin waere im besten Fall sinnlos.
local function sauber(s, max)
    if type(s) ~= "string" then return nil, "kein Text" end
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return nil, "leer" end
    if #s > max then return nil, "zu lang" end
    if s:find("[\1-\31\127]") then return nil, "steuerzeichen" end
    if s:find("|", 1, true) then return nil, "escape" end
    if s:find("{", 1, true) or s:find("}", 1, true) then return nil, "platzhalter" end
    return s
end

function A.setze(wort, form, sprache)
    sprache = spracheOk(sprache)
    local w, g1 = sauber(wort, A.MAX_WORT)
    if not w then return false, g1 end
    local f, g2 = sauber(form, A.MAX_FORM)
    if not f then return false, g2 end
    local eig = eigeneTabelle(sprache, true)
    if not eig then return false, "keine Datenbank" end
    if eig[w] == nil then
        local n = 0
        for _ in pairs(eig) do n = n + 1 end
        if n >= A.MAX_EIGENE then return false, "Deckel " .. A.MAX_EIGENE end
    end
    eig[w] = f
    A.stand = A.stand + 1
    return true
end

function A.weg(wort, sprache)
    sprache = spracheOk(sprache)
    local eig = eigeneTabelle(sprache, false)
    if not eig then return false, "nichts Eigenes" end
    local k = tostring(wort or ""):lower()
    for w in pairs(eig) do
        if tostring(w):lower() == k then
            eig[w] = nil
            A.stand = A.stand + 1
            return true
        end
    end
    return false, "nicht gefunden"
end

-- Zahl der Eintraege: eingebaut, eigen.
function A.zahlen(sprache)
    sprache = spracheOk(sprache)
    local a = 0
    for _ in pairs(A.LEXIKON[sprache] or {}) do a = a + 1 end
    local b = 0
    local eig = eigeneTabelle(sprache, false)
    if eig then for _ in pairs(eig) do b = b + 1 end end
    return a, b
end

-- =============================================================================================
-- /lyra aussprache
-- =============================================================================================
-- Die Ausgabetexte liegen absichtlich HIER und nicht in Locales/*.lua: sie gehoeren zu einem
-- Debug-/Pflegebefehl, den die Uebersetzung nie einholen muss - dasselbe Muster wie
-- Sinne/Questie2.lua Q.status() und Sinne/Karte2.lua K.hilfe().
function A.liste(sprache)
    sprache = spracheOk(sprache)
    local de = ns.sprache() == "de"
    local eingebaut, eigen = A.zahlen(sprache)
    local out = {
        (de and "Aussprache (%s): %d eingebaute Eintraege, %d eigene."
             or "Pronunciation (%s): %d built-in entries, %d of your own."):format(sprache, eingebaut, eigen),
        "  " .. (de and "Sie gilt nur fuer das Vorlesen (TTS), nie fuer die Sprechblase."
                     or "Applies to reading aloud (TTS) only, never to the speech bubble."),
    }
    local eig = eigeneTabelle(sprache, false)
    local namen = {}
    if eig then for w in pairs(eig) do namen[#namen + 1] = w end end
    table.sort(namen)
    for _, w in ipairs(namen) do
        out[#out + 1] = ("    %s = %s"):format(w, tostring(eig[w]))
    end
    if #namen == 0 then
        out[#out + 1] = "  " .. (de and "Eigene Eintraege: keine. /lyra aussprache <Wort> = <Sprechform>"
                                     or "Your own entries: none. /lyra aussprache <word> = <spoken form>")
    end
    return out
end

-- "/lyra aussprache"                      -> Liste
-- "/lyra aussprache liste"                -> dasselbe
-- "/lyra aussprache weg Onyxia"           -> eigenen Eintrag loeschen
-- "/lyra aussprache Onyxia = Onixia"      -> eigenen Eintrag setzen
-- "/lyra aussprache Onyxia"               -> zeigen, was fuer das Wort gilt
function A.befehl(rest)
    local de = ns.sprache() == "de"
    rest = tostring(rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if rest == "" or rest:lower() == "liste" or rest:lower() == "list" then
        for _, z in ipairs(A.liste()) do ns.print(z) end
        return true
    end
    local ohne = rest:match("^[Ww][Ee][Gg]%s+(.+)$") or rest:match("^[Rr][Ee][Mm][Oo][Vv][Ee]%s+(.+)$")
        or rest:match("^[Ll][Oo][Ee][Ss][Cc][Hh]%s+(.+)$")
    if ohne then
        local ok, grund = A.weg(ohne)
        ns.print(ok and ((de and "Aussprache: \"%s\" wieder wie eingebaut." or "Pronunciation: \"%s\" back to built-in."):format(ohne))
                     or ((de and "Aussprache: \"%s\" nicht entfernt (%s)." or "Pronunciation: \"%s\" not removed (%s)."):format(ohne, tostring(grund))))
        return ok
    end
    local wort, form = rest:match("^(.-)%s*=%s*(.+)$")
    if wort then
        local ok, grund = A.setze(wort, form)
        ns.print(ok and ((de and "Aussprache: \"%s\" wird als \"%s\" gesprochen." or "Pronunciation: \"%s\" is spoken as \"%s\"."):format(wort, form))
                     or ((de and "Aussprache: nicht uebernommen (%s)." or "Pronunciation: not accepted (%s)."):format(tostring(grund))))
        return ok
    end
    local f, eigen = A.form(rest)
    if f then
        ns.print((de and "Aussprache: \"%s\" wird als \"%s\" gesprochen (%s)."
                      or "Pronunciation: \"%s\" is spoken as \"%s\" (%s)."):format(
            rest, f, eigen and (de and "eigener Eintrag" or "your entry") or (de and "eingebaut" or "built-in")))
    else
        ns.print((de and "Aussprache: fuer \"%s\" gilt nichts Eigenes. /lyra aussprache %s = <Sprechform>"
                      or "Pronunciation: nothing set for \"%s\". /lyra aussprache %s = <spoken form>"):format(rest, rest))
    end
    return true
end

function A.status()
    local de = ns.sprache() == "de"
    local sp = spracheOk()
    local eingebaut, eigen = A.zahlen(sp)
    return {
        (de and "Aussprache: %d eingebaut + %d eigen (%s), nur fuer das Vorlesen."
             or "Pronunciation: %d built-in + %d own (%s), for reading aloud only."):format(eingebaut, eigen, sp),
    }
end
