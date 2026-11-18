# Changelog

## Unreleased

- First start: on a fresh install the window opens once next to the screen centre (before, it only showed with the character frame open, so new players saw nothing). Afterwards it stays docked to the character frame; free window and the rest are in the settings.
- Chat history: Up / Down in the chat input step through the lines you sent, slash commands like `/console` included (no Alt needed) to send them again or edit them first; the last 100 lines are kept across /reload and restarts. Switchable in the settings, `/isistats chat clear` empties it.
- Fishing pole warning: while a fishing pole is equipped, a red "Fishing pole equipped" row sits at the very top of the window; when combat starts with it in hand there is a raid warning with sound (also with the window closed). Both on by default and switchable in the settings.

## 0.6.0 - 2026-11-17

### Leveling

- New at the very top: XP still needed for the next level in thousands ("XP to level 42   12.4k") with a progress bar; tooltip with exact XP and rested XP. Hidden at the maximum level, on by default.
- Below it: played time on this level and the estimated time to the next level (from your XP rate on this level; "-" until there is enough data). Both on by default and switchable in the settings.
- The game's played-time query at login no longer prints a chat line.

## 0.5.0 - 2026-11-17

### Renamed

- The addon is now **isiStatsForever** (addon folder, title, settings page, release zip, GitHub repo). The slash commands `/isistats` and `/istats` stay; updating from isiStats needs the new folder (the old `isiStats` folder can be deleted).

### Weapon skills and defense

- Skill rows in fixed columns: +/- vs. target, bonus, current / max at the right edge - the numbers line up exactly.
- A thin progress bar under each skill shows current / max like the game's skill panel.
- Tooltips show the distance to the maximum and, for equipped weapons below the cap, that the skill rises by fighting with them.
- Defense moved below the weapon skills and is shown like them as current / max; the defense section keeps the values derived from it.
- New setting "Show the target row without a target" (on by default).

### Defaults and window

- Weapon damage is on by default: melee damage for warrior, paladin and rogue, ranged damage for hunter (casters already had spell damage). Characters keep values they switched themselves.
- Without section headers there are no gaps between the sections; the rows form one continuous list.
- New settings: "Hide in combat" / "Show only in combat" and "Lock position and size" (also `/isistats lock` / `unlock`).

### Maintenance

- Saved settings of removed rows are cleaned up on login.
- `/isistats debug` lists the raw game values of every weapon skill and defense and keeps the output in the saved variables (`lastDebug`) for bug reports.
- Development: Data.lua split into Util, Skills, Catalog, Data and CombatCache; StyLua check in the GitHub CI.

## 0.4.1 - 2026-11-17

- No change in the addon itself; isiStats needs no other addon (all values come straight from the game).
- Development: the class matrix now equips every weapon type each class can use in WoW Forever (Classic Era weapon rules; 64 combinations) and checks the shown skill, its vs.-target value and glancing only for melee.

## 0.4.0 - 2026-11-17

### Weapon skills vs. your target

- Every weapon skill row shows its hit/crit modifier against the current target (defense = level x 5, 0.04% per point, as in the game's skill panel); the row above the list names the target. Tooltip: hit, crit and glancing blows (melee only). Without a hostile target it compares against an enemy of your level.
- A target of level ?? (not a world boss) shows "defense unknown" - nothing is guessed.
- Miss chance vs. boss now uses the game panel's 0.04% per skill point.
- Melee and ranged: the separate weapon skill rows (main hand, off hand, ranged) are gone; the skills are listed under weapon skills.

### Combat

- Values the game hides from addons in combat are still shown live where they come straight from the game (attributes, health, crit, hit, dodge, parry, block, armor, resistances, spell values). Values that need calculating (attack power total, DPS, armor reduction, vs.-target modifiers) keep their last value from before the fight, greyed out with a tooltip note. `/isistats debug` lists which game functions were hidden.

### Window

- Rounded window with a soft drop shadow and hairline ring; the opacity slider also fades shadow and ring.
- Section headers are hidden by default; setting "Show section headers" brings them back (and with them collapsing).
- Values fade in briefly when they change (buff, proc, gear); setting "Fade in values when they change", on by default.
- Slightly wider (270) so skill rows fit the extra value.
- Language follows the WoW Forever client: German on a German client, English on every other client.

### Error log

- isiStats' own Lua errors are kept (also with script errors switched off); `/isistats errors` shows them, `/isistats errors clear` empties the log.

### Fixes

- Without any known weapon skill the target row was overwritten.

### Development

- Project rules (CLAUDE.md, AGENTS.md, docs/RULES.md), pre-commit hook, locale check, load test with asserts for German and English clients, class matrix test for all 9 classes (incl. wand, thrown weapon, hunter bow + melee weapon).

## 0.3.1 - 2026-11-17

- New addon icon in the in-game addon list.
- First release on CurseForge.

## 0.3.0 - 2026-11-17

- Background opacity: slider in the settings and `/isistats alpha <0-100>`; text stays fully readable.
- Resize grip in the bottom-right corner scales the window (0.5x - 2x), the top-left corner stays in place.
- Fix: the window did not load after the resize grip was added.

## 0.2.0 - 2026-11-17

- Settings page (Options -> AddOns -> isiStats): every value can be switched on or off, saved per character.
- Class defaults: main stat, the class's attack value (melee AP, ranged AP or spell damage), defense and the skills of the equipped weapons.
- Buttons for class defaults, all on, all off.

## 0.1.0 - 2026-11-17

- First version: attributes, melee, ranged, spell, defense, weapon skills and resistances.
- Weapon skills and defense via `C_SkillInfo.GetSkillLineInfoByID` (WoW Forever has no classic skill list).
- Window docks to the character frame or floats freely; collapsible sections.
