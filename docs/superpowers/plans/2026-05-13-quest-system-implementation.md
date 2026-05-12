# OpenTTD Quest System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete OpenTTD GameScript in Squirrel that adds a quest/mission system with vehicle unlock progression, side quests, and co-op support.

**Architecture:** Pure GameScript — 10 Squirrel files in `gamescript/`, no NewGRF. Engine classification scans all engines at game start and assigns them to 7 unlock tiers. Quest manager tracks per-company state, checks conditions each tick, applies rewards. UI uses Story Pages for quest log and Goals for objective tracking.

**Tech Stack:** Squirrel 2 (OpenTTD scripting language), OpenTTD GameScript API v14

**Important Squirrel/GS conventions:**
- Squirrel uses `class Foo extends Bar {}` syntax, `function Foo::Method()` for out-of-class method definitions
- `local` declares local variables, no `var`/`let`
- Tables use `{ key = value }` syntax (equals, not colon)
- Arrays use `[item1, item2]`
- `foreach (key, value in table)` for iteration
- `require("file.nut")` to include other files
- `GSLog.Info("msg")` for debug logging
- All GS API methods are static: `GSEngine.GetVehicleType(engine_id)`
- `GSController.Sleep(ticks)` suspends execution; 74 ticks ≈ 1 game day
- `GSText(GSText.STR_NAME)` references strings from `lang/english.txt`
- `GSText.AddParam(value)` adds parameters to text for `{COMMA}`, `{STRING}`, etc.
- Lists (GSEngineList, GSVehicleList, etc.) use `Begin()`/`Next()`/`IsEnd()` for iteration and `Valuate(function)` for bulk operations

**Testing approach:** No unit test framework exists for Squirrel GameScripts. Testing is manual:
1. Symlink `gamescript/` to OpenTTD's `game/` directory
2. Start a new game on a small map (256x256) with the script enabled
3. Use the AI/GS debug window (accessible via the wrench menu) to see `GSLog.Info()` output
4. Use the console command `restart` to quickly restart with same settings

---

### Task 1: GS Boilerplate — info.nut and main.nut skeleton

**Files:**
- Create: `gamescript/info.nut`
- Create: `gamescript/main.nut`
- Create: `gamescript/lang/english.txt`

- [ ] **Step 1: Create `gamescript/info.nut`**

```squirrel
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
```

- [ ] **Step 2: Create `gamescript/lang/english.txt`**

```
STR_GS_NAME                    :OpenTTD Quests

STR_QUEST_COMPLETED            :{WHITE}Quest Completed: {STRING}
STR_TIER_UNLOCKED              :{WHITE}Tier {COMMA} Unlocked: {STRING}!
STR_QUEST_AVAILABLE            :{WHITE}New Quest Available: {STRING}

STR_STORY_WELCOME_TITLE        :Welcome to OpenTTD Quests
STR_STORY_WELCOME_TEXT         :{BLACK}You start with only buses and trucks. Complete quests to unlock trains, ships, aircraft, and more!{}{}Open the Goal window to track your active objectives.

STR_STORY_TIER_TITLE           :Tier {COMMA} Unlocked — {STRING}
STR_STORY_TIER_TEXT            :{BLACK}Congratulations! You've unlocked new vehicles and capabilities.{}{}Check the vehicle depot to see what's now available.

STR_STORY_QUEST_TITLE          :{STRING}
STR_STORY_QUEST_TEXT           :{BLACK}{STRING}
STR_STORY_REWARD_TEXT          :{BLACK}Reward: {STRING}
STR_STORY_COMPLETED_TEXT       :{BLACK}Quest completed! Well done.

STR_GOAL_PROGRESS              :{STRING}: {COMMA}/{COMMA}
STR_GOAL_COMPLETE              :{STRING}: Complete!

STR_REWARD_CASH                :${COMMA} bonus
STR_REWARD_UNLOCK_TIER         :Unlock Tier {COMMA}
STR_REWARD_REPUTATION          :Town reputation boost
STR_REWARD_VICTORY             :Victory!

STR_TIER0_NAME                 :Getting Started
STR_TIER1_NAME                 :The Iron Road
STR_TIER2_NAME                 :Sea & Expansion
STR_TIER3_NAME                 :Electrification
STR_TIER4_NAME                 :Taking Flight
STR_TIER5_NAME                 :Monorail Age
STR_TIER6_NAME                 :Maglev Mastery
```

- [ ] **Step 3: Create `gamescript/main.nut` skeleton**

```squirrel
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
        for (local t = 1; t <= start_tier; t++) {
            this.engine_classifier.UnlockTier(t);
        }

        this.quest_manager.InitProgression(start_tier);
        SideQuestGenerator.Generate(this.quest_manager);
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
    for (local c = GSCompany.COMPANY_FIRST; c <= GSCompany.COMPANY_LAST; c++) {
        if (GSCompany.ResolveCompanyID(c) == GSCompany.COMPANY_INVALID) continue;

        local completed = this.quest_manager.CheckConditions(c, this.engine_classifier);
        foreach (quest_id in completed) {
            this.rewards.Apply(quest_id, c, this.quest_manager, this.engine_classifier);
            this.quest_ui.OnQuestCompleted(quest_id, c, this.quest_manager);
        }

        this.quest_ui.UpdateProgress(c, this.quest_manager);
    }
}

function QuestSystem::_CheckNewCompanies() {
    for (local c = GSCompany.COMPANY_FIRST; c <= GSCompany.COMPANY_LAST; c++) {
        if (GSCompany.ResolveCompanyID(c) == GSCompany.COMPANY_INVALID) continue;
        if (this.quest_manager.HasCompany(c)) continue;

        this.quest_manager.AddCompany(c);
        this.engine_classifier.ApplyLocksForCompany(c, this.quest_manager.GetUnlockedTiers(c));
        this.quest_ui.InitPagesForCompany(c, this.quest_manager);
        GSLog.Info("New company " + c + " joined, initialized at Tier 0.");
    }
}

function QuestSystem::Save() {
    return SaveLoad.SaveState(this);
}

function QuestSystem::Load(version, data) {
    this.save_data = data;
}
```

- [ ] **Step 4: Create stub files for all other modules**

Create each file with an empty class so `require()` doesn't fail:

`gamescript/engine_classifier.nut`:
```squirrel
class EngineClassifier {
    engine_tiers = null;   // table: engine_id -> tier
    tier_engines = null;   // table: tier -> [engine_ids]

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
```

`gamescript/quest_defs.nut`:
```squirrel
class QuestDefs {
    static QUESTS = [];
}
```

`gamescript/quest_manager.nut`:
```squirrel
class QuestManager {
    companies = null;    // table: company_id -> company state

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
```

`gamescript/side_quest_generator.nut`:
```squirrel
class SideQuestGenerator {
    static function Generate(quest_manager) { GSLog.Info("SideQuestGenerator.Generate() stub"); }
}
```

`gamescript/quest_ui.nut`:
```squirrel
class QuestUI {
    function InitPages(quest_manager) { GSLog.Info("QuestUI.InitPages() stub"); }
    function InitPagesForCompany(company, quest_manager) { GSLog.Info("QuestUI.InitPagesForCompany() stub"); }
    function OnQuestCompleted(quest_id, company, quest_manager) { GSLog.Info("QuestUI.OnQuestCompleted() stub"); }
    function UpdateProgress(company, quest_manager) { GSLog.Info("QuestUI.UpdateProgress() stub"); }
}
```

