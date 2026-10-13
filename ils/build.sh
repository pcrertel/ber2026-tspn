#!/bin/bash
#
# Compiles the ILS-BCD of the paper into the executable ils-bcd.
#
#   Usage:  ils/build.sh
#
# The modules must be given to the compiler in this order, which is the order
# of their dependencies: geometry and the assignment solver first, then the
# instance and its I/O, then the BCD, then the metaheuristic, then the main
# program.
#
# The flags below are the ones used for the experiments reported in the paper.
# Two of them deserve a note:
#
#   -march=native  tunes the binary for the CPU it is compiled on, so the
#                  executable is not portable to a different machine; drop it
#                  if you need a portable binary.
#   -ffast-math    relaxes floating point semantics. The search is robust to
#                  it - every tour length is recomputed from the coordinates
#                  before being reported - but a run may follow a slightly
#                  different path, and ties may break the other way.
#
# Set FLAGS in the environment to override them, for instance
#
#   FLAGS="-O2 -g -fcheck=all" ils/build.sh
#
# to get a debug build.
#
# Requires gfortran. Nothing else.

set -eu

cd "$(dirname "$0")"

FLAGS=${FLAGS:--O3 -march=native -ffast-math -flto=auto -Wall}

echo "== gfortran $FLAGS"
gfortran $FLAGS \
    assct.f \
    geometry.f90 \
    instance.f90 \
    blockcoordinatedescent.f90 \
    metaheuristic.f90 \
    main.f90 \
    -o ils-bcd

rm -f ./*.mod
echo "== ils/ils-bcd"
