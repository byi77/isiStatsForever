# CurseForge project page

**Name:** isiStats
**Summary (max 250 chars):** Compact character stats for WoW Forever: weapon skills, defense, melee, ranged and spell values. Every value can be switched on or off; class defaults show what matters.
**Category:** Character Advancement (or: Combat)
**License:** All Rights Reserved
**Source:** https://github.com/byi77/isiStats
**Logo / avatar:** docs/logo.png (400x400)

## Description

**isiStats** shows the numbers the character sheet hides, in one compact window next to your character frame.

- **Weapon skills** of every learned weapon type as *current / max*. Skills below the cap are yellow, equipped weapons are highlighted.
- **Vs. your target**: behind every weapon skill its hit and crit modifier against the target you have selected - the same numbers as the game's skill panel. Hover a skill for glancing blows.
- **Defense** with the chance to be missed and crit reduction vs. an attacker of your level, plus armor reduction vs. your level and level +3.
- **Melee**: attack power, damage, speed, DPS, crit, hit, miss chance vs. a boss (level +3).
- **Ranged** (with a ranged weapon) and **spell** values (for mana users): spell damage per school, healing, spell crit, spell hit, mana per 5.
- **Resistances**.
- **In combat** the values stay visible: live where the game allows it, otherwise the last value greyed out.

### Your stats, your choice

Options → AddOns → isiStats: switch every single value on or off, saved per character. Out of the box each class sees its main stat, its attack value (melee AP, ranged AP or spell damage), defense and the skills of the equipped weapons with their value against your target.

### Window

Rounded, compact window that docks to the character frame or floats freely. Resize grip in the bottom-right corner, adjustable background opacity, optional section headers, values fade in when they change. English and German.

### Commands

- `/isistats` - show/hide
- `/isistats config` - settings
- `/isistats scale 0.5-2`, `/isistats alpha 0-100`
- `/isistats dock` / `free` / `reset`
- `/isistats errors` - error log for bug reports

Bug reports and ideas: https://github.com/byi77/isiStats/issues
