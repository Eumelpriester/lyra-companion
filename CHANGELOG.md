# Changelog

## 0.15.0 (2026-09-20)

### Welle 11a: Der Tod bekommt eine Stimme
**Der Tod bekommt eine Stimme.** Nach dem Fall eines Hardcore-Charakters schweigt Lyra
weiterhin eine Minute — das bleibt so. Danach spricht sie einen Nachruf aus den Fakten, die
ohnehin in deiner Chronik stehen: Stufe, Zone, gespielte Stunden, Beinahe-Tode, der ärgste
Gegner. Hast du ihr letzte Worte mitgegeben, trägt sie sie weiter — und nur dann; sie erfindet
keine. Die Frage nach den letzten Worten hat jetzt vier Fassungen statt einer, der Vorgänger
sechs Zeilen statt zwei. Das Chronik-Fenster hat einen neuen Abschnitt: die **Halle der
Gefallenen**, mit allen deinen gefallenen Charakteren, ihrer Stufe, ihrer Zone und ihren letzten
Worten. Nur deine eigenen, nie fremde.
**Sie erinnert sich an dich.** 48 neue Zeilen greifen erst, wenn ihr eine Weile zusammen
unterwegs wart — der Schwerpunkt liegt auf den ersten zehn Stunden, wo es bisher vier Zeilen im
ganzen Katalog gab. Dazu 15 seltene Zeilen, die du vielleicht nie hörst.
**Der Rückblick kommt jetzt beim Abschied.** Wenn du `/camp` tippst, erzählt sie im Countdown
etwas aus *dieser* Sitzung statt beim nächsten Login von der letzten.
**Größere Vorräte.** Der Fluchtmob-Warner hatte zwei Sätze und hat jetzt sechs; `LEVELUP`
zwölf statt sechs, Lyra anklicken zwanzig statt elf, Emotes sechzehn statt neun.

### Sicherheit
- **Erschöpfung im offenen Meer sagt jetzt das Richtige.** Bisher kam beim
  Erschöpfungsbalken eine Plauderzeile über das Gasthaus — und die wurde im Kampf
  zurückgehalten, in der Gruppe verworfen und im Still-Modus geschluckt. Jetzt kommt eine
  Warnung der Stufe 2, sie kommt in allen drei Lagen durch, und sie sagt, was hilft:
  umkehren. Auftauchen hilft bei Erschöpfung nicht.
- **Dein eigener Beinahe-Tod schlägt fremde Statistik.** Stehen an derselben Stelle deine
  eigene knappe Erinnerung und eine fremde Todeszelle, kommt nur noch deine — und die
  fremden schweigen dort 30 Sekunden.

### Ruhe und Dosierung
- **Hinweise der Stufe 1** (Klippen, tiefes Wasser, Tränke, Bestiarium, Runner …) haben
  jetzt 15 Sekunden Abstand und höchstens zehn je Stunde. Warnungen und Alarme sind
  unberührt: Leben unter 20 %, Sturz, letzte Luft und die Boss-Ansage kommen weiter sofort.
- **Einzelne Ereignisse abschalten:** `/lyra stumm <EREIGNIS>`, zurück mit `/lyra laut
  <EREIGNIS>`. Was du zuletzt gehört hast, zeigt `/lyra gehoert` — mit der ID zum
  Abschalten. Alarme lassen sich nicht abschalten.
- **„Warum sagst du nichts?"** — `/lyra warum` nennt die letzten fünf Meldungen, die nicht
  herausgekommen sind, und den Grund dafür. Es steht auch dabei, was davon Verlust war und
  was einfach so eingestellt ist.
- **Seltene Zeilen.** Zeilen, die als selten markiert sind, kommen nur noch ein Viertel so
  oft und nie zweimal hintereinander.

### Ton
- **Lyra hat einen eigenen Lautstärkeregler**, `/lyra lautstaerke <0-100>` oder der Schieber
  in der Feineinstellung. Er wirkt relativ zum gewählten Tonkanal; Blizzards Regler wird
  dafür nur für die Dauer einer Zeile gesenkt und danach exakt zurückgestellt — auch, wenn
  du mittendrin neu lädst. Alarme bleiben immer voll laut.

## 0.14.0 (2026-09-20)

### Lyra verzählt sich seltener
Die Freitext-Fragen aus 0.13.0 antworten jetzt genauer — und vor allem seltener falsch. Lyra
zieht ein vertipptes Wort nicht mehr auf irgendein ähnlich klingendes Wort, das ganz woanders
hingehört, und ein einzelnes Wort reicht ihr nicht mehr aus, um eine ganze Frage für
verstanden zu halten. Wo sie früher eine echte Zahl zur falschen Frage genannt hat — „wie oft
war ich im Brachland" mit der Zahl deiner Tode —, sagt sie jetzt schlicht: dazu steht noch
nichts in meinem Buch.
**Zonennamen versteht sie in beiden Sprachen.** Wer auf einem deutschen Client „how many times
have I been to Stranglethorn Vale" tippt, bekommt die Zahl für das Schlingendorntal, und
umgekehrt genauso — für die Außenzonen und Hauptstädte der Classic-Welt.
**Und auf „warum" antwortet sie ehrlich.** „Warum bin ich in Westfall immer fast gestorben?"
beantwortet keine Zahlentabelle. Lyra erfindet dafür nichts, sondern gibt die Tatsache zurück:
„Warum? Ich zähle, ich deute nicht. Ich weiß nur: …"
`/lyra hilfe` endet jetzt mit einem Satz, der immer gestimmt hat und bisher nirgends stand:
Lyra antwortet aus festen Vorlagen und deiner eigenen Chronik. Es läuft kein Sprachmodell.

### Farbthemen
- **Vier benannte Farbpaletten** für Sprechblase, Untertitel-Leiste und den Warnstufen-Puls
  am Bildschirmrand: `standard` (Lyras Violett, unverändert), `kontrast` (Schwarz/Weiß),
  `warm` (Bernstein auf Braun) und `kalt` (Eisblau auf Nachtblau). Umschalten mit
  `/lyra farbe <name>`; die Wahl bleibt gespeichert. Voreinstellung ist `standard` —
  wer nichts tut, sieht nichts Neues.
- Jede Palette ist auf Lesbarkeit gerechnet: Text steht in allen vier zwischen 16,8:1 und
  21:1 auf dem Blasengrund, die Untertitel-Leiste auch über einem gleißend hellen Spielbild
  noch zwischen 11,8:1 und 15,1:1. Verlangt sind 4,5:1.
- Das Häkchen **„Hoher Kontrast“ gewinnt gegen jede Palettenwahl.** Eine Farbwahl kann die
  Barrierefreiheit nicht unterlaufen; `/lyra farbe` sagt es dir, wenn deine Wahl gerade
  deshalb nicht wirkt.
- Keine Palette ändert **Helligkeit oder Takt** des Pulses — das ist die
  Photosensibilitätsgrenze und keine Geschmacksfrage. Und Lyras Alarm ist in keiner Palette
  Blizzards Rot: der Client zeichnet dort seine eigene Warnung, und zwei gleiche Rot kann
  niemand auseinanderhalten.

### Kleinkram
- Die Client-Erkennung für WoW: Forever hält jetzt auch eine Buildlinie 1.7x bis 1.9x aus.
  Die TOC-Zeile selbst bleibt draußen, bis ein Client Suffix und Nummer bestätigt.
- Lizenzangaben der eingebetteten Bibliotheken nachgeschlagen und belegt (`Libs/LICENSE.txt`).
  LibDataBroker-1.1 steht bei CurseForge unter „All Rights Reserved“ und wird deshalb **nicht
  mehr mitgeliefert**; die Leisten-Anzeige (Titan Panel, ElvUI-Datentexte) funktioniert weiter,
  weil jedes dieser Addons die Bibliothek selbst mitbringt.
- Fehlermeldungen: deutsche Vorlagen, und der Hinweis, welche Angaben eine Meldung
  reparierbar machen.

### Stimme
- 23 Zeilen, die seit den Wellen 5, 6, 8 und 9b nur als Untertitel erschienen, sind jetzt
  aufgenommen, Deutsch und Englisch: die Vorwarnungen vor Sturz und tiefem Wasser, das
  Ankommen an einer eigenen Notiz, das Ein- und Ausschalten des Barrierefrei-Modus und Lyras
  drei Rückfall-Antworten im Freitext. Zeilen mit Platzhaltern (Zonenname, Zahl, Notiztitel)
  bleiben Untertitel oder Vorlesen. Wie immer: neue Tondateien hört der Client erst nach einem
  vollständigen Neustart.

## 0.13.0 (2026-09-20)

### Welle 9b: Frei schreiben mit Lyra
Unter Lyras Gesprächsfenster steht jetzt ein Eingabefeld. Du kannst sie in ganzen Sätzen nach
deiner eigenen Chronik fragen — nach Zonen und Besuchen, nach deinem ärgsten Gegner, nach
Beinahe-Toden, Spielzeit, Sitzungen, Notizen und deinem Vorgänger. Sie versteht 18 Arten von
Fragen in Deutsch und Englisch, verzeiht Tippfehler und erkennt Zonen- und Gegnernamen aus
deiner eigenen Chronik. Antwortet sie nicht, sagt sie jetzt auch, warum: „dazu steht noch
nichts in meinem Buch", „Karten sind nicht mein Fach" oder schlicht „das habe ich nicht
verstanden" — drei Antworten statt einer. Und sie kommt später von selbst noch einmal auf
deine Frage zurück.
**Es läuft kein Sprachmodell.** Lyra antwortet aus festen Vorlagen und deinen eigenen Zahlen;
nichts verlässt deinen Rechner, und dein Tipptext wird standardmäßig nicht einmal
gespeichert. Das Eingabefeld nimmt den Fokus nur auf Klick und gibt ihn bei Kampfbeginn
sofort wieder ab — ein Feld, das WASD schluckt, ist auf Hardcore lebensgefährlich.
Schalter: `/lyra freitext an|aus` und „Frei schreiben" in der Feineinstellung.
`/lyra <Frage>` funktioniert weiter wie bisher.

### Welle 9a: Sie spricht die Namen richtig aus — und behält, was ihr gesagt wurde

**Persönliche Zeilen werden wieder nur angezeigt.** In `/lyra persoenlich` stand seit jeher
„nie mit Stimme". Seit die Vorlese-Funktion da ist, hat sie sich daran nicht gehalten — jede
Zeile ohne Aufnahme wurde vorgelesen, und persönliche Zeilen haben nie eine. Das ist jetzt
wieder so, wie es dasteht. Wer es anders will, findet in der Feineinstellung ein Kästchen
dafür; es ist aus.

**Sie spricht die Namen richtig aus.** Lyras eigene Stimme ist aufgenommen und klingt, wie sie
klingen soll. Die Zeilen mit einem Zonennamen, einer Zahl oder deinem Namen darin kann man
nicht vorher aufnehmen — die liest dein Betriebssystem vor, und das las bisher „Azeroth" mit
einem harten Z und „Onyxia" mit einem Ü. Lyra bringt jetzt ein Aussprache-Verzeichnis mit,
für Deutsch und Englisch. Es gilt **nur** fürs Vorlesen: in der Sprechblase steht weiterhin
der Name, nicht die Lautschrift. Fehlt dir ein Wort, leg es selbst ab —
`/lyra aussprache Onyxia = Onixia`.

**Sie ist jetzt auch in deiner Leiste.** Wer Titan-Panel, Bartender4, ChocolateBar oder einen
Knopf-Sammler benutzt, findet Lyra dort: ihr Zustand als Text, ein Klick öffnet das Menü. Der
Minimap-Knopf bleibt, wie er war — das kommt dazu, es ersetzt nichts.

**Einstellungen mitnehmen.** `/lyra profil export` gibt dir eine Zeichenkette, die du kopieren,
aufheben oder verschicken kannst; `/lyra profil import` liest sie wieder ein. Darin stehen
**nur** Einstellungen — keine Chronik, kein Charaktername, kein Realm. Was nicht auf die Liste
gehört, kommt beim Import nicht durch, auch nicht, wenn jemand daran herumgeschraubt hat.

