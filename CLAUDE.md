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
4. `profiles.lua` — Uses `EA.DB` (not via upvalue, lazy access)
5. `logbook.lua` — Uses `EA.DB`
6. `priors.lua` — Static data, no dependencies
7. `run.lua` — Uses `EA.Logbook`
8. `stats.lua` — Uses `EA.Profiles`, Ebonhold APIs
9. `engine.lua` — Uses everything above
10. `ui/*` — Uses all core modules
11. `init.lua` — Wires everything together on `ADDON_LOADED`

### Testing Considerations
- No automated test framework; testing is done in-game
- Use `/ea` to open the UI and verify behavior
- The engine can be enabled/disabled via the start/stop button
- History tab shows detailed decision traces for debugging

### Common Patterns
- Nil-safe chaining: `if EA.Run and EA.Run.GetRun then EA.Run:GetRun() end`
- pcall wrapping for Ebonhold API calls (they may not exist)
- `CreateFrame("Frame")` with `OnUpdate` scripts for timers/tickers

## Known Optimization Opportunities

### Performance
1. **Redundant `tonumber(x or 0) or 0` chains** — ~275 occurrences. Many are on values already known to be numbers
2. **Duplicate `getRunData()` function** — Defined identically in both `engine.lua` and `startstop.lua`; should be shared via `EA.Engine` or a utility
3. **Duplicate `rerollsRemaining()` / `banishesRemaining()`** — Also duplicated between `engine.lua` and `startstop.lua`
4. **`countOwnedStacks()` called per-choice per-tick** — Could cache results for the duration of a single tick
5. **`bucketOverCap()` iterates all bucket echoKeys** calling `countOwnedStacks()` for each — O(n*m) per decision
6. **`DB:IterPerks()` rebuilds full sorted list** every time it's called (used in logbook seeding, library page)
7. **`Logbook:SeedFromDB()` iterates all perks on init** — could be deferred or lazy
8. **Tooltip scanning in `Stats:SpellStatContribution()`** — No caching, re-scans on every `Compute()` call
9. **Engine ticker at 0.12s** — Calls `getCurrentOfferEx()` + `normalizeChoice()` + `GetSpellInfo()` every tick even when idle

### Code Quality
10. **Globals**: `EchoArchitect`, `EchoArchitect_PerkDB`, `EchoArchitect_Logbook`, `EchoArchitect_CharDB` are intentional (SavedVariables). No accidental global leaks detected
11. **`deepMerge` is called on every `GetActiveProfile()`** — Runs on every engine tick via profile access
12. **History entries accumulate unboundedly** in `run.history` — No pruning mechanism; long sessions could grow large
13. **`_v` migration in `GetActiveProfile()`** runs every call instead of once
14. **`explainDecision()` builds large diagnostic tables** even when not displayed
15. **Serializer** uses string concatenation in a loop (`serPretty`); could use `table.concat` more aggressively
