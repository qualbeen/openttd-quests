#!/usr/bin/env python3
"""Generate Squirrel quest definition files from YAML sources.

Reads quests/progression/*.yaml and quests/side-quests/*.yaml,
validates them, and generates:
  - gamescript/quest_defs.nut (enums + progression quests)
  - gamescript/side_quest_templates.nut (side quest template data)
"""

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install it with: pip install pyyaml")
    sys.exit(1)

PROJECT_ROOT = Path(__file__).parent.parent

OBJECTIVE_TYPES = [
    "buy_vehicle", "route_profit", "connect_towns_road", "transport_cargo",
    "connect_town_internal", "connect_towns_rail", "transport_passengers_rail",
    "grow_town", "rail_network", "build_dock_and_ship", "transport_oil",
    "company_value", "build_electrified_rail", "electric_train_speed",
    "transport_cargo_types", "build_airport_and_fly", "air_bridge",
    "all_transport_types", "build_monorail", "monorail_speed", "network_size",
    "build_maglev", "total_pop_served",
]

REWARD_TYPES = ["cash", "unlock_tier", "reputation", "victory"]

VEHICLE_TYPE_MAP = {
    "road": "GSVehicle.VT_ROAD",
    "rail": "GSVehicle.VT_RAIL",
    "water": "GSVehicle.VT_WATER",
    "air": "GSVehicle.VT_AIR",
}

FIXED_PARAMS = {
    "min_towns", "min_stops", "count", "min_speed", "min_distance",
    "vehicle_type", "min_tiles",
}

SCALED_PARAMS = {
    "amount", "target", "min_passengers", "min_profit",
}

SIDE_QUEST_NEEDS = {
    "two_towns", "two_towns_far", "industry_and_town", "one_town",
}


def load_progression_quests():
    quests = []
    quest_dir = PROJECT_ROOT / "quests" / "progression"
    for yaml_file in sorted(quest_dir.glob("tier-*.yaml")):
        with open(yaml_file) as f:
            data = yaml.safe_load(f)
        if data and "quests" in data:
            quests.extend(data["quests"])
    return quests


def load_side_quest_templates():
    templates = []
    tmpl_dir = PROJECT_ROOT / "quests" / "side-quests"
    for yaml_file in sorted(tmpl_dir.glob("*.yaml")):
        with open(yaml_file) as f:
            data = yaml.safe_load(f)
        if data:
            templates.append(data)
    return templates


def validate_quests(quests):
    errors = []
    quest_ids = {q["id"] for q in quests}

    for quest in quests:
        qid = quest.get("id", "<missing>")

        if "id" not in quest:
            errors.append(f"Quest missing 'id' field")
            continue
        if "name" not in quest:
            errors.append(f"{qid}: missing 'name'")
        if "tier" not in quest:
            errors.append(f"{qid}: missing 'tier'")
        if "objectives" not in quest or not quest["objectives"]:
            errors.append(f"{qid}: missing or empty 'objectives'")
            continue
        if "rewards" not in quest or not quest["rewards"]:
            errors.append(f"{qid}: missing or empty 'rewards'")
        if "story" not in quest:
            errors.append(f"{qid}: missing 'story'")

        for prereq in quest.get("prerequisites", []):
            if prereq not in quest_ids:
                errors.append(f"{qid}: prerequisite '{prereq}' not found")

        for obj in quest.get("objectives", []):
            obj_type = obj.get("type", "")
            if obj_type not in OBJECTIVE_TYPES:
                errors.append(f"{qid}: unknown objective type '{obj_type}'")
            if "desc" not in obj:
                errors.append(f"{qid}: objective missing 'desc'")

        for reward in quest.get("rewards", []):
            rtype = reward.get("type", "")
            if rtype not in REWARD_TYPES:
                errors.append(f"{qid}: unknown reward type '{rtype}'")

    if errors:
        for err in errors:
            print(f"  ERROR: {err}", file=sys.stderr)
    return errors


def validate_templates(templates):
    errors = []
    for tmpl in templates:
        name = tmpl.get("template", "<missing>")
        if "template" not in tmpl:
            errors.append("Template missing 'template' field")
        if "tier" not in tmpl:
            errors.append(f"{name}: missing 'tier'")
        if "needs" not in tmpl:
            errors.append(f"{name}: missing 'needs'")
        elif tmpl["needs"] not in SIDE_QUEST_NEEDS:
            errors.append(f"{name}: unknown needs '{tmpl['needs']}'")
        obj_type = tmpl.get("objective_type", "")
        if obj_type and obj_type not in OBJECTIVE_TYPES:
            errors.append(f"{name}: unknown objective_type '{obj_type}'")

    if errors:
        for err in errors:
            print(f"  ERROR: {err}", file=sys.stderr)
    return errors


def is_scaled(param_name, param_value):
    if isinstance(param_value, dict):
        return param_value.get("scaled", False)
    if param_name in SCALED_PARAMS:
        return True
    if param_name in FIXED_PARAMS:
        return False
    if isinstance(param_value, str):
        return False
    return False


