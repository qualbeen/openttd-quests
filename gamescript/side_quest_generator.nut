class SideQuestGenerator {
}

function SideQuestGenerator::_Fmt(s, val) {
    local pos = s.find("%s");
    if (pos == null) pos = s.find("%d");
    if (pos == null) return s;
    return s.slice(0, pos) + val + s.slice(pos + 2);
}

function SideQuestGenerator::Generate(quest_manager) {
    local count = GSController.GetSetting("side_quest_count");
    if (count == 0) {
        local map_size = GSMap.GetMapSizeX() * GSMap.GetMapSizeY();
        if (map_size <= 256 * 256) count = 8;
        else if (map_size <= 512 * 512) count = 12;
        else count = 15;
    }

    local templates = SideQuestGenerator._GetTemplates();
    local generated = 0;
    local attempt = 0;
    local used_names = {};

    while (generated < count && attempt < count * 3) {
        attempt++;
        local tmpl = templates[generated % templates.len()];
        local quest = SideQuestGenerator._GenerateFromTemplate(tmpl, generated);

        if (quest != null && !(quest.name in used_names)) {
            used_names[quest.name] <- true;
            quest_manager.AddSideQuest(quest);
            generated++;
            GSLog.Info("Generated side quest: " + quest.name);
        }
    }

    GSLog.Info("Generated " + generated + " side quests");
}

function SideQuestGenerator::_GetTemplates() {
    local diff = GSController.GetSetting("difficulty");
    local multiplier = 1.0;
    if (diff == 0) multiplier = 0.5;
    if (diff == 2) multiplier = 2.0;

    return [
        {
            template = "town_express",
            tier = 0,
            name_fmt = "Express to %s",
            desc_fmt = "Run a bus between %s and %s",
            needs = "two_towns",
            reward_min = 10000, reward_max = 20000,
            check_type = ObjType.CONNECT_TOWNS_ROAD,
            obj_params = { min_towns = 2 },
            mult = multiplier
        },
        {
            template = "cargo_hauler",
            tier = 0,
            name_fmt = "Hauler for %s",
            desc_fmt = "Truck cargo from %s to %s",
            needs = "industry_and_town",
            reward_min = 15000, reward_max = 25000,
            check_type = ObjType.TRANSPORT_CARGO,
            obj_params = { amount = (100 * multiplier).tointeger() },
            mult = multiplier
        },
        {
            template = "passenger_line",
            tier = 1,
            name_fmt = "Rail to %s",
            desc_fmt = "Transport passengers by train between %s and %s",
            needs = "two_towns",
            reward_min = 30000, reward_max = 45000,
            check_type = ObjType.TRANSPORT_PASSENGERS_RAIL,
            obj_params = { amount = (300 * multiplier).tointeger() },
            mult = multiplier
        },
        {
            template = "city_builder",
            tier = 1,
            name_fmt = "Grow %s",
            desc_fmt = "Grow %s to %d population",
            needs = "one_town",
            reward_min = 35000, reward_max = 50000,
            check_type = ObjType.GROW_TOWN,
            obj_params = {},
            mult = multiplier
        },
        {
            template = "island_supply",
            tier = 2,
            name_fmt = "Supply %s by sea",
            desc_fmt = "Ship goods to %s",
            needs = "one_town",
            reward_min = 40000, reward_max = 60000,
            check_type = ObjType.BUILD_DOCK_AND_SHIP,
            obj_params = {},
            mult = multiplier
        },
        {
            template = "jet_setter",
            tier = 4,
            name_fmt = "Flights to %s",
            desc_fmt = "Fly passengers between %s and %s",
            needs = "two_towns_far",
            reward_min = 80000, reward_max = 120000,
            check_type = ObjType.AIR_BRIDGE,
            obj_params = { min_distance = 100 },
            mult = multiplier
        }
    ];
}

function SideQuestGenerator::_GenerateFromTemplate(tmpl, index) {
    local quest = null;

    switch (tmpl.needs) {
        case "two_towns":
            quest = SideQuestGenerator._PickTwoTowns(tmpl, index);
            break;
        case "two_towns_far":
            quest = SideQuestGenerator._PickTwoTownsFar(tmpl, index, 100);
            break;
        case "industry_and_town":
            quest = SideQuestGenerator._PickIndustryAndTown(tmpl, index);
            break;
        case "one_town":
            quest = SideQuestGenerator._PickOneTown(tmpl, index);
            break;
    }

    return quest;
}

function SideQuestGenerator::_PickTwoTowns(tmpl, index) {
    local town_count = GSTown.GetTownCount();
    if (town_count < 2) return null;

    local t1 = GSBase.RandRange(town_count);
    local t2 = GSBase.RandRange(town_count);
    while (t2 == t1 && town_count > 1) t2 = GSBase.RandRange(town_count);
    if (!GSTown.IsValidTown(t1) || !GSTown.IsValidTown(t2)) return null;

    local name1 = GSTown.GetName(t1);
    local name2 = GSTown.GetName(t2);
    local reward = tmpl.reward_min + GSBase.RandRange(tmpl.reward_max - tmpl.reward_min);

    local qname = SideQuestGenerator._Fmt(tmpl.name_fmt, name2);
    local desc = SideQuestGenerator._Fmt(SideQuestGenerator._Fmt(tmpl.desc_fmt, name1), name2);

    return {
        id = "side_" + index,
        name = qname,
        tier = tmpl.tier,
        prerequisites = [],
        objectives = [
            { type = tmpl.check_type, params = tmpl.obj_params, desc = desc }
        ],
        rewards = [{ type = RewardType.CASH, amount = reward }],
        story = desc + ". The people are counting on you!",
        towns = [t1, t2]
    };
}