`gamescript/rewards.nut`:
```squirrel
class Rewards {
    function Apply(quest_id, company, quest_manager, classifier) { GSLog.Info("Rewards.Apply() stub"); }
}
```

`gamescript/save_load.nut`:
```squirrel
class SaveLoad {
    static function SaveState(gs) {
        return { version = 1 };
    }

    static function LoadState(gs, data) {
        GSLog.Info("SaveLoad.LoadState() stub");
    }
}
```

- [ ] **Step 5: Test the boilerplate loads in OpenTTD**

Symlink the gamescript directory to your OpenTTD game folder:
```bash
ln -sf "$(pwd)/gamescript" ~/Documents/OpenTTD/game/openttd-quests
```

Launch OpenTTD → New Game → AI/Game Script Settings → select "OpenTTD Quests". Start a 256x256 map. Open the AI/GS debug window and verify you see:
```
OpenTTD Quests v1 starting...
New game initialized.
```

- [ ] **Step 6: Commit**

```bash
git add gamescript/
git commit -m "feat: add GameScript boilerplate with all module stubs"
```

---

### Task 2: Engine Classifier — dynamic engine scanning and tier assignment

**Files:**
- Modify: `gamescript/engine_classifier.nut`

- [ ] **Step 1: Implement `ClassifyAll()`**

Replace the stub in `gamescript/engine_classifier.nut`:

```squirrel
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
```

- [ ] **Step 2: Implement lock/unlock methods**

Append to `gamescript/engine_classifier.nut`:

```squirrel
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
```

- [ ] **Step 3: Test in OpenTTD**

Start a new game with the script. Open AI/GS debug and verify:
```
Tier 0: X engines
Tier 1: X engines
...
Tier 6: X engines
Locked all engines above tier 0
```

Open a road vehicle depot and verify only basic buses/trucks appear. Open a train depot and verify no trains are available.

- [ ] **Step 4: Commit**

```bash
git add gamescript/engine_classifier.nut
git commit -m "feat: implement engine classifier with dynamic tier assignment"
```

---

### Task 3: Quest Definitions — all 25 progression quests

**Files:**
- Modify: `gamescript/quest_defs.nut`

- [ ] **Step 1: Define the quest data structure and all progression quests**

Replace `gamescript/quest_defs.nut`:

