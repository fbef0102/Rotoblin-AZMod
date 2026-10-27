#!/usr/bin/env python3
"""
================================================================================
l4d2_nut_to_l4d1_stripper.py - VScript to Stripper:Source Converter
================================================================================
Description:
    Converts Left 4 Dead 2 VScript map fix files (.nut) into Stripper:Source (.cfg) format for Left 4 Dead 1.
    Fully implements original VScript logic for make_ladder, find_ladder, and clone_model
    by parsing the source map's BSP (Lump 0 & Lump 14).
    Prepends "anv_mapfixes" to targetnames only when g_UpdateName + is used in EntFire,
    automatically generates missing team filters, places filters and logic_auto at the bottom,
    combines logic_auto outputs with empty lines between different targetnames, comments out
    unresolved ladders, supports con_comment with escape character translation (\t and \n),
    and converts EntFire into logic_auto OnMapSpawn outputs.

Usage:
    python l4d2_nut_to_l4d1_stripper.py <input_file.nut> <output_file.cfg> <map.bsp>
================================================================================
"""

import sys
import os
import re
import csv
import struct
from bspinfo import lumps, lump, ents

# ============================================================================
# BSP Parser helpers for find_ladder, clone_model, and filter emulation
# ============================================================================
def parse_bsp_data(bsp_path):
    """Parse Lump 0 and Lump 14 of BSP to build ladder database and find team filters."""
    ladders_db = []
    filters_db = []
    
    if not bsp_path or not os.path.exists(bsp_path):
        return ladders_db, filters_db

    try:
        with open(bsp_path, "rb") as f:
            bsp_data = f.read()

        # Parse Lump header (64 lumps)
        ver, lump_table = lumps(bsp_data)

        # Lump 14: Models
        models_data = lump(bsp_data, lump_table, 14)
        parsed_models = []
        struct_size = 48
        for i in range(0, len(models_data), struct_size):
            m_bytes = models_data[i:i+struct_size]
            if len(m_bytes) < struct_size:
                break
            mins_x, mins_y, mins_z, maxs_x, maxs_y, maxs_z, org_x, org_y, org_z = struct.unpack('<9f', m_bytes[:36])
            parsed_models.append({
                "mins": (mins_x, mins_y, mins_z),
                "maxs": (maxs_x, maxs_y, maxs_z),
                "origin": (org_x, org_y, org_z)
            })

        # Lump 0: Entities
        all_entities = ents(bsp_data, lump_table)
        for kv, _ in all_entities:
            classname = kv.get("classname", "")
            
            if classname == "func_simpleladder":
                model_str = kv.get("model", "")
                orig_str = kv.get("origin", "0 0 0")
                org_parts = [float(x) for x in orig_str.split()]
                ent_org = (org_parts[0], org_parts[1], org_parts[2]) if len(org_parts) == 3 else (0.0, 0.0, 0.0)

                # Calculate VSSM (Surrounding Maxs center point)
                vssm = ent_org
                if model_str.startswith("*"):
                    try:
                        midx = int(model_str[1:])
                        if midx < len(parsed_models):
                            m = parsed_models[midx]
                            mins, maxs, m_org = m["mins"], m["maxs"], m["origin"]
                            vx = (maxs[0] - ((maxs[0] - mins[0]) / 2)) + m_org[0] + ent_org[0]
                            vy = (maxs[1] - ((maxs[1] - mins[1]) / 2)) + m_org[1] + ent_org[1]
                            vz = (maxs[2] - ((maxs[2] - mins[2]) / 2)) + m_org[2] + ent_org[2]
                            vssm = (vx, vy, vz)
                    except ValueError:
                        pass

                nx = kv.get("normal.x")
                ny = kv.get("normal.y")
                nz = kv.get("normal.z")
                if nx and ny and nz:
                    normal_str = f"{nx} {ny} {nz}"
                else:
                    normal_str = kv.get("normal", "0 1 0")

                ladders_db.append({
                    "vssm": vssm,
                    "model": model_str,
                    "normal": normal_str
                })
            
            elif classname == "filter_activator_team":
                filters_db.append({
                    "targetname": kv.get("targetname", ""),
                    "filterteam": kv.get("filterteam", ""),
                    "classname": classname
                })
                
    except Exception as e:
        print(f"Warning: Failed to parse BSP data: {e}")

    return ladders_db, filters_db

