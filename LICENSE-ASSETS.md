# Licenses — art, voice, sound cues, data

The **code** of this addon is MIT-licensed — see `LICENSE`.
The files described below are **not** covered by that license.

---

## Sprite art — `Lyra_Gestalt/bilder/*.png` and `Lyra_Gestalt/bilder/rund/*.png`

Derived from the "Mage Extended" set by **Prometheus Pictures** under its
**Extended License** (commercial use and modification permitted).

The set is **licensed, not free**. The sheets are bundled **solely as part of this
addon**, in the cropped and resized form the addon uses. Extracting the artwork,
redistributing the source files, reselling them or reusing them in other projects
is **not permitted** — neither by this license nor by ours.

License reference: the twelve license files of the purchased set (Prometheus Pictures,
"Mage Extended", Extended License, one per spectrum) are included in
`Lyra_Gestalt/LICENSES/sprites-mage-extended/`.

## Voice — `Lyra_Gestalt_Stimme_de/stimme/*.ogg`, `Lyra_Gestalt_Stimme_en/stimme/*.ogg`

Synthetic speech, generated offline with an AI text-to-speech model (Chatterbox,
Resemble AI, MIT) and **labelled as AI-generated** in line with **EU AI Act Art. 50**.

All rights reserved. These files are licensed for use only as part of this addon.
Extracting, redistributing, reselling or reusing them in other projects is not
permitted. Not for reuse outside this addon.

Reference material used for rendering is not part of this package. The voice files are bundled solely as part of this addon and may not be extracted, reused or redistributed separately.

## Sound cues — `Lyra_Gestalt/laute/*.ogg`

Rendered with [Piper](https://github.com/rhasspy/piper) (MIT), voice
`de_DE-ramona-low`. Piper is MIT-licensed; the voice model is distributed with Piper under its own model card (see the Piper voices repository).

## Danger map data — `Lyra_Gestalt_Daten/`

**GNU General Public License v3.0** — full text in `Lyra_Gestalt_Daten/LICENSE`.

This folder contains aggregated data derived from the public Deathlog database
(<https://github.com/Deathwing/Deathlog>, © Yazpad / Deathwing, GPLv3) and is
distributed under the same license. It contains **no character names, no guild
names and no last words** — only aggregates per map grid cell.

The core addon `Lyra_Gestalt` is separate from it; it only reads the global table
`LyraGestalt_Daten`.

## Embedded libraries — `Lyra_Gestalt/Libs/`

Four third-party libraries travel with the addon, **unmodified**, and none of them is
a hard dependency — the addon runs without any of them.

| Library | Rev. | Licence |
|---|---|---|
| LibStub | 2 | Public Domain |
| CallbackHandler-1.0 | 8 | BSD (Ace3 style) |
| HereBeDragons-2.0 | 33 | BSD 3-Clause |
| HereBeDragons-Pins-2.0 | 17 | BSD 3-Clause |

Full licence texts, revisions and the source each copy was taken from:
`Lyra_Gestalt/Libs/LICENSE.txt`.

**Not embedded any more: LibDataBroker-1.1.** Up to 0.13.0 a copy shipped with the
addon. **It was removed in 0.14.0**, because the library's own project page states
*"All Rights Reserved unless otherwise explicitly stated."* — which does not cover
redistribution. Lyra still looks LibDataBroker up through LibStub and registers her
data object if a display addon (Titan Panel, ElvUI data texts, ChocolateBar, a button
collector …) brought the library along. If nothing brought it, she creates no data
object and nothing is missing. Details: `Lyra_Gestalt/Libs/LICENSE.txt`.

---

---

Lyra Gestalt is an independent fan project and is **not affiliated with or endorsed
by Blizzard Entertainment, Inc.** World of Warcraft and Blizzard Entertainment are
trademarks of Blizzard Entertainment, Inc. No Blizzard audio, artwork or other
game asset is shipped with this addon.
