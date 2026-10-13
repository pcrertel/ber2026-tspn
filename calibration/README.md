# The calibration instances

The eleven parameters of the ILS-BCD were calibrated with irace on instances
generated for that purpose, disjoint from the 235 converted ones, by a
procedure that reproduces the way those were built. Section 5.4 of the paper
describes it; `generate_calibration.f90` is the implementation.

The instances themselves are under `instances/calibration/`: the 20 of the
training set irace used, the 40 of the test set, the seeds they were drawn with
in `seeds.csv`, and the order irace presents the training ones in,
`train-order.txt`.

## Regenerating them

```
calibration/run-generation.sh
```

writes to `work/calibration/`, without touching `instances/`, and validates
everything it produces. It generates two sets:

- `all/`, 80 instances, 5 for each $m \in \{10,20,30,40\}$ and 10 for each
  $m \in \{50,\dots,100\}$. The 20 of `instances/calibration/train/` are the
  subset of these listed in `train-order.txt`.
- `test/`, 40 instances, 4 for each $m$, drawn from a different root seed, so
  the two sets are disjoint. These are exactly the 40 of
  `instances/calibration/test/`.

Both come out byte-for-byte identical to the shipped files:

```
calibration/run-generation.sh
diff -r instances/calibration/test work/calibration/test
```

prints nothing, and each file of `instances/calibration/train/` is identical to
the file of the same name in `work/calibration/all/`.

## How an instance is drawn

The centres of the $m$ clusters are placed by best-candidate sampling: each
centre is the best of ten candidates drawn uniformly in the square, the one
whose distance to the centres already placed is largest. The number of points
of each cluster is borrowed from a GTSP instance of Section 5.1 with a
comparable number of clusters — `seeds.csv` records which one, under `donor`.
The points of a cluster are then drawn in the Voronoi cell of its centre and
displaced a little, so that they may cross the boundary of the cell, which
reproduces the small overlap between the neighborhoods of the converted
instances. Coordinates are rounded to integers, and each cluster is finally
turned into a polygon exactly as in `conversion/`.

The side of the square is one of $2 \times 10^{j}$, $j \in \{2,3,4,5\}$, one
per order of magnitude within the range of coordinates of the converted
instances. Since coordinates are integers, the side also sets how coarse the
grid is relative to a cluster, and hence how often a cluster collapses to a
segment or to a single point.

`validate-instance.awk` checks one instance: the header, the vertex counts, and
that every polygon is simple with at most three reflex vertices.
