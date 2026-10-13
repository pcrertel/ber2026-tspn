# The São Paulo instance

`96sp4966.dat` is the TSPN instance built from the map of the city of São Paulo,
Brazil, introduced in

> E. G. Birgin and J. M. Martínez, *Block coordinate descent for smooth
> nonconvex constrained minimization*, Computational Optimization and
> Applications 83(1):1–27, 2022. DOI 10.1007/s10589-022-00389-5

It has 96 polygonal neighborhoods, the districts of the city, with between 51
and 57 vertices each and 4,966 in all. They are far less regular than the
neighborhoods of the converted instances, with 16 to 29 reflex vertices each,
and all but two pairs of them are disjoint.

The file redistributed here is the instance as that code reads it: the outline
of each district taken from the municipal map, reduced to 80% of its size about
the centre of its own bounding box, and, where it had 100 vertices or more,
subsampled to about 50. The coordinates are in metres, in the SAD69 projection
of the original map.

`reference-cost.dat` records the length of the tour reported in that paper,
212,292.01, which is what `ils/run.sh` compares its own result against on this
instance. Both fields of the line carry that same value, since this instance
does not come from a GTSP instance and so has no GTSP reference.