def find_ladder_in_db(desired_vssm_str, radius, ladders_db):
    """Emulate original VScript find_ladder logic."""
    try:
        parts = [float(x) for x in desired_vssm_str.split()]
        if len(parts) != 3:
            return None
        target_vssm = parts
        r_sqr = radius * radius

        for ladder in ladders_db:
            vx, vy, vz = ladder["vssm"]
            dx = target_vssm[0] - vx
            dy = target_vssm[1] - vy
            dz = target_vssm[2] - vz
            dist_sqr = dx*dx + dy*dy + dz*dz
            if dist_sqr < r_sqr:
                return ladder
    except Exception:
        pass
    return None

def find_filter_in_db(target_team, filters_db):
    """Find matching filter_activator_team targetname based on team."""
    for f in filters_db:
        if f["filterteam"] == target_team and f["classname"] == "filter_activator_team":
            return f["targetname"]
    return ""

def calculate_filter_origin(entity_origin_str):
    """Calculate filter origin based on entity origin with Z + 100."""
    try:
        parts = [float(x) for x in entity_origin_str.split()]
        if len(parts) == 3:
            return f"{parts[0]} {parts[1]} {parts[2] + 100}"
    except Exception:
        pass
    return "0 0 100"

def comment_out_block(block_str):
    """Comment out an entire block line by line using ;."""
    return "\n".join([f"; {line}" if line.strip() else ";" for line in block_str.splitlines()])

# ============================================================================
# Argument & Statement Parsers
# ============================================================================
def parse_vscript_args(args_str):
    try:
        reader = csv.reader([args_str], skipinitialspace=True)
        for row in reader:
            return [r.strip('" \t') for r in row]
    except Exception:
        return []
    return []

# Global databases & tracking for missing filters
GLOBAL_LADDERS_DB = []
GLOBAL_FILTERS_DB = []
GENERATED_FILTERS = set()

