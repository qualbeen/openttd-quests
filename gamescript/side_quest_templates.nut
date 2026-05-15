// AUTO-GENERATED from quests/side-quests/*.yaml
// Do not edit manually — run: python3 scripts/generate_quest_defs.py

class SideQuestTemplates {
    static function GetAll(multiplier) {
        return [
            {
                template = "cargo_hauler",
                tier = 0,
                name_fmt = "Hauler for %s",
                desc_fmt = "Truck cargo from %s to %s",
                needs = "industry_and_town",
                check_type = ObjType.TRANSPORT_CARGO,
                obj_params = { amount = (100 * multiplier).tointeger() },
                reward_min = 15000, reward_max = 25000,
                mult = multiplier
            },
            {
                template = "city_builder",
                tier = 1,
                name_fmt = "Grow %s",
                desc_fmt = "Grow %s to %d population",
                needs = "one_town",
                check_type = ObjType.GROW_TOWN,
                obj_params = {},
                reward_min = 35000, reward_max = 50000,
                mult = multiplier
            },
            {
                template = "island_supply",
                tier = 2,
                name_fmt = "Supply %s by sea",
                desc_fmt = "Ship goods to %s",
                needs = "one_town",
                check_type = ObjType.BUILD_DOCK_AND_SHIP,
                obj_params = {},
                reward_min = 40000, reward_max = 60000,
                mult = multiplier
            },
            {
                template = "jet_setter",
                tier = 4,
                name_fmt = "Flights to %s",
                desc_fmt = "Fly passengers between %s and %s",
                needs = "two_towns_far",
                picker_params = { min_distance = 100 },
                check_type = ObjType.AIR_BRIDGE,
                obj_params = { min_distance = 100 },
                reward_min = 80000, reward_max = 120000,
                mult = multiplier
            },
            {
                template = "passenger_line",
                tier = 1,
                name_fmt = "Rail to %s",
                desc_fmt = "Transport passengers by train between %s and %s",
                needs = "two_towns",
                check_type = ObjType.TRANSPORT_PASSENGERS_RAIL,
                obj_params = { amount = (300 * multiplier).tointeger() },
                reward_min = 30000, reward_max = 45000,
                mult = multiplier
            },
            {
                template = "town_express",
                tier = 0,
                name_fmt = "Express to %s",
                desc_fmt = "Run a bus between %s and %s",
                needs = "two_towns",
                check_type = ObjType.CONNECT_TOWNS_ROAD,
                obj_params = { min_towns = 2 },
                reward_min = 10000, reward_max = 20000,
                mult = multiplier
            }
        ];
    }
}
