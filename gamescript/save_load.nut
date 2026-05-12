class SaveLoad {
}

function SaveLoad::SaveState(gs) {
    local data = {
        version = 1,
        companies = {},
        engine_tiers = {},
        side_quests = []
    };

    foreach (engine_id, tier in gs.engine_classifier.engine_tiers) {
        if (!(tier in data.engine_tiers)) data.engine_tiers[tier] <- [];
        data.engine_tiers[tier].append(engine_id);
    }

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
            local r = { type = reward.type };
            if ("amount" in reward) r.amount <- reward.amount;
            if ("tier" in reward) r.tier <- reward.tier;
            sq_data.rewards.append(r);
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

    if ("engine_tiers" in data) {
        gs.engine_classifier.engine_tiers = {};
        gs.engine_classifier.tier_engines = {};
        for (local t = 0; t <= 6; t++) {
            gs.engine_classifier.tier_engines[t] <- [];
        }

        foreach (tier, engines in data.engine_tiers) {
            tier = tier.tointeger();
            foreach (engine_id in engines) {
                gs.engine_classifier.engine_tiers[engine_id] <- tier;
                gs.engine_classifier.tier_engines[tier].append(engine_id);
            }
        }
        GSLog.Info("Loaded engine tiers from save.");
    }

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
                local r = { type = reward.type };
                if ("amount" in reward) r.amount <- reward.amount;
                if ("tier" in reward) r.tier <- reward.tier;
                sq.rewards.append(r);
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
