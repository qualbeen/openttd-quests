class QuestManager {
    companies = null;

    constructor() {
        this.companies = {};
    }

    function HasCompany(company) { return company in this.companies; }
    function AddCompany(company) { GSLog.Info("QuestManager.AddCompany() stub"); }
    function GetUnlockedTiers(company) { return [0]; }
    function InitProgression(start_tier) { GSLog.Info("QuestManager.InitProgression() stub"); }
    function CheckConditions(company, classifier) { return []; }
    function GetActiveQuests(company) { return []; }
    function GetQuestState(company, quest_id) { return "locked"; }
    function GetQuestProgress(company, quest_id) { return {}; }
}
