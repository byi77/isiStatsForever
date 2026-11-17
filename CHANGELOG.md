# Changelog

## Unreleased

- Renamed to **isiStatsForever** (addon folder, title, settings page, release zip, GitHub repo). The slash commands `/isistats` and `/istats` and the saved settings stay the same.
- Skill rows in fixed columns (+/- vs. target, bonus, current / max), so the numbers line up exactly; a thin progress bar under each skill shows current / max like the game's skill panel.
- Skill tooltips show the distance to the maximum ("20 to the maximum (300)") and, for equipped weapons below the cap, that the skill rises by fighting with them.
- New setting "Show the target row without a target" (on by default).
- Saved settings of removed rows (old "vs. target" section, main-hand/off-hand/ranged skill rows) are cleaned up on login.
- Development: StyLua check in the GitHub CI.
- Development: Data.lua split into Util, Skills, Catalog, Data and CombatCache.
- Skill rows: current / max now sits at the right edge, the +/- values (vs.-target modifier, bonus) in front of it.
- Defense moved below the weapon skills and is shown like them as current / max (yellow below the cap, bonus in green); the defense section keeps the values derived from it (missed by, crit reduction, armor, ...).
- Without section headers there are no empty gaps between the sections any more; the rows form one continuous list.
- Weapon damage is on by default: melee damage for warrior, paladin and rogue, ranged damage for hunter (casters already had spell damage). Characters keep values they switched themselves.

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
