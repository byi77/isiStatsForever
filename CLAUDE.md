# Project Instructions

isiStatsForever is a character stats addon for **WoW Forever** only. The repo lives in
`C:\Git\isiStatsForever` (public: `byi77/isiStatsForever`, CurseForge project `1812815`); the game folder
`C:\World of Warcraft\_forever_\Interface\AddOns\isiStatsForever` only gets the addon files through
`tools/deploy_local.ps1`. Rules adapted from isiLive; see also `AGENTS.md` and `docs/RULES.md`.

## Language

- Chat responses and thinking: always in German (Deutsch) - every reply, also short status lines
  and replies after English tool output, code or commit text.
- Code and code comments: always in English.
- `README.md` and `CHANGELOG.md` stay English; all other maintained docs are German.

## Files

`Locale.lua` texts - `ErrorLog.lua` own error log - `Util.lua` guarded calls, secret values,
formatting, formulas - `Skills.lua` skill lines and weapon slots - `Tracking.lua` gathering tracking warning - `Warnings.lua` class and gear warnings - `Buffs.lua` buff reminder - `Flights.lua` measured flight times - `Catalog.lua` value rows and
class defaults - `Data.lua` collects the sections - `CombatCache.lua` last values in combat -
`UI.lua` window - `Options.lua` settings page - `Core.lua` saved variables, events, slash commands.

## Target client

- Only WoW Forever: client `1.60.x`, `## Interface: 16001`. No support code for retail, Classic Era
  or other flavors.
- Forever is a modern client (retail engine) with classic rules. Classic-era APIs may be missing:
  - No `GetNumSkillLines` / `GetSkillLineInfo` / `GetSpellInfo`. Skills come from
    `C_SkillInfo.GetSkillLineInfoByID(skillLineID)` (skill line IDs are locale independent,
    see `SKILL` in `Skills.lua`). The classic skill list stays only as a guarded fallback.
  - Settings page: `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory`;
    `InterfaceOptions_AddCategory` only as fallback.
  - Textures for the client (icons) must be `.tga` (or `.blp`), never `.png`. `media/corner_*.tga`
  are isiLive's own generated corner textures (rounded window, ring, shadow).
- Every WoW API call goes through `call()` in `Util.lua` (type check + `pcall`). Never call a
  `C_*` member bare; a removed member reads as `nil` and must fail closed.
- Screen alerts: `UI.SetAlert(key, text or nil)`, texts that stay while their cause lasts (buff
  "runs out soon": 10 s), with the
  warning sound once when one appears. Exception fishing pole: sound every 2 s while in combat
  (user decisions 2026-11-22; no fading notices). `RaidNotice_AddMessage` is a deprecation shim that is nil
  unless cvar `loadDeprecationFallbacks` is set. Before using a classic global, check that
  Blizzard's source defines it outside `Blizzard_Deprecated*`.
- Minimap tracking: `C_Minimap.GetTrackingInfo(i)` (`spellID`, `active`), event
  `MINIMAP_UPDATE_TRACKING`; herbs 2383 / 8387, minerals 2580 / 8388.
- Buff reminder: a new buff is one entry in `Buffs.LIST` (`Buffs.lua`, fields documented there); no
  catalog, locale or option edits. Take every spell ID of the name from the game data.
- Buff warnings (user decision 2026-11-22): `warnMissing` = text stays like the tracking warning;
  `warnMinutes` = one message before the end (10 s, once per buff run, also across a reload).
- Auras: `C_UnitAuras.GetPlayerAuraBySpellID` returns **nil for a hidden aura** in combat. Treat nil
  as missing only when `C_Secrets.ShouldSpellAuraBeSecret(id)` is false.
- Class and gear warnings (user request 2026-11-22): one entry in `Warnings.LIST` (`Warnings.lua`,
  fields documented there) plus `WARN_<KEY>_OPT` and its texts in enUS and deDE. Sources: soul shard
  item 6265 is a reagent as in classic (SpellReagents 1.60.1.71037); ammo = slot 0; durability =
  `GetInventoryAlertStatus` (DurabilityFrame); pet = `C_PetInfo.GetPetHappiness` (PetHappiness.lua);
  stance = `GetShapeshiftFormInfo` spell ID (StanceBar); poisons / imbues =
  `C_Item.GetWeaponEnchantInfo` (BuffFrame). Self buffs and reagents are tables generated from
  SpellReagents, SpellLevels and SkillLineAbility (class mask). Every warning is on by default for
  every class (user decision 2026-11-22). Auras: same nil-in-combat rule as below.