def get_param_raw_value(param_value):
    if isinstance(param_value, dict):
        return param_value["value"]
    return param_value


def format_param(name, value):
    raw = get_param_raw_value(value)
    if name == "vehicle_type" and isinstance(raw, str):
        return VEHICLE_TYPE_MAP.get(raw, raw)
    scaled = is_scaled(name, value)
    if scaled and isinstance(raw, (int, float)):
        return f"({raw} * mult).tointeger()"
    return str(raw)


def get_scaled_value_expr(name, value):
    raw = get_param_raw_value(value)
    if is_scaled(name, value) and isinstance(raw, (int, float)):
        return f'({raw} * mult).tointeger()'
    return str(raw)


def interpolate_string(template, params, all_objectives=None):
    """Replace {param_name} or {N.param_name} placeholders with Squirrel expressions."""
    parts = []
    last_end = 0

    for match in re.finditer(r'\{(\d+\.)?(\w+)\}', template):
        start, end = match.span()
        if start > last_end:
            parts.append(('literal', template[last_end:start]))

        idx_str = match.group(1)
        param_name = match.group(2)

        if idx_str is not None:
            obj_idx = int(idx_str.rstrip('.'))
            if all_objectives and obj_idx < len(all_objectives):
                obj_params = all_objectives[obj_idx].get("params", {})
                if param_name in obj_params:
                    expr = get_scaled_value_expr(param_name, obj_params[param_name])
                    parts.append(('expr', expr))
                else:
                    parts.append(('literal', match.group(0)))
            else:
                parts.append(('literal', match.group(0)))
        else:
            if params and param_name in params:
                expr = get_scaled_value_expr(param_name, params[param_name])
                parts.append(('expr', expr))
            elif all_objectives:
                found = False
                for obj in all_objectives:
                    obj_params = obj.get("params", {})
                    if param_name in obj_params:
                        expr = get_scaled_value_expr(param_name, obj_params[param_name])
                        parts.append(('expr', expr))
                        found = True
                        break
                if not found:
                    parts.append(('literal', match.group(0)))
            else:
                parts.append(('literal', match.group(0)))

        last_end = end

    if last_end < len(template):
        parts.append(('literal', template[last_end:]))

    has_expr = any(t == 'expr' for t, _ in parts)
    if not has_expr:
        full_text = ''.join(v for _, v in parts)
        return f'"{_escape(full_text)}"'

    merged = _merge_adjacent_literals(parts)
    result_parts = []
    for idx, (ptype, value) in enumerate(merged):
        if ptype == 'literal' and value:
            escaped = _escape_nontrim(value)
            if idx == len(merged) - 1:
                escaped = escaped.rstrip()
            if escaped:
                result_parts.append(f'"{escaped}"')
        elif ptype == 'expr':
            result_parts.append(value)

    return ' + '.join(result_parts)


def _escape(s):
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ').strip()


def _escape_nontrim(s):
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ')


def _merge_adjacent_literals(parts):
    merged = []
    for ptype, value in parts:
        if ptype == 'literal' and merged and merged[-1][0] == 'literal':
            merged[-1] = ('literal', merged[-1][1] + value)
        else:
            merged.append((ptype, value))
    return merged


