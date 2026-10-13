# GTSP → TSPN

Builds a TSPN instance from a GTSP instance by turning each cluster of points
into a polygonal neighborhood that contains it. Section 5.1 of the paper
describes the procedure; these three programs are the implementation.

```
conversion/run-conversion.sh                      # overwrites instances/tspn/
conversion/run-conversion.sh --out /tmp/check     # writes elsewhere, to compare
```

The 235 instances under `instances/tspn/` come out byte-for-byte identical, so

```
conversion/run-conversion.sh --out /tmp/check
diff -r instances/tspn /tmp/check/instances/tspn
```

prints nothing.

## The three stages

| | |
|---|---|
| `stage1_read_gtsp.f90` | reads a `.gtsp` file and writes the points of each cluster |
| `stage2_sort_by_angle.f90` | sorts the points of each cluster by the angle around its geometric centre, which is the order stage 3 walks |
| `stage3_build_polygons.f90` | builds the polygon of each cluster: the convex hull, then up to $\hat k$ triangular slices carved out of its longest edges, each one turning a discarded interior point into a reflex vertex |

A cluster of one point gives a point, two points give a segment, and three or
more non-collinear points give a simple polygon with at most $\hat k$ reflex
vertices.

`--khat <k>` sets $\hat k$, which is 3 in the paper and in the shipped
instances. `--khat 0` stops at the convex hull, giving the convex instances of
Section 5.3.1.

`--figures` also writes MetaPost sources that draw the neighborhoods of each
instance.

## What it reads

`instances/gtsp/<library>/<name>.gtsp` for every name listed in
`instances/gtsp/selected-instances/<library>.txt`. Nothing else, and nothing
outside `instances/gtsp/` is read.

## Compiler flags

Stage 3 decides whether three points are collinear by comparing a normalised
triangle area against a tolerance. The tolerance is what makes the decision
stable, but flags that reassociate floating point arithmetic can still move a
borderline case and change a polygon by one vertex. The shipped instances were
produced with `-O2`, which is what the script uses; do not add
`-march=native`, `-ffast-math` or `-Ofast`.

## Checking the result

`validate_convex.py` checks a set of instances produced with `--khat 0`: that
every neighborhood is strictly convex, that it contains all the points of its
cluster, and that it agrees with a convex hull computed by a different
algorithm.
