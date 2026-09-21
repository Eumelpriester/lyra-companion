<!-- Englische Fassung von CHANGELOG.md. Bei Änderungen beide Dateien pflegen; die Website liest je Sprache die passende. -->
# Changelog

## 0.16.0 (2026-09-21)

### Wave 13: Docking points

Seven new moments where Lyra says something, and three existing ones that now say more than
they did — 41 new lines per language. Four of the new moments need no third-party add-on at
all; the rest read along with what you have installed anyway, and stay quiet without it.
Eight new checkboxes in the fine tuning page, section **"Further data sources"**, all on by
default.

**Without a single third-party add-on**

- **Your log is getting heavy.** When three or more quests in your log are ready to turn in,
  Lyra says something once. She names the count, never the titles. At most every 30 minutes,
  never in combat, never in an instance, not in the first minute after logging in and not
  right after a single "quest complete" line. No Questie, no other add-on.
- **The trainer-ceiling line now comes without the crafting window open.** Until now Lyra only
  noticed the ceiling at 75/150/225/300 with the window open — anyone mining on the move never
  heard the line. She now reads the rank straight from the skill book. If the profession sits
  collapsed there she stays quiet: she never expands it for you. Three new lines to go with it.
- **The first time in the saddle** gets a line of its own — four of them, all voiced, once per
  character. If you are already mounted when you log in, you hear nothing: Lyra does not tell
  these after the fact. A druid's travel form does not count.
- **The first hundred gold** (and once more at a thousand), once per character, one number and
  nothing else. If you are already past it when you log in, you hear nothing.

**What she reads, if you have it**

- **The way to the turn-in.** When you have a finished quest in the log and the one who takes
  it is in the same zone, Lyra no longer just says "they're around here somewhere" but how far
  and which way: "The one who takes it is two hundred paces to the north." Roughly, in paces,
  in words — no decimal place, no waypoint, no follow-up line. Beyond four hundred paces she
  says nothing at all. For this she reads Questie and HereBeDragons; without them everything
  stays as it was.
- **One mechanic, before you pull.** When you target an enemy out of combat that has an
  ability rated dangerous, Lyra names exactly one of them — "That one stuns. Don't fight it by
  the cliff." Once per enemy type and session, never the whole list (that is in the tooltip),
  never in combat, never while another warning is running. Needs **NpcAbilities**.
- **Your last seconds.** When you die, Lyra says a line a minute later about *how* it
  happened — not as a table, but the way someone sitting next to you would put it: "That
  didn't come suddenly. That came slowly." No rows of numbers, no damage figures and never
  another player's name. The line comes **before** the eulogy — first what happened, then who
  you were — and it is written into your legacy. Needs **Details!**.
- **Persistence while farming.** If you hunt the same item with **Rarity**, you get a short
  line at 100, 250 and 500 attempts — once per mark and item, never in combat, never in a
  group. She does **not** say the drop chance; Rarity shows that itself, and better. She says
  what the number does to a person: "You don't give up, hm."
- **What's stored elsewhere.** With Bagnon (or **BagBrother**) the travel check before a
  dungeon no longer only tells you that you are short on potions or bandages, but also that
  some are sitting on another of your characters or in your own bank. And when you pick up a
  trade good or a recipe that you already have a pile of somewhere else, she says so once —
  and then never again for that item. Because the saved bags are from each character's last
  logout, she always says so; she never claims the stuff is there right now. **She never reads
  guild banks** — what is in them belongs to other players.

**The same everywhere:** if an add-on is missing, Lyra stays quiet, throws no error, and
`/lyra status` says what is missing, by name.

## 0.15.3 (2026-09-21)

### Ready for WoW: Forever

- Lyra now ships a dedicated TOC for **WoW: Forever** (`## Interface-Camelot: 16001`), in all
  five packages — core, danger map, both voice packs and the personal lines. The packager
  builds the matching `_Camelot.toc` files from it. Until now Lyra loaded from the fallback
  TOC on Forever and showed up as "out of date" in the add-on list.
- **16001 is the beta client's number.** At launch on 4 November 2026 it will be a different
  one, and that number gets read off the client and carried over — never guessed. Too low a
  number means "out of date" and the add-on still loads; too high means it does not load at
  all.
- `/lyra status` has a new line, **"Loaded TOC"**: the interface number of the TOC the client
  actually loaded, and whether it fits that client. A "?" means the client does not report it
  — nothing is guessed in its place.
- Under the hood: on Forever, client detection does not rely on `WOW_PROJECT_ID`. That client
  reports the same value as retail; Lyra decides on a feature test that runs first. Nothing
  changes in behaviour — it is now tested rather than accidental.
- The danger map stays deliberately silent on Forever. Its data comes from Classic Era, and
  the same map IDs cover reworked zones there. A wrong warning is worse than none.

## 0.15.2 (2026-09-21)

**Death spots now have their own checkboxes.** Under "Fine tuning → Map" you will find two new
options: one for the line Lyra says at a predecessor's death spot, one for the marker on the
world map and the minimap. They toggle exactly what `/lyra karte sterbeort` and
`/lyra karte sterbeortpin` already toggled — untick one and the pin is gone right away, no zone
change needed.

## 0.15.1 (2026-09-21)

**She remembers where it happened.** When you walk a new character onto the spot where one of
your predecessors fell, Lyra tells you — **once**, with name, level and date, and never again
after that. If several of them lie there, she speaks of the most recent one and names the
number. No blame, no advice, no cause of death: just the place. She has been writing those
coordinates down since version 0.9, and until now nobody ever read them.
**Your own gravestone beats any statistic.** On a spot where one of your predecessors lies,
your own close-call marker, the foreign death statistics and your own "this place is safe"
waypoint all keep quiet — one place, one line. Warnings about something that is about to
happen are untouched; survival still has right of way.
**On the map** every death spot now has its own marker, on the world map and the minimap, with
name, level and date in the tooltip. Your own characters only, never anybody else's. To switch
it off: `/lyra karte sterbeort aus` (the line) or `/lyra karte sterbeortpin aus` (the marker
only).

---

## 0.15.0 (2026-09-20)

### Wave 11a: Death gets a voice
**Death gets a voice.** After a hardcore character falls, Lyra still keeps quiet for a minute —
that stays. After that she speaks an obituary built from the facts already in your chronicle:
level, zone, hours played, close calls, worst enemy. If you gave her last words she carries them
on — and only then; she never invents any. The last-words prompt now has four wordings instead
of one, and your predecessor six lines instead of two. The chronicle window has a new section:
the **Hall of the Fallen**, with every character of yours who fell, their level, their zone and
their last words. Yours only, never anybody else's.
**She remembers you.** 48 new lines only unlock once you have been travelling together for a
while — the focus is on the first ten hours, where the whole catalogue used to hold four lines.
Plus 15 rare lines you may never hear.
**The recap moved to the goodbye.** Type `/camp` and she tells you something from *this*
session during the countdown, instead of telling you about the last one at your next login.
**Bigger pools.** The runner warning had two sentences and now has six; `LEVELUP` twelve instead
of six, clicking Lyra twenty instead of eleven, emotes sixteen instead of nine.

### Safety
- **Fatigue in open water now says the right thing.** Until now the fatigue bar produced a
  chatty line about the inn - and that line was held back in combat, dropped in a group and
  swallowed in silent mode. It is now a level 2 warning, it comes through in all three
  situations, and it says what actually helps: turn back. Surfacing does not help against
  fatigue.
- **Your own close call beats someone else's statistic.** Where your own close call and a
  foreign death cell sit on the same spot, only yours is spoken - and the foreign ones stay
  quiet there for 30 seconds.

### Quiet and pacing
- **Level 1 hints** (cliffs, deep water, potions, bestiary, runners ...) now keep 15 seconds
  apart and at most ten per hour. Warnings and alarms are untouched: health below 20 %,
  falling, last breath and the boss pull still come instantly.
- **Mute a single event:** `/lyra stumm <EVENT>`, undo with `/lyra laut <EVENT>`. `/lyra
  gehoert` lists what you heard last, with the ID to switch it off. Alarms cannot be muted.
- **"Why aren't you saying anything?"** - `/lyra warum` names the last five messages that did
  not make it out, and why. It also says which of those were losses and which were simply
  how you set her up.
- **Rare lines.** Lines marked as rare now come up a quarter as often, and never twice in a
  row.

### Sound
- **Lyra has her own volume control**, `/lyra lautstaerke <0-100>` or the slider in the fine
  settings. It works relative to the sound channel you picked; Blizzard's own slider is only
  lowered for the length of one line and put back exactly afterwards - even if you reload
  mid-line. Alarms always stay at full volume.

## 0.14.0 (2026-09-20)

