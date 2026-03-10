# EchoArchitect

**Intelligent Echo Optimizer for Project Ebonhold (WoW 3.3.5a WotLK)**

EchoArchitect automates and assists with the Echo perk system on the [Project Ebonhold](https://projectebonhold.com) private server. It handles picking, rerolling, banishing, and weighting echoes during runs (Level 1-80), with full session tracking, a logbook, profile management, and a comprehensive UI.

**Version:** 3.6.2 | **Interface:** 30300 (WotLK 3.3.5a)

---

## Table of Contents

- [Installation](#installation)
- [Getting Started](#getting-started)
- [The Weight System](#the-weight-system)
- [Scoring Formula](#scoring-formula)
- [Decision Engine](#decision-engine)
- [Buckets](#buckets)
- [Settings Reference](#settings-reference)
- [Profiles](#profiles)
- [UI Tabs Overview](#ui-tabs-overview)
- [Import & Export](#import--export)
- [Tips & Best Practices](#tips--best-practices)
- [Troubleshooting](#troubleshooting)
- [Contact & Support](#contact--support)

---

## Installation

1. Download or clone this repository.
2. Copy the `EchoArchitect/` folder (the one containing `EchoArchitect.toc`) into your WoW addons directory:
   ```
   World of Warcraft/Interface/AddOns/EchoArchitect/
   ```
3. Make sure the folder structure looks like this:
   ```
   Interface/AddOns/EchoArchitect/
   ├── EchoArchitect.toc
   └── src/
       ├── serialize.lua
       ├── data/perkdb.lua
       ├── db.lua
       ├── utils.lua
       ├── profiles.lua
       ├── logbook.lua
       ├── priors.lua
       ├── run.lua
       ├── stats.lua
       ├── engine.lua
       └── ui/
           ├── theme.lua
           ├── widgets.lua
           ├── startstop.lua
           ├── window.lua
           ├── pages_dashboard.lua
           ├── pages_settings.lua
           ├── pages_library.lua
           ├── pages_current_echoes.lua
           ├── pages_history.lua
           ├── pages_logbook.lua
           ├── pages_profiles.lua
           ├── pages_help.lua
           └── init.lua
   ```
4. Launch WoW 3.3.5a and ensure the addon is enabled in the addon list on the character selection screen.
5. Log in and type `/ea` to open the EchoArchitect window.

---

## Getting Started

### Opening the UI

Type `/ea` in the chat to toggle the EchoArchitect window. You can also find it under **Interface > AddOns > EchoArchitect** in the game settings.

### First-Time Setup

1. **Open EchoArchitect** with `/ea`.
2. Go to the **Library** tab.
3. Set **weights** for echoes you care about. Higher weight = higher priority.
4. Optionally create **buckets** to group similar echoes and prevent over-stacking.
5. Go to the **Settings** tab and configure your automation preferences.
6. Click the **Start** button (floating button at the top of the screen) to begin automation.

### The Start/Stop Button

A floating button appears at the top of your screen. It shows:
- Current automation state (Running / Stopped / Paused)
- Remaining echoes, rerolls, and banishes (configurable)
- The reason if automation paused (e.g., "Paused: Threshold Met")

Click it to toggle automation on or off. You can drag it by the thin bar at the top.

---

## The Weight System

EchoArchitect makes every decision based on **weights**. Each echo has a numerical weight value that represents how much you want it.

- **Positive weight** = desirable echo (higher = more desirable)
- **Zero weight** = neutral (addon will still consider it)
- **Negative weight** = undesirable (addon will avoid it)
- **Blacklisted** = never pick, candidate for banishing

You assign weights in the **Library** tab. Think of weights as your personal preference scale.

### Quality Modifiers

Each rarity tier (Common, Uncommon, Rare, Epic, Legendary) can have:
- **Quality Bonus**: Flat value added to the base weight
- **Quality Multiplier**: Multiplies the total after bonus is applied

These are set globally in the **Settings** tab under "Scoring".

---

## Scoring Formula

Every time the addon evaluates an echo offer, it calculates a **final score** for each option:

```
Final Score = (Base Weight + Quality Bonus) x Quality Multiplier x Owned Factor
```

Where:
- **Base Weight** = the weight you set for this echo in the Library
- **Quality Bonus** = the flat bonus for this echo's rarity (e.g., +5 for Rare)
- **Quality Multiplier** = the multiplier for this echo's rarity (e.g., 1.5x for Epic)
- **Owned Factor** = penalty for already owning stacks of this echo

### Owned Factor (Duplicate Penalty)

```
Owned Factor = 1 - (Duplicate Penalty% x Number of Owned Stacks)
```

Example: If Duplicate Penalty is 20% and you own 2 stacks:
```
Owned Factor = 1 - (0.20 x 2) = 0.60
```

The echo's score is reduced to 60% of its normal value.

---

## Decision Engine

The engine runs on a 0.12-second ticker and follows a strict priority order:

### Decision Priority (Top to Bottom)

| Priority | Action | Condition |
|----------|--------|-----------|
| 1 | **Pause** | 2+ options score above threshold (`pauseIfMultipleAbove` enabled) |
| 2 | **Pause** | All options are blacklisted or have negative weight (`pauseIfOnlyBlacklisted` enabled) |
| 3 | **Pick** | Best option scores above `minKeepScore + aggressiveness` |
| 4 | **Banish** | A blacklisted echo is shown and banishes are available |
| 5 | **Reroll** | Best option scores below threshold, rerolls available, and level/reroll limits not exceeded |
| 6 | **Pick Best** | Fallback: picks the highest-scoring option regardless of threshold |

### Safety Mechanisms

- **Continuous Reroll Limit**: Prevents rerolling endlessly (configurable, default: 1)
- **Minimum Level Before Rerolling**: Won't reroll before a certain echo level (default: 12)
- **Multiple Above Threshold Pause**: Pauses so you can manually choose between good options
- **Blacklist-Only Pause**: Pauses when all options are undesirable

---

## Buckets

Buckets prevent over-stacking similar effects. They group echoes by category (e.g., "Hit Rating", "Crit", "Survivability").

### How Buckets Work

1. Create a bucket in the Library tab (e.g., "Hit Rating").
2. Assign echoes to the bucket (e.g., Keen Aim, Precision Strike).
3. Set a **max stacks** value for the bucket.
4. When the bucket reaches its limit, the weight of echoes in that bucket is reduced.

### Why Buckets Matter

Without buckets, automation may over-value repeated stats. For example, it might keep picking Hit Rating echoes even after you've hit the cap. Buckets prevent this by tracking how many effects of each type you already have.

### Example

- Bucket: "Hit Rating" with max stacks = 3
- Echoes assigned: Keen Aim, Precise Shot
- After picking 3 hit rating echoes, the addon reduces the weight of any further hit echoes

---

## Settings Reference

### Automation Toggles

| Setting | Default | Description |
|---------|---------|-------------|
| Enable Picking | On | Allow the addon to automatically pick echoes |
| Enable Rerolling | On | Allow the addon to automatically reroll |
| Enable Banishing | On | Allow the addon to automatically banish |
| Show Start/Stop Button | On | Display the floating automation button |
| Hide Perk Frame While Running | Off | Hide the Ebonhold perk UI during automation |

### Reroll Behavior

| Setting | Default | Description |
|---------|---------|-------------|
| Automation Speed | 0.25s | Delay between automated actions (0.05 - 1.5s) |
| Pause if 2+ Above Threshold | Off | Pause when multiple good options appear |
| Threshold | 0 | Weight value that triggers the "multiple above" pause |
| Pause if Only Blacklisted | On | Pause when all options are blacklisted/negative |
| Reroll Aggressiveness | Normal (0.5) | How eagerly the addon rerolls (None / Mild / Normal / Aggressive) |
| Max Continuous Rerolls | 1 | Maximum rerolls in a row before forcing a pick |
| Min Level Before Rerolling | 12 | Don't reroll before this echo level |
| Only Reroll Below Weight | - | Only reroll if best option is below this weight |

### Scoring

| Setting | Default | Description |
|---------|---------|-------------|
| Duplicate Echo Penalty | 0% | Weight reduction per owned stack (0-100%) |
| Quality Bonus (per tier) | 0 | Flat value added per rarity (Common through Legendary) |
| Quality Multiplier (per tier) | 1.0 | Multiplier applied per rarity (Common through Legendary) |

### UI Settings

| Setting | Default | Description |
|---------|---------|-------------|
| UI Scale | 1.0 | Scale of the EchoArchitect window (0.7-1.3) |
| Show Remaining Echoes | On | Display on the Start/Stop button |
| Show Remaining Rerolls | On | Display on the Start/Stop button |
| Show Remaining Banishes | On | Display on the Start/Stop button |

---

## Profiles

Profiles store your complete EchoArchitect configuration including:
- All echo weights
- Bucket assignments
- Quality bonuses and multipliers
- Automation settings
- Blacklists

### Managing Profiles

In the **Profiles** tab you can:

| Action | Description |
|--------|-------------|
| **Create New** | Create a fresh profile with default settings |
| **Copy Selected** | Clone an existing profile under a new name |
| **Set Active** | Switch to a different profile (applies immediately) |
| **Delete** | Remove a profile (cannot delete the active profile) |
| **Export Selected** | Generate a shareable string of the profile |
| **Import To Selected** | Overwrite a profile with an imported string |

### Profile Tips

- Keep one stable "Main" profile for your primary build.
- Create test profiles for experimentation.
- Always export before making major changes.
- Name profiles clearly (e.g., "Arms PvE", "Frost Leveling").
- If behavior feels inconsistent, verify you're on the correct profile.
- Share profiles with others on the Ebonhold Discord!

---

## UI Tabs Overview

### Dashboard

The Dashboard is your live view during a session:
- **Current Offer**: The echoes currently being offered, with their scores
- **Decision**: What the addon decided (pick, reroll, banish, pause) and why
- **Session Stats**: Picks made, rerolls used, banishes used, session time
- **Progress Bars**: Echo level progress and run progress

Updates in real time while automation is running.

### Library

Where you configure individual echo weights and manage buckets.

**Echo List (Left Panel):**
- Browse all available echoes (filtered by your class by default)
- Toggle "Show All" to see echoes from other classes
- Set weight per echo, toggle blacklist, assign to buckets
- Search by name

**Inspector (Right Panel):**
- Detailed info about the selected echo: name, quality, tooltip, weight, bucket, owned stacks, class restrictions

**Bucket Panel:**
- Create/delete buckets, set max stacks, view assigned echoes

### Current Echoes

Shows all echoes you currently own in the active run, with stack counts and details.

### History

Detailed log of every action during the current run:
- Level, echo name, rerolls used, action taken, source (auto/manual)
- Click any entry to see the full decision trace: all offered echoes, their scores, and the reasoning

### Logbook

Aggregate statistics across all sessions and characters:
- How often each echo has been seen, picked, and banished
- Rarity distribution breakdown
- Session highlights
- Export/import logbook data

### Settings

All automation, scoring, and UI configuration (see [Settings Reference](#settings-reference)).

### Profiles

Profile management: create, clone, switch, delete, export, import (see [Profiles](#profiles)).

### Help

In-addon documentation covering weights, buckets, profiles, settings, and support info.

---

## Import & Export

### Exporting a Profile

1. Go to the **Profiles** tab.
2. Select the profile you want to export.
3. Click **Export Selected**.
4. Copy the generated string from the text box.

### Importing a Profile

1. Go to the **Profiles** tab.
2. Select or create the profile you want to overwrite.
3. Paste the export string into the text box.
4. Click **Import To Selected**.
5. Review weights, buckets, and automation settings.

### Important Warning

When importing or exporting large logbook databases, the game client may freeze temporarily. This is normal. **Do not** force close the game, Alt+F4, or reload the UI repeatedly. Wait for the operation to complete.

---

## Tips & Best Practices

### Weight Setup

- Start with simple weights: +10 for echoes you want, 0 for neutral, -10 for undesirable.
- Refine gradually based on your experience.
- Use quality multipliers sparingly - they can cause unexpected score jumps.

### Automation

- Start with conservative settings (low aggressiveness, reroll limit 1).
- Increase aggressiveness once your weights are well-tuned.
- Use "Pause if 2+ Above Threshold" for important decisions.
- Set "Min Level Before Rerolling" to avoid wasting rerolls on early levels.

### Buckets

- Create buckets for stat categories (Hit, Crit, Haste, Survivability).
- Set reasonable max stacks based on stat caps.
- Not every echo needs a bucket - only those you want to limit.

### General

- Always export your profile before major changes.
- The History tab is your best debugging tool - check it when behavior seems wrong.
- Avoid extreme weight values (1000+) unless you truly want that echo above all others.
- Automation amplifies your logic - it does not replace build knowledge.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Addon doesn't appear | Verify folder structure: `Interface/AddOns/EchoArchitect/EchoArchitect.toc` must exist |
| `/ea` does nothing | Check if addon is enabled in the character select addon list |
| Automation not picking | Check if automation is started (Start/Stop button), and if Enable Picking is on in Settings |
| Automation paused unexpectedly | Check the Start/Stop button text for the reason (threshold, blacklist-only, session complete) |
| Wrong echoes being picked | Verify active profile, check weights in Library, review History for decision trace |
| UI looks too small/large | Adjust UI Scale in Settings (0.7-1.3) |
| Frame position stuck | Use Interface > AddOns > EchoArchitect > "Reset Frame Position" |
| Import/Export freezes game | This is normal for large data. Wait for it to complete |

---

## Saved Variables

EchoArchitect stores data in two WoW SavedVariables:

| Variable | Scope | Contents |
|----------|-------|----------|
| `EchoArchitect_Logbook` | Global (all characters) | Aggregate logbook data, seen/picked/banished counts, rarity distribution |
| `EchoArchitect_CharDB` | Per-character | Profiles, weights, blacklists, buckets, run state, session state, UI preferences |

These are stored in your WoW `WTF/` folder and persist between sessions.

---

## Contact & Support

For feedback, bug reports, or feature requests:

**Discord:** `badutski2`

When reporting a bug, please include:
- The exact error message (if any)
- What you were doing before it happened
- When exactly it occurred
- Steps to reproduce

When suggesting a feature, please include:
- The goal of the feature
- Where it should appear in the UI
- How it should behave in edge cases
- What problem it solves
