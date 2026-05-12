# Writing Quests

Quests are defined as YAML files in `quests/progression/` (main tree) or `quests/side-quests/` (bonus quests).

## Progression Quest Format

```yaml
id: "tier1_first_railway"
name: "The Iron Road"
tier: 1
description: "Build your first railway connection between two towns."

prerequisites:
  - "tier0_bus_service"

objectives:
  - type: "connect_towns"
    params:
      min_towns: 2
      transport_type: "rail"
    description: "Connect at least 2 towns with a rail line"

  - type: "transport_cargo"
    params:
      cargo: "passengers"
      amount: 100
      transport_type: "rail"
    description: "Transport 100 passengers by rail"

rewards:
  - type: "unlock_tier"
    tier: 1
    description: "Unlocks basic train engines"

  - type: "cash"
    amount: 50000
    description: "Bonus: $50,000"

story:
  title: "The Iron Road"
  text: >
    The roads are getting crowded. The townspeople have heard
    of this new invention — the railway. Connect two towns
    with steel rails and show them the future of transport.
```

## Side Quest Template Format

```yaml
id: "side_cargo_express"
name: "Cargo Express"
type: "side_quest"
generation: "procedural"

template:
  pick:
    source: "random_industry"
    destination: "random_town"
    cargo: "from_source"

  objectives:
    - type: "transport_cargo"
      params:
        cargo: "{picked.cargo}"
        amount: 200
        from: "{picked.source}"
        to: "{picked.destination}"

  rewards:
    - type: "cash"
      amount: 25000
```

## Objective Types

| Type | Parameters | Description |
|------|-----------|-------------|
| `transport_cargo` | `cargo`, `amount`, `from`, `to`, `transport_type` | Deliver cargo between locations |
| `connect_towns` | `min_towns`, `transport_type` | Connect towns with transport links |
| `grow_town` | `town` (or `any`), `target_population` | Grow a town to a target size |
| `build_station` | `min_platforms`, `transport_type` | Build a station meeting criteria |
| `reach_profit` | `amount`, `period` | Reach a profit target |
| `company_value` | `amount` | Reach a company value |

## Tips

- Keep objectives achievable in 15-60 minutes of gameplay
- Rewards should feel proportional to effort
- Side quests should work on any map — use procedural templates
- Test with both small (256x256) and large (1024x1024) maps
