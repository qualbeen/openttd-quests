class QuestManager {
    companies = null;
    quest_defs = null;
    side_quests = null;
    pax_cargo = null;
}

function QuestManager::constructor() {
    this.companies = {};
    this.side_quests = [];

    this.pax_cargo = 0;
    for (local cargo = 0; cargo < 64; cargo++) {
        if (GSCargo.IsValidCargo(cargo) && GSCargo.HasCargoClass(cargo, GSCargo.CC_PASSENGERS)) {
            this.pax_cargo = cargo;
            break;
        }
    }
    GSLog.Info("Passenger cargo ID: " + this.pax_cargo);

    local diff = GSController.GetSetting("difficulty");
    local mult = 1.0;
    if (diff == 0) mult = 0.5;
    if (diff == 2) mult = 2.0;
    this.quest_defs = QuestDefs.GetAll(mult);
}

function QuestManager::InitProgression(start_tier) {
    for (local company = GSCompany.COMPANY_FIRST; company <= GSCompany.COMPANY_LAST; company++) {
        if (GSCompany.ResolveCompanyID(company) == GSCompany.COMPANY_INVALID) continue;
        this.AddCompany(company, start_tier);
    }
}

function QuestManager::AddCompany(company, start_tier = 0) {
    if (company in this.companies) {
        GSLog.Info("Company " + company + " already initialized, skipping.");
        return;
    }

    local unlocked = [];
    for (local tier = 0; tier <= start_tier; tier++) {
        unlocked.append(tier);
    }

    this.companies[company] <- {
        unlocked_tiers = unlocked,
        quest_states = {},
        quest_progress = {}
    };

    foreach (quest in this.quest_defs) {
        if (quest.tier <= start_tier) {
            local all_prereqs_met = true;
            foreach (prereq in quest.prerequisites) {
                if (!(prereq in this.companies[company].quest_states) ||
                    this.companies[company].quest_states[prereq] != "completed") {
                    all_prereqs_met = false;
                    break;
                }
            }

            if (quest.tier < start_tier) {
                this.companies[company].quest_states[quest.id] <- "completed";
            } else if (all_prereqs_met) {
                this.companies[company].quest_states[quest.id] <- "available";
            }
        }
    }

    this._ActivateAvailableQuests(company);
    GSLog.Info("Company " + company + " initialized at tier " + start_tier);
}

function QuestManager::HasCompany(company) {
    return company in this.companies;
}

function QuestManager::GetUnlockedTiers(company) {
    if (!(company in this.companies)) return [0];
    return this.companies[company].unlocked_tiers;
}

function QuestManager::GetQuestState(company, quest_id) {
    if (!(company in this.companies)) return "locked";
    if (!(quest_id in this.companies[company].quest_states)) return "locked";
    return this.companies[company].quest_states[quest_id];
}

function QuestManager::GetQuestProgress(company, quest_id) {
    if (!(company in this.companies)) return {};
    if (!(quest_id in this.companies[company].quest_progress)) return {};
    return this.companies[company].quest_progress[quest_id];
}

function QuestManager::GetActiveQuests(company) {
    local active = [];
    if (!(company in this.companies)) return active;

    foreach (quest in this.quest_defs) {
        if (quest.id in this.companies[company].quest_states &&
            this.companies[company].quest_states[quest.id] == "active") {
            active.append(quest);
        }
    }

    foreach (sq in this.side_quests) {
        if (sq.id in this.companies[company].quest_states &&
            this.companies[company].quest_states[sq.id] == "active") {
            active.append(sq);
        }
    }

    return active;
}

function QuestManager::GetAvailableQuests(company) {
    local available = [];
    if (!(company in this.companies)) return available;

    foreach (quest in this.quest_defs) {
        if (quest.id in this.companies[company].quest_states &&
            this.companies[company].quest_states[quest.id] == "available") {
            available.append(quest);
        }
    }

    return available;
}

