# EchoArchitect - WoW 3.3.5a (WotLK) Addon for Project Ebonhold

## Overview

EchoArchitect is an intelligent Echo optimizer addon for the **Project Ebonhold** WoW 3.3.5a private server. It automates and assists with the Echo perk system: picking, rerolling, banishing, and weighting echoes during runs (level 1-80). It includes full session tracking, a logbook, profile management, and a comprehensive UI.

**Version:** 3.6.2
**Interface:** 30300 (WotLK 3.3.5a)
**Slash command:** `/ea`

## Architecture

```
EchoArchitect/
├── EchoArchitect.toc          # Addon manifest (load order matters!)
└── src/
    ├── serialize.lua           # Custom serializer/deserializer (EA1: format)
    ├── data/perkdb.lua         # Static perk database (EchoArchitect_PerkDB)
    ├── db.lua                  # DB utilities: class masks, perk metadata, spell cache
    ├── utils.lua               # Shared utility functions (EA.Utils)
    ├── profiles.lua            # Profile system (per-character SavedVariables)
    ├── logbook.lua             # Global logbook (cross-character SavedVariables)
    ├── priors.lua              # Static prior frequency data for echo appearances
    ├── run.lua                 # Run/session state machine (picks, XP, timing)
    ├── stats.lua               # Stat computation from perks + ash tree
    ├── engine.lua              # Core decision engine + automation ticker
    └── ui/
        ├── theme.lua           # Color constants and theme definitions
        ├── widgets.lua         # Reusable UI widget factories
        ├── startstop.lua       # Floating start/stop automation button
        ├── window.lua          # Main window frame + tab navigation
        ├── pages_dashboard.lua # Dashboard tab (current offer, decision, session stats)
        ├── pages_settings.lua  # Settings tab (automation config, UI scale)
        ├── pages_library.lua   # Library tab (browse all echoes, set weights/blacklist)
        ├── pages_current_echoes.lua  # Current echoes tab (owned perks view)
        ├── pages_history.lua   # History tab (run action history with detail view)
        ├── pages_logbook.lua   # Logbook tab (aggregate stats, export/import)
        ├── pages_profiles.lua  # Profiles tab (create/clone/switch/delete profiles)
        ├── pages_help.lua      # Help tab (in-addon documentation)
        └── init.lua            # Entry point: event handling, slash command, addon panel
```

## Key Concepts

### SavedVariables
- **`EchoArchitect_Logbook`** (global, cross-character): Aggregate logbook data (seen/picked/banished counts, rarity distribution, session highlights)
- **`EchoArchitect_CharDB`** (per-character): Profiles, weights, blacklists, buckets, run state, session state, UI preferences

### Echo System
- Echoes are perks identified by `spellId` + `quality` (0=Common, 1=Uncommon, 2=Rare, 3=Epic, 4=Legendary)
- Keys are formatted as `"spellId:quality"` (e.g., `"200000:0"`)
- Each echo has a `classMask` (bitmask for allowed classes), `maxStack`, `groupId`, and optional `requiredSpell`

### Decision Engine (engine.lua)
The engine runs on a 0.12s ticker (`OnUpdate`) and makes automated decisions:
1. **Score** each offered echo: `(baseWeight + qualityBonus) * qualityMultiplier * ownedFactor`
2. **Decision priority**: pause (multiple above threshold) > pick (above minKeepScore) > banish (blacklisted) > reroll (below threshold) > fallback pick (best available)
3. Actions: `pick`, `reroll`, `banish`, `pause`

### Profile System
- Per-character profiles with weights, blacklists, buckets, automation settings, and scoring rules
- Profiles can be exported/imported using the `EA1:` serialization format
- Supports clone, rename, delete operations

### Hooks
- The engine hooks into `ProjectEbonhold.PerkService` (SelectPerk, RequestReroll, BanishPerk) to track manual actions
- PerkUI is optionally hidden during automated runs

## External API Dependencies (Project Ebonhold)

The addon interacts with these Ebonhold-specific globals:
- `ProjectEbonhold.PerkService` — `.GetCurrentChoice()`, `.SelectPerk()`, `.RequestReroll()`, `.BanishPerk()`, `.GetGrantedPerks()`, `.GetLockedPerks()`
- `ProjectEbonhold.PerkUI` — `.Show()`, `.Hide()`, `.UpdateSinglePerk()`
- `ProjectEbonhold.PlayerRunService` — `.GetCurrentData()`
- `ProjectEbonhold.Constants` — `.ENABLE_BANISH_SYSTEM`
- `ProjectEbonhold.SkillTree` — `.LoadoutsData` (ash tree integration)
- `_G.EbonholdPlayerRunData` — Fallback run data global
- `_G.ProjectEbonholdPerkFrame` — The perk selection UI frame
- `TalentDatabase` — Ash tree talent data

## Development Guidelines

### Code Style
- Minimal whitespace, compact Lua style
- Heavy use of `tonumber(x or 0) or 0` for nil-safe number access
- Local aliases at file top: `local EA = EchoArchitect`, `local E = EA.Engine`, etc.
- No external libraries — pure WoW API + custom serializer