function SideQuestGenerator::_PickTwoTownsFar(tmpl, index, min_dist) {
    local town_count = GSTown.GetTownCount();
    if (town_count < 2) return null;

    for (local attempt = 0; attempt < 20; attempt++) {
        local t1 = GSBase.RandRange(town_count);
        local t2 = GSBase.RandRange(town_count);
        if (t1 == t2) continue;
        if (!GSTown.IsValidTown(t1) || !GSTown.IsValidTown(t2)) continue;

        local dist = GSMap.DistanceManhattan(GSTown.GetLocation(t1), GSTown.GetLocation(t2));
        if (dist >= min_dist) {
            local name1 = GSTown.GetName(t1);
            local name2 = GSTown.GetName(t2);
            local reward = tmpl.reward_min + GSBase.RandRange(tmpl.reward_max - tmpl.reward_min);

            local qname = SideQuestGenerator._Fmt(tmpl.name_fmt, name2);
            local desc = SideQuestGenerator._Fmt(SideQuestGenerator._Fmt(tmpl.desc_fmt, name1), name2);

            return {
                id = "side_" + index,
                name = qname,
                tier = tmpl.tier,
                prerequisites = [],
                objectives = [
                    { type = tmpl.check_type, params = tmpl.obj_params, desc = desc }
                ],
                rewards = [{ type = RewardType.CASH, amount = reward }],
                story = desc + ". Show them what air travel can do!",
                towns = [t1, t2]
            };
        }
    }
    return null;
}

function SideQuestGenerator::_PickIndustryAndTown(tmpl, index) {
    local industries = GSIndustryList();
    if (industries.Count() == 0) return null;

    local ind = industries.Begin();
    local ind_name = GSIndustry.GetName(ind);
    local ind_loc = GSIndustry.GetLocation(ind);

    local nearest_town = -1;
    local nearest_dist = 999999;
    local towns = GSTownList();
    for (local town = towns.Begin(); !towns.IsEnd(); town = towns.Next()) {
        local dist = GSMap.DistanceManhattan(ind_loc, GSTown.GetLocation(town));
        if (dist < nearest_dist) {
            nearest_dist = dist;
            nearest_town = town;
        }
    }

    if (nearest_town < 0) return null;
    local town_name = GSTown.GetName(nearest_town);
    local reward = tmpl.reward_min + GSBase.RandRange(tmpl.reward_max - tmpl.reward_min);

    local qname = SideQuestGenerator._Fmt(tmpl.name_fmt, ind_name);
    local desc = SideQuestGenerator._Fmt(SideQuestGenerator._Fmt(tmpl.desc_fmt, ind_name), town_name);

    return {
        id = "side_" + index,
        name = qname,
        tier = tmpl.tier,
        prerequisites = [],
        objectives = [
            { type = tmpl.check_type, params = tmpl.obj_params, desc = desc }
        ],
        rewards = [{ type = RewardType.CASH, amount = reward }],
        story = "The folks in " + town_name + " need supplies from " + ind_name + ". Can you deliver?",
        towns = [nearest_town]
    };
}

function SideQuestGenerator::_PickOneTown(tmpl, index) {
    local town_count = GSTown.GetTownCount();
    if (town_count == 0) return null;

    local town = GSBase.RandRange(town_count);
    if (!GSTown.IsValidTown(town)) return null;

    local name = GSTown.GetName(town);
    local pop = GSTown.GetPopulation(town);
    local reward = tmpl.reward_min + GSBase.RandRange(tmpl.reward_max - tmpl.reward_min);

    local params = clone tmpl.obj_params;
    if (tmpl.template == "city_builder") {
        local target = (pop * 2 < 500) ? 500 : pop * 2;
        params.target <- (target * tmpl.mult).tointeger();
    }

    local desc = "";
    if (tmpl.template == "city_builder") {
        desc = SideQuestGenerator._Fmt(SideQuestGenerator._Fmt(tmpl.desc_fmt, name), params.target);
    } else {
        desc = SideQuestGenerator._Fmt(tmpl.desc_fmt, name);
    }

    local qname = SideQuestGenerator._Fmt(tmpl.name_fmt, name);

    return {
        id = "side_" + index,
        name = qname,
        tier = tmpl.tier,
        prerequisites = [],
        objectives = [
            { type = tmpl.check_type, params = params, desc = desc }
        ],
        rewards = [{ type = RewardType.CASH, amount = reward }],
        story = desc + ". A worthy challenge!",
        towns = [town]
    };
}
