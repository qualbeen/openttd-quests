# OpenTTD Quest System — Design Spec

## Overview

A GameScript (Squirrel) that adds a quest/mission system to OpenTTD with a locked progression model. Players start with only buses and trucks, unlocking trains, ships, aircraft, monorail, and maglev by completing quests. Supports singleplayer and co-op (shared company progress).

## Architecture

Pure GameScript — single Squirrel package, no companion NewGRF required. Distributed as a folder drop into OpenTTD's `game/` directory or via GitHub Releases.

### Components

| File | Responsibility |
|------|---------------|
| `info.nut` | GS metadata: name, version, author, configurable settings |
| `main.nut` | Entry point. `GSController::Start()` main loop. Initializes all subsystems, runs tick loop |
| `engine_classifier.nut` | Scans all engines at game start via `GSEngineList`. Assigns each to a tier (0-6) based on vehicle type, rail type, speed, and price. Locks/unlocks via `GSEngine.EnableForCompany()` / `DisableForCompany()` |
| `quest_manager.nut` | Tracks quest state per company. Checks completion conditions each tick cycle. Triggers rewards on completion. Manages quest dependencies (prerequisite chains) |
| `quest_defs.nut` | Hand-crafted progression quest definitions — objectives, rewards, prerequisites, story text |
| `side_quest_generator.nut` | At game start, generates side quests from map data — picks real towns, industries, distances. Templates define generation rules |
| `quest_ui.nut` | Manages Story Pages (quest log, lore, reward previews) and Goals (active objective tracking with progress text) |
| `rewards.nut` | Applies rewards: tier unlocks (via engine_classifier), cash bonuses, town authority rating boosts (via `GSTown.ChangeRating()`) |
| `save_load.nut` | Serializes/deserializes all state via GS `Save()` / `Load()` table |
| `lang/english.txt` | String table for all UI text |

### Main Loop

```
Start():
  1. Classify all engines → tier map
  2. If new game: lock all engines except Tier 0, generate side quests
     If loaded save: restore state from Save table
  3. Initialize UI (story pages, goals)
  4. Loop (every ~74 ticks / ~1 game day):
     a. For each company:
        - Check active quest conditions against game state
        - Update goal progress text
        - If quest completed: apply rewards, advance quest state, update UI
        - If new quests available: show notification, add to quest log
     b. Sleep(74)
```

## Tier System

Seven unlock tiers, gated by progression quests.

| Tier | Name | Unlocks | Gate Quest |
|------|------|---------|------------|
| 0 | Getting Started | Basic road vehicles (buses, mail trucks, cargo trucks) | *(available from start)* |
| 1 | The Iron Road | Normal rail locomotives + wagons, more road vehicles | "Trucker's Life" — deliver 200 cargo by truck |
| 2 | Sea & Expansion | All ships, better trains, trams | "Rail Network" — 5 towns by rail + $50k profit |
| 3 | Electrification | Electric rail type + electric locomotives | "Trade Empire" — $500k company value + 8 towns |
| 4 | Taking Flight | All aircraft, airports, remaining road vehicles | "Industrial Giant" — 5 cargo types + $1M value |
| 5 | Monorail Age | Monorail rail type + vehicles | "Transport Mogul" — 15 towns + all 4 transport types |
| 6 | Maglev Mastery | Maglev rail type + vehicles | "Continental Network" — 20 towns + $5M value |

## Engine Classification Algorithm

At game start, the classifier scans every engine via `GSEngineList` and assigns a tier using these rules:

1. **Aircraft** → Tier 4
2. **Ships** → Tier 2
3. **Road vehicles**: split by price relative to median. Cheaper half → Tier 0 (starter), expensive half → split by speed into Tier 1 / Tier 4
4. **Trains by rail type**:
   - Maglev → Tier 6
   - Monorail → Tier 5
   - Electric → Tier 3
   - Normal rail: split by speed relative to median. Slower → Tier 1, faster → Tier 2
5. **Wagons**: classified by their rail type, same as locomotives

