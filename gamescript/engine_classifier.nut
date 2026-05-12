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

    function ClassifyAll() { GSLog.Info("EngineClassifier.ClassifyAll() stub"); }
    function LockAllAboveTier(tier) { GSLog.Info("EngineClassifier.LockAllAboveTier() stub"); }
    function UnlockTier(tier) { GSLog.Info("EngineClassifier.UnlockTier() stub"); }
    function ApplyLocksForCompany(company, unlocked_tiers) { GSLog.Info("EngineClassifier.ApplyLocksForCompany() stub"); }
    function GetTierEngines(tier) { return this.tier_engines[tier]; }
    function GetEngineTier(engine_id) { return engine_id in this.engine_tiers ? this.engine_tiers[engine_id] : -1; }
}
