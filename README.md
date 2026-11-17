<p align="center"><img src="docs/logo.png" width="160" alt="isiStats logo"></p>

# isiStats

Character stats for **WoW Forever** (client 1.60.x, interface 16001): attributes, melee, ranged and spell values, defense, weapon skills and resistances in one compact window.

## Features

- **Weapon skills** of every learned weapon type as `current / max`; skills below the cap are yellow, equipped weapons are highlighted.
- **Defense** with miss chance and crit reduction vs. an attacker of your level, armor reduction vs. your level and level +3.
- **Melee**: attack power, damage, speed, DPS, crit, hit, main/off-hand skill and the miss chance vs. a boss (level +3, classic formula).
- **Ranged** (only with a ranged weapon) and **spell** values (only for mana users).
- **Settings page** (Options -> AddOns -> isiStats): every value on/off, saved per character. Class defaults show the main stat, the class's attack value, defense and the equipped weapon skills.
- Window docks to the character frame or floats freely, resize grip in the bottom-right corner, adjustable background opacity.

## Commands

| Command | Effect |
|---|---|
| `/isistats` or `/istats` | Show/hide the window |
| `/isistats config` | Open the settings |
| `/isistats dock` / `free` | Dock to the character frame / free window |
| `/isistats scale <0.5-2>` | Window size |
| `/isistats alpha <0-100>` | Background opacity in percent |
| `/isistats reset` | Reset position and settings |
| `/isistats debug` | Print raw API info (for bug reports) |

## Development

```sh
luacheck *.lua            # strict globals: every WoW API is listed in .luacheckrc
stylua --check *.lua
lua tools/load_test.lua . # loads the addon against stubbed WoW APIs
```

Releases: bump `## Version` in the TOC, add a `CHANGELOG.md` entry, tag `vX.Y.Z` and push the tag. The release workflow checks that the tag matches the TOC version, builds `isiStats-vX.Y.Z.zip` and publishes a GitHub release with the changelog entry as notes.

## License

All rights reserved, see [LICENSE](LICENSE).