def generate_quest_defs(quests):
    lines = []
    lines.append("// AUTO-GENERATED from quests/progression/*.yaml")
    lines.append("// Do not edit manually — run: python3 scripts/generate_quest_defs.py")
    lines.append("")

    lines.append("enum ObjType {")
    for i, obj_type in enumerate(OBJECTIVE_TYPES):
        comma = "," if i < len(OBJECTIVE_TYPES) - 1 else ""
        lines.append(f"    {obj_type.upper()}{comma}")
    lines.append("}")
    lines.append("")

    lines.append("enum RewardType {")
    for i, rtype in enumerate(REWARD_TYPES):
        comma = "," if i < len(REWARD_TYPES) - 1 else ""
        lines.append(f"    {rtype.upper()}{comma}")
    lines.append("}")
    lines.append("")

    lines.append("class QuestDefs {")
    lines.append("    static function GetAll(difficulty_mult) {")
    lines.append("        local mult = difficulty_mult;")
    lines.append("")
    lines.append("        return [")

    current_tier = -1
    for i, quest in enumerate(quests):
        tier = quest["tier"]
        if tier != current_tier:
            tier_quests = [q for q in quests if q["tier"] == tier]
            lines.append(f"            // ========== TIER {tier} ({len(tier_quests)} quests) ==========")
            lines.append("")
            current_tier = tier

        lines.append("            {")
        lines.append(f'                id = "{quest["id"]}",')
        lines.append(f'                name = "{_escape(quest["name"])}",')
        lines.append(f'                tier = {quest["tier"]},')

        prereqs = quest.get("prerequisites", [])
        if prereqs:
            prereq_strs = ', '.join(f'"{p}"' for p in prereqs)
            lines.append(f'                prerequisites = [{prereq_strs}],')
        else:
            lines.append('                prerequisites = [],')

        lines.append('                objectives = [')
        for obj in quest["objectives"]:
            lines.append('                    {')
            lines.append(f'                        type = ObjType.{obj["type"].upper()},')

            params = obj.get("params", {})
            if params:
                param_strs = []
                for pname, pvalue in params.items():
                    param_strs.append(f"{pname} = {format_param(pname, pvalue)}")
                lines.append(f'                        params = {{ {", ".join(param_strs)} }},')
            else:
                lines.append('                        params = {},')

            desc_str = interpolate_string(obj["desc"], params)
            lines.append(f'                        desc = {desc_str}')
            lines.append('                    }' + (',' if obj != quest["objectives"][-1] else ''))

        lines.append('                ],')

        lines.append('                rewards = [')
        for reward in quest["rewards"]:
            reward_parts = [f'type = RewardType.{reward["type"].upper()}']
            if reward["type"] == "cash":
                amt = reward["amount"]
                reward_parts.append(f"amount = ({amt} * mult).tointeger()")
            elif reward["type"] == "unlock_tier":
                reward_parts.append(f'tier = {reward["tier"]}')
            elif reward["type"] == "reputation":
                reward_parts.append(f'amount = {reward["amount"]}')
            reward_str = ', '.join(reward_parts)
            comma = ',' if reward != quest["rewards"][-1] else ''
            lines.append(f'                    {{ {reward_str} }}{comma}')
        lines.append('                ],')

        story_str = interpolate_string(quest["story"], None, quest["objectives"])
        lines.append(f'                story = {story_str}')

        comma = ',' if i < len(quests) - 1 else ''
        lines.append(f'            }}{comma}')
        lines.append('')

    lines.append("        ];")
    lines.append("    }")
    lines.append("}")
    lines.append("")

    return '\n'.join(lines)


def generate_side_quest_templates(templates):
    lines = []
    lines.append("// AUTO-GENERATED from quests/side-quests/*.yaml")
    lines.append("// Do not edit manually — run: python3 scripts/generate_quest_defs.py")
    lines.append("")
    lines.append("class SideQuestTemplates {")
    lines.append("    static function GetAll(multiplier) {")
    lines.append("        return [")

    for i, tmpl in enumerate(templates):
        lines.append("            {")
        lines.append(f'                template = "{tmpl["template"]}",')
        lines.append(f'                tier = {tmpl["tier"]},')
        lines.append(f'                name_fmt = "{_escape(tmpl["name_fmt"])}",')
        lines.append(f'                desc_fmt = "{_escape(tmpl["desc_fmt"])}",')
        lines.append(f'                needs = "{tmpl["needs"]}",')

        if tmpl.get("picker_params"):
            pp_strs = []
            for k, v in tmpl["picker_params"].items():
                pp_strs.append(f"{k} = {v}")
            lines.append(f'                picker_params = {{ {", ".join(pp_strs)} }},')

        obj_type = tmpl.get("objective_type", "")
        lines.append(f'                check_type = ObjType.{obj_type.upper()},')

        obj_params = tmpl.get("objective_params", {})
        if obj_params:
            op_strs = []
            for k, v in obj_params.items():
                if k == "amount":
                    op_strs.append(f"{k} = ({v} * multiplier).tointeger()")
                else:
                    op_strs.append(f"{k} = {v}")
            lines.append(f'                obj_params = {{ {", ".join(op_strs)} }},')
        else:
            lines.append('                obj_params = {},')

        rr = tmpl.get("reward_range", {})
        lines.append(f'                reward_min = {rr.get("min", 10000)}, reward_max = {rr.get("max", 20000)},')
        lines.append(f'                mult = multiplier')

        comma = ',' if i < len(templates) - 1 else ''
        lines.append(f'            }}{comma}')

    lines.append("        ];")
    lines.append("    }")
    lines.append("}")
    lines.append("")

    return '\n'.join(lines)


def main():
    print("Loading progression quests...")
    quests = load_progression_quests()
    print(f"  Found {len(quests)} quests")

    print("Loading side quest templates...")
    templates = load_side_quest_templates()
    print(f"  Found {len(templates)} templates")

    print("Validating...")
    quest_errors = validate_quests(quests)
    template_errors = validate_templates(templates)

    if quest_errors or template_errors:
        print(f"\nValidation failed with {len(quest_errors) + len(template_errors)} error(s)")
        sys.exit(1)

    print("Generating gamescript/quest_defs.nut...")
    quest_defs_output = generate_quest_defs(quests)
    output_path = PROJECT_ROOT / "gamescript" / "quest_defs.nut"
    output_path.write_text(quest_defs_output)

    print("Generating gamescript/side_quest_templates.nut...")
    templates_output = generate_side_quest_templates(templates)
    templates_path = PROJECT_ROOT / "gamescript" / "side_quest_templates.nut"
    templates_path.write_text(templates_output)

    print("Done!")


if __name__ == "__main__":
    main()