| | |
|---|---|
| **Neu** | Aussprache-Verzeichnis für vorgelesene Zeilen, 68 Einträge (de/en), nur für die Stimme |
| **Neu** | `/lyra aussprache` — eigene Aussprache ablegen, ansehen, entfernen |
| **Neu** | `/lyra profil export` und `/lyra profil import` mit Kopierfenster |
| **Neu** | LibDataBroker-Anzeige für Titan-Panel, Bartender4, ChocolateBar und Knopf-Sammler |
| **Neu** | Kästchen *Auch persönliche Zeilen vorlesen* (aus) unter *Feineinstellung → Stimme* |
| **Geändert** | Persönliche Zeilen werden angezeigt, nie vorgelesen — so, wie es immer dastand |
| **Geändert** | Questie wird über die offizielle Schnittstelle gelesen; der alte Weg bleibt als Rückfall |
| **Behoben** | Beim Annehmen einer Quest konnte Lyras Zeile zu früh kommen, bevor Questie fertig geladen war |

**Prüfstand:** 58 Läufe, 4 396 Prüfungen, alle grün. Katalog 122 Ereignisse.

## 0.12.0 (2026-09-20)

### Welle 8: Sie warnt, bevor es passiert

**Die Warnung kommt jetzt vorher.** Bisher hat Lyra gesagt „hier sind schon welche
gestürzt", wenn du bereits an der Klippe standest. Jetzt schaut sie, wohin du läufst, und
sagt es zwanzig bis vierzig Meter vorher — leise, einmal, und nur an Stellen, an denen
mindestens zehn Leute auf dieselbe Weise gestorben sind. *Sie sagt nicht, wohin du gehen
sollst. Sie sagt, wo andere gestorben sind.*

Dazu gehört eine lange Liste von Dingen, bei denen sie **nicht** redet: nicht im Kampf,
nicht auf dem Greifen, nicht im Flug, nicht in der Stadt oder im Gasthaus, nicht in einer
Instanz, nicht wenn du stehst, nicht wenn du dich drehst, nicht zweimal an derselben
Stelle. Eine Warnung, die zu oft kommt, ist schlimmer als keine — deshalb sind die Riegel
länger als die Funktion.

**Schwimmen.** Steht deine Luft unter der Hälfte und du bist über einer Stelle, an der
schon Leute ertrunken sind, sagt sie es. Einmal.

**Sie überlebt einen Patch-Tag.** Beim Einloggen prüft Lyra die acht Stellen, an denen sie
am Spiel hängt. Fällt eine weg, schaltet sie den betroffenen Sinn ab und sagt einen Satz im
Chat — statt dir einen Fehler mit ihrem Namen darin zu zeigen. Der Rest läuft weiter.
`/lyra selbsttest` sagt genau, was fehlt; das ist die Zeile, die in einen Bugreport gehört.

**Und sie lässt sich wieder am Kragen packen.** Wenn du Lyra über den Bildschirm ziehst,
erschrickt sie jetzt auch dann, wenn sie gerade ein Gesicht zu einem Ereignis macht.

| | |
|---|---|
| **Neu** | `STURZ_VORAUS`, `WASSER_VORAUS`: eine ruhige Zeile 20–40 Meter vor einer Sturz- oder Ertrinkungsstelle, in Laufrichtung, ab zehn Toten dort |
| **Neu** | `TIEFES_WASSER`: über einer Ertrinkungsstelle mit halber Luft |
| **Neu** | Selbsttest beim Login. Fällt eine Schnittstelle weg, kommt ein Satz statt eines Fehlers, und nur der betroffene Sinn geht aus |
| **Neu** | `/lyra selbsttest` — acht Zeilen für den Bugreport |
| **Neu** | `/lyra vorwarnung an\|aus` und ein Kästchen unter *Feineinstellung → Datenquellen* |
| **Geändert** | Die Einstellungsseite heißt jetzt „Lyra Companion", so wie das Addon überall sonst |
| **Geändert** | „Warnstufe auch als Form" ist in die Feineinstellung gewandert; die erste Seite ist wieder dreizehn Einträge lang |
| **Behoben** | Lyra ließ sich beim Ziehen nicht mehr erschrecken, sobald sie ein Gesicht zu einem Ereignis hielt |
| **Behoben** | Nach einem Beinahe-Tod in den ersten Minuten redete sie *mehr* statt weniger. Die Stimmung rechnet jetzt anders |
| **Behoben** | Auf Clients mit Blizzards eigener Sprachausgabe wurde eine Kategorie geraten. Wird sie nicht gemeldet, entscheidet jetzt der Client |

Alles Neue liegt in zwei Dateien (`Core/Selbsttest.lua`, `Sinne/Welle8.lua`); an bestehenden
Dateien stehen rund 40 neue Zeilen. Ohne das Paket Lyra_Gestalt_Daten passiert nichts, auf
Retail und Forever ebenfalls nicht — dort liegt hinter denselben Karten eine andere Welt.
Prüfstand: vier Drehbücher, 240 Prüfungen, alle grün.


---

### Der Rand-Puls ohne Ecken

**Bildschirmrand-Puls: die Ecken.** Der Warnrahmen bestand aus vier Bändern, die sich in den
Ecken überlappten — im ADD-Blend addierte sich dort die Helligkeit auf das Doppelte, und man
sah vier hellere Rechtecke. Der Rand ist jetzt ein 9-Slice: vier Kanten, die vor der Ecke
enden, und vier Eck-Kacheln, die den Verlauf diagonal fortsetzen. Keine zwei Flächen teilen
sich noch einen Pixel, also kann nichts mehr doppelt gezeichnet werden. Die Randbreite hängt
ab sofort an der kurzen Bildschirmseite statt an beiden Achsen einzeln: auf 16:9, 16:10 und
21:9 ist der Rahmen gleich breit, vorher war er auf Ultrawide links und rechts fast doppelt so
breit wie oben und unten. `bilder/puls_rand.png` ist dafür von einer Vollbild-Maske zu einer
Eck-Kachel geworden, aus der sich auch die Kanten ihren Verlauf holen — eine Datei für alle
acht Flächen. Unter dem Strich liegt trotz kräftigerer Wirkung 31 % weniger Licht auf dem
Bildschirm, und der Spitzenwert fällt von 0,70 auf 0,48. Stufen, Farben, Doppelschlag,
Standzeit, Streamer- und Barrierefrei-Verhalten sind unverändert.

**Hinweis zum Ansehen:** eine neue Bilddatei sieht der Client erst nach einem vollen Neustart, `/reload` reicht nicht.

## 0.11.0 (2026-09-20)

### Welle 5: Die Karte

Lyra zeichnet jetzt auf die Karte, was sie weiß. Jede Stelle, an der du fast gestorben
bist, bekommt einen Pin auf Welt- und Minimap — mit dem Leben, das dir geblieben ist, und
wer daran schuld war. Deine eigenen Punkte aus `/lyra punkt` liegen daneben, mit deiner
Notiz im Tooltip. Und über die Zone, in der du gerade stehst, legt sie die Gefahrenkarte:
halbdurchsichtige Felder, orange für Stürze, blau für Ertrinken, rot für Kreaturen, je
kräftiger die Farbe, desto mehr Tode. Gezeigt wird dabei genau das, wovor sie auch warnt —
eine Karte, die etwas anderes behauptet als die Begleiterin, wäre schlimmer als keine.

**Der Fund dieser Runde war eine Zahl, die seit Welle 1 falsch war.** Lyras Warnung vor
einer alten Beinahe-Stelle hing an einem festen Anteil der Kartenbreite — und Zonen sind
verschieden groß. In einer weiten Außenzone bedeutete derselbe Wert ein Vielfaches dessen,
was er in einer Stadt bedeutete: die Warnung kam je nach Gegend zu früh oder viel zu spät.
Sie rechnet jetzt in echten Yard, für jede Zone einzeln.

**Was sie ausdrücklich nicht tut:** Sie legt keinen zweiten Warnruf auf dieselbe Stelle.
Den gab es schon; er war nur schlecht vermessen.

| | |
|---|---|
| **Neu** | Pins auf Welt- und Minimap für Beinahe-Tode und für deine eigenen Punkte, mit Lyras Text im Tooltip |
| **Neu** | Gefahrenkarten-Overlay auf der Weltkarte deiner Zone, Farbe nach Todesart, Deckkraft nach Zahl der Tode. Braucht das Paket Lyra_Gestalt_Daten, nur auf Classic-Clients |
| **Neu** | `PUNKT_NAH`: ein Satz, wenn du an einem selbst gesetzten Punkt ankommst — höchstens alle zehn Minuten je Punkt, nie im Kampf |
| **Neu** | `/lyra karte`: Übersicht und Schalter (`/lyra karte overlay an\|aus`, ebenso beinahe, notizen, nah) |
| **Neu** | `/lyra punkt weg [n]`: einen Punkt wieder löschen |
| **Neu** | Vier Kästchen unter *Feineinstellung → Karte und Pins*, alle Default an. Der alte Schalter „Karten-Pins" bleibt der Hauptschalter |
| **Neu** | Mit TomTom färbt Lyra den Wegpunkt-Pfeil lila — aber nur, wenn ein anderes Addon ihn übernommen hat und die Farbe auch hält |
| **Behoben** | Die Warnung vor einer alten Beinahe-Stelle kam je nach Zonengröße deutlich zu früh oder zu spät. Sie misst jetzt in Yard |
| **Behoben** | Beinahe-Pins lagen doppelt, seit es zwei Stellen gab, die sie zeichnen wollten |
| **Intern** | HereBeDragons ist eingebettet (Libs/). Bringt ein anderes Addon eine neuere Fassung mit, gewinnt dessen — Lyra verlangt nichts |

Alles Neue liegt in einer einzigen Datei (`Sinne/Karte2.lua`); an bestehenden Dateien
stehen rund 50 neue Zeilen. Ohne HereBeDragons passiert nichts, und `/lyra karte` sagt
ehrlich, warum. Prüfstand: vier Drehbücher, 388 Prüfungen, alle grün.

### Welle 6: Barrierefreiheit, Koexistenz, Andocken

**Lyra hat jetzt einen Barrierefreiheits-Modus, und er ist ein Schalter, kein Kleingedrucktes.**
Ein Klick — oder `/lyra barrierefrei an` — und die Untertitel-Leiste bleibt dauerhaft stehen,
vor jeder Zeile steht „Lyra:", die Schrift wird größer, jede Zeile bleibt länger, und Zeilen
ohne Sprachaufnahme werden vorgelesen, sofern dein System eine Stimme hat. Schaltest du ihn
wieder aus, bekommst du deine alten Einstellungen zurück: der Modus merkt sie sich, er
überschreibt sie nicht.

**Warnstufen tragen ab sofort eine Form, nicht nur eine Farbe.** Ein Punkt für einen Hinweis,
ein Dreieck für eine Warnung, zwei für einen Alarm — klein an der Sprechblase, im
Barrierefreiheits-Modus größer. Das gilt auch ohne den Modus. Farbe allein trägt eine Warnung
für rund acht Prozent der männlichen Spieler nicht, und Blizzards eigene Rahmenfarben ändern
daran nichts.

**Und Lyra funktioniert vollständig ohne Figur.** Der Erst-Start-Assistent hat eine vierte
Frage bekommen: „Soll ich zu sehen sein?" Wer „nur Stimme und Untertitel" wählt, bekommt
dieselbe Lyra — dieselben Ereignisse, dieselbe Stimme, dasselbe Gedächtnis —, nur ohne
Portrait. Ihr Text steht dann in der Untertitel-Leiste oder in einer Sprechblase am unteren
Bildschirmrand. Auch nachträglich: `/lyra figur aus`.

