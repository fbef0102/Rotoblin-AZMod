#!/usr/bin/env python3
"""
Usage:
    python find_model_coords.py <model_list_file> <map.bsp>

Description:
    1. Reads a text file containing 'model "*number"' definitions and extracts all model indices.
    2. Parses Lump 14 (Models) of the BSP file with the help of bspinfo.py[cite: 2].
    3. Retrieves origin, mins, maxs, and calculates the corresponding VSSM coordinates for each model[cite: 2].
"""

import sys
import os
import re
import struct
from bspinfo import lumps, lump

def main():
    if len(sys.argv) < 3:
        print("Usage: python find_model_coords.py <model_list_file> <map.bsp>")
        sys.exit(1)

    model_file = sys.argv[1]
    bsp_file = sys.argv[2]

    if not os.path.exists(model_file):
        print(f"Error: Input file '{model_file}' not found.")
        sys.exit(1)

    if not os.path.exists(bsp_file):
        print(f"Error: BSP file '{bsp_file}' not found.")
        sys.exit(1)

    # 1. Read input file and extract model indices matching "*number" format
    target_indices = set()
    with open(model_file, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
        matches = re.findall(r'"model"\s*"\*(\d+)"|\*(\d+)', content)
        for m in matches:
            num_str = m[0] if m[0] else m[1]
            if num_str:
                target_indices.add(int(num_str))

    print(f"Parsed Model Indices from file: {sorted(list(target_indices))}")

    # 2. Read and parse BSP structure using bspinfo[cite: 2]
    with open(bsp_file, "rb") as f:
        bsp_data = f.read()

    ver, lump_table = lumps(bsp_data)

    # 3. Read Lump 14 (Models)[cite: 2]
    try:
        models_data = lump(bsp_data, lump_table, 14)
    except Exception as e:
        print(f"Error: Failed to read Lump 14 (Models): {e}")
        sys.exit(1)

    # Source Engine dmodel_t structure size is typically 48 bytes
    # The first 36 bytes contain: mins (3 floats), maxs (3 floats), origin (3 floats)
    struct_size = 48
    models_db = {}

    for idx in range(0, len(models_data), struct_size):
        m_bytes = models_data[idx:idx+struct_size]
        if len(m_bytes) < struct_size:
            break
        mins_x, mins_y, mins_z, maxs_x, maxs_y, maxs_z, org_x, org_y, org_z = struct.unpack('<9f', m_bytes[:36])
        
        # Formula for VSSM center calculation: Maxs - ((Maxs - Mins) / 2) + Origin[cite: 2]
        vssm_x = (maxs_x - ((maxs_x - mins_x) / 2)) + org_x
        vssm_y = (maxs_y - ((maxs_y - mins_y) / 2)) + org_y
        vssm_z = (maxs_z - ((maxs_z - mins_z) / 2)) + org_z

        model_index = idx // struct_size
        models_db[model_index] = {
            "mins": (mins_x, mins_y, mins_z),
            "maxs": (maxs_x, maxs_y, maxs_z),
            "origin": (org_x, org_y, org_z),
            "vssm": (vssm_x, vssm_y, vssm_z)
        }

    # 4. Output results
    print("\n--- Model Coordinates & VSSM Results ---")
    for midx in sorted(list(target_indices)):
        if midx in models_db:
            m = models_db[midx]
            print(f"Model *{midx}:")
            print(f"  - Origin: {m['origin']}")
            print(f"  - Mins:   {m['mins']}")
            print(f"  - Maxs:   {m['maxs']}")
            print(f"  - Calculated VSSM: {m['vssm'][0]:.3f} {m['vssm'][1]:.3f} {m['vssm'][2]:.3f}")
        else:
            print(f"Model *{midx}: Data not found in BSP Lump 14.")

if __name__ == "__main__":
    main()