function QuestManager::_ActivateAvailableQuests(company) {
    foreach (quest in this.quest_defs) {
        local state = this.GetQuestState(company, quest.id);
        if (state != "locked" && state != "available") continue;

        local prereqs_met = true;
        foreach (prereq in quest.prerequisites) {
            if (this.GetQuestState(company, prereq) != "completed") {
                prereqs_met = false;
                break;
            }
        }

        local tier_unlocked = false;
        foreach (ut in this.companies[company].unlocked_tiers) {
            if (ut == quest.tier) { tier_unlocked = true; break; }
        }

        if (prereqs_met && tier_unlocked && state == "locked") {
            this.companies[company].quest_states[quest.id] <- "available";
        }
        if (prereqs_met && tier_unlocked && (state == "available" || state == "locked")) {
            this.companies[company].quest_states[quest.id] <- "active";
            this.companies[company].quest_progress[quest.id] <- {};
        }
    }

    foreach (sq in this.side_quests) {
        local state = this.GetQuestState(company, sq.id);
        if (state != "locked") continue;

        local tier_unlocked = false;
        foreach (ut in this.companies[company].unlocked_tiers) {
            if (ut == sq.tier) { tier_unlocked = true; break; }
        }

        if (tier_unlocked) {
            this.companies[company].quest_states[sq.id] <- "active";
            this.companies[company].quest_progress[sq.id] <- {};
        }
    }
}

function QuestManager::CompleteQuest(company, quest_id) {
    if (!(company in this.companies)) return;
    this.companies[company].quest_states[quest_id] = "completed";
    GSLog.Info("Quest '" + quest_id + "' completed for company " + company);
    this._ActivateAvailableQuests(company);
}

function QuestManager::UnlockTier(company, tier) {
    if (!(company in this.companies)) return;
    local already = false;
    foreach (ut in this.companies[company].unlocked_tiers) {
        if (ut == tier) { already = true; break; }
    }
    if (!already) {
        this.companies[company].unlocked_tiers.append(tier);
        GSLog.Info("Tier " + tier + " unlocked for company " + company);
        this._ActivateAvailableQuests(company);
    }
}

function QuestManager::GetQuestDef(quest_id) {
    foreach (quest in this.quest_defs) {
        if (quest.id == quest_id) return quest;
    }
    foreach (sq in this.side_quests) {
        if (sq.id == quest_id) return sq;
    }
    return null;
}

function QuestManager::AddSideQuest(quest) {
    this.side_quests.append(quest);
}

function QuestManager::CheckConditions(company, classifier) {
    local mode = GSCompanyMode(company);
    local completed = [];
    local active = this.GetActiveQuests(company);

    foreach (quest in active) {
        local all_done = true;

        foreach (idx, obj in quest.objectives) {
            local progress_key = "obj_" + idx;
            local done = this._CheckObjective(company, obj, quest, progress_key);
            if (!done) all_done = false;
        }

        if (all_done) {
            completed.append(quest.id);
        }
    }

    return completed;
}