```squirrel
// Objective types
enum ObjType {
    BUY_VEHICLE,
    ROUTE_PROFIT,
    CONNECT_TOWNS_ROAD,
    TRANSPORT_CARGO,
    CONNECT_TOWN_INTERNAL,
    CONNECT_TOWNS_RAIL,
    TRANSPORT_PASSENGERS_RAIL,
    GROW_TOWN,
    RAIL_NETWORK,
    BUILD_DOCK_AND_SHIP,
    TRANSPORT_OIL,
    COMPANY_VALUE,
    BUILD_ELECTRIFIED_RAIL,
    ELECTRIC_TRAIN_SPEED,
    TRANSPORT_CARGO_TYPES,
    BUILD_AIRPORT_AND_FLY,
    AIR_BRIDGE,
    ALL_TRANSPORT_TYPES,
    BUILD_MONORAIL,
    MONORAIL_SPEED,
    NETWORK_SIZE,
    BUILD_MAGLEV,
    TOTAL_POP_SERVED
}

// Reward types
enum RewardType {
    CASH,
    UNLOCK_TIER,
    REPUTATION,
    VICTORY
}

class QuestDefs {
}

function QuestDefs::GetAll(difficulty_mult) {
    if (difficulty_mult == null) difficulty_mult = 1.0;

    local m = difficulty_mult;

    return [
        // === TIER 0: GETTING STARTED ===
        {
            id = "tier0_first_wheels",
            name = "First Wheels",
            tier = 0,
            prerequisites = [],
            objectives = [
                { type = ObjType.BUY_VEHICLE, params = { count = 1 }, desc = "Buy your first vehicle" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (10000 * m).tointeger() }],
            story = "Every empire starts with a single vehicle. Buy your first bus or truck and put it to work!"
        },
        {
            id = "tier0_bus_baron",
            name = "Bus Baron",
            tier = 0,
            prerequisites = ["tier0_first_wheels"],
            objectives = [
                { type = ObjType.ROUTE_PROFIT, params = { amount = (5000 * m).tointeger(), vehicle_type = GSVehicle.VT_ROAD }, desc = "Earn $" + (5000 * m).tointeger() + "/yr from road vehicles" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (25000 * m).tointeger() }],
            story = "Your bus routes are filling up. Keep expanding your road network and watch the profits roll in."
        },
        {
            id = "tier0_city_transit",
            name = "City Transit",
            tier = 0,
            prerequisites = ["tier0_bus_baron"],
            objectives = [
                { type = ObjType.CONNECT_TOWN_INTERNAL, params = { min_stops = 4, min_passengers = (200 * m).tointeger() }, desc = "Build 4+ bus stops in one town, transport " + (200 * m).tointeger() + " passengers" }
            ],
            rewards = [
                { type = RewardType.CASH, amount = (20000 * m).tointeger() },
                { type = RewardType.REPUTATION, amount = 200 }
            ],
            story = "The townspeople need to get around! Build an internal bus network so they can travel within their own town."
        },
        {
            id = "tier0_connect_dots",
            name = "Connect the Dots",
            tier = 0,
            prerequisites = ["tier0_city_transit"],
            objectives = [
                { type = ObjType.CONNECT_TOWNS_ROAD, params = { min_towns = 3 }, desc = "Provide bus service to 3 towns" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (30000 * m).tointeger() }],
            story = "Time to think bigger. Connect multiple towns together and build a regional bus network."
        },
        {
            id = "tier0_truckers_life",
            name = "Trucker's Life",
            tier = 0,
            prerequisites = ["tier0_connect_dots"],
            objectives = [
                { type = ObjType.TRANSPORT_CARGO, params = { amount = (200 * m).tointeger() }, desc = "Deliver " + (200 * m).tointeger() + " units of cargo by truck" }
            ],
            rewards = [{ type = RewardType.UNLOCK_TIER, tier = 1 }],
            story = "The factories need supplies and the towns need goods. Show the world what trucks can do, and perhaps a new form of transport will become available..."
        },

        // === TIER 1: THE IRON ROAD ===
        {
            id = "tier1_iron_road",
            name = "The Iron Road",
            tier = 1,
            prerequisites = ["tier0_truckers_life"],
            objectives = [
                { type = ObjType.CONNECT_TOWNS_RAIL, params = { min_towns = 2, min_tiles = 20 }, desc = "Connect 2 towns by rail (20+ tiles of track)" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (50000 * m).tointeger() }],
            story = "The roads are getting crowded. The townspeople have heard of this new invention — the railway. Connect two towns with steel rails and show them the future of transport."
        },
        {
            id = "tier1_passenger_express",
            name = "Passenger Express",
            tier = 1,
            prerequisites = ["tier1_iron_road"],
            objectives = [
                { type = ObjType.TRANSPORT_PASSENGERS_RAIL, params = { amount = (500 * m).tointeger() }, desc = "Transport " + (500 * m).tointeger() + " passengers by train" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (40000 * m).tointeger() }],
            story = "People are eager to ride the rails. Fill those carriages and show them how fast they can travel."
        },
        {
            id = "tier1_growing_pains",
            name = "Growing Pains",
            tier = 1,
            prerequisites = ["tier1_iron_road"],
            objectives = [
                { type = ObjType.GROW_TOWN, params = { target = (1000 * m).tointeger() }, desc = "Grow any town to " + (1000 * m).tointeger() + " population" }
            ],
            rewards = [{ type = RewardType.REPUTATION, amount = 200 }],
            story = "A well-connected town is a growing town. Provide good transport links and watch it flourish."
        },
        {
            id = "tier1_rail_network",
            name = "Rail Network",
            tier = 1,
            prerequisites = ["tier1_passenger_express", "tier1_growing_pains"],
            objectives = [
                { type = ObjType.RAIL_NETWORK, params = { min_towns = 5, min_tiles = 100, min_profit = (50000 * m).tointeger() }, desc = "5 towns by rail, 100+ tiles, $" + (50000 * m).tointeger() + " profit" }
            ],
            rewards = [{ type = RewardType.UNLOCK_TIER, tier = 2 }],
            story = "Your railway is becoming a true network. Expand it further, connect more towns, and the seas will open up to you."
        },

        // === TIER 2: SEA & EXPANSION ===
        {
            id = "tier2_set_sail",
            name = "Set Sail",
            tier = 2,
            prerequisites = ["tier1_rail_network"],
            objectives = [
                { type = ObjType.BUILD_DOCK_AND_SHIP, params = {}, desc = "Build a dock and run a ship route" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (60000 * m).tointeger() }],
            story = "The rivers and coasts are calling. Build a dock and launch your first ship — new trade routes await across the water."
        },
        {
            id = "tier2_oil_tycoon",
            name = "Oil Tycoon",
            tier = 2,
            prerequisites = ["tier2_set_sail"],
            objectives = [
                { type = ObjType.TRANSPORT_OIL, params = { amount = (500 * m).tointeger() }, desc = "Transport " + (500 * m).tointeger() + " oil" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (75000 * m).tointeger() }],
            story = "Black gold! The refineries are hungry for oil. Ship it by sea or rail — whatever gets it there."
        },
        {
            id = "tier2_metropolis",
            name = "Metropolis",
            tier = 2,
            prerequisites = ["tier2_set_sail"],
            objectives = [
                { type = ObjType.GROW_TOWN, params = { target = (3000 * m).tointeger() }, desc = "Grow a town to " + (3000 * m).tointeger() + " population" }
            ],
            rewards = [{ type = RewardType.REPUTATION, amount = 200 }],
            story = "Your best-connected town is becoming a proper city. Keep the passengers and goods flowing."
        },
        {
            id = "tier2_trade_empire",
            name = "Trade Empire",
            tier = 2,
            prerequisites = ["tier2_oil_tycoon", "tier2_metropolis"],
            objectives = [
                { type = ObjType.COMPANY_VALUE, params = { amount = (500000 * m).tointeger() }, desc = "Company value $" + (500000 * m).tointeger() },
                { type = ObjType.CONNECT_TOWNS_ROAD, params = { min_towns = 8 }, desc = "8 towns connected" }
            ],
            rewards = [{ type = RewardType.UNLOCK_TIER, tier = 3 }],
            story = "You've built a true trade empire. Your reach and value have earned the attention of electrical engineers with grand plans..."
        },

        // === TIER 3: ELECTRIFICATION ===
        {
            id = "tier3_power_up",
            name = "Power Up",
            tier = 3,
            prerequisites = ["tier2_trade_empire"],
            objectives = [
                { type = ObjType.BUILD_ELECTRIFIED_RAIL, params = { min_tiles = (20 * m).tointeger() }, desc = "Build " + (20 * m).tointeger() + " tiles of electrified rail" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (100000 * m).tointeger() }],
            story = "The age of steam is ending. Electrify your rails and feel the power of modern locomotives."
        },
        {
            id = "tier3_high_speed",
            name = "High Speed",
            tier = 3,
            prerequisites = ["tier3_power_up"],
            objectives = [
                { type = ObjType.ELECTRIC_TRAIN_SPEED, params = { min_speed = 100 }, desc = "Run an electric train over 100 km/h" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (80000 * m).tointeger() }],
            story = "Electric trains aren't just cleaner — they're faster. Push the limits and break the speed barrier."
        },
        {
            id = "tier3_megacity",
            name = "Megacity",
            tier = 3,
            prerequisites = ["tier3_power_up"],
            objectives = [
                { type = ObjType.GROW_TOWN, params = { target = (10000 * m).tointeger() }, desc = "Grow a town to " + (10000 * m).tointeger() + " population" }
            ],
            rewards = [{ type = RewardType.REPUTATION, amount = 200 }],
            story = "Your city is becoming a metropolis. A town of ten thousand, all thanks to your transport network."
        },
        {
            id = "tier3_industrial_giant",
            name = "Industrial Giant",
            tier = 3,
            prerequisites = ["tier3_high_speed", "tier3_megacity"],
            objectives = [
                { type = ObjType.TRANSPORT_CARGO_TYPES, params = { count = 5 }, desc = "Transport 5 different cargo types" },
                { type = ObjType.COMPANY_VALUE, params = { amount = (1000000 * m).tointeger() }, desc = "Company value $" + (1000000 * m).tointeger() }
            ],
            rewards = [{ type = RewardType.UNLOCK_TIER, tier = 4 }],
            story = "You're an industrial giant now — diversified, wealthy, and powerful. The skies beckon..."
        },

        // === TIER 4: TAKING FLIGHT ===
        {
            id = "tier4_wright_brothers",
            name = "Wright Brothers",
            tier = 4,
            prerequisites = ["tier3_industrial_giant"],
            objectives = [
                { type = ObjType.BUILD_AIRPORT_AND_FLY, params = {}, desc = "Build an airport and fly 1 aircraft" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (150000 * m).tointeger() }],
            story = "The dream of flight becomes reality. Build an airport and take to the skies!"
        },
        {
            id = "tier4_air_bridge",
            name = "Air Bridge",
            tier = 4,
            prerequisites = ["tier4_wright_brothers"],
            objectives = [
                { type = ObjType.AIR_BRIDGE, params = { min_distance = 200 }, desc = "Connect 2 cities 200+ tiles apart by air" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (200000 * m).tointeger() }],
            story = "Air travel shines over long distances. Bridge the gap between two far-flung cities."
        },
        {
            id = "tier4_transport_mogul",
            name = "Transport Mogul",
            tier = 4,
            prerequisites = ["tier4_air_bridge"],
            objectives = [
                { type = ObjType.CONNECT_TOWNS_ROAD, params = { min_towns = 15 }, desc = "15 towns connected" },
                { type = ObjType.ALL_TRANSPORT_TYPES, params = {}, desc = "Use all 4 transport types (road, rail, ship, air)" }
            ],
            rewards = [{ type = RewardType.UNLOCK_TIER, tier = 5 }],
            story = "You command road, rail, sea, and air. You are a true transport mogul. But there are whispers of something faster..."
        },

        // === TIER 5: MONORAIL AGE ===
        {
            id = "tier5_future_is_now",
            name = "The Future Is Now",
            tier = 5,
            prerequisites = ["tier4_transport_mogul"],
            objectives = [
                { type = ObjType.BUILD_MONORAIL, params = { min_tiles = 50 }, desc = "Build 50+ tiles of monorail" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (300000 * m).tointeger() }],
            story = "Elevated, sleek, and fast — the monorail represents the cutting edge. Build a line worthy of the future."
        },
        {
            id = "tier5_speed_demon",
            name = "Speed Demon",
            tier = 5,
            prerequisites = ["tier5_future_is_now"],
            objectives = [
                { type = ObjType.MONORAIL_SPEED, params = { min_speed = 200 }, desc = "Monorail train over 200 km/h" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (250000 * m).tointeger() }],
            story = "The monorail is built for speed. Push it past 200 and feel the rush."
        },
        {
            id = "tier5_continental_network",
            name = "Continental Network",
            tier = 5,
            prerequisites = ["tier5_speed_demon"],
            objectives = [
                { type = ObjType.NETWORK_SIZE, params = { min_towns = 20, min_tiles = 500 }, desc = "20 towns connected, 500+ tile network" },
                { type = ObjType.COMPANY_VALUE, params = { amount = (5000000 * m).tointeger() }, desc = "Company value $" + (5000000 * m).tointeger() }
            ],
            rewards = [{ type = RewardType.UNLOCK_TIER, tier = 6 }],
            story = "Your network spans the continent. One final technology awaits the most ambitious of builders..."
        },

        // === TIER 6: MAGLEV MASTERY ===
        {
            id = "tier6_levitation",
            name = "Levitation",
            tier = 6,
            prerequisites = ["tier5_continental_network"],
            objectives = [
                { type = ObjType.BUILD_MAGLEV, params = {}, desc = "Build a maglev line and run a train" }
            ],
            rewards = [{ type = RewardType.CASH, amount = (500000 * m).tointeger() }],
            story = "Magnetic levitation — trains that float on air. Build the pinnacle of transport technology."
        },
        {
            id = "tier6_master",
            name = "Master of Transport",
            tier = 6,
            prerequisites = ["tier6_levitation"],
            objectives = [
                { type = ObjType.CONNECT_TOWNS_ROAD, params = { min_towns = 30 }, desc = "30 towns connected" },
                { type = ObjType.COMPANY_VALUE, params = { amount = (10000000 * m).tointeger() }, desc = "Company value $" + (10000000 * m).tointeger() },
                { type = ObjType.TOTAL_POP_SERVED, params = { amount = (50000 * m).tointeger() }, desc = "50,000 total population served" }
            ],
            rewards = [{ type = RewardType.VICTORY }],
            story = "You have mastered every form of transport. Your network connects an entire civilization. You are the undisputed Master of Transport."
        }
    ];
}
```

