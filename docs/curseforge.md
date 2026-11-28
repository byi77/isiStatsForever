# CurseForge project page

**Name:** isiStatsForever
**Summary (max 250 chars):** Compact character stats for WoW Forever: weapon skills, defense, melee, ranged and spell values. Every value can be switched on or off; class defaults show what matters.
**Category:** Character Advancement (or: Combat)
**License:** All Rights Reserved
**Source:** https://github.com/byi77/isiStatsForever
**Logo / avatar:** docs/logo.png (400x400)

## Description

**isiStatsForever** shows the numbers the character sheet hides, in one compact window, free or docked to your character frame.

- **Buff reminder**: Well-Rested (sleeping bag, with stacks, below level 60) and Might of Stormwind with time left at the top of the window, red when missing. A screen warning before they run out (15 / 5 minutes), and one that stays while Well-Rested is missing.
- **Fishing pole warning**: red row while a fishing pole is equipped; when combat starts with it, a text stays on screen until you take it off, with a warning sound every 2 seconds during the fight.
- **Gathering tracking warning**: a text stays on screen while you have herbalism or mining and Find Herbs / Find Minerals is off, with a warning sound when it appears.
- **Class and gear warnings**: lasting screen warnings for low soul shards, low ammo, Cheetah / Pack aspect in combat, an unhappy or missing pet, missing Battle Shout, Defensive Stance without a shield, missing poisons, imbues and self buffs, low reagents and broken gear.
- **Flight times**: every whole flight you take is measured and saved on your own install; measured times of many routes ship with the addon, and your own measurement always wins. The flight map tooltip shows the time of each flight point (or a ~ estimate from saved stretches), and during the flight a bar shows start -> destination with the time left (counting up when the time is not known yet).
- **More warnings**: almost full bags, unspent talent points, and briefly at the start of a fight a quiet yellow hint when an equipped weapon skill is more than 10 below its maximum.
- **XP per hour, kills to the next level, session values** (time, XP, gold, kills since the login): optional rows.
- **Professions** at their rank's maximum, time to the maximum weapon skill, gold per hour, hearthstone cooldown, repair costs (automatic repair optional), time per level.
- **Item levels** in item tooltips, on the character window and in the bags (each switchable), the average as a row.
- **Gear durability**, level-up gains in the chat, a short hint for a weapon to train in the bags (each weapon only once per character), deaths and repair costs per session, flight statistics.
- **Combat banner**: a big text in the middle of the screen when combat starts and ends.
- **Damage meter reset**: Blizzard's damage meter starts empty in every group you join.
- **Chat history**: Up / Down in the chat input step through your sent lines, also after a restart.
- **Leveling**: XP to the next level in thousands, time on this level and the estimated time to the next level.
- **Weapon skills** of every learned weapon type as *current / max*. Skills below the cap are yellow, equipped weapons have a dot.
- **Vs. your target**: behind every weapon skill how many of your auto attacks don't hit fully (no damage or only glancing), calculated from the game's own values with your weapon skill, hit and expertise. Hover a skill for the split. Ranged weapons show the miss chance.
- **Defense**: the defense skill as *current / max*, the chance to be missed and crit reduction vs. an attacker of your level, armor reduction vs. your level and level +3, and your resistances in one colored row.
- **Melee**: attack power, damage, speed, DPS, crit, hit, miss chance vs. a boss (level +3).
- **Ranged** (with a ranged weapon) and **spell** values (for mana users): spell damage per school, healing, spell crit, spell hit, mana per 5.
- **In combat** the values stay visible: live where the game allows it, otherwise the last value greyed out.

### Your stats, your choice

Options → AddOns → isiStatsForever: switch every single value on or off, saved per character. Out of the box each class sees its main stat, its attack value and damage (melee AP + weapon damage, ranged AP + ranged damage, or spell damage), crit and hit, defense and the skills of the equipped weapons with their value against your target. At level 60 the XP rows step aside and gear, resistances and the miss chance vs. a raid boss come in.

### Window

Modern, compact window that floats freely (open from the start) or docks to the character frame - your choice in the settings. Buffs and warnings as colored pills at the top, the level bar, your key values as tiles (main stat, power, DPS or spell crit), then everything that belongs together in one section: attributes, offense, weapon skills, defense, gear and session. Collapsible headers keep a short summary while collapsed, related values share a row (Crit · Hit, Dodge · Parry), and a font with even digits keeps the numbers lined up. Class color in the title bar, resize grip, adjustable background opacity, taller rows on request; values fade in when they change. Every part is switchable. English and German.

### Commands

- `/isistats` - show/hide
- `/isistats config` - settings
- `/isistats scale 0.5-2`, `/isistats alpha 0-100`
- `/isistats dock` / `free` / `reset`, `/isistats lock` / `unlock`
- `/isistats flights` - saved flight times and routes never flown (`flights clear` deletes them)
- `/isistats session reset` - start the session values again
- `/isistats levels` - time per level
- `/isistats errors` - error log for bug reports
- `/isistats perf` - CPU share and memory of the addon

Bug reports and ideas: https://github.com/byi77/isiStatsForever/issues
