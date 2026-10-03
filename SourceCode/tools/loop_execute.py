#!/usr/bin/env python3
"""
Automates batch processing of .cfg files within a folder by executing python script on each file sequentially.
"""
import sys
import subprocess
from pathlib import Path
import argparse

# Usage: python loop_execute.py   [-r]
# Example: python loop_execute.py search_angles_blocker.py "\Rotoblin-AZMod\left4dead\addons\stripper\Roto-AZMod\maps\"

def run_batch_search(py_execute_file: str, folder_path: str, recursive: bool = False):
    script_path = Path(py_execute_file)
    folder = Path(folder_path)

    # Check if the target Python script exists
    if not script_path.exists() or not script_path.is_file():
        print(f"Error: Target script '{py_execute_file}' does not exist or is not a valid file.")
        return

    # Check if target directory exists
    if not folder.exists() or not folder.is_dir():
        print(f"Error: Directory '{folder_path}' does not exist or is not a valid directory.")
        return

    # Search for .cfg files (optionally including subdirectories)
    pattern = "**/*.cfg" if recursive else "*.cfg"
    cfg_files = sorted(list(folder.glob(pattern)))

    if not cfg_files:
        print(f"No .cfg files found in '{folder_path}'.")
        return

    print(f"Found {len(cfg_files)} .cfg file(s), starting sequential processing using '{script_path.name}'...\n" + "=" * 60)

    # Process each file sequentially by calling target script
    for idx, cfg_file in enumerate(cfg_files, 1):
        print(f"\n[{idx}/{len(cfg_files)}] Analyzing file: {cfg_file}")
        print("-" * 60)

        # Execute target script using current Python environment
        cmd = [sys.executable, str(script_path), str(cfg_file)]

        try:
            subprocess.run(cmd, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Execution failed (Exit code {e.returncode}): {cfg_file}")
        except FileNotFoundError:
            print(f"Error: Could not execute '{py_execute_file}'.")
            break

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Batch process all .cfg files in a directory using a specified Python script."
    )
    parser.add_argument("script", help="Path to the Python script to execute on each .cfg file")
    parser.add_argument("folder", nargs="?", default=".", help="Target directory path (default: current directory)")
    parser.add_argument("-r", "--recursive", action="store_true", help="Scan subdirectories recursively")

    args = parser.parse_args()
    run_batch_search(args.script, args.folder, args.recursive)