- Damage meter: `C_DamageMeter.ResetAllCombatSessions()` (Blizzard's own "reset all sessions"
  menu entry) on `GROUP_JOINED` / `GROUP_FORMED`, once per `partyGUID`. Neither fires on a login or
  `/reload` inside a group (user request 2026-11-22: clear once per group join).
- Flight times (`Flights.lua`, user request 2026-11-27): only own measurements. Click = post-hook on
  `TakeTaxiNode(slot)`, node IDs from `C_TaxiMap.GetAllTaxiNodes(GetTaxiMapID())` (cached on
  `TAXIMAP_OPENED`, `slotIndex` -> `nodeID`, state `Enum.FlightPathState.Current` = start), take-off
  `PLAYER_CONTROL_LOST` + `UnitOnTaxi`, landing `PLAYER_CONTROL_GAINED`. Dropped: `TaxiRequestEarlyLanding`,
  `C_SummonInfo.ConfirmSummon`, `AcceptBattlefieldPort(_, true)`, `LFG_PROPOSAL_SUCCEEDED`,
  `PLAYER_LEAVING_WORLD`. Estimate (user decision 2026-11-27, exception to no-guess): sum of saved
  times along the game's hops (`GetNumRoutes`, `TaxiGetNodeSlot(slot, hop, true)`), always shown with
  `~`, never saved. Tooltip: `HookScript("OnEnter")` on `TaxiButton<slot>` and the
  `FlightMap_FlightPointPinTemplate` pins. Never name other flight addons in repo files.
- When a feature stops producing data without an error, check the API member first
  (`/isistats debug` prints what exists).

## Secret values (combat)

Forever has the Midnight-style addon restrictions: in combat some API returns are **secret values**.

- Any arithmetic, comparison, `tostring`, `..` or `gsub` on a secret raises an error and taints the
  addon. Check `issecretvalue` (via `isSecret()` / `num()` / `str()` in `Util.lua`) **before** any
  other operation.
