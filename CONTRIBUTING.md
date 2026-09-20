# Contributing

Short version: **translations and phrase suggestions are the two things that help
most.** Code contributions are welcome too, but Lyra has two hard rules that no
patch can bend.

## The two rules

1. **No automation.** Lyra never presses a key, never moves, never casts, never
   targets. She reads the public AddOn API, she shows, she speaks. A patch that
   acts for the player will be closed, however useful it is.
2. **No data about other players.** No names, no whispers, no group members, no
   addon communication channel, no chat output. There is no network code in this
   addon and there will not be.

`/lyra debug` must never print a character, guild, account or channel name. If a
patch adds something to that output, it has to survive that test.

## Reporting a bug

Use the **Bug report** template. The `/lyra debug` block is mandatory — it carries
version, client build, locale, loaded voice packs and the last events, and nothing
that identifies you.

If the voice is silent, restart the game client completely before reporting. WoW
only finds sound files that were present in the AddOns folder when the client
started; a `/reload` is not enough.

## Suggesting a phrase

Use the **Phrase suggestion** template, or say it in `#ideas` on Discord: <https://discord.gg/pXjy8RJ5Cv>

Lyra's lines are not in the Lua files — they come from **`phrasen.json`**, which is
the source of truth for both `phrasen.lua` and the pre-rendered voice files. One
entry per event looks like this:

```json
{
  "id": "LOGIN",
  "klasse": "plauder",
  "stufe": 0,
  "miene": "happy",
  "halte": 15,
  "cue": "hihi",
  "drossel": "session",
  "exag": 0.5,
  "texte": [
    { "de": "Ich war die ganze Zeit hier. Ehrlich. Fast.",
      "en": "I was here the whole time. Honestly. Almost.",
      "v": true }
  ]
}
```

| Field | Meaning |
|---|---|
| `klasse` | `plauder` (chatter), `still` (subtitle only), `warn` (warning) |
| `stufe` | warning level: 0 none, 1 hint, 2 warning, 3 alarm — drives bubble border, jolt and screen pulse |
| `miene` | which of the ~30 expressions she wears |
| `exag` | expressiveness for the voice renderer |
| `v: true` | this line gets pre-rendered to voice. Only possible **without** placeholders |

What makes a line usable:

- **Short.** Roughly 120 characters. It has to fit a speech bubble and be readable
  in half a second.
- **Both languages**, or English alone and we translate.
- **No placeholders** if it should be spoken — the renderer speaks a fixed
  sentence. The one exception is the address token `{Held|Heldin}` /
  `{mein Lieber|meine Liebe}`, which is resolved per setting and rendered in both
  variants.
- **No colour codes, no URLs, no control characters, no names.**
- **Warnings are not jokes.** A `warn` line has to be useful before it is clever.
  Chatter may be funny.
- **Written by you.** Not a quote from the game, a film or another addon.

Accepted lines are rendered to voice in the next release and the author is credited
in the chronicle of supporters.

## Translating

Lyra's interface strings and her phrases are fully localizable. English and German
are complete; everything else is open.

- **Interface and phrase text:** the **Localization** tab of the CurseForge project.
  That works without a GitHub account and is the preferred way. Namespaces: `ui`,
  `phrasen`, `zonen`.
- **In this repo:** `Locales/enUS.lua` and `Locales/deDE.lua` hold the UI strings.
  A new language is a new file with the same keys.
- **Voice is a separate matter.** Only German and English are recorded. A new voice
  language needs a fully translated phrase set **plus** a TTS voice with a clean,
  documented license. Please talk to us before you start rendering — we will help,
  and we would rather not have to reject finished work over its license.

## Code

- The repo layout is what the BigWigs packager needs: the main TOC in the root, the
  extra addons under `Pakete/`. It is **generated** from a development monorepo by
  `tools/release-sync.sh`, so a patch here is merged back by hand. That also means:
  editing addon code in this tree works, but the next sync overwrites it — say in the
  pull request which files you touched.
- **Four embedded libraries, and no framework.** `Libs/` holds LibStub,
  CallbackHandler-1.0 and HereBeDragons-2.0 (+Pins), byte-identical copies, none of
  them a hard dependency — the addon runs without any of them. There is no Ace3.
  Licences and provenance: `Libs/LICENSE.txt`. **Please do not add a library** in a
  pull request; open an issue first, because every added file is a licence question
  before it is a code question.
- File names stay **ASCII**. The client does not load non-ASCII paths reliably on
  every system.
- Every pull request runs the packager as a dry build. If that fails, the release
  would have failed too.

## Licenses

Code is MIT (`LICENSE`). Art and voice are **not** free — see `LICENSE-ASSETS.md`.
The danger map data is GPLv3 (`Pakete/Daten/LICENSE`). By contributing code you
agree to it being published under MIT.