### Load Order (Critical!)
Files load in `.toc` order. Dependencies flow top-down:
1. `serialize.lua` — No dependencies
2. `data/perkdb.lua` — Sets `EchoArchitect_PerkDB` global
3. `db.lua` — Reads `EchoArchitect_PerkDB`
4. `utils.lua` — Shared utilities (`EA.Utils`); uses `EA.Engine` lazily
5. `profiles.lua` — Uses `EA.DB` (not via upvalue, lazy access)
6. `logbook.lua` — Uses `EA.DB`
7. `priors.lua` — Static data, no dependencies
8. `run.lua` — Uses `EA.Logbook`
9. `stats.lua` — Uses `EA.Profiles`, Ebonhold APIs
10. `engine.lua` — Uses everything above; aliases `EA.Utils.*`
11. `ui/*` — Uses all core modules + `EA.Utils`
12. `init.lua` — Wires everything together on `ADDON_LOADED`

### Testing Considerations
- No automated test framework; testing is done in-game
- Use `/ea` to open the UI and verify behavior
- The engine can be enabled/disabled via the start/stop button
- History tab shows detailed decision traces for debugging

### Common Patterns
- Nil-safe chaining: `if EA.Run and EA.Run.GetRun then EA.Run:GetRun() end`
- pcall wrapping for Ebonhold API calls (they may not exist)
- `CreateFrame("Frame")` with `OnUpdate` scripts for timers/tickers

## Optimization Status

### Applied Fixes (v3.6.2 optimization pass)

1. ~~Redundant `tonumber(x or 0) or 0` chains~~ — Low priority; ~275 occurrences but most are at system boundaries. **Not fixed** (minimal risk/benefit ratio).
2. **FIXED** — Duplicate `getRunData()`, `rerollsRemaining()`, `banishesRemaining()` extracted to `EA.Utils` in `src/utils.lua`. Engine and startstop now alias from the shared module.
3. **FIXED** — See #2.
4. **FIXED** — `countOwnedStacks()` now has a tick-level cache (0.12s TTL) that prevents redundant API calls within the same tick.
5. **FIXED** — `bucketOverCap()` benefits from #4's cache; `countOwnedStacks()` results are reused across calls in the same tick.
6. **FIXED** — `DB:IterPerks()` results are now cached per `showAll` flag, invalidated on `SPELLS_CHANGED` event.
7. ~~`Logbook:SeedFromDB()` iterates all perks on init~~ — Runs once at load; now benefits from #6's cached `IterPerks()`. **Acceptable**.
8. **FIXED** — `Stats:SpellStatContribution()` now caches tooltip scan results per `spellId` in `S._statCache`.
9. ~~Engine ticker micro-optimizations~~ — **Not fixed** (negligible impact; ticker is already well-structured).
10. **N/A** — Globals are intentional SavedVariables. No accidental leaks.
11. **FIXED** — `GetActiveProfile()` now skips `deepMerge` and migration after the first call via `_eaMerged` flag on the profile table.
12. **FIXED** — `run.history` is now pruned to a maximum of 500 entries (keeps the most recent).
13. **FIXED** — See #11. `_v` migration only runs once (guarded by `_eaMerged`).
14. ~~`explainDecision()` builds large tables~~ — **Not fixed** (only runs on action events, not every tick; overhead is negligible).
15. ~~Serializer string concatenation~~ — **Not fixed** (minimal impact for addon use case).
16. **FIXED** — Duplicated utility functions extracted:
    - `QualityName()`, `ShowSpellTooltip()`, `ReasonText()`, `ParseKey()`/`keyParts()`, `GetRunData()`, `RerollsRemaining()`, `BanishesRemaining()` → `EA.Utils` module (`src/utils.lua`)
    - `solid()` → exposed as `T:Solid()` in `theme.lua`; dashboard and current_echoes now use it
17. **FIXED** — `W:BindCommit` and `W:AttachSpellTooltip` are now bound once at row creation in `pages_library.lua`. Callbacks reference mutable row data instead of closures.
18. **FIXED** — Unescaped backslashes corrected to `"Interface\\Buttons\\WHITE8X8"` in `pages_settings.lua` and `pages_help.lua`.
19. **FIXED** — Dead code in `pages_help.lua` line 317: `CreateTexture` global check removed; now calls `content:CreateTexture()` directly.
20. **FIXED** — `pages_profiles.lua` now uses a `FauxScrollFrame` for the profile list. Profiles beyond 14 are scrollable.
21. ~~`enforcePageAttach()` race condition workaround~~ — **Not fixed** (structural change to page registration system; risk outweighs benefit).
22. **FIXED** — No-op `if d.scale==nil then d.scale=nil end` removed from `pages_dashboard.lua`.
23. ~~Nil-safety gaps for `p.automation`~~ — **Not fixed** (already properly guarded with `and` chains; `_eaMerged` ensures `automation` table exists after first access).
24. **FIXED** — Variable shadowing in `pages_logbook.lua` line 466: outer `s` renamed to `ss`, removed unused `k` and `asc` variables. Inner sort comparator now uses `ss.sortKey`/`ss.sortAsc`.

**Additional fix:** Variable `io` in `pages_profiles.lua` shadowed Lua's built-in `io` library. Renamed to `ioBox`.

### Remaining Opportunities

- **#1**: Bulk `tonumber(x or 0) or 0` cleanup — Low priority, many are at system boundaries
- **#7**: Lazy `Logbook:SeedFromDB()` — Acceptable as-is with cached `IterPerks`
- **#9**: Engine ticker idle optimization — Negligible impact
- **#14**: Lazy `explainDecision()` — Only runs on actions, not ticks
- **#15**: Serializer `table.concat` — Minimal impact
- **#21**: Page registration system refactor — Structural change, risk outweighs benefit