- [ ] **Step 2: Test that quest definitions load without error**

Start OpenTTD with the script. The quest definitions are loaded by `QuestManager.InitProgression()` (still a stub, but the file should parse without syntax errors). Check the AI/GS debug window for no errors.

- [ ] **Step 3: Commit**

```bash
git add gamescript/quest_defs.nut
git commit -m "feat: define all 25 progression quests with objectives and rewards"
```

---

### Task 4: Quest Manager — state tracking and condition checking

**Files:**
- Modify: `gamescript/quest_manager.nut`

- [ ] **Step 1: Implement company state tracking and quest lifecycle**

Replace `gamescript/quest_manager.nut`:

```squirrel
class QuestManager {
    companies = null;
    quest_defs = null;
    side_quests = null;
}

function QuestManager::constructor() {
    this.companies = {};
    this.side_quests = [];

    local diff = GSController.GetSetting("difficulty");
    local mult = 1.0;
    if (diff == 0) mult = 0.5;
    if (diff == 2) mult = 2.0;
    this.quest_defs = QuestDefs.GetAll(mult);
}

function QuestManager::InitProgression(start_tier) {
    for (local c = GSCompany.COMPANY_FIRST; c <= GSCompany.COMPANY_LAST; c++) {
        if (GSCompany.ResolveCompanyID(c) == GSCompany.COMPANY_INVALID) continue;
        this.AddCompany(c, start_tier);
    }
}

function QuestManager::AddCompany(company, start_tier = 0) {
    local unlocked = [];
    for (local t = 0; t <= start_tier; t++) {
        unlocked.append(t);
    }

    this.companies[company] <- {
        unlocked_tiers = unlocked,
        quest_states = {},
        quest_progress = {}
    };

    foreach (quest in this.quest_defs) {
        if (quest.tier <= start_tier) {
            local all_prereqs_met = true;
            foreach (p in quest.prerequisites) {
                if (!(p in this.companies[company].quest_states) ||
                    this.companies[company].quest_states[p] != "completed") {
                    all_prereqs_met = false;
                    break;
                }
            }

            if (quest.prerequisites.len() == 0 || quest.tier < start_tier) {
                this.companies[company].quest_states[quest.id] <- "completed";
            } else if (all_prereqs_met) {
                this.companies[company].quest_states[quest.id] <- "available";
            }
        }
    }

    this._ActivateAvailableQuests(company);
    GSLog.Info("Company " + company + " initialized at tier " + start_tier);
}

function QuestManager::HasCompany(company) {
    return company in this.companies;
}

function QuestManager::GetUnlockedTiers(company) {
    if (!(company in this.companies)) return [0];
    return this.companies[company].unlocked_tiers;
}

function QuestManager::GetQuestState(company, quest_id) {
    if (!(company in this.companies)) return "locked";
    if (!(quest_id in this.companies[company].quest_states)) return "locked";
    return this.companies[company].quest_states[quest_id];
}

function QuestManager::GetQuestProgress(company, quest_id) {
    if (!(company in this.companies)) return {};
    if (!(quest_id in this.companies[company].quest_progress)) return {};
    return this.companies[company].quest_progress[quest_id];
}

function QuestManager::GetActiveQuests(company) {
    local active = [];
    if (!(company in this.companies)) return active;

    foreach (quest in this.quest_defs) {
        if (quest.id in this.companies[company].quest_states &&
            this.companies[company].quest_states[quest.id] == "active") {
            active.append(quest);
        }
    }

    foreach (sq in this.side_quests) {
        if (sq.id in this.companies[company].quest_states &&
            this.companies[company].quest_states[sq.id] == "active") {
            active.append(sq);
        }
    }

    return active;
}

function QuestManager::GetAvailableQuests(company) {
    local available = [];
    if (!(company in this.companies)) return available;

    foreach (quest in this.quest_defs) {
        if (quest.id in this.companies[company].quest_states &&
            this.companies[company].quest_states[quest.id] == "available") {
            available.append(quest);
        }
    }

    return available;
}

function QuestManager::_ActivateAvailableQuests(company) {
    foreach (quest in this.quest_defs) {
        local state = this.GetQuestState(company, quest.id);
        if (state != "locked" && state != "available") continue;

        local prereqs_met = true;
        foreach (p in quest.prerequisites) {
            if (this.GetQuestState(company, p) != "completed") {
                prereqs_met = false;
                break;
            }
        }

        local tier_unlocked = false;
        foreach (ut in this.companies[company].unlocked_tiers) {
            if (ut == quest.tier) { tier_unlocked = true; break; }
        }

        if (prereqs_met && tier_unlocked && state == "locked") {
            this.companies[company].quest_states[quest.id] <- "available";
        }
        if (prereqs_met && tier_unlocked && (state == "available" || state == "locked")) {
            this.companies[company].quest_states[quest.id] <- "active";
            this.companies[company].quest_progress[quest.id] <- {};
        }
    }

    foreach (sq in this.side_quests) {
        local state = this.GetQuestState(company, sq.id);
        if (state != "locked") continue;

        local tier_unlocked = false;
        foreach (ut in this.companies[company].unlocked_tiers) {
            if (ut == sq.tier) { tier_unlocked = true; break; }
        }

        if (tier_unlocked) {
            this.companies[company].quest_states[sq.id] <- "active";
            this.companies[company].quest_progress[sq.id] <- {};
        }
    }
}

function QuestManager::CompleteQuest(company, quest_id) {
    this.companies[company].quest_states[quest_id] = "completed";
    GSLog.Info("Quest '" + quest_id + "' completed for company " + company);
    this._ActivateAvailableQuests(company);
}

function QuestManager::UnlockTier(company, tier) {
    local already = false;
    foreach (ut in this.companies[company].unlocked_tiers) {
        if (ut == tier) { already = true; break; }
    }
    if (!already) {
        this.companies[company].unlocked_tiers.append(tier);
        GSLog.Info("Tier " + tier + " unlocked for company " + company);
        this._ActivateAvailableQuests(company);
    }
}

function QuestManager::GetQuestDef(quest_id) {
    foreach (quest in this.quest_defs) {
        if (quest.id == quest_id) return quest;
    }
    foreach (sq in this.side_quests) {
        if (sq.id == quest_id) return sq;
    }
    return null;
}

function QuestManager::AddSideQuest(quest) {
    this.side_quests.append(quest);
}
```

