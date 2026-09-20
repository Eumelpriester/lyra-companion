# Lyra Companion

**A visible, talking companion who watches your Hardcore run — and never presses a key.**

She lives at the edge of your screen: a face with about thirty expressions, a voice in
English and German, and a memory. She reacts to what happens to **you** — health
dropping, a burst of damage, air running out, an elite in your target, a zone where you
nearly died last week.

She says less than a typical addon and remembers much more.

Website: **<https://lyracompanion.de>** · Classic Era / Hardcore 1.15.9 · free, and it
stays free.

<!-- In der Addon-Liste des Spiels steht "Lyra - Arcane Companion"; der Ordner heisst
     technisch Lyra_Gestalt. Oeffentlich heisst das Projekt "Lyra Companion" — eine
     Stelle, an der die drei Namen erklaert sind, reicht. -->

---

## What Lyra does

- **Watches your life.** Health thresholds, sudden burst damage, fall damage, breath
  underwater, fatigue — spoken and shown, instantly, in combat.
- **Names the danger.** Adds joining the fight, elites in your target, level gaps that
  will kill you, an empty potion bag.
- **Warns before the place, not after the death.** A data pack aggregated from the
  public Deathlog database marks the cliffs, the deep water and the camps where
  hardcore characters die — and Lyra remembers the spots where *you* nearly died.
