# Changelog

## Unreleased

- Melee: the main/off-hand weapon skill rows are gone; the skills are listed under weapon skills.
- Combat: values the game hides from addons (secret values) are still shown live where they come straight from the game (attributes, health, crit, hit, dodge, parry, block, armor, resistances, spell values), the same way isiLive's stats box does it. Values that need calculating (attack power total, DPS, armor reduction, vs.-target modifiers) keep their last value from before the fight, greyed out with a tooltip note. `/isistats debug` lists which game functions were hidden.
- Every weapon skill row shows its hit/crit modifier against the current target (defense = level x 5) right behind the skill; the row above the list names the target. Tooltip: hit, crit and glancing blows. Without a hostile target it compares against an enemy of your level, like the game's skill panel.
- Window is slightly wider (270) so skill rows fit the extra value.
- Miss chance vs. boss now uses the game panel's 0.04% per skill point.

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
