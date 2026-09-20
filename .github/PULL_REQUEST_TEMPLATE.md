<!-- Kurz halten. Wer hier viel ausfuellen muss, schickt den Patch nicht. -->

**What does this change, in one sentence?**


**Why?** (a bug number, a report, or "it bothered me")


---

- [ ] I read `CONTRIBUTING.md`.
- [ ] **No automation.** Nothing here presses a key, moves, casts or targets for the player.
- [ ] **No data about other players.** No names, no whispers, no group members, no addon
      communication channel, no chat output, no network access.
- [ ] `/lyra debug` still prints no character, guild, account or channel name.
- [ ] I did not add a third-party library (that needs an issue first — it is a licence
      question before it is a code question).

**Tested on:** <!-- e.g. Classic Era 1.15.9, German client, fresh SavedVariables -->

<!--
Heads-up, so it does not surprise you: the addon code in this repository is generated
from a development monorepo by tools/release-sync.sh, and the next sync overwrites it.
Your patch is merged back by hand — that works, it just means the diff may look
different once it lands. Please name the files you touched above if the diff is large.

Every pull request runs the packager as a dry build (gate + test-build). Nothing in
this repository uploads anything automatically; releases are started by hand.
-->
