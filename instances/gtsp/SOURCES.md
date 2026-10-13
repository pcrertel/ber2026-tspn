# Where these GTSP instances come from

The 235 files under `gtsplib/` and `momlib/` are redistributed unchanged from
two public benchmark libraries for the Generalized Traveling Salesman Problem.
They are the inputs of `conversion/`, which turns each cluster of points into a
polygonal neighborhood; the TSPN instances it produces are under
`../tspn/`.

**GTSP Lib** — 45 instances, under `gtsplib/`. The library of clustered
instances derived from TSPLIB by

> M. Fischetti, J. J. S. González and P. Toth, *A Branch-and-Cut Algorithm for
> the Symmetric Generalized Traveling Salesman Problem*, Operations Research
> 45(3):378–394, 1997.

**MOM Lib** — 190 instances, under `momlib/`. The library introduced by

> M. Mestria, L. Satoru Ochi and S. de Lima Martins, *GRASP with path relinking
> for the symmetric Euclidean clustered traveling salesman problem*, Computers
> & Operations Research 40(12):3218–3229, 2013.
> DOI 10.1016/j.cor.2012.10.001

## Which instances, and why these

The two lists under `selected-instances/` name the files the conversion reads.
They are every instance of the two libraries that has at most 100 clusters and
gives the geographic coordinates of its points, which the conversion needs: a
neighborhood is built from the positions of the points of a cluster, so an
instance given only by a distance matrix cannot be converted.

The libraries contain further instances, with more than 100 clusters or without
coordinates, which are not redistributed here.

## Reference costs

`../reference-gtsp-costs.dat` gives, for each instance, the length of the best
known GTSP tour. Those tours come from the libraries above; this repository
records only their lengths, which is what the paper uses as a reference.
