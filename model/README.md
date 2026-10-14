# The MIQCP model

This folder contains the mixed-integer quadratically constrained program for
the TSPN, solved with CPLEX, and the instances in the form it reads.

To solve one instance:

    model/run_model.py --library gtsplib --time-limit 3600 10att48

With no instance name it runs over the whole library. `run_model.py --help`
lists the options; two of them change the problem being solved:

| | |
|---|---|
| `--only-visit-points` | fix the visiting sequence to the one in `nn-solution/` and optimize only the visit points. Without it the sequence is a variable of the model. |
| `--no-extra-constraints` | drop the additional constraints based on norm inequalities |

Solutions are written to `write-solutions/`.

| | |
|---|---|
| `model_tspn.py` | the model |
| `run_model.py` | the entry point |
| `instances/` | the TSPN instances with each non-convex neighborhood already partitioned into convex polygons, which is the form the model reads |
| `nn-solution/` | the visiting sequence of each instance, from the nearest neighbour heuristic: the tour length on the first line, then the indices of the neighborhoods in the order they are visited |

Requires CPLEX with its Python API, the `cplex` and `docplex` modules.
