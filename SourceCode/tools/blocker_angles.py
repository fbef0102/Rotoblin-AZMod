#!/usr/bin/env python3
"""Rewrite rotated env_player_blocker entries in Stripper cfgs.

L4D1's env_player_blocker is an axis-aligned SOLID_BBOX: it ignores "angles"
(and has no "boxmins"/"boxmaxs"), so a rotated box from an L4D2
env_physics_blocker spawns as the unrotated mins/maxs. This replaces each
rotated blocker with a chain of small axis-aligned boxes that together cover
the rotated box it was meant to be. Neighbouring pieces overlap, so the chain
has no gaps; no piece corner sits more than --tol units outside the true box
(the report says when a long box needs more than --cap pieces for that).

A box whose face is a steep slope (between 46 and 89 degrees: a slide-off
plate) is left alone and listed: cut into boxes it becomes a staircase that
players walk up (step height 18), which is the opposite of a slide-off slope.
--steep converts those too.

usage: blocker_angles.py [--tol 8] [--cap 48] [--steep] [--write] cfg...
Without --write it only prints what it would do.
"""
import argparse, itertools, math, re, sys

KV = re.compile(r'^\s*"([^"]+)"\s+"([^"]*)"')
SECTION = re.compile(r'^\s*(add|filter|modify|remove)\s*:', re.I)


def vec(s):
    v = [float(x) for x in s.replace(",", " ").split()]  # the engine reads "a, b, c" too
    return (v + [0.0, 0.0, 0.0])[:3]


def angle_matrix(p, y, r):
    """Source AngleMatrix: columns are the local x (forward), y (left), z (up) axes."""
    sp, cp = math.sin(math.radians(p)), math.cos(math.radians(p))
    sy, cy = math.sin(math.radians(y)), math.cos(math.radians(y))
    sr, cr = math.sin(math.radians(r)), math.cos(math.radians(r))
    return [
        [cp * cy, sp * sr * cy - cr * sy, sp * cr * cy + sr * sy],
        [cp * sy, sp * sr * sy + cr * cy, sp * cr * sy - sr * cy],
        [-sp, sr * cp, cr * cp],
    ]


def clip_poly(poly, n, d):
    """Keep the part of a convex polygon where n.p <= d."""
    out = []
    for i, p in enumerate(poly):
        q = poly[(i + 1) % len(poly)]
        dp = sum(n[k] * p[k] for k in range(3)) - d
        dq = sum(n[k] * q[k] for k in range(3)) - d
        if dp <= 0:
            out.append(p)
        if (dp < 0) != (dq < 0) and dp != dq:
            t = dp / (dp - dq)
            out.append([p[k] + (q[k] - p[k]) * t for k in range(3)])
    return out


def box_faces(corner):
    """The 6 faces of a box given corner(bits) -> point, bits = (x, y, z) in {0,1}."""
    faces = []
    for axis in range(3):
        for side in (0, 1):
            u, v = [k for k in range(3) if k != axis]
            ring = []
            for bu, bv in ((0, 0), (1, 0), (1, 1), (0, 1)):
                bits = [0, 0, 0]
                bits[axis], bits[u], bits[v] = side, bu, bv
                ring.append(corner(bits))
            faces.append(ring)
    return faces


def halfspaces_obb(origin, mins, maxs, m):
    hs = []
    for j in range(3):
        ax = [m[k][j] for k in range(3)]
        o = sum(ax[k] * origin[k] for k in range(3))
        hs.append((ax, o + maxs[j]))
        hs.append(([-x for x in ax], -(o + mins[j])))
    return hs


def halfspaces_cell(lo, hi):
    hs = []
    for k in range(3):
        n = [0.0, 0.0, 0.0]
        n[k] = 1.0
        hs.append((n, hi[k]))
        hs.append(([-x for x in n], -lo[k]))
    return hs


def intersect_aabb(faces_a, hs_b, faces_b, hs_a):
    """AABB of the intersection of two convex boxes, or None: every corner of the
    intersection lies on a face of one box, inside the other."""
    pts = []
    for faces, hs in ((faces_a, hs_b), (faces_b, hs_a)):
        for f in faces:
            for n, d in hs:
                f = clip_poly(f, n, d)
                if not f:
                    break
            pts.extend(f)
    if not pts:
        return None
    return ([min(p[k] for p in pts) for k in range(3)],
            [max(p[k] for p in pts) for k in range(3)])