| | |
|---|---|
| **Neu** | Barrierefreiheits-Modus als ein Schalter (Panel ganz oben, `/lyra barrierefrei an|aus`) — Leiste, Sprechername, Schriftgröße, Standzeit, Vorlesen, Form-Symbole in einem Zug, mit vollständigem Rückweg |
| **Neu** | Warnstufe zusätzlich als Form: `o` Hinweis, `^` Warnung, `^^` Alarm. Abschaltbar, standardmäßig an |
| **Neu** | „Nur Stimme und Untertitel": vierte Option im Erst-Start-Assistenten und `/lyra figur aus`. Lyra bleibt dabei vollwertig |
| **Neu** | Nie zwei Stimmen gleichzeitig: spricht Blizzards Sprachausgabe oder ein Screenreader, stellt Lyra ihr Vorlesen zurück, bis der andere fertig ist — statt wie bisher dauerhaft zu schweigen, nur weil die Funktion eingeschaltet ist |
| **Neu** | Lyra kann durch Blizzards eigenen Kampf-Audio-Assistenten sprechen (`C_CombatAudioAlert`) — auf **allen** Clients, nicht nur auf Retail. Dann kann es zwei Stimmen gar nicht geben |
| **Neu** | Stillhalte-Regel für **GTFO**: während eines Bodeneffekt-Alarms plaudert Lyra nicht (3 s, bei der hohen Alarmstufe 6 s). Warnungen laufen weiter durch. Kein Schalter — eine Regel, die nur leiser macht, braucht keinen |
| **Neu** | Gamepad: Gesprächsfenster und Menü sind mit **ConsolePort** bedienbar |
| **Neu** | WeakAuras-Auren können jetzt an genau einem Lyra-Ereignis hängen: `LYRA_EREIGNIS:HP20` als Trigger-Name, ohne eine Zeile Lua. Ältere WeakAuras bekommen weiter `LYRA_EREIGNIS` |
| **Neu** | `/lyra status` sagt, was Lyra kostet: Speicher je Paket und Rechenzeit (letztere nur, wenn `scriptProfile` läuft — sonst steht dort, wie man sie misst, statt einer 0) |
| **Neu** | Self-Found und Hardcore werden über `C_GameRules` erkannt statt geraten; `/lyra status` nennt die Quelle und trennt sauber, was der Realm sagt und was dein Schalter sagt. Lyra setzt ihn weiterhin nicht selbst |
| **Behoben** | Die Client-Weiche hing an Interface-Nummern. Ein Forever-Build mit einer Nummer außerhalb des erwarteten Bereichs wäre als „TBC" gelaufen — mit gesperrtem Combat-Log-Verhalten, das dort eine Blizzard-Fehlermeldung mit Lyras Namen ausgelöst hätte. Sie fällt jetzt zuerst an einem Laufzeit-Test (`C_RestrictedActions`) |
| **Behoben** | Lyras Vorlesen schwieg dauerhaft, sobald Blizzards Kampf-Audiohinweise nur **eingeschaltet** waren. Jetzt zählt, ob gerade jemand redet |

Alles Neue liegt in einer einzigen Datei (`Sinne/Welle6.lua`); an bestehenden Dateien stehen
rund 180 neue Zeilen, gut die Hälfte davon Kommentar und Einstellungstexte. Ohne GTFO, ohne
ConsolePort und ohne WeakAuras passiert nichts, und `/lyra status` sagt ehrlich „nicht
installiert". Prüfstand: 4 Drehbücher, 555 Prüfungen, alle grün.

### Welle 7: Screenshot-Runde — Puls, Blase, Chronik-Fenster, Sprachwechsel

**Bildschirmrand-Warnung neu gebaut.** Statt eines harten weißen Blocks liegt jetzt ein
weiches Glühen am Rand, mit einer eigenen Textur statt einer Verlaufs-API, die auf Classic
Era nicht verlässlich ist. Drei unterscheidbare Stufen: Hinweis dezent violett, Warnung
kräftiger, Alarm rot-violett mit einem kurzen Doppelschlag. Nie länger als eine Sekunde.
Im Streamer-Modus bleibt der Puls aus; im Barrierefreiheits-Modus wird er kräftiger statt
schwächer, dafür mit größerem Abstand zwischen zwei Pulsen.

**Die Sprechblase kürzt nicht mehr.** Ein langer Satz neben dem Portrait endete bisher mit
„…". Jetzt bricht er um — in jeder Lage. Ist rechts oder links kein Platz mehr, geht die
Blase nach oben, statt an den Bildschirmrand geschoben zu werden.

**Die Chronik ist ein Fenster.** `/lyra chronik` öffnet ein Fenster mit den besuchten Zonen,
den Beinahe-Toden mit Datum und Ort, den gefährlichsten Gegnern und den Sitzungen — statt
fünf Zeilen im Chat. Ohne Charakter-, Gilden- oder Realmnamen: ein Screenshot davon verrät
nicht, wem er gehört.

**Sprachwechsel ohne Neuladen.** `/lyra sprache de|en` stellt Einstellungsseite, Menü,
Gespräch und Chronik sofort um. Sollte ein Teil davon auf einem Client doch ein `/reload`
brauchen, sagt Lyra es im Chat, statt es zu verschweigen.

**Die Untertitel-Leiste trägt das Warnsymbol** (`o` / `^` / `^^`) wie die Sprechblase. Im
Stream ist die Warnstufe damit auch ohne Farbe zu erkennen.

---

**Dazu in derselben Version:** die sechs Welle-4-Ereignisse sind jetzt vertont; `/lyra test <ID>` geht
wie Klick und „Sag was" am Stundenbudget vorbei (vorher nach 15 Proben stumm); die Sprechblase bleibt
per Clamping im Bild; die Randkachel der Blase ist korrekt gedreht (Leitermuster behoben); die erzeugte
`_Vanilla.toc` beginnt mit einer Direktive (12.0.7-Regel); Libs: LibStub, CallbackHandler-1.0,
HereBeDragons-2.0 mit Lizenzhinweis. Prüfstand: 45 Läufe, 3 201 Prüfungen, alle grün — und seit heute
im Projekt statt in /tmp (`tests/pruefstand/`).

## 0.10.0 (2026-09-20)

### Welle 4: Alltag II, Hardcore-Wechsel, Signale

Sechs neue Ereignisse, keines davon laut. Lyra sagt am Handwerksfenster etwas zum ersten
Fortschritt einer Sitzung und wenn ein Beruf an der Lehrer-Grenze steht; sie erinnert nach
einem knappen Kampf einmal an Verbände, wenn keine im Beutel liegen; sie begrüßt einen
Wechsel in den oder aus dem Hardcore-Modus mit genau einem Satz; und sie zählt still mit,
wie viele Fundstellen GatherMate2 heute neu eingetragen hat. Dazu beantwortet sie auf Zuruf
die vier großen Era-Einstimmungen — die Voraussetzung, nie die Route.

**Der Fund dieser Runde steckte in einer API, nach der niemand gefragt hatte.** Auf Classic
Era laufen Verzauberkunst und Tierausbildung nicht über `TRADE_SKILL_*`, sondern über die
alte Craft-API mit eigenem Fenster und eigenen Events. Ein Berufs-Moment, der nur auf das
Handwerksfenster hört, wäre für Magier mit Verzauberkunst — eine der häufigsten
Era-Kombinationen überhaupt — dauerhaft blind geblieben. Lyra hört jetzt auf beides.

**Und Lyra ist ab sofort eine Signalquelle.** Nach jeder Zeile schickt sie das Custom-Event
`LYRA_EREIGNIS` (ID, Klasse, Stufe) an WeakAuras. Wer eine eigene Aura auf Lyras Warnungen
bauen will, braucht dafür drei Zeilen — die Anleitung steht in `Sinne/WELLE4.md`. Das alte
`LYRA_GESTALT` feuert unverändert weiter; bestehende Auren brechen nicht.

| | |
|---|---|
| **Neu** | `BERUF_ERSTER` / `BERUF_GRENZE`: ein Satz zum ersten Punkt einer Sitzung und an den Lehrer-Grenzen 75/150/225/300 (`TRADE_SKILL_*` **und** die Era-Craft-API) |
| **Neu** | `ERSTE_HILFE`: nach einem Kampf unter der Hälfte des Lebens (auf Hardcore) bzw. unter einem Drittel eine Plauder-Zeile (Stufe 0, keine Warnung), wenn kein Verband im Beutel liegt — einmal je Sitzung, und er entfällt, wenn du inzwischen welche gekauft hast |
| **Neu** | `HC_MODUS_AN` / `HC_MODUS_AUS`: eine Zeile, wenn der Hardcore-Zustand beim Login anders ist als zuletzt gemerkt. Einmal je Wechsel, kein Schalter nötig |
| **Neu** | `GM2_KNOTEN`: zählt neue GatherMate2-Fundstellen der Sitzung; ab der zehnten darf sie etwas sagen, danach höchstens alle 30 Minuten. Der Knoten wird nie beim Namen genannt |
| **Neu** | `/lyra attunement [onyxia|mc|bwl|naxx]`: die Voraussetzung in drei Sätzen. Keine Route, keine Schrittfolge |
| **Neu** | Custom-Event `LYRA_EREIGNIS` für WeakAuras, dokumentiert in `Sinne/WELLE4.md` |
| **Neu** | Vier Schalter unter *Feineinstellung → Alltag II und Signale*, alle Default an |
| **Neu** | `/lyra status` sagt eine Zeile zu Welle 4: welche Berufs-API der Client hat, ob WeakAuras und GatherMate2 erkannt wurden und über welchen Weg |
| **Behoben** | Die Hardcore-Zeile wäre am Plauder-Abstand verhungert, weil Welle 4 den letzten Login-Slot bekommt. Vierter Fund desselben Musters seit Review 5 — und wieder im Prüfstand reproduziert, nicht im Spiel bemerkt |

Alles Neue liegt in einer einzigen Datei (`Sinne/Welle4.lua`); an bestehenden Dateien
stehen rund 50 neue Zeilen, gut die Hälfte davon Kommentar und Einstellungstexte. Ohne WeakAuras und ohne GatherMate2 passiert nichts, und `/lyra status`
sagt ehrlich „fehlt". Prüfstand: 34 Drehbücher, 2099 Prüfungen, alle grün — davon 401 neu.

**Dazu im selben Paket:** alles aus 0.9.1 (unten) — beide Stände sind in derselben Nacht entstanden,
ausgeliefert wird nur 0.10.0. Die sechs neuen Ereignisse sind **vertont** (15 deutsche, 14 englische
Aufnahmen, per Whisper gegengehört); nur Zeilen mit Live-Werten (`{beruf}`, `{wert}`, `{anzahl}`)
bleiben absichtlich Untertitel bzw. Vorlesen — eine Aufnahme kann keine Zahl einsetzen.

## 0.9.1 (2026-09-19)

### Aufräumen vor dem Upload

Keine neuen Features. Diese Version schließt die zwei Punkte, die der Port 0.9.0 offen gelassen
hat, und bringt die Lizenz- und Metadaten-Texte in Ordnung — das ist der Teil, den die
CurseForge-Moderation liest.

