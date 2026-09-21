-- Locales/enUS.lua — UI-Strings (Settings, Slash). Phrasen liegen in phrasen.lua.
local ADDON, ns = ...
ns.locales = ns.locales or {}
ns.locales.enUS = {
    -- W8: der ANZEIGENAME. Der Schluessel bleibt "Lyra Gestalt" - er steckt in UI/Settings.lua,
    -- UI/Menue.lua und UI/Minimap.lua und ist ein interner Name, kein Text. Der WERT ist seit
    -- dem 20.09.2026 "Lyra Companion": so heisst das Addon ueberall sonst (TOC-Title
    -- "Lyra - Arcane Companion", Website, CurseForge), nur die Einstellungsseite und der
    -- Eintrag in Blizzards Addon-Liste trugen noch den alten Namen (Screenshot 06).
    -- In beiden Sprachen gleich: ein Produktname wird nicht uebersetzt.
    -- NICHT umbenannt werden interne Namen: Ordner Lyra_Gestalt, LyraGestaltDB, LyraGestalt_*.
    ["Lyra Gestalt"] = "Lyra Companion",
    ["Language"] = "Language", ["Auto"] = "Auto", ["German"] = "German", ["English"] = "English",
    ["Address"] = "How Lyra addresses you", ["By character"] = "By character", ["Male"] = "Male", ["Female"] = "Female", ["No address"] = "No address",
    ["Voice"] = "Voice", ["Voice enabled"] = "Voice enabled", ["Sound channel"] = "Sound channel", ["Subtitles"] = "Always show text",
    ["Talkativeness"] = "Talkativeness", ["Silent"] = "Silent", ["Little"] = "Little", ["Normal"] = "Normal", ["Chatty"] = "Chatty",
    ["Combat: warnings only"] = "In combat: warnings only", ["Quiet in groups"] = "Quiet in groups and raids",
    ["Cheeky humor"] = "Cheeky humor", ["Bubble duration"] = "Speech bubble duration (s)", ["Font size"] = "Font size", ["High contrast"] = "High contrast",
    ["Scale"] = "Size", ["Locked"] = "Lock position", ["Reset position"] = "Reset position", ["Hidden"] = "Hide Lyra",
    ["Sound cues"] = "Little sounds (hmm, oh, hihi)",
    ["Test"] = "Say something",
    ["Loaded"] = "loaded. /lyra opens the settings.",
    ["voicepack missing"] = "voice pack not installed: ",
    -- Settings: section headers, tooltips
    ["Language and address"] = "Language and address", ["Behavior"] = "Behavior", ["Figure"] = "Lyra's figure", ["Try it"] = "Try it",
    ["Dialog volume"] = "Dialog volume", ["Dialog volume tip"] = "Blizzard's dialog channel volume. Applies when the sound channel is set to Dialog.",
    ["Test tip"] = "Lyra says an idle line right now (the usual pause between lines is skipped).",
    ["Test silent"] = "Lyra stayed silent: ", ["Reset position tip"] = "Moves Lyra back to the left edge of the screen at half height - free space in almost every UI layout.",
    -- Slash
    ["Status"] = "Status", ["yes"] = "yes", ["no"] = "no", ["not loaded"] = "not loaded",
    ["Combat"] = "In combat", ["Group"] = "In group", ["Voice pack"] = "Voice pack", ["Version"] = "Version",
    ["Position reset"] = "Position reset.", ["Size range"] = "Size must be between 0.2 and 1.5.",
    ["Debug on"] = "Debug on.", ["Debug off"] = "Debug off.", ["Drop log"] = "Last drops (reason, event, time):", ["Drop log empty"] = "no drops yet",
    ["unknown command"] = "Unknown command. /lyra help",
    ["Help text"] = "/lyra - open settings\n"
        .. "/lyra lang de|en|auto - language\n"
        .. "/lyra address m|f|none|auto - how Lyra addresses you\n"
        .. "/lyra mute - voice on/off\n"
        .. "/lyra silent|little|normal|chatty - talkativeness\n"
        .. "/lyra group - quiet in groups on/off\n"
        .. "/lyra portrait | figure - switch view\n"
        .. "/lyra small | medium | large - size\n"
        .. "/lyra size 0.2-1.5 - free size\n"
        .. "/lyra preset quiet|normal|lively|streamer\n"
        .. "/lyra setup - first-run wizard\n"
        .. "/lyra schrift auto|10-28 - font size\n"
        .. "/lyra bewegung voll|reduziert|aus - motion\n"
        .. "/lyra leiste aus|auto|immer - subtitle bar\n"
        .. "/lyra lock - lock position on/off\n"
        .. "/lyra hide | show - hide or show Lyra\n"
        .. "/lyra position reset|vorschlag - position\n"
        .. "/lyra test - say something\n"
        .. "/lyra status | debug | help",
    ["Combat transparency"] = "Transparency in combat", ["Screen glow on warnings"] = "Screen edge glow on warnings", ["Minimap button"] = "Minimap button",
    -- Interaction: menu, dialog, free text
    ["Say something"] = "Say something", ["Ask me"] = "Ask me", ["Quiet mode"] = "Quiet mode",
    ["Lock"] = "Lock position", ["Unlock"] = "Unlock position", ["Hide"] = "Hide Lyra", ["Settings"] = "Settings",
    ["Hidden hint"] = "Lyra is hidden. /lyra show brings her back.",
    ["Quiet on"] = "Quiet mode on: warnings only. Middle-click Lyra, Shift+right-click or /lyra menu to turn it off.",
    ["Quiet off"] = "Quiet mode off.",
    ["Note saved"] = "Note saved to the chronicle.", ["Notes"] = "Notes",
    -- W7: language switch without /reload - honest feedback in chat.
    ["Language switched"] = "Language: %s. Settings page, menu, conversation and chronicle are updated - no /reload needed.",
    ["Language switched simple"] = "Language: %s. Menu, conversation and chronicle are updated.",
    ["Language partial"] = "Language: %s. Menu, conversation and chronicle are updated. These settings labels only change after /reload: %s",
    ["Chronicle missing"] = "No chronicle summary available yet.",
    -- W7: chronicle window (/lyra chronicle). No character or guild names, screenshot-ready.
    ["Chronicle"] = "Chronicle",
    ["Chronicle zones"] = "Zones",
    ["Chronicle close calls"] = "Close calls",
    ["Chronicle bestiary"] = "Bestiary",
    ["Chronicle sessions"] = "Sessions",
    ["Chronicle empty"] = "Nothing written down yet. Lyra starts once you head out.",
    ["Chronicle visits"] = "visited %dx",
    ["Chronicle zone near"] = "visited %dx, %dx close",
    ["Chronicle hits"] = "%d hits, hardest %d",
    ["Chronicle rival"] = "%dx near-death, %dx death",
    ["Chronicle session"] = "%d sessions, this one since %s",
    ["Chronicle more"] = "… and %d more",
    ["Esc hint"] = "Esc closes",
    ["Dialog missing"] = "Dialog data not loaded.",
    ["Help text 2"] = "/lyra menu - Lyra's menu (also: shift+right-click Lyra, right-click the minimap button)\n"
        .. "/lyra ask - talk to Lyra (also: right-click Lyra; keys 1-4, Esc closes)\n"
        .. "/lyra chronicle - chronicle summary\n"
        .. "/lyra note: <text> - diary entry\n"
        .. "/lyra <anything> - just ask her",
    -- Design: figure tooltip, minimap button, settings (kampfAlpha, glow, minimap)
    -- FIX5: new click mapping 0.6.1 (two tooltip lines, one would be too long)
    ["Tooltip hint"] = "Left: a line · Double-click: portrait/figure · Right: talk",
    ["Tooltip hint 2"] = "Shift+Right: menu · Middle: quiet mode · Wheel: size · Drag: move",
    -- REVIEW2: Duplikate "Quiet mode"/"Combat transparency"/"Minimap button" entfernt (letzter Eintrag gewinnt; Menue zeigte "quiet mode")
    ["Minimap hint"] = "Left: show/hide Lyra · Right: Lyra's menu (settings are in there) · Drag: move button",
    ["Lyra hidden"] = "Lyra is hidden", ["Lyra visible"] = "Lyra is visible",
    ["Combat transparency tip"] = "Lyra becomes more transparent in combat (100% = unchanged).",
    ["Screen glow"] = "Screen edge warning", ["Screen glow tip"] = "Short pulse at the screen edge on low health, low breath and falls. Turn off if you are sensitive to flashing.",
    ["Danger map"] = "Danger map (Deathlog data pack)",
    -- Feature wave 1: travel check lists, toggles, legacy, test (Sinne/Extra.lua, Sinne/Erbe.lua, UI/Streamer.lua)
    ["potions"] = "potions", ["bandages"] = "bandages", ["repair"] = "repairs", ["ammo"] = "ammo", ["reagents"] = "reagents",
    ["Photos"] = "Photos", ["Photos tip"] = "Screenshot at every tenth level and when you survive a fight below 20% health (max. one per 2 minutes).",
    ["Ultra mode"] = "Ultra mode", ["Ultra mode tip"] = "Lyra's face follows your health in combat - for players with hidden health bars.",
    ["Streamer mode"] = "Streamer mode", ["Streamer mode tip"] = "Green chroma tile behind Lyra (round in portrait view) and no address. The subtitle bar is its own setting since 0.6.2 - \"Automatic\" switches it on here anyway.",
    ["Self-found"] = "Solo Self-Found (no trade hints)",
    ["Self-found tip"] = "Lyra stops mentioning trade, auction house, mail and group finding. For solo self-found runs.",
    ["Mood"] = "Mood", ["Mood tip"] = "How Lyra feels right now: mood, familiarity, time of day. /lyra mood prints it to chat.",
    ["Legacy day"] = "Day of remembrance", ["Holiday"] = "Holiday",
    ["Legacy also outside Hardcore"] = "Legacy also outside Hardcore", ["Legacy tip"] = "Lyra remembers a death of this character even without Hardcore mode (for testing).",
    ["Last words prompt"] = "What should the next one know? Tell me: /lyra <your words>",
    ["Last words saved"] = "Last words saved. I'll carry them on.",
    ["Legacy list"] = "Legacy (your own fallen characters):", ["Legacy empty"] = "Legacy: nobody has fallen yet.",
    ["Test running"] = "Test running: all warnings every 4 s. /lyra test stop cancels.", ["Test stopped"] = "Test stopped.",
    ["unknown event"] = "Unknown event:",
    -- REVIEW6B: Welle-2-Befehle standen in keinem Hilfetext.
    ["Help text 3"] = "/lyra test <ID> | all | stop - play an event\n"
        .. "/lyra photo | ultra | streamer - toggles\n"
        .. "/lyra legacy - fallen predecessors (your own characters)\n"
        .. "/lyra personal - state of the personal lines (Lyra_Gestalt_Persoenlich)\n"
        .. "/lyra cd - emergency buttons and cooldowns\n"
        .. "/lyra quests - quest progress\n"
        .. "/lyra profile - your playstyle profile\n"
        .. "/lyra advice - class advice\n"
        .. "/lyra mark <skull|cross|1-8> - raid mark on your target (monsters only)\n"
        .. "/lyra pins - refresh map pins (needs HereBeDragons)\n"
        .. "/lyra details [on|off] - what I read out of Details\n"
        .. "/lyra bosses [on|off] - your boss chronicle (attempts, kills, best time)\n"
        .. "/lyra questie [on|off] - target zone, quest level and chain from Questie\n"
        .. "/lyra doing - what you are working on right now",
    -- Design v2: presets, view, size, first-run wizard
    ["How should Lyra be?"] = "How should Lyra be?",
    ["Preset"] = "Preset",
    ["Preset quiet"] = "Quiet - warnings, otherwise silence",
    ["Preset normal"] = "Normal - warnings and the occasional remark",
    ["Preset lively"] = "Lively - she likes to talk",
    ["Preset streamer"] = "Streamer - subtitles, chroma tile, no screen pulse",
    ["Preset custom"] = "Custom",
    ["Preset tip"] = "Sets several switches at once (talkativeness, combat, groups, little sounds, humor, screen pulse, streamer). Change a single switch afterwards and this reads \"Custom\" - nothing is reset.",
    ["View"] = "View",
    ["View portrait"] = "Portrait (head only, round)",
    ["View figure"] = "Full figure",
    ["View tip"] = "Portrait shows only Lyra's face in a round frame - small, easy to read, and the safe choice for streams and screenshots. You can switch any time, also by double-clicking Lyra.",
    ["Size preset"] = "Size",
    ["Size small"] = "Small", ["Size medium"] = "Medium", ["Size large"] = "Large",
    ["Size preset tip"] = "Portrait: 96 / 112 / 128 pixels. Full figure: 179 / 256 / 358 pixels tall. Fastest: the mouse wheel over Lyra; values in between: /lyra size <number>.",
    ["Setup wizard"] = "First-run wizard",
    ["Setup wizard tip"] = "Lyra asks the three setup questions again (language, address, talkativeness). Also available as /lyra setup.",
    ["Playstyle profile"] = "Playstyle profile (learns)", ["Map pins setting"] = "Map pins (close calls, notes)", ["No mark target"] = "No target or a player - I only mark monsters.", ["Map pins"] = "%d points on the map.",
    ["Repeat last"] = "Repeat last line", ["Nothing to repeat"] = "Nothing said yet.", ["Arcane mage"] = "Arcane mage",
    -- design-v3 team B (0.6.2): subcategory, automatic font size, motion, key hints, invitation
    ["Fine tuning"] = "Fine tuning",
    ["Readability"] = "Readability",
    ["Data sources"] = "Data sources and partner addons",
    ["Font size auto"] = "Automatic font size",
    ["Font size auto tip"] = "The text follows your client's UI scale: Lyra works out how many screen pixels a letter should have (22) and sets the size accordingly - the same size on every monitor. Off = you set it yourself.",
    ["Font size tip"] = "In UI units, 10 to 28. Applies to the speech bubble, the conversation, the menu, the tooltip and the subtitle bar.",
    ["Sound channel tip"] = "Which channel Lyra speaks on. Alarms (below 20% health, drowning, falling) always use \"Master\" regardless - a muted dialog channel must not swallow a death warning.",
    -- REVIEW7 / DESIGN-V3 B-8: subtitle bar, decoupled from "streamer"
    ["Subtitle bar"] = "Subtitle bar",
    ["Subtitle bar off"] = "Off",
    ["Subtitle bar auto"] = "Automatic",
    ["Subtitle bar always"] = "Always",
    ["Subtitle bar tip"] = "The large bar at the bottom of the screen that a recording can read too. Automatic means: on when streamer mode is running, when Lyra is hidden (no speech bubble then), or when the font comes out very small. Streamer mode does not change this setting.",
    ["Motion"] = "Motion",
    ["Motion full"] = "Full - breathing, nodding, jolt",
    ["Motion reduced"] = "Reduced - only on warnings",
    ["Motion off"] = "Off - Lyra stands still",
    ["Motion tip"] = "Reduced: no breathing, no nodding, no pulsing - the warning halo stops pulsing too (it stays visible, it carries the warning level). The short jolt on a warning stays. Off: no motion at all, no idle expressions, hard expression changes. For motion sensitivity and for recordings.",
    ["Keys hint"] = "1-%d · Esc closes",
    ["Position suggested"] = "Suggestion: %s (%d, %d). /lyra position reset restores the default.",
    -- B-11: the ONE line for existing users. No popup, no second attempt.
    ["Invite setup"] = "You can show me how you want me - /lyra einrichten, takes a minute.",
    -- 0.7.0: /lyra personal (Sinne/Persoenlich.lua, data package Lyra_Gestalt_Persoenlich)
    ["Personal title"] = "Personal lines:",
    ["Personal missing"] = "The package Lyra_Gestalt_Persoenlich is not loaded. Without it I say exactly what is built in - nothing is wrong.",
    ["Personal restart"] = "Just dropped it in? A new addon folder only shows up after a full client restart; /reload is not enough.",
    ["Personal inactive"] = "Package found but not in use (%s).",
    ["Personal active"] = "Package loaded: %d lines, mixed in with weight %d.",
    ["Personal events"] = "Events: %s",
    -- W9: made accurate again (AI audit L2). Until 0.12.0 this said "never with voice", which
    -- stopped being true in 0.9.0 when the reading-aloud layer started speaking every line
    -- without a recording. Gestalt/Stimme.lua now skips personal lines, so the promise holds -
    -- and the sentence names the switch that lifts it.
    ["Personal voiceless"] = "Personal lines are shown, never read aloud, and never used as a warning. If you want it the other way round: \"Read personal lines aloud too\" in the fine settings.",
    ["Personal origin"] = "Created %s, source %s, character %s.",
    ["Personal clean"] = "No line rejected.",
    ["Personal rejected"] = "Rejected: %d line(s).",
    -- 0.8.0 wave 3: working together with Details, DBM/BigWigs, Questie
    ["Details comment"] = "Comment after long fights (needs Details)",
    ["Details comment tip"] = "After a fight longer than 20 seconds Lyra says at most one sentence every ten minutes about your own numbers - a record, \"above your average\", unusually much damage taken. No number lists, no group values with names; from Details she reads only your own actor and the nameless group total. Without Details nothing happens.",
    ["Boss chronicle"] = "Boss chronicle (attempts, kills, best time)",
    ["Boss chronicle tip"] = "Lyra remembers per boss how often you tried, how often it went down and how fast the fastest kill was - see /lyra bosses. That yields exactly two sentences: on a repeat attempt and on the very first kill. Lyra staying quiet while DBM or BigWigs is talking does not depend on this switch - that always applies.",
    ["Questie deep"] = "Use Questie more deeply (target zone, level, chain)",
    ["Questie deep tip"] = "When you accept a quest, Lyra reads the target zone and quest level from Questie and connects them with your chronicle (\"you nearly died there nine days ago\"). On turn-in she names the next quest in the chain. Read-only; without Questie nothing happens.",
    -- PORT 0.9.0: Text-to-Speech (Gestalt/Stimme.lua). Lines without a pre-rendered OGG.
    ["TTS mode"] = "Read unvoiced lines aloud (TTS)",
    ["TTS off"] = "Off",
    ["TTS fallback"] = "Only lines without a voice file",
    ["TTS always"] = "Always, even when quiet",
    ["TTS tip"] = "Lyra's own voice is pre-rendered, so lines with placeholders (a zone name, a number, your name) have no audio file and were silent until now. Your operating system can read them out instead - a different, robotic voice, but a voice. Lines that do have a voice file are never replaced. Lyra stays quiet when Blizzard's own combat audio alerts or screen narration are on, because three voices at once are not three times as helpful.",
    ["TTS no voices"] = "This client reports no text-to-speech voices, so nothing will be read aloud. Voices come from the operating system (Windows SAPI, macOS); on Linux/Wine there usually are none. Nothing breaks - the lines stay silent, as before.",
    ["TTS voice"] = "TTS voice",
    ["TTS voice tip"] = "Automatic picks a voice whose name matches the selected language. The list comes from your operating system, not from the addon.",
    -- W4: wave 4 (Sinne/Welle4.lua)
    ["Wave 4"] = "Everyday II and signals",
    ["Profession moment"] = "A word on professions",
    ["Profession moment tip"] = "At the crafting window Lyra says one sentence on the first point of a session, and one when a profession hits a trainer ceiling (75/150/225/300). At most once each per session. The chat line for every 25th point is a different, older feature and stays as it is.",
    ["First aid"] = "Remind me about bandages",
    ["First aid tip"] = "After a fight that took you below half your health - below a third outside Hardcore - Lyra looks into your bags. No bandage in there means one sentence, once per session, never again that day. If you buy some in the meantime, the sentence is dropped.",
    ["GatherMate nodes"] = "Count gathering nodes (needs GatherMate2)",
    ["GatherMate nodes tip"] = "When GatherMate2 records a new node, Lyra counts along. From the tenth node of a session she may say something, then at most every thirty minutes. She never names the node - GatherMate2 shows it better with a pin. Without GatherMate2 nothing happens.",
    ["WA signal"] = "Send a signal to WeakAuras",
    ["WA signal tip"] = "After every line Lyra sends the custom event LYRA_EREIGNIS (id, class, level) to WeakAuras, so you can build your own auras on her warnings. Read-only in one direction - Lyra never reads anything back out of WeakAuras. Details in Sinne/WELLE4.md.",
    ["Attunement unknown"] = "I don't know that attunement.",
    -- W5: wave 5 "Map" (Sinne/Karte2.lua)
    ["Wave 5"] = "Map and pins",
    ["Pin close calls"] = "Pin the places where it was close",
    ["Pin close calls tip"] = "Every spot where you nearly died gets a pin on the world map and the minimap, with the health you were left with and what did it. The data is your own chronicle - nothing is fetched from anywhere.",
    ["Pin notes"] = "Pin my own waypoints",
    ["Pin notes tip"] = "The points you set with /lyra punkt get a pin. Hovering it shows your note and when you set it. /lyra punkte lists them, /lyra punkt weg removes the last one.",
    ["Danger overlay"] = "Danger map overlay",
    ["Danger overlay tip"] = "Shows the cells Lyra actually warns about as translucent squares on the world map of the zone you are in - orange for falls, blue for drowning, red for creatures, the stronger the colour the more deaths. Needs the Lyra_Gestalt_Daten package and only works on Classic clients, because the cells are Classic Era deaths.",
    ["Waypoint proximity"] = "Say something when I reach my own waypoint",
    ["Waypoint proximity tip"] = "Within about 60 yards of a point you set yourself, Lyra says one sentence. Distance is measured in real yards, checked every two seconds, never in combat, and at most once every ten minutes per point.",
    ["Map overview"] = "Map",
    -- W6: wave 6 "Trust, accessibility, docking" (Sinne/Welle6.lua)
    ["Accessibility"] = "Accessibility",
    ["Accessibility mode"] = "Accessibility mode",
    ["Accessibility mode tip"] = "One switch for everything that makes Lyra readable and audible: the subtitle bar stays up permanently, every line is prefixed with \"Lyra:\", the bubble is opaque and the font larger, every line stays longer, and lines without a voice recording are read out (if your system has a voice). Warning levels also get a shape: a dot, a triangle, two triangles. Turning it off gives you your previous settings back - the mode remembers them.",
    ["Figure visible"] = "Show Lyra's figure",
    ["Figure visible tip"] = "Off means: voice and subtitles only. Lyra stays fully there - same events, same voice, same memory - she just has no portrait any more. Her text then appears in the subtitle bar, or in a speech bubble anchored to the bottom of the screen. Also available as /lyra figur aus.",
    ["Figure off hint"] = "I'm voice and text now. /lyra figur an brings me back.",
    ["Warning symbol"] = "Warning level as a shape too",
    ["Warning symbol tip"] = "Besides the colour, every warning level carries a small mark on the speech bubble: o notice, ^ warning, ^^ alarm. Colour alone carries nothing for roughly eight percent of male players - which is why this is on by default, and only larger in accessibility mode.",
    ["Wave 6"] = "Accessibility and voices",
    ["Speaker name"] = "Prefix every line with \"Lyra:\"",
    ["Speaker name tip"] = "The Deaf/HoH standard asks for a speaker tag in front of every line of dialogue. On stream, and next to other text output, it also makes it obvious at a glance who is talking. Applies to the bubble and the subtitle bar.",
    ["Coexistence"] = "Never two voices at once",
    ["Coexistence tip"] = "While Blizzard's own speech output or a screen reader is talking, Lyra holds her text-to-speech back until the other one is done. Since patch 12.0.0 Blizzard's speech is allowed to overlap - for someone using a screen reader, two voices at once is the end of usability. If Lyra can speak through Blizzard's own audio assist, she does, and the question never comes up.",
    ["Hold own voice"] = "Hold back Lyra's own recording too",
    ["Hold own voice tip"] = "By default the rule above only covers the read-aloud voice. Lyra's pre-rendered lines are short and sound like her - they do not drown out a reader. If you want it stricter, turn this on: then the recording stays silent too while somebody else is talking. The text always comes.",
    ["Foreign voice"] = "foreign voices",
    ["not installed"] = "not installed",
    ["frames"] = "frames",
    ["Client"] = "Client",
    ["Switch"] = "switch",
    -- W12A: /lyra status shows the interface number of the TOC the client actually loaded.
    ["Loaded TOC"] = "Loaded TOC",
    ["fits"] = "fits",
    ["Manual switch"] = "manual switch",
    ["Realm"] = "realm",
    ["Memory"] = "Memory",
    ["not measurable"] = "not measurable (the client does not report it)",
    ["CPU"] = "CPU time",
    ["CPU hint"] = "not measured - /console scriptProfile 1 and relog, then a number appears here",
    ["since login"] = "since login",
    ["TTS no voices short"] = "no voice installed",
    -- W8: Welle 8 (praeventive Sturz- und Wasserwarnung)
    ["Pre-warning"] = "Warn before cliffs and deep water",
    ["Pre-warning tip"] = "Lyra says a quiet line BEFORE you reach a spot where many hardcore characters have fallen or drowned - roughly twenty to forty yards ahead, only while you are actually walking towards it. She never tells you where to go; she tells you where others died. Never in combat, never on a taxi, never in a city or an inn, at most once per spot per session. Needs the danger map data pack and only works on Classic Era style clients.",
    -- W9a: reading personal lines aloud (Gestalt/Stimme.lua) and the pronunciation lexicon
    ["TTS personal"] = "Read personal lines aloud too",
    ["TTS personal tip"] = "Personal lines come from the Lyra_Gestalt_Persoenlich package - written by hand or produced by the editor. They have no recording and are therefore only shown; that is exactly what /lyra persoenlich has always promised. This switch lifts that promise for you: the reading voice will speak them as well. It does not sound like Lyra, and a note that a line came from a model does not travel with the voice.",
    -- W9b: Welle 9b (Freitext mit Lyra, Stufe 1 - UI/Freitext.lua)
    ["Wave 9b"] = "Free writing",
    ["Freetext"] = "Input field in the dialogue",
    ["Freetext tip"] = "There is an input field below Lyra's dialogue window. You can ask her full questions about your own chronicle - zones, enemies, close calls, your playtime, your sessions. She answers from fixed templates and your own numbers; no language model runs, nothing leaves your computer. The field takes focus ONLY on click and drops it the moment combat starts - an input field that swallows WASD is lethal on hardcore. /lyra <question> keeps working too.",
    ["Remember questions"] = "Remember questions",
    ["Remember questions tip"] = "By default your conversation history lives in memory only and is gone when you log out. With this box ticked the last five questions (only the questions, never the answers) are written to the SavedVariables - as plain text on your disk. It is meant as groundwork for a later stage; leave it off until you need it.",
    ["Freetext hint"] = "Enter sends · Esc closes",
    ["Freetext on"] = "Free text on. Click the field below the dialogue window.",
    ["Freetext off"] = "Free text off.",
    -- W10B: wave 10b (colour palettes, UI/Farben.lua) - appended only, nothing rebuilt.
    ["Colour theme"] = "Colour theme",
    ["Colour theme unknown"] = "No palette by that name. Available",
    ["Colour theme overridden"] = "Not in effect right now: \"High contrast\" is on and wins over any palette.",
    ["Colour theme tip"] = "Four named palettes for the speech bubble, the subtitle bar and the warning pulse at the screen edge: standard (Lyra's violet), kontrast (black/white), warm (amber on brown), kalt (ice blue on night blue). Every palette is checked for readability - text is above 11:1 in all four, the requirement is 4.5:1. The \"High contrast\" checkbox wins over the palette choice; no palette changes the brightness or the rhythm of the pulse, those are the photosensitivity limit. Also available as /lyra farbe <name>.",
    -- W10a: the disclosure line for /lyra hilfe (free-text concept §2.8, wave 9b §8 item 5).
    ["Disclosure"] = "Lyra answers from fixed templates and your own chronicle. No language model is running.",
    -- =========================================================================================
    -- W11B (20.09.2026): direction, safety, controls. APPENDED ONLY, nothing rewritten.
    -- =========================================================================================
    ["Event muted"] = "%s is quiet now. Bring it back with /lyra laut %s.",
    ["Event unmuted"] = "%s will speak up again.",
    ["Event is alarm"] = "%s is an alarm (level 3). I am not switching that one off for you - that is what it is for. If you want me fully quiet: /lyra stumm without an event, or turn the voice off.",
    ["Event unknown"] = "I do not know an event called %s. /lyra gehoert lists what I said last.",
    ["Recently heard"] = "What you heard from me last (newest first):",
    ["Recently heard empty"] = "nothing said yet this session",
    ["muted"] = "muted",
    ["Mute hint"] = "/lyra stumm <EVENT> switches one of these off, /lyra laut <EVENT> switches it back on.",
    ["Why silent"] = "What I did NOT say last, and why:",
    ["Why nothing dropped"] = "nothing dropped - everything that came up also came out",
    ["Why counters"] = "%d of those were losses, %d were by design.",
    ["loss"] = "loss",
    ["by design"] = "by design",
    ["Why drossel"] = "throttle - this event has a waiting time and it was still running",
    ["Why preset-leerlauf"] = "talkativeness - on \"little\" and \"silent\" I do not chat into the void",
    ["Why session"] = "once per session - that one already happened today",
    ["Why abstand"] = "spacing - something else came through shortly before",
    ["Why budget"] = "hourly budget - my allowance for this hour is used up",
    ["Why gruppe"] = "group - I hold back in parties and raids",
    ["Why still-modus"] = "silent mode",
    ["Why stumm"] = "you switched off this exact event (/lyra laut <ID>)",
    ["Why ruhe"] = "quiet spell - after a memorial or someone else's warning I stay quiet for a moment",
    ["Why tod-ruhe"] = "after a death I stay silent for a minute",
    ["Why ladebildschirm"] = "loading screen",
    ["Why warteliste-voll"] = "combat - the waiting list was full",
    ["Why warte-ttl"] = "combat - it took too long, the line no longer fit afterwards",
    ["Muted count"] = "Muted events: %d (/lyra gehoert)",
    ["Volume range"] = "My volume runs from 0 to 100.",
    ["Volume is"] = "My volume: %d %%",
    ["Volume alarm note"] = "Alarms (level 3: health below 20 %, falling, last breath) stay at full volume.",
    ["Lyra volume"] = "Lyra's volume",
    ["Lyra volume tip"] = "How loud I am - relative to the sound channel you picked above. 100 % means unchanged. Technically I lower that channel for the one to four seconds of my line and put it back exactly afterwards; I never change your Blizzard slider permanently. During those seconds the whole channel is quieter, not just me - which is why the default is 100. Alarms (level 3) always stay at full volume, for the same reason they move to the Master channel.",
    ["Recently heard button"] = "Recently heard",
    ["Recently heard button tip"] = "Prints the events I said most recently, with their IDs, plus the line you need to switch one of them off. A clickable list with checkboxes is not something WoW's settings API gives us here: the page is built ONCE at login, and what you heard last is not known at that point.",
    ["Wave 11b"] = "Pacing and quiet",
    ["Help text w11b"] = "/lyra stumm <EVENT> - switch off a single event (/lyra laut <EVENT> to undo)\n"
        .. "/lyra gehoert - what I said last, with the ID to switch it off\n"
        .. "/lyra warum - what I did NOT say last, and why\n"
        .. "/lyra lautstaerke <0-100> - how loud I am (alarms stay at full volume)",
    -- W11A: wave 11a (death gets a voice, familiarity, remembering) - appended only.
    -- The last-words prompt and its confirmation deliberately stay in the locale and do NOT move
    -- into the phrase catalogue: Core/Regie.lua routes them past the director on purpose, because
    -- the 60 s death lock would otherwise swallow them. Sinne/Erbe.lua picks a variant at random;
    -- if one is missing it falls back to the first cleanly.
    ["Last words prompt 2"] = "Anything you want to pass on to the next one? Tell me: /lyra <your words>",
    ["Last words prompt 3"] = "One sentence, and I'll carry it on. /lyra <your words>",
    ["Last words prompt 4"] = "I'm taking notes. Say it if you want to: /lyra <your words>",
    -- IMPORTANT: every variant must carry the word "saved". tests/pruefstand/review4.lua checks
    -- the confirmation for exactly that, and rightly so: a confirmation that does not confirm
    -- that something was saved is not one.
    ["Last words saved 2"] = "It is saved. The next one gets to hear it.",
    ["Last words saved 3"] = "Written down and saved. Word for word, not roughly.",
    -- Hall of the fallen: second section in the chronicle window (Sinne/Erbe.lua E.halleZeilen).
    ["Hall of the fallen"] = "Hall of the fallen",
    -- W11C: wave 11c (the line at the death spot) - appended only.
    -- Tooltip of the death-spot pin on world map and minimap (Sinne/Karte2.lua). Three
    -- substitutions in THIS order: name, level, day. Translators must not reorder them.
    -- The LINE Lyra speaks there is not here but in the phrase catalogue (ERBE_STERBEORT,
    -- docs/phrasen-w11c.json): that one goes through the director, the tooltip does not.
    ["Fell here"] = "%s fell here. Level %d, %s.",
    ["Death spot"] = "Death spot",
    -- W11D: wave 11d (two checkboxes) - appended only.
    -- The two checkboxes in the "map" section of the fine tuning page (UI/Settings.lua). They
    -- toggle the very same two keys as "/lyra karte sterbeort|sterbeortpin on|off":
    -- "sterbeort" is the LINE, "pinSterbeort" is the PIN. One state, two ways to reach it.
    ["Death spot line"] = "Say where a predecessor fell",
    ["Death spot line tip"] = "When a new character reaches the spot where one of your own predecessors fell, Lyra says so exactly once - with name, level and date.",
    ["Pin death spots"] = "Show death spots on the map",
    ["Pin death spots tip"] = "Every death spot of one of your own predecessors gets a marker on the world map and the minimap, with name, level and date in the tooltip - your own characters only, never anybody else's.",
}
