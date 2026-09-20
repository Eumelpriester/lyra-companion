# Lyra Gestalt — Persönliche Zeilen / Personal lines

*(Deutsch zuerst, English below.)*

---

## Deutsch

### Was das ist

Ein **Datenpaket**. Es enthält 29 Sätze, die aus **deiner eigenen Chronik** geschrieben wurden —
aus den Zonen, Sitzungen, Stufen und Zahlen, die `Lyra_Gestalt` in deinen SavedVariables
mitschreibt. Lyra mischt diese Sätze bei passender Gelegenheit unter ihre eingebauten Zeilen:
Wenn du nach Tagen in eine Zone zurückkommst, sagt sie vielleicht nicht „Hier warst du schon mal",
sondern nennt die Stadt, die Zahl der Besuche und dass es dort noch nie knapp geworden ist.

Es ist **kein Addon im eigentlichen Sinn**: keine Funktion, kein Code, keine Ereignisse, kein
Netzwerk. Die Datei `persoenlich.lua` ist eine Lua-Tabelle mit Text, nichts weiter. Der ganze
Prüf- und Auswahl-Kram sitzt im Kern (`Lyra_Gestalt/Sinne/Persoenlich.lua`).

### Wer die Zeilen schreibt

Diese Fassung ist **von Hand** geschrieben (`quelle = "hand"`), am 17.09.2026, aus der Chronik von
`Testheld-Testrealm`. Jede Zahl darin steht so in der Chronik. Was nicht in der Chronik steht,
steht auch nicht in einer Zeile — es gibt keinen erfundenen Rivalen, keinen erfundenen Beinahe-Tod
und keine erfundene Zone.

Später soll ein **Redakteur** dieselbe Datei erzeugen: entweder das Werkzeug
`tools/persoenlich-vorlage.py` (füllt Vorlagen deterministisch, ohne Modell) oder ein
Sprachmodell über die „Brücke" (`docs/redakteur-konzept.md`). Das Format ist in beiden Fällen
dasselbe, und der Kern behandelt alle drei Quellen gleich.

### Installation

Ordner nach `Interface/AddOns/` legen, sodass es so aussieht:

```
Interface/AddOns/Lyra_Gestalt/
Interface/AddOns/Lyra_Gestalt_Persoenlich/
```

**Danach den Client einmal komplett neu starten.** Ein `/reload` genügt **nicht**: die Addon-Liste
wird beim Programmstart aufgebaut, ein neu angelegter Ordner ist vorher unsichtbar. Wird später nur
der *Inhalt* von `persoenlich.lua` geändert, reicht `/reload`.

Kontrolle im Spiel: `/lyra persoenlich`. Dort steht, ob das Paket geladen ist, wie viele Zeilen
gültig sind, wann es erzeugt wurde und welche Zeilen mit welchem Grund verworfen wurden.

### Entfernen

Ordner `Lyra_Gestalt_Persoenlich` löschen — oder im Addon-Verzeichnis des Clients das Häkchen
entfernen. Mehr ist nicht nötig:

* Das Paket hat **keine** SavedVariables, es bleibt also nichts zurück.
* `Lyra_Gestalt` prüft die globale Tabelle und findet sie dann einfach nicht mehr. Kein Wrapper,
  keine Fehlermeldung, keine persönlichen Zeilen — exakt das Verhalten von vorher.
* Wer den Ordner behalten, die Zeilen aber abschalten will, kann in den SavedVariables von
  `Lyra_Gestalt` `account.persoenlich = false` setzen.

### Datenschutz

* **Es gehen keine Daten irgendwohin.** Weder dieses Paket noch `Lyra_Gestalt` hat Netzwerkcode.
  WoW-Addons können grundsätzlich nicht ins Internet.
* Es stehen **nur deine eigenen Daten** darin — Zonen, Sitzungen, Stufen, Zahlen aus deiner
  Chronik. Keine Daten anderer Spieler, keine fremden Namen, keine Koordinaten.