This works with any NewGRF vehicle set — no hardcoded engine IDs.

### Engine availability rules

- At game start: `DisableForCompany()` all engines above Tier 0 for all companies
- On tier unlock: `EnableForCompany()` all engines in that tier
- Engines with a future `GetDesignDate()`: enabled when both the tier is unlocked AND the game date reaches the design date
- New companies joining mid-game: immediately apply current unlock state

## Progression Quests

~25 hand-crafted quests across 7 tiers. Each tier has 3-4 quests before a gate quest.

### Tier 0 — Getting Started
1. **"First Wheels"** — Buy your first vehicle. Reward: $10,000
2. **"Bus Baron"** — Run a bus route earning $5,000/yr. Reward: $25,000
3. **"City Transit"** — Build 4+ bus stops within a single town (all within the same town's authority area) and transport 200 passengers between them. Reward: $20,000 + town reputation boost
4. **"Connect the Dots"** — Bus service to 3 towns. Reward: $30,000
5. **"Trucker's Life"** *(gate)* — Deliver 200 cargo by truck. Reward: **Unlocks Tier 1**

### Tier 1 — The Iron Road
6. **"The Iron Road"** — Connect 2 towns by rail, minimum 20 tiles of track. Reward: $50,000
7. **"Passenger Express"** — Transport 500 passengers by train. Reward: $40,000
8. **"Growing Pains"** — Grow any town to 1,000 pop. Reward: Town reputation boost
9. **"Rail Network"** *(gate)* — 5 towns by rail, total network at least 100 tiles + $50,000 profit. Reward: **Unlocks Tier 2**

### Tier 2 — Sea & Expansion
10. **"Set Sail"** — Build a dock and run a ship route. Reward: $60,000
11. **"Oil Tycoon"** — Transport 500 oil by ship or train. Reward: $75,000
12. **"Metropolis"** — Grow a town to 3,000 pop. Reward: Town reputation boost
13. **"Trade Empire"** *(gate)* — $500k company value + 8 towns connected. Reward: **Unlocks Tier 3**

### Tier 3 — Electrification
14. **"Power Up"** — Build 20 tiles of electrified rail. Reward: $100,000
15. **"High Speed"** — Run an electric train over 100 km/h. Reward: Reduced running costs (temporary)
16. **"Megacity"** — Grow a town to 10,000 pop. Reward: Town reputation boost
17. **"Industrial Giant"** *(gate)* — Transport 5 different cargo types + $1M value. Reward: **Unlocks Tier 4**

### Tier 4 — Taking Flight
18. **"Wright Brothers"** — Build an airport and fly 1 aircraft. Reward: $150,000
19. **"Air Bridge"** — Connect 2 cities 200+ tiles apart by air. Reward: $200,000
20. **"Transport Mogul"** *(gate)* — 15 towns connected + all 4 transport types used. Reward: **Unlocks Tier 5**

### Tier 5 — Monorail Age
21. **"The Future Is Now"** — Build 50+ tiles of monorail. Reward: $300,000
22. **"Speed Demon"** — Monorail train over 200 km/h. Reward: $250,000
22. **"Continental Network"** *(gate)* — 20 towns connected, total network at least 500 tiles + $5M value. Reward: **Unlocks Tier 6**

### Tier 6 — Maglev Mastery
24. **"Levitation"** — Build a maglev line and run a train. Reward: $500,000
25. **"Master of Transport"** *(final)* — 30 towns, $10M value, 50k population served. Reward: Victory

## Side Quests

Generated at game start from map data. Each side quest references actual towns and industries on the map.

### Generation rules
- Number of side quests scales with map size (~10-15 per game)
- Each side quest has a minimum tier requirement (can't get ship quests before Tier 2)
- Side quests give cash rewards only — tier unlocks are always on the main path
- Templates define the generation pattern; specific towns/industries are picked at random

### Side quest templates

| Template | Min Tier | Pattern | Reward Range |
|----------|----------|---------|-------------|
| Town Express | 0 | Run buses between {Town A} and {Town B} | $10k-20k |
| Cargo Hauler | 0 | Truck {amount} cargo from {Industry} to {Town} | $15k-25k |
| Coal Run | 1 | Deliver {amount} coal from {Mine} to {Power Station} | $25k-40k |
| Passenger Line | 1 | Transport {amount} passengers by train between {Town A} and {Town B} | $30k-45k |
| Island Supply | 2 | Ship goods to the most remote town | $40k-60k |
| Bulk Shipping | 2 | Ship {amount} cargo between ports | $45k-65k |
| City Builder | 1 | Grow {Town} by {factor}x its starting population | $35k-50k |
| Metro Service | 0 | Build {N} bus stops within {Town} (all in same authority area), transport {amount} passengers internally | $15k-30k |
| One-Way System | 0 | Build a one-way street network in {Town} spanning {X}+ tiles. Only straight one-way segments count — turns and crossings are excluded. At most 20% of road tiles in the network may be turns/crossings | $20k-35k |
| Jet Setter | 4 | Fly {amount} passengers between {City A} and {City B} | $80k-120k |

## Quest UI

### Story Book (quest log)
- One page per active/available quest showing: name, flavor text, objectives list, rewards preview
- Completed quests get a completion page with a summary
- Location elements link to relevant map tiles (towns, industries)
- New tier unlocks get a celebratory story page

### Goal Window (active tracking)
- Each active quest objective appears as a Goal with progress text
- Progress updates automatically (e.g., "Passengers: 342/500")
- Goals marked completed when objective is met
- Goal destination links to relevant map location

### Notifications
- News message when a quest is completed
- News message when a new tier is unlocked
- Story page auto-opens on tier unlock to show what's now available

## Co-op / Multiplayer

- Quest state is tracked per company, not per player
- Any player in a company contributes to quest progress
- Tier unlocks apply to the whole company
- Multiple companies have independent quest progression
- New companies joining mid-game start at Tier 0

## Save / Load

All state serialized via the GS `Save()` function returning a table:

```
{
  version: 1,
  companies: {
    0: {
      unlocked_tiers: [0, 1, 2],
      quest_states: { "tier0_first_wheels": "completed", "tier1_iron_road": "in_progress", ... },
      quest_progress: { "tier1_passenger_express": { passengers: 342 }, ... },
      side_quests: [ { id: "side_1", template: "coal_run", mine_id: 5, station_id: 12, ... }, ... ]
    },
    ...
  },
  engine_tiers: { 0: [1, 3, 5, 7], 1: [10, 11, 15], ... },
  side_quest_pool: [ ... ]
}
```

On load, the classifier does NOT re-scan engines — it uses the saved tier map to ensure consistency (engines don't shift tiers mid-game if a NewGRF somehow changes).

## Configurable Settings (info.nut)

Exposed via OpenTTD's GS settings dialog before game start:

| Setting | Default | Description |
|---------|---------|-------------|
| `difficulty` | `normal` | `easy` / `normal` / `hard` — scales objective amounts (0.5x / 1x / 2x) |
| `side_quest_count` | `auto` | Number of side quests to generate (`auto` = based on map size) |
| `cash_rewards` | `on` | Enable/disable cash reward bonuses |
| `start_tier` | `0` | Start with higher tiers already unlocked (for experienced players) |

## Definitions

- **"Town connected"**: a town is connected to your network if your company has at least one station within the town's authority area that has been serviced (had a vehicle load/unload) within the last year
- **"Town reputation boost"**: calls `GSTown.ChangeRating(town, company, +200)` for the nearest serviced town, improving the local authority's opinion of the company
- **"Transport types used"**: having at least one active vehicle of each type (road, rail, ship, aircraft) that has generated revenue in the current year

## Testing Strategy

- Manual playtesting on small maps (256x256) for fast iteration
- Test each tier gate quest is achievable
- Test with default vehicles and at least one popular NewGRF set (e.g., NUTS)
- Test save/load at various progression states
- Test new company joining mid-game in multiplayer
- Test on maps with no industries of certain types (edge case for side quest generation)