function QuestManager::GetObjectiveProgress(company, obj, quest) {
    local mode = GSCompanyMode(company);
    switch (obj.type) {
        case ObjType.BUY_VEHICLE: {
            local vehicles = GSVehicleList();
            return { current = vehicles.Count() > 0 ? 1 : 0, target = 1 };
        }
        case ObjType.ROUTE_PROFIT: {
            local best = 0;
            local vehicles = GSVehicleList();
            for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
                if (GSVehicle.GetVehicleType(vehicle) == obj.params.vehicle_type) {
                    best = max(best, GSVehicle.GetProfitThisYear(vehicle));
                }
            }
            return { current = best, target = obj.params.amount };
        }
        case ObjType.CONNECT_TOWNS_ROAD:
        case ObjType.CONNECT_TOWNS_RAIL: {
            local vtype = obj.type == ObjType.CONNECT_TOWNS_ROAD ? GSVehicle.VT_ROAD : GSVehicle.VT_RAIL;
            local connected = {};
            local stations = GSStationList(
                vtype == GSVehicle.VT_ROAD ? GSStation.STATION_BUS_STOP : GSStation.STATION_TRAIN
            );
            for (local station = stations.Begin(); !stations.IsEnd(); station = stations.Next()) {
                if (GSStation.HasCargoRating(station, this.pax_cargo)) {
                    connected[GSStation.GetNearestTown(station)] <- true;
                }
            }
            local count = 0;
            foreach (town, _ in connected) count++;
            local min_towns = "min_towns" in obj.params ? obj.params.min_towns : 1;
            return { current = count, target = min_towns };
        }
        case ObjType.CONNECT_TOWN_INTERNAL: {
            local best_stops = 0;
            local town_stops = {};
            local stations = GSStationList(GSStation.STATION_BUS_STOP);
            for (local station = stations.Begin(); !stations.IsEnd(); station = stations.Next()) {
                if (!GSStation.HasCargoRating(station, this.pax_cargo)) continue;
                local town = GSStation.GetNearestTown(station);
                if (!(town in town_stops)) town_stops[town] <- 0;
                town_stops[town]++;
            }
            foreach (town, count in town_stops) {
                best_stops = max(best_stops, count);
            }
            return { current = best_stops, target = obj.params.min_stops };
        }
        case ObjType.GROW_TOWN: {
            local best_pop = 0;
            if (quest != null && "towns" in quest) {
                foreach (town_id in quest.towns) {
                    if (GSTown.IsValidTown(town_id)) {
                        best_pop = max(best_pop, GSTown.GetPopulation(town_id));
                    }
                }
            } else {
                local towns = GSTownList();
                for (local town_id = towns.Begin(); !towns.IsEnd(); town_id = towns.Next()) {
                    best_pop = max(best_pop, GSTown.GetPopulation(town_id));
                }
            }
            return { current = best_pop, target = obj.params.target };
        }
        case ObjType.COMPANY_VALUE: {
            local val = GSCompany.GetQuarterlyCompanyValue(company, GSCompany.CURRENT_QUARTER);
            return { current = val, target = obj.params.amount };
        }
    }
    return { current = 0, target = 1 };
}

function QuestManager::_CheckObjective(company, obj, quest, progress_key) {
    switch (obj.type) {
        case ObjType.BUY_VEHICLE:
            return this._CheckBuyVehicle(company);
        case ObjType.ROUTE_PROFIT:
            return this._CheckRouteProfit(company, obj.params);
        case ObjType.CONNECT_TOWNS_ROAD:
            return this._CheckConnectedTowns(company, obj.params, GSVehicle.VT_ROAD, quest);
        case ObjType.TRANSPORT_CARGO:
            return this._CheckTransportCargo(company, obj.params, quest, progress_key);
        case ObjType.CONNECT_TOWN_INTERNAL:
            return this._CheckConnectTownInternal(company, obj.params);
        case ObjType.CONNECT_TOWNS_RAIL:
            return this._CheckConnectedTowns(company, obj.params, GSVehicle.VT_RAIL, quest);
        case ObjType.TRANSPORT_PASSENGERS_RAIL:
            return this._CheckTransportPassengersRail(company, obj.params, quest, progress_key);
        case ObjType.GROW_TOWN:
            return this._CheckGrowTown(company, obj.params, quest);
        case ObjType.RAIL_NETWORK:
            return this._CheckRailNetwork(company, obj.params);
        case ObjType.BUILD_DOCK_AND_SHIP:
            return this._CheckDockAndShip(company);
        case ObjType.TRANSPORT_OIL:
            return this._CheckTransportCargo(company, { amount = obj.params.amount, cargo_name = "oil" }, quest, progress_key);
        case ObjType.COMPANY_VALUE:
            return this._CheckCompanyValue(company, obj.params);
        case ObjType.BUILD_ELECTRIFIED_RAIL:
            return this._CheckElectrifiedRail(company, obj.params);
        case ObjType.ELECTRIC_TRAIN_SPEED:
            return this._CheckElectricTrainSpeed(company, obj.params);
        case ObjType.TRANSPORT_CARGO_TYPES:
            return this._CheckCargoTypes(company, obj.params);
        case ObjType.BUILD_AIRPORT_AND_FLY:
            return this._CheckAirportAndFly(company);
        case ObjType.AIR_BRIDGE:
            return this._CheckAirBridge(company, obj.params);
        case ObjType.ALL_TRANSPORT_TYPES:
            return this._CheckAllTransportTypes(company);
        case ObjType.BUILD_MONORAIL:
            return this._CheckBuildMonorail(company, obj.params);
        case ObjType.MONORAIL_SPEED:
            return this._CheckMonorailSpeed(company, obj.params);
        case ObjType.NETWORK_SIZE:
            return this._CheckNetworkSize(company, obj.params);
        case ObjType.BUILD_MAGLEV:
            return this._CheckBuildMaglev(company);
        case ObjType.TOTAL_POP_SERVED:
            return this._CheckTotalPopServed(company, obj.params);
    }
    return false;
}

