-- Bruecke.lua — Lyra_Gestalt_Daten: Plausibilitaet der Gefahrenkarte, sonst nichts.
-- Dieses Addon hat KEINEN Zugriff auf den Namensraum des Kerns: `local ADDON, ns = ...`
-- liefert hier den eigenen (leeren) Namensraum von Lyra_Gestalt_Daten. Der Kern
-- (Lyra_Gestalt/Sinne/Gefahren_Daten.lua) liest deshalb die globale Tabelle
-- LyraGestalt_Daten bei ADDON_LOADED("Lyra_Gestalt_Daten") bzw. PLAYER_LOGIN und
-- spielt die Zellen level-gefiltert in ns.Gefahren[mapID] ein.
-- Hier: kaputte oder fremde Daten entschaerfen, Kennzahlen nachrechnen, Herkunft markieren.
local ADDON = ...

local D = LyraGestalt_Daten
if type(D) ~= "table" or type(D.zellen) ~= "table" then
    -- Unbrauchbar: der Kern soll gar nicht erst versuchen, daraus zu lesen.
    LyraGestalt_Daten = nil
    return
end

local karten, zellen = 0, 0
for mapID, liste in pairs(D.zellen) do
    if type(mapID) == "number" and type(liste) == "table" then
        karten = karten + 1
        zellen = zellen + #liste
    else
        D.zellen[mapID] = nil          -- fremder Schluessel: raus
    end
end

D.addon = ADDON
D.karten = karten
D.anzahlZellen = zellen
D.geladen = true
