# CurseForge project page

**Name:** isiStatsForever
**Summary (max 250 chars):** Compact character stats for WoW Forever: weapon skills, defense, melee, ranged and spell values. Every value can be switched on or off; class defaults show what matters.
**Category:** Character Advancement (or: Combat)
**License:** All Rights Reserved
**Source:** https://github.com/byi77/isiStatsForever
**Logo / avatar:** docs/logo.png (400x400)

## Description

**isiStatsForever** shows the numbers the character sheet hides, in one compact window next to your character frame.

- **Fishing pole warning**: red row while a fishing pole is equipped, raid warning with sound when combat starts with it.
- **Chat history**: Up / Down in the chat input step through your sent lines, also after a restart.
- **Leveling**: XP to the next level in thousands, time on this level and the estimated time to the next level.
- **Weapon skills** of every learned weapon type as *current / max*. Skills below the cap are yellow, equipped weapons are highlighted.
- **Vs. your target**: behind every weapon skill its hit and crit modifier against the target you have selected - the same numbers as the game's skill panel. Hover a skill for glancing blows.
- **Defense** with the chance to be missed and crit reduction vs. an attacker of your level, plus armor reduction vs. your level and level +3.
- **Melee**: attack power, damage, speed, DPS, crit, hit, miss chance vs. a boss (level +3).
- **Ranged** (with a ranged weapon) and **spell** values (for mana users): spell damage per school, healing, spell crit, spell hit, mana per 5.
- **Resistances**.
- **In combat** the values stay visible: live where the game allows it, otherwise the last value greyed out.

### Your stats, your choice

Options → AddOns → isiStatsForever: switch every single value on or off, saved per character. Out of the box each class sees its main stat, its attack value and damage (melee AP + weapon damage, ranged AP + ranged damage, or spell damage), defense and the skills of the equipped weapons with their value against your target.

### Window

Rounded, compact window that docks to the character frame or floats freely. Resize grip in the bottom-right corner, adjustable background opacity, optional section headers, values fade in when they change. English and German.

### Commands

- `/isistats` - show/hide
- `/isistats config` - settings
- `/isistats scale 0.5-2`, `/isistats alpha 0-100`
- `/isistats dock` / `free` / `reset`, `/isistats lock` / `unlock`
- `/isistats errors` - error log for bug reports

Bug reports and ideas: https://github.com/byi77/isiStatsForever/issues