### Lyra miscounts less often
The free-text questions from 0.13.0 now answer more precisely — and, above all, less often
wrongly. Lyra no longer pulls a mistyped word onto some similar-sounding word that belongs
somewhere else entirely, and a single word is no longer enough for her to consider a whole
question understood. Where she used to give a real number to the wrong question — "how often
was I in the Barrens" answered with your death count — she now simply says: there's nothing in
my book about that yet.
**She understands zone names in both languages.** Type "wie oft war ich im Schlingendorntal" on
an English client and you get the count for Stranglethorn Vale, and the other way round just
the same — for the outdoor zones and capitals of the Classic world.
**And she answers "why" honestly.** "Why did I almost die in Westfall every time?" is not a
question a table of numbers can answer. Lyra invents nothing for it; she hands back the fact:
"Why? I count, I don't interpret. All I know is: …"
`/lyra hilfe` now ends with a sentence that was always true and was written down nowhere:
Lyra answers from fixed templates and your own chronicle. No language model is running.

### Colour themes
- **Four named colour palettes** for the speech bubble, the subtitle bar and the warning
  pulse at the screen edge: `standard` (Lyra's violet, unchanged), `kontrast` (black/white),
  `warm` (amber on brown) and `kalt` (ice blue on night blue). Switch with
  `/lyra farbe <name>`; your choice is remembered. The default is `standard` — do nothing
  and nothing changes.
- Every palette is checked for readability: text sits between 16.8:1 and 21:1 on the bubble
  background in all four, and the subtitle bar still reaches 11.8:1 to 15.1:1 over the
  brightest possible game image. The requirement is 4.5:1.
- The **"High contrast" checkbox wins over any palette choice.** A colour theme cannot
  undercut accessibility, and `/lyra farbe` tells you when your choice is being overridden
  for that reason.
- No palette changes the **brightness or the rhythm** of the pulse — that is the
  photosensitivity limit, not a matter of taste. And Lyra's alarm is never Blizzard's red in
  any palette: the client draws its own warning in that colour, and two identical reds cannot
  be told apart.

### Small things
- Client detection for WoW: Forever now survives a 1.7x–1.9x build line as well. The TOC line
  itself stays out until a client confirms both the suffix and the number.
- Licence details for the embedded libraries looked up and documented (`Libs/LICENSE.txt`).
  LibDataBroker-1.1 is listed as "All Rights Reserved" on CurseForge and is therefore **no
  longer bundled**; the data-broker display (Titan Panel, ElvUI datatexts) keeps working because
  every one of those addons ships the library itself.
- Bug reports: German issue templates, and a clear note on which details make a report
  fixable in one go.

### Voice
- 23 lines that only appeared as subtitles since waves 5, 6, 8 and 9b are now recorded, in
  German and English: the early warnings before falls and deep water, arriving at one of your
  own notes, switching accessibility mode on and off, and Lyra's three fallback answers in free
  text. Lines with placeholders (zone name, number, note title) stay subtitle or read-aloud. As
  always: the client only hears new sound files after a full restart.

## 0.13.0 (2026-09-20)

### Wave 9b: Writing freely with Lyra
There is now an input field below Lyra's dialogue window. You can ask her full questions about
your own chronicle — zones and visits, your worst enemy, close calls, playtime, sessions,
notes and your predecessor. She understands 18 kinds of question in German and English,
forgives typos, and recognises zone and creature names from your own chronicle. When she
cannot answer, she now says why: "there's nothing in my book about that yet", "maps are not
my trade", or simply "I didn't catch that" — three answers instead of one. And she comes back
to your question later, on her own.
**No language model runs.** Lyra answers from fixed templates and your own numbers; nothing
leaves your computer, and by default what you type is not even saved. The input field takes
focus only on click and drops it the moment combat starts — a field that swallows WASD is
lethal on hardcore.
Switches: `/lyra freitext an|aus` and "Free writing" in the fine settings. `/lyra <question>`
keeps working as before.

### Wave 9a: She says the names right — and keeps what she promised

**Personal lines are shown again, never read aloud.** `/lyra persoenlich` has always said
"never with voice". Since the reading-aloud feature arrived, that stopped being true — every
line without a recording was read out, and personal lines never have one. It is true again.
If you want it the other way round, there is a checkbox for it in the fine settings; it is off.

**She says the names right.** Lyra's own voice is recorded and sounds the way it should. The
lines that carry a zone name, a number or your name cannot be recorded in advance — those are
read by your operating system, and it used to say "Azeroth" with a hard Z and "Onyxia" with an
umlaut. Lyra now ships a pronunciation lexicon for German and English. It applies **only** to
reading aloud: the speech bubble still shows the name, not the phonetic spelling. Missing a
word? Add it yourself — `/lyra aussprache Onyxia = Oh-nik-see-uh`.

**She is in your bar now, too.** If you use Titan Panel, Bartender4, ChocolateBar or a minimap
button collector, you will find Lyra there: her state as text, one click opens the menu. The
minimap button stays exactly as it was — this is in addition, not instead.

**Take your settings with you.** `/lyra profil export` gives you a string you can copy, keep or
send on; `/lyra profil import` reads it back. It contains **settings only** — no chronicle, no
character name, no realm. Anything that does not belong on the list does not get through on
import, not even if somebody has tampered with the string.

| | |
|---|---|
| **New** | Pronunciation lexicon for spoken lines, 68 entries (de/en), voice only |
| **New** | `/lyra aussprache` — add, list and remove your own pronunciations |
| **New** | `/lyra profil export` and `/lyra profil import` with a copy window |
| **New** | LibDataBroker feed for Titan Panel, Bartender4, ChocolateBar and button collectors |
| **New** | Checkbox *Read personal lines aloud too* (off) under *Fine settings → Voice* |
| **Changed** | Personal lines are shown, never read aloud — the way it always said |
| **Changed** | Questie is read through its official API; the old path remains as a fallback |
| **Fixed** | When accepting a quest, Lyra's line could come too early, before Questie had finished loading |

**Test harness:** 58 runs, 4,396 checks, all green. Catalogue: 122 events.

## 0.12.0 (2026-09-20)

### Wave 8: She warns before it happens

**The warning now comes beforehand.** Until now Lyra said "people have already fallen here"
when you were standing at the cliff edge. Now she looks at where you are running and says it
twenty to forty yards ahead — quietly, once, and only in places where at least ten people
died the same way. *She does not tell you where to go. She tells you where others died.*

That comes with a long list of situations in which she does **not** speak: not in combat, not
on the gryphon, not in flight, not in a city or an inn, not in an instance, not while you are
standing still, not while you are turning on the spot, not twice in the same place. A warning
that comes too often is worse than no warning at all — which is why the locks are longer than
the feature.

**Swimming.** If your breath is below half and you are over a spot where people have already
drowned, she says so. Once.

**She survives a patch day.** At login Lyra checks the eight places where she hooks into the
game. If one falls away, she switches off the affected sense and says one sentence in chat —
instead of showing you an error with her name in it. The rest keeps running.
`/lyra selbsttest` says exactly what is missing; that is the line that belongs in a bug report.

**And she can be grabbed by the scruff of the neck again.** When you drag Lyra across the
screen she now gets startled even while she is pulling a face at an event.

| | |
|---|---|
| **New** | `STURZ_VORAUS`, `WASSER_VORAUS`: one calm line 20–40 yards ahead of a falling or drowning spot, in your direction of travel, from ten deaths there onwards |
| **New** | `TIEFES_WASSER`: over a drowning spot with half your breath left |
| **New** | Self-test at login. If an interface falls away, a sentence comes instead of an error, and only the affected sense goes off |
| **New** | `/lyra selbsttest` — eight lines for the bug report |
| **New** | `/lyra vorwarnung an\|aus` and a checkbox under *Fine-tuning → Data sources* |
| **Changed** | The settings page is now called "Lyra Companion", the way the addon is called everywhere else |
| **Changed** | "Warning level as a shape too" has moved into the fine-tuning; the first page is thirteen entries long again |
| **Fixed** | Lyra could no longer be startled while being dragged as soon as she was holding a face for an event |
| **Fixed** | After a close call in the first few minutes she talked *more* instead of less. The mood now calculates differently |
| **Fixed** | On clients with Blizzard's own text-to-speech a category was being guessed. If it is not reported, the client now decides |

Everything new lives in two files (`Core/Selbsttest.lua`, `Sinne/Welle8.lua`); about 40 new
lines were added to existing files. Without the package Lyra_Gestalt_Daten nothing happens,
and nothing happens on Retail and Forever either — there a different world lies behind the
same maps. Test harness: four scripts, 240 checks, all green.


---

### The edge pulse without corners

**Screen-edge pulse: the corners.** The warning frame consisted of four bands that overlapped
in the corners — in ADD blend the brightness added up to double there, and you saw four
brighter rectangles. The edge is now a 9-slice: four edges that stop short of the corner, and
four corner tiles that continue the gradient diagonally. No two surfaces share a single pixel
any more, so nothing can be drawn twice. From now on the edge width hangs on the short side of
the screen instead of on both axes separately: on 16:9, 16:10 and 21:9 the frame is equally
wide, whereas before it was almost twice as wide on the left and right as at the top and
bottom on ultrawide. For that, `bilder/puls_rand.png` has gone from a full-screen mask to a
corner tile that the edges also take their gradient from — one file for all eight surfaces.
The bottom line: despite a stronger effect there is 31 % less light on the screen, and the
peak value drops from 0.70 to 0.48. Levels, colours, double beat, display time, Streamer and
accessibility behaviour are unchanged.

**Note on viewing it:** the client only sees a new image file after a full restart, `/reload` is not enough.

## 0.11.0 (2026-09-20)

### Wave 5: The map

Lyra now draws what she knows onto the map. Every spot where you nearly died gets a pin on
the world map and the minimap — with the health you had left and who was to blame. Your own
points from `/lyra punkt` sit next to them, with your note in the tooltip. And over the zone
you are currently standing in she lays the danger map: semi-transparent cells, orange for
falls, blue for drowning, red for creatures; the stronger the colour, the more deaths. What
is shown is exactly what she also warns about — a map that claims something other than the
companion does would be worse than no map at all.

**The find of this round was a number that had been wrong since wave 1.** Lyra's warning
about an old close-call spot hung on a fixed fraction of the map's width — and zones vary in
size. In a wide outdoor zone the same value meant a multiple of what it meant in a city: the
warning came far too early or far too late depending on the area. She now calculates in real
yards, separately for each zone.

**What she explicitly does not do:** she does not put a second warning call on the same spot.
That one already existed; it was just badly measured.

| | |
|---|---|
| **New** | Pins on world map and minimap for close calls and for your own points, with Lyra's text in the tooltip |
| **New** | Danger-map overlay on the world map of your zone, colour by type of death, opacity by number of deaths. Needs the package Lyra_Gestalt_Daten, Classic clients only |
| **New** | `PUNKT_NAH`: one line when you arrive at a point you set yourself — at most every ten minutes per point, never in combat |
| **New** | `/lyra karte`: overview and switches (`/lyra karte overlay an\|aus`, likewise beinahe, notizen, nah) |
| **New** | `/lyra punkt weg [n]`: delete a point again |
| **New** | Four checkboxes under *Fine-tuning → Map and pins*, all on by default. The old "Map pins" switch stays the master switch |
| **New** | With TomTom, Lyra tints the waypoint arrow purple — but only if another addon has taken it over and actually keeps the colour |
| **Fixed** | The warning about an old close-call spot came far too early or far too late depending on zone size. It now measures in yards |
| **Fixed** | Close-call pins were drawn twice, ever since there were two places that wanted to draw them |
| **Internal** | HereBeDragons is embedded (Libs/). If another addon brings a newer version along, that one wins — Lyra demands nothing |

Everything new lives in a single file (`Sinne/Karte2.lua`); about 50 new lines were added to
existing files. Without HereBeDragons nothing happens, and `/lyra karte` says honestly why.
Test harness: four scripts, 388 checks, all green.

### Wave 6: Accessibility, coexistence, integrations

**Lyra now has an accessibility mode, and it is a switch, not fine print.**
One click — or `/lyra barrierefrei an` — and the subtitle bar stays up permanently, every line
is prefixed with "Lyra:", the text gets larger, every line stays longer, and lines without a
voice recording are read aloud, provided your system has a voice. Turn it off again and you get
your old settings back: the mode remembers them, it does not overwrite them.

**Warning levels now carry a shape, not just a colour.** A dot for a hint, a triangle for a
warning, two for an alarm — small on the speech bubble, larger in accessibility mode. That
applies without the mode as well. Colour alone does not carry a warning for roughly eight per
cent of male players, and Blizzard's own frame colours change nothing about that.

**And Lyra works fully without the figure.** The first-run assistant has gained a fourth
question: "Should I be visible?" Anyone who picks "voice and subtitles only" gets the same
Lyra — the same events, the same voice, the same memory — just without the portrait. Her text
then appears in the subtitle bar or in a speech bubble at the bottom edge of the screen. It
also works after the fact: `/lyra figur aus`.

| | |
|---|---|
| **New** | Accessibility mode as a single switch (top of the panel, `/lyra barrierefrei an|aus`) — bar, speaker name, font size, display time, read-aloud, shape symbols in one go, with a complete way back |
| **New** | Warning level additionally as a shape: `o` hint, `^` warning, `^^` alarm. Can be switched off, on by default |
| **New** | "Voice and subtitles only": fourth option in the first-run assistant and `/lyra figur aus`. Lyra stays fully functional |
| **New** | Never two voices at once: if Blizzard's speech output or a screen reader is talking, Lyra defers her read-aloud until the other one has finished — instead of, as before, staying silent permanently just because the feature is switched on |
| **New** | Lyra can speak through Blizzard's own combat audio assistant (`C_CombatAudioAlert`) — on **all** clients, not just Retail. Then two voices cannot happen at all |
| **New** | Hold-your-tongue rule for **GTFO**: during a ground-effect alert Lyra does not chat (3 s, 6 s at the high alert level). Warnings still come through. No switch — a rule that can only make her quieter does not need one |
| **New** | Gamepad: conversation window and menu can be operated with **ConsolePort** |
| **New** | WeakAuras auras can now hang on exactly one Lyra event: `LYRA_EREIGNIS:HP20` as the trigger name, without a line of Lua. Older WeakAuras still get `LYRA_EREIGNIS` |
| **New** | `/lyra status` says what Lyra costs: memory per package and CPU time (the latter only when `scriptProfile` is running — otherwise it says how to measure it, instead of showing a 0) |
| **New** | Self-Found and Hardcore are detected via `C_GameRules` instead of guessed; `/lyra status` names the source and cleanly separates what the realm says from what your switch says. Lyra still does not set it herself |
| **Fixed** | The client switch hung on interface numbers. A Forever build with a number outside the expected range would have run as "TBC" — with combat-log behaviour locked, which there would have triggered a Blizzard error message with Lyra's name in it. It now falls back first to a runtime test (`C_RestrictedActions`) |
| **Fixed** | Lyra's read-aloud stayed silent permanently as soon as Blizzard's combat audio cues were merely **switched on**. Now what counts is whether someone is actually speaking right now |

Everything new lives in a single file (`Sinne/Welle6.lua`); about 180 new lines were added to
existing files, a good half of them comments and settings texts. Without GTFO, without
ConsolePort and without WeakAuras nothing happens, and `/lyra status` says honestly "not
installed". Test harness: 4 scripts, 555 checks, all green.

### Wave 7: Screenshot round — pulse, speech bubble, chronicle window, language switch

**Screen-edge warning rebuilt.** Instead of a hard white block there is now a soft glow at
the edge, with its own texture instead of a gradient API that is not reliable on Classic Era.
Three distinguishable levels: hint discreetly violet, warning stronger, alarm red-violet with
a short double beat. Never longer than a second. In Streamer mode the pulse stays off; in
accessibility mode it gets stronger rather than weaker, but with a larger gap between two
pulses.

**The speech bubble no longer truncates.** A long sentence next to the portrait used to end
with "…". Now it wraps — in every position. If there is no room left to the right or the left,
the bubble moves upwards instead of being pushed against the edge of the screen.

**The chronicle is a window.** `/lyra chronik` opens a window with the zones you have visited,
the close calls with date and place, the most dangerous enemies and the sessions — instead of
five lines in chat. Without character, guild or realm names: a screenshot of it does not give
away whose it is.

**Language switch without reloading.** `/lyra sprache de|en` switches the settings page, menu,
conversation and chronicle over immediately. Should part of it still need a `/reload` on some
client, Lyra says so in chat instead of keeping quiet about it.

**The subtitle bar carries the warning symbol** (`o` / `^` / `^^`) like the speech bubble. On
stream the warning level is therefore recognisable without colour too.

---

**Also in the same version:** the six wave 4 events now have voice recordings; `/lyra test <ID>`
bypasses the hourly budget like a click and "say something" do (previously it went mute after
15 tries); the speech bubble stays on screen via clamping; the bubble's edge tile is rotated
correctly (ladder pattern fixed); the generated `_Vanilla.toc` starts with a directive (12.0.7
rule); libs: LibStub, CallbackHandler-1.0, HereBeDragons-2.0 with a license note. Test harness:
45 runs, 3 201 checks, all green — and as of today inside the project instead of in /tmp
(`tests/pruefstand/`).

## 0.10.0 (2026-09-20)

### Wave 4: Everyday life II, Hardcore switch, signals

Six new events, none of them loud. Lyra says something at the crafting window about the first
bit of progress in a session and when a profession is at a trainer threshold; after a close
fight she reminds you once about bandages if there are none in your bags; she greets a switch
into or out of Hardcore mode with exactly one sentence; and she quietly keeps count of how many
nodes GatherMate2 has newly recorded today. On top of that she answers, on request, the four
big Era attunements — the prerequisite, never the route.

**The find of this round was hiding in an API nobody had asked about.** On Classic Era,
Enchanting and Beast Training do not run through `TRADE_SKILL_*` but through the old Craft API
with its own window and its own events. A profession moment that only listens to the crafting
window would have stayed permanently blind for mages with Enchanting — one of the most common
Era combinations there is. Lyra now listens to both.

**And Lyra is a signal source from now on.** After every line she sends the custom event
`LYRA_EREIGNIS` (ID, class, level) to WeakAuras. Anyone who wants to build their own aura on
Lyra's warnings needs three lines for it — the instructions are in `Sinne/WELLE4.md`. The old
`LYRA_GESTALT` still fires unchanged; existing auras do not break.

| | |
|---|---|
| **New** | `BERUF_ERSTER` / `BERUF_GRENZE`: one line for the first point of a session and at the trainer thresholds 75/150/225/300 (`TRADE_SKILL_*` **and** the Era Craft API) |
| **New** | `ERSTE_HILFE`: after a fight below half health (on Hardcore) or below a third, a chatter line (level 0, not a warning) when there is no bandage in your bags — once per session, and it is dropped if you have bought some in the meantime |
| **New** | `HC_MODUS_AN` / `HC_MODUS_AUS`: one line when the Hardcore state at login differs from the one last remembered. Once per switch, no setting needed |
| **New** | `GM2_KNOTEN`: counts new GatherMate2 nodes in the session; from the tenth onwards she may say something, after that at most every 30 minutes. The node is never named |
| **New** | `/lyra attunement [onyxia|mc|bwl|naxx]`: the prerequisite in three sentences. No route, no step-by-step |
| **New** | Custom event `LYRA_EREIGNIS` for WeakAuras, documented in `Sinne/WELLE4.md` |
| **New** | Four switches under *Fine-tuning → Everyday life II and signals*, all on by default |
| **New** | `/lyra status` says one line about wave 4: which profession API the client has, whether WeakAuras and GatherMate2 were detected and by which route |
| **Fixed** | The Hardcore line would have starved on the chatter spacing, because wave 4 gets the last login slot. Fourth find of the same pattern since review 5 — and again reproduced in the test harness, not noticed in the game |

Everything new lives in a single file (`Sinne/Welle4.lua`); about 50 new lines were added to
existing files, a good half of them comments and settings texts. Without WeakAuras and without
GatherMate2 nothing happens, and `/lyra status` says honestly "missing". Test harness: 34
scripts, 2099 checks, all green — 401 of them new.

**Also in the same package:** everything from 0.9.1 (below) — both states came about on the same
night, but only 0.10.0 is shipped. The six new events have **voice recordings** (15 German, 14
English takes, checked against Whisper); only lines with live values (`{beruf}`, `{wert}`,
`{anzahl}`) deliberately stay subtitle or read-aloud — a recording cannot insert a number.

## 0.9.1 (2026-09-19)

### Tidying up before the upload

No new features. This version closes the two points that the port 0.9.0 left open, and puts the
license and metadata texts in order — that is the part the CurseForge moderation reads.

**The worst find was a line that would have lied in conversation.** `UI/Dialog.lua` did already
read the target's level via `ns.Compat.unitLevelLesbar()`, but appended an `or 0` to it. On
Retail and Forever the level of a foreign unit in combat is a "secret value" — the helper returns
`nil` there, and `nil or 0` became **level 0**. From your own level 3 upwards that means "easy":
in combat Lyra would have rated every enemy whose level she cannot even read as harmless. The
right sentence had been sitting ready in `dialog.lua` the whole time ("I can't read its level.
That's rarely a good sign.") and was simply unreachable.

| | |
|---|---|
| **Fixed** | `UI/Dialog.lua`: an unreadable target level is "unknown" again instead of "easy" (`-- REVIEW9:`) |
| **Fixed** | `Lyra_Gestalt_Stimme_de` was the only one of the five packages with **no flavour lines** — on TBC, MoP and Retail Lyra would have been mute there, of all places in German |
| **Fixed** | All `## X-License:` lines referred to a file `LICENSE.md` that does not exist in the zip (what ships is `LICENSE` and `LICENSE-ASSETS.md`) |
| **Fixed** | `LICENSE-ASSETS.md` still listed the sprites under `Lyra_Gestalt/gestalt/*.png` — the folder has been called `bilder/` (and `bilder/rund/`) since 0.8.0 |
| **New** | Feature flag `C.F.gefahrenkarte`: the danger map is **off on Retail and Forever** |
| **New** | `/lyra status` now says one line about the danger map — cells, switch off, package missing or client does not match |

### The danger map stays silent on Retail and Forever

The cells in the package `Lyra_Gestalt_Daten` are aggregated **Hardcore deaths from Classic Era**.
Behind the same `mapID` there is a reworked zone without Hardcore on Retail, and on Forever a
world with reworked classes and mobs. Until now the lookup simply ran there too and **mostly**
found nothing — "mostly" is the gap: a cell that does hit is a false warning there, and a false
warning is worse than none at all. Exactly this reasoning has been sitting with the reagent
reminders since 0.9.0.

MoP Classic deliberately stays on: Vanilla Azeroth is the same world there, and the fall and water
cells — the majority — are terrain, not game content.

It is switched off **silently**: no notice at login, no line in chat. Whoever asks gets the reason
in `/lyra status`, along with the client profile.

### Small things

- The personal package still carried a real character name in the `charKey` field and the real
  account folder in its header, even though the comment above it already spoke of
  "Testheld-Testrealm". Both are anonymised now. **For your own machine:** in the copy under
  `Interface/AddOns/` your own `Name-Realm` has to be there, otherwise the loader ignores the
  package.
- `Sinne/BRUECKEN.md` named an absolute path containing the username of the development machine.
- Voice descriptions now say the same thing everywhere: synthetic, generated offline and **marked
  as AI-generated** (EU AI Act Art. 50).
- Test harness: two new scenes per client profile (danger map, conversation about the target),
  **1 698 checks** in 29 runs, all green. Both new scenes are counter-checked — with the old code
  they go red.

## 0.9.0 (2026-09-18)

### Lyra moves house — to five clients instead of one

Up to 0.8.0 Lyra ran on Classic Era. She ran well there, and nowhere else had ever been checked.
This version makes her multi-version capable: **Classic Era 1.15.9, Burning Crusade Anniversary
2.5.6, Mists of Pandaria Classic 5.5.4, Retail Midnight 12.1 and WoW: Forever.**

**And one piece of honesty up front, which the README states just the same:** what is tested **in
the game** is still only Classic Era. Everything else is built against Blizzard's own API
documentation (the branches `live`, `classic_era`, `classic_anniversary`, `classic` and
**`forever`** of `Gethe/wow-ui-source`) and against five client-profile mock-ups in the test
harness. Whoever starts Lyra on Retail or Forever first is the test.

**The finding that set off this round: WoW: Forever is not a Classic client but a mainline client
with Vanilla content.** Until yesterday `Core/Compat.lua` held the usual Questie rule "unknown
project ID ⇒ Classic path". On Forever that would have registered the combat log — and there it is
locked. At the first fight the player would have seen a Blizzard error message with Lyra's name in
it. That can no longer happen, and it does not matter which build number Forever gets for its
launch on 04.11.: the detection first checks the interface number and then falls back to a
**feature test** (`C_QuestLog.GetInfo` exists only in the mainline code family). The error
therefore always goes in the safe direction.

| | |
|---|---|
| **New** | `Core/Compat.lua` rewritten: client profile (`era`/`tbc`/`mists`/`retail`/`forever`), twelve feature flags, secret-value guards, questlog shim |
| **New** | **Read-aloud (text-to-speech)** for lines without a recording — `C_VoiceChat.SpeakText`, opt-in, off by default |
| **New** | Substitute bestiary without the combat log (`UNIT_COMBAT` + target/nameplate heuristics) |
| **New** | Multi-client TOCs: `## Interface-TBC/-Mists/-Mainline`, `enable-toc-creation: yes` |
| **New** | `docs/port-2026-09-18.md` — profile matrix, what is missing where, checklist for a real test |
| **New** | Five test-harness runs (one per client profile), 414 additional checkpoints |

### What is different on Retail and Forever

The two share a code base, so it is the same list.

- **The health warning works fully there.** `UnitHealth("player")` stays readable under secret
  values — that is exactly what Lyra is built around. `Sinne/Leben.lua` therefore needed **not a
  single line** changed.
- **The combat log is closed to addons**; since Retail 12.0 even the attempt to register throws.
  Lyra does not even try there. Her bestiary still counts encounters, close calls and deaths; it
  assigns damage via the current target, i.e. **by guessing** — with several enemies it guesses
  wrong, and the documentation says so. On Retail the bestiary is a side feature; rebuilding a
  damage parser for it would be the wrong work.
- **The level warning stays silent in combat**, because an enemy's level is a "secret value" there.
  The elite/boss warning stays, because a name is not a combat value.
- **The quest log has a different route** (`C_QuestLog.GetInfo` instead of `GetQuestLogTitle`,
  which has been removed on Retail since 9.0.1). Lyra's quest lines come just the same there.
- **Hardcore detection works on Forever** — it has `C_GameRules.IsHardcoreActive`, Retail does not.
  So legacy and memorial day live on there. That was the nicest surprise of the round.
- Questie only exists for Classic; the Questie depth is silent on Retail and Forever.

### Read-aloud (text-to-speech)

Lyra's own voice is pre-rendered. Lines with placeholders — a zone name, a number, your name —
cannot be pre-rendered, and those used to be **mute**. From 0.9.0 the operating system can read
them aloud: a different, robotic voice, but a voice.

The rule is deliberately narrow: lines **with** a recording are never replaced. Reading aloud only
happens when talkativeness is set to "normal" or "a lot" anyway, and **not** while Blizzard's own
combat audio cues or the screen narration are running — three voices at once are not three times as
helpful. A warning pushes to the front and throws the queue away.

**The default is off.** The voices come from the operating system (Windows SAPI, macOS); under
Linux/Wine there usually are none, and then read-aloud is simply silent. A feature that does not
run on the development machine must not be the default. The voice selection only appears in the
settings if the client reports at least one voice.

Settings: **Read lines without voice aloud** (off / only lines without a sound file / always) and
**read-aloud voice** (automatic or a specific one).

### Small things

- World holidays no longer hang on "is this Retail?" but on the game content. **Mists of Pandaria
  Classic now gets Brewfest and Pilgrim's Bounty**, which really do exist there.
- The campfire sense now reads the spell name via `C_Spell.GetSpellInfo` as well. On Retail/Forever
  it would otherwise have relied on the built-in name list — and would have found nothing at all on
  a French interface.
- The reagent reminder for mages and the ammunition reminder for hunters now only come on clients
  that know both (Vanilla, TBC). Since Cataclysm there have been neither teleport reagents nor an
  ammunition slot — the reminder would not be useless there, it would be wrong.
- The adds watch now queries foreign units inside `pcall`. It runs from a timer, and there is no
  safety net there.

### Known gaps

- **Whether `UNIT_COMBAT` delivers readable damage numbers on Retail/Forever nobody knows**, not
  even the documentation. If they are "secret", the bestiary there only counts encounters and
  deaths — without an error message, just with less content. That is the first item on the
  checklist.
- The Forever interface number `16001` is the **beta** number from 17.09.2026. The TOC therefore
  carries **no** `## Interface-Camelot:` line yet — a wrong version tag is worse than a missing one.
  Until then Forever loads the fallback TOC (with an "out of date" notice, but it loads), and the
  detection kicks in at runtime.
- `C_CombatAudioAlert.SpeakText` would be the better read-aloud route on Retail than
  `C_VoiceChat.SpeakText`. Without a Retail client there is no way to listen to it — wave 4.


## 0.8.0 (2026-09-17)

### Wave 3 — Lyra works together with your addons by saying less

The most-used addons do their job well. Details calculates better than Lyra, Questie shows better,
DBM is faster, GTFO is louder, Omen measures more precisely. What none of them has is a **memory
with an opinion**. That is exactly where this wave starts — and at the point where Lyra used to be
in the way.

**The most important change is a rule, not a feature: when DBM or BigWigs speaks, Lyra does not.**
DBM has its own countdown voices and counts down the last seconds of every timer. A second voice on
the same second is not twice as helpful, it is not helpful at all. From now on Lyra stays quiet
while a DBM sound is playing, while a timer is under ten seconds, while BigWigs is counting down and
while a boss encounter is running — the last one also **without** DBM and BigWigs, via Blizzard's own
encounter events.

**Warnings still come through.** The lock only brakes chatter; an HP20 warning in a boss fight
arrives. On Hardcore anything else would be a mistake with consequences. That is also why the rule
has no switch: it can only make Lyra quieter, never louder.

| | |
|---|---|
| **New** | `Sinne/DBM.lua` — hold-your-tongue rule + boss chronicle (attempts, kills, wipes, best time per boss), `/lyra bosse` |
| **New** | `Sinne/Details.lua` — one line after long fights, from **your own** numbers, `/lyra details` |
| **New** | `Sinne/Bedrohung.lua` — "you're pulling aggro even though there's a tank standing there" (native, without Omen) |
| **New** | `Sinne/Questie2.lua` — target zone and quest level on accepting, quest chain on handing in, `/lyra woran` |
| **New** | `Sinne/Persoenlichkeit.lua` — class, race, level, real clock time, favourite zone, the question from earlier |
| **New** | `docs/welle3-audit.md`, `Sinne/WELLE3.md`, `docs/phrasen-w3.json` (13 events, 18 lines on existing IDs) |
| **Changed** | `Sinne/Bruecken.lua`, `Sinne/Bruecken2.lua`: one `-- WELLE3:` line each — the old Details and threat blocks step back |
| **Changed** | `Core/Init.lua` (version, five keys), `UI/Settings.lua` (three checkboxes), `UI/Slash.lua`, locales, `Sinne/Extra.lua`, TOC |
| **Changed** | `docs/phrasen.json` — the 13 events and 18 lines are **merged**: **105 events**, `phrasen.lua` regenerated |
| **Renamed** | Texture folder `gestalt/` → **`bilder/`** (see below), all paths in Lua, tools and docs updated |

**The texture folder is now called `bilder/`.** Up to 0.7.0 the images lived in `gestalt/` and the
code in `Gestalt/`. Windows and macOS do not distinguish upper and lower case in file names in their
default settings: when the zip is **extracted**, the two folders merge into one, and which name wins
is decided by the order inside the archive. That is a bug that happens before the first login, only
on other people's machines and only on two out of three operating systems — in other words exactly
the kind you do not find but prevent. Code in `Gestalt/`, images in `bilder/`.

**`{klasse}` and `{rasse}` now speak Lyra's language, not the client's.** Anyone with a German
client who set Lyra to English read "There's my Magierin." — in six lines, among them the very first
one after logging in. Two small tables (9 classes, 8 races, keyed by the language-independent token
from `UnitClass`/`UnitRace`) now translate; if client and Lyra language match, the client name still
wins, because it is always correctly inflected.

**Lyra only names a number when it comes out of your own history.** Not "you're doing 143 damage per
second" — that is on the screen anyway — but "thirty per cent above your average", "you took more
than usual", "him again, third time". And at the very first kill of a boss, a sentence nobody else
says.

**Only your own value is read out of Details**, plus the nameless group sum for a percentage. It
never walks the actor list, never fetches a foreign actor, never stores or prints a player name.
That "there's a tank standing there" is something Lyra establishes without any name at all. In the
dry run every single Details access is logged and counter-checked.

**More personal means six new placeholders, not sixty new events.** `{klasse}`, `{rasse}`,
`{stufe}`, `{uhr}`, `{heimat}` and `{frage}` now hang on *every* existing line — the same route
`{erinnerung}` took in wave 1. On top of that: **familiarity also grows through interaction.** Until
now only playtime counted; a click now counts as a minute, a question as five, capped at 20 hours.
`/lyra stimmung` still shows the real hours — nobody is lying, the level just arrives earlier.

**No `Sinne/Omen.lua`, and that is deliberate.** Omen has no interface: its threat data is
file-local. Docking on would only work via its bar frames and would break silently at the next
layout change. The native API can do Era — Omen itself uses it unguarded. So `Sinne/Bedrohung.lua`,
native. Naming a file after an addon that it deliberately does not touch would be a lie in the file
name.

**DBM and BigWigs are not installed on this machine.** All callback names and argument positions are
documented from GitHub and from mock-ups in the dry run (153 checks, 14 scenes, 0 FAIL). Untested in
the game — the checklist is in `Sinne/WELLE3.md`.

## 0.7.0 (2026-09-17)

### Lyra tells stories from your own chronicle

Up to now Lyra said, across 92 events, what somebody wrote by hand for *everyone*: "You've been here
before. I remember, even if you don't." New is an optional data package
**`Lyra_Gestalt_Persoenlich`**, which contains sentences from your **own** chronicle — with the town,
the number of visits, the level, the length of the last sessions. Lyra mixes them in among the
built-in lines, in roughly one case out of three.

That is block **W1-H/W1-I** from `docs/redakteur-konzept.md` — the 12-to-16-hour version from the
appendix, so **without** a server, without a language model, without a bridge, without network code.
The point is the one question you want answered before another 150 hours: *does this feel good?*

| | |
|---|---|
| **New** | `addon/Lyra_Gestalt_Persoenlich/` (TOC, `persoenlich.lua` with 29 hand-written lines, README de/en) |
| **New** | `Sinne/Persoenlich.lua` — checks the package, mixes the lines in, `/lyra persoenlich` |
| **New** | `tools/persoenlich-vorlage.py` — produces the same package without a model, from SavedVariables |
| **New** | `Sinne/PERSOENLICH.md` — format, rules, director patch (Regie), checkpoints |
| **Changed** | `Core/Regie.lua`: three lines in `waehle()`, marked `-- PERSOENLICH:` |
| **Changed** | `UI/Slash.lua`: `/lyra persoenlich`; locales: 11 keys `Personal …` |

**Without the package nothing changes.** No wrapper, no error message, the same selection as in
0.6.2 — counter-checked in the harness with 200 runs. The package is **not** shipped with the addon:
it comes into being on your own machine, out of your own chronicle.

**Personal lines do not speak.** They have no pre-rendered OGG and will not get one. From that
follows the hard rule: **only `plauder` and `still` events, never a warning.** An HP20 warning has to
speak; a zone greeting may be read. The loader discards every line for a `warn` event, with a
reason, visible in `/lyra persoenlich`. The speech bubble appears anyway — even with subtitles
switched off, because no voice was played.

**What else the loader discards:** more than 120 characters, `|c` colour codes and other `|` escapes,
control characters, `{platzhalter}`, URLs, unknown events, lines belonging to another character, more
than 200 entries. A package with a foreign `charKey` or a foreign schema is **ignored, not deleted** —
it applies again as soon as the matching character plays.

**Privacy, as strict as ever:** the addon has no network code and will not get any. The package
contains only your own data. The character name appears exactly once, in the `charKey` field, serves
only for matching and is never printed — the sentences themselves contain no name, neither someone
else's nor your own.

**Installation note:** a **newly created addon folder** only shows up in the addon list after a
**restart of the client**. `/reload` is not enough. If only the contents of `persoenlich.lua` are
changed later, `/reload` is sufficient.

## 0.6.2 (2026-09-17)

### Design v3, part A — Lyra's picture, the speech bubble and what a warning looks like

**There is now really a face in the portrait.** Until now the addon cut a head section out of a large
image at runtime — with a mask, a fallback route in case the mask failed, an emergency switch for
that, and a self-test on top. And with **one fixed crop for all 29 expressions**, which was off for
seven of them: with "defeated" (the face she shows in death) and with "beaten down" you saw almost
nothing but an empty ring.

Instead, there are now 29 ready-made round images in the addon, each with the crop that fits that
expression. The addon sets one of them — nothing more happens. Mask, fallback, emergency switch,
self-test and all the arithmetic around them are gone without replacement; `/lyra maske` from now on
only says that this no longer exists.

**Lyra is bigger.** The portrait no longer hangs on the size of the whole figure but has its own
values: **96 / 112 / 128** pixels instead of 67 / 96 / 134, default 112. At a small UI scale, 96
units was an icon, not a face — with 29 expressions that is the wrong trade. `/lyra groesse <number>`
still affects both.

**A warning is now visible out of the corner of your eye too.** Until now only the ring colour
changed from violet to orange. Calculated, that change has a contrast of **1.01 : 1** — in greyscale
it is *exactly nonexistent*, and out of the corner of your eye, which is what it was for, so is it.
From now on the shape carries it:

| Level | What happens |
|---|---|
| Hint | a **symbol** on the left in the speech bubble |
| Warning | plus a **glow** around the portrait, calm |
| Alarm | the glow **pulses**, the ring becomes **twice as thick** |

Colour still comes on top — it is just no longer the only thing. Anyone who has turned motion off
still gets the glow, just without pulsing: it is the warning, not the decoration.

**The "!" in front of warning lines has become a symbol.** It ate two characters of width, moved
along on line breaks and appeared twice in the subtitle. Now an icon sits fixed to the left of the
text. In the **subtitle bar for streams the "!" stays as text** — a recording only shows what is in
the picture, and a symbol from a font Blizzard does not ship would be an empty box there. Fixed along
the way: an alarm line without the internal "warning" marker used to get **no** sign at all — and no
screen pulse either. Both now hang on the level.

**The speech bubble is wider, denser and positioned correctly.** It has its own frame instead of a
Blizzard texture that not one other addon in Classic uses; it is fully opaque instead of 97 %; it has
grown from 44 to around 56 characters per line (below 45 characters reading becomes strenuous); and
in the portrait it now always stands **beside** the circle instead of above it, with the tail at eye
level.

**Small things:** when the mouse moves away from Lyra, the hover expression stops immediately instead
of trailing for two seconds. New players now find Lyra **on the left at half height** — bottom right
she sat in the middle of the action bars in most setups. Anyone who has already moved her keeps their
spot.

Evidence, measurements and the open points for the play test: `docs/design-v3-A-umsetzung.md`. What
still has to be carried over into other windows: `docs/design-v3-A-patches.md`.

### Design v3, part B — type, menu, settings, the first impression

**The type is now the same size on every screen.** Until now there was a number in the settings, and
what became of it on the monitor was decided by the client's UI scale: the same "16" was **10 or 30
screen pixels** depending on the setting. New is "font size **automatic**" (default) — Lyra works out
how large a letter should *really* be and sets the number accordingly. Pull the UI slider and speech
bubble, conversation, menu and tooltip follow immediately. The slider stays and overrides at any
time; `/lyra schrift auto` switches back. Anyone who has already set their own size keeps it.

**The settings have 13 entries at the top instead of 33.** Everything you set once and then never
touch again — sound channel, bubble duration, combat transparency, the switches for screenshots,
ultra, streamer, legacy, Self-Found, map pins — has moved to its own subpage **"Fine-tuning"**. At
the top only the decisions you actually make remain. The screen pulse deliberately stays at the top:
it is the switch for light sensitivity, and that does not belong two clicks deep.

**New: motion.** Three levels instead of on/off.

| | What happens |
|---|---|
| **Full** | as before: breathing, nodding, the short jolt on a warning |
| **Reduced** | Lyra stands still; warnings still jolt, the warning glow lights up but does not pulse |
| **Off** | no motion at all, hard expression changes, no stirrings while idle |

For motion sensitivity — and for recordings in which nothing should be twitching in the background.

**A warning that a muted dialogue channel no longer swallows.** By default Lyra speaks on Blizzard's
dialogue channel. Anyone who pulls that to zero (many do, because of quest-giver babble) had thereby
unknowingly also switched off the audible part of the **death warning**. Alarms — below 20 % health,
drowning, falling — now always run on "Master". Everything else stays on the channel you set, and
anyone who switches the voice off entirely still switches it off entirely.

**Menu and conversation fade in softly** (eighty milliseconds, opacity only — nothing grows or jumps),
sit on the same edge as the speech bubble, and at the bottom there is finally the line that says the
**number keys** work: "1–9 · Esc closes". In combat it is pale, because they do not work there. The
menu title is noticeably brighter (the only text in the whole addon that was just below the
readability limit), and the small face in the menu and conversation header now shows **the same image
as Lyra herself** — including the expressions where an almost empty circle used to sit.

**Lyra's windows no longer fold into the quest tracker.** Menu and conversation now check whether
something is already in the place where they want to open — Questie, minimap, chat, Details — and
dodge to the other side. `/lyra position vorschlag` has Lyra look for a free spot herself.

**Anyone who has had Lyra for a while finally hears about the setup assistant.** It has existed since
0.3.0, but it only ran on a fresh installation — anyone coming from 0.2 never saw it. At the first
login after this update **a single line** now appears in the speech bubble: "I can show you how you
want me — `/lyra einrichten`." Plus the minimap button blinks three times. No popup, no second
prompt, no counter. Anyone who ignores it has ignored it.

**The assistant itself asks three questions instead of four.** The question about the view is gone:
it was the shortest path from "freshly installed" to a presentation that this set of images cannot
ship. The portrait remains the default; the whole figure is still available via double-click, via the
menu and via `/lyra figur`. And the last sentence now names the off switch (`/lyra still`) — that
belongs in the first minute, not in the FAQ.

**Small things:** the minimap button fills its frame (20 pixels instead of 18). "Reset position" no
longer pushes Lyra into the bottom right corner but to the new default spot. `/lyra maske` says that
the mask no longer exists, instead of silently doing nothing. Two colour tables and two frame recipes
that had to be maintained separately have collapsed into one each.

Measured with **265 checks** (previously 93), among them the automatic font size at five UI scales,
the panel with and without subpage support, the invitation exactly once, and the alarm on the right
sound channel. Details: `docs/design-v3-B-umsetzung.md`, open hand-overs:
`docs/design-v3-B-patches.md`.

### Integration — the two halves put together, and Lyra speaks in conversation

Team A and team B built in parallel. Whatever lay in the other team's files was left next to it as an
instruction. This round built it in, checked it and merged it.

**Lyra now talks when you address her, too.** She spoke every warning, but not a single word in the
conversation you opened yourself — dialogue texts went past the voice. From now on they have
recordings: the nodes of the conversation tree, the answers to free text (`/lyra danke`) and the three
"I don't understand that" lines. If you switch quickly through the nodes, the old line breaks off
instead of overlapping with the new one. **A warning never breaks off** and is never interrupted —
it keeps right of way in both directions. Lines with inserted values ("You're standing in
*Westfall*") stay mute; they cannot be recorded in advance. If a recording is missing, it is silent —
the window always comes.

**The subtitle bar no longer belongs to Streamer mode.** Until now one switch toggled the green tile,
the bar, the form of address and the screen-edge pulse together: anyone who only wanted subtitles had
to take the green tile along. Now there is a separate setting for it (**off / automatic / always**,
default automatic). "Automatic" means: the bar comes when Streamer mode is running, when Lyra is
hidden — then there is no speech bubble, and every spoken line still has to be readable — or when the
type comes out very small. On top of that it is **wider** (60 % of the screen instead of a fixed 900
pixels; on a 3440 that was a strip) and its **type follows the setting** instead of being fixed.

**The green tile is round when Lyra is round.** A square around a circle leaves the corners green and
eats away the soft ring edge. In the full figure it stays square.

**The screen-edge pulse never reaches for Blizzard's warning image again.** If a client could not draw
a gradient, the addon took as a substitute exactly the full-screen texture that the client itself
fades in below 20 % health — during an alarm two identical images then lay on top of each other, and
"the game is warning" could no longer be told apart from "Lyra is warning". The fallback has been
replaced: four solid-colour bands with a hard edge, narrower and paler than the gradient. Coarser,
but the **shape** distinguishes them — four edges are not a vignette.

**The speech bubble dodges the same things as menu and conversation.** If something is in the way on
the left *and* the right (Questie tracker, chat window), it goes upwards; if that is blocked too, it
lies on top instead of disappearing underneath.

**The tooltip on Lyra follows your font size** and its hint lines are a little brighter (contrast
8.97 : 1 → 10.41 : 1).

**One setting is touched once:** anyone who still has the old default font size 16 stored gets the new
automatic mode. It was never a conscious choice — it *was* the default. Every other value stays, and
it happens exactly once; if you set 16 again afterwards, it stays.

Measured with **351 checks** (previously 265) plus seven further harnesses, all without errors. New is
`tools/qa-dialogstimme.py`: it holds the voice catalogue and the dialogue data together — on the first
run it found three entries that still spoke the texts of the old four-part setup assistant. Details:
`docs/review7-2026-09-17.md`.

## 0.6.1 (2026-09-17)

### Fix round 5 — right-click and the new click bindings

**Right-clicking Lyra does something again.** In 0.6.0 it did nothing at all — no menu, no message,
nothing. The cause was a single swapped order in the new menu: the labels got their text *before* they
had a font. The client aborts that with a hard error ("FontString:SetText(): Font not set"), and it
does so in the middle of building the menu — so it never became visible. The error appears 18 times in
Harald's error log, every time by the same route: right-click on the figure → menu. Now every text runs
through one place that always sets the font first, and that font additionally has a net of two
fallbacks.

**And since right-click had to go on the table anyway, the whole binding is new:**

| On Lyra | up to 0.6.0 | from 0.6.1 |
|---|---|---|
| Left | line | line (unchanged) |
| Double left-click | settings | **portrait ⇄ whole figure** |
| Right | menu | **conversation** — with a monster targeted she starts right away with what she knows about it |
| Shift+right | – | **menu** |
| Middle | – | **silent mode on/off** |
| Mouse wheel | – | **size: small ⇄ medium ⇄ large** |

Talking is the thing you click her for — up to 0.6.0 the conversation was two clicks deep. The menu is
administration and moves to where administration belongs: **right-click on the minimap button** now
opens it (previously it jumped straight into the settings; those are still in there as the last menu
entry), plus shift+right-click on Lyra and `/lyra menue`. The menu appears **at the mouse pointer**
again — now that it also comes from the minimap button, "next to Lyra" would be the wrong place.

All of this uses its own, unprotected frames and therefore works **in combat too**.

Checked with 93 new checks that for the first time do *not* call the handlers directly but send a real
mouse click to a screen coordinate — with frame levels, sizes and hit testing. Held against the old
state, the same harness tears the bug open again. Details and evidence: `docs/fix5-2026-09-17.md`.

## 0.6.0 (2026-09-17)

### Fix round 4 — motion and portrait

**She no longer floats away.** That was the most stubborn bug in the project, and the third round had
repaired it in the wrong place. The finding from Harald's screenshot: the frame was correct — tooltip
and mouse area sat at the stored position — only her *image* had slid about 170 px above it. A
translation offset that is aborted mid-run stays behind as a pure drawing offset: no re-anchoring
removes it, no measurement sees it. And because breathing, like nodding, went upwards first, every
remainder was a little way up and never down.

That is why she no longer moves via animations at all, but the way Blizzard does it itself when the
real position has to be right: her position is **re-set** six times a second, never carried forward. A
value that is recalculated fresh every time cannot build up — and image and mouse area can no longer
drift apart.

- **Her face is back in the portrait.** The round crop is now produced via geometry instead of via a
  sub-section of the texture — the same construction Blizzard uses for its own round portraits.
- **The bobbing while speaking is calmer.** In the whole figure she nods 1 px in 1.2 seconds
  (previously 2 px in 0.35 seconds). In the portrait the image no longer moves **at all** — a
  thumb-sized head that bobs looks like trembling. Instead her ring slowly brightens and darkens while
  she speaks.
- **Warnings in the portrait:** a short flash of the ring and a small 2 px jolt, instead of the big
  jolt from the figure view.
- **New: `/lyra maske aus`** — if no face should appear in the portrait after all, this shows her
  square inside the ring right away. At startup she also checks for herself whether face and mask
  loaded, and says so instead of silently showing an empty ring.
- **New: `/lyra drift reset`** sets her motion layer hard to zero; `/lyra drift` now also shows motion
  state and self-test.
- The drift watch measures **always** again (up to 0.5.1 it waited for no animation to be running —
  but breathing ran constantly, so it never kicked in).

Checked with 31 new checks under four different assumptions about how the client handles aborted
animations — under every single one she is back exactly in her place after 300 speech bubbles, 50
jolts, 20 view changes and 10 layouts. Details and evidence: `docs/fix4-2026-09-17.md`.

## 0.5.0 (2026-09-17) — Lifelike, wave 1

**Lyra does not say more, she says more fitting things.** Almost everything here changes the
*selection* of existing lines, not the amount of talking.

- **She has a mood — and it is always explainable.** A close call, too many fights in a row, a
  memorial day: then she is *worried*, her face shows it, and she talks less. After a level-up or in
  the inn she is *cheerful*. Never rolled at random. `/lyra stimmung` writes the reason into chat.
- **She knows you longer the longer you play.** Four levels (0 / 10 / 50 / 100 hours,
  **account-wide**, AFK does not count). From level 1 she remembers earlier times ("last week in
  Westfall, when it got close"), from level 2 she gets personal. The counting is done by herself —
  never via `RequestTimePlayed()`, which would write into your chat.
- **She knows what time it is.** A different greeting in the morning, in the evening and at two
  o'clock at night.
- **Small rituals:** farewell on `/camp`, a line after ≥ 5 minutes AFK, the late hour, the anniversary
  of first sighting, the memorial day of a fallen predecessor, in-game holidays (Winter Veil,
  Hallow's End, Love is in the Air, Midsummer), a reply to your own emote (only without a target, at
  most three times per session) and the campfire.
- **New questions in conversation:** "what time is it", "how long have we known each other", "do you
  remember", "how is your mood".
- **New commands:** `/lyra stimmung`, `/lyra ssf` (solo self-found — then she stops mentioning trade,
  auction house and mail). The switch is also in the settings panel.
- **The limits stay:** no chat, no automation, no data from other players. Foreign emotes fail the
  GUID check, a player name is never stored.

**Warnings remain untouchable.** The new talkativeness rules only affect chatter. A worried Lyra does
not swallow an HP20 warning — not even during the five minutes of silence after a memorial line
(review 5).

## 0.4.0 (2026-09-17) — Bridges to other addons

**New: Lyra works together with your other addons.** None of them is a requirement — if one is
missing, she simply stays quiet at that point, and `/lyra status` says honestly "missing".

- **TomTom**: `/lyra punkt [title]` remembers the spot you are standing on — as a waypoint *and* as a
  note in the chronicle. `/lyra punkte` lists them, `/lyra punkte <n>` points the arrow at number n.
  Works in free text too: "merk dir die Stelle Erzader", "mark this spot".
- **Questie**: `/lyra such <name>` finds a mob and points the arrow at the nearest spawn — your current
  zone always wins. `/lyra quest <title>` finds the quest giver. If the one you are looking for has
  caught you before, she mentions it (`MOB_RIVALE_WARNUNG`). Free text: "wo ist Hogger", "wo bekomme
  ich …", "where is …".
- **!BugGrabber / BugSack**: Lua errors are "runes running wild" to Lyra. The first one comes
  immediately, after that at most every 10 minutes with a count; `/lyra runen` shows the last three.
- **DBM**: boss pull, kill, wipe and an **enrage pre-warning 20 s ahead**.
- **Threat** (native API, no Omen needed): whoever pulls aggro in the group hears about it — exactly
  once per fight. Never solo.
- New commands: `/lyra punkt`, `/lyra punkte`, `/lyra such`, `/lyra quest`, `/lyra runen`,
  `/lyra status` shows the partner addons that were detected.
- The limits stay: Lyra **shows and speaks**. She sets a waypoint because you asked — she moves
  nothing, presses no key and never writes into chat.

**The "direct" rule.** Everything that is an **answer to your question** comes immediately: no chatter
spacing, no hourly budget, no silent mode, and not even the 5-second lock after a loading screen holds
her back. One exception, deliberately: **after your death Lyra is silent for 60 seconds** — no matter
who asks. Only the question about your last words and her confirmation still come through there, and
those bypass the director (Regie).

**Fixes**

- **The name search no longer stutters.** The Questie name index (around 10 000 entries) used to be
  built in one go at the first `/lyra such` — exactly at the moment you asked. Now it runs in chunks
  of 500 entries across several frames.
- **Login schedule spread out.** After logging in, up to five lines want out (greeting, first login of
  the day, fallen predecessor, their last words, recap of the last session). The fixed timings did not
  fit the talking spacing: "first login today" lay 4 seconds next to the last words, was swallowed and
  was the only one without a second attempt — that line dropped out silently. Now the director (Regie)
  hands out slots, and every line gets its own place (6 s / 40 s / 74 s / 108 s / 142 s at "normal").
  The same when entering an instance: the travel check now reliably comes after the instance line.
- **A waypoint from the conversation window** sometimes carried the name from the question you *last*
  typed ("/lyra wo ist Hogger" … later a click on "set point" → waypoint "Hogger"). The redirect that
  caused this has been dropped without replacement.
- **Lyra no longer pulls faces while hovering when she is speaking.** The small stirrings (idle, mouse
  over) now dodge everything in one single place: a held expression, a standing speech bubble, an open
  conversation window and an open menu. Only dragging still startles her — but you did that yourself.
- **The DBM enrage timer** is registered under both callback names (`DBM_TimerStart` **and**
  `DBM_TimerBegin`), depending on the DBM version. The pre-warning still comes only once.
- The callback for the error messages can no longer disappear silently (the owner table stays on the
  module).
- Note coordinates are rounded to three decimal places — equally precise, noticeably smaller stored
  data.
- `docs/design-v2.md` 5.3 aligned with the data: **10 / 10 / 3** warning levels instead of 7 / 8 / 3.
  `HP50` explicitly stays "expression only": no text, no sound, no pulse.
- **WoW: Forever** (interface 16xxx) is detected as a Retail code base; the combat log stays unused
  there as it does on Retail 12.

All findings: `docs/review4-2026-09-17.md`.

## 0.3.1 (2026-09-17) — Fix round 3: floating and readability
- **Lyra no longer floats upwards.** Nodding and the warning jolt were on the same frame, and the
  emergency stop only reset the size, never the position: if a translation animation was aborted in
  the middle of the loop — and that happens at the end of every speech bubble — the offset reached
  stayed behind. Since both loops go upwards first, the remainder was always directed upwards and
  added up. Now the jolt has its own layer, the emergency stop re-anchors all layers, and before every
  start everything is stopped and cleaned up first.
- **Drift watch**: checks every 5 seconds whether one of Lyra's animation layers has wandered off
  (> 6 px when nothing is running) and resets it if necessary — with a message in debug mode.
- **The conversation window is dark now** like the right-click menu: Lyra's text bright, one size
  larger and **without the heavy outline** that made the letters run together. Answers sit on their
  own, fully opaque tiles with a golden number; under the mouse the tile brightens and the text turns
  white. High contrast: pure black/white, inverted under the mouse.
- **Speech bubble** stays light, but with darker text (#1A0F2E) and 96 % instead of 92 % opacity — the
  game image no longer shines through the type.
- **Subtitle bar** (streamer) from 60 % to 85 % opacity: on snow and in front of fire the bar had
  become so bright that white text on it fell below the target contrast.
- **Tooltip** on Lyra: title and hint line noticeably brighter.
- All text/background combinations have been recalculated with the WCAG formula and are above 7:1 —
  even over a bright game image. Table in `docs/fix3-2026-09-17.md`.

## 0.3.0 (2026-09-17) — Design v2, top 5
- **Portrait mode** (the new default): Lyra shows only head and shoulders in a round frame (96 px at
  "medium"), ring in Lyra's purple. The whole figure is still reachable via the settings, the
  right-click menu or `/lyra figur`.
- **Size presets** small/medium/large instead of a 27-step slider; free values still via
  `/lyra groesse <number>`.
- **Warning hierarchy in three levels**: 1 hint (bubble only), 2 warning (red edge, voice, short
  jolt), 3 alarm (plus screen-edge pulse). All 18 warning events assigned; an empty-potion notice no
  longer jolts like 12 % health.
- **The screen-edge pulse is violet now** and drawn by us — previously it lay pixel-identical on
  Blizzard's own low-health vignette. The breath alarm stays blue. Peak 0.45 instead of 0.6, duration
  0.9 s instead of 1.2 s, a 4-second lock between two pulses (light sensitivity).
- **Ground shadow** under her feet (only in the whole figure) — she no longer floats.
- **Idle micro-changes**: every 45–90 s a different expression for 2.5 s; mouse over → interested;
  moving her → startled. Never during an event, never in combat.
- **First-run assistant**: at the very first login Lyra asks four questions (language, form of
  address, talkativeness, view) in the familiar conversation window instead of a popup; afterwards the
  minimap button pulses three times. Repeatable with `/lyra einrichten`.
- **Readability of the speech bubble**: no more black outline on a light background (only in contrast
  mode), line spacing, width scales with the font size, display time depends on the length of the text
  (short lines stand in the way for a shorter time, long ones long enough).
- **Settings presets** quiet/normal/lively/streamer right at the top of the panel. The individual
  switches stay below; anyone who changes one sees "custom setting" — nothing is reset.
- New slash commands: `/lyra portrait|figur`, `/lyra klein|mittel|gross`,
  `/lyra preset leise|normal|lebendig|streamer`, `/lyra einrichten`.
- The warning jolt is no longer a scale animation but a translation (house rule since 0.2.1: no scale
  animations).

## 0.2.0 (2026-09-16)
- Chronicle: zone memory, close calls, bestiary, rituals (return, milestones, playtime).
- Danger map: your own close-call spots + optional data addon from the Deathlog database.
- Interaction: right-click menu, conversation tree, `/lyra <text>` with local understanding, silent mode.
- Design: breathing/nodding/crossfade, speech bubble with tail and fade, screen-edge glow, minimap button, combat transparency.
- 46 events, 76+ spoken lines de/en with variants for forms of address.

## 0.1.0 (2026-09-16)
- First scaffolding: director (Regie), figure, speech bubble, voice (LoD packages de/en), 29 senses, settings, slash.

## 0.2.1 (2026-09-17)
- Fix: the figure grew while the breathing animation was running until she disappeared (scale loop) — breathing is now translation, emergency stop at scale 1.
- Fix: the dialogue "More…" showed the same answers; lore reduced to 6 lines, rotation persistent, ends after 3 lines.
- Sprites repacked: 512×512, one frame per sheet, figure centred and feet aligned (no sliding on expression changes), 75 % less VRAM.

## 0.5.0 (2026-09-17) — lifelike
- State model (mood, familiarity 0/10/50/100 h, time of day, session, stress): the same events sound different depending on the state (`wenn` tags on lines, 25 state lines).
- Rituals: farewell on /camp, return after AFK, late at night, anniversary, remembrance of fallen predecessors, holidays, reaction to your own emotes (/hug, /wink …), campfire.
- Base mood extended by AFK/taxi/death/worried/cheerful/night; micro-stirrings according to familiarity.
- `/lyra stimmung`, `/lyra ssf` (solo self-found: no trade hints), intents time/how long/do you remember/mood.
- Group events (boss kill/wipe/pull/enrage, aggro, instance, travel check) carry `gruppeOk` and appear despite "stay silent in a group"; boss kill/wipe are chatter with a throttle again.

## 0.5.1 (2026-09-17) — client fixes from Harald's screenshot
- The portrait was invisible (only the ring): our own PNG mask did not load → Blizzard's TempPortraitAlphaMask.
- Drift of the animation layers: a single anchor (CENTER) instead of SetAllPoints; the drift watch now measures always (breathing runs constantly) and resets hard.
- Speech bubble: Blizzard's bubble texture is dark → bright text, opaque dark purple background.
- Nodding while speaking is gentler (1 px, 1.2 s). New: `/lyra animation aus|an`, `/lyra drift` (diagnostics).

## 0.6.0 (2026-09-17) — Abilities wave 2
- Emergency buttons: at HP35/HP20 Lyra says which rescue spell is ready (per class), or how long it is still asleep; she learns which buttons are never used (`/lyra cooldowns`, the question "what is ready").
- Class advice as a data table (mage from klassenrat/magier.md, general HC advice), `/lyra rat`.
- Quest progress natively: objective done, almost finished, quest complete, hand-in nearby (with Questie data), `/lyra quests`.
- Play-style profile: fights, low points, false-alarm rate → style cautious/normal/daredevil as the `wenn` tag `stil`, `/lyra profil`, can be switched off.
- Map: your own close-call spots and notes as pins on the world map/minimap (HereBeDragons pins, if an addon provides them), `/lyra karte`; raid marks via `/lyra mark [skull|kreuz|1-8]` and "mark the target".
- Bridges 2: Lyra events as the WeakAuras custom event `LYRA_GESTALT`, Pawn upgrade hint on your own loot, Details damage record.
