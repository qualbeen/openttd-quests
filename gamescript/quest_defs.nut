// Quest Definitions
// Defines all objective types, reward types, and the 25 progression quests

enum ObjType {
    BUY_VEHICLE,
    ROUTE_PROFIT,
    CONNECT_TOWNS_ROAD,
    TRANSPORT_CARGO,
    CONNECT_TOWN_INTERNAL,
    CONNECT_TOWNS_RAIL,
    TRANSPORT_PASSENGERS_RAIL,
    GROW_TOWN,
    RAIL_NETWORK,
    BUILD_DOCK_AND_SHIP,
    TRANSPORT_OIL,
    COMPANY_VALUE,
    BUILD_ELECTRIFIED_RAIL,
    ELECTRIC_TRAIN_SPEED,
    TRANSPORT_CARGO_TYPES,
    BUILD_AIRPORT_AND_FLY,
    AIR_BRIDGE,
    ALL_TRANSPORT_TYPES,
    BUILD_MONORAIL,
    MONORAIL_SPEED,
    NETWORK_SIZE,
    BUILD_MAGLEV,
    TOTAL_POP_SERVED
}

enum RewardType {
    CASH,
    UNLOCK_TIER,
    REPUTATION,
    VICTORY
}

class QuestDefs {
    static function GetAll(difficulty_mult) {
        local m = difficulty_mult;

        return [
            // ========== TIER 0 (5 quests) ==========

            {
                id = "tier0_first_wheels",
                name = "First Wheels",
                tier = 0,
                prerequisites = [],
                objectives = [
                    {
                        type = ObjType.BUY_VEHICLE,
                        params = { count = 1 },
                        desc = "Purchase your first vehicle"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (10000 * m).tointeger() }
                ],
                story = "Every empire starts with a single vehicle. Buy your first road vehicle and begin your journey to transportation dominance."
            },

            {
                id = "tier0_bus_baron",
                name = "Bus Baron",
                tier = 0,
                prerequisites = [],
                objectives = [
                    {
                        type = ObjType.ROUTE_PROFIT,
                        params = { amount = (5000 * m).tointeger(), vehicle_type = GSVehicle.VT_ROAD },
                        desc = "Earn " + (5000 * m).tointeger() + " from a single road vehicle"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (25000 * m).tointeger() }
                ],
                story = "Prove your routes are profitable. Make a single road vehicle earn " + (5000 * m).tointeger() + " in lifetime profit."
            },

            {
                id = "tier0_city_transit",
                name = "City Transit",
                tier = 0,
                prerequisites = [],
                objectives = [
                    {
                        type = ObjType.CONNECT_TOWN_INTERNAL,
                        params = { min_stops = 4, min_passengers = (200 * m).tointeger() },
                        desc = "Build a city bus network with 4 stops and transport " + (200 * m).tointeger() + " passengers"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (20000 * m).tointeger() },
                    { type = RewardType.REPUTATION, amount = 200 }
                ],
                story = "Cities need internal transit. Build a network with at least 4 stops and move " + (200 * m).tointeger() + " passengers within a single town."
            },

            {
                id = "tier0_connect_dots",
                name = "Connect the Dots",
                tier = 0,
                prerequisites = [],
                objectives = [
                    {
                        type = ObjType.CONNECT_TOWNS_ROAD,
                        params = { min_towns = 3 },
                        desc = "Connect at least 3 towns with road routes"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (30000 * m).tointeger() }
                ],
                story = "Expand your network beyond a single town. Link at least 3 towns together with profitable road routes."
            },

            {
                id = "tier0_truckers_life",
                name = "Trucker's Life",
                tier = 0,
                prerequisites = [],
                objectives = [
                    {
                        type = ObjType.TRANSPORT_CARGO,
                        params = { amount = (200 * m).tointeger() },
                        desc = "Transport " + (200 * m).tointeger() + " units of any cargo"
                    }
                ],
                rewards = [
                    { type = RewardType.UNLOCK_TIER, tier = 1 }
                ],
                story = "Time to haul some freight! Transport " + (200 * m).tointeger() + " units of cargo to unlock rail technology."
            },

            // ========== TIER 1 (4 quests) ==========

            {
                id = "tier1_iron_road",
                name = "The Iron Road",
                tier = 1,
                prerequisites = ["tier0_truckers_life"],
                objectives = [
                    {
                        type = ObjType.CONNECT_TOWNS_RAIL,
                        params = { min_towns = 2, min_tiles = 20 },
                        desc = "Connect 2 towns with at least 20 tiles of railway"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (50000 * m).tointeger() }
                ],
                story = "The age of rail has arrived. Lay down at least 20 tiles of track and connect 2 towns by railway."
            },

            {
                id = "tier1_passenger_express",
                name = "Passenger Express",
                tier = 1,
                prerequisites = ["tier1_iron_road"],
                objectives = [
                    {
                        type = ObjType.TRANSPORT_PASSENGERS_RAIL,
                        params = { amount = (500 * m).tointeger() },
                        desc = "Transport " + (500 * m).tointeger() + " passengers by rail"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (40000 * m).tointeger() }
                ],
                story = "Trains move people efficiently. Transport " + (500 * m).tointeger() + " passengers using your railway network."
            },

            {
                id = "tier1_growing_pains",
                name = "Growing Pains",
                tier = 1,
                prerequisites = ["tier1_iron_road"],
                objectives = [
                    {
                        type = ObjType.GROW_TOWN,
                        params = { target = (1000 * m).tointeger() },
                        desc = "Grow a town to " + (1000 * m).tointeger() + " population"
                    }
                ],
                rewards = [
                    { type = RewardType.REPUTATION, amount = 200 }
                ],
                story = "Good service attracts settlers. Grow any town to a population of " + (1000 * m).tointeger() + " through excellent transport."
            },

            {
                id = "tier1_rail_network",
                name = "Rail Network",
                tier = 1,
                prerequisites = ["tier1_passenger_express", "tier1_growing_pains"],
                objectives = [
                    {
                        type = ObjType.RAIL_NETWORK,
                        params = { min_towns = 5, min_tiles = 100, min_profit = (50000 * m).tointeger() },
                        desc = "Build a network connecting 5 towns with 100 rail tiles, earning " + (50000 * m).tointeger() + " profit"
                    }
                ],
                rewards = [
                    { type = RewardType.UNLOCK_TIER, tier = 2 }
                ],
                story = "Your railway empire expands. Connect 5 towns with 100+ tiles of track and earn " + (50000 * m).tointeger() + " to unlock maritime transport."
            },

            // ========== TIER 2 (4 quests) ==========

            {
                id = "tier2_set_sail",
                name = "Set Sail",
                tier = 2,
                prerequisites = ["tier1_rail_network"],
                objectives = [
                    {
                        type = ObjType.BUILD_DOCK_AND_SHIP,
                        params = {},
                        desc = "Build a dock and operate a ship"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (60000 * m).tointeger() }
                ],
                story = "The seas beckon. Build a dock and put your first ship into service."
            },

            {
                id = "tier2_oil_tycoon",
                name = "Oil Tycoon",
                tier = 2,
                prerequisites = ["tier2_set_sail"],
                objectives = [
                    {
                        type = ObjType.TRANSPORT_OIL,
                        params = { amount = (500 * m).tointeger() },
                        desc = "Transport " + (500 * m).tointeger() + " units of oil"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (75000 * m).tointeger() }
                ],
                story = "Black gold flows through your network. Transport " + (500 * m).tointeger() + " units of oil to fuel the economy."
            },

            {
                id = "tier2_metropolis",
                name = "Metropolis",
                tier = 2,
                prerequisites = ["tier2_set_sail"],
                objectives = [
                    {
                        type = ObjType.GROW_TOWN,
                        params = { target = (3000 * m).tointeger() },
                        desc = "Grow a town to " + (3000 * m).tointeger() + " population"
                    }
                ],
                rewards = [
                    { type = RewardType.REPUTATION, amount = 200 }
                ],
                story = "Create a thriving metropolis. Grow a town to " + (3000 * m).tointeger() + " citizens through multi-modal transport."
            },

            {
                id = "tier2_trade_empire",
                name = "Trade Empire",
                tier = 2,
                prerequisites = ["tier2_oil_tycoon", "tier2_metropolis"],
                objectives = [
                    {
                        type = ObjType.COMPANY_VALUE,
                        params = { amount = (500000 * m).tointeger() },
                        desc = "Reach company value of " + (500000 * m).tointeger()
                    },
                    {
                        type = ObjType.CONNECT_TOWNS_ROAD,
                        params = { min_towns = 8 },
                        desc = "Connect 8 towns by road"
                    }
                ],
                rewards = [
                    { type = RewardType.UNLOCK_TIER, tier = 3 }
                ],
                story = "Your empire flourishes. Reach a company value of " + (500000 * m).tointeger() + " and connect 8 towns to unlock electric rail."
            },

            // ========== TIER 3 (4 quests) ==========

            {
                id = "tier3_power_up",
                name = "Power Up",
                tier = 3,
                prerequisites = ["tier2_trade_empire"],
                objectives = [
                    {
                        type = ObjType.BUILD_ELECTRIFIED_RAIL,
                        params = { min_tiles = (20 * m).tointeger() },
                        desc = "Build " + (20 * m).tointeger() + " tiles of electrified railway"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (100000 * m).tointeger() }
                ],
                story = "The future is electric. Build " + (20 * m).tointeger() + " tiles of electrified railway to modernize your network."
            },

            {
                id = "tier3_high_speed",
                name = "High Speed Rail",
                tier = 3,
                prerequisites = ["tier3_power_up"],
                objectives = [
                    {
                        type = ObjType.ELECTRIC_TRAIN_SPEED,
                        params = { min_speed = 100 },
                        desc = "Operate an electric train reaching 100 km/h"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (80000 * m).tointeger() }
                ],
                story = "Speed is the name of the game. Get an electric train to reach 100 km/h on your network."
            },

            {
                id = "tier3_megacity",
                name = "Megacity",
                tier = 3,
                prerequisites = ["tier3_power_up"],
                objectives = [
                    {
                        type = ObjType.GROW_TOWN,
                        params = { target = (10000 * m).tointeger() },
                        desc = "Grow a town to " + (10000 * m).tointeger() + " population"
                    }
                ],
                rewards = [
                    { type = RewardType.REPUTATION, amount = 200 }
                ],
                story = "Build a true megacity. Grow a town to " + (10000 * m).tointeger() + " population with world-class transport infrastructure."
            },

            {
                id = "tier3_industrial_giant",
                name = "Industrial Giant",
                tier = 3,
                prerequisites = ["tier3_high_speed", "tier3_megacity"],
                objectives = [
                    {
                        type = ObjType.TRANSPORT_CARGO_TYPES,
                        params = { count = 5 },
                        desc = "Transport at least 5 different cargo types"
                    },
                    {
                        type = ObjType.COMPANY_VALUE,
                        params = { amount = (1000000 * m).tointeger() },
                        desc = "Reach company value of " + (1000000 * m).tointeger()
                    }
                ],
                rewards = [
                    { type = RewardType.UNLOCK_TIER, tier = 4 }
                ],
                story = "Diversify and dominate. Transport 5 cargo types and reach " + (1000000 * m).tointeger() + " company value to unlock aviation."
            },

            // ========== TIER 4 (3 quests) ==========

            {
                id = "tier4_wright_brothers",
                name = "Wright Brothers",
                tier = 4,
                prerequisites = ["tier3_industrial_giant"],
                objectives = [
                    {
                        type = ObjType.BUILD_AIRPORT_AND_FLY,
                        params = {},
                        desc = "Build an airport and operate an aircraft"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (150000 * m).tointeger() }
                ],
                story = "Take to the skies! Build an airport and put your first aircraft into operation."
            },

            {
                id = "tier4_air_bridge",
                name = "Air Bridge",
                tier = 4,
                prerequisites = ["tier4_wright_brothers"],
                objectives = [
                    {
                        type = ObjType.AIR_BRIDGE,
                        params = { min_distance = 200 },
                        desc = "Operate an air route spanning 200 tiles"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (200000 * m).tointeger() }
                ],
                story = "Connect distant lands by air. Establish a profitable route spanning at least 200 tiles."
            },

            {
                id = "tier4_transport_mogul",
                name = "Transport Mogul",
                tier = 4,
                prerequisites = ["tier4_air_bridge"],
                objectives = [
                    {
                        type = ObjType.CONNECT_TOWNS_ROAD,
                        params = { min_towns = 15 },
                        desc = "Connect 15 towns by road"
                    },
                    {
                        type = ObjType.ALL_TRANSPORT_TYPES,
                        params = {},
                        desc = "Operate all transport types: road, rail, water, and air"
                    }
                ],
                rewards = [
                    { type = RewardType.UNLOCK_TIER, tier = 5 }
                ],
                story = "Master all modes of transport. Connect 15 towns by road and operate road, rail, ship, and air vehicles to unlock monorail."
            },

            // ========== TIER 5 (3 quests) ==========

            {
                id = "tier5_future_is_now",
                name = "The Future Is Now",
                tier = 5,
                prerequisites = ["tier4_transport_mogul"],
                objectives = [
                    {
                        type = ObjType.BUILD_MONORAIL,
                        params = { min_tiles = 50 },
                        desc = "Build 50 tiles of monorail"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (300000 * m).tointeger() }
                ],
                story = "Embrace cutting-edge technology. Build 50 tiles of monorail to revolutionize your network."
            },

            {
                id = "tier5_speed_demon",
                name = "Speed Demon",
                tier = 5,
                prerequisites = ["tier5_future_is_now"],
                objectives = [
                    {
                        type = ObjType.MONORAIL_SPEED,
                        params = { min_speed = 200 },
                        desc = "Operate a monorail reaching 200 km/h"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (250000 * m).tointeger() }
                ],
                story = "Push the limits of speed. Get a monorail vehicle to reach 200 km/h on your network."
            },

            {
                id = "tier5_continental_network",
                name = "Continental Network",
                tier = 5,
                prerequisites = ["tier5_speed_demon"],
                objectives = [
                    {
                        type = ObjType.NETWORK_SIZE,
                        params = { min_towns = 20, min_tiles = 500 },
                        desc = "Connect 20 towns with 500 tiles of track"
                    },
                    {
                        type = ObjType.COMPANY_VALUE,
                        params = { amount = (5000000 * m).tointeger() },
                        desc = "Reach company value of " + (5000000 * m).tointeger()
                    }
                ],
                rewards = [
                    { type = RewardType.UNLOCK_TIER, tier = 6 }
                ],
                story = "Your network spans the continent. Connect 20 towns with 500 tiles of rail and reach " + (5000000 * m).tointeger() + " value to unlock maglev."
            },

            // ========== TIER 6 (2 quests) ==========

            {
                id = "tier6_levitation",
                name = "Levitation",
                tier = 6,
                prerequisites = ["tier5_continental_network"],
                objectives = [
                    {
                        type = ObjType.BUILD_MAGLEV,
                        params = {},
                        desc = "Build maglev infrastructure and operate a maglev train"
                    }
                ],
                rewards = [
                    { type = RewardType.CASH, amount = (500000 * m).tointeger() }
                ],
                story = "The ultimate in rail technology. Build maglev track and put a magnetic levitation train into service."
            },

            {
                id = "tier6_master",
                name = "Transport Master",
                tier = 6,
                prerequisites = ["tier6_levitation"],
                objectives = [
                    {
                        type = ObjType.CONNECT_TOWNS_ROAD,
                        params = { min_towns = 30 },
                        desc = "Connect 30 towns by road"
                    },
                    {
                        type = ObjType.COMPANY_VALUE,
                        params = { amount = (10000000 * m).tointeger() },
                        desc = "Reach company value of " + (10000000 * m).tointeger()
                    },
                    {
                        type = ObjType.TOTAL_POP_SERVED,
                        params = { amount = (50000 * m).tointeger() },
                        desc = "Serve a total population of " + (50000 * m).tointeger() + " across all towns"
                    }
                ],
                rewards = [
                    { type = RewardType.VICTORY }
                ],
                story = "The ultimate achievement. Connect 30 towns, reach " + (10000000 * m).tointeger() + " company value, and serve " + (50000 * m).tointeger() + " citizens to become the Transport Master!"
            }
        ];
    }
}
