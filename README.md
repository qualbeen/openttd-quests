# OpenTTD Quests

A quest and mission system for OpenTTD. Play singleplayer or co-op with a progression tree, side quests, and real rewards — unlock vehicles, infrastructure, and economic bonuses as you build your transport empire.

## Features

- **Progression tree** — start with only buses and trucks, unlock trains, ships, aircraft, monorail, and maglev through quests
- **Side quests** — procedurally generated from your map each game for replayability
- **Co-op support** — shared quest progress within a company
- **NewGRF compatible** — dynamically classifies whatever vehicles are available, works with any vehicle set
- **Real rewards** — vehicle unlocks, infrastructure access, cash bonuses, and town reputation

## Install

1. Download the latest release from [Releases](https://github.com/qualbeen/openttd-quests/releases)
2. Extract the `openttd-quests` folder into your OpenTTD game scripts directory:
   - **Linux:** `~/.openttd/game/`
   - **macOS:** `~/Documents/OpenTTD/game/`
   - **Windows:** `Documents\OpenTTD\game\`
3. Start OpenTTD → New Game → AI/Game Script Settings → select "OpenTTD Quests"

## How It Works

The GameScript scans all available engines at game start and assigns them to unlock tiers based on their properties (vehicle type, speed, rail type, price). You start with only basic road vehicles and progressively unlock everything else by completing quests.

Quest objectives include:
- Transport cargo between towns
- Build rail networks and stations
- Grow cities to target populations
- Reach profit and company value milestones

## Contributing

Want to add a quest? See [docs/guides/contributing.md](docs/guides/contributing.md) and [docs/guides/quest-writing.md](docs/guides/quest-writing.md).

Quest proposals can be submitted as [GitHub Issues](https://github.com/qualbeen/openttd-quests/issues) using the quest proposal template.

## License

GPL v2 — same as OpenTTD.
