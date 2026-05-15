class EngineClassifier {
    engine_tiers = null;
    tier_engines = null;

    constructor() {
        this.engine_tiers = {};
        this.tier_engines = {};
        for (local tier = 0; tier <= 6; tier++) {
            this.tier_engines[tier] <- [];
        }
    }
}

function EngineClassifier::ClassifyAll() {
    this.engine_tiers = {};
    for (local tier = 0; tier <= 6; tier++) {
        this.tier_engines[tier] = [];
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
        for (local engine = list.Begin(); !list.IsEnd(); engine = list.Next()) {
            this._Assign(engine, 4);
        }
        return;
    }

    if (vtype == GSVehicle.VT_WATER) {
        for (local engine = list.Begin(); !list.IsEnd(); engine = list.Next()) {
            this._Assign(engine, 2);
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
    for (local engine = list.Begin(); !list.IsEnd(); engine = list.Next()) {
        this._Assign(engine, 0);
    }
}

function EngineClassifier::_ClassifyTrains(list) {
    local normal_engines = [];
    local normal_speeds = [];

    for (local engine = list.Begin(); !list.IsEnd(); engine = list.Next()) {
        local rail_type = GSEngine.GetRailType(engine);
        local rt_name = GSRail.GetName(rail_type);

        if (rt_name == null) {
            this._Assign(engine, 1);
            continue;
        }

        local rt_lower = rt_name.tolower();

        if (rt_lower.find("maglev") != null) {
            this._Assign(engine, 6);
        } else if (rt_lower.find("mono") != null) {
            this._Assign(engine, 5);
        } else if (rt_lower.find("elec") != null || rt_lower.find("elrl") != null) {
            this._Assign(engine, 3);
        } else {
            normal_engines.append(engine);
            normal_speeds.append(GSEngine.GetMaxSpeed(engine));
        }
    }

    if (normal_engines.len() == 0) return;

    local sorted_speeds = clone normal_speeds;
    sorted_speeds.sort(function(a, b) { if (a < b) return -1; if (a > b) return 1; return 0; });
    local median_speed = sorted_speeds[sorted_speeds.len() / 2];

    foreach (idx, engine in normal_engines) {
        if (normal_speeds[idx] <= median_speed) {
            this._Assign(engine, 1);
        } else {
            this._Assign(engine, 2);
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
    for (local company = GSCompany.COMPANY_FIRST; company <= GSCompany.COMPANY_LAST; company++) {
        if (GSCompany.ResolveCompanyID(company) == GSCompany.COMPANY_INVALID) continue;
        foreach (engine_id, tier in this.engine_tiers) {
            if (tier > max_tier) {
                GSEngine.DisableForCompany(engine_id, company);
            }
        }
    }
    GSLog.Info("Locked all engines above tier " + max_tier);
}

function EngineClassifier::UnlockTier(tier) {
    local engines = this.GetTierEngines(tier);
    for (local company = GSCompany.COMPANY_FIRST; company <= GSCompany.COMPANY_LAST; company++) {
        if (GSCompany.ResolveCompanyID(company) == GSCompany.COMPANY_INVALID) continue;
        foreach (engine in engines) {
            GSEngine.EnableForCompany(engine, company);
        }
    }
    GSLog.Info("Unlocked tier " + tier + " (" + engines.len() + " engines) for all companies");
}

function EngineClassifier::UnlockTierForCompany(tier, company) {
    local engines = this.GetTierEngines(tier);
    foreach (engine in engines) {
        GSEngine.EnableForCompany(engine, company);
    }
}

function EngineClassifier::ApplyLocksForCompany(company, unlocked_tiers) {
    foreach (engine_id, tier in this.engine_tiers) {
        local unlocked = false;
        foreach (ut in unlocked_tiers) {
            if (ut == tier) { unlocked = true; break; }
        }
        if (!unlocked) {
            GSEngine.DisableForCompany(engine_id, company);
        }
    }
}