**Der schlimmste Fund war eine Zeile, die im Gespräch gelogen hätte.** `UI/Dialog.lua` las die
Stufe des Ziels zwar schon über `ns.Compat.unitLevelLesbar()`, hängte aber ein `or 0` daran. Auf
Retail und Forever ist die Stufe einer fremden Einheit im Kampf ein „secret value" — der Helfer
gibt dort `nil` zurück, und aus `nil or 0` wurde die **Stufe 0**. Ab der eigenen Stufe 3 heißt
das „leicht": Lyra hätte im Kampf jeden Gegner, dessen Stufe sie gar nicht lesen kann, als
harmlos eingestuft. Der richtige Satz stand die ganze Zeit fertig in `dialog.lua` („Die Stufe
kann ich nicht lesen. Das ist selten ein gutes Zeichen.") und war nur unerreichbar.

| | |
|---|---|
| **Behoben** | `UI/Dialog.lua`: unlesbare Ziel-Stufe wird wieder „unbekannt" statt „leicht" (`-- REVIEW9:`) |
| **Behoben** | `Lyra_Gestalt_Stimme_de` hatte als einziges der fünf Pakete **keine Flavor-Zeilen** — auf TBC, MoP und Retail wäre Lyra dort stumm geblieben, ausgerechnet auf Deutsch |
| **Behoben** | Alle `## X-License:`-Zeilen verwiesen auf eine Datei `LICENSE.md`, die es im Zip nicht gibt (ausgeliefert werden `LICENSE` und `LICENSE-ASSETS.md`) |
| **Behoben** | `LICENSE-ASSETS.md` nannte die Sprites noch unter `Lyra_Gestalt/gestalt/*.png` — der Ordner heißt seit 0.8.0 `bilder/` (und `bilder/rund/`) |
| **Neu** | Feature-Flag `C.F.gefahrenkarte`: die Gefahrenkarte ist auf **Retail und Forever aus** |
| **Neu** | `/lyra status` sagt jetzt eine Zeile zur Gefahrenkarte — Zellen, Schalter aus, Paket fehlt oder Client passt nicht |

### Die Gefahrenkarte schweigt auf Retail und Forever

Die Zellen im Paket `Lyra_Gestalt_Daten` sind aggregierte **Hardcore-Tode aus Classic Era**.
Hinter derselben `mapID` steht auf Retail eine überarbeitete Zone ohne Hardcore und auf Forever
eine Welt mit überarbeiteten Klassen und Mobs. Bisher lief die Übernahme dort einfach mit und
fand **meist** nichts — „meist" ist die Lücke: eine Zelle, die doch trifft, ist dort eine falsche
Warnung, und eine falsche Warnung ist schlimmer als gar keine. Genau diese Begründung steht seit
0.9.0 schon bei den Reagenzien-Hinweisen.

MoP Classic bleibt bewusst an: Vanilla-Azeroth ist dort dieselbe Welt, und die Sturz- und
Wasser-Zellen — die Mehrheit — sind Gelände, kein Spielinhalt.

Abgeschaltet wird **still**: kein Hinweis beim Login, keine Zeile im Chat. Wer nachfragt, bekommt
in `/lyra status` den Grund samt Client-Profil.

### Kleinigkeiten

- Das persönliche Paket trug im Feld `charKey` noch einen echten Charakternamen und im Kopf den
  echten Kontoordner, obwohl der Kommentar darüber schon von „Testheld-Testrealm" sprach. Beides
  ist jetzt anonymisiert. **Für den eigenen Rechner:** in der Kopie unter `Interface/AddOns/`
  muss dort der eigene `Name-Realm` stehen, sonst ignoriert der Loader das Paket.
- `Sinne/BRUECKEN.md` nannte einen absoluten Pfad mit dem Benutzernamen des Entwicklungsrechners.
- Stimm-Beschreibungen sagen jetzt überall dasselbe: synthetisch, offline erzeugt und **als
  KI-generiert gekennzeichnet** (EU AI Act Art. 50).
- Prüfstand: zwei neue Szenen je Client-Profil (Gefahrenkarte, Gespräch über das Ziel),
  **1 698 Prüfungen** in 29 Läufen, alle grün. Beide neuen Szenen sind gegengeprüft — mit dem
  alten Code werden sie rot.

## 0.9.0 (2026-09-18)

### Lyra zieht um — auf fünf Clients statt einem

Bis 0.8.0 lief Lyra auf Classic Era. Sie lief dort gut, und nirgends sonst war je nachgesehen
worden. Diese Version macht sie mehrversionsfähig: **Classic Era 1.15.9, Burning Crusade
Anniversary 2.5.6, Mists of Pandaria Classic 5.5.4, Retail Midnight 12.1 und WoW: Forever.**

**Und eine Ehrlichkeit vorweg, die im README genauso steht:** getestet **im Spiel** ist weiterhin
nur Classic Era. Alles andere ist gegen Blizzards eigene API-Dokumentation gebaut (die Branches
`live`, `classic_era`, `classic_anniversary`, `classic` und **`forever`** von
`Gethe/wow-ui-source`) und gegen fünf Client-Profil-Attrappen im Prüfstand. Wer Lyra als Erster
auf Retail oder Forever startet, ist der Test.

**Der Befund, der diese Runde ausgelöst hat: WoW: Forever ist kein Classic-Client, sondern ein
Mainline-Client mit Vanilla-Inhalt.** Bis gestern stand in `Core/Compat.lua` die übliche
Questie-Weiche „unbekannte Projekt-ID ⇒ Classic-Pfad". Auf Forever hätte sie den Combat-Log
registriert — und der ist dort gesperrt. Der Spieler hätte beim ersten Kampf eine
Blizzard-Fehlermeldung mit Lyras Namen darin gesehen. Das kann jetzt nicht mehr passieren, und
zwar unabhängig davon, welche Build-Nummer Forever zum Launch am 04.11. bekommt: die Erkennung
prüft erst die Interface-Nummer und fällt dann auf einen **Feature-Test** zurück
(`C_QuestLog.GetInfo` gibt es nur auf der Mainline-Codefamilie). Der Fehler geht damit immer in
die sichere Richtung.

| | |
|---|---|
| **Neu** | `Core/Compat.lua` neu geschrieben: Client-Profil (`era`/`tbc`/`mists`/`retail`/`forever`), zwölf Feature-Flags, Secret-Value-Wachen, Questlog-Shim |
| **Neu** | **Vorlesen (Text-to-Speech)** für Zeilen ohne Aufnahme — `C_VoiceChat.SpeakText`, opt-in, Standard aus |
| **Neu** | Ersatz-Bestiarium ohne Combat-Log (`UNIT_COMBAT` + Ziel-/Namensplaketten-Heuristik) |
| **Neu** | Multi-Client-TOCs: `## Interface-TBC/-Mists/-Mainline`, `enable-toc-creation: yes` |
| **Neu** | `docs/port-2026-09-18.md` — Profil-Matrix, was wo fehlt, Prüfliste für einen echten Test |
| **Neu** | Fünf Prüfstand-Läufe (einer je Client-Profil), 414 zusätzliche Prüfpunkte |

### Was auf Retail und Forever anders ist

Beide teilen sich eine Codebasis, es ist also dieselbe Liste.

- **Die Lebenswarnung funktioniert dort vollständig.** `UnitHealth("player")` bleibt unter Secret
  Values lesbar — genau darum herum ist Lyra gebaut. `Sinne/Leben.lua` musste deshalb **keine
  Zeile** geändert werden.
- **Der Combat-Log ist für Addons zu**, seit Retail 12.0 wirft schon der Registrierungsversuch.
  Lyra versucht es dort gar nicht erst. Ihr Bestiarium zählt weiter Begegnungen, Beinahe-Tode und
  Tode; den Schaden ordnet es über das aktuelle Ziel **geraten** zu — bei mehreren Gegnern rät es
  falsch, und das steht so auch in der Doku. Auf Retail ist das Bestiarium ein Nebenfeature;
  dafür einen Schadensparser nachzubauen wäre die falsche Arbeit.
- **Die Stufen-Warnung schweigt im Kampf**, weil die Stufe eines Gegners dort ein „secret value"
  ist. Die Elite-/Boss-Warnung bleibt, denn ein Name ist kein Kampfwert.
- **Das Questlog hat einen anderen Weg** (`C_QuestLog.GetInfo` statt `GetQuestLogTitle`, das auf
  Retail seit 9.0.1 entfernt ist). Lyras Quest-Sätze kommen dort genauso.
- **Hardcore-Erkennung geht auf Forever** — es hat `C_GameRules.IsHardcoreActive`, Retail nicht.
  Erbe und Gedenktag leben dort also weiter. Das war die angenehmste Überraschung der Runde.
- Questie gibt es nur für Classic; die Questie-Tiefe ist auf Retail und Forever still.

### Vorlesen (Text-to-Speech)

Lyras eigene Stimme ist vorgerendert. Zeilen mit Platzhaltern — ein Zonenname, eine Zahl, dein
Name — kann man nicht vorrendern, und die waren bisher **stumm**. Ab 0.9.0 kann das
Betriebssystem sie vorlesen: eine andere, robotische Stimme, aber eine.

Die Regel ist bewusst eng: Zeilen **mit** Aufnahme werden nie ersetzt. Vorgelesen wird nur, wenn
die Gesprächigkeit ohnehin auf „normal" oder „viel" steht, und **nicht**, solange Blizzards eigene
Kampf-Audiohinweise oder die Bildschirm-Narration laufen — drei Stimmen gleichzeitig sind nicht
dreimal so hilfreich. Eine Warnung drängt sich vor und wirft die Warteschlange weg.

**Standard ist aus.** Die Stimmen kommen vom Betriebssystem (Windows SAPI, macOS); unter
Linux/Wine gibt es meist keine, und dann ist das Vorlesen einfach still. Ein Feature, das auf dem
Entwicklungsrechner nicht läuft, darf nicht der Default sein. Die Stimmen-Auswahl erscheint in den
Einstellungen nur, wenn der Client mindestens eine Stimme meldet.

Einstellungen: **Zeilen ohne Stimme vorlesen** (aus / nur Zeilen ohne Sprachdatei / immer) und
**Vorlese-Stimme** (automatisch oder eine bestimmte).

### Kleinigkeiten

- Weltfeste hängen nicht mehr an „ist das Retail?", sondern am Spielinhalt. **Mists of Pandaria
  Classic bekommt jetzt Braufest und Pilgerfreuden**, die es dort wirklich gibt.
- Der Lagerfeuer-Sinn liest den Zaubernamen jetzt auch über `C_Spell.GetSpellInfo`. Auf
  Retail/Forever hätte er sich sonst auf die eingebaute Namensliste verlassen — und auf einer
  französischen Oberfläche gar nichts gefunden.
- Der Reagenzien-Hinweis für Magier und der Munitions-Hinweis für Jäger kommen nur noch auf
  Clients, die beides kennen (Vanilla, TBC). Seit Cataclysm gibt es weder Teleport-Reagenzien noch
  einen Munitionsplatz — der Hinweis wäre dort nicht nutzlos, sondern falsch.
- Die Adds-Wache fragt fremde Einheiten jetzt in `pcall` ab. Sie läuft aus einem Timer, und dort
  gibt es kein Schutznetz.

### Bekannte Lücken

- **Ob `UNIT_COMBAT` auf Retail/Forever lesbare Schadenszahlen liefert, weiß niemand**, auch die
  Doku nicht. Sind sie „secret", zählt das Bestiarium dort nur noch Begegnungen und Tode — ohne
  Fehlermeldung, nur mit weniger Inhalt. Das ist der erste Punkt auf der Prüfliste.
- Die Forever-Interface-Nummer `16001` ist die **Beta**-Nummer vom 17.09.2026. Die TOC trägt
  deshalb noch **keine** `## Interface-Camelot:`-Zeile — ein falsches Version-Tag ist schlimmer
  als ein fehlendes. Bis dahin lädt Forever die Rückfall-TOC (mit „veraltet"-Hinweis, aber sie
  lädt), und die Erkennung greift zur Laufzeit.
- `C_CombatAudioAlert.SpeakText` wäre auf Retail der bessere Vorlese-Weg als
  `C_VoiceChat.SpeakText`. Ohne einen Retail-Client lässt sich das nicht abhören — Welle 4.


## 0.8.0 (2026-09-17)

### Welle 3 — Lyra arbeitet mit deinen Addons zusammen, indem sie weniger sagt

Die meistgenutzten Addons machen ihre Sache gut. Details rechnet besser als Lyra, Questie zeigt
besser, DBM ist schneller, GTFO ist lauter, Omen misst genauer. Was keines davon hat, ist ein
**Gedächtnis mit einer Meinung**. Genau dort setzt diese Welle an — und an der Stelle, an der
Lyra bisher im Weg stand.

**Die wichtigste Neuerung ist eine Regel, kein Feature: wenn DBM oder BigWigs spricht, spricht
Lyra nicht.** DBM hat eigene Countdown-Stimmen und zählt die letzten Sekunden jedes Timers vor.
Eine zweite Stimme auf derselben Sekunde ist nicht doppelt so hilfreich, sondern gar nicht.
Ab jetzt schweigt Lyra, während ein DBM-Ton läuft, während ein Timer unter zehn Sekunden steht,
während BigWigs vorzählt und während ein Boss-Encounter läuft — Letzteres auch **ohne** DBM und
BigWigs, über Blizzards eigene Encounter-Ereignisse.

**Warnungen laufen weiter durch.** Der Riegel bremst ausschließlich Geplauder; eine HP20-Warnung
im Bosskampf kommt an. Auf Hardcore wäre alles andere ein Fehler mit Konsequenz. Deshalb hat die
Regel auch keinen Schalter: sie kann Lyra nur leiser machen, nie lauter.

| | |
|---|---|
| **Neu** | `Sinne/DBM.lua` — Stillhalte-Regel + Boss-Chronik (je Boss Versuche, Kills, Wipes, beste Zeit), `/lyra bosse` |
| **Neu** | `Sinne/Details.lua` — ein Satz nach langen Kämpfen aus **eigenen** Zahlen, `/lyra details` |
| **Neu** | `Sinne/Bedrohung.lua` — „du ziehst Aggro, obwohl da ein Tank steht" (nativ, ohne Omen) |
| **Neu** | `Sinne/Questie2.lua` — Zielzone und Queststufe beim Annehmen, Questkette beim Abgeben, `/lyra woran` |
| **Neu** | `Sinne/Persoenlichkeit.lua` — Klasse, Rasse, Stufe, echte Uhrzeit, Lieblingszone, die Frage von vorhin |
| **Neu** | `docs/welle3-audit.md`, `Sinne/WELLE3.md`, `docs/phrasen-w3.json` (13 Ereignisse, 18 Zeilen an bestehenden IDs) |
| **Geändert** | `Sinne/Bruecken.lua`, `Sinne/Bruecken2.lua`: je eine Zeile `-- WELLE3:` — die alten Details- und Threat-Blöcke treten zurück |
| **Geändert** | `Core/Init.lua` (Version, fünf Schlüssel), `UI/Settings.lua` (drei Kästchen), `UI/Slash.lua`, Locales, `Sinne/Extra.lua`, TOC |
| **Geändert** | `docs/phrasen.json` — die 13 Ereignisse und 18 Zeilen sind **gemerged**: **105 Ereignisse**, `phrasen.lua` neu erzeugt |
| **Umbenannt** | Texturordner `gestalt/` → **`bilder/`** (siehe unten), alle Pfade in Lua, Werkzeugen und Doku nachgezogen |

**Der Texturordner heißt jetzt `bilder/`.** Bis 0.7.0 lagen die Bilder in `gestalt/` und der Code
in `Gestalt/`. Windows und macOS unterscheiden in ihren Standardeinstellungen keine Groß- und
Kleinschreibung in Dateinamen: beim **Entpacken** des Zips verschmelzen die beiden Ordner zu einem,
und welcher Name gewinnt, entscheidet die Reihenfolge im Archiv. Das ist ein Fehler, der vor dem
ersten Login passiert, nur bei anderen Leuten und nur auf zwei von drei Betriebssystemen — also
genau die Sorte, die man nicht findet, sondern verhindert. Code in `Gestalt/`, Bilder in `bilder/`.

**`{klasse}` und `{rasse}` sprechen jetzt Lyras Sprache, nicht die des Clients.** Wer einen
deutschen Client hat und Lyra auf Englisch stellt, las „There's my Magierin." — in sechs Zeilen,
darunter die allererste nach dem Einloggen. Zwei kleine Tabellen (9 Klassen, 8 Rassen, Schlüssel
ist das sprachunabhängige Token aus `UnitClass`/`UnitRace`) übersetzen jetzt; passen Client- und
Lyra-Sprache zusammen, gewinnt weiter der Client-Name, weil er immer richtig gebeugt ist.

**Lyra nennt eine Zahl nur, wenn sie aus deiner eigenen Geschichte kommt.** Nicht „du machst 143
Schaden pro Sekunde" — das steht ohnehin auf dem Bildschirm —, sondern „dreißig Prozent über
deinem Schnitt", „du hast mehr eingesteckt als sonst", „der schon wieder, drittes Mal". Und beim
allerersten Kill eines Bosses einen Satz, den niemand sonst sagt.

**Aus Details wird ausschließlich dein eigener Wert gelesen**, dazu die namenlose Gruppensumme
für einen Prozentsatz. Es wird nie über die Akteursliste gelaufen, nie ein fremder Akteur geholt,
nie ein Spielername gespeichert oder ausgegeben. Dass „da ein Tank steht", stellt Lyra ohne
jeden Namen fest. Im Trockentest wird jeder einzelne Details-Zugriff mitgeschrieben und
gegengeprüft.

**Persönlicher heißt: sechs neue Platzhalter, nicht sechzig neue Ereignisse.** `{klasse}`,
`{rasse}`, `{stufe}`, `{uhr}`, `{heimat}` und `{frage}` hängen ab jetzt an *jeder* bestehenden
Zeile — derselbe Weg, den `{erinnerung}` in Welle 1 gegangen ist. Dazu: **Vertrautheit wächst
auch durch Interaktion.** Bisher zählte nur Spielzeit; ein Klick zählt jetzt wie eine Minute,
eine Frage wie fünf, gedeckelt bei 20 Stunden. `/lyra stimmung` zeigt weiter die echten Stunden —
gelogen wird nicht, die Stufe kommt nur früher.

**Kein `Sinne/Omen.lua`, und das mit Absicht.** Omen hat keine Schnittstelle: seine
Bedrohungsdaten sind file-local. Andocken ginge nur über seine Balken-Frames und bräche beim
nächsten Layout-Wechsel still. Die native API kann Era — Omen selbst benutzt sie ungeguarded.
Also `Sinne/Bedrohung.lua`, nativ. Eine Datei nach einem Addon zu benennen, das sie bewusst
nicht anfasst, wäre eine Lüge im Dateinamen.

**DBM und BigWigs sind auf diesem Rechner nicht installiert.** Alle Callback-Namen und
Argument-Positionen stammen belegt aus GitHub und aus Attrappen im Trockentest (153 Prüfungen,
14 Szenen, 0 FAIL). Im Spiel ungeprüft — die Prüfliste steht in `Sinne/WELLE3.md`.

## 0.7.0 (2026-09-17)

### Lyra erzählt aus deiner eigenen Chronik

Bisher sagte Lyra 92 Ereignisse lang, was jemand von Hand für *alle* geschrieben hat: „Hier warst du
schon mal. Ich erinnere mich, auch wenn du es nicht tust." Neu ist ein optionales Datenpaket
**`Lyra_Gestalt_Persoenlich`**, das Sätze aus der **eigenen** Chronik enthält — mit der Stadt, der
Zahl der Besuche, der Stufe, der Länge der letzten Sitzungen. Lyra mischt sie unter die eingebauten
Zeilen, etwa in jedem dritten Fall.

Das ist Block **W1-H/W1-I** aus `docs/redakteur-konzept.md` — die 12-bis-16-Stunden-Fassung aus dem
Anhang, also **ohne** Server, ohne Sprachmodell, ohne Brücke, ohne Netzcode. Der Sinn ist die eine
Frage, die man vor 150 weiteren Stunden beantworten will: *fühlt sich das gut an?*

| | |
|---|---|
| **Neu** | `addon/Lyra_Gestalt_Persoenlich/` (TOC, `persoenlich.lua` mit 29 handgeschriebenen Zeilen, README de/en) |
| **Neu** | `Sinne/Persoenlich.lua` — prüft das Paket, mischt die Zeilen ein, `/lyra persoenlich` |
| **Neu** | `tools/persoenlich-vorlage.py` — erzeugt dasselbe Paket ohne Modell aus SavedVariables |
| **Neu** | `Sinne/PERSOENLICH.md` — Format, Regeln, Regie-Patch, Prüfpunkte |
| **Geändert** | `Core/Regie.lua`: drei Zeilen in `waehle()`, markiert `-- PERSOENLICH:` |
| **Geändert** | `UI/Slash.lua`: `/lyra persoenlich`; Locales: 11 Schlüssel `Personal …` |

**Ohne das Paket ändert sich nichts.** Kein Wrapper, keine Fehlermeldung, dieselbe Auswahl wie in
0.6.2 — im Harness mit 200 Läufen gegengeprüft. Das Paket wird **nicht** mit dem Addon ausgeliefert:
es entsteht auf dem eigenen Rechner, aus der eigenen Chronik.

**Persönliche Zeilen sprechen nicht.** Sie haben kein vorgerendertes OGG und bekommen keins. Daraus
folgt die harte Regel: **nur `plauder`- und `still`-Ereignisse, nie eine Warnung.** Eine
HP20-Warnung muss sprechen; ein Zonengruß darf lesen. Der Loader verwirft jede Zeile für ein
`warn`-Ereignis, mit Grund, sichtbar in `/lyra persoenlich`. Die Sprechblase erscheint trotzdem —
auch bei abgeschalteten Untertiteln, weil keine Stimme gespielt wurde.

**Was der Loader sonst verwirft:** mehr als 120 Zeichen, `|c`-Farbcodes und andere
`|`-Escapes, Steuerzeichen, `{platzhalter}`, URLs, unbekannte Ereignisse, Zeilen eines anderen
Charakters, mehr als 200 Einträge. Ein Paket mit fremdem `charKey` oder fremdem Schema wird
**ignoriert, nicht gelöscht** — es gilt wieder, sobald der passende Charakter spielt.

**Datenschutz, unverändert streng:** Das Addon hat keinen Netzcode und bekommt keinen. Im Paket
stehen nur eigene Daten. Der Charaktername steht genau einmal, im Feld `charKey`, dient nur der
Zuordnung und wird nie ausgegeben — in den Sätzen selbst kommt kein Name vor, kein fremder und
nicht der eigene.

**Installationshinweis:** Ein **neu angelegter Addon-Ordner** ist erst nach einem **Neustart des
Clients** in der Addon-Liste. `/reload` genügt nicht. Wird später nur der Inhalt von
`persoenlich.lua` geändert, reicht `/reload`.

## 0.6.2 (2026-09-17)

### Design v3, Teil A — Lyras Bild, die Sprechblase und wie eine Warnung aussieht

**Im Portrait ist jetzt wirklich ein Gesicht.** Bisher schnitt das Addon zur Laufzeit einen
Kopfausschnitt aus einem großen Bild — mit einer Maske, einem Ersatzweg für den Fall, dass die
Maske streikt, einem Notschalter dafür und einem Selbsttest obendrauf. Und mit **einem festen
Ausschnitt für alle 29 Mienen**, der bei sieben davon danebenlag: bei „besiegt" (das Gesicht, das
sie im Tod zeigt) und bei „niedergeschlagen" sah man fast nichts als einen leeren Ring.

