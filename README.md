<p align="center"><img src="docs/logo.png" width="160" alt="isiStatsForever logo"></p>

# isiStatsForever

Character stats for **WoW Forever** (client 1.60.x, interface 16001): attributes, melee, ranged and spell values, defense, weapon skills and resistances in one compact window.

## Features

- **Buff reminder** at the very top: Well-Rested from the sleeping bag (stacks out of 3 and time left; hidden from level 60, it only gives XP) and the world buff Might of Stormwind (Alliance, time left). Red when missing, yellow with fewer stacks or shortly before the end, each switchable. Screen warnings with their own switches: one message with sound 15 minutes (Well-Rested) or 5 minutes (Might of Stormwind) before the end, and a text that stays while Well-Rested is missing. More buffs: one entry in `Buffs.lua`.
- **Fishing pole warning**: a red row near the top while a fishing pole is equipped, and when combat starts with it in hand a text in the middle of the screen that stays until the pole is taken off, and a sound every 2 seconds while the fight lasts (also with the window closed, and when the pole is equipped during a fight).
- **Gathering tracking warning**: with herbalism or mining learned, a text stays in the middle of the screen while neither Find Herbs nor Find Minerals is on (with both professions one is enough). It goes away as soon as one is on. A warning sound plays once when it appears.
- **Class and gear warnings**: red texts in the middle of the screen that stay while the cause lasts, each switchable. Warlock: 5 soul shards or fewer. Hunter: 200 ammo or less, Cheetah / Pack aspect in combat, pet not happy, no pet in combat. Warrior: Battle Shout missing in combat, Defensive Stance without a shield. Rogue: no poison. Shaman: no weapon imbue in combat. Mage, Priest, Druid, Paladin, Shaman: missing self buffs out of combat; Paladin tank: Righteous Fury. Reagents at 5 or fewer. Everyone: gear almost broken. All on by default. More warnings: one entry in `Warnings.lua`.
- **Flight times**: measures every whole flight and saves it on your own install (measured times of many routes ship with the addon, your own win); the time (or a "~" estimate from saved stretches) in the flight map tooltip and in chat when you take a flight; `/isistats flights [clear]`; on by default, switchable.
- **Flight bar**: during a flight, start -> destination with a bar that fills up and the time left, or counting up for an unknown time; Shift + drag moves it, Ctrl + click closes it; on by default, switchable.
- **Warnings** also for almost full bags, unspent talent points and (briefly at the start of a fight, yellow, silent) an equipped weapon skill more than 10 below its maximum.
- **XP per hour, kills to the next level and session values** (time, XP, gold, kills since the login): optional rows, off by default; `/isistats session reset`.
- **Landing notice** 5 seconds before a known arrival; `/isistats flights` also lists routes from the last flight master you never flew.
- **Professions** at their rank's maximum: a warning to learn the next rank. Weapon skill tooltips show the time to the maximum.
- **Gold per hour, hearthstone cooldown**, repair costs at a vendor (automatic repair optional) and the time per level (`/isistats levels`).
- **Item levels** in item tooltips, on the character window and in the bags (each switchable), the average as a row.
- **Gear durability** as a row, level-up gains in the chat, a short hint for a weapon to train in the bags (each weapon only once per character), deaths and repair costs in the session, flight statistics.
- **Combat banner**: a big fading text in the middle of the screen when combat starts and ends; on by default, switchable.
- **Damage meter reset**: Blizzard's damage meter is cleared once each time you join a group (not on /reload); switchable.
- **Chat history**: Up / Down in the chat input step through the lines you sent, kept across /reload and restarts (last 100; `/isistats chat clear`).
- **Leveling** near the top: XP still needed for the next level in thousands (e.g. `12.4k`) with a progress bar, played time on this level and the estimated time to the next level (from your XP rate on this level). Hidden at the maximum level.
- **Weapon skills** of every learned weapon type as `current / max` in fixed columns with a progress bar; skills below the cap are yellow, equipped weapons are highlighted, the tooltip shows the distance to the maximum. Defense is listed below the weapons the same way.
- **Vs. your target**: behind every weapon skill one percentage - how many auto attacks don't hit fully (no damage or only glancing; ranged: missed), calculated from the game's own values with your weapon skill, hit, expertise and dual wielding. Yellow from 30%, red from 50%. The tooltip has the split and what the skill alone changes. Without a hostile target it compares against an enemy of your level.
- **Defense** with miss chance and crit reduction vs. an attacker of your level, armor reduction vs. your level and level +3.
- **Melee**: attack power, damage, speed, DPS, crit, hit and the miss chance vs. a boss (level +3).
- **Ranged** (only with a ranged weapon; wands show damage only) and **spell** values (only for mana users).
- **Settings page** (Options -> AddOns -> isiStatsForever): every value on/off, saved per character. Class defaults: main stat, the class's attack value and damage (melee AP + weapon damage, ranged AP + ranged damage, or spell damage), defense, the equipped weapon skills and their value vs. your target.
- English and German, following the client language.
- Rounded window with a soft shadow (isiLive look), floats freely (open from the start) or docks to the character frame (your choice in the settings), resize grip in the bottom-right corner, adjustable background opacity, optional section headers.
- Values that change (buff, proc, new gear) briefly fade in; switchable.
- Optional: hide the window in combat, or show it only in combat; lock position and size.
- In combat, values the game hides from addons stay visible: live where possible, otherwise the last value greyed out.
- Built-in error log: own Lua errors are kept even with script errors switched off (`/isistats errors`).

## Commands

| Command | Effect |
|---|---|
| `/isistats` or `/istats` | Show/hide the window |
| `/isistats config` | Open the settings |
| `/isistats dock` / `free` | Dock to the character frame / free window |
| `/isistats scale <0.5-2>` | Window size |
| `/isistats alpha <0-100>` | Background opacity in percent |
| `/isistats lock` / `unlock` | Lock / unlock position and size |
| `/isistats reset` | Reset position and settings |
| `/isistats chat clear` | Clear the saved chat history |
| `/isistats errors` / `errors clear` | Show / clear the error log |
| `/isistats perf` | CPU share and memory of the addon |
| `/isistats debug` | Print raw API info (for bug reports) |

## Development

```sh
git config core.hooksPath .githooks   # once: runs all checks below before every commit
stylua --check *.lua tools/*.lua
luacheck *.lua                        # strict globals: every WoW API is listed in .luacheckrc
lua tools/check_locale.lua            # enUS and deDE: same keys, same placeholders
lua tools/load_test.lua . deDE        # loads the addon against stubbed WoW APIs, with asserts
lua tools/load_test.lua . enUS        # same with an English client
lua tools/class_matrix.lua . deDE     # every class: defaults, typical gear and every usable weapon type
```

Project rules for contributors and agents: `CLAUDE.md`, `AGENTS.md`, `docs/RULES.md`.

Releases: bump `## Version` in the TOC, add a `CHANGELOG.md` entry, tag `vX.Y.Z` and push the tag. The release workflow checks that the tag matches the TOC version, builds `isiStatsForever-vX.Y.Z.zip` and publishes a GitHub release with the changelog entry as notes.

## License

All rights reserved, see [LICENSE](LICENSE).
