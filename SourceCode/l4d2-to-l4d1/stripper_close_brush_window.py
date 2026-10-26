#!/usr/bin/env python3
"""Close the NULL-model crash window on model-less func_brush blockers in stripper cfgs.

A func_brush added with no "model" spawns SOLID_VPHYSICS with a NULL model_t and only
becomes a SOLID_BBOX when its logic_auto "AddOutput,solid 2" fires on the first simulated
tick. L4D1's CM_VCollideForModel has no NULL check, so any trace that touches the brush
before then segfaults the server (seen at map load in ZombieManager::IsSpaceForZombieHere).

For every such brush that has a matching "<name>,AddOutput,solid 2" output:
  * add "StartDisabled" "1" so it spawns FSOLID_NOT_SOLID and traces skip it
  * add "<name>,Enable" 0.1 s after the solid output so it turns solid once it is a BBOX
Brushes with no targetname or no matching solid output are left untouched and reported.
Only inserts lines; bytes and line endings of existing lines are preserved.

usage: stripper_close_brush_window.py [--check] file.cfg [file.cfg ...]   (edits in place)
"""
import re
import sys

ENABLE_AFTER = 0.1  # seconds after the solid output
SOLID_RE = re.compile(r'^(\s*)"(\w+)"\s+"([^,"]+),AddOutput,solid 2,([\d.]+),(-?\d+)"\s*$', re.I)


def eol_of(line):
    return "\r\n" if line.endswith("\r\n") else "\n" if line.endswith("\n") else ""


def live(line):
    return not line.lstrip().startswith(";")


def process(path, write):
    lines = open(path, encoding="latin-1", newline="").read().splitlines(keepends=True)
    default_eol = next((eol_of(l) for l in lines if eol_of(l)), "\n")

    # every brace block that holds no nested brace: (start, end) line indexes
    blocks = []
    i = 0
    while i < len(lines):
        if live(lines[i]) and lines[i].strip() == "{":
            j = i + 1
            while j < len(lines) and not (live(lines[j]) and lines[j].strip() in ("{", "}")):
                j += 1
            if j < len(lines) and lines[j].strip() == "}":
                blocks.append((i, j))
                i = j
            else:
                i = j - 1
        i += 1

    brushes = {}  # targetname -> [classname line index, ...]
    unnamed = 0
    for a, b in blocks:
        body = [(k, lines[k]) for k in range(a + 1, b) if live(lines[k])]
        text = "".join(l for _, l in body)
        if not re.search(r'"classname"\s+"func_brush"', text, re.I):
            continue
        if '"origin"' not in text.lower() or re.search(r'"model"\s+"', text, re.I):
            continue
        if re.search(r'"StartDisabled"', text, re.I):
            continue
        m = re.search(r'"targetname"\s+"([^"]+)"', text, re.I)
        if not m:
            unnamed += 1
            continue
        cls = next(k for k, l in body if re.search(r'"classname"', l, re.I))
        brushes.setdefault(m.group(1), []).append(cls)

    solid_lines = {}  # targetname -> [line index, ...]
    for k, l in enumerate(lines):
        if live(l):
            m = SOLID_RE.match(l.rstrip("\r\n"))
            if m and m.group(3) in brushes:
                solid_lines.setdefault(m.group(3), []).append(k)

    inserts = {}
    for name, idxs in solid_lines.items():
        for k in idxs:
            indent, out, _, delay, times = SOLID_RE.match(lines[k].rstrip("\r\n")).groups()
            # outputs of one entity do not fire in file order (the engine prepends each
            # action to the list), so Enable gets a later fire time instead of relying on order
            later = f"{float(delay) + ENABLE_AFTER:g}"
            inserts[k] = f'{indent}"{out}" "{name},Enable,,{later},{times}"'
        for cls in brushes[name]:
            indent = re.match(r"\s*", lines[cls]).group(0)
            inserts[cls] = f'{indent}"StartDisabled" "1"'

    skipped = sorted(set(brushes) - set(solid_lines))
    if write and inserts:
        out = []
        for k, l in enumerate(lines):
            out.append(l if eol_of(l) or k not in inserts else l + default_eol)
            if k in inserts:
                out.append(inserts[k] + (eol_of(l) or default_eol))
        open(path, "w", encoding="latin-1", newline="").write("".join(out))
    fixed = sum(len(brushes[n]) for n in solid_lines)
    return fixed, skipped, unnamed


def main():
    args = sys.argv[1:]
    write = "--check" not in args
    total = 0
    for path in (a for a in args if a != "--check"):
        fixed, skipped, unnamed = process(path, write)
        total += fixed
        if fixed or skipped or unnamed:
            note = f"  no solid output: {skipped}" if skipped else ""
            note += f"  unnamed: {unnamed}" if unnamed else ""
            print(f"{path}: {fixed} brushes{note}")
    print(f"total brushes fixed: {total}")


if __name__ == "__main__":
    main()
