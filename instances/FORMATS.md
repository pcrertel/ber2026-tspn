# File formats

All files are plain text, with numbers in free format separated by blanks and
newlines: a reader may simply read tokens in order.

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
segment. With `nv(k) >= 3` it is a simple polygon, in general non-convex, with
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
length of the closed tour.

The tour starts at neighborhood 1 and runs towards whichever neighbour of 1 has
the smaller index, so the same cycle is always written the same way.

## Reference costs — `reference-gtsp-costs.dat`

```
<instance>  <GTSP tour>  <GTSP tour + BCD>
```

One line per instance, with comment lines beginning with `#`. The second field
is the length of the best known tour of the GTSP instance the TSPN instance was
built from; the third is the length of that same visiting sequence after the
visit points are recomputed with the BCD.

`sao-paulo/reference-cost.dat` has the same shape, with the length reported in
the literature in both fields.

## GTSP instance — `gtsp/*/*.gtsp`

The format of the GTSP Lib, derived from TSPLIB: a header of `KEY : value`
lines, then `NODE_COORD_SECTION` with one `index x y` per line, then
`GTSP_SET_SECTION` with one line per cluster: the index of the cluster, the
indices of the points that belong to it, and `-1`.

## Calibration instance — `calibration/{train,test}/*.dat`

The same format as a TSPN instance.

## Model instance — `model/instances/*/*.dat`

A declarative form of the same data, with each non-convex neighborhood already
partitioned into convex polygons: the number of neighborhoods, the points of
the GTSP clusters, and for each neighborhood the convex polygons of its
partition with their vertices.