def convert_statement_to_stripper(statement):
    """
    Returns tuple: (func_comment, entity_block, logic_auto_outputs, extra_add_blocks)
    """
    statement = statement.strip()
    if not statement or statement.startswith("//"):
        return None, None, [], []

    # 0a. con_comment
    m = re.match(r'con_comment\s*\((.*?)\)\s*;?', statement, re.DOTALL)
    if m:
        raw_arg = m.group(1).strip()
        if (raw_arg.startswith('"') and raw_arg.endswith('"')) or (raw_arg.startswith("'") and raw_arg.endswith("'")):
            comment_text = raw_arg[1:-1]
        else:
            comment_text = raw_arg
        
        comment_text = comment_text.replace(r'\t', '\t').replace(r'\n', '\n')
        
        comment_lines = []
        for line in comment_text.splitlines():
            comment_lines.append(f"; {line}")
        
        block = "\n".join(comment_lines)
        return None, block, [], []

    # 0b. EntFire
    m = re.match(r'EntFire\s*\((.*?)\)\s*;?', statement, re.DOTALL)
    if m:
        raw_args_str = m.group(1)
        args = parse_vscript_args(raw_args_str)
        if len(args) >= 2:
            raw_target_arg = args[0]
            action = args[1]
            value = args[2] if len(args) > 2 and args[2] and args[2] != "null" else ""
            delay = args[3] if len(args) > 3 and args[3] and args[3] != "null" else "0"

            # Check if args[0] contains g_UpdateName +
            gm = re.search(r'g_UpdateName\s*\+\s*["\']?(.*?)["\']?$', raw_target_arg)
            if gm:
                sub_name = gm.group(1).strip('"\'')
                target = f"anv_mapfixes{sub_name}"
            else:
                gm2 = re.search(r'g_UpdateName\s*\+\s*["\']([^"\']+)["\']', raw_target_arg)
                if gm2:
                    sub_name = gm2.group(1)
                    target = f"anv_mapfixes{sub_name}"
                else:
                    target = raw_target_arg.strip('"\'')

            output_line = f'"OnMapSpawn" "{target},{action},{value},{delay},-1"'
            return "; EntFire", None, [output_line], []

    # 1. make_clip
    m = re.match(r'make_clip\s*\((.*?)\)\s*;?', statement, re.DOTALL)
    if m:
        args = parse_vscript_args(m.group(1))
        if len(args) >= 6:
            targetname, blocktype, initialstate, mins, maxs, origin = args[:6]
            targetname = f"anv_mapfixes{targetname}"
            angles = args[6] if len(args) > 6 and args[6] else "0 0 0"
            blocktype_map = {
                "Everyone": "0", "Survivors": "1", "SI Players": "2",
                "SI Players and AI": "3", "All and Physics": "4"
            }
            block_int = blocktype_map.get(blocktype, blocktype)
            angles_line = f'\n    "angles" "{angles}"' if angles != "0 0 0" else ""
            block = f"""{{
    "targetname" "{targetname}"
    "classname" "env_player_blocker"
    "origin" "{origin}"{angles_line}
    "mins" "{mins}"
    "maxs" "{maxs}"
    "initialstate" "{initialstate}"
    "BlockType" "{block_int}"
}}"""
            return "; make_clip", block, [], []

    # 2. make_brush
    m = re.match(r'make_brush\s*\((.*?)\)\s*;?', statement, re.DOTALL)
    if m:
        args = parse_vscript_args(m.group(1))
        if len(args) >= 4:
            targetname, mins, maxs, origin = args[:4]
            targetname = f"anv_mapfixes{targetname}"
            block = f"""{{
    "targetname" "{targetname}"
    "classname" "func_brush"
    "StartDisabled" "1"
    "origin" "{origin}"
}}"""
            outputs = [
                f'"OnMapSpawn" "{targetname},AddOutput,mins {mins},0,-1"',
                f'"OnMapSpawn" "{targetname},AddOutput,maxs {maxs},0,-1"',
                f'"OnMapSpawn" "{targetname},AddOutput,solid 2,0,-1"',
                f'"OnMapSpawn" "{targetname},Enable,,0.1,-1"'
            ]
            return "; make_brush", block, outputs, []

    # 3. make_navblock
    m = re.match(r'make_navblock\s*\((.*?)\)\s*;?', statement, re.DOTALL)
    if m:
        args = parse_vscript_args(m.group(1))
        if len(args) >= 6:
            targetname, teamblock, state, mins, maxs, origin = args[:6]
            targetname = f"anv_mapfixes{targetname}"
            team_map = {"Everyone": "-1", "Survivors": "2", "Infected": "3"}
            team_int = team_map.get(teamblock, teamblock)
            action = "BlockNav" if state == "Apply" else "UnblockNav" if state == "Remove" else ""
            block = f"""{{
    "targetname" "{targetname}"
    "classname" "func_nav_blocker"
    "origin" "{origin}"
    "teamToBlock" "{team_int}"
}}"""
            outputs = [
                f'"OnMapSpawn" "{targetname},AddOutput,mins {mins},0,-1"',
                f'"OnMapSpawn" "{targetname},AddOutput,maxs {maxs},0,-1"',
                f'"OnMapSpawn" "{targetname},AddOutput,solid 2,0,-1"'
            ]
            if action:
                outputs.append(f'"OnMapSpawn" "{targetname},{action},,1,-1"')
            return "; make_navblock", block, outputs, []

    # 4. make_trigpush
    m = re.match(r'make_trigpush\s*\((.*?)\)\s*;?', statement, re.DOTALL)
    if m:
        args = parse_vscript_args(m.group(1))
        if len(args) >= 7:
            targetname, activator, speed, direction, mins, maxs, origin = args[:7]
            targetname = f"anv_mapfixes{targetname}"
            angles = args[7] if len(args) > 7 and args[7] else "0 0 0"
            filter_override = args[8] if len(args) > 8 and args[8] else ""
            spawnflags = "1"
            filtername = ""
            extra_blocks = []

            if filter_override:
                filtername = filter_override
            else:
                if activator in ("Survivor", "Survivors"):
                    filtername = find_filter_in_db("2", GLOBAL_FILTERS_DB)
                    if not filtername:
                        filtername = "anv_globalfixes_filter_survivor"
                        if "2" not in GENERATED_FILTERS:
                            GENERATED_FILTERS.add("2")
                            filter_origin = calculate_filter_origin(origin)
                            extra_blocks.append(f"""{{
    "origin" "{filter_origin}"
    "targetname" "{filtername}"
    "Negated" "Allow entities that match criteria"
    "filterteam" "2"
    "classname" "filter_activator_team"
}}""")
                elif activator in ("Infected", "Ghost"):
                    filtername = find_filter_in_db("3", GLOBAL_FILTERS_DB)
                    if not filtername:
                        filtername = "anv_globalfixes_filter_infected"
                        if "3" not in GENERATED_FILTERS:
                            GENERATED_FILTERS.add("3")
                            filter_origin = calculate_filter_origin(origin)
                            extra_blocks.append(f"""{{
    "origin" "{filter_origin}"
    "targetname" "{filtername}"
    "Negated" "Allow entities that match criteria"
    "filterteam" "3"
    "classname" "filter_activator_team"
}}""")
                elif activator == "Everything":
                    spawnflags = "64"
                elif activator == "Physics":
                    spawnflags = "8"

            filter_line = f'\n    "filtername" "{filtername}"' if filtername else ""
            angles_line = f'\n    "angles" "{angles}"' if angles != "0 0 0" else ""
            block = f"""{{
    "targetname" "{targetname}"
    "classname" "trigger_push"
    "spawnflags" "{spawnflags}"{filter_line}
    "speed" "{speed}"
    "pushdir" "{direction}"
    "origin" "{origin}"{angles_line}
}}"""
            outputs = [
                f'"OnMapSpawn" "{targetname},AddOutput,mins {mins},0,-1"',
                f'"OnMapSpawn" "{targetname},AddOutput,maxs {maxs},0,-1"',
                f'"OnMapSpawn" "{targetname},AddOutput,solid 2,0,-1"'
            ]
            return "; make_trigpush", block, outputs, extra_blocks

    # 5. make_trighurt
    m = re.match(r'make_trighurt\s*\((.*?)\)\s*;?', statement, re.DOTALL)
    if m:
        args = parse_vscript_args(m.group(1))
        if len(args) >= 5:
            targetname, activator, mins, maxs, origin = args[:5]
            targetname = f"anv_mapfixes{targetname}"
            classname = "trigger_hurt"
            filtername = ""
            damagetype = "1"
            extra_blocks = []

            if activator in ("Survivor", "Survivors"):
                filtername = find_filter_in_db("2", GLOBAL_FILTERS_DB)
                if not filtername:
                    filtername = "anv_globalfixes_filter_survivor"
                    if "2" not in GENERATED_FILTERS:
                        GENERATED_FILTERS.add("2")
                        filter_origin = calculate_filter_origin(origin)
                        extra_blocks.append(f"""{{
    "origin" "{filter_origin}"
    "targetname" "{filtername}"
    "Negated" "Allow entities that match criteria"
    "filterteam" "2"
    "classname" "filter_activator_team"
}}""")
            elif activator in ("Infected", "Ghost"):
                filtername = find_filter_in_db("3", GLOBAL_FILTERS_DB)
                if not filtername:
                    filtername = "anv_globalfixes_filter_infected"
                    if "3" not in GENERATED_FILTERS:
                        GENERATED_FILTERS.add("3")
                        filter_origin = calculate_filter_origin(origin)
                        extra_blocks.append(f"""{{
    "origin" "{filter_origin}"
    "targetname" "{filtername}"
    "Negated" "Allow entities that match criteria"
    "filterteam" "3"
    "classname" "filter_activator_team"
}}""")
                if activator == "Ghost":
                    classname = "trigger_hurt_ghost"
                    damagetype = "32"

            filter_line = f'\n    "filtername" "{filtername}"' if filtername else ""
            block = f"""{{
    "targetname" "{targetname}"
    "StartDisabled" "0"
    "spawnflags" "1"
    "nodmgforce" "1"
    "damage" "10000"
    "damagecap" "10000"
    "origin" "{origin}"
    "damagetype" "{damagetype}"{filter_line}
    "classname" "{classname}"
}}"""
            outputs = [
                f'"OnMapSpawn" "{targetname},AddOutput,mins {mins},0,-1"',
                f'"OnMapSpawn" "{targetname},AddOutput,maxs {maxs},0,-1"',
                f'"OnMapSpawn" "{targetname},AddOutput,solid 2,0,-1"'
            ]
            return "; make_trighurt", block, outputs, extra_blocks

    # 6. make_prop
    m = re.match(r'make_prop\s*\((.*?)\)\s*;?', statement, re.DOTALL)
    if m:
        args = parse_vscript_args(m.group(1))
        if len(args) >= 4:
            ptype, targetname, model, origin = args[:4]
            raw_targetname = targetname
            targetname = f"anv_mapfixes{targetname}"
            angles = args[4] if len(args) > 4 and args[4] else "0 0 0"
            shadows = args[5] if len(args) > 5 and args[5] else "shadow_yes"
            solidity = args[6] if len(args) > 6 and args[6] else "solid_yes"
            color = args[7] if len(args) > 7 and args[7] else "255 255 255"
            class_map = {
                "dynamic": "prop_dynamic", "dynamic_ovr": "prop_dynamic_override",
                "physics": "prop_physics", "physics_ovr": "prop_physics_override"
            }
            classname = class_map.get(ptype, "prop_dynamic")
            disableshadows = "1" if shadows == "shadow_no" else "0"
            solidity_lines = ""
            if solidity == "solid_yes":
                solidity_lines = '\n    "solid" "6"' if "dynamic" in ptype else '\n    "spawnflags" "0"'
            elif solidity == "solid_no":
                solidity_lines = '\n    "solid" "0"' if "dynamic" in ptype else '\n    "spawnflags" "4"'
            rendermode_line = '\n    "rendermode" "10"' if raw_targetname.startswith("_solidify") else ""
            angles_line = f'\n    "angles" "{angles}"' if angles != "0 0 0" else ""
            block = f"""{{
    "targetname" "{targetname}"
    "classname" "{classname}"
    "model" "{model}"
    "origin" "{origin}"{angles_line}
    "disableshadows" "{disableshadows}"
    "rendercolor" "{color}"{solidity_lines}{rendermode_line}
}}"""
            return "; make_prop", block, [], []

    # 7. make_decal
    m = re.match(r'make_decal\s*\((.*?)\)\s*;?', statement, re.DOTALL)
    if m:
        args = parse_vscript_args(m.group(1))
        if len(args) >= 2:
            texture, origin = args[:2]
            block = f"""{{
    "classname" "infodecal"
    "texture" "{texture}"
    "origin" "{origin}"
}}"""
            return "; make_decal", block, [], []

    # 8. Convert make_ladder
    m = re.match(r'make_ladder\s*\((.*?)\)\s*;?', statement, re.DOTALL)
    if m:
        args = parse_vscript_args(m.group(1))
        if len(args) >= 3:
            user_strNewLadderName = f"anv_mapfixes{args[0]}"
            user_strDesiredVSSM = args[1]
            user_strOffsetOrigin = args[2]
            user_strOffsetAngles = args[3] if len(args) > 3 and args[3] and args[3] != "null" else "0 0 0"
            user_strNormalOverride = args[4] if len(args) > 4 and args[4] and args[4] != "null" else None
            user_intTeam = args[5] if len(args) > 5 and args[5] and args[5] != "null" else "2"
            user_flRadius = float(args[6]) if len(args) > 6 and args[6] and args[6] != "null" else 1.4

            strModel = ""
            ported_normal = "0 1 0"

            found_ladder = find_ladder_in_db(user_strDesiredVSSM, user_flRadius, GLOBAL_LADDERS_DB)
            if found_ladder:
                strModel = found_ladder["model"]
                ported_normal = found_ladder["normal"]

            final_normal = user_strNormalOverride if user_strNormalOverride else ported_normal
            
            normal_lines = ""
            parts = final_normal.split()
            if len(parts) == 3:
                try:
                    nx, ny, nz = float(parts[0]), float(parts[1]), float(parts[2])
                    normal_lines = f'\n    "normal.x" "{nx}"\n    "normal.y" "{ny}"\n    "normal.z" "{nz}"'
                except ValueError:
                    pass

            angles_line = f'\n    "angles" "{user_strOffsetAngles}"' if user_strOffsetAngles != "0 0 0" else ""
            block = f"""{{
    "targetname" "{user_strNewLadderName}"
    "classname" "func_simpleladder"
    "origin" "{user_strOffsetOrigin}"{angles_line}
    "team" "{user_intTeam}"
    ; Cloned from VSSM: {user_strDesiredVSSM}
    "model" "{strModel}"{normal_lines}
}}"""
            if not found_ladder:
                block = comment_out_block(block)

            return "; make_ladder", block, [], []

    # 9. Convert patch_ladder
    m = re.match(r'patch_ladder\s*\((.*?)\)\s*;?', statement, re.DOTALL)
    if m:
        args = parse_vscript_args(m.group(1))
        if len(args) >= 2:
            desired_vssm = args[0]
            offset_origin = args[1]
            normal_override = args[2] if len(args) > 2 and args[2] and args[2] != "null" else None

            found_ladder = find_ladder_in_db(desired_vssm, 1.4, GLOBAL_LADDERS_DB)
            ladder_model = found_ladder["model"] if found_ladder and found_ladder["model"] else ""

            match_block = f'"model" "{ladder_model}"' if ladder_model else f'"origin" "{desired_vssm}"'

            replace_lines = ""
            if offset_origin and offset_origin != "0 0 0":
                replace_lines += f'\n        "origin" "{offset_origin}"'

            if normal_override:
                parts = normal_override.split()
                if len(parts) == 3:
                    try:
                        nx, ny, nz = float(parts[0]), float(parts[1]), float(parts[2])
                        replace_lines += f'\n        "normal.x" "{nx}"\n        "normal.y" "{ny}"\n        "normal.z" "{nz}"'
                    except ValueError:
                        pass

            block = f"""modify:
{{
    match:
    {{
        "classname" "func_simpleladder"
        ; VSSM: {desired_vssm}
        {match_block}
    }}
    replace:
    {{{replace_lines}
    }}
}}"""
            if not found_ladder or not ladder_model:
                block = comment_out_block(block)

            return "; patch_ladder", block, [], []

    return None, None, [], []

