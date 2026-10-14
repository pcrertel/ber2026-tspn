# The ILS-BCD

This folder contains the iterated local search and the block coordinate descent
that computes the visit points of each visiting sequence it evaluates.

To build it and run it on one instance:

    ils/build.sh
    ils/run.sh instances/tspn/momlib/10i60-21.dat 1 60

The arguments of `run.sh` are the instance, the seed and the time limit in
seconds. A run ends after 3,000 consecutive iterations without improving the
incumbent, or at the time limit, whichever comes first.

`run.sh` prints the tour length and its gaps to the references of
`instances/reference-gtsp-costs.dat`, and writes to `out/<instance>-seed<seed>/`:

| | |
|---|---|
| `tour.dat` | the solution: the neighborhood visited and the visit point, one line per stop, in the order of the tour, with the tour length on the last line; the same format as `instances/reference-solutions/` |
| `initial.dat` | the initial solution, in the same format |
| `incumbent.dat` | one line per improvement of the incumbent, with the time at which it happened |
| `summary.csv` | one row with the final length, the gaps, the CPU times, the iteration counts and the per-neighborhood counters |
| `run.log` | what the program wrote to its output |

## Parameters

`run.sh` uses the configuration calibrated with irace:

| symbol | name | value |
|---|---|---|
| n_stag | `nstag` | 10 |
| eta_0 | `eps` | 0.01 |
| h | `h` | 0.95 |
| L | `strlen` | 3 |
| — | `reverse` | 0, a relocated string is not inserted reversed |
| \|Z\| | `cardZ` | 10 |
| l | `numdbmoves` | 5 |
| k | `bsk` | 3 |
| — | `vnd_type` | 0, the VND visits its neighborhoods in a fixed order |
| — | `bestfirst` | 0, first improvement |
| K | `ncand_max` | 10 |

To use another configuration, edit `PARAM_1` and `PARAM_2` in `run.sh`; the
eleven values are read as one list, in the order above.

## The modules

| | |
|---|---|
| `main.f90` | reads the instance and the parameters, runs the search, writes the output |
| `metaheuristic.f90` | the ILS and the VND with its eight neighborhoods |
| `blockcoordinatedescent.f90` | the BCD that computes the visit points of a sequence |
| `geometry.f90` | the geometric primitives, including the projection onto a polygon |
| `instance.f90` | the instance, the parameters, the counters and the I/O |
| `assct.f` | the assignment problem solved by the neighborhood of Gutin |