def outside(p, origin, mins, maxs, m):
    """Distance from world point p to the rotated box (0 inside)."""
    d = [p[k] - origin[k] for k in range(3)]
    loc = [sum(m[k][j] * d[k] for k in range(3)) for j in range(3)]
    return math.sqrt(sum(max(mins[j] - loc[j], 0, loc[j] - maxs[j]) ** 2 for j in range(3)))


def cut(origin, mins, maxs, m, counts):
    def obb_corner(bits):
        c = [maxs[j] if bits[j] else mins[j] for j in range(3)]
        return [origin[k] + sum(m[k][j] * c[j] for j in range(3)) for k in range(3)]
    obb_f = box_faces(obb_corner)
    obb_h = halfspaces_obb(origin, mins, maxs, m)
    verts = [p for f in obb_f for p in f]
    wlo = [min(v[k] for v in verts) for k in range(3)]
    whi = [max(v[k] for v in verts) for k in range(3)]
    pieces, bulge = [], 0.0
    for idx in itertools.product(*(range(c) for c in counts)):
        lo = [wlo[k] + (whi[k] - wlo[k]) * idx[k] / counts[k] for k in range(3)]
        hi = [wlo[k] + (whi[k] - wlo[k]) * (idx[k] + 1) / counts[k] for k in range(3)]
        cell_f = box_faces(lambda bits: [hi[k] if bits[k] else lo[k] for k in range(3)])
        r = intersect_aabb(obb_f, halfspaces_cell(lo, hi), cell_f, obb_h)
        if r is None or min(r[1][k] - r[0][k] for k in range(3)) < 0.25:
            continue
        pieces.append(r)
        bulge = max([bulge] + [outside(c, origin, mins, maxs, m)
                               for c in itertools.product(*zip(*r))])
    return pieces, bulge


