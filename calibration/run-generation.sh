#!/bin/bash
#
# Generates the calibration instances and validates them.
#
#   Usage:  calibration/run-generation.sh [--out <dir>]
#
#   --out <dir>   write under <dir> instead of work/calibration/
#
# It writes two sets:
#
#   all/    80 instances, 5 for each npol in {10,20,30,40} and 10 for each
#           npol in {50,...,100}. The 20 of calibration/train/ are the subset
#           named in calibration/train-order.txt.
#   test/   40 instances, 4 for each npol, from a different root seed.
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
        -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
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
