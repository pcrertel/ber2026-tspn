# TSPN with non-convex polygonal neighborhoods

Instances, code and results of the paper

> **The Traveling Salesman Problem with non-convex polygonal neighborhoods: A hybrid Iterated Local Search–Block Coordinate Descent approach**

The paper studies the Traveling Salesman Problem with Neighborhoods (TSPN)
where each neighborhood is a simple, possibly non-convex polygon. It proposes a
block coordinate descent (BCD) method that computes the visit points of a fixed
visiting sequence, embeds it in an iterated local search (ILS-BCD), and compares
both against a mixed-integer quadratically constrained program solved with
CPLEX.

This repository holds the 235 TSPN instances used in the paper, the programs
that build them from GTSP instances, the instances used to calibrate the
parameters and the program that generates them, the ILS-BCD itself with a
script that runs it on one instance, the MIQCP model, and the results.

## What is here

| | |
|---|---|
| [`instances/`](instances/) | the TSPN instances, the GTSP instances they come from, the calibration sets, and the reference costs and solutions |
| [`conversion/`](conversion/) | GTSP → TSPN, in three stages |
| [`calibration/`](calibration/) | the generator of the calibration instances |
| [`ils/`](ils/) | the ILS-BCD, with `build.sh` and `run.sh` |
| [`model/`](model/) | the MIQCP and the instances in the form it reads |
| [`results/`](results/) | the best solution the ILS-BCD found on every instance, with a figure of each one and the raw per-run data |

## Quick start

Run the ILS-BCD on one instance for 60 seconds:

```
ils/build.sh
ils/run.sh instances/tspn/momlib/10i60-21.dat 1 60
```

which prints the length of the tour found and its gaps to the two references,
and writes the solution, the trajectory of the incumbent and a one-row summary
to `out/10i60-21-seed1/`. [`ils/README.md`](ils/README.md) describes the
parameters, the outputs and the stopping criteria.

Rebuild the 235 instances from the GTSP sources:

```
conversion/run-conversion.sh --out /tmp/check
diff -r instances/tspn /tmp/check/instances/tspn
```

The rebuilt instances are byte-for-byte identical to the ones shipped.

## Requirements

`gfortran` for everything in `conversion/`, `calibration/` and `ils/`; nothing
else. The experiments of the paper were run with gfortran 12.3.0 on Ubuntu
23.04. `model/` additionally needs CPLEX with its Python API, and was run with
IBM ILOG CPLEX Optimization Studio 22.1.2.

## Formats

[`instances/FORMATS.md`](instances/FORMATS.md) describes the instance files,
the solution files and the file of reference costs. The solutions that `run.sh`
writes are in the same format as the reference solutions, so the two can be
compared directly.

## Credits

The instances of the GTSP Lib and the MOM Lib redistributed here keep their own
provenance, recorded in
[`instances/gtsp/SOURCES.md`](instances/gtsp/SOURCES.md); the São Paulo
instance is from another paper, credited in
[`instances/sao-paulo/SOURCE.md`](instances/sao-paulo/SOURCE.md).
