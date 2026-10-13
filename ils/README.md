# The ILS-BCD

The iterated local search of the paper, with the block coordinate descent that
computes the visit points of each visiting sequence it evaluates.

## Build and run

```
ils/build.sh
ils/run.sh <instance.dat> <seed> <time limit in seconds>
```

For example

```
ils/run.sh instances/tspn/momlib/10i60-21.dat 1 60
```

`build.sh` compiles the six modules into `ils/ils-bcd` and `run.sh` builds it
on first use if it is missing. The flags are the ones used for the experiments;
`build.sh` documents them, including the two that are worth knowing about,
`-march=native` and `-ffast-math`.

## What a run writes

Everything goes to `out/<instance>-seed<seed>/`:

| | |
|---|---|
| `tour.dat` | the solution: the neighborhood visited and the visit point, one line per stop, in the order of the tour, with the tour length on the last line. Same format as `instances/reference-solutions/`. |
| `initial.dat` | the initial solution, in the same format |
| `incumbent.dat` | one line per improvement of the incumbent, with the time at which it happened |
| `summary.csv` | one row with the final length, the gaps, the CPU times, the iteration counts and the per-neighborhood counters |
| `run.log` | what the program wrote to its output |

`run.sh` also prints the tour length and the gaps to the two references of
`instances/reference-gtsp-costs.dat`. An instance that has no line there still
runs, and `run.sh` says that the gaps are not available.

## When a run stops

A run ends after 3,000 consecutive iterations without improving the incumbent,
or when it reaches the time limit given on the command line, whichever comes
first. The limit is enforced from outside, by `timeout`, and nothing inside the
search reads it: the acceptance threshold is cooled every $n_{\mathrm{stag}}$
iterations without improvement, which is a count of iterations and not of
seconds. A run with a larger limit therefore follows the same trajectory as a
shorter one, for as long as the shorter one lasted, and the clock only decides
where it is cut.

The experiments of the paper used a limit of 1,200 seconds, ten seeds per
instance. All reported times include the construction of the initial solution,
which the clock covers.

## Parameters

`run.sh` sets the configuration calibrated with irace, the first of the five
elite configurations reported in the paper:

| in the paper | here | value |
|---|---|---|
| $n_{\mathrm{stag}}$ | `nstag` | 10 |
| $\eta_0$ | `eps` | 0.01 |
| $h$ | `h` | 0.95 |
| $L$ | `strlen` | 3 |
| reverse | `reverse` | 0 (a relocated string is not inserted reversed) |
| $\lvert Z \rvert$ | `cardZ` | 10 |
| $\ell$ | `numdbmoves` | 5 |
| $k$ | `bsk` | 3 |
| — | `vnd_type` | 0 (the VND visits its neighborhoods in a fixed order) |
| — | `bestfirst` | 0 (first improvement) |
| $K$ | `ncand_max` | 10 |

They are written in `run.sh`, each with a comment, and reach the program
through its standard input. To try another configuration, edit the two lines
of `run.sh` that set `PARAM_1` and `PARAM_2`; the eleven values are read as one
list, in the order of the table above.

## The modules

| | |
|---|---|
| `main.f90` | reads the instance and the parameters, runs the search, writes the output |
| `metaheuristic.f90` | the ILS and the VND with its eight neighborhoods |
| `blockcoordinatedescent.f90` | the BCD that computes the visit points of a sequence |
| `geometry.f90` | the geometric primitives, including the projection onto a polygon |
| `instance.f90` | the instance, the parameters, the counters and all the I/O |
| `assct.f` | the assignment problem solved by the neighborhood of Gutin |

They must be given to the compiler in that order of dependency, which is what
`build.sh` does.
