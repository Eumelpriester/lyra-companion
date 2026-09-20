local ADDON, ns = ...
ns.locales = ns.locales or {}
ns.locales.deDE = {
    -- W8: derselbe Anzeigename wie im Englischen (Begruendung steht in Locales/enUS.lua).
    -- Bisher fiel deDE hier auf enUS zurueck; jetzt steht er ausdruecklich da, damit eine
    -- kuenftige Aenderung nicht versehentlich nur eine Sprache trifft.
    ["Lyra Gestalt"] = "Lyra Companion",
    ["Language"] = "Sprache", ["Auto"] = "Automatisch", ["German"] = "Deutsch", ["English"] = "Englisch",
    ["Address"] = "Wie Lyra dich anspricht", ["By character"] = "Nach Charakter", ["Male"] = "Männlich", ["Female"] = "Weiblich", ["No address"] = "Keine Anrede",
    ["Voice"] = "Stimme", ["Voice enabled"] = "Stimme an", ["Sound channel"] = "Tonkanal", ["Subtitles"] = "Text immer zeigen",
    ["Talkativeness"] = "Gesprächigkeit", ["Silent"] = "Still", ["Little"] = "Wenig", ["Normal"] = "Normal", ["Chatty"] = "Gesprächig",
    ["Combat: warnings only"] = "Im Kampf nur Warnungen", ["Quiet in groups"] = "In Gruppe und Schlachtzug schweigen",
    ["Cheeky humor"] = "Frecher Humor", ["Bubble duration"] = "Sprechblasen-Dauer (s)", ["Font size"] = "Schriftgröße", ["High contrast"] = "Hoher Kontrast",
    ["Scale"] = "Größe", ["Locked"] = "Position sperren", ["Reset position"] = "Position zurücksetzen", ["Hidden"] = "Lyra ausblenden",
    ["Sound cues"] = "Kleine Laute (hmm, oh, hihi)",
    ["Test"] = "Sag was",
    ["Loaded"] = "geladen. /lyra öffnet die Einstellungen.",
    ["voicepack missing"] = "Sprachpaket nicht installiert: ",
    -- Settings: Abschnitte, Tooltips
    ["Language and address"] = "Sprache und Anrede", ["Behavior"] = "Verhalten", ["Figure"] = "Lyras Gestalt", ["Try it"] = "Ausprobieren",
    ["Dialog volume"] = "Dialog-Lautstärke", ["Dialog volume tip"] = "Blizzards Dialog-Kanal. Gilt, wenn der Tonkanal auf Dialog steht.",
    ["Test tip"] = "Lyra sagt sofort eine Leerlauf-Zeile (die übliche Pause zwischen Zeilen wird übersprungen).",
    ["Test silent"] = "Lyra blieb still: ", ["Reset position tip"] = "Setzt Lyra zurück an den linken Bildrand auf halber Höhe – dort ist bei fast jedem UI-Aufbau Platz.",
    -- Slash
    ["Status"] = "Status", ["yes"] = "ja", ["no"] = "nein", ["not loaded"] = "nicht geladen",
    ["Combat"] = "Im Kampf", ["Group"] = "In Gruppe", ["Voice pack"] = "Sprachpaket", ["Version"] = "Version",
    ["Position reset"] = "Position zurückgesetzt.", ["Size range"] = "Größe muss zwischen 0.2 und 1.5 liegen.",
    ["Debug on"] = "Debug an.", ["Debug off"] = "Debug aus.", ["Drop log"] = "Letzte Drops (Grund, Ereignis, Zeit):", ["Drop log empty"] = "noch keine Drops",
    ["unknown command"] = "Unbekannter Befehl. /lyra hilfe",
    ["Help text"] = "/lyra - Einstellungen öffnen\n"
        .. "/lyra sprache de|en|auto - Sprache\n"
        .. "/lyra anrede m|w|keine|auto - wie Lyra dich anspricht\n"
        .. "/lyra stumm - Stimme an/aus\n"
        .. "/lyra still|wenig|normal|viel - Gesprächigkeit\n"
        .. "/lyra gruppe - in Gruppen schweigen an/aus\n"
        .. "/lyra portrait | figur - Ansicht wechseln\n"
        .. "/lyra klein | mittel | gross - Größe\n"
        .. "/lyra groesse 0.2-1.5 - Größe frei einstellen\n"
        .. "/lyra preset leise|normal|lebendig|streamer\n"
        .. "/lyra einrichten - Erst-Start-Assistent\n"
        .. "/lyra schrift auto|10-28 - Schriftgröße\n"
        .. "/lyra bewegung voll|reduziert|aus - Bewegung\n"
        .. "/lyra leiste aus|auto|immer - Untertitel-Leiste\n"
        .. "/lyra sperren - Position sperren an/aus\n"
        .. "/lyra verstecken | zeigen - Lyra aus- oder einblenden\n"
        .. "/lyra position reset|vorschlag - Position\n"
        .. "/lyra probe - sag was\n"
        .. "/lyra status | debug | hilfe",
    ["Combat transparency"] = "Transparenz im Kampf", ["Screen glow on warnings"] = "Bildschirmrand leuchtet bei Warnungen", ["Minimap button"] = "Minimap-Knopf",
    -- Interaktion: Menü, Dialog, Freitext
    ["Say something"] = "Sag was", ["Ask me"] = "Frag mich", ["Quiet mode"] = "Still-Modus",
    ["Lock"] = "Sperren", ["Unlock"] = "Entsperren", ["Hide"] = "Ausblenden", ["Settings"] = "Einstellungen",
    ["Hidden hint"] = "Lyra ist ausgeblendet. /lyra zeigen holt sie zurück.",
    ["Quiet on"] = "Still-Modus an: nur Warnungen. Mittelklick auf Lyra, Shift+Rechtsklick oder /lyra menue schaltet ihn aus.",
    ["Quiet off"] = "Still-Modus aus.",
    ["Note saved"] = "Notiz in der Chronik gespeichert.", ["Notes"] = "Notizen",
    -- W7: Sprachwechsel ohne /reload — ehrliche Rückmeldung im Chat.
    ["Language switched"] = "Sprache: %s. Einstellungsseite, Menü, Gespräch und Chronik sind umgestellt — kein /reload nötig.",
    ["Language switched simple"] = "Sprache: %s. Menü, Gespräch und Chronik sind umgestellt.",
    ["Language partial"] = "Sprache: %s. Menü, Gespräch und Chronik sind umgestellt. Diese Beschriftungen der Einstellungsseite erst nach /reload: %s",
    ["Chronicle missing"] = "Noch keine Chronik-Zusammenfassung verfügbar.",
    -- W7: Chronik-Fenster (/lyra chronik). Keine Charakter- oder Gildennamen, screenshot-tauglich.
    ["Chronicle"] = "Chronik",
    ["Chronicle zones"] = "Zonen",
    ["Chronicle close calls"] = "Beinahe-Tode",
    ["Chronicle bestiary"] = "Bestiarium",
    ["Chronicle sessions"] = "Sitzungen",
    ["Chronicle empty"] = "Noch nichts aufgeschrieben. Lyra fängt an, sobald du losziehst.",
    ["Chronicle visits"] = "%dx besucht",
    ["Chronicle zone near"] = "%dx besucht, %dx knapp",
    ["Chronicle hits"] = "%d Treffer, härtester %d",
    ["Chronicle rival"] = "%dx beinahe, %dx Tod",
    ["Chronicle session"] = "%d Sitzungen, diese seit %s",
    ["Chronicle more"] = "… und %d weitere",
    ["Esc hint"] = "Esc schließt",
    ["Dialog missing"] = "Dialog-Daten nicht geladen.",
    ["Help text 2"] = "/lyra menue - Lyras Menü (auch: Shift+Rechtsklick auf Lyra, Rechtsklick auf den Minimap-Knopf)\n"
        .. "/lyra frag - mit Lyra reden (auch: Rechtsklick auf Lyra; Tasten 1-4, Esc schließt)\n"
        .. "/lyra chronik - Chronik-Zusammenfassung\n"
        .. "/lyra notiz: <Text> - Tagebuch-Eintrag\n"
        .. "/lyra <irgendwas> - frag sie einfach",
    -- Design: Tooltip Gestalt, Minimap-Knopf, Einstellungen (kampfAlpha, glow, minimap)
    -- FIX5: neue Klick-Belegung 0.6.1 (zwei Tooltip-Zeilen, sonst wird die Zeile zu lang)
    ["Tooltip hint"] = "Links: Spruch · Doppelklick: Portrait/Figur · Rechts: Gespräch",
    ["Tooltip hint 2"] = "Shift+Rechts: Menü · Mitte: Still-Modus · Mausrad: Größe · Ziehen: verschieben",
    -- REVIEW2: Duplikate "Quiet mode"/"Combat transparency"/"Minimap button" entfernt (letzter Eintrag gewinnt; Menue zeigte "still-Modus")
    ["Minimap hint"] = "Links: Lyra ein-/ausblenden · Rechts: Lyras Menü (Einstellungen stehen darin) · Ziehen: Knopf verschieben",
    ["Lyra hidden"] = "Lyra ist ausgeblendet", ["Lyra visible"] = "Lyra ist sichtbar",
    ["Combat transparency tip"] = "Lyra wird im Kampf durchsichtiger (100 % = unverändert).",
    ["Screen glow"] = "Bildschirmrand-Warnung", ["Screen glow tip"] = "Kurzer Puls am Bildschirmrand bei wenig Leben, wenig Atem und Sturz. Bei Lichtempfindlichkeit ausschalten.",
    ["Danger map"] = "Gefahrenkarte (Deathlog-Datenpaket)",
    -- Feature-Welle 1: Reisecheck-Listen, Schalter, Erbe, Test (Sinne/Extra.lua, Sinne/Erbe.lua, UI/Streamer.lua)
    ["potions"] = "Tränke", ["bandages"] = "Verbände", ["repair"] = "Reparatur", ["ammo"] = "Munition", ["reagents"] = "Reagenzien",
    ["Photos"] = "Erinnerungsfotos", ["Photos tip"] = "Screenshot bei Zehner-Stufen und wenn du einen Kampf unter 20 % Leben überlebst (max. eines je 2 Minuten).",
    ["Ultra mode"] = "Ultra-Modus", ["Ultra mode tip"] = "Lyras Miene folgt im Kampf deinem Leben – für Spieler mit ausgeblendeter Lebensanzeige.",
    ["Streamer mode"] = "Streamer-Modus", ["Streamer mode tip"] = "Grüne Chroma-Kachel hinter Lyra (im Portrait rund) und keine Anrede. Die Untertitel-Leiste ist seit 0.6.2 eine eigene Einstellung – „Automatisch“ schaltet sie hier ohnehin ein.",
    ["Self-found"] = "Solo Self-Found (keine Handels-Hinweise)",
    ["Self-found tip"] = "Lyra erwähnt Handel, Auktionshaus, Post und Gruppensuche nicht mehr. Für Solo-Self-Found-Läufe.",
    ["Mood"] = "Stimmung", ["Mood tip"] = "Wie Lyra gerade gestimmt ist: Laune, Vertrautheit, Tageszeit. /lyra stimmung zeigt es im Chat.",
    ["Legacy day"] = "Gedenktag", ["Holiday"] = "Fest",
    ["Legacy also outside Hardcore"] = "Erbe auch außerhalb von Hardcore", ["Legacy tip"] = "Lyra merkt sich einen Tod dieses Charakters auch ohne Hardcore-Modus (zum Testen).",
    ["Last words prompt"] = "Was soll der Nächste wissen? Schreib es mir: /lyra <deine Worte>",
    ["Last words saved"] = "Letzte Worte gespeichert. Ich trage sie weiter.",
    ["Legacy list"] = "Erbe (eigene gefallene Charaktere):", ["Legacy empty"] = "Erbe: noch niemand gefallen.",
    ["Test running"] = "Test läuft: alle Warnungen im 4-s-Takt. /lyra test stop bricht ab.", ["Test stopped"] = "Test beendet.",
    ["unknown event"] = "Unbekanntes Ereignis:",
    -- REVIEW6B: Welle-2-Befehle standen in keinem Hilfetext.
    ["Help text 3"] = "/lyra test <ID> | alle | stop - Ereignis vorspielen\n"
        .. "/lyra foto | ultra | streamer - Schalter an/aus\n"
        .. "/lyra erbe - gefallene Vorgänger (eigene Charaktere)\n"
        .. "/lyra persoenlich - Stand der persönlichen Zeilen (Lyra_Gestalt_Persoenlich)\n"
        .. "/lyra cd - Notfallknöpfe und Abklingzeiten\n"
        .. "/lyra quests - Quest-Fortschritt\n"
        .. "/lyra profil - dein Spielstil-Profil\n"
        .. "/lyra rat - Klassenrat\n"
        .. "/lyra mark <totenkopf|kreuz|1-8> - Zeichen auf dein Ziel (nur Ungeheuer)\n"
        .. "/lyra pins - Karten-Pins neu setzen (braucht HereBeDragons)\n"
        .. "/lyra details [an|aus] - was ich aus Details gelesen habe\n"
        .. "/lyra bosse [an|aus] - deine Boss-Chronik (Versuche, Kills, beste Zeit)\n"
        .. "/lyra questie [an|aus] - Zielzone, Queststufe und Kette aus Questie\n"
        .. "/lyra woran - woran du gerade dran bist",
    -- Design v2: Presets, Ansicht, Größe, Erst-Start-Assistent
    ["How should Lyra be?"] = "Wie soll Lyra sein?",
    ["Preset"] = "Voreinstellung",
    ["Preset quiet"] = "Leise – Warnungen, sonst Ruhe",
    ["Preset normal"] = "Normal – Warnungen und gelegentliche Bemerkungen",
    ["Preset lively"] = "Lebendig – sie redet gern",
    ["Preset streamer"] = "Streamer – Untertitel, Chroma-Kachel, kein Bildschirm-Puls",
    ["Preset custom"] = "Eigene Einstellung",
    ["Preset tip"] = "Setzt mehrere Schalter auf einmal (Gesprächigkeit, Kampf, Gruppe, Laute, Humor, Bildschirm-Puls, Streamer). Änderst du danach einen einzelnen Schalter, steht hier „Eigene Einstellung“ – zurückgesetzt wird nichts.",
    ["View"] = "Ansicht",
    ["View portrait"] = "Portrait (nur Kopf, rund)",
    ["View figure"] = "Ganze Figur",
    ["View tip"] = "Portrait zeigt nur Lyras Gesicht in einem runden Rahmen – klein, gut lesbar und für Streams und Screenshots die sichere Wahl. Umschalten geht jederzeit, auch mit einem Doppelklick auf Lyra.",
    ["Size preset"] = "Größe",
    ["Size small"] = "Klein", ["Size medium"] = "Mittel", ["Size large"] = "Groß",
    ["Size preset tip"] = "Portrait: 96 / 112 / 128 Pixel. Ganze Figur: 179 / 256 / 358 Pixel hoch. Am schnellsten geht es mit dem Mausrad über Lyra; Zwischenwerte gibt es über /lyra groesse <Zahl>.",
    ["Setup wizard"] = "Erst-Start-Assistent",
    ["Setup wizard tip"] = "Lyra stellt dir noch einmal die drei Einrichtungsfragen (Sprache, Anrede, Gesprächigkeit). Auch über /lyra einrichten.",
    ["Playstyle profile"] = "Spielstil-Profil (lernt mit)", ["Map pins setting"] = "Karten-Pins (Beinahe-Stellen, Notizen)", ["No mark target"] = "Kein Ziel oder ein Spieler - ich markiere nur Ungeheuer.", ["Map pins"] = "%d Punkte auf der Karte.",
    ["Repeat last"] = "Letzten Satz wiederholen", ["Nothing to repeat"] = "Noch nichts gesagt.", ["Arcane mage"] = "Arkanmagierin",
    -- DESIGN-V3 Team B (0.6.2): Unterkategorie, Schrift-Automatik, Bewegung, Tastenkuerzel, Einladung
    ["Fine tuning"] = "Feineinstellung",
    ["Readability"] = "Lesbarkeit",
    ["Data sources"] = "Datenquellen und Partner-Addons",
    ["Font size auto"] = "Schriftgröße automatisch",
    ["Font size auto tip"] = "Die Schrift folgt der UI-Größe deines Clients: Lyra rechnet aus, wie viele Bildschirm-Pixel ein Buchstabe haben soll (22), und stellt die Größe danach ein – auf jedem Monitor gleich groß. Aus = du stellst sie selbst.",
    ["Font size tip"] = "In UI-Einheiten, 10 bis 28. Gilt für Sprechblase, Gespräch, Menü, Tooltip und Untertitel-Leiste.",
    ["Sound channel tip"] = "Auf welchem Kanal Lyra spricht. Alarme (unter 20 % Leben, Ertrinken, Sturz) laufen unabhängig davon immer auf „Master“ – ein leiser Dialogkanal darf eine Todeswarnung nicht verschlucken.",
    -- REVIEW7 / DESIGN-V3 B-8: Untertitel-Leiste, von "streamer" geloest
    ["Subtitle bar"] = "Untertitel-Leiste",
    ["Subtitle bar off"] = "Aus",
    ["Subtitle bar auto"] = "Automatisch",
    ["Subtitle bar always"] = "Immer",
    ["Subtitle bar tip"] = "Der große Balken am unteren Bildschirmrand, den auch eine Aufnahme mitliest. Automatisch heißt: an, wenn der Streamer-Modus läuft, wenn Lyra ausgeblendet ist (dann kommt keine Sprechblase) oder wenn die Schrift sehr klein ausfällt. Der Streamer-Modus ändert diese Einstellung nicht.",
    ["Motion"] = "Bewegung",
    ["Motion full"] = "Voll – Atmen, Nicken, Ruck",
    ["Motion reduced"] = "Reduziert – nur bei Warnungen",
    ["Motion off"] = "Aus – Lyra steht still",
    ["Motion tip"] = "Reduziert: kein Atmen, kein Nicken, kein Pulsieren – auch der Warnhalo steht still (er bleibt sichtbar, er trägt die Warnstufe). Der kurze Ruck bei einer Warnung bleibt. Aus: gar keine Bewegung, keine Regungen, harte Mienenwechsel. Für Bewegungsempfindlichkeit und für Aufnahmen.",
    ["Keys hint"] = "1–%d · Esc schließt",
    ["Position suggested"] = "Vorschlag: %s (%d, %d). /lyra position reset stellt den Standard her.",
    -- B-11: die EINE Zeile fuer Bestandsnutzer. Kein Popup, kein zweiter Versuch.
    ["Invite setup"] = "Ich kann mir zeigen lassen, wie du mich haben willst – /lyra einrichten, das dauert eine Minute.",
    -- 0.7.0: /lyra persoenlich (Sinne/Persoenlich.lua, Datenpaket Lyra_Gestalt_Persoenlich)
    ["Personal title"] = "Persönliche Zeilen:",
    ["Personal missing"] = "Das Paket Lyra_Gestalt_Persoenlich ist nicht geladen. Ohne Paket sage ich genau das, was eingebaut ist – alles in Ordnung.",
    ["Personal restart"] = "Gerade erst hineingelegt? Ein neuer Addon-Ordner ist erst nach einem Neustart des Clients sichtbar, /reload genügt nicht.",
    ["Personal inactive"] = "Paket gefunden, aber nicht in Gebrauch (%s).",
    ["Personal active"] = "Paket geladen: %d Zeilen, eingemischt mit Gewicht %d.",
    ["Personal events"] = "Ereignisse: %s",
    -- W9: praezisiert (KI-Audit L2). Bis 0.12.0 stand hier "nie mit Stimme" - das galt seit
    -- 0.9.0 nicht mehr, weil die Vorlese-Schicht jede Zeile ohne Aufnahme vorlas. Jetzt gilt der
    -- Satz wieder: Gestalt/Stimme.lua spart persoenliche Zeilen aus. Der Nachsatz nennt den
    -- Schalter, der das aufhebt - eine Zusage, die man umlegen kann, muss sagen, wo.
    ["Personal voiceless"] = "Persönliche Zeilen werden angezeigt, nie vorgelesen, und nie als Warnung. Wer es anders will: „Auch persönliche Zeilen vorlesen“ in der Feineinstellung.",
    ["Personal origin"] = "Erzeugt am %s, Quelle %s, Charakter %s.",
    ["Personal clean"] = "Keine Zeile verworfen.",
    ["Personal rejected"] = "Verworfen: %d Zeile(n).",
    -- 0.8.0 Welle 3: Zusammenspiel mit Details, DBM/BigWigs, Questie
    ["Details comment"] = "Kommentar nach langen Kämpfen (braucht Details)",
    ["Details comment tip"] = "Nach einem Kampf über 20 Sekunden sagt Lyra höchstens alle zehn Minuten einen Satz zu deinem eigenen Wert – Rekord, „über deinem Schnitt“, ungewöhnlich viel eingesteckt. Sie nennt keine Zahlenliste und keinen Gruppenwert mit Namen; aus Details liest sie nur deinen eigenen Akteur und die namenlose Gruppensumme. Ohne Details passiert nichts.",
    ["Boss chronicle"] = "Boss-Chronik (Versuche, Kills, beste Zeit)",
    ["Boss chronicle tip"] = "Lyra merkt sich je Boss, wie oft du es versucht hast, wie oft er gefallen ist und wie schnell es am schnellsten ging – nachzulesen mit /lyra bosse. Daraus kommen genau zwei Sätze: beim Wiederholungsversuch und beim allerersten Kill. Dass Lyra schweigt, während DBM oder BigWigs spricht, hängt nicht an diesem Schalter – das gilt immer.",
    ["Questie deep"] = "Questie tiefer nutzen (Zielzone, Stufe, Kette)",
    ["Questie deep tip"] = "Beim Annehmen einer Quest liest Lyra aus Questie die Zielzone und die Queststufe und verbindet sie mit deiner Chronik („da warst du vor neun Tagen fast tot“). Beim Abgeben nennt sie die nächste Quest der Kette. Nur lesend, ohne Questie passiert nichts.",
    -- PORT 0.9.0: Text-to-Speech (Gestalt/Stimme.lua). Zeilen ohne vorgerenderte OGG.
    ["TTS mode"] = "Zeilen ohne Stimme vorlesen (TTS)",
    ["TTS off"] = "Aus",
    ["TTS fallback"] = "Nur Zeilen ohne Sprachdatei",
    ["TTS always"] = "Immer, auch wenn sie leise ist",
    ["TTS tip"] = "Lyras eigene Stimme ist vorgerendert. Zeilen mit Platzhaltern – ein Zonenname, eine Zahl, dein Name – haben deshalb keine Audiodatei und waren bisher stumm. Dein Betriebssystem kann sie stattdessen vorlesen: eine andere, robotische Stimme, aber eine. Zeilen, die eine Sprachdatei haben, werden nie ersetzt. Solange Blizzards eigene Kampf-Audiohinweise oder die Bildschirm-Narration laufen, schweigt sie – drei Stimmen gleichzeitig sind nicht dreimal so hilfreich.",
    ["TTS no voices"] = "Dieser Client meldet keine Vorlese-Stimmen, es wird also nichts vorgelesen. Die Stimmen kommen vom Betriebssystem (Windows SAPI, macOS); unter Linux/Wine gibt es meist keine. Es geht nichts kaputt – die Zeilen bleiben stumm wie bisher.",
    ["TTS voice"] = "Vorlese-Stimme",
    ["TTS voice tip"] = "„Automatisch“ nimmt eine Stimme, deren Name zur gewählten Sprache passt. Die Liste kommt von deinem Betriebssystem, nicht vom Addon.",
    -- W4: Welle 4 (Sinne/Welle4.lua)
    ["Wave 4"] = "Alltag II und Signale",
    ["Profession moment"] = "Ein Wort zu Berufen",
    ["Profession moment tip"] = "Am Handwerksfenster sagt Lyra einen Satz zum ersten Punkt einer Sitzung und einen, wenn ein Beruf an der Lehrer-Grenze steht (75/150/225/300). Höchstens je einmal pro Sitzung. Die Chat-Zeile zu jedem 25. Punkt ist ein anderes, älteres Feature und bleibt, wie sie ist.",
    ["First aid"] = "An Verbände erinnern",
    ["First aid tip"] = "Nach einem Kampf, der dich unter die Hälfte deines Lebens gebracht hat – außerhalb von Hardcore unter ein Drittel –, sieht Lyra in deine Taschen. Liegt dort kein Verband, kommt ein Satz, einmal pro Sitzung, danach an diesem Tag nie wieder. Wer in der Zwischenzeit welche kauft, bekommt den Satz gar nicht mehr.",
    ["GatherMate nodes"] = "Fundstellen mitzählen (braucht GatherMate2)",
    ["GatherMate nodes tip"] = "Trägt GatherMate2 einen neuen Knoten ein, zählt Lyra mit. Ab dem zehnten Knoten einer Sitzung darf sie etwas sagen, danach höchstens alle dreißig Minuten. Sie nennt den Knoten nie beim Namen – das zeigt GatherMate2 mit einem Pin besser. Ohne GatherMate2 passiert nichts.",
    ["WA signal"] = "Signal an WeakAuras senden",
    ["WA signal tip"] = "Nach jeder Zeile schickt Lyra das Custom-Event LYRA_EREIGNIS (ID, Klasse, Stufe) an WeakAuras, damit du eigene Auren auf ihre Warnungen bauen kannst. Nur in eine Richtung – Lyra liest nie etwas aus WeakAuras zurück. Einzelheiten in Sinne/WELLE4.md.",
    ["Attunement unknown"] = "Diese Einstimmung kenne ich nicht.",
    -- W5: Welle 5 „Karte" (Sinne/Karte2.lua)
    ["Wave 5"] = "Karte und Pins",
    ["Pin close calls"] = "Stellen anzeigen, an denen es knapp war",
    ["Pin close calls tip"] = "Jeder Ort, an dem du fast gestorben bist, bekommt einen Pin auf Welt- und Minimap – mit dem Leben, das dir geblieben ist, und wer daran schuld war. Die Daten stammen aus deiner eigenen Chronik, es wird nichts nachgeschlagen.",
    ["Pin notes"] = "Eigene Punkte anzeigen",
    ["Pin notes tip"] = "Die Punkte, die du mit /lyra punkt setzt, bekommen einen Pin. Der Mauszeiger darauf zeigt deine Notiz und wann du sie gesetzt hast. /lyra punkte listet sie auf, /lyra punkt weg löscht den letzten.",
    ["Danger overlay"] = "Gefahrenkarte auf der Weltkarte",
    ["Danger overlay tip"] = "Zeigt genau die Zellen, vor denen Lyra auch warnt, als halbdurchsichtige Flächen auf der Weltkarte deiner Zone – orange für Stürze, blau für Ertrinken, rot für Kreaturen, und je kräftiger die Farbe, desto mehr Tode. Braucht das Paket Lyra_Gestalt_Daten und läuft nur auf Classic-Clients, weil die Zellen Classic-Era-Tode sind.",
    ["Waypoint proximity"] = "Etwas sagen, wenn ich an meinem Punkt ankomme",
    ["Waypoint proximity tip"] = "Im Umkreis von etwa 60 Metern um einen selbst gesetzten Punkt sagt Lyra einen Satz. Gemessen wird in echten Yard, geprüft alle zwei Sekunden, nie im Kampf und höchstens alle zehn Minuten je Punkt.",
    ["Map overview"] = "Karte",
    -- W6: Feature-Welle 6 "Vertrauen, Barrierefreiheit, Andocken" (Sinne/Welle6.lua)
    ["Accessibility"] = "Barrierefreiheit",
    ["Accessibility mode"] = "Barrierefreiheits-Modus",
    ["Accessibility mode tip"] = "Ein Schalter fuer alles, was Lyra lesbar und hoerbar macht: die Untertitel-Leiste bleibt dauerhaft stehen, vor jeder Zeile steht \"Lyra:\", die Blase ist deckend und die Schrift groesser, jede Zeile bleibt laenger stehen, und Zeilen ohne Sprachaufnahme werden vorgelesen (sofern dein System eine Stimme hat). Warnstufen bekommen zusaetzlich eine Form: ein Punkt, ein Dreieck, zwei Dreiecke. Beim Ausschalten bekommst du deine vorherigen Einstellungen zurueck - der Modus merkt sie sich.",
    ["Figure visible"] = "Lyra ist zu sehen",
    ["Figure visible tip"] = "Aus heisst: nur Stimme und Untertitel. Lyra bleibt vollstaendig da - dieselben Ereignisse, dieselbe Stimme, dasselbe Gedaechtnis -, sie hat nur kein Portrait mehr. Ihr Text steht dann in der Untertitel-Leiste oder in einer Sprechblase am unteren Bildschirmrand. Auch ueber /lyra figur aus erreichbar.",
    ["Figure off hint"] = "Ich bin jetzt nur Stimme und Text. /lyra figur an holt mich zurueck.",
    ["Warning symbol"] = "Warnstufe auch als Form",
    ["Warning symbol tip"] = "Neben der Farbe traegt jede Warnstufe ein kleines Zeichen an der Sprechblase: o Hinweis, ^ Warnung, ^^ Alarm. Farbe allein ist fuer rund acht Prozent der maennlichen Spieler kein Traeger - deshalb steht das Zeichen hier standardmaessig an, im Barrierefreiheits-Modus nur groesser.",
    ["Wave 6"] = "Barrierefreiheit und Stimmen",
    ["Speaker name"] = "\"Lyra:\" vor jeder Zeile",
    ["Speaker name tip"] = "Der Deaf/HoH-Standard verlangt einen Sprechernamen vor jedem Dialog. Im Stream und neben anderen Textausgaben ist ausserdem sofort klar, wer da spricht. Steht in Sprechblase und Untertitel-Leiste.",
    ["Coexistence"] = "Nie zwei Stimmen gleichzeitig",
    ["Coexistence tip"] = "Spricht gerade Blizzards eigene Sprachausgabe oder ein Screenreader, stellt Lyra ihr Vorlesen zurueck, bis der andere fertig ist. Seit Patch 12.0.0 darf Blizzards Sprachausgabe ueberlappen - fuer jemanden, der einen Screenreader benutzt, sind zwei Stimmen gleichzeitig das Ende der Benutzbarkeit. Kann Lyra durch Blizzards eigenen Audio-Assistenten sprechen, nutzt sie ihn und die Frage stellt sich gar nicht.",
    ["Hold own voice"] = "Auch Lyras eigene Aufnahme zurueckhalten",
    ["Hold own voice tip"] = "Standardmaessig gilt die Regel oben nur fuer das Vorlesen. Lyras vorgerenderte Stimme ist kurz und klingt nach ihr - sie uebertoent keinen Vorleser. Wer es trotzdem strenger will, schaltet das hier ein: dann bleibt auch die Aufnahme stumm, solange jemand anders redet. Der Text kommt in jedem Fall.",
    ["Foreign voice"] = "fremde Stimmen",
    ["not installed"] = "nicht installiert",
    ["frames"] = "Fenster",
    ["Client"] = "Client",
    ["Switch"] = "Weiche",
    ["Manual switch"] = "Schalter",
    ["Realm"] = "Realm",
    ["Memory"] = "Speicher",
    ["not measurable"] = "nicht messbar (Client gibt es nicht her)",
    ["CPU"] = "Rechenzeit",
    ["CPU hint"] = "nicht gemessen - /console scriptProfile 1 und neu einloggen, dann steht hier eine Zahl",
    ["since login"] = "seit dem Login",
    ["TTS no voices short"] = "keine Stimme im System",
    -- W8: Welle 8 (praeventive Sturz- und Wasserwarnung)
    ["Pre-warning"] = "Vor Klippen und tiefem Wasser warnen",
    ["Pre-warning tip"] = "Lyra sagt eine ruhige Zeile, BEVOR du an eine Stelle kommst, an der viele Hardcore-Charaktere gestuerzt oder ertrunken sind - etwa zwanzig bis vierzig Meter voraus, und nur, wenn du wirklich darauf zulaeufst. Sie sagt nie, wohin du gehen sollst; sie sagt, wo andere gestorben sind. Nie im Kampf, nie auf einem Flug, nie in einer Stadt oder einem Gasthaus, hoechstens einmal je Stelle und Sitzung. Braucht das Gefahrenkarten-Datenpaket und laeuft nur auf Classic-Era-artigen Clients.",
    -- W9a: persoenliche Zeilen vorlesen (Gestalt/Stimme.lua) und das Aussprache-Lexikon
    ["TTS personal"] = "Auch persönliche Zeilen vorlesen",
    ["TTS personal tip"] = "Persönliche Zeilen kommen aus dem Paket Lyra_Gestalt_Persoenlich – von Hand geschrieben oder vom Redakteur erzeugt. Sie haben keine Aufnahme und werden deshalb normalerweise nur angezeigt; genau das sagt /lyra persoenlich seit jeher zu. Dieser Schalter hebt die Zusage für dich auf: dann liest die Vorlese-Stimme sie mit. Sie klingt nicht wie Lyra, und ein Hinweis darauf, dass eine Zeile von einem Modell stammt, läuft in der Stimme nicht mit.",
    -- W9b: Welle 9b (Freitext mit Lyra, Stufe 1 - UI/Freitext.lua)
    ["Wave 9b"] = "Frei schreiben",
    ["Freetext"] = "Eingabefeld im Gespräch",
    ["Freetext tip"] = "Unter Lyras Gesprächsfenster steht ein Eingabefeld. Du kannst sie in ganzen Sätzen nach deiner eigenen Chronik fragen - nach Zonen, Gegnern, Beinahe-Toden, deiner Spielzeit, deinen Sitzungen. Sie antwortet aus festen Vorlagen und deinen eigenen Zahlen; es läuft kein Sprachmodell, nichts verlässt deinen Rechner. Das Feld nimmt den Fokus NUR auf Klick und gibt ihn bei Kampfbeginn sofort wieder ab - ein Eingabefeld, das WASD schluckt, ist auf Hardcore lebensgefährlich. Geht auch weiter über /lyra <Frage>.",
    ["Remember questions"] = "Fragen merken",
    ["Remember questions tip"] = "Standardmäßig lebt dein Gesprächsverlauf nur im Arbeitsspeicher und ist nach dem Ausloggen weg. Mit diesem Häkchen landen die letzten fünf Fragen (nur die Fragen, nie die Antworten) in den SavedVariables - also als Klartext auf deiner Festplatte. Gedacht ist das als Vorbereitung für eine spätere Ausbaustufe; solange du es nicht brauchst, lass es aus.",
    ["Freetext hint"] = "Enter sendet · Esc schließt",
    ["Freetext on"] = "Freitext an. Klick ins Feld unter dem Gesprächsfenster.",
    ["Freetext off"] = "Freitext aus.",
    -- W10B: Welle 10b (Farb-Paletten, UI/Farben.lua) - NUR angehaengt, nichts umgebaut.
    ["Colour theme"] = "Farbthema",
    ["Colour theme unknown"] = "So heißt keine Palette. Es gibt",
    ["Colour theme overridden"] = "Wirkt gerade nicht: „Hoher Kontrast\" ist an und gewinnt gegen jede Palette.",
    ["Colour theme tip"] = "Vier benannte Paletten für Sprechblase, Untertitel-Leiste und den Warnstufen-Puls am Bildschirmrand: standard (Lyras Violett), kontrast (Schwarz/Weiß), warm (Bernstein auf Braun), kalt (Eisblau auf Nachtblau). Jede Palette ist auf Lesbarkeit gerechnet – Text steht in allen vier über 11:1, verlangt sind 4,5:1. Das Häkchen „Hoher Kontrast\" gewinnt gegen die Palettenwahl; Helligkeit und Takt des Pulses ändert keine Palette, die sind die Photosensibilitäts-Grenze. Auch über /lyra farbe <name>.",
    -- W10a: der Offenlegungssatz fuer /lyra hilfe (Freitext-Konzept §2.8, Welle 9b §8 Punkt 5).
    -- Der EU AI Act Art. 50 verlangt ihn nach dem Wortlaut nicht - Stufe 1 ist eine Tabelle mit
    -- Schluesselwoertern und einer Kosinusaehnlichkeit. Ehrlicher als Schweigen ist er trotzdem,
    -- und spaetestens wenn eine Stufe 2 daneben steht, ist er das wichtigste Unterscheidungsmerkmal.
    ["Disclosure"] = "Lyra antwortet aus festen Vorlagen und deiner eigenen Chronik. Es läuft kein Sprachmodell.",
}