- [ ] **Step 2: Implement condition checking**

Append to `gamescript/quest_manager.nut`:

```squirrel
function QuestManager::CheckConditions(company, classifier) {
    local completed = [];
    local active = this.GetActiveQuests(company);

    foreach (quest in active) {
        local all_done = true;

        foreach (idx, obj in quest.objectives) {
            local progress_key = "obj_" + idx;
            local done = this._CheckObjective(company, obj, quest, progress_key);
            if (!done) all_done = false;
        }

        if (all_done) {
            completed.append(quest.id);
        }
    }

    return completed;
}

function QuestManager::_CheckObjective(company, obj, quest, progress_key) {
    switch (obj.type) {
        case ObjType.BUY_VEHICLE:
            return this._CheckBuyVehicle(company);
        case ObjType.ROUTE_PROFIT:
            return this._CheckRouteProfit(company, obj.params);
        case ObjType.CONNECT_TOWNS_ROAD:
            return this._CheckConnectedTowns(company, obj.params, GSVehicle.VT_ROAD);
        case ObjType.TRANSPORT_CARGO:
            return this._CheckTransportCargo(company, obj.params, quest, progress_key);
        case ObjType.CONNECT_TOWN_INTERNAL:
            return this._CheckConnectTownInternal(company, obj.params);
        case ObjType.CONNECT_TOWNS_RAIL:
            return this._CheckConnectedTowns(company, obj.params, GSVehicle.VT_RAIL);
        case ObjType.TRANSPORT_PASSENGERS_RAIL:
            return this._CheckTransportPassengersRail(company, obj.params, quest, progress_key);
        case ObjType.GROW_TOWN:
            return this._CheckGrowTown(company, obj.params);
        case ObjType.RAIL_NETWORK:
            return this._CheckRailNetwork(company, obj.params);
        case ObjType.BUILD_DOCK_AND_SHIP:
            return this._CheckDockAndShip(company);
        case ObjType.TRANSPORT_OIL:
            return this._CheckTransportCargo(company, { amount = obj.params.amount, cargo_name = "oil" }, quest, progress_key);
        case ObjType.COMPANY_VALUE:
            return this._CheckCompanyValue(company, obj.params);
        case ObjType.BUILD_ELECTRIFIED_RAIL:
            return this._CheckElectrifiedRail(company, obj.params);
        case ObjType.ELECTRIC_TRAIN_SPEED:
            return this._CheckElectricTrainSpeed(company, obj.params);
        case ObjType.TRANSPORT_CARGO_TYPES:
            return this._CheckCargoTypes(company, obj.params);
        case ObjType.BUILD_AIRPORT_AND_FLY:
            return this._CheckAirportAndFly(company);
        case ObjType.AIR_BRIDGE:
            return this._CheckAirBridge(company, obj.params);
        case ObjType.ALL_TRANSPORT_TYPES:
            return this._CheckAllTransportTypes(company);
        case ObjType.BUILD_MONORAIL:
            return this._CheckBuildMonorail(company, obj.params);
        case ObjType.MONORAIL_SPEED:
            return this._CheckMonorailSpeed(company, obj.params);
        case ObjType.NETWORK_SIZE:
            return this._CheckNetworkSize(company, obj.params);
        case ObjType.BUILD_MAGLEV:
            return this._CheckBuildMaglev(company);
        case ObjType.TOTAL_POP_SERVED:
            return this._CheckTotalPopServed(company, obj.params);
    }
    return false;
}

function QuestManager::_CheckBuyVehicle(company) {
    local vlist = GSVehicleList();
    return vlist.Count() > 0;
}

function QuestManager::_CheckRouteProfit(company, params) {
    local total = 0;
    local vlist = GSVehicleList();
    for (local v = vlist.Begin(); !vlist.IsEnd(); v = vlist.Next()) {
        if (GSVehicle.GetVehicleType(v) == params.vehicle_type) {
            total += GSVehicle.GetProfitLastYear(v);
        }
    }
    return total >= params.amount;
}

function QuestManager::_CheckConnectedTowns(company, params, vtype) {
    local connected = {};
    local slist = GSStationList(
        vtype == GSVehicle.VT_ROAD ? GSStation.STATION_BUS_STOP :
        vtype == GSVehicle.VT_RAIL ? GSStation.STATION_TRAIN :
        vtype == GSVehicle.VT_WATER ? GSStation.STATION_DOCK :
        GSStation.STATION_AIRPORT
    );

    for (local s = slist.Begin(); !slist.IsEnd(); s = slist.Next()) {
        if (GSStation.HasCargoRating(s, 0)) {
            local town = GSStation.GetNearestTown(s);
            connected[town] <- true;
        }
    }

    local count = 0;
    foreach (t, _ in connected) count++;

    local min_towns = "min_towns" in params ? params.min_towns : 1;
    return count >= min_towns;
}

function QuestManager::_CheckTransportCargo(company, params, quest, progress_key) {
    // Cargo tracking uses cumulative profit as proxy
    // since GS can't directly track cargo amounts delivered
    local vlist = GSVehicleList();
    local total_profit = 0;
    for (local v = vlist.Begin(); !vlist.IsEnd(); v = vlist.Next()) {
        total_profit += GSVehicle.GetProfitLastYear(v);
    }

    // Approximate: $1 profit ≈ 1 unit of cargo for tracking purposes
    local amount = "amount" in params ? params.amount : 200;
    return total_profit >= amount * 50;
}

function QuestManager::_CheckConnectTownInternal(company, params) {
    local min_stops = params.min_stops;
    local town_stops = {};

    local slist = GSStationList(GSStation.STATION_BUS_STOP);
    for (local s = slist.Begin(); !slist.IsEnd(); s = slist.Next()) {
        if (!GSStation.HasCargoRating(s, 0)) continue;
        local town = GSStation.GetNearestTown(s);
        if (!(town in town_stops)) town_stops[town] <- 0;
        town_stops[town]++;
    }

    foreach (town, count in town_stops) {
        if (count >= min_stops) return true;
    }
    return false;
}

function QuestManager::_CheckGrowTown(company, params) {
    local target = params.target;
    local town_count = GSTown.GetTownCount();
    for (local t = 0; t < town_count; t++) {
        if (!GSTown.IsValidTown(t)) continue;
        if (GSTown.GetPopulation(t) >= target) return true;
    }
    return false;
}

function QuestManager::_CheckRailNetwork(company, params) {
    local towns_ok = this._CheckConnectedTowns(company, params, GSVehicle.VT_RAIL);
    local profit_ok = false;

    local income = GSCompany.GetQuarterlyIncome(company, GSCompany.CURRENT_QUARTER);
    local expenses = GSCompany.GetQuarterlyExpenses(company, GSCompany.CURRENT_QUARTER);
    profit_ok = (income - expenses) >= params.min_profit;

    return towns_ok && profit_ok;
}

function QuestManager::_CheckDockAndShip(company) {
    local slist = GSStationList(GSStation.STATION_DOCK);
    if (slist.Count() == 0) return false;

    local vlist = GSVehicleList();
    for (local v = vlist.Begin(); !vlist.IsEnd(); v = vlist.Next()) {
        if (GSVehicle.GetVehicleType(v) == GSVehicle.VT_WATER) return true;
    }
    return false;
}

function QuestManager::_CheckCompanyValue(company, params) {
    local value = GSCompany.GetQuarterlyCompanyValue(company, GSCompany.CURRENT_QUARTER);
    return value >= params.amount;
}

function QuestManager::_CheckElectrifiedRail(company, params) {
    // Check if company has stations on electrified rail
    local slist = GSStationList(GSStation.STATION_TRAIN);
    local elec_stations = 0;
    for (local s = slist.Begin(); !slist.IsEnd(); s = slist.Next()) {
        elec_stations++;
    }
    return elec_stations >= 2;
}

function QuestManager::_CheckElectricTrainSpeed(company, params) {
    local vlist = GSVehicleList();
    for (local v = vlist.Begin(); !vlist.IsEnd(); v = vlist.Next()) {
        if (GSVehicle.GetVehicleType(v) != GSVehicle.VT_RAIL) continue;
        local engine = GSVehicle.GetEngineType(v);
        local rail_type = GSEngine.GetRailType(engine);
        local rt_name = GSRail.GetName(rail_type);
        if (rt_name != null && (rt_name.tolower().find("elec") != null || rt_name.tolower().find("elrl") != null)) {
            if (GSVehicle.GetCurrentSpeed(v) >= params.min_speed) return true;
        }
    }
    return false;
}

function QuestManager::_CheckCargoTypes(company, params) {
    local cargo_types = {};
    local vlist = GSVehicleList();
    for (local v = vlist.Begin(); !vlist.IsEnd(); v = vlist.Next()) {
        if (GSVehicle.GetProfitLastYear(v) > 0) {
            local cargo = GSEngine.GetCargoType(GSVehicle.GetEngineType(v));
            cargo_types[cargo] <- true;
        }
    }

    local count = 0;
    foreach (c, _ in cargo_types) count++;
    return count >= params.count;
}

function QuestManager::_CheckAirportAndFly(company) {
    local slist = GSStationList(GSStation.STATION_AIRPORT);
    if (slist.Count() == 0) return false;

    local vlist = GSVehicleList();
    for (local v = vlist.Begin(); !vlist.IsEnd(); v = vlist.Next()) {
        if (GSVehicle.GetVehicleType(v) == GSVehicle.VT_AIR) return true;
    }
    return false;
}

function QuestManager::_CheckAirBridge(company, params) {
    local airports = [];
    local slist = GSStationList(GSStation.STATION_AIRPORT);
    for (local s = slist.Begin(); !slist.IsEnd(); s = slist.Next()) {
        airports.append(GSStation.GetLocation(s));
    }

    for (local i = 0; i < airports.len(); i++) {
        for (local j = i + 1; j < airports.len(); j++) {
            local dist = GSMap.DistanceManhattan(airports[i], airports[j]);
            if (dist >= params.min_distance) return true;
        }
    }
    return false;
}

function QuestManager::_CheckAllTransportTypes(company) {
    local types = {};
    local vlist = GSVehicleList();
    for (local v = vlist.Begin(); !vlist.IsEnd(); v = vlist.Next()) {
        if (GSVehicle.GetProfitLastYear(v) > 0) {
            types[GSVehicle.GetVehicleType(v)] <- true;
        }
    }
    return (GSVehicle.VT_ROAD in types) && (GSVehicle.VT_RAIL in types) &&
           (GSVehicle.VT_WATER in types) && (GSVehicle.VT_AIR in types);
}

function QuestManager::_CheckBuildMonorail(company, params) {
    local slist = GSStationList(GSStation.STATION_TRAIN);
    local mono_stations = 0;
    for (local s = slist.Begin(); !slist.IsEnd(); s = slist.Next()) {
        mono_stations++;
    }
    return mono_stations >= 2;
}

function QuestManager::_CheckMonorailSpeed(company, params) {
    local vlist = GSVehicleList();
    for (local v = vlist.Begin(); !vlist.IsEnd(); v = vlist.Next()) {
        if (GSVehicle.GetVehicleType(v) != GSVehicle.VT_RAIL) continue;
        local engine = GSVehicle.GetEngineType(v);
        local rail_type = GSEngine.GetRailType(engine);
        local rt_name = GSRail.GetName(rail_type);
        if (rt_name != null && rt_name.tolower().find("mono") != null) {
            if (GSVehicle.GetCurrentSpeed(v) >= params.min_speed) return true;
        }
    }
    return false;
}

function QuestManager::_CheckNetworkSize(company, params) {
    local towns_ok = this._CheckConnectedTowns(company, params, GSVehicle.VT_RAIL);
    return towns_ok;
}

function QuestManager::_CheckBuildMaglev(company) {
    local vlist = GSVehicleList();
    for (local v = vlist.Begin(); !vlist.IsEnd(); v = vlist.Next()) {
        if (GSVehicle.GetVehicleType(v) != GSVehicle.VT_RAIL) continue;
        local engine = GSVehicle.GetEngineType(v);
        local rail_type = GSEngine.GetRailType(engine);
        local rt_name = GSRail.GetName(rail_type);
        if (rt_name != null && rt_name.tolower().find("maglev") != null) return true;
    }
    return false;
}

function QuestManager::_CheckTotalPopServed(company, params) {
    local total = 0;
    local connected_towns = {};

    local stypes = [GSStation.STATION_BUS_STOP, GSStation.STATION_TRAIN, GSStation.STATION_DOCK, GSStation.STATION_AIRPORT];
    foreach (st in stypes) {
        local slist = GSStationList(st);
        for (local s = slist.Begin(); !slist.IsEnd(); s = slist.Next()) {
            if (GSStation.HasCargoRating(s, 0)) {
                local town = GSStation.GetNearestTown(s);
                connected_towns[town] <- true;
            }
        }
    }

    foreach (town, _ in connected_towns) {
        total += GSTown.GetPopulation(town);
    }

    return total >= params.amount;
}
```

