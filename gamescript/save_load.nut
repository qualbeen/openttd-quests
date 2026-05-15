class SaveLoad {
}

function SaveLoad::SaveState(gs) {
    local data = {
        version = 2,
        companies = {},
        side_quests = []
    };

    foreach (company, state in gs.quest_manager.companies) {
        data.companies[company] <- {
            unlocked_tiers = clone state.unlocked_tiers,
            quest_states = {},
            quest_progress = {}
        };

        foreach (qid, qstate in state.quest_states) {
            data.companies[company].quest_states[qid] <- qstate;
        }

        foreach (qid, progress in state.quest_progress) {
            data.companies[company].quest_progress[qid] <- clone progress;
        }
    }

    foreach (sq in gs.quest_manager.side_quests) {
        local sq_data = {
            id = sq.id,
            name = sq.name,
            tier = sq.tier,
            story = sq.story,
            objectives = [],
            rewards = []
        };

        foreach (obj in sq.objectives) {
            sq_data.objectives.append({
                type = obj.type,
                desc = obj.desc,
                params = clone obj.params
            });
        }

        foreach (reward in sq.rewards) {
            local reward_data = { type = reward.type };
            if ("amount" in reward) reward_data.amount <- reward.amount;
            if ("tier" in reward) reward_data.tier <- reward.tier;
            sq_data.rewards.append(reward_data);
        }

        data.side_quests.append(sq_data);
    }

    GSLog.Info("Game saved. " + data.companies.len() + " companies.");
    return data;
}

function SaveLoad::LoadState(gs, data) {
    if (!("version" in data)) {
        GSLog.Error("SaveLoad: no version in save data");
        return;
    }

    gs.engine_classifier.ClassifyAll();
    GSLog.Info("Re-classified engines on load.");

    if ("side_quests" in data) {
        foreach (sq_data in data.side_quests) {
            local sq = {
                id = sq_data.id,
                name = sq_data.name,
                tier = sq_data.tier,
                prerequisites = [],
                story = sq_data.story,
                objectives = [],
                rewards = []
            };

            foreach (obj in sq_data.objectives) {
                sq.objectives.append({
                    type = obj.type,
                    desc = obj.desc,
                    params = clone obj.params
                });
            }

            foreach (reward in sq_data.rewards) {
                local reward_entry = { type = reward.type };
                if ("amount" in reward) reward_entry.amount <- reward.amount;
                if ("tier" in reward) reward_entry.tier <- reward.tier;
                sq.rewards.append(reward_entry);
            }

            gs.quest_manager.AddSideQuest(sq);
        }
    }

    if ("companies" in data) {
        foreach (company, cdata in data.companies) {
            company = company.tointeger();
            gs.quest_manager.companies[company] <- {
                unlocked_tiers = clone cdata.unlocked_tiers,
                quest_states = {},
                quest_progress = {}
            };

            foreach (qid, qstate in cdata.quest_states) {
                gs.quest_manager.companies[company].quest_states[qid] <- qstate;
            }

            foreach (qid, progress in cdata.quest_progress) {
                gs.quest_manager.companies[company].quest_progress[qid] <- clone progress;
            }

            gs.engine_classifier.ApplyLocksForCompany(company, cdata.unlocked_tiers);
        }
    }

    GSLog.Info("Game loaded. " + gs.quest_manager.companies.len() + " companies restored.");
}
