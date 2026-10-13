# File formats

All files are plain text. Numbers are written in free format, separated by
blanks and newlines, so a reader may simply read tokens in order; the line
breaks shown below are the ones the programs write, not part of the format.

## TSPN instance — `tspn/*/*.dat`, `sao-paulo/96sp4966.dat`

```
m  nvmax
nv(1)
x(1,1)  y(1,1)
...
x(1,nv(1))  y(1,nv(1))
nv(2)
...
```

`m` is the number of neighborhoods and `nvmax` the largest `nv(k)`. Then, for
each neighborhood `k` in turn, its number of vertices `nv(k)` followed by that
many coordinate pairs, the vertices in order along the boundary.

A neighborhood with `nv(k) = 1` is a single point and one with `nv(k) = 2` is a
segment. With `nv(k) >= 3` it is a simple polygon, non-convex in general, with
at most three reflex vertices in the converted instances and between 16 and 29
in the São Paulo one.

## Solution — `reference-solutions/*.dat`, and what `ils/run.sh` writes

```
k(1)  x(1)  y(1)
k(2)  x(2)  y(2)
...
k(m)  x(m)  y(m)
cost
```

One line per stop, in the order of the tour: the index `k` of the neighborhood
visited and the coordinates of the visit point inside it. The last line is the
length of the closed tour that joins the `m` visit points in that order.

The tour is written in a canonical form: it starts at neighborhood 1 and runs
towards whichever neighbour of 1 has the smaller index. A closed tour can be
read from any starting point and in either direction, and this form picks one
representative of all of them, so two solution files are identical if and only
if they describe the same cycle with the same visit points.

## Reference costs — `reference-gtsp-costs.dat`

```
<instance>  <GTSP tour>  <GTSP tour + BCD>
```

One line per instance, with comment lines beginning with `#`. The second field
is the length of the best known tour of the GTSP instance the TSPN instance was
built from, which is a feasible TSPN tour because every point of a GTSP cluster
belongs to the polygon built from it. The third is the length of that same
visiting sequence after the visit points are recomputed with the BCD, which is
the reference the paper calls GTSP + BCD.

`sao-paulo/reference-cost.dat` has the same shape for the São Paulo instance,
where both fields are the length reported in the paper that introduced it.

## GTSP instance — `gtsp/*/*.gtsp`

The format of the GTSP Lib, derived from TSPLIB: a header of `KEY : value`
lines, then `NODE_COORD_SECTION` with one `index x y` per line, then
`GTSP_SET_SECTION` with one line per cluster: the index of the cluster, the
indices of the points that belong to it, and `-1`. These files are
redistributed unchanged; see `SOURCES.md`.

## Calibration instance — `calibration/*/*.dat`

The same format as a TSPN instance. `seeds.csv` records, for each of them, the
number of neighborhoods, the largest number of vertices, the side of the square
domain, the seed it was drawn with, and the GTSP instance whose cluster sizes
were borrowed. `train-order.txt` lists the 20 training instances in the order
irace presents them.

## Model instance — `model/instances/*/*.dat`

A declarative form of the same data, with each non-convex neighborhood already
partitioned into convex polygons, which is what the MIQCP needs: the number of
neighborhoods, the points of the GTSP clusters, and for each neighborhood the
convex polygons of its partition with their vertices. Section 5.1 of the paper
describes how such a partition is obtained.
