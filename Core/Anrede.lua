-- Core/Anrede.lua — Anrede-Token {m|f} bzw. {m|f|neutral} aufloesen; UnitSex-Cache.
-- API: UnitSex("player") (1 unbekannt, 2 maennlich, 3 weiblich). Nur lesend.
local ADDON, ns = ...
-- REVIEW: erster Trenner ist Pflicht, sonst frisst der Resolver Platzhalter wie {zone}/{level}/{name}
-- (die werden erst danach von ns.fuelle ersetzt).
local TOKEN = "{([^{}|]*)|([^{}|]*)|?([^{}|]*)}"

ns.sexCache = nil
function ns.geschlecht()
    if ns.streamerAnrede then return "keine" end   -- Streamer-Modus (UI/Streamer.lua): nie eine Anrede
    local a = ns.Get("anrede")
    if a == "m" or a == "f" or a == "keine" then return a end
    if not ns.sexCache then
        local s = UnitSex("player")
        ns.sexCache = (s == 3) and "f" or "m"
    end
    return ns.sexCache
end

function ns.hatToken(text)
    -- REVIEW: auch dreiteilige Token {m|f|neutral} erkennen (zweiter Teil darf '|' enthalten)
    return text and text:find("{[^{}|]*|[^{}]*}") ~= nil
end

-- Loest Token auf. Bei "keine": dritter Teil, sonst Anrede entfernen + Satzzeichen glaetten.
function ns.Anrede(text, g)
    if not text then return "" end
    g = g or ns.geschlecht()
    -- W16: ab Stufe 2 darf ein Spitzname statt "Held"/"Heldin" stehen — NUR im Text. Die Stimme
    -- bleibt unberuehrt: Core/Regie.lua ausgebenKern() waehlt die Tondatei ueber ns.hatToken()
    -- auf dem ROHEN Text VOR dieser Aufloesung, nicht ueber das Ergebnis von ns.Anrede().
    -- EINMAL je Aufruf gewuerfelt, nicht je Token - sonst koennte ein Satz mit zwei Token einmal
    -- den Spitznamen und einmal "Held" sagen.
    -- Bei g == "keine" (Streamer-Modus, Einstellung "Keine Anrede") gewinnt weiter der dritte
    -- Token-Teil: wer keine Anrede will, will auch keinen Kosenamen.
    local spitz = nil
    if g ~= "keine" and ns.Bindung and ns.Bindung.spitzname then
        local ok, s = pcall(ns.Bindung.spitzname)
        if ok and type(s) == "string" and s ~= "" then spitz = s end
    end
    local out = text:gsub(TOKEN, function(m, f, n)
        if g == "keine" then return n or "" end
        if spitz then return spitz end
        if g == "f" then return (f ~= "" and f) or m end
        return m
    end)
    if g == "keine" then
        out = out:gsub(",%s*%.", "."):gsub(",%s*!", "!"):gsub(",%s*%?", "?"):gsub("%s%s+", " "):gsub("^%s+", "")
    end
    return out
end

-- Platzhalter {zone} {name} {level} {buff} {beruf} {wert} {ziel}
function ns.fuelle(text, vars)
    if not vars then return text end
    return (text:gsub("{(%a+)}", function(k) local v = vars[k]; return v ~= nil and tostring(v) or ("{" .. k .. "}") end))
end
