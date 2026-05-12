# OpenTTD Quests — Development Guide

## Project Overview

An OpenTTD GameScript (Squirrel language) that adds a quest/mission system with vehicle unlock progression.

## Architecture

- `gamescript/` — the installable GameScript (Squirrel `.nut` files)
- `quests/` — human-readable quest definitions in YAML
- `docs/` — player and contributor documentation
- `plans/` — implementation plans

## Key Technical Details

- **Language:** Squirrel 2 (OpenTTD's scripting language)
- **API:** OpenTTD GameScript API (GSGoal, GSStoryPage, GSEngine, etc.)
- **Vehicle unlocks:** `GSEngine.EnableForCompany()` / `DisableForCompany()`
- **Engine discovery:** `GSEngineList` + `GSEngine` properties for dynamic tier classification
- **UI:** Story Pages for quest log, Goals for objective tracking
- **Save/Load:** Via GS `Save()` / `Load()` table serialization

## Development

- Test by copying `gamescript/` to your OpenTTD `game/` directory
- Only one GameScript can run at a time in OpenTTD
- GameScript must be selected before starting a new game
- Quest definitions in `quests/` are the source of truth; `quest_defs.nut` is generated/synced from them

## Conventions

- Quest YAML files use the format defined in `docs/guides/quest-writing.md`
- Progression quests are numbered by tier (tier-0, tier-1, etc.)
- Side quest templates define generation rules, not specific instances