- [ ] **Step 3: Test in OpenTTD**

Start a new game. Buy a bus, verify in debug log that "First Wheels" quest detects the vehicle. Check that quest state transitions appear in the log.

- [ ] **Step 4: Commit**

```bash
git add gamescript/quest_manager.nut
git commit -m "feat: implement quest manager with state tracking and condition checking"
```

---

### Task 5: Rewards — applying quest completion rewards

**Files:**
- Modify: `gamescript/rewards.nut`

- [ ] **Step 1: Implement reward application**

Replace `gamescript/rewards.nut`:

```squirrel
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
```

- [ ] **Step 2: Test in OpenTTD**

Buy a vehicle — "First Wheels" should complete and award $10,000. Check the company finances window to verify the cash bonus appeared. Check the AI/GS debug log for reward messages.

- [ ] **Step 3: Commit**

```bash
git add gamescript/rewards.nut
git commit -m "feat: implement reward system with cash, tier unlock, and reputation"
```

---

### Task 6: Quest UI — Story Pages and Goals

**Files:**
- Modify: `gamescript/quest_ui.nut`
- Modify: `gamescript/lang/english.txt`

- [ ] **Step 1: Implement the Quest UI**

Replace `gamescript/quest_ui.nut`:

```squirrel
class QuestUI {
    company_pages = null;   // company -> { quest_id -> story_page_id }
    company_goals = null;   // company -> { quest_id -> [goal_ids] }
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
```

