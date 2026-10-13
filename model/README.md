# The MIQCP model

The mixed-integer quadratically constrained program of the paper, solved with
CPLEX. It is the exact counterpart the ILS-BCD and the BCD are compared
against: Section 5.2 of the paper uses it to measure what the additional
constraints based on norm inequalities are worth, and Section 5.3 uses it, with
the visiting sequence fixed, to check the visit points the BCD computes.

```
model/run_model.py --library gtsplib --time-limit 3600 10att48
model/run_model.py --only-visit-points --library both
model/run_model.py --no-extra-constraints --library gtsplib 15pr76
```

`run_model.py --help` lists the options. The two that select the experiment are

- `--only-visit-points`, which fixes the visiting sequence to the one in
  `nn-solution/` and optimizes only the visit points, the experiment of
  Section 5.3. Without it the sequence is a variable of the model, the
  experiment of Section 5.2.
- `--no-extra-constraints`, which drops the additional constraints based on
  norm inequalities, giving the baseline formulation of Section 5.2.

Solutions are written to `write-solutions/`.

## What it reads

`instances/<library>/<name>.dat` are the TSPN instances of this repository with
each non-convex neighborhood already partitioned into convex polygons, which is
the form the model needs: it places the visit point in one of the convex pieces
and needs each piece separately. Section 5.1 of the paper describes how such a
partition is obtained; any method that partitions a simple polygon into convex
polygons will do, and the files here are the ones used for the experiments.

`nn-solution/nn-sol-<name>.dat` holds, for each instance, the visiting sequence
produced by the nearest neighbour heuristic, which is the fixed sequence of the
experiment of Section 5.3. The first line is the length of that tour and the
rest are the indices of the neighborhoods in the order they are visited.

## Requirements

CPLEX with its Python API, that is, the `cplex` and `docplex` modules. The
experiments of the paper used IBM ILOG CPLEX Optimization Studio 22.1.2 with
default parameters and a CPU time limit of one hour per instance. The
Community Edition that ships with the Python packages is limited in problem
size and will refuse all but the smallest of these instances.

`model_tspn.py` is the model. `run_model.py` is the only entry point; it
resolves `instances/`, `nn-solution/` and `write-solutions/` relative to this
directory and so may be invoked from anywhere.
