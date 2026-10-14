# The São Paulo instance

`96sp4966.dat` is the TSPN instance built from the map of the city of São Paulo,
Brazil, introduced in [\[3\]](../../README.md#instance-references).

It has 96 polygonal neighborhoods, the districts of the city, with between 51
and 57 vertices each and 4,966 in all, 16 to 29 of them reflex. All but two
pairs of the neighborhoods are disjoint.

The file is the instance as the code of [\[3\]](../../README.md#instance-references)
reads it: the outline of each district from the municipal map, reduced to 80% of
its size about the centre of its own bounding box and, where it had 100 vertices
or more, subsampled to about 50. The coordinates are in metres, in the SAD69
projection of the original map.

`reference-cost.dat` records the tour length reported there, 212,292.01.
