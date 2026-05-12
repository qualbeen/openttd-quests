class QuestSystemInfo extends GSInfo {
    function GetAuthor()      { return "qualbeen"; }
    function GetName()        { return "OpenTTD Quests"; }
    function GetDescription() { return "Quest and mission system with vehicle unlock progression"; }
    function GetVersion()     { return 1; }
    function GetDate()        { return "2026-05-13"; }
    function CreateInstance() { return "QuestSystem"; }
    function GetShortName()   { return "QUEST"; }
    function GetAPIVersion()  { return "14"; }
    function GetURL()         { return "https://github.com/qualbeen/openttd-quests"; }

    function GetSettings() {
        AddSetting({
            name = "difficulty",
            description = "Difficulty level (scales objective amounts)",
            min_value = 0,
            max_value = 2,
            easy_value = 0,
            medium_value = 1,
            hard_value = 1,
            custom_value = 1,
            flags = 0
        });
        AddLabels("difficulty", {
            _0 = "Easy (0.5x)",
            _1 = "Normal (1x)",
            _2 = "Hard (2x)"
        });

        AddSetting({
            name = "side_quest_count",
            description = "Number of side quests (0 = auto based on map size)",
            min_value = 0,
            max_value = 30,
            easy_value = 0,
            medium_value = 0,
            hard_value = 0,
            custom_value = 0,
            flags = 0
        });

        AddSetting({
            name = "cash_rewards",
            description = "Enable cash reward bonuses",
            min_value = 0,
            max_value = 1,
            easy_value = 1,
            medium_value = 1,
            hard_value = 1,
            custom_value = 1,
            flags = CONFIG_BOOLEAN
        });

        AddSetting({
            name = "start_tier",
            description = "Start with tiers already unlocked (for experienced players)",
            min_value = 0,
            max_value = 6,
            easy_value = 0,
            medium_value = 0,
            hard_value = 0,
            custom_value = 0,
            flags = 0
        });
    }
}

RegisterGS(QuestSystemInfo());