Stattdessen liegen jetzt 29 fertige runde Bilder im Addon, jedes mit dem Ausschnitt, der zu dieser
Miene passt. Das Addon setzt eines davon — mehr passiert nicht. Maske, Ersatzweg, Notschalter,
Selbsttest und die Rechnerei drumherum sind ersatzlos weg; `/lyra maske` sagt künftig nur noch,
dass es das nicht mehr gibt.

**Lyra ist größer.** Das Portrait hängt nicht mehr an der Größe der ganzen Figur, sondern hat eigene
Werte: **96 / 112 / 128** Pixel statt 67 / 96 / 134, Standard 112. Bei kleinem UI-Maßstab waren
96 Einheiten ein Icon, kein Gesicht — bei 29 Mienen der falsche Handel. `/lyra groesse <Zahl>`
wirkt unverändert auf beides.

**Eine Warnung sieht man jetzt auch aus dem Augenwinkel.** Bisher wechselte nur die Ringfarbe von
Violett auf Orange. Nachgerechnet hat dieser Wechsel einen Kontrast von **1,01 : 1** — im
Graustufenbild ist er *exakt nicht vorhanden*, und im Augenwinkel, wofür er gedacht war, auch nicht.
Ab jetzt trägt die Form:

| Stufe | Was passiert |
|---|---|
| Hinweis | ein **Symbol** links in der Sprechblase |
| Warnung | dazu ein **Schein** um das Portrait, ruhig |
| Alarm | der Schein **pulst**, der Ring wird **doppelt so dick** |

