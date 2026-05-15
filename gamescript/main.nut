require("engine_classifier.nut");
require("quest_defs.nut");
require("quest_manager.nut");
require("side_quest_generator.nut");
require("quest_ui.nut");
require("rewards.nut");
require("save_load.nut");

class QuestSystem extends GSController {
    engine_classifier = null;
    quest_manager = null;
    quest_ui = null;
    rewards = null;
    save_data = null;

    constructor() {
        this.engine_classifier = EngineClassifier();
        this.quest_manager = QuestManager();
        this.quest_ui = QuestUI();
        this.rewards = Rewards();
    }
}

function QuestSystem::Start() {
    GSLog.Info("OpenTTD Quests v1 starting...");

    if (this.save_data != null) {
        SaveLoad.LoadState(this, this.save_data);
        this.save_data = null;
        GSLog.Info("Loaded saved state.");
    } else {
        this.engine_classifier.ClassifyAll();
        this.engine_classifier.LockAllAboveTier(0);

        local start_tier = GSController.GetSetting("start_tier");
        for (local tier = 1; tier <= start_tier; tier++) {
            this.engine_classifier.UnlockTier(tier);
        }

        SideQuestGenerator.Generate(this.quest_manager);
        this.quest_manager.InitProgression(start_tier);
        GSLog.Info("New game initialized.");
    }

    this.quest_ui.InitPages(this.quest_manager);

    while (true) {
        this._HandleCompanies();
        this._CheckNewCompanies();
        GSController.Sleep(74);
    }
}

function QuestSystem::_HandleCompanies() {
    for (local company = GSCompany.COMPANY_FIRST; company <= GSCompany.COMPANY_LAST; company++) {
        if (GSCompany.ResolveCompanyID(company) == GSCompany.COMPANY_INVALID) continue;

        local completed = this.quest_manager.CheckConditions(company, this.engine_classifier);
        foreach (quest_id in completed) {
            this.rewards.Apply(quest_id, company, this.quest_manager, this.engine_classifier);
            this.quest_ui.OnQuestCompleted(quest_id, company, this.quest_manager);
        }

        this.quest_ui.UpdateProgress(company, this.quest_manager);
    }
}

function QuestSystem::_CheckNewCompanies() {
    for (local company = GSCompany.COMPANY_FIRST; company <= GSCompany.COMPANY_LAST; company++) {
        if (GSCompany.ResolveCompanyID(company) == GSCompany.COMPANY_INVALID) continue;
        if (this.quest_manager.HasCompany(company)) continue;

        this.quest_manager.AddCompany(company);
        this.engine_classifier.ApplyLocksForCompany(company, this.quest_manager.GetUnlockedTiers(company));
        this.quest_ui.InitPagesForCompany(company, this.quest_manager);
        GSLog.Info("New company " + company + " joined, initialized at Tier 0.");
    }
}

function QuestSystem::Save() {
    return SaveLoad.SaveState(this);
}

function QuestSystem::Load(version, data) {
    this.save_data = data;
}
