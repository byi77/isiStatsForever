# Changelog

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