function QuestManager::_CheckBuyVehicle(company) {
    local vehicles = GSVehicleList();
    return vehicles.Count() > 0;
}

function QuestManager::_CheckRouteProfit(company, params) {
    local total = 0;
    local vehicles = GSVehicleList();
    for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
        if (GSVehicle.GetVehicleType(vehicle) == params.vehicle_type) {
            total += GSVehicle.GetProfitThisYear(vehicle);
        }
    }
    return total >= params.amount;
}

function QuestManager::_CheckConnectedTowns(company, params, vtype, quest = null) {
    local connected = {};
    local stations = GSStationList(
        vtype == GSVehicle.VT_ROAD ? GSStation.STATION_BUS_STOP :
        vtype == GSVehicle.VT_RAIL ? GSStation.STATION_TRAIN :
        vtype == GSVehicle.VT_WATER ? GSStation.STATION_DOCK :
        GSStation.STATION_AIRPORT
    );

    for (local station = stations.Begin(); !stations.IsEnd(); station = stations.Next()) {
        if (GSStation.HasCargoRating(station, this.pax_cargo)) {
            local town = GSStation.GetNearestTown(station);
            connected[town] <- true;
        }
    }

    if (quest != null && "towns" in quest) {
        foreach (qt in quest.towns) {
            if (!(qt in connected)) return false;
        }
        return true;
    }

    local count = 0;
    foreach (town, _ in connected) count++;

    local min_towns = "min_towns" in params ? params.min_towns : 1;
    return count >= min_towns;
}

function QuestManager::_CheckTransportCargo(company, params, quest, progress_key) {
    if ("towns" in quest) {
        local has_station = false;
        local stations = GSStationList(GSStation.STATION_TRUCK_STOP);
        for (local station = stations.Begin(); !stations.IsEnd(); station = stations.Next()) {
            local town = GSStation.GetNearestTown(station);
            foreach (qt in quest.towns) {
                if (town == qt) { has_station = true; break; }
            }
            if (has_station) break;
        }
        if (!has_station) return false;
    }

    local vehicles = GSVehicleList();
    local total_profit = 0;
    for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
        local engine = GSVehicle.GetEngineType(vehicle);
        local cargo = GSEngine.GetCargoType(engine);
        if (GSCargo.HasCargoClass(cargo, GSCargo.CC_PASSENGERS)) continue;
        total_profit += GSVehicle.GetProfitThisYear(vehicle);
    }

    local amount = "amount" in params ? params.amount : 200;
    return total_profit >= amount * 50;
}

function QuestManager::_CheckTransportPassengersRail(company, params, quest, progress_key) {
    local vehicles = GSVehicleList();
    local total_profit = 0;
    for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
        if (GSVehicle.GetVehicleType(vehicle) == GSVehicle.VT_RAIL) {
            total_profit += GSVehicle.GetProfitThisYear(vehicle);
        }
    }

    local amount = "amount" in params ? params.amount : 500;
    return total_profit >= amount * 50;
}