- Displaying is allowed: `string.format(fmt, secret)` returns a secret string that a FontString can
  show (`show()` in `Util.lua`; same technique as isiLive's stats box). Plain single API values are
  shown live this way.
- Computed values (sums, DPS, armor reduction, vs.-target modifiers) cannot be computed from secrets:
  they keep their last out-of-combat value, greyed out with a tooltip note
  (`Data.ApplyCombatCache` in `CombatCache.lua`, rows matched by `key`).
- Rows that only show when a value is > 0 (mana, parry, block value) decide in combat from the last
  plain value (`positive()`), never by comparing a secret.
- `/isistats debug` lists the API functions that returned secrets.

## Error log

`ErrorLog.lua` joins WoW's error handler chain (the previous handler is always called), keeps
isiStatsForever's own errors (message or stack contains `isiStatsForever`) de-duplicated in `IsiStatsDB.errors`
(max 30) and survives `/isistats reset`. First stop for any "geht nicht" report: `/isistats errors`.

## Numbers: source of truth

The in-game display is authoritative for numeric values - never adopt numbers from other addons or
third-party databases. Current references (WoW Forever skill panel, verified 2026-11-17):

- Hit and crit modifier: `(weapon skill - target defense) * 0.04%` at any gap.
- Target defense = target level x 5; "Schlachtzugsboss" = defense 315 (level 63).
- Glancing blows: `GetGlancingBlowChance` / `GetGlancingBlowPenalty` (0-1), never a rebuilt formula.
  They also happen against targets below the player's level (combat log 2026-11-22).
- Miss: 5% vs. your level, 8% vs. a raid boss, +19% dual wielding (`CR_*_HIT_CAP_TOOLTIP`).
- Dodge / parry: 5% / 5% vs. your level, 6.5% / 16.5% vs. a raid boss (`CR_EXPERTISE_TOOLTIP`);
  `GetExpertise()` is in percent and lowers both. The Lua tables `BASE_ENEMY_*` in Blizzard's
  `PaperDollFrame.lua` are leftovers - not a source.
- Blizzard's global strings: wago.tools/db2/GlobalStrings (build + locale). Read the tooltip texts
  there before calling a value unknown.
- Hit: `GetCombatRatingBonus(6)` + `GetHitModifier` / `GetOffhandHitModifier`; ranged
  `GetCombatRatingBonus(7)` + `GetRangedHitModifier`. Fist weapons use skill 162 (unarmed).
- Blizzard's UI source for this client: github.com/Gethe/wow-ui-source, branch `forever`.

## Hit results: calculated, not counted

User decision 2026-11-22: one percentage behind each skill = not a full hit (no damage + glancing),
calculated from the values above, not the bare skill modifier; the split only in the tooltip, no
extra rows. Checked against 514 white swings from `/combatlog` files (one-handed,
mobs 42-45): no damage 15.4% calculated / 14.4% logged, glancing 17.5% / 16.7%. Don't build a
swing counter again: 20 swings are +/-16 points, worse than the calculation. Judge a formula only
on hundreds of swings.

A target of level `??` that is not a world boss has an unknown defense: show `??`, compute nothing.

## Tests and checks

Run before every commit (the pre-commit hook does it, `git config core.hooksPath .githooks`):

```sh
stylua --check *.lua tools/*.lua
luacheck *.lua
lua tools/check_locale.lua
lua tools/load_test.lua . deDE
lua tools/load_test.lua . enUS
lua tools/class_matrix.lua . deDE   # all 9 classes: defaults, gear, every usable weapon type
```

`tools/wow_stub.lua` is the shared stub environment (loads the TOC files through the real
event handler); new tests build on it instead of their own stubs.

- `.luacheckrc` lists every WoW global the addon reads (strict). A new API must be added there;
  a use-before-define or a typo is then an error (this caught a real in-game breakage).
- `tools/load_test.lua` loads all addon files against stubbed WoW APIs and drives them through the
  real event handler and slash command. Extend it with **asserts** (exit non-zero), not prints.
  Do not re-implement addon logic in the test.

## Settings pattern

The saved variables keep their names from before the rename (`IsiStatsDB`, `IsiStatsCharDB`), and so
do the slash commands `/isistats` and `/istats` - do not rename them.

- `IsiStatsDB` (account-wide): window settings, defaults in `DEFAULTS` in `Core.lua`
  (missing keys are filled on load; a new key needs a default there).
- `IsiStatsCharDB.rows` (per character): `rows[id] = true/false` only where the user chose; `nil`
  means the class default from `Data.GetDefaults()` (`Catalog.lua`). Changing a default therefore changes it for
  everyone who never touched that row - intended, mention it in the changelog.
- A new value row needs: catalog entry in `Data.GetCatalog()` (`Catalog.lua`), an `addRow(rows, id, ...)` call in `Data.lua`,
  locale keys in enUS **and** deDE.

## UI style

isiLive "modern" look: graphite surfaces, hairline borders, cool blue accent (`C` palette in
`UI.lua`), dimmed labels. No gold glow, no scale bouncing. Colors only via the palette tokens.

## Releases and commits

- Never release (tag, CurseForge upload) unless the user explicitly asks.
- After every commit and every push (release commits included) run `tools/deploy_local.ps1` right
  away, without asking (user rule 2026-11-22), and compare the installed files with the repo. If
  the TOC's file list changed and WoW is running, don't copy: ask to close WoW first (`/reload`
  does not load new files). The script copies the working tree: say so when it holds uncommitted
  changes. Deploys without a commit or push still need the user's word.
- Release: bump `## Version` in the TOC, move `## Unreleased` in `CHANGELOG.md` to
  `## X.Y.Z - YYYY-MM-DD`, commit `release(vX.Y.Z)`, tag `vX.Y.Z`, push main then the tag. The
  release workflow checks tag = TOC version, builds the zip, publishes the GitHub release and uploads
  to CurseForge (`CF_API_KEY` secret, `X-Curse-Project-ID` in the TOC).
- Commits: author `byi77 <52194710+byi77@users.noreply.github.com>` (GitHub rejects the private
  email). **No `Co-Authored-By: Claude` trailer** - only the user is listed as contributor.
