#!/bin/bash
#
# Regenerates the calibration instances and validates them.
#
#   Usage:  calibration/run-generation.sh [--out <dir>]
#
#   --out <dir>   write under <dir> instead of work/calibration/
#
# The generator produces two disjoint sets, both drawn by the procedure
# described in the paper:
#
#   all/    80 instances, 5 for each npol in {10,20,30,40} and 10 for each
#           npol in {50,...,100}. The 20 instances that irace actually used as
#           its training set are the subset listed in
#           instances/calibration/train-order.txt, and they are the ones
#           shipped under instances/calibration/train/.
#   test/   40 instances, 4 for each npol, from a different root seed. These
#           are exactly the ones shipped under instances/calibration/test/.
#
# Both sets come out byte-for-byte identical to the shipped files, which is
# what calibration/README.md explains how to check.
#
# Nothing is written over instances/; the output goes to scratch space.
#
# Requires gfortran, and awk for the validation step.

set -u

cal=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$cal/.." && pwd)
cd "$root"

outroot="$root/work/calibration"

while [ $# -gt 0 ]; do
    case "$1" in
        --out)     outroot=$2; shift 2 ;;
        -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
done

bin=$(mktemp -d)
trap 'rm -rf "$bin"' EXIT

echo "== compiling"
gfortran -O2 -Wall -J "$bin" "$cal/generate_calibration.f90" -o "$bin/generate" || exit 1

all="$outroot/all"
test="$outroot/test"
mkdir -p "$all" "$test"

echo "== generating the full design (80)"
"$bin/generate" "$cal/cluster-profiles.dat" "$all" || exit 1

echo "== generating the test set (40)"
"$bin/generate" "$cal/cluster-profiles.dat" "$test" 4 7654321 tst || exit 1

echo "== validating"
failed=0
total=0
for f in "$all"/*.dat "$test"/*.dat; do
    total=$((total + 1))
    line=$(awk -v FN="$f" -f "$cal/validate-instance.awk" "$f")
    case "$line" in
        *": OK "*) ;;
        *) echo "   $line"; failed=$((failed + 1)) ;;
    esac
done

echo
echo "generated and validated $total instances, $failed failures"
echo "output under $outroot"
[ $failed -eq 0 ] || exit 1