Farbe kommt weiterhin dazu — sie ist nur nicht mehr das Einzige. Wer Bewegung abgeschaltet hat,
bekommt den Schein trotzdem, nur ohne Pulsieren: er ist die Warnung, nicht die Verzierung.

**Das „!" vor Warnzeilen ist ein Symbol geworden.** Es fraß zwei Zeichen Breite, rutschte beim
Zeilenumbruch mit und stand im Untertitel doppelt. Jetzt steht ein Icon fest links neben dem Text.
In der **Untertitel-Leiste für Streams bleibt das „!" als Text** — eine Aufnahme zeigt nur, was im
Bild steht, und ein Symbol aus einer Schriftart, die Blizzard nicht mitliefert, wäre dort ein leeres
Kästchen. Nebenbei behoben: eine Alarmzeile ohne die interne Markierung „Warnung" bekam bisher
**gar kein** Zeichen — und auch keinen Bildschirmpuls. Beides hängt jetzt an der Stufe.

**Die Sprechblase ist breiter, dichter und steht richtig.** Sie hat einen eigenen Rahmen statt einer
Blizzard-Textur, die in Classic von keinem einzigen anderen Addon benutzt wird; sie ist voll
deckend statt zu 97 %; sie ist von 44 auf rund 56 Zeichen je Zeile gewachsen (unter 45 Zeichen wird
Lesen anstrengend); und im Portrait steht sie **immer seitlich** neben dem Kreis statt darüber, mit
dem Zipfel auf Augenhöhe.

**Kleinigkeiten:** Fährt die Maus von Lyra weg, hört die Hover-Miene sofort auf, statt zwei Sekunden
nachzulaufen. Neue Spieler finden Lyra ab jetzt **links auf halber Höhe** — unten rechts lag sie bei
den meisten Aufbauten mitten in den Tastenleisten. Wer sie schon verschoben hat, behält seinen
Platz.

Belege, Messungen und die offenen Punkte für den Spieltest: `docs/design-v3-A-umsetzung.md`.
Was davon noch in anderen Fenstern nachzuziehen ist: `docs/design-v3-A-patches.md`.

### Design v3, Teil B — Schrift, Menü, Einstellungen, der erste Eindruck

**Die Schrift ist jetzt auf jedem Bildschirm gleich groß.** Bisher stand in den Einstellungen eine
Zahl, und was daraus auf dem Monitor wurde, entschied der UI-Maßstab des Clients: dieselbe „16" war
je nach Einstellung **10 oder 30 Bildschirm-Pixel**. Neu ist „Schriftgröße **automatisch**"
(Standard) — Lyra rechnet aus, wie groß ein Buchstabe *wirklich* werden soll, und stellt die Zahl
danach ein. Zieht man am UI-Regler, ziehen Sprechblase, Gespräch, Menü und Tooltip sofort mit. Der
Schieberegler bleibt und übersteuert jederzeit; `/lyra schrift auto` schaltet zurück.
Wer schon eine eigene Größe eingestellt hat, behält sie.

**Die Einstellungen haben oben 13 Einträge statt 33.** Alles, was man einmal einstellt und dann nie
wieder anfasst — Tonkanal, Blasendauer, Kampf-Transparenz, die Schalter für Fotos, Ultra, Streamer,
Erbe, Self-Found, Karten-Pins — ist in eine eigene Unterseite **„Feineinstellung"** gewandert. Oben
stehen nur noch die Entscheidungen, die man tatsächlich trifft. Der Bildschirm-Puls bleibt bewusst
oben: er ist der Schalter für Lichtempfindlichkeit, und der gehört nicht zwei Klicks tief.

**Neu: Bewegung.** Drei Stufen statt an/aus.

| | Was passiert |
|---|---|
| **Voll** | wie bisher: Atmen, Nicken, der kurze Ruck bei einer Warnung |
| **Reduziert** | Lyra steht ruhig; Warnungen rucken weiterhin, der Warnschein leuchtet, pulst aber nicht |
| **Aus** | gar keine Bewegung, harte Mienenwechsel, keine Regungen im Leerlauf |

Für Bewegungsempfindlichkeit — und für Aufnahmen, in denen nichts im Hintergrund zappeln soll.

**Eine Warnung, die ein stummer Dialogkanal nicht mehr verschluckt.** Lyra spricht standardmäßig auf
Blizzards Dialog-Kanal. Wer den auf null zieht (viele tun das wegen des Questgeber-Gebrabbels), hatte
damit unbemerkt auch den hörbaren Teil der **Todeswarnung** abgeschaltet. Alarme — unter 20 % Leben,
Ertrinken, Sturz — laufen ab jetzt immer auf „Master". Alles andere bleibt auf dem eingestellten
Kanal, und wer die Stimme ganz ausschaltet, schaltet sie weiter ganz aus.

**Menü und Gespräch blenden weich ein** (achtzig Millisekunden, nur Deckkraft — nichts wird größer
oder springt), stehen auf demselben Rand wie die Sprechblase, und unten steht endlich die Zeile, die
sagt, dass die **Zifferntasten** funktionieren: „1–9 · Esc schließt". Im Kampf ist sie blass, denn
dort greifen sie nicht. Der Menü-Titel ist deutlich heller (der einzige Text im ganzen Addon, der
knapp unter der Lesbarkeitsgrenze lag), und das kleine Gesicht im Menü- und Gesprächskopf zeigt
jetzt **dasselbe Bild wie Lyra selbst** — auch bei den Mienen, bei denen dort bisher ein fast leerer
Kreis stand.

**Lyras Fenster klappen nicht mehr in den Quest-Tracker.** Menü und Gespräch prüfen jetzt, ob an der
Stelle, wo sie aufgehen wollen, schon etwas steht — Questie, Minimap, Chat, Details — und weichen
auf die andere Seite aus. `/lyra position vorschlag` sucht Lyra selbst einen freien Platz.

**Wer Lyra schon länger hat, erfährt endlich vom Einrichtungs-Assistenten.** Es gibt ihn seit 0.3.0,
aber er lief nur bei einer frischen Installation — wer von 0.2 kommt, hat ihn nie gesehen. Beim
ersten Login nach diesem Update kommt jetzt **eine einzige Zeile** in der Sprechblase: „Ich kann mir
zeigen lassen, wie du mich haben willst — `/lyra einrichten`." Dazu blinkt der Minimap-Knopf dreimal.
Kein Popup, keine zweite Nachfrage, kein Zähler. Wer sie ignoriert, hat sie ignoriert.

**Der Assistent selbst stellt drei Fragen statt vier.** Die Frage nach der Ansicht ist raus: sie war
der kürzeste Weg von „frisch installiert" zu einer Darstellung, die dieser Bildersatz nicht
auslieferbar macht. Das Porträt bleibt die Voreinstellung; die ganze Figur gibt es weiterhin per
Doppelklick, über das Menü und über `/lyra figur`. Und der letzte Satz nennt jetzt den Ausschalter
(`/lyra still`) — der gehört in die erste Minute, nicht in die FAQ.

**Kleinigkeiten:** Der Minimap-Knopf füllt seinen Rahmen aus (20 statt 18 Pixel). „Position
zurücksetzen" schiebt Lyra nicht mehr in die Ecke unten rechts, sondern an den neuen Standardplatz.
`/lyra maske` sagt, dass es die Maske nicht mehr gibt, statt still nichts zu tun. Zwei Farbtabellen
und zwei Rahmen-Rezepte, die getrennt gepflegt werden mussten, sind auf je eines zusammengefallen.

Gemessen mit **265 Prüfungen** (vorher 93), darunter die Schrift-Automatik bei fünf UI-Maßstäben,
das Panel mit und ohne Unterseiten-Unterstützung, die Einladung genau einmal und der Alarm auf dem
richtigen Tonkanal. Einzelheiten: `docs/design-v3-B-umsetzung.md`, offene Übergaben:
`docs/design-v3-B-patches.md`.

### Integration — die beiden Hälften zusammengesetzt, und Lyra spricht im Gespräch

Team A und Team B haben parallel gebaut. Was jeweils in den Dateien des anderen lag, lag danach als
Anweisung daneben. Diese Runde hat es eingebaut, geprüft und zusammengeführt.

