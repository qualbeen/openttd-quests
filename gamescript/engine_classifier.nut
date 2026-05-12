class EngineClassifier {
    engine_tiers = null;
    tier_engines = null;

    constructor() {
        this.engine_tiers = {};
        this.tier_engines = {};
        for (local t = 0; t <= 6; t++) {
            this.tier_engines[t] <- [];
        }
    }
}

function EngineClassifier::ClassifyAll() {
    this.engine_tiers = {};
    for (local t = 0; t <= 6; t++) {
        this.tier_engines[t] = [];
    }

    this._ClassifyByType(GSVehicle.VT_ROAD);
    this._ClassifyByType(GSVehicle.VT_RAIL);
    this._ClassifyByType(GSVehicle.VT_WATER);
    this._ClassifyByType(GSVehicle.VT_AIR);

    foreach (tier, engines in this.tier_engines) {
        GSLog.Info("Tier " + tier + ": " + engines.len() + " engines");
    }
}

function EngineClassifier::_ClassifyByType(vtype) {
    local list = GSEngineList(vtype);

    if (vtype == GSVehicle.VT_AIR) {
        for (local e = list.Begin(); !list.IsEnd(); e = list.Next()) {
            this._Assign(e, 4);
        }
        return;
    }

    if (vtype == GSVehicle.VT_WATER) {
        for (local e = list.Begin(); !list.IsEnd(); e = list.Next()) {
            this._Assign(e, 2);
        }
        return;
    }

    if (vtype == GSVehicle.VT_ROAD) {
        this._ClassifyRoadVehicles(list);
        return;
    }

    if (vtype == GSVehicle.VT_RAIL) {
        this._ClassifyTrains(list);
        return;
    }
}

function EngineClassifier::_ClassifyRoadVehicles(list) {
    local prices = [];
    local speeds = [];
    local engines = [];

    for (local e = list.Begin(); !list.IsEnd(); e = list.Next()) {
        local price = GSEngine.GetPrice(e);
        local speed = GSEngine.GetMaxSpeed(e);
        prices.append(price);
        speeds.append(speed);
        engines.append(e);
    }

    if (engines.len() == 0) return;

    prices.sort(@(a, b) a <=> b);
    speeds.sort(@(a, b) a <=> b);
    local median_price = prices[prices.len() / 2];
    local median_speed = speeds[speeds.len() / 2];

    foreach (e in engines) {
        local price = GSEngine.GetPrice(e);
        local speed = GSEngine.GetMaxSpeed(e);

        if (price <= median_price) {
            this._Assign(e, 0);
        } else if (speed <= median_speed) {
            this._Assign(e, 1);
        } else {
            this._Assign(e, 4);
        }
    }
}

function EngineClassifier::_ClassifyTrains(list) {
    local normal_engines = [];
    local normal_speeds = [];

    for (local e = list.Begin(); !list.IsEnd(); e = list.Next()) {
        local rail_type = GSEngine.GetRailType(e);
        local rt_name = GSRail.GetName(rail_type);

        if (rt_name == null) {
            this._Assign(e, 1);
            continue;
        }

        local rt_lower = rt_name.tolower();

        if (rt_lower.find("maglev") != null) {
            this._Assign(e, 6);
        } else if (rt_lower.find("mono") != null) {
            this._Assign(e, 5);
        } else if (rt_lower.find("elec") != null || rt_lower.find("elrl") != null) {
            this._Assign(e, 3);
        } else {
            normal_engines.append(e);
            normal_speeds.append(GSEngine.GetMaxSpeed(e));
        }
    }

    if (normal_engines.len() == 0) return;

    local sorted_speeds = clone normal_speeds;
    sorted_speeds.sort(@(a, b) a <=> b);
    local median_speed = sorted_speeds[sorted_speeds.len() / 2];

    foreach (idx, e in normal_engines) {
        if (normal_speeds[idx] <= median_speed) {
            this._Assign(e, 1);
        } else {
            this._Assign(e, 2);
        }
    }
}

function EngineClassifier::_Assign(engine_id, tier) {
    this.engine_tiers[engine_id] <- tier;
    this.tier_engines[tier].append(engine_id);
}

function EngineClassifier::GetTierEngines(tier) {
    return tier in this.tier_engines ? this.tier_engines[tier] : [];
}

function EngineClassifier::GetEngineTier(engine_id) {
    return engine_id in this.engine_tiers ? this.engine_tiers[engine_id] : -1;
}

function EngineClassifier::LockAllAboveTier(max_tier) {
    for (local c = GSCompany.COMPANY_FIRST; c <= GSCompany.COMPANY_LAST; c++) {
        if (GSCompany.ResolveCompanyID(c) == GSCompany.COMPANY_INVALID) continue;
        foreach (engine_id, tier in this.engine_tiers) {
            if (tier > max_tier) {
                GSEngine.DisableForCompany(engine_id, c);
            }
        }
    }
    GSLog.Info("Locked all engines above tier " + max_tier);
}

function EngineClassifier::UnlockTier(tier) {
    local engines = this.GetTierEngines(tier);
    for (local c = GSCompany.COMPANY_FIRST; c <= GSCompany.COMPANY_LAST; c++) {
        if (GSCompany.ResolveCompanyID(c) == GSCompany.COMPANY_INVALID) continue;
        foreach (e in engines) {
            GSEngine.EnableForCompany(e, c);
        }
    }
    GSLog.Info("Unlocked tier " + tier + " (" + engines.len() + " engines) for all companies");
}

function EngineClassifier::UnlockTierForCompany(tier, company) {
    local engines = this.GetTierEngines(tier);
    foreach (e in engines) {
        GSEngine.EnableForCompany(e, company);
    }
}

function EngineClassifier::ApplyLocksForCompany(company, unlocked_tiers) {
    foreach (engine_id, tier in this.engine_tiers) {
        local unlocked = false;
        foreach (ut in unlocked_tiers) {
            if (ut == tier) { unlocked = true; break; }
        }
        if (unlocked) {
            GSEngine.EnableForCompany(engine_id, company);
        } else {
            GSEngine.DisableForCompany(engine_id, company);
        }
    }
}