* Der **Charaktername** steht genau einmal in der Datei, im Feld `charKey`. Er dient nur der
  Zuordnung („gehört dieses Paket zu dem Charakter, der gerade spielt?") und wird nie ausgegeben.
  In den Sätzen selbst kommt kein Name vor.
* Deine **Notizen** (`/lyra punkt …`) werden nicht automatisch verarbeitet. Wenn eine Zeile eine
  Notiz zitiert, hat ein Mensch sie dort hineingeschrieben.

### Format, in fünf Zeilen

```lua
LyraGestalt_Persoenlich = {
  version = 1, erzeugt = "2026-09-17", quelle = "hand", charKey = "Name-Realm",
  zeilen = { { ereignis = "ZONE_ERINNERUNG", key = "Undercity", de = "…", en = "…", wenn = { zeit = "tag" } }, … },
}
```

Erlaubt sind nur Ereignisse der Klassen `plauder` und `still` — **nie `warn`**. Eine Warnung muss
sprechen, und persönliche Zeilen haben keine vorgerenderte Stimme; sie erscheinen nur in der
Sprechblase. Alles Weitere steht in `Lyra_Gestalt/Sinne/PERSOENLICH.md`.

---

## English

### What this is

A **data package**. It holds 29 sentences written from **your own chronicle** — the zones,
sessions, levels and numbers that `Lyra_Gestalt` records in your SavedVariables. Lyra mixes these
sentences in among her built-in lines when the occasion fits: coming back to a zone after a few
days she may not say "you've been here before" but name the city, the number of visits and the
fact that it never got close there.

It is **not an addon in any real sense**: no functions, no code, no events, no network.
`persoenlich.lua` is a Lua table of text and nothing else. All checking and picking happens in the
core (`Lyra_Gestalt/Sinne/Persoenlich.lua`).

### Who writes the lines

This edition was written **by hand** (`quelle = "hand"`) on 2026-09-17 from the chronicle of
`Testheld-Testrealm`. Every number in it is a number from that chronicle. Anything that is not
in the chronicle is not in a line either — no invented rival, no invented close call, no invented
zone.

Later an **editor** is meant to produce the same file: either the tool
`tools/persoenlich-vorlage.py` (fills templates deterministically, no model involved) or a language
model via the "bridge" (`docs/redakteur-konzept.md`). The format is identical in all cases and the
core treats all sources the same.

### Installing

Put the folder into `Interface/AddOns/` so that you have:

```
Interface/AddOns/Lyra_Gestalt/
Interface/AddOns/Lyra_Gestalt_Persoenlich/
```

**Then restart the game client completely.** A `/reload` is **not** enough: the addon list is built
at program start, so a newly created folder is invisible until then. Later changes to the *contents*
of `persoenlich.lua` do take effect on `/reload`.

Check in game with `/lyra persoenlich`. It reports whether the package is loaded, how many lines
are valid, when it was created, and which lines were rejected for which reason.

### Removing

Delete the folder `Lyra_Gestalt_Persoenlich`, or untick it in the client's addon list. That's all:

* The package has **no** SavedVariables, so nothing is left behind.
* `Lyra_Gestalt` looks for the global table, does not find it, and installs no wrapper. No error,
  no personal lines — exactly the behaviour from before.
* To keep the folder but switch the lines off, set `account.persoenlich = false` in the
  SavedVariables of `Lyra_Gestalt`.

### Privacy

* **Nothing is sent anywhere.** Neither this package nor `Lyra_Gestalt` has any network code.
  WoW addons cannot reach the internet at all.
* It contains **your own data only** — zones, sessions, levels, counts from your chronicle. No data
  about other players, no foreign names, no coordinates.
* The **character name** appears exactly once, in the `charKey` field. It is used only to decide
  whether the package belongs to the character currently playing, and it is never printed. The
  sentences themselves contain no name.
* Your **notes** (`/lyra punkt …`) are not processed automatically. If a line quotes a note, a human
  put it there.

### Licence

Same licence as `Lyra_Gestalt` (see `Lyra_Gestalt/LICENSE` and `Lyra_Gestalt/LICENSE-ASSETS.md`). The text in `persoenlich.lua` is
about your own character; do with it what you like.