def main():
    global GLOBAL_LADDERS_DB, GLOBAL_FILTERS_DB

    if len(sys.argv) < 4:
        print("Usage: python l4d2_nut_to_l4d1_stripper.py <input_nut_path> <output_cfg_path> <map.bsp>")
        sys.exit(1)

    input_nut_path = sys.argv[1]
    output_cfg_path = sys.argv[2]
    bsp_path = sys.argv[3]

    if not os.path.exists(input_nut_path):
        print(f"Error: Input file '{input_nut_path}' not found.")
        sys.exit(1)

    if not os.path.exists(bsp_path):
        print(f"Error: Mandatory BSP file '{bsp_path}' not found.")
        sys.exit(1)

    print(f"Parsing BSP database: {bsp_path} ...")
    GLOBAL_LADDERS_DB, GLOBAL_FILTERS_DB = parse_bsp_data(bsp_path)
    print(f"Loaded {len(GLOBAL_LADDERS_DB)} ladders and {len(GLOBAL_FILTERS_DB)} filters from BSP.")

    add_blocks_with_comments = [] # list of tuples: (comment, block)
    logic_auto_outputs_grouped = [] # list of tuples: (targetname, output_lines_list)
    modify_blocks = []
    current_statement = ""

    try:
        with open(input_nut_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                stripped = line.strip()
                if not stripped or stripped.startswith("//"):
                    continue
                current_statement += " " + stripped
                if current_statement.endswith(";"):
                    comment, block, outputs, extra_blocks = convert_statement_to_stripper(current_statement)
                    if block:
                        if block.startswith("modify:") or block.startswith("; modify:") or block.startswith("; "):
                            if comment is None:
                                add_blocks_with_comments.append((None, block))
                            else:
                                modify_blocks.append((comment, block))
                        else:
                            add_blocks_with_comments.append((comment, block))
                    if outputs:
                        m_tn = re.search(r'"OnMapSpawn"\s+"([^,]+),', outputs[0])
                        tn = m_tn.group(1) if m_tn else "unknown"
                        logic_auto_outputs_grouped.append((tn, outputs))
                    if extra_blocks:
                        for eb in extra_blocks:
                            add_blocks_with_comments.append(("; filter_activator_team", eb))
                    current_statement = ""

        # Build combined output sections
        final_sections = []

        if add_blocks_with_comments or logic_auto_outputs_grouped:
            regular_add_lines = ["add:"]
            filter_add_lines = []
            
            last_comment = None
            for comment, block in add_blocks_with_comments:
                if comment is None:
                    regular_add_lines.append(block)
                elif comment == "; filter_activator_team":
                    filter_add_lines.append(comment)
                    filter_add_lines.append(block)
                else:
                    if comment and comment != last_comment:
                        regular_add_lines.append(comment)
                        last_comment = comment
                    regular_add_lines.append(block)

            # 1. Regular add blocks first
            if len(regular_add_lines) > 1:
                final_sections.append("\n".join(regular_add_lines))

            # 2. filter_activator_team blocks next (at the bottom of add)
            if filter_add_lines:
                filter_content = ["add:"] if len(regular_add_lines) == 1 else []
                filter_content.extend(filter_add_lines)
                final_sections.append("\n".join(filter_content))

            # 3. logic_auto block at the absolute bottom with ; logic_auto comment right before it
            if logic_auto_outputs_grouped:
                grouped_output_lines = []
                last_tn = None
                for tn, outs in logic_auto_outputs_grouped:
                    if last_tn is not None and last_tn != tn:
                        grouped_output_lines.append("") # empty line between different targetnames
                    for out in outs:
                        grouped_output_lines.append(f"    {out}")
                    last_tn = tn

                logic_auto_block = "add:\n{\n    \"classname\" \"logic_auto\"\n" + "\n".join(grouped_output_lines) + "\n}"
                final_sections.append("; logic_auto\n" + logic_auto_block)

        if modify_blocks:
            last_mod_comment = None
            for comment, block in modify_blocks:
                if comment and comment != last_mod_comment:
                    final_sections.append(comment + "\n" + block)
                    last_mod_comment = comment
                else:
                    final_sections.append(block)

        output_dir = os.path.dirname(output_cfg_path)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir, exist_ok=True)

        with open(output_cfg_path, "w", encoding="utf-8") as f:
            f.write("\n\n".join(final_sections))

        print(f"Conversion successful! Output written to '{output_cfg_path}'.")

    except Exception as e:
        print(f"An error occurred during conversion: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()