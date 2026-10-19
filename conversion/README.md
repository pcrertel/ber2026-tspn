# GTSP → TSPN

This folder contains the programs that build a TSPN instance from a GTSP
instance, turning each cluster of points into a polygonal neighborhood that
contains it.

To build the 295 instances of `instances/tspn/`:

    conversion/run-conversion.sh

Options:

| | |
|---|---|
| `--out <dir>` | write under `<dir>` instead of over `instances/tspn/` |
| `--khat <k>` | at most `k` reflex vertices per neighborhood; 3 by default, and 0 stops at the convex hull |
| `--figures` | also write MetaPost sources that draw the neighborhoods |

The programs:

| | |
|---|---|
| `stage1_read_gtsp.f90` | reads a `.gtsp` file and writes the points of each cluster |
| `stage2_sort_by_angle.f90` | sorts the points of each cluster by angle around its centre |
| `stage3_build_polygons.f90` | builds the polygon: the convex hull, then up to `k` slices carved out of its longest edges, each one turning a discarded point into a reflex vertex |
| `validate_convex.py` | checks a set built with `--khat 0`; run it as `conversion/validate_convex.py <dir>` |

A cluster of one point gives a point, two points give a segment, and three or
more give a simple polygon.

It reads `instances/gtsp/<library>/<name>.gtsp` for every name listed in
`instances/gtsp/selected-instances/<library>.txt`.