def split(origin, mins, maxs, ang, tol, cap):
    """Cut the rotated box into world-aligned slabs (along one or two world axes)
    and cover each slab's share of the box with its own axis-aligned box.
    Returns (pieces, bulge): the fewest pieces whose corners stay within tol of
    the true box, or the tightest cut that fits in cap pieces."""
    m = angle_matrix(*ang)
    best = None
    for axes in ((0,), (1,), (2,), (0, 1), (0, 2), (1, 2)):
        for n in range(1, cap + 1):
            for n2 in (range(1, cap // n + 1) if len(axes) == 2 else (None,)):
                counts = [1, 1, 1]
                counts[axes[0]] = n
                if n2:
                    counts[axes[1]] = n2
                if counts[0] * counts[1] * counts[2] > cap:
                    continue
                if best and not best[0][0] and counts[0] * counts[1] * counts[2] >= best[0][1]:
                    continue  # already have a cut within tol using no more pieces
                pieces, bulge = cut(origin, mins, maxs, m, counts)
                if not pieces:
                    continue
                key = (bulge > tol + 1e-6, len(pieces) if bulge <= tol + 1e-6 else bulge)
                if best is None or key < best[0]:
                    best = (key, pieces, bulge)
    return best[1], best[2]


def face_slope(mins, maxs, ang):
    """Degrees from horizontal of the box's largest faces (90 = upright wall)."""
    m = angle_matrix(*ang)
    thin = min(range(3), key=lambda j: maxs[j] - mins[j])
    return math.degrees(math.acos(min(1.0, abs(m[2][thin]))))


def fmt(v):
    return " ".join(str(int(x)) for x in v)


def piece_text(kv_lines, lo, hi, indent):
    # grow half a unit each way so neighbours overlap instead of just touching
    lo = [x - 0.5 for x in lo]
    hi = [x + 0.5 for x in hi]
    o = [round((lo[k] + hi[k]) / 2) for k in range(3)]
    mn = [math.floor(lo[k] - o[k]) for k in range(3)]
    mx = [math.ceil(hi[k] - o[k]) for k in range(3)]
    out = ["{"]
    for key, _, line in kv_lines:
        k = key.lower()
        if k == "origin":
            out.append(f'{indent}"origin" "{fmt(o)}"')
        elif k == "mins":
            out.append(f'{indent}"mins" "{fmt(mn)}"')
        elif k == "maxs":
            out.append(f'{indent}"maxs" "{fmt(mx)}"')
        elif k in ("angles", "boxmins", "boxmaxs"):
            continue
        else:
            out.append(line)
    if not any(k.lower() == "origin" for k, _, _ in kv_lines):
        out.insert(1, f'{indent}"origin" "{fmt(o)}"')
    out.append("}")
    return out


def convert(text, tol, cap, report, name, steep=False):
    lines = text.split("\n")
    out, i, section = [], 0, None
    while i < len(lines):
        line = lines[i]
        s = SECTION.match(line)
        if s:
            section = s.group(1).lower()
        if section == "add" and line.strip() == "{":
            j = i + 1
            while j < len(lines) and lines[j].strip() != "}":
                j += 1
            body = lines[i + 1:j]
            kv = [(m.group(1), m.group(2), l) for l in body if not l.lstrip().startswith((";", "//"))
                  for m in [KV.match(l)] if m]
            d = {k.lower(): v for k, v, _ in kv}
            ang = vec(d.get("angles", "0 0 0"))
            if (d.get("classname", "").lower() == "env_player_blocker"
                    and any(abs(a) > 0.01 for a in ang)):
                if "origin" not in d or "mins" not in d or "maxs" not in d or len(kv) != len(
                        [l for l in body if l.strip() and not l.lstrip().startswith((";", "//"))]):
                    report.append((name, "SKIPPED (no origin/mins/maxs, or a line it could not read)", d))
                    out.extend(lines[i:j + 1]); i = j + 1; continue
                origin, mins, maxs = vec(d.get("origin", "0 0 0")), vec(d["mins"]), vec(d["maxs"])
                slope = face_slope(mins, maxs, ang)
                if not steep and 46 < slope < 89:
                    report.append((name, f"LEFT AS IS (face slope {slope:.0f} deg, boxes would make stairs)", d))
                    out.extend(lines[i:j + 1]); i = j + 1; continue
                pieces, used = split(origin, mins, maxs, ang, tol, cap)
                indent = re.match(r"^(\s*)", kv[0][2]).group(1) or "\t"
                out.append(f'; rotated blocker split into {len(pieces)} axis-aligned boxes '
                           f'(was origin "{d.get("origin", "0 0 0")}" angles "{d["angles"]}" '
                           f'mins "{d["mins"]}" maxs "{d["maxs"]}")')
                for lo, hi in pieces:
                    out.extend(piece_text(kv, lo, hi, indent))
                report.append((name, len(pieces), used, d))
                i = j + 1
                continue
        out.append(line)
        i += 1
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tol", type=float, default=8.0)
    ap.add_argument("--cap", type=int, default=48)
    ap.add_argument("--steep", action="store_true")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("files", nargs="+")
    a = ap.parse_args()
    report, total = [], 0
    for f in a.files:
        raw = open(f, "rb").read()
        crlf = b"\r\n" in raw
        text = raw.decode("utf-8", errors="surrogateescape").replace("\r\n", "\n")
        new = convert(text, a.tol, a.cap, report, f, a.steep)
        if new != text and a.write:
            if crlf:
                new = new.replace("\n", "\r\n")
            open(f, "wb").write(new.encode("utf-8", errors="surrogateescape"))
    for r in report:
        if isinstance(r[1], str):
            d = r[2]
            print(f"{r[0].rsplit('/', 1)[-1]}: {d.get('origin', '(no origin)')} angles "
                  f"{d.get('angles')}: {r[1]}")
            continue
        name, n, used, d = r
        total += n
        flag = f"  (bulge {used:.1f})" + ("" if used <= a.tol + 1e-6 else "  OVER TOL")
        print(f"{name.rsplit('/', 1)[-1]}: {d.get('origin', '(no origin)')} angles {d['angles']} "
              f"-> {n} boxes{flag}")
    rot = sum(1 for r in report if not isinstance(r[1], str))
    print(f"\n{rot} rotated blockers -> {total} boxes (+{total - rot} entities)")


if __name__ == "__main__":
    main()