**Lyra redet jetzt auch, wenn du sie ansprichst.** Sie sprach jede Warnung, aber kein einziges Wort
im Gespräch, das du selbst geöffnet hast — Dialogtexte liefen an der Stimme vorbei. Ab jetzt sind
sie vertont: die Knoten des Gesprächsbaums, die Antworten auf Freitext (`/lyra danke`) und die drei
„das verstehe ich nicht"-Zeilen. Wechselst du schnell durch die Knoten, bricht die alte Zeile ab,
statt sich mit der neuen zu überlagern. **Eine Warnung bricht nie ab** und wird auch nie
unterbrochen — sie behält Vorfahrt in beide Richtungen. Zeilen mit eingesetzten Werten („Du stehst
in *Westfall*") bleiben stumm; sie lassen sich nicht vorab aufnehmen. Fehlt eine Aufnahme, ist es
still — das Fenster kommt immer.

**Die Untertitel-Leiste gehört nicht mehr dem Streamer-Modus.** Bisher schaltete ein Schalter die
grüne Kachel, die Leiste, die Anrede und den Bildschirmrand-Puls gemeinsam um: wer nur Untertitel
wollte, musste die grüne Kachel mitnehmen. Jetzt gibt es dafür eine eigene Einstellung
(**aus / automatisch / immer**, Standard automatisch). „Automatisch" heißt: die Leiste kommt, wenn
der Streamer-Modus läuft, wenn Lyra ausgeblendet ist — dann gibt es keine Sprechblase, und jede
gesprochene Zeile muss trotzdem lesbar sein — oder wenn die Schrift sehr klein ausfällt. Dazu ist
sie **breiter** (60 % des Bildschirms statt fester 900 Pixel; auf einem 3440er war das ein Streifen)
und ihre **Schrift folgt der Einstellung** statt fest zu sein.

**Die grüne Kachel ist rund, wenn Lyra rund ist.** Ein Quadrat um einen Kreis lässt die Ecken grün
stehen und frisst die weiche Ringkante weg. In der Ganzfigur bleibt sie quadratisch.

**Der Bildschirmrand-Puls greift nie wieder nach Blizzards Warnbild.** Konnte ein Client keinen
Farbverlauf zeichnen, nahm das Addon ersatzweise genau die Vollbild-Textur, die der Client bei unter
20 % Leben selbst einblendet — bei einem Alarm lagen dann zwei identische Bilder übereinander, und
„das Spiel warnt" ließ sich von „Lyra warnt" nicht mehr trennen. Der Ersatzweg ist ersetzt: vier
einfarbige Bänder mit harter Kante, schmaler und blasser als der Verlauf. Gröber, aber die **Form**
unterscheidet — vier Kanten sind keine Vignette.

**Die Sprechblase weicht demselben aus wie Menü und Gespräch.** Steht links *und* rechts etwas im
Weg (Questie-Tracker, Chatfenster), geht sie nach oben; ist auch das zu, legt sie sich darüber statt
darunter zu verschwinden.

**Der Tooltip auf Lyra folgt deiner Schriftgröße** und seine Hinweiszeilen sind etwas heller
(Kontrast 8,97 : 1 → 10,41 : 1).

**Eine Einstellung wird einmalig angefasst:** wer noch die alte Standard-Schriftgröße 16 gespeichert
hat, bekommt die neue Automatik. Sie war nie bewusst gewählt — sie *war* der Standard. Jeder andere
Wert bleibt, und es passiert genau einmal; stellst du danach wieder 16 ein, bleibt sie.

Gemessen mit **351 Prüfungen** (vorher 265) plus sieben weiteren Prüfständen, alle ohne Fehler.
Neu ist `tools/qa-dialogstimme.py`: es hält den Stimm-Katalog und die Dialogdaten zusammen — beim
ersten Lauf fand es drei Einträge, die noch die Texte des alten vierteiligen Einrichtungsassistenten
sprachen. Einzelheiten: `docs/review7-2026-09-17.md`.

## 0.6.1 (2026-09-17)

### Fix-Runde 5 — Rechtsklick & neue Klick-Belegung

**Der Rechtsklick auf Lyra tut wieder etwas.** In 0.6.0 tat er gar nichts — kein Menü, keine
Meldung, nichts. Ursache war eine einzige vertauschte Reihenfolge im neuen Menü: die Beschriftungen
bekamen ihren Text, *bevor* sie eine Schrift hatten. Der Client bricht das mit einem harten Fehler
ab („FontString:SetText(): Font not set"), und zwar mitten im Aufbau des Menüs — es wurde also nie
sichtbar. Der Fehler steht 18-mal in Haralds Fehlerprotokoll, jedes Mal mit demselben Weg:
Rechtsklick auf die Gestalt → Menü. Jetzt läuft jeder Text durch eine Stelle, die immer erst die
Schrift setzt, und diese Schrift hat zusätzlich ein Netz aus zwei Rückfällen.

**Und weil der Rechtsklick sowieso auf den Tisch musste, ist die ganze Belegung neu:**

| Auf Lyra | bis 0.6.0 | ab 0.6.1 |
|---|---|---|
| Links | Spruch | Spruch (unverändert) |
| Doppelklick links | Einstellungen | **Portrait ⇄ ganze Figur** |
| Rechts | Menü | **Gespräch** — mit einem Ungeheuer im Ziel fängt sie gleich damit an, was sie darüber weiß |
| Shift+Rechts | – | **Menü** |
| Mitte | – | **Still-Modus an/aus** |
| Mausrad | – | **Größe: klein ⇄ mittel ⇄ groß** |

Reden ist die Sache, die man an ihr anklickt — bis 0.6.0 lag das Gespräch zwei Klicks tief. Das
Menü ist Verwaltung und rückt dahin, wo Verwaltung hingehört: **Rechtsklick auf den Minimap-Knopf**
öffnet es jetzt (vorher sprang er direkt in die Einstellungen; die stehen als letzter Menüeintrag
weiter drin), dazu Shift+Rechtsklick auf Lyra und `/lyra menue`. Das Menü erscheint wieder **am
Mauszeiger** — seit es auch vom Minimap-Knopf kommt, wäre „neben Lyra" der falsche Ort.

Alles davon sind eigene, nicht geschützte Fenster und funktioniert deshalb **auch im Kampf**.

Geprüft mit 93 neuen Prüfungen, die zum ersten Mal *nicht* die Handler direkt aufrufen, sondern
einen echten Mausklick auf eine Bildschirmkoordinate schicken — mit Frame-Ebenen, Größen und
Trefferprüfung. Gegen den alten Stand gehalten, reißt derselbe Prüfstand den Fehler wieder auf.
Einzelheiten und Belege: `docs/fix5-2026-09-17.md`.

## 0.6.0 (2026-09-17)

### Fix-Runde 4 — Bewegung & Portrait

**Sie schwebt nicht mehr davon.** Das war der hartnäckigste Fehler des Projekts, und die dritte
Runde hatte an der falschen Stelle repariert. Der Befund aus Haralds Screenshot: der Rahmen stand
richtig — Tooltip und Mausfeld saßen an der gespeicherten Stelle —, nur ihr *Bild* war rund 170 px
darüber gerutscht. Ein Translation-Versatz, der mitten im Lauf abgebrochen wird, bleibt als reiner
Zeichnungs-Versatz stehen: kein Neu-Verankern nimmt ihn weg, keine Messung sieht ihn. Und weil
Atmen wie Nicken erst nach oben gingen, war jeder Rest ein Stück nach oben und nie nach unten.

Deshalb bewegt sie sich jetzt gar nicht mehr über Animationen, sondern so, wie Blizzard es selbst
macht, wenn die echte Position stimmen muss: ihre Position wird sechsmal pro Sekunde **neu
gesetzt**, nie fortgeschrieben. Ein Wert, der jedes Mal frisch berechnet wird, kann sich nicht
aufschaukeln — und Bild und Mausfeld können nicht mehr auseinanderlaufen.

- **Ihr Gesicht ist im Portrait wieder da.** Der runde Ausschnitt entsteht jetzt über die Geometrie
  statt über einen Teilausschnitt der Textur — dieselbe Bauweise, die Blizzard für seine eigenen
  runden Portraits benutzt.
- **Das Hüpfen beim Sprechen ist ruhiger.** In der ganzen Figur nickt sie 1 px in 1,2 Sekunden
  (vorher 2 px in 0,35 Sekunden). Im Portrait bewegt sich das Bild **gar nicht** mehr — ein
  daumengroßer Kopf, der wippt, sieht nach Zittern aus. Stattdessen wird ihr Ring beim Sprechen
  langsam heller und dunkler.
- **Warnungen im Portrait:** kurzes Aufleuchten des Rings und ein kleiner Ruck von 2 px, statt des
  großen Rucks aus der Figur-Ansicht.
- **Neu: `/lyra maske aus`** — falls im Portrait doch einmal kein Gesicht erscheint, zeigt sie sich
  damit sofort quadratisch im Ring. Beim Start prüft sie außerdem selbst, ob Gesicht und Maske
  geladen haben, und sagt es, statt still einen leeren Ring zu zeigen.
- **Neu: `/lyra drift reset`** stellt ihre Bewegungsebene hart auf Null; `/lyra drift` zeigt jetzt
  auch Bewegungszustand und Selbsttest.
- Der Drift-Wächter misst wieder **immer** (bis 0.5.1 wartete er darauf, dass keine Animation läuft
  — das Atmen lief aber dauernd, also griff er nie).

Geprüft mit 31 neuen Prüfungen unter vier verschiedenen Annahmen darüber, wie der Client
abgebrochene Animationen behandelt — unter jeder einzelnen steht sie nach 300 Sprechblasen,
50 Rucken, 20 Ansichtswechseln und 10 Layouts wieder exakt auf ihrem Platz. Einzelheiten und
Belege: `docs/fix4-2026-09-17.md`.

## 0.5.0 (2026-09-17) — Lebensecht, Welle 1

**Lyra sagt nicht mehr, sondern passenderes.** Fast alles hier verändert die *Auswahl* vorhandener
Zeilen, nicht die Redemenge.

- **Sie hat eine Laune — und sie ist immer erklärbar.** Beinahe-Tod, zu viele Kämpfe hintereinander,
  ein Gedenktag: dann ist sie *besorgt*, ihr Gesicht zeigt es, und sie redet weniger. Nach einem
  Levelaufstieg oder im Gasthaus ist sie *gut gelaunt*. Nie gewürfelt. `/lyra stimmung` schreibt
  den Grund in den Chat.
- **Sie kennt dich länger, je länger du spielst.** Vier Stufen (0 / 10 / 50 / 100 Stunden,
  **account-weit**, AFK zählt nicht mit). Ab Stufe 1 erinnert sie sich an früher („letzte Woche in
  Westfall, als es knapp wurde"), ab Stufe 2 wird sie persönlich. Gezählt wird selbst — nie über
  `RequestTimePlayed()`, das würde dir in den Chat schreiben.
- **Sie weiß, wie spät es ist.** Andere Begrüßung morgens, abends und um zwei Uhr nachts.
- **Kleine Rituale:** Verabschiedung bei `/camp`, eine Zeile nach ≥ 5 Minuten AFK, die späte Stunde,
  Jahrestag der Erstsichtung, Gedenktag eines gefallenen Vorgängers, In-Game-Feste
  (Winterhauch, Schlotternächte, Liebe liegt in der Luft, Sonnenwende), Antwort auf dein eigenes
  Emote (nur ohne Ziel, höchstens dreimal je Sitzung) und das Lagerfeuer.
- **Neue Fragen im Gespräch:** „wie spät ist es", „wie lange kennen wir uns", „erinnerst du dich",
  „wie ist deine Laune".
- **Neue Befehle:** `/lyra stimmung`, `/lyra ssf` (Solo Self-Found — dann erwähnt sie Handel,
  Auktionshaus und Post nicht mehr). Der Schalter steht auch im Einstellungen-Panel.
- **Grenzen bleiben:** kein Chat, keine Automation, keine Daten anderer Spieler. Fremde Emotes
  fallen an der GUID-Prüfung durch, es wird nie ein Spielername gespeichert.

**Warnungen bleiben unantastbar.** Die neue Gesprächigkeits-Regelung berührt nur das Plaudern.
Eine besorgte Lyra verschluckt keine HP20-Warnung — auch nicht in den fünf Minuten Stille nach
einem Gedenksatz (Review 5).

## 0.4.0 (2026-09-17) — Brücken zu anderen Addons

**Neu: Lyra arbeitet mit deinen anderen Addons zusammen.** Keines davon ist Voraussetzung — fehlt
eines, bleibt sie an dieser Stelle einfach still, und `/lyra status` sagt ehrlich „fehlt".

- **TomTom**: `/lyra punkt [Titel]` merkt sich die Stelle, an der du stehst — als Wegpunkt *und*
  als Notiz in der Chronik. `/lyra punkte` listet sie, `/lyra punkte <n>` setzt den Pfeil auf
  Nummer n. Geht auch im Freitext: „merk dir die Stelle Erzader", „mark this spot".
- **Questie**: `/lyra such <Name>` findet einen Mob und setzt den Pfeil auf den nächstgelegenen
  Spawn — deine aktuelle Zone gewinnt immer. `/lyra quest <Titel>` findet den Questgeber.
  Hat dich der Gesuchte schon einmal erwischt, sagt sie es dazu (`MOB_RIVALE_WARNUNG`).
  Freitext: „wo ist Hogger", „wo bekomme ich …", „where is …".
- **!BugGrabber / BugSack**: Lua-Fehler sind für Lyra „wildgewordene Runen". Der erste kommt sofort,
  danach höchstens alle 10 Minuten mit Anzahl; `/lyra runen` zeigt die letzten drei.
- **DBM**: Boss-Pull, Kill, Wipe und eine **Enrage-Vorwarnung 20 s vorher**.
- **Bedrohung** (natives API, kein Omen nötig): Wer in der Gruppe Aggro zieht, hört es — genau
  einmal je Kampf. Solo nie.
- Neue Befehle: `/lyra punkt`, `/lyra punkte`, `/lyra such`, `/lyra quest`, `/lyra runen`,
  `/lyra status` zeigt die erkannten Partner-Addons.
- Grenzen bleiben: Lyra **zeigt und spricht**. Sie setzt einen Wegpunkt, weil du gefragt hast —
  sie bewegt nichts, drückt keine Taste und schreibt nie in den Chat.

**Die „direkt"-Regel.** Alles, was eine **Antwort auf deine Frage** ist, kommt sofort: kein
Plauder-Abstand, kein Stundenbudget, kein Still-Modus, und auch der 5-Sekunden-Riegel nach einem
Ladebildschirm hält sie nicht auf. Eine Ausnahme, bewusst: **nach deinem Tod schweigt Lyra
60 Sekunden** — egal, wer fragt. Nur die Frage nach deinen letzten Worten und ihre Bestätigung
kommen dort noch, und die laufen an der Regie vorbei.

**Fixes**

- **Die Namenssuche ruckelt nicht mehr.** Der Questie-Namensindex (rund 10 000 Einträge) wurde beim
  ersten `/lyra such` in einem Rutsch gebaut — genau in dem Moment, in dem du gefragt hast. Jetzt
  läuft er in Häppchen zu 500 Einträgen über mehrere Frames.
- **Login-Zeitplan entzerrt.** Nach dem Einloggen wollen bis zu fünf Zeilen heraus (Gruß, erster
  Login des Tages, gefallener Vorgänger, dessen letzte Worte, Rückblick auf die letzte Sitzung).
  Die festen Zeitpunkte passten nicht zum Redeabstand: „erster Login heute" lag 4 Sekunden neben den
  letzten Worten, wurde verschluckt und hatte als einzige keinen zweiten Versuch — die Zeile fiel
  still aus. Jetzt vergibt die Regie Slots, jede Zeile bekommt ihren eigenen Platz
  (6 s / 40 s / 74 s / 108 s / 142 s bei „Normal"). Dasselbe beim Betreten einer Instanz: der
  Reisecheck kommt jetzt sicher hinter der Instanz-Zeile.
- **Wegpunkt aus dem Gesprächsfenster** trug unter Umständen den Namen aus deiner *zuletzt*
  getippten Frage („/lyra wo ist Hogger" … später Klick auf „Punkt setzen" → Wegpunkt „Hogger").
  Die Umleitung, die das verursacht hat, ist ersatzlos entfallen.
- **Lyra verzieht beim Drübermausen nicht mehr das Gesicht, während sie spricht.** Die kleinen
  Regungen (Leerlauf, Maus drauf) weichen jetzt an einer einzigen Stelle allem aus: gehaltener
  Miene, stehender Sprechblase, offenem Gesprächsfenster und offenem Menü. Nur das Ziehen erschreckt
  sie weiterhin — das hast du ja selbst gemacht.
- **DBM-Enrage-Timer** wird unter beiden Rückruf-Namen registriert (`DBM_TimerStart` **und**
  `DBM_TimerBegin`), je nach DBM-Version. Die Vorwarnung kommt trotzdem nur einmal.
- Der Rückruf für die Fehlermeldungen kann nicht mehr still verschwinden (Eigner-Tabelle bleibt am
  Modul).
- Notiz-Koordinaten werden auf drei Nachkommastellen gerundet — gleich genau, deutlich kleinere
  gespeicherte Daten.
- `docs/design-v2.md` 5.3 an die Daten angeglichen: **10 / 10 / 3** Warnstufen statt 7 / 8 / 3.
  `HP50` bleibt ausdrücklich „nur Miene": kein Text, kein Ton, kein Puls.
- **WoW: Forever** (Interface 16xxx) wird als Retail-Codebasis erkannt; das Combat-Log bleibt dort
  wie auf Retail 12 ungenutzt.

Alle Befunde: `docs/review4-2026-09-17.md`.

## 0.3.1 (2026-09-17) — Fix-Runde 3: Schweben und Lesbarkeit
- **Lyra schwebt nicht mehr nach oben.** Nicken und Warn-Ruck lagen auf demselben Frame, und der
  Not-Aus setzte nur die Größe zurück, nie die Position: Wurde eine Verschiebe-Animation mitten in
  der Schleife abgebrochen — und das passiert am Ende jeder Sprechblase — blieb der erreichte
  Versatz stehen. Da beide Schleifen erst nach oben gehen, war der Rest immer nach oben gerichtet
  und summierte sich. Jetzt hat der Ruck eine eigene Ebene, der Not-Aus verankert alle Ebenen neu,
  und vor jedem Start wird erst angehalten und aufgeräumt.
- **Drift-Wächter**: prüft alle 5 Sekunden, ob eine Animationsebene von Lyra abgewandert ist
  (> 6 px, wenn nichts läuft), und setzt sie gegebenenfalls zurück — mit Meldung im Debug-Modus.
- **Gesprächsfenster ist jetzt dunkel** wie das Rechtsklick-Menü: Lyras Text hell, eine Stufe
  größer und **ohne den fetten Umriss**, der die Buchstaben zulaufen ließ. Antworten sitzen auf
  eigenen, voll deckenden Kacheln mit goldener Ziffer; unter der Maus wird die Kachel heller und
  der Text weiß. Hoher Kontrast: reines Schwarz/Weiß, unter der Maus invertiert.
- **Sprechblase** bleibt hell, aber dunklerer Text (#1A0F2E) und 96 % statt 92 % Deckung — das
  Spielbild scheint nicht mehr durch die Schrift.
- **Untertitel-Leiste** (Streamer) von 60 % auf 85 % Deckung: auf Schnee und vor Feuer war der
  Balken so hell geworden, dass weiße Schrift darauf unter dem Ziel-Kontrast lag.
- **Tooltip** an Lyra: Titel und Hinweiszeile deutlich heller.
- Alle Text-/Hintergrund-Kombinationen sind nach der WCAG-Formel nachgerechnet und liegen über
  7:1 — auch über hellem Spielbild. Tabelle in `docs/fix3-2026-09-17.md`.

## 0.3.0 (2026-09-17) — Design v2, Top 5
- **Portrait-Modus** (neuer Standard): Lyra zeigt nur noch Kopf und Schultern in einem runden
  Rahmen (96 px bei „Mittel"), Ring in Lyras Lila. Ganze Figur bleibt über
  Einstellungen, Rechtsklick-Menü oder `/lyra figur` erreichbar.
- **Größen-Presets** Klein/Mittel/Groß statt 27-stufigem Schieberegler; freie Werte weiter über
  `/lyra groesse <zahl>`.
- **Warn-Hierarchie in drei Stufen**: 1 Hinweis (nur Blase), 2 Warnung (roter Rand, Stimme, kurzer
  Ruck), 3 Alarm (zusätzlich Bildschirmrand-Puls). Alle 18 Warn-Ereignisse zugeordnet; eine leere
  Trankmeldung ruckt nicht mehr wie 12 % Leben.
- **Bildschirmrand-Puls ist jetzt violett** und selbst gezeichnet — vorher lag er pixelgleich auf
  Blizzards eigener Low-Health-Vignette. Atem-Alarm bleibt blau. Spitze 0,45 statt 0,6, Dauer 0,9 s
  statt 1,2 s, 4-Sekunden-Riegel zwischen zwei Pulsen (Lichtempfindlichkeit).
- **Sockel-Schatten** unter den Füßen (nur in der Ganzfigur) — sie schwebt nicht mehr.
- **Leerlauf-Mikrowechsel**: alle 45–90 s für 2,5 s eine andere Miene; Maus drüber → interessiert;
  Verschieben → erschrocken. Nie während eines Ereignisses, nie im Kampf.
- **Erst-Start-Assistent**: Beim allerersten Login fragt Lyra vier Fragen (Sprache, Anrede,
  Gesprächigkeit, Ansicht) im gewohnten Gesprächsfenster statt eines Popups; danach pulst der
  Minimap-Knopf dreimal. Wiederholbar mit `/lyra einrichten`.
- **Lesbarkeit der Sprechblase**: kein schwarzer Umriss mehr auf hellem Grund (nur noch im
  Kontrast-Modus), Zeilenabstand, Breite skaliert mit der Schriftgröße, Standzeit richtet sich nach
  der Textlänge (kurze Zeilen stehen kürzer im Weg, lange lange genug).
- **Einstellungs-Presets** Leise/Normal/Lebendig/Streamer ganz oben im Panel. Einzelschalter bleiben
  darunter; wer einen ändert, sieht „Eigene Einstellung" — zurückgesetzt wird nichts.
- Neue Slash-Befehle: `/lyra portrait|figur`, `/lyra klein|mittel|gross`,
  `/lyra preset leise|normal|lebendig|streamer`, `/lyra einrichten`.
- Der Warn-Ruck ist keine Scale-Animation mehr, sondern eine Verschiebung (Hausregel seit 0.2.1:
  keine Scale-Animationen).

## 0.2.0 (2026-09-16)
- Chronik: Zonen-Gedächtnis, Beinahe-Tode, Bestiarium, Rituale (Wiederkehr, Meilensteine, Spieldauer).
- Gefahrenkarte: eigene Beinahe-Stellen + optionales Daten-Addon aus der Deathlog-Datenbank.
- Interaktion: Rechtsklick-Menü, Gesprächsbaum, `/lyra <text>` mit lokalem Verständnis, Still-Modus.
- Design: Atmen/Nicken/Crossfade, Sprechblase mit Schwanz und Fade, Bildschirmrand-Glow, Minimap-Knopf, Kampf-Transparenz.
- 46 Ereignisse, 76+ gesprochene Zeilen de/en mit Anrede-Varianten.

## 0.1.0 (2026-09-16)
- Erstes Gerüst: Regie, Gestalt, Sprechblase, Stimme (LoD-Pakete de/en), 29 Sinne, Settings, Slash.

## 0.2.1 (2026-09-17)
- Fix: Gestalt wuchs bei laufender Atem-Animation bis zum Verschwinden (Scale-Loop) — Atmen jetzt Translation, Not-Aus auf Scale 1.
- Fix: Dialog „Mehr…" zeigte dieselben Antworten; Lore auf 6 Zeilen, Rotation persistent, Abschluss nach 3 Zeilen.
- Sprites neu gepackt: 512×512, ein Frame je Sheet, Figur zentriert und Füße ausgerichtet (kein Rutschen beim Mienenwechsel), 75 % weniger VRAM.

## 0.5.0 (2026-09-17) — lebensecht
- Zustandsmodell (Laune, Vertrautheit 0/10/50/100 h, Tageszeit, Sitzung, Stress): dieselben Ereignisse klingen je nach Zustand anders (`wenn`-Tags an Zeilen, 25 Zustands-Zeilen).
- Rituale: Abschied bei /camp, Rückkehr nach AFK, Spätnachts, Jahrestag, Gedenken an gefallene Vorgänger, Feiertage, Reaktion auf eigene Emotes (/hug, /wink …), Lagerfeuer.
- Grundstimmung um AFK/Taxi/Tod/besorgt/gut/Nacht erweitert; Mikro-Regungen nach Vertrautheit.
- `/lyra stimmung`, `/lyra ssf` (Solo-Self-Found: keine Handelshinweise), Intents Zeit/Wie lange/Erinnerst du dich/Laune.
- Gruppenereignisse (Boss-Kill/-Wipe/Pull/Enrage, Aggro, Instanz, Reisecheck) tragen `gruppeOk` und erscheinen trotz „In Gruppe schweigen"; Boss-Kill/-Wipe wieder Plauderei mit Drossel.

## 0.5.1 (2026-09-17) — Client-Fixes aus Haralds Screenshot
- Portrait war unsichtbar (nur Ring): eigene PNG-Maske lud nicht → Blizzards TempPortraitAlphaMask.
- Drift der Animationsebenen: Einzelanker (CENTER) statt SetAllPoints; Drift-Wächter misst jetzt immer (Atmen läuft dauerhaft) und setzt hart zurück.
- Sprechblase: Blizzards Blasen-Textur ist dunkel → heller Text, dunkler Lila-Grund deckend.
- Nicken beim Sprechen sanfter (1 px, 1,2 s). Neu: `/lyra animation aus|an`, `/lyra drift` (Diagnose).

## 0.6.0 (2026-09-17) — Fähigkeiten-Welle 2
- Notfallknöpfe: bei HP35/HP20 sagt Lyra, welcher Rettungszauber bereit ist (je Klasse), oder wie lange er noch schläft; lernt, welche Knöpfe nie genutzt werden (`/lyra cooldowns`, Frage „was ist bereit").
- Klassenrat als Datentabelle (Magier aus klassenrat/magier.md, allgemeiner HC-Rat), `/lyra rat`.
- Quest-Fortschritt nativ: Ziel erledigt, fast fertig, Quest komplett, Abgabe in der Nähe (mit Questie-Daten), `/lyra quests`.
- Spielstil-Profil: Kämpfe, Tiefstände, Fehlalarm-Quote → Stil vorsichtig/normal/Draufgänger als `wenn`-Tag `stil`, `/lyra profil`, abschaltbar.
- Karte: eigene Beinahe-Stellen und Notizen als Pins auf Weltkarte/Minimap (HereBeDragons-Pins, falls ein Addon sie liefert), `/lyra karte`; Raid-Marks per `/lyra mark [skull|kreuz|1-8]` und „markier das Ziel".
- Brücken 2: Lyra-Ereignisse als WeakAuras-Custom-Event `LYRA_GESTALT`, Pawn-Upgrade-Hinweis bei eigener Beute, Details-Schadensrekord.