function QuestManager::_CheckConnectTownInternal(company, params) {
    local min_stops = params.min_stops;
    local town_stops = {};

    local stations = GSStationList(GSStation.STATION_BUS_STOP);
    for (local station = stations.Begin(); !stations.IsEnd(); station = stations.Next()) {
        if (!GSStation.HasCargoRating(station, this.pax_cargo)) continue;
        local town = GSStation.GetNearestTown(station);
        if (!(town in town_stops)) town_stops[town] <- 0;
        town_stops[town]++;
    }

    local has_stops = false;
    foreach (town, count in town_stops) {
        if (count >= min_stops) { has_stops = true; break; }
    }
    if (!has_stops) return false;

    local min_pass = "min_passengers" in params ? params.min_passengers : 0;
    if (min_pass > 0) {
        local bus_profit = 0;
        local vehicles = GSVehicleList();
        for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
            if (GSVehicle.GetVehicleType(vehicle) != GSVehicle.VT_ROAD) continue;
            local engine = GSVehicle.GetEngineType(vehicle);
            if (!GSCargo.HasCargoClass(GSEngine.GetCargoType(engine), GSCargo.CC_PASSENGERS)) continue;
            bus_profit += GSVehicle.GetProfitThisYear(vehicle);
        }
        if (bus_profit < min_pass * 25) return false;
    }

    return true;
}

function QuestManager::_CheckGrowTown(company, params, quest = null) {
    local target = params.target;

    if (quest != null && "towns" in quest) {
        foreach (town_id in quest.towns) {
            if (GSTown.IsValidTown(town_id) && GSTown.GetPopulation(town_id) >= target) return true;
        }
        return false;
    }

    local towns = GSTownList();
    for (local town_id = towns.Begin(); !towns.IsEnd(); town_id = towns.Next()) {
        if (GSTown.GetPopulation(town_id) >= target) return true;
    }
    return false;
}

function QuestManager::_CheckRailNetwork(company, params) {
    local towns_ok = this._CheckConnectedTowns(company, params, GSVehicle.VT_RAIL);
    local profit_ok = false;

    local income = GSCompany.GetQuarterlyIncome(company, GSCompany.CURRENT_QUARTER);
    local expenses = GSCompany.GetQuarterlyExpenses(company, GSCompany.CURRENT_QUARTER);
    profit_ok = (income - expenses) >= params.min_profit;

    return towns_ok && profit_ok;
}

function QuestManager::_CheckDockAndShip(company) {
    local stations = GSStationList(GSStation.STATION_DOCK);
    if (stations.Count() == 0) return false;

    local vehicles = GSVehicleList();
    for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
        if (GSVehicle.GetVehicleType(vehicle) == GSVehicle.VT_WATER) return true;
    }
    return false;
}

function QuestManager::_CheckCompanyValue(company, params) {
    local value = GSCompany.GetQuarterlyCompanyValue(company, GSCompany.CURRENT_QUARTER);
    return value >= params.amount;
}

function QuestManager::_CheckElectrifiedRail(company, params) {
    local vehicles = GSVehicleList();
    for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
        if (GSVehicle.GetVehicleType(vehicle) != GSVehicle.VT_RAIL) continue;
        local engine = GSVehicle.GetEngineType(vehicle);
        local rail_type = GSEngine.GetRailType(engine);
        local rt_name = GSRail.GetName(rail_type);
        if (rt_name != null && (rt_name.tolower().find("elec") != null || rt_name.tolower().find("elrl") != null)) {
            return true;
        }
    }
    return false;
}

function QuestManager::_CheckElectricTrainSpeed(company, params) {
    local vehicles = GSVehicleList();
    for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
        if (GSVehicle.GetVehicleType(vehicle) != GSVehicle.VT_RAIL) continue;
        local engine = GSVehicle.GetEngineType(vehicle);
        local rail_type = GSEngine.GetRailType(engine);
        local rt_name = GSRail.GetName(rail_type);
        if (rt_name != null && (rt_name.tolower().find("elec") != null || rt_name.tolower().find("elrl") != null)) {
            if (GSVehicle.GetCurrentSpeed(vehicle) >= params.min_speed) return true;
        }
    }
    return false;
}

function QuestManager::_CheckCargoTypes(company, params) {
    local cargo_types = {};
    local vehicles = GSVehicleList();
    for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
        if (GSVehicle.GetProfitThisYear(vehicle) > 0) {
            local cargo = GSEngine.GetCargoType(GSVehicle.GetEngineType(vehicle));
            cargo_types[cargo] <- true;
        }
    }

    local count = 0;
    foreach (cargo, _ in cargo_types) count++;
    return count >= params.count;
}

