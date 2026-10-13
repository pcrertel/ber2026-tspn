#!/usr/bin/env python3
"""Validates a convex conversion, the one obtained with --khat 0.

    conversion/run-conversion.sh --khat 0 --out /tmp/convex
    conversion/validate_convex.py /tmp/convex

For every instance it checks that

  - the format is right: the header 'npol nvmax', with nvmax the largest nv(k),
    and the same npol as the non-convex instance of instances/tspn/;
  - every polygon with nv >= 3 is strictly convex, that is, has no vertex
    collinear with its neighbours, and all of them have the same orientation;
  - the polygon contains every point of its GTSP cluster, read from the output
    of stage 2;
  - its vertices are those of a convex hull computed here by a different
    algorithm, Andrew's monotone chain, discarding as collinear the vertices
    that lie within 1e-12 (relative) of the outline, as the converter does
    with colintol: in the instances whose coordinates are decimal, fl417 and
    d493, there are vertices collinear to within floating point noise;
  - points (nv = 1) and segments (nv = 2) are identical to those of the
    non-convex instance.

It also counts the neighbourhoods that differ from the non-convex ones, which
is every cluster that had a slice carved out of its hull.

Exits with status 1 if anything failed.
"""
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")

if len(sys.argv) != 2:
    sys.exit(__doc__)

OUT = sys.argv[1]
CX = os.path.join(OUT, "instances", "tspn")               # the convex instances
WORK = os.path.join(OUT, "work", "stage2-sorted-points")  # the cluster points
NC = os.path.join(ROOT, "instances", "tspn")              # the shipped instances


def read(path):
    tok = open(path).read().split()
    m, nvmax = int(tok[0]), int(tok[1])
    p, P = 2, []
    for _ in range(m):
        k = int(tok[p])
        p += 1
        P.append([(float(tok[p + 2 * j]), float(tok[p + 2 * j + 1]))
                  for j in range(k)])
        p += 2 * k
    assert p == len(tok), f"{path}: trailing data in the file"
    return nvmax, P


def cross(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def hull(pts):
    pts = sorted(set(pts))
    if len(pts) <= 2:
        return pts
    diam2 = max((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2
                for a in pts for b in pts)
    tol = 1e-12 * diam2
    lo, up = [], []
    for q in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], q) <= tol:
            lo.pop()
        lo.append(q)
    for q in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], q) <= tol:
            up.pop()
        up.append(q)
    return lo[:-1] + up[:-1]


probs = []
tot = {"inst": 0, "pol": 0, "changed": 0, "pt": 0, "seg": 0, "orient": set()}
for lib in ("gtsplib", "momlib"):
    for f in sorted(glob.glob(os.path.join(CX, lib, "*.dat"))):
        name = os.path.basename(f)
        tot["inst"] += 1
        nvmax, P = read(f)
        _, Q = read(os.path.join(NC, lib, name))
        _, C = read(os.path.join(WORK, lib, name))
        if len(P) != len(Q) or len(P) != len(C):
            probs.append(f"{name}: npol differs")
            continue
        if nvmax != max(len(v) for v in P):
            probs.append(f"{name}: nvmax")
        for i, (v, q, c) in enumerate(zip(P, Q, C)):
            tot["pol"] += 1
            scale = max(1.0, max(abs(x) for p in c for x in p))
            if len(v) <= 2:
                tot["pt" if len(v) == 1 else "seg"] += 1
                if v != q:
                    probs.append(f"{name} pol {i+1}: the point or segment "
                                 "differs from the non-convex instance")
                continue
            if v != q:
                tot["changed"] += 1
            n = len(v)
            cr = [cross(v[j], v[(j + 1) % n], v[(j + 2) % n]) for j in range(n)]
            if not (all(x > 0 for x in cr) or all(x < 0 for x in cr)):
                probs.append(f"{name} pol {i+1}: not strictly convex")
            tot["orient"].add("ccw" if cr[0] > 0 else "cw")
            sg = 1 if cr[0] > 0 else -1
            for p in c:
                if any(sg * cross(v[j], v[(j + 1) % n], p) < -1e-9 * scale ** 2
                       for j in range(n)):
                    probs.append(f"{name} pol {i+1}: a point of the cluster "
                                 "lies outside")
                    break
            if set(hull(c)) != set(v):
                probs.append(f"{name} pol {i+1}: the vertices differ from the "
                             "independently computed convex hull")

print(f"{tot['inst']} instances, {tot['pol']} neighbourhoods "
      f"({tot['pt']} points, {tot['seg']} segments); "
      f"orientation of the polygons: {sorted(tot['orient'])}")
print(f"polygons that differ from the non-convex case: {tot['changed']}")
print(f"problems: {len(probs)}")
for p in probs[:20]:
    print("  " + p)
sys.exit(1 if probs else 0)
