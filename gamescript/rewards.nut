class Rewards {
}

function Rewards::Apply(quest_id, company, quest_manager, classifier) {
    local quest = quest_manager.GetQuestDef(quest_id);
    if (quest == null) {
        GSLog.Error("Rewards: unknown quest " + quest_id);
        return;
    }

    local cash_enabled = GSController.GetSetting("cash_rewards") == 1;

    foreach (reward in quest.rewards) {
        switch (reward.type) {
            case RewardType.CASH:
                if (cash_enabled) {
                    GSCompany.ChangeBankBalance(company, reward.amount, GSCompany.EXPENSES_OTHER);
                    GSLog.Info("Reward: $" + reward.amount + " to company " + company);
                }
                break;

            case RewardType.UNLOCK_TIER:
                quest_manager.UnlockTier(company, reward.tier);
                classifier.UnlockTierForCompany(reward.tier, company);
                GSLog.Info("Reward: Tier " + reward.tier + " unlocked for company " + company);
                break;

            case RewardType.REPUTATION:
                this._ApplyReputation(company, reward.amount);
                GSLog.Info("Reward: Reputation +" + reward.amount + " for company " + company);
                break;

            case RewardType.VICTORY:
                GSLog.Info("VICTORY! Company " + company + " has completed all quests!");
                break;
        }
    }

    quest_manager.CompleteQuest(company, quest_id);
}

function Rewards::_ApplyReputation(company, amount) {
    local mode = GSCompanyMode(company);
    local best_town = -1;
    local best_pop = 0;

    local stypes = [GSStation.STATION_BUS_STOP, GSStation.STATION_TRAIN, GSStation.STATION_DOCK, GSStation.STATION_AIRPORT];
    foreach (st in stypes) {
        local slist = GSStationList(st);
        for (local s = slist.Begin(); !slist.IsEnd(); s = slist.Next()) {
            if (GSStation.HasCargoRating(s, 0)) {
                local town = GSStation.GetNearestTown(s);
                local pop = GSTown.GetPopulation(town);
                if (pop > best_pop) {
                    best_pop = pop;
                    best_town = town;
                }
            }
        }
    }

    if (best_town >= 0) {
        GSTown.ChangeRating(best_town, company, amount);
    }
}