function QuestManager::_CheckAirportAndFly(company) {
    local stations = GSStationList(GSStation.STATION_AIRPORT);
    if (stations.Count() == 0) return false;

    local vehicles = GSVehicleList();
    for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
        if (GSVehicle.GetVehicleType(vehicle) == GSVehicle.VT_AIR) return true;
    }
    return false;
}

function QuestManager::_CheckAirBridge(company, params) {
    local airports = [];
    local stations = GSStationList(GSStation.STATION_AIRPORT);
    for (local station = stations.Begin(); !stations.IsEnd(); station = stations.Next()) {
        airports.append(GSStation.GetLocation(station));
    }

    for (local i = 0; i < airports.len(); i++) {
        for (local j = i + 1; j < airports.len(); j++) {
            local dist = GSMap.DistanceManhattan(airports[i], airports[j]);
            if (dist >= params.min_distance) return true;
        }
    }
    return false;
}

function QuestManager::_CheckAllTransportTypes(company) {
    local types = {};
    local vehicles = GSVehicleList();
    for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
        if (GSVehicle.GetProfitThisYear(vehicle) > 0) {
            types[GSVehicle.GetVehicleType(vehicle)] <- true;
        }
    }
    return (GSVehicle.VT_ROAD in types) && (GSVehicle.VT_RAIL in types) &&
           (GSVehicle.VT_WATER in types) && (GSVehicle.VT_AIR in types);
}

function QuestManager::_CheckBuildMonorail(company, params) {
    local vehicles = GSVehicleList();
    for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
        if (GSVehicle.GetVehicleType(vehicle) != GSVehicle.VT_RAIL) continue;
        local engine = GSVehicle.GetEngineType(vehicle);
        local rail_type = GSEngine.GetRailType(engine);
        local rt_name = GSRail.GetName(rail_type);
        if (rt_name != null && rt_name.tolower().find("mono") != null) {
            return true;
        }
    }
    return false;
}

function QuestManager::_CheckMonorailSpeed(company, params) {
    local vehicles = GSVehicleList();
    for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
        if (GSVehicle.GetVehicleType(vehicle) != GSVehicle.VT_RAIL) continue;
        local engine = GSVehicle.GetEngineType(vehicle);
        local rail_type = GSEngine.GetRailType(engine);
        local rt_name = GSRail.GetName(rail_type);
        if (rt_name != null && rt_name.tolower().find("mono") != null) {
            if (GSVehicle.GetCurrentSpeed(vehicle) >= params.min_speed) return true;
        }
    }
    return false;
}

function QuestManager::_CheckNetworkSize(company, params) {
    local towns_ok = this._CheckConnectedTowns(company, params, GSVehicle.VT_RAIL);
    return towns_ok;
}

function QuestManager::_CheckBuildMaglev(company) {
    local vehicles = GSVehicleList();
    for (local vehicle = vehicles.Begin(); !vehicles.IsEnd(); vehicle = vehicles.Next()) {
        if (GSVehicle.GetVehicleType(vehicle) != GSVehicle.VT_RAIL) continue;
        local engine = GSVehicle.GetEngineType(vehicle);
        local rail_type = GSEngine.GetRailType(engine);
        local rt_name = GSRail.GetName(rail_type);
        if (rt_name != null && rt_name.tolower().find("maglev") != null) return true;
    }
    return false;
}

function QuestManager::_CheckTotalPopServed(company, params) {
    local total = 0;
    local connected_towns = {};

    local stypes = [GSStation.STATION_BUS_STOP, GSStation.STATION_TRAIN, GSStation.STATION_DOCK, GSStation.STATION_AIRPORT];
    foreach (st in stypes) {
        local stations = GSStationList(st);
        for (local station = stations.Begin(); !stations.IsEnd(); station = stations.Next()) {
            if (GSStation.HasCargoRating(station, this.pax_cargo)) {
                local town = GSStation.GetNearestTown(station);
                connected_towns[town] <- true;
            }
        }
    }

    foreach (town, _ in connected_towns) {
        total += GSTown.GetPopulation(town);
    }

    return total >= params.amount;
}
