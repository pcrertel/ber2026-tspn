#!/bin/bash
#
# Runs the ILS-BCD on one TSPN instance.
#
#   Usage:  ils/run.sh <instance.dat> <seed> <time limit in seconds>
#
#   Example:
#       ils/build.sh
#       ils/run.sh instances/tspn/momlib/10i60-21.dat 1 60
#
# Everything the run produces goes to out/<instance>-seed<seed>/:
#
#   tour.dat        the solution. One line per stop, in the order of the tour:
#                   the index of the neighbourhood visited and the coordinates
#                   of the visit point. The last line is the tour length.
#                   This is the format of instances/reference-solutions/, so
#                   the two can be compared directly.
#   incumbent.dat   one line per improvement of the incumbent, with the time at
#                   which it happened and the tour length; this is the data
#                   behind a convergence curve.
#   summary.csv     one row with the final tour length, the gaps, the CPU
#                   times, the iteration counts and the per-neighbourhood
#                   counters of this run.
#   initial.dat     the initial solution, in the format of tour.dat.
#   run.log         whatever the program wrote to stdout and stderr.
#
# The parameters of the search are the ones calibrated with irace and reported
# in the paper; they are set below, each with the symbol used there.
#
# The reference costs come from instances/reference-gtsp-costs.dat, which gives
# for each of the 235 converted instances the length of the GTSP tour and the
# length of that same tour after the visit points are recomputed with the BCD.
# They are only used to report gaps. An instance absent from that file still
# runs; the gap columns are then meaningless and this script says so.
#
# Requires gfortran (through ils/build.sh), awk and GNU timeout.

set -u

if [ $# -ne 3 ]; then
    sed -n '2,37p' "$0"
    exit 1
fi

ils=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$ils/.." && pwd)

inst=$1
seed=$2
tlim=$3

# ------------------------------------------------------------------ checks
case "$inst" in
    /*) instpath=$inst ;;
     *) instpath=$PWD/$inst ;;
esac
if [ ! -f "$instpath" ]; then
    echo "run.sh: no such instance: $inst" >&2
    exit 1
fi
case "$seed" in ''|*[!0-9]*) echo "run.sh: the seed must be a positive integer" >&2; exit 1 ;; esac
case "$tlim" in ''|*[!0-9]*) echo "run.sh: the time limit must be an integer number of seconds" >&2; exit 1 ;; esac

if [ ! -x "$ils/ils-bcd" ]; then
    echo "== building, which happens once"
    "$ils/build.sh" || exit 1
fi

name=$(basename "$instpath" .dat)
run="$root/out/$name-seed$seed"
rm -rf "$run"
mkdir -p "$run/ils-toursol" "$run/tables" "$run/incumbent"

# ------------------------------------------------- the reference costs, if any
# One line per instance:  <name>  <GTSP tour>  <GTSP tour + BCD>
bks="$run/reference.txt"
temgap=0
for costs in "$root/instances/reference-gtsp-costs.dat" \
             "$root/instances/sao-paulo/reference-cost.dat"; do
    [ -f "$costs" ] || continue
    if awk -v n="$name" '$1 == n {print; found = 1; exit} END {exit !found}' \
           "$costs" > "$bks"; then
        temgap=1
        break
    fi
done
if [ $temgap -eq 0 ]; then
    echo "$name 0.0 0.0" > "$bks"
    echo "== no reference cost for $name: the gap columns are not meaningful"
fi

# ------------------------------------------------------------- the parameters
# The configuration calibrated with irace, the first of the five elite ones
# reported in the paper. The eleven values are read as one list, in this order:
#
#   nstag       n_stag,  iterations without improvement between two updates
#                        of the acceptance threshold
#   eps         eta_0,   the initial acceptance threshold
#   h           h,       the factor the threshold is multiplied by
#   strlen      L,       the longest string the string relocation moves
#   reverse              1 if a relocated string may be inserted reversed
#   cardZ       |Z|,     tour positions reassigned in the neighborhood of Gutin
#   numdbmoves  l,       double bridge moves applied in the perturbation
#   bsk         k,       the parameter of the Balas-Simonetti neighborhood
#   vnd_type             0 for the fixed neighborhood order of the VND
#   bestfirst            0 for first improvement
#   ncand_max   K,       the size of the candidate lists
#
PARAM_1="10 0.01 0.95"
PARAM_2="3 0 10 5 3 0 0 10"

# ----------------------------------------------------------------------- run
# ILS_VERSION labels the output files and ILS_TUNING must be off, so that the
# program expects the five records written below instead of the four of the
# calibration contract. The time limit is not passed to the program: it is
# imposed by the `timeout` below, which is the only thing that enforces it.
export ILS_VERSION=run
export ILS_TUNING=0

echo "== $name, seed $seed, $tlim s"
cd "$run"
{
    echo "\"incumbent/\""
    echo "\"$instpath\""
    echo "\"$bks\""
    echo "$seed $seed"
    echo "$PARAM_1"
    echo "$PARAM_2"
} | timeout --foreground "$tlim" "$ils/ils-bcd" > run.log 2>&1
rc=$?
if [ $rc -ne 0 ] && [ $rc -ne 124 ]; then
    echo "run.sh: the program exited with code $rc; see $run/run.log" >&2
    tail -5 run.log >&2
    exit $rc
fi
[ $rc -eq 124 ] && echo "== stopped by the time limit"

# ------------------------------------------------------- tidy up the outputs
mv -f "ils-toursol/ils-sol-$name-seed$seed-run.dat"  tour.dat     2>/dev/null
mv -f "ils-toursol/ils-init-$name-seed$seed-run.dat" initial.dat  2>/dev/null
mv -f "tables/bench-$name.dat-seed$seed-run.csv"     summary.csv  2>/dev/null
mv -f "incumbent/$name.dat"                          incumbent.dat 2>/dev/null
rm -rf ils-toursol tables incumbent

if [ ! -f tour.dat ]; then
    echo "run.sh: the run produced no solution; see $run/run.log" >&2
    exit 1
fi

# ----------------------------------------------------------------- report it
cost=$(tail -1 tour.dat | awk '{print $1}')
printf '\n   tour length   %s\n' "$cost"
if [ $temgap -eq 1 ]; then
    # For the 235 converted instances the two reference values are the GTSP
    # tour and that same tour with the visit points recomputed by the BCD. For
    # Sao Paulo both are the length reported in the literature, and then one
    # line says it all.
    awk -v c="$cost" '{
        if ($2 == $3) printf "   vs reference  %+.4f%%\n", 100*(c-$2)/$2
        else printf "   vs GTSP tour  %+.4f%%\n   vs GTSP + BCD %+.4f%%\n", \
            100*(c-$2)/$2, 100*(c-$3)/$3
    }' "$bks"
fi
printf '   solution      out/%s/tour.dat\n' "$name-seed$seed"
printf '   trajectory    out/%s/incumbent.dat\n' "$name-seed$seed"
printf '   summary       out/%s/summary.csv\n' "$name-seed$seed"
rm -f "$bks"
