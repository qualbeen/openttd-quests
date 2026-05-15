# Writing Quests

Quests are defined as YAML files in `quests/progression/` (main progression tree) or `quests/side-quests/` (procedural bonus quests).

Run `python3 scripts/generate_quest_defs.py` to regenerate the Squirrel files after editing YAML. The install script does this automatically.

## Progression Quest Format

```yaml
quests:
  - id: "tier1_iron_road"
    name: "The Iron Road"
    tier: 1
    prerequisites:
      - "tier0_truckers_life"

    # Optional: Archipelago multiworld randomizer integration
    archipelago:
      location_id: 100006    # Unique AP location ID

    objectives:
      - type: "connect_towns_rail"
        params:
          min_towns: 2
          min_tiles: 20
        desc: "Connect 2 towns with at least 20 tiles of railway"

    rewards:
      - type: "cash"
        amount: 50000
        archipelago:
          item_id: 200006    # Unique AP item ID

    story: >
      The age of rail has arrived. Lay down at least 20 tiles of
      track and connect 2 towns by railway.
```

## Difficulty Scaling

Numeric parameters are automatically scaled by the difficulty multiplier (0.5x easy, 1x normal, 2x hard).

**Scaled by default:** `amount`, `target`, `min_passengers`, `min_profit`

**Never scaled:** `min_towns`, `min_stops`, `count`, `min_speed`, `min_distance`, `vehicle_type`, `min_tiles`

To override the default for a specific parameter, use the explicit form:

```yaml
params:
  min_tiles: { value: 20, scaled: true }
```

## String Interpolation

Use `{param_name}` placeholders in `desc` and `story` fields. Scaled values are automatically computed:

```yaml
desc: "Transport {amount} passengers by rail"
# Generates: "Transport " + (500 * mult).tointeger() + " passengers by rail"
```

For quests with multiple objectives, reference a specific objective's param with `{N.param_name}`:

```yaml
story: >
  Reach {1.amount} company value and serve {2.amount} citizens.
# Uses amount from objective index 1 and 2 respectively
```

## Side Quest Template Format

Side quest templates define procedural quest generation rules, not specific instances. Each template is a separate YAML file in `quests/side-quests/`.

```yaml
template: "town_express"
tier: 0
name_fmt: "Express to %s"
desc_fmt: "Run a bus between %s and %s"
needs: "two_towns"
objective_type: "connect_towns_road"
objective_params:
  min_towns: 2
reward_range:
  min: 10000
  max: 20000
story_suffix: "The people are counting on you!"
```

### Picker Types (`needs`)

| Type | Description |
|------|-------------|
| `two_towns` | Pick 2 random towns |
| `two_towns_far` | Pick 2 towns at least `picker_params.min_distance` apart |
| `industry_and_town` | Pick an industry and its nearest town |
| `one_town` | Pick a single random town |

### Dynamic Parameters

For templates where objective params depend on runtime data:

```yaml
dynamic_params:
  target: "max(pop * 2, 500)"    # Squirrel expression evaluated at generation time
```

## Objective Types

| Type | Parameters | Description |
|------|-----------|-------------|
| `buy_vehicle` | `count` | Purchase vehicles |
| `route_profit` | `amount`, `vehicle_type` | Single vehicle profit threshold |
| `connect_towns_road` | `min_towns` | Connect towns via road |
| `connect_towns_rail` | `min_towns`, `min_tiles` | Connect towns via rail |
| `transport_cargo` | `amount` | Deliver cargo units |
| `connect_town_internal` | `min_stops`, `min_passengers` | Multiple stops within one town |
| `transport_passengers_rail` | `amount` | Deliver passengers by train |
| `grow_town` | `target` | Grow town population |
| `rail_network` | `min_towns`, `min_tiles`, `min_profit` | Build rail network |
| `build_dock_and_ship` | _(none)_ | Build dock, operate ship |
| `transport_oil` | `amount` | Deliver oil |
| `company_value` | `amount` | Reach company value |
| `build_electrified_rail` | `min_tiles` | Build electrified track |
| `electric_train_speed` | `min_speed` | Electric train speed |
| `transport_cargo_types` | `count` | Transport N different cargo types |
| `build_airport_and_fly` | _(none)_ | Build airport, operate aircraft |
| `air_bridge` | `min_distance` | Air route spanning distance |
| `all_transport_types` | _(none)_ | Use all 4 transport modes |
| `build_monorail` | `min_tiles` | Build monorail |
| `monorail_speed` | `min_speed` | Monorail speed threshold |
| `network_size` | `min_towns`, `min_tiles` | Large network size |
| `build_maglev` | _(none)_ | Build maglev |
| `total_pop_served` | `amount` | Serve total population |

## Reward Types

| Type | Parameters | Description |
|------|-----------|-------------|
| `cash` | `amount` | Money bonus (scaled by difficulty) |
| `unlock_tier` | `tier` | Unlock vehicle tier (0-6) |
| `reputation` | `amount` | Town authority rating boost (not scaled) |
| `victory` | _(none)_ | Game completion |

## Archipelago Integration

Optional fields for future [Archipelago](https://archipelago.gg/) multiworld randomizer support:

- `archipelago.location_id` on quests — unique numeric ID for the quest as a "location" (check)
- `archipelago.item_id` on rewards — unique numeric ID for the reward as an "item" (receive)

ID ranges: locations start at 100001, items start at 200001.

## Tips

- Keep objectives achievable in 15-60 minutes of gameplay
- Rewards should feel proportional to effort
- Side quests should work on any map — use procedural templates
- Test with both small (256x256) and large (1024x1024) maps
- Run the converter after changes: `python3 scripts/generate_quest_defs.py`