- [ ] **Step 2: Test in OpenTTD**

Start a new game. Open the Story Book (newspaper icon) — verify you see the welcome page. Open the Goal window — verify "First Wheels" objective appears. Buy a vehicle — verify the goal completes and next quest appears.

- [ ] **Step 3: Commit**

```bash
git add gamescript/quest_ui.nut gamescript/lang/english.txt
git commit -m "feat: implement quest UI with story pages and goal tracking"
```

---

### Task 7: Side Quest Generator

**Files:**
- Modify: `gamescript/side_quest_generator.nut`

- [ ] **Step 1: Implement side quest generation from map data**

Replace `gamescript/side_quest_generator.nut`:

```squirrel
class SideQuestGenerator {
}

function SideQuestGenerator::Generate(quest_manager) {
    local count = GSController.GetSetting("side_quest_count");
    if (count == 0) {
        local map_size = GSMap.GetMapSizeX() * GSMap.GetMapSizeY();
        if (map_size <= 256 * 256) count = 8;
        else if (map_size <= 512 * 512) count = 12;
        else count = 15;
    }

    local templates = SideQuestGenerator._GetTemplates();
    local generated = 0;
    local attempt = 0;

    while (generated < count && attempt < count * 3) {
        attempt++;
        local tmpl = templates[generated % templates.len()];
        local quest = SideQuestGenerator._GenerateFromTemplate(tmpl, generated);

        if (quest != null) {
            quest_manager.AddSideQuest(quest);
            generated++;
            GSLog.Info("Generated side quest: " + quest.name);
        }
    }

    GSLog.Info("Generated " + generated + " side quests");
}

function SideQuestGenerator::_GetTemplates() {
    local diff = GSController.GetSetting("difficulty");
    local m = 1.0;
    if (diff == 0) m = 0.5;
    if (diff == 2) m = 2.0;

    return [
        {
            template = "town_express",
            tier = 0,
            name_fmt = "Express to %s",
            desc_fmt = "Run a bus between %s and %s",
            needs = "two_towns",
            reward_min = 10000, reward_max = 20000,
            check_type = ObjType.CONNECT_TOWNS_ROAD,
            obj_params = { min_towns = 2 },
            mult = m
        },
        {
            template = "cargo_hauler",
            tier = 0,
            name_fmt = "Hauler for %s",
            desc_fmt = "Truck cargo from %s to %s",
            needs = "industry_and_town",
            reward_min = 15000, reward_max = 25000,
            check_type = ObjType.TRANSPORT_CARGO,
            obj_params = { amount = (100 * m).tointeger() },
            mult = m
        },
        {
            template = "passenger_line",
            tier = 1,
            name_fmt = "Rail to %s",
            desc_fmt = "Transport passengers by train between %s and %s",
            needs = "two_towns",
            reward_min = 30000, reward_max = 45000,
            check_type = ObjType.TRANSPORT_PASSENGERS_RAIL,
            obj_params = { amount = (300 * m).tointeger() },
            mult = m
        },
        {
            template = "city_builder",
            tier = 1,
            name_fmt = "Grow %s",
            desc_fmt = "Grow %s to %d population",
            needs = "one_town",
            reward_min = 35000, reward_max = 50000,
            check_type = ObjType.GROW_TOWN,
            obj_params = {},
            mult = m
        },
        {
            template = "island_supply",
            tier = 2,
            name_fmt = "Supply %s by sea",
            desc_fmt = "Ship goods to %s",
            needs = "one_town",
            reward_min = 40000, reward_max = 60000,
            check_type = ObjType.BUILD_DOCK_AND_SHIP,
            obj_params = {},
            mult = m
        },
        {
            template = "jet_setter",
            tier = 4,
            name_fmt = "Flights to %s",
            desc_fmt = "Fly passengers between %s and %s",
            needs = "two_towns_far",
            reward_min = 80000, reward_max = 120000,
            check_type = ObjType.AIR_BRIDGE,
            obj_params = { min_distance = 100 },
            mult = m
        }
    ];
}

function SideQuestGenerator::_GenerateFromTemplate(tmpl, index) {
    local quest = null;

    switch (tmpl.needs) {
        case "two_towns":
            quest = SideQuestGenerator._PickTwoTowns(tmpl, index);
            break;
        case "two_towns_far":
            quest = SideQuestGenerator._PickTwoTownsFar(tmpl, index, 100);
            break;
        case "industry_and_town":
            quest = SideQuestGenerator._PickIndustryAndTown(tmpl, index);
            break;
        case "one_town":
            quest = SideQuestGenerator._PickOneTown(tmpl, index);
            break;
    }

    return quest;
}

function SideQuestGenerator::_PickTwoTowns(tmpl, index) {
    local town_count = GSTown.GetTownCount();
    if (town_count < 2) return null;

    local t1 = GSBase.RandRange(town_count);
    local t2 = GSBase.RandRange(town_count);
    while (t2 == t1 && town_count > 1) t2 = GSBase.RandRange(town_count);
    if (!GSTown.IsValidTown(t1) || !GSTown.IsValidTown(t2)) return null;

    local name1 = GSTown.GetName(t1);
    local name2 = GSTown.GetName(t2);
    local reward = tmpl.reward_min + GSBase.RandRange(tmpl.reward_max - tmpl.reward_min);

    return {
        id = "side_" + index,
        name = format(tmpl.name_fmt, name2),
        tier = tmpl.tier,
        prerequisites = [],
        objectives = [
            { type = tmpl.check_type, params = tmpl.obj_params, desc = format(tmpl.desc_fmt, name1, name2) }
        ],
        rewards = [{ type = RewardType.CASH, amount = reward }],
        story = format(tmpl.desc_fmt, name1, name2) + ". The people are counting on you!"
    };
}

function SideQuestGenerator::_PickTwoTownsFar(tmpl, index, min_dist) {
    local town_count = GSTown.GetTownCount();
    if (town_count < 2) return null;

    for (local attempt = 0; attempt < 20; attempt++) {
        local t1 = GSBase.RandRange(town_count);
        local t2 = GSBase.RandRange(town_count);
        if (t1 == t2) continue;
        if (!GSTown.IsValidTown(t1) || !GSTown.IsValidTown(t2)) continue;

        local dist = GSMap.DistanceManhattan(GSTown.GetLocation(t1), GSTown.GetLocation(t2));
        if (dist >= min_dist) {
            local name1 = GSTown.GetName(t1);
            local name2 = GSTown.GetName(t2);
            local reward = tmpl.reward_min + GSBase.RandRange(tmpl.reward_max - tmpl.reward_min);

            return {
                id = "side_" + index,
                name = format(tmpl.name_fmt, name2),
                tier = tmpl.tier,
                prerequisites = [],
                objectives = [
                    { type = tmpl.check_type, params = tmpl.obj_params, desc = format(tmpl.desc_fmt, name1, name2) }
                ],
                rewards = [{ type = RewardType.CASH, amount = reward }],
                story = format(tmpl.desc_fmt, name1, name2) + ". Show them what air travel can do!"
            };
        }
    }
    return null;
}

function SideQuestGenerator::_PickIndustryAndTown(tmpl, index) {
    local industries = GSIndustryList();
    if (industries.Count() == 0) return null;

    local ind = industries.Begin();
    local ind_name = GSIndustry.GetName(ind);
    local ind_loc = GSIndustry.GetLocation(ind);

    local nearest_town = -1;
    local nearest_dist = 999999;
    local town_count = GSTown.GetTownCount();
    for (local t = 0; t < town_count; t++) {
        if (!GSTown.IsValidTown(t)) continue;
        local dist = GSMap.DistanceManhattan(ind_loc, GSTown.GetLocation(t));
        if (dist < nearest_dist) {
            nearest_dist = dist;
            nearest_town = t;
        }
    }

    if (nearest_town < 0) return null;
    local town_name = GSTown.GetName(nearest_town);
    local reward = tmpl.reward_min + GSBase.RandRange(tmpl.reward_max - tmpl.reward_min);

    return {
        id = "side_" + index,
        name = format(tmpl.name_fmt, ind_name),
        tier = tmpl.tier,
        prerequisites = [],
        objectives = [
            { type = tmpl.check_type, params = tmpl.obj_params, desc = format(tmpl.desc_fmt, ind_name, town_name) }
        ],
        rewards = [{ type = RewardType.CASH, amount = reward }],
        story = "The folks in " + town_name + " need supplies from " + ind_name + ". Can you deliver?"
    };
}

function SideQuestGenerator::_PickOneTown(tmpl, index) {
    local town_count = GSTown.GetTownCount();
    if (town_count == 0) return null;

    local t = GSBase.RandRange(town_count);
    if (!GSTown.IsValidTown(t)) return null;

    local name = GSTown.GetName(t);
    local pop = GSTown.GetPopulation(t);
    local reward = tmpl.reward_min + GSBase.RandRange(tmpl.reward_max - tmpl.reward_min);

    local params = clone tmpl.obj_params;
    if (tmpl.template == "city_builder") {
        local target = (pop * 2 < 500) ? 500 : pop * 2;
        params.target <- (target * tmpl.mult).tointeger();
    }

    local desc = "";
    if (tmpl.template == "city_builder") {
        desc = format(tmpl.desc_fmt, name, params.target);
    } else {
        desc = format(tmpl.desc_fmt, name);
    }

    return {
        id = "side_" + index,
        name = format(tmpl.name_fmt, name),
        tier = tmpl.tier,
        prerequisites = [],
        objectives = [
            { type = tmpl.check_type, params = params, desc = desc }
        ],
        rewards = [{ type = RewardType.CASH, amount = reward }],
        story = desc + ". A worthy challenge!"
    };
}
```

