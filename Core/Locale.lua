-- Core/Locale.lua — ns.L mit Fallback auf den Schluessel. UI-Sprache folgt ns.sprache().
local ADDON, ns = ...
ns.L = setmetatable({}, { __index = function(t, k)
    local tbl = (ns.sprache() == "de") and ns.locales.deDE or ns.locales.enUS
    local v = tbl[k] or ns.locales.enUS[k] or k
    return v
end })
