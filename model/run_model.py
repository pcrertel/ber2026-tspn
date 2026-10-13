#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Solves the MIQCP of the paper with CPLEX on the TSPN instances of this
repository.

Usage:
    model/run_model.py [options] [<instance> ...]

With no instance name it runs over every instance of the chosen library.

Options:
    --library gtsplib|momlib|both   which set to run over (default: both)
    --time-limit <seconds>          CPU time limit per instance (default: 3600)
    --only-visit-points             fix the visiting sequence to the one of
                                    nn-solution/ and optimize only the visit
                                    points, which is the experiment of
                                    Section 5.3 of the paper. Without this flag
                                    the sequence is a variable of the model,
                                    which is the experiment of Section 5.2.
    --no-extra-constraints          solve the model without the additional
                                    constraints based on norm inequalities,
                                    the baseline of Section 5.2
    --normalize                     scale the coordinates to [-1,1]

The instances under instances/ are the TSPN instances of this repository with
each non-convex neighbourhood already partitioned into convex polygons, which
is the form the model needs; Section 5.1 of the paper describes how such a
partition is obtained.

With --only-visit-points the sequence comes from nn-solution/nn-sol-<name>.dat,
the tour produced by the nearest neighbour heuristic, which is the sequence
used in the paper.

Solutions are written to write-solutions/, and the tables of the run to the
standard output.

Requires CPLEX with its Python API (the `cplex` and `docplex` modules).
"""
import argparse
import os
import sys


def main():
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument("instances", nargs="*")
    p.add_argument("--library", default="both",
                   choices=("gtsplib", "momlib", "both"))
    p.add_argument("--time-limit", type=float, default=3600.0)
    p.add_argument("--only-visit-points", action="store_true")
    p.add_argument("--no-extra-constraints", action="store_true")
    p.add_argument("--normalize", action="store_true")
    p.add_argument("-h", "--help", action="store_true")
    a = p.parse_args()
    if a.help:
        print(__doc__)
        return 0

    # model_tspn.py resolves 'instances', 'nn-solution' and 'write-solutions'
    # against the current directory, so the run happens here.
    here = os.path.dirname(os.path.abspath(__file__))
    os.chdir(here)
    sys.path.insert(0, here)
    os.makedirs("write-solutions", exist_ok=True)

    try:
        import model_tspn as M
    except ImportError as e:
        sys.exit("run_model.py: could not import the model (%s).\n"
                 "It needs CPLEX with its Python API." % e)

    libs = ("gtsplib", "momlib") if a.library == "both" else (a.library,)
    pedidas = {x[:-4] if x.endswith(".dat") else x for x in a.instances}

    total = 0
    for lib in libs:
        conj = M.read_all_instance_files("instances", lib)
        if pedidas:
            conj = {k: v for k, v in conj.items()
                    if (k[:-4] if k.endswith(".dat") else k) in pedidas
                    or k in pedidas}
        if not conj:
            continue
        print("== %s: %d instance(s), time limit %g s, %s, %s"
              % (lib, len(conj), a.time_limit,
                 "fixed sequence" if a.only_visit_points else "free sequence",
                 "baseline model" if a.no_extra_constraints
                 else "with the additional constraints"))
        M.process_input_data_and_solve_model(
            conj, a.time_limit, a.only_visit_points, a.normalize,
            not a.no_extra_constraints)
        total += len(conj)

    if total == 0:
        sys.exit("run_model.py: no instance matched.")
    print("\n== solved %d instance(s); solutions under model/write-solutions/"
          % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
