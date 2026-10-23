#!/usr/bin/env python3
"""
Scans an individual .cfg file to locate and report entity blocks ({ ... }) that contain both "env_player_blocker" and "angles".
"""

import sys
import re

# Example: python search_angles_blocker.py c1m4_atrium.cfg

def scan_file(filepath: str):
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except Exception as e:
        print(f"Failed to read file {filepath}: {e}")
        return

    lines = content.splitlines()

    # Match { ... } blocks and record their start and end positions in the original text
    pattern = re.compile(r'\{[^{}]*\}', re.DOTALL)
    
    matches = list(pattern.finditer(content))
    found_count = 0

    print(f"Starting scan for file: {filepath}\n" + "="*40)

    for match in matches:
        block = match.group(0)
        block_lower = block.lower()

        # Contains both env_player_blocker and angles
        if "env_player_blocker" in block_lower and "angles" in block_lower:
            found_count += 1
            
            # Calculate 0-based start and end line numbers for the block
            start_line_idx = content[:match.start()].count('\n')
            end_line_idx = content[:match.end()].count('\n')
            
            # 1. First line string and prefix text
            first_line = lines[start_line_idx] if start_line_idx < len(lines) else ""
            first_line_prefix = first_line.split(block[0])
            
            print(f"[Match Found] Near line {start_line_idx}:")
            print(first_line_prefix[0] + block)
            print("-" * 40)

    print(f"\nScan complete. Found {found_count} matching block(s).")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python search_angles_blocker.py /path/to/file")
    else:
        scan_file(sys.argv[1])