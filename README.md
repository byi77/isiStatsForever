<p align="center"><img src="docs/logo.png" width="160" alt="isiStats logo"></p>

# isiStats

Character stats for **WoW Forever** (client 1.60.x, interface 16001): attributes, melee, ranged and spell values, defense, weapon skills and resistances in one compact window.

## Features

- **Weapon skills** of every learned weapon type as `current / max`; skills below the cap are yellow, equipped weapons are highlighted.
- **Vs. your target**: behind every weapon skill its hit/crit modifier against your current target (defense = level x 5, 0.04% per point, as in the game's skill panel); the tooltip adds glancing blows for melee weapons. Without a hostile target it compares against an enemy of your level.
- **Defense** with miss chance and crit reduction vs. an attacker of your level, armor reduction vs. your level and level +3.
- **Melee**: attack power, damage, speed, DPS, crit, hit and the miss chance vs. a boss (level +3).
- **Ranged** (only with a ranged weapon; wands show damage only) and **spell** values (only for mana users).
- **Settings page** (Options -> AddOns -> isiStats): every value on/off, saved per character. Class defaults: main stat, the class's attack value (melee AP, ranged AP or spell damage), defense, the equipped weapon skills and their value vs. your target.
- English and German, following the client language.
- Rounded window with a soft shadow (isiLive look), docks to the character frame or floats freely, resize grip in the bottom-right corner, adjustable background opacity, optional section headers.
- Values that change (buff, proc, new gear) briefly fade in; switchable.
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
| `/isistats reset` | Reset position and settings |
| `/isistats errors` / `errors clear` | Show / clear the error log |
| `/isistats debug` | Print raw API info (for bug reports) |

## Development

```sh
git config core.hooksPath .githooks   # once: runs all checks below before every commit
stylua --check *.lua tools/*.lua
luacheck *.lua                        # strict globals: every WoW API is listed in .luacheckrc
lua tools/check_locale.lua            # enUS and deDE: same keys, same placeholders
lua tools/load_test.lua . deDE        # loads the addon against stubbed WoW APIs, with asserts
lua tools/load_test.lua . enUS        # same with an English client
lua tools/class_matrix.lua . deDE     # every class: defaults and visible values with typical gear
```

Project rules for contributors and agents: `CLAUDE.md`, `AGENTS.md`, `docs/RULES.md`.

Releases: bump `## Version` in the TOC, add a `CHANGELOG.md` entry, tag `vX.Y.Z` and push the tag. The release workflow checks that the tag matches the TOC version, builds `isiStats-vX.Y.Z.zip` and publishes a GitHub release with the changelog entry as notes.

## License

All rights reserved, see [LICENSE](LICENSE).