- **Remembers.** Zone greetings with history ("Welcome back to the Barrens. Last time
  you nearly died here."), a bestiary of the mobs that keep hurting you, session and
  milestone rituals.
- **Speaks.** Pre-rendered voice lines in English and German, plus a subtitle in the
  speech bubble. Voice packs are loaded on demand.
- **Talks back.** Click her for a dialog tree, or type `/lyra <anything>` and she
  answers from fixed templates and your own chronicle. No language model runs.
- **Stays out of the way.** Three warning levels, per-category switches, presets from
  Quiet to Streamer, combat and group quiet modes, four colour palettes, size presets,
  free positioning.

## What Lyra never does

> **No automation.** She never presses a key, never moves, never casts, never targets.
> **No chat output.** She never writes into any channel — not say, not guild, not whisper.
> **No data about other players.** No names, no whispers, no group members, no addon channel.
> **No network.** Nothing leaves your machine. **No ads, no purchases, no premium features.**
> Everything runs through the public AddOn API: she reads, she shows, she speaks.

This addon is free and complete, and it stays that way. There is no paid tier and there
will not be one.

## The voice is AI-generated, and we say so first

Lyra's voice is **synthetic**. It was rendered **offline**, before release, by an AI
text-to-speech model and shipped as ordinary OGG files — labelled as AI-generated in
line with **EU AI Act Art. 50**.

While you play, **no model runs, and there is no network traffic at all.** The addon
plays sound files, the same way every other addon with sound does. No Blizzard audio is
shipped. Details: [`LICENSE-ASSETS.md`](LICENSE-ASSETS.md).

If you would rather not hear it: `/lyra stumm` turns the voice off and keeps the
subtitles.

---

## Install

**From this repository.** Download the zip attached to the latest entry under
*Releases*, unpack it into `Interface/AddOns/`, restart the client.

**From lyracompanion.de.** The same zip, with its SHA-256 next to it, at
<https://lyracompanion.de/en/#download>.

**CurseBreaker** installs it straight from the GitHub releases of this repository:
`install gh:OWNER/REPO`, with the owner and repository name from this page's address.

**CurseForge, Wago Addons, WoWInterface** — submitted or planned, not live yet. When a
project page exists, it will be linked here and on the website, and not one day earlier.

**Discord** — questions, bug reports and phrase ideas, in English and German: <https://discord.gg/pXjy8RJ5Cv>

<!-- NACHZUTRAGEN, sobald es das wirklich gibt — nicht vorher:
     * CurseForge-Slug (Projekt 1703906), sobald "Approved"
     * Wago-Slug
     Ein Link auf eine Seite in Moderation ist ein toter Link mit Anlauf. -->

After unpacking, **four** folders must be there:

```
Interface/AddOns/Lyra_Gestalt/                 the addon
Interface/AddOns/Lyra_Gestalt_Stimme_de/       German voice, loaded on demand
Interface/AddOns/Lyra_Gestalt_Stimme_en/       English voice, loaded on demand
Interface/AddOns/Lyra_Gestalt_Daten/           danger map (Deathlog data)
```

Copying only the first one gives you a mute Lyra without a danger map.

> ⚠ **Restart the game client completely — `/reload` is not enough.**
> WoW only finds sound files that were already in the AddOns folder when the client
> started. This one step is the cause of about half of all "the voice is silent"
> reports.

Nothing else to install and nothing to configure. On first login Lyra asks four
questions (language, how to address you, talkativeness, portrait or full figure).
Repeat any time with `/lyra einrichten`.

## Commands

| Command | What it does |
|---|---|
| `/lyra` | open settings |
| `/lyra hilfe` | list every command |
| `/lyra status` | version, client, loaded voice packs, active options, self-test |
| `/lyra lang de` / `en` | language (default: your client locale) |
| `/lyra anrede m` / `f` / `keine` | how she addresses you |
| `/lyra leise` / `normal` / `lebendig` / `streamer` | presets |
| `/lyra still` · `/lyra stumm` | quiet mode · mute voice |
| `/lyra farbe standard` / `kontrast` / `warm` / `kalt` | colour palette |
| `/lyra portrait` / `figur` · `/lyra klein` / `mittel` / `gross` | view and size |
| `/lyra chronik` | chronicle, bestiary, near-death map |
| `/lyra frag` | dialog tree · `/lyra <text>` just talk to her |
| `/lyra test HP20` | preview a single event (any event ID) |
| `/lyra debug` | diagnostic block for bug reports — contains no names |

---

## FAQ

**Is this allowed on Hardcore realms?**
Yes. Lyra reads the same public AddOn API that Deathlog, Questie and DBM read. She
performs no action for you: no key press, no movement, no casting, no targeting, no
automation of any kind. The full source is in this repository — read it.

**Does it work with Deathlog / Hardcore / Questie / unitscan?**
Yes, all of them. Lyra writes nothing to chat and uses no addon communication channel,
so she cannot collide with them. If you run Deathlog, Lyra deliberately stays silent
about other players' deaths — that is Deathlog's job.

**Which game versions?**
**Classic Era / Hardcore (1.15.9) is the one that is tested and shipped.** The TOC
carries interface numbers for TBC, Mists and Retail and the code has a client switch,
but no other client has been played through — treat them as untested. On Retail the
combat-log senses would be limited by the new secret-value rules anyway. For *WoW:
Forever* we are waiting for a client that confirms its interface number.

**Why is the voice not playing?**
Three usual reasons: (1) you installed while the client was running — restart the
client, not just `/reload`; (2) `/lyra stumm` is active; (3) the in-game "Dialog" sound
channel is muted — Lyra uses `Sound_DialogVolume`. Check `/lyra status`, it lists the
loaded voice packs.

**She talks too much / too little.**
`/lyra leise` or `/lyra lebendig`, or open the settings and switch off individual
categories. Lyra ships with the *Normal* preset and is deliberately quieter than most
addons. During combat she only says the things that can save your life.

**Can I move or resize her?**
Drag her with the left mouse button (unless locked). `/lyra klein|mittel|gross`, or
`/lyra groesse <number>` for a free value. `/lyra portrait` shows head and shoulders
only, `/lyra figur` the full figure.

**Does she send anything anywhere?**
No. There is no network code in this addon. Nothing is uploaded, nothing is collected,
nothing about other players is ever stored. `/lyra debug` prints no character, guild or
channel names.

---

## Known issues

- A voice pack installed **while the client is running** stays silent until the next
  full restart. That is how WoW loads sound files; it is not fixable from the addon.
- Lines that contain a placeholder (zone name, a number, the title of one of your own
  notes) are **subtitle only** — the renderer speaks fixed sentences.
- At UI scales below 0.65 the speech bubble can overlap the default action bar.
  Workaround: `/lyra klein`, or drag her higher.
- Only Classic Era is tested; see the FAQ above.

Report bugs as **issues** — the templates (English and German) ask for the `/lyra debug`
block, which is what makes a bug fixable in one go instead of five.

---

## Personal lines — optional, and built on your own machine

There is a fifth folder that is **not** part of the download:
`Lyra_Gestalt_Persoenlich`. It holds sentences written from *your own* chronicle — your
zones, your sessions, your numbers — and Lyra mixes them in among her built-in lines. It
is user-specific by definition, so it cannot ship with the addon. Format, rules and an
empty template: [`docs/persoenlich/`](docs/persoenlich/).

## Contributing

**Translations and phrase suggestions help most.** English and German are complete;
everything else is open, and translators are credited in the chronicle of supporters.
Full guide: [CONTRIBUTING.md](CONTRIBUTING.md).

- **Bugs and ideas:** the *Issues* tab of this repository. Templates exist in English
  and German. Please include the `/lyra debug` block.
- **Interface and phrase text:** `Locales/enUS.lua` and `Locales/deDE.lua` hold the UI
  strings; a new language is a new file with the same keys. Once the CurseForge project
  is live, its *Localization* tab will work without a GitHub account.
- **Voice:** only German and English are recorded. A new voice language needs a fully
  translated phrase set **plus** a TTS voice with a clean, documented licence — please
  ask before you start rendering, so that finished work does not have to be turned down
  over its licence.
- **Two rules no patch can bend:** no automation, and no data about other players.

## Build it yourself

This repository is the **release layout** the [BigWigs packager][pkg] expects: the main
TOC in the root, the extra addons under `Pakete/`, lifted to the top level of the zip by
`.pkgmeta`.

```bash
curl -sO https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh
chmod +x release.sh
./release.sh -d          # builds .release/*.zip, uploads nothing
```

The result must contain exactly four top-level folders.

[pkg]: https://github.com/BigWigsMods/packager

---

## Licences

Four different licences apply to four different things. This matters if you want to
reuse anything.

| Part | Licence | Reuse |
|---|---|---|
| **Code** — everything `.lua` and `.toc` written for this addon | **MIT**, see [`LICENSE`](LICENSE) | yes, freely |
| **Sprite art** — `Lyra_Gestalt/bilder/` | "Mage Extended" set by **Prometheus Pictures**, under its **Extended License** | **no.** Licensed, not free. Bundled solely as part of this addon, in the cropped form it uses. Extracting, redistributing or reusing the art elsewhere is not permitted. The twelve licence files of the purchased set are in `LICENSES/`. |
| **Voice** — `Lyra_Gestalt_Stimme_*/stimme/*.ogg` | synthetic speech, **AI-generated offline**, all rights reserved | **no.** For use as part of this addon only. |
| **Sound cues** — `Lyra_Gestalt/laute/*.ogg` | rendered with [Piper](https://github.com/rhasspy/piper) (MIT) | see Piper's model card |
| **Danger map data** — `Lyra_Gestalt_Daten/` | **GPLv3** — required by its source | yes, under GPLv3. Aggregated from the public [Deathlog database](https://github.com/Deathwing/Deathlog) by Deathwing and Yazpad. Grid aggregates only: **no character names, no guild names, no last words.** |
| **Embedded libraries** — `Lyra_Gestalt/Libs/` | LibStub (Public Domain), CallbackHandler-1.0 (BSD), HereBeDragons-2.0 and -Pins (BSD 3-Clause) | under their own licences, see `Lyra_Gestalt/Libs/LICENSE.txt` |

Full detail for art, voice, data and libraries: [`LICENSE-ASSETS.md`](LICENSE-ASSETS.md).

Lyra Companion is an independent fan project. **Not affiliated with or endorsed by
Blizzard Entertainment.** World of Warcraft and Blizzard Entertainment are trademarks of
Blizzard Entertainment, Inc. No Blizzard audio, artwork or other game asset is shipped
with this addon.

## Support

The addon is free and complete either way. If you want to support development:
<https://buy.stripe.com/00w8wOeo2dJ71Wr5ZBcwg01>

---

## Deutsch — die Kurzfassung

**Lyra Companion ist eine sichtbare Begleiterin für WoW Classic Era / Hardcore:** ein
Gesicht am Bildschirmrand, eine Stimme auf Deutsch und Englisch, und ein Gedächtnis. Sie
sagt an, was *dir* passiert — Leben fällt, Schaden kommt in einem Stück, die Luft wird
knapp, ein Elite steht im Ziel, vor dir liegt eine Stelle, an der schon viele gestürzt
oder ertrunken sind.

**Sie drückt nie eine Taste.** Keine Automatisierung, keine Chat-Ausgabe, keine Daten
über andere Spieler, keine Netzverbindung. Sie liest die öffentliche AddOn-Schnittstelle,
sie zeigt, sie spricht.

**Ihre Stimme ist KI-generiert** — offline erzeugt und als Klangdatei mitgeliefert;
während du spielst, läuft kein Modell. Gekennzeichnet nach EU-KI-Verordnung Art. 50.
Wer sie nicht hören will: `/lyra stumm`.

**Installation:** Zip entpacken nach `Interface/AddOns/`, sodass dort **vier** Ordner
liegen (`Lyra_Gestalt`, `Lyra_Gestalt_Stimme_de`, `Lyra_Gestalt_Stimme_en`,
`Lyra_Gestalt_Daten`). Danach den **Spielclient komplett neu starten** — `/reload`
genügt nicht, WoW findet nur Tondateien, die beim Start schon da waren.

**Die drei Befehle, die man wirklich braucht:** `/lyra` (Einstellungen),
`/lyra leise` (weniger reden), `/lyra status` (was geladen ist).

**Fehler melden:** über den Reiter *Issues*, es gibt eine deutsche Vorlage. Bitte den
Block aus `/lyra debug` mitschicken — er enthält Version, Client, Sprache und die
letzten Ereignisse, aber **keine** Charakter-, Gilden- oder Kontonamen.

**Lizenzen in einem Satz:** Code MIT, Sprites lizenziert und **nicht** weiterverwendbar,
Stimme KI-generiert und nur als Teil dieses Addons nutzbar, Gefahrenkarte GPLv3 (aus
Deathlog). Einzelheiten stehen oben in der Tabelle und in `LICENSE-ASSETS.md`.

Alles Weitere auf Deutsch: <https://lyracompanion.de>