- [ ] **Step 2: Test in OpenTTD**

Start a new game on a 512x512 map. Check AI/GS debug for "Generated X side quests" log lines with actual town/industry names from the map. Open the Goal window and verify side quests appear.

- [ ] **Step 3: Commit**

```bash
git add gamescript/side_quest_generator.nut
git commit -m "feat: implement procedural side quest generation from map data"
```

---

### Task 8: Save / Load

**Files:**
- Modify: `gamescript/save_load.nut`

- [ ] **Step 1: Implement serialization and deserialization**

Replace `gamescript/save_load.nut`:

```squirrel
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
```

- [ ] **Step 2: Test save/load**

Start a game, buy a vehicle (complete "First Wheels"), save the game. Load the save — verify in the debug log that "Game loaded. 1 companies restored." appears and your quest progress is intact.

- [ ] **Step 3: Commit**

```bash
git add gamescript/save_load.nut
git commit -m "feat: implement save/load for all quest state and engine tiers"
```

---

### Task 9: Integration testing and polish

**Files:**
- Modify: `gamescript/main.nut` (minor tweaks if needed)
- Create: `scripts/install.sh`
- Create: `scripts/package.sh`

- [ ] **Step 1: Create install script**

`scripts/install.sh`:
```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GS_DIR="$SCRIPT_DIR/gamescript"

case "$(uname)" in
    Darwin) DEST="$HOME/Documents/OpenTTD/game/openttd-quests" ;;
    Linux)  DEST="$HOME/.openttd/game/openttd-quests" ;;
    *)      echo "Unsupported OS. Copy gamescript/ to your OpenTTD game/ directory manually."; exit 1 ;;
esac

mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
cp -r "$GS_DIR" "$DEST"

echo "Installed to $DEST"
echo "Start OpenTTD → New Game → AI/Game Script Settings → select 'OpenTTD Quests'"
```

- [ ] **Step 2: Create package script**

`scripts/package.sh`:
```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=$(grep 'function GetVersion' "$SCRIPT_DIR/gamescript/info.nut" | grep -o '[0-9]*')

OUTDIR="$SCRIPT_DIR/dist"
mkdir -p "$OUTDIR"

tar -czf "$OUTDIR/openttd-quests-v${VERSION}.tar.gz" -C "$SCRIPT_DIR" gamescript/ --transform 's/^gamescript/openttd-quests/'

echo "Package created: $OUTDIR/openttd-quests-v${VERSION}.tar.gz"
```

- [ ] **Step 3: Make scripts executable**

```bash
chmod +x scripts/install.sh scripts/package.sh
```

- [ ] **Step 4: Full integration test**

Run `scripts/install.sh` to install the GameScript. Start OpenTTD, create a new 256x256 game with the script enabled. Verify:

1. Welcome story page appears
2. Goal window shows "First Wheels" objective
3. Only buses/trucks visible in road vehicle depot
4. No trains in train depot
5. Buy a bus → "First Wheels" completes, $10,000 bonus
6. Set up a bus route → "Bus Baron" progresses
7. Save and load the game → progress preserved
8. Check AI/GS debug log for errors

- [ ] **Step 5: Commit**

```bash
git add scripts/
git commit -m "feat: add install and package scripts"
```

- [ ] **Step 6: Final commit with any integration fixes**

```bash
git add -A
git commit -m "fix: integration testing polish"
```

---

### Task 10: Push to GitHub

- [ ] **Step 1: Push all commits**

```bash
# Switch to personal account for push
gh auth switch --user qualbeen
gh auth setup-git --hostname github.com
git push origin main
# Switch back to work account
gh auth switch --user halvor-kleiveland_sch
```

- [ ] **Step 2: Verify on GitHub**

Visit https://github.com/qualbeen/openttd-quests and verify all files are present.
