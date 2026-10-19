# TSPN with non-convex polygonal neighborhoods

Instances, code and results of the paper

> **The Traveling Salesman Problem with non-convex polygonal neighborhoods: A hybrid Iterated Local Search–Block Coordinate Descent approach**

The problem asks for the shortest closed tour that visits a set of polygonal
neighborhoods, each of them simple and possibly non-convex, at one point of
each.

| | |
|---|---|
| [`instances/`](instances/) | the 295 TSPN instances, the GTSP instances they come from, and the reference costs and solutions |
| [`conversion/`](conversion/) | GTSP → TSPN, in three stages |
| [`calibration/`](calibration/) | the calibration instances and the program that generates them |
| [`ils/`](ils/) | the ILS-BCD, with `build.sh` and `run.sh` |
| [`model/`](model/) | the MIQCP and the instances in the form it reads |
| [`results/`](results/) | the best solution found on every instance, with a figure of most of them and the raw per-run data |

To run the ILS-BCD on one instance for 60 seconds:

    ils/build.sh
    ils/run.sh instances/tspn/momlib/10i60-21.dat 1 60

[`instances/FORMATS.md`](instances/FORMATS.md) describes the file formats.

## Requirements

`gfortran` for `conversion/`, `calibration/` and `ils/`. `model/` also needs
CPLEX with its Python API. The experiments were run with gfortran 12.3.0 and
CPLEX 22.1.2.

## Instance references

[1] GTSP Lib — M. Fischetti, J. J. S. González and P. Toth, *A Branch-and-Cut
Algorithm for the Symmetric Generalized Traveling Salesman Problem*, Operations
Research 45(3):378–394, 1997.

[2] MOM Lib — M. Mestria, L. Satoru Ochi and S. de Lima Martins, *GRASP with
path relinking for the symmetric Euclidean clustered traveling salesman
problem*, Computers & Operations Research 40(12):3218–3229, 2013.
DOI 10.1016/j.cor.2012.10.001

[3] the São Paulo instance — E. G. Birgin and J. M. Martínez, *Block coordinate
descent for smooth nonconvex constrained minimization*, Computational
Optimization and Applications 83(1):1–27, 2022.
DOI 10.1007/s10589-022-00389-5
