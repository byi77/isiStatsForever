# Changelog

## Unreleased

- Fixed: API audit against the Forever client source (1.60.1.70938). The chat window count now comes from the client constant `Constants.ChatFrameConstants.MaxChatWindows`; `NUM_CHAT_WINDOWS` only exists as a deprecation shim, and the hard-coded 10 is gone. The window subtitle and the class defaults no longer use a class or level value that could be secret without checking it first.

## 0.11.2 - 2026-11-24

- Fixed: the hunter pet mood warning showed while the pet was dismissed (or dead). It now only checks a pet that is out.

## 0.11.1 - 2026-11-23

- Changed: the percentage behind a weapon skill (attacks that do not hit fully) is colored by the skill effect against the target, like the hit line in its tooltip: red when your skill is below the target's defense, green when above, white when equal. Before, it only turned yellow from 30% and red from 50%.

## 0.11.0 - 2026-11-23

- New: class and gear warnings. A red text stays in the middle of the screen while the cause lasts, with a sound once when it appears, like the missing Well-Rested warning. All are on by default for every class; each has its own switch in the settings (Warnings), where only your class's warnings are listed.
  - Warlock: 5 soul shards or fewer in the bags (once you know a spell that uses them).
  - Hunter: 200 ammo or less (with a bow, gun or crossbow); Aspect of the Cheetah or the Pack on in combat; pet only content or unhappy; no pet or a dead pet in combat.
  - Warrior: Battle Shout missing in combat; Defensive Stance without a shield.
  - Rogue: no poison on a weapon. Shaman: no weapon imbue in combat.
  - Out of combat, missing self buffs: Mage armor and Arcane Intellect; Priest Inner Fire and Fortitude; Druid Mark of the Wild; Paladin aura and blessing; Shaman Lightning Shield. Paladin with a shield: Righteous Fury missing.
  - Reagents at 5 or fewer, for the highest rank you know: Flash and Blinding Powder, teleport and portal runes, Arcane Powder, candles, Rebirth seeds and Gift of the Wild herbs, Symbol of Kings, Ankh.
  - Everyone: gear almost broken or broken (the same state as the game's armor figure).
- New: Blizzard's damage meter is cleared once each time you join a group (one line in the chat says so). A /reload or login inside a group keeps the numbers. On by default, switch: Options -> AddOns -> isiStatsForever -> "Clear the damage meter when joining a group".
- The window shows the addon version at the bottom left.

## 0.10.0 - 2026-11-22

- New: buff warnings in the middle of the screen. Well-Rested (below level 60): a message with sound 15 minutes before it runs out, and a text that stays while it is missing, like the tracking warning. Might of Stormwind: a message with sound 5 minutes before it runs out. The messages before the end come once and stay 10 seconds. The warnings are on by default; each has its own switch in the settings (Options -> AddOns -> isiStatsForever -> Buffs).
- The Well-Rested row turns yellow in the last 15 minutes (was 5).

## 0.9.0 - 2026-11-22

- New: buff reminder at the very top of the window for Well-Rested (sleeping bag: stacks out of 3 and time left; hidden from level 60, it only gives XP) and Might of Stormwind (world buff, Alliance: time left). Red when missing, yellow with fewer stacks or in the last 5 minutes. Each can be switched off in the settings. In combat a buff the game hides keeps its last readable state, greyed out, with the time counting on.
- New: gathering tracking warning. With herbalism or mining learned, a text stays in the middle of the screen while neither Find Herbs nor Find Minerals is on (one is enough with both professions) and goes away as soon as one is switched on. A warning sound plays once when it appears. Switchable in the settings.
- Fishing pole warning: the text now stays in the middle of the screen from combat start until the pole is taken off (before, it was only small red error text that faded out, as the raid warning function it used is missing on this client). The sound now comes every 2 seconds for as long as you are in combat with the pole (before: 5 times), also when the pole is equipped during a fight.

## 0.8.0 - 2026-11-22

The percentage behind your weapon skills has a new meaning: where it showed e.g. -0.72% it can now show 63%. Your character did not get worse - the old number was only the penalty from missing skill, the new one is how many attacks really don't hit fully.

- **Real hit value**: the percentage behind each weapon skill now is the share of auto attacks that don't hit fully against your target - no damage (missed, dodged, parried) plus only glancing; ranged: missed. Calculated from the game's own values with weapon skill, hit, expertise and dual wielding, also in combat. The small +/- from skill alone moved into the tooltip, next to the split.
- Fixed: miss vs. boss was too low (now 8% / 27% dual wielding at maximum skill, as in the game's tooltip).
- Fixed: hit includes the hit rating bonus, and the off hand uses its own value.
- Fixed: ranged hit showed the melee value.
- Fixed: fist weapons use the unarmed skill, like the game.
- Fixed: glancing blows come from the game's own functions and are also shown against targets of your level and below.

## 0.7.3 - 2026-11-21

- Estimated time to the next level: now calculated from your XP rate in the last 30 minutes of active play instead of the average over the whole level. Breaks without XP count as 5 minutes at most, so after a few idle hours the estimate matches your pace a few kills into farming. While you gain no XP, the last rate stays. The rate is kept per character across level-ups and relogs; until there is enough data (3 XP gains, 5 minutes of active play) the level average is used as before. The tooltip says which one is shown.

## 0.7.2 - 2026-11-20

- Internal audit.

## 0.7.1 - 2026-11-19

- Error log: errors of other addons (e.g. taint from another addon in Blizzard's status bars) are no longer logged as isiStatsForever errors; the log's own error handler in the stack made every error look like ours.
- Fishing pole warning: the raid warning at combat start now comes 5 times, 1 second apart, so it stays on screen longer; it stops as soon as the pole is taken off.

## 0.7.0 - 2026-11-18

### Chat history, fishing pole warning, first start

- Fresh install: the window is now its own free window and open from the start (before, it was docked to the character frame and only showed with that open, so new players saw nothing). Docking to the character frame is a choice in the settings. Existing settings stay as they are.
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
