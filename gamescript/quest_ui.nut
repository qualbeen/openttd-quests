class QuestUI {
    company_pages = null;
    company_goals = null;
}

function QuestUI::constructor() {
    this.company_pages = {};
    this.company_goals = {};
}

function QuestUI::InitPages(quest_manager) {
    for (local c = GSCompany.COMPANY_FIRST; c <= GSCompany.COMPANY_LAST; c++) {
        if (GSCompany.ResolveCompanyID(c) == GSCompany.COMPANY_INVALID) continue;
        this.InitPagesForCompany(c, quest_manager);
    }
}

function QuestUI::InitPagesForCompany(company, quest_manager) {
    this.company_pages[company] <- {};
    this.company_goals[company] <- {};

    this._CreateWelcomePage(company);

    local active = quest_manager.GetActiveQuests(company);
    foreach (quest in active) {
        this._CreateQuestPage(company, quest);
        this._CreateGoals(company, quest);
    }
}

function QuestUI::_CreateWelcomePage(company) {
    local page = GSStoryPage.New(company, GSText(GSText.STR_STORY_WELCOME_TITLE));
    GSStoryPage.NewElement(page, GSStoryPage.SPET_TEXT, 0, GSText(GSText.STR_STORY_WELCOME_TEXT));
    GSStoryPage.Show(page);
}

function QuestUI::_CreateQuestPage(company, quest) {
    local title = GSText(GSText.STR_STORY_QUEST_TITLE);
    title.AddParam(quest.name);

    local page = GSStoryPage.New(company, title);

    local story_text = GSText(GSText.STR_STORY_QUEST_TEXT);
    story_text.AddParam(quest.story);
    GSStoryPage.NewElement(page, GSStoryPage.SPET_TEXT, 0, story_text);

    foreach (obj in quest.objectives) {
        GSStoryPage.NewElement(page, GSStoryPage.SPET_TEXT, 0, GSText(GSText.STR_STORY_QUEST_TEXT, obj.desc));
    }

    local reward_desc = this._BuildRewardText(quest);
    local reward_text = GSText(GSText.STR_STORY_REWARD_TEXT);
    reward_text.AddParam(reward_desc);
    GSStoryPage.NewElement(page, GSStoryPage.SPET_TEXT, 0, reward_text);

    this.company_pages[company][quest.id] <- page;
}

function QuestUI::_CreateGoals(company, quest) {
    local goal_ids = [];

    foreach (obj in quest.objectives) {
        local goal = GSGoal.New(company, GSText(GSText.STR_GOAL_PROGRESS, obj.desc, 0, 1), GSGoal.GT_NONE, 0);
        goal_ids.append(goal);
    }

    this.company_goals[company][quest.id] <- goal_ids;
}

function QuestUI::_BuildRewardText(quest) {
    local parts = [];
    foreach (reward in quest.rewards) {
        switch (reward.type) {
            case RewardType.CASH:
                parts.append("$" + reward.amount);
                break;
            case RewardType.UNLOCK_TIER:
                parts.append("Unlock Tier " + reward.tier);
                break;
            case RewardType.REPUTATION:
                parts.append("Town reputation boost");
                break;
            case RewardType.VICTORY:
                parts.append("Victory!");
                break;
        }
    }

    local result = "";
    foreach (idx, p in parts) {
        if (idx > 0) result += ", ";
        result += p;
    }
    return result;
}

function QuestUI::OnQuestCompleted(quest_id, company, quest_manager) {
    if (company in this.company_goals && quest_id in this.company_goals[company]) {
        foreach (goal_id in this.company_goals[company][quest_id]) {
            GSGoal.SetCompleted(goal_id, true);
        }
    }

    local quest = quest_manager.GetQuestDef(quest_id);
    if (quest != null) {
        GSGoal.Question(0, company, GSText(GSText.STR_QUEST_COMPLETED, quest.name), GSGoal.QT_INFORMATION, GSGoal.BUTTON_CLOSE);
    }

    local newly_active = quest_manager.GetActiveQuests(company);
    foreach (q in newly_active) {
        if (!(q.id in this.company_pages[company])) {
            this._CreateQuestPage(company, q);
            this._CreateGoals(company, q);
        }
    }

    foreach (reward in quest.rewards) {
        if (reward.type == RewardType.UNLOCK_TIER) {
            this._CreateTierUnlockPage(company, reward.tier);
        }
    }
}

function QuestUI::_CreateTierUnlockPage(company, tier) {
    local tier_names = ["Getting Started", "The Iron Road", "Sea & Expansion", "Electrification", "Taking Flight", "Monorail Age", "Maglev Mastery"];
    local name = tier < tier_names.len() ? tier_names[tier] : "Tier " + tier;

    local title = GSText(GSText.STR_STORY_TIER_TITLE, tier, name);
    local page = GSStoryPage.New(company, title);
    GSStoryPage.NewElement(page, GSStoryPage.SPET_TEXT, 0, GSText(GSText.STR_STORY_TIER_TEXT));
    GSStoryPage.Show(page);

    GSGoal.Question(0, company, GSText(GSText.STR_TIER_UNLOCKED, tier, name), GSGoal.QT_INFORMATION, GSGoal.BUTTON_CLOSE);
}

function QuestUI::UpdateProgress(company, quest_manager) {
    if (!(company in this.company_goals)) return;

    local active = quest_manager.GetActiveQuests(company);
    foreach (quest in active) {
        if (!(quest.id in this.company_goals[company])) continue;

        local goal_ids = this.company_goals[company][quest.id];
        foreach (idx, obj in quest.objectives) {
            if (idx >= goal_ids.len()) continue;
            local goal_id = goal_ids[idx];
            if (!GSGoal.IsValidGoal(goal_id)) continue;

            GSGoal.SetText(goal_id, GSText(GSText.STR_GOAL_PROGRESS, obj.desc, 0, 1));
        }
    }
}
