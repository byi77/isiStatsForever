# Project Instructions

isiStats is a character stats addon for **WoW Forever** only. The repo lives directly in the
addon folder `C:\World of Warcraft\_forever_\Interface\AddOns\isiStats` (public: `byi77/isiStats`,
CurseForge project `1812815`). Rules adapted from isiLive; see also `AGENTS.md` and `docs/RULES.md`.

## Language

- Chat responses and thinking: always in German (Deutsch) - every reply, also short status lines
  and replies after English tool output, code or commit text.
- Code and code comments: always in English.
- `README.md` and `CHANGELOG.md` stay English; all other maintained docs are German.

## Target client

- Only WoW Forever: client `1.60.x`, `## Interface: 16001`. No support code for retail, Classic Era
  or other flavors.
- Forever is a modern client (retail engine) with classic rules. Classic-era APIs may be missing:
  - No `GetNumSkillLines` / `GetSkillLineInfo` / `GetSpellInfo`. Skills come from
    `C_SkillInfo.GetSkillLineInfoByID(skillLineID)` (skill line IDs are locale independent,
    see `SKILL` in `Data.lua`). The classic skill list stays only as a guarded fallback.
  - Settings page: `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory`;
    `InterfaceOptions_AddCategory` only as fallback.
  - Textures for the client (icons) must be `.tga` (or `.blp`), never `.png`. `media/corner_*.tga`
  are isiLive's own generated corner textures (rounded window, ring, shadow).
- Every WoW API call goes through `call()` in `Data.lua` (type check + `pcall`). Never call a
  `C_*` member bare; a removed member reads as `nil` and must fail closed.
- When a feature stops producing data without an error, check the API member first
  (`/isistats debug` prints what exists).

## Secret values (combat)

Forever has the Midnight-style addon restrictions: in combat some API returns are **secret values**.

- Any arithmetic, comparison, `tostring`, `..` or `gsub` on a secret raises an error and taints the
  addon. Check `issecretvalue` (via `isSecret()` / `num()` / `str()` in `Data.lua`) **before** any
  other operation.
- Displaying is allowed: `string.format(fmt, secret)` returns a secret string that a FontString can
  show (`show()` in `Data.lua`; same technique as isiLive's stats box). Plain single API values are
  shown live this way.
- Computed values (sums, DPS, armor reduction, vs.-target modifiers) cannot be computed from secrets:
  they keep their last out-of-combat value, greyed out with a tooltip note
  (`Data.ApplyCombatCache`, rows matched by `key`).
- Rows that only show when a value is > 0 (mana, parry, block value) decide in combat from the last
  plain value (`positive()`), never by comparing a secret.
- `/isistats debug` lists the API functions that returned secrets.

## Error log

`ErrorLog.lua` joins WoW's error handler chain (the previous handler is always called), keeps
isiStats' own errors (message or stack contains `isiStats`) de-duplicated in `IsiStatsDB.errors`
(max 30) and survives `/isistats reset`. First stop for any "geht nicht" report: `/isistats errors`.

## Numbers: source of truth

The in-game display is authoritative for numeric values - never adopt numbers from other addons or
third-party databases. Current references (WoW Forever skill panel, verified 2026-11-17):

- Hit and crit modifier: `(weapon skill - target defense) * 0.04%` at any gap.
- Target defense = target level x 5; "Schlachtzugsboss" = defense 315 (level 63).
- Glancing blows: chance `10% + (defense - min(skill, 5 x level)) * 2%`, capped 0-100; damage
  reduction from `1.3 - 0.05 x diff` (0.01-0.91) and `1.2 - 0.03 x diff` (0.2-0.99) averaged
  (skill 203 vs. 315 -> 100% / 89% less, matches the panel).

A target of level `??` that is not a world boss has an unknown defense: show `??`, compute nothing.

## Tests and checks

Run before every commit (the pre-commit hook does it, `git config core.hooksPath .githooks`):

```sh
stylua --check *.lua tools/*.lua
luacheck *.lua
lua tools/check_locale.lua
lua tools/load_test.lua . deDE
lua tools/load_test.lua . enUS
lua tools/class_matrix.lua . deDE   # all 9 classes: defaults, gear, wand/thrown/bow
```

`tools/wow_stub.lua` is the shared stub environment (loads the TOC files through the real
event handler); new tests build on it instead of their own stubs.

- `.luacheckrc` lists every WoW global the addon reads (strict). A new API must be added there;
  a use-before-define or a typo is then an error (this caught a real in-game breakage).
- `tools/load_test.lua` loads all addon files against stubbed WoW APIs and drives them through the
  real event handler and slash command. Extend it with **asserts** (exit non-zero), not prints.
  Do not re-implement addon logic in the test.

## Settings pattern

- `IsiStatsDB` (account-wide): window settings, defaults in `DEFAULTS` in `Core.lua`
  (missing keys are filled on load; a new key needs a default there).
- `IsiStatsCharDB.rows` (per character): `rows[id] = true/false` only where the user chose; `nil`
  means the class default from `Data.GetDefaults()`. Changing a default therefore changes it for
  everyone who never touched that row - intended, mention it in the changelog.
- A new value row needs: catalog entry in `Data.GetCatalog()`, an `addRow(rows, id, ...)` call,
  locale keys in enUS **and** deDE.

## UI style

isiLive "modern" look: graphite surfaces, hairline borders, cool blue accent (`C` palette in
`UI.lua`), dimmed labels. No gold glow, no scale bouncing. Colors only via the palette tokens.

## Releases and commits

- Never release (tag, CurseForge upload) unless the user explicitly asks.
- Release: bump `## Version` in the TOC, move `## Unreleased` in `CHANGELOG.md` to
  `## X.Y.Z - YYYY-MM-DD`, commit `release(vX.Y.Z)`, tag `vX.Y.Z`, push main then the tag. The
  release workflow checks tag = TOC version, builds the zip, publishes the GitHub release and uploads
  to CurseForge (`CF_API_KEY` secret, `X-Curse-Project-ID` in the TOC).
- Commits: author `byi77 <52194710+byi77@users.noreply.github.com>` (GitHub rejects the private
  email). **No `Co-Authored-By: Claude` trailer** - only the user is listed as contributor.
