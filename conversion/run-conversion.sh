#!/bin/bash
#
# Rebuilds the 235 TSPN instances of this repository from the GTSP instances in
# instances/gtsp/, running the three conversion stages in order.
#
#   Usage:  conversion/run-conversion.sh [--out <dir>] [--khat <k>] [--figures]
#
#   --khat <k>     upper bound on the number of triangular slices carved out of
#                  each convex hull, which is the number of reflex vertices the
#                  neighbourhood may have (default 3, as in the paper); 0 keeps
#                  the convex hull, giving convex neighbourhoods
#   --out <dir>    write the instances under <dir> instead of over
#                  instances/tspn/, which is the way to compare a fresh run
#                  against the shipped instances without overwriting them
#   --figures      also write the MetaPost sources of the neighbourhood figures
#
# With no options it overwrites instances/tspn/ with freshly converted copies,
# which are byte-for-byte identical to the ones shipped.
#
# The two intermediate stages go to work/ under the output directory, which is
# scratch space recreated by every run.
#
# Requires gfortran.  Nothing else.
#
# A note on compiler flags.  Stage 3 compares a normalised triangle area
# against a tolerance to decide collinearity; the tolerance is what makes the
# decision stable, but flags that reassociate floating point arithmetic can
# still move a borderline case.  The shipped instances were produced with -O2
# as below.  Do not use -march=native, -ffast-math or -Ofast.

set -u

conv=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$conv/.." && pwd)
cd "$root"

outroot="$root"
khat=3
figures=0

while [ $# -gt 0 ]; do
    case "$1" in
        --out)     outroot=$(cd "$2" 2>/dev/null && pwd || echo "$2"); shift 2 ;;
        --khat)    khat=$2; shift 2 ;;
        --figures) figures=1; shift ;;
        -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
done

bin=$(mktemp -d)
trap 'rm -rf "$bin"' EXIT

echo "== compiling"
gfortran -O2 -Wall -J "$bin" "$conv/stage1_read_gtsp.f90"      -o "$bin/stage1" || exit 1
gfortran -O2 -Wall -J "$bin" "$conv/stage2_sort_by_angle.f90"  -o "$bin/stage2" || exit 1
gfortran -O2 -Wall -J "$bin" "$conv/stage3_build_polygons.f90" -o "$bin/stage3" || exit 1

export TSPN_KHAT=$khat
echo "== khat = $khat, output under $outroot"

total=0
failed=0

for list in instances/gtsp/selected-instances/*.txt; do
    lib=$(basename "$list" .txt)           # gtsplib | momlib

    s1="$outroot/work/stage1-gtsp-points/$lib"
    s2="$outroot/work/stage2-sorted-points/$lib"
    s3="$outroot/instances/tspn/$lib"
    fig="$outroot/figures/$lib"

    mkdir -p "$s1" "$s2" "$s3"
    [ $figures -eq 1 ] && mkdir -p "$fig"

    echo "== $lib ($(grep -c . "$list") instances)"

    while read -r inst; do
        [ -z "$inst" ] && continue
        case "$inst" in \#*) continue ;; esac
        src="instances/gtsp/$lib/$inst.gtsp"

        if [ ! -f "$src" ]; then
            echo "   MISSING SOURCE: $src" >&2
            failed=$((failed + 1)); continue
        fi
        if ! "$bin/stage1" "$src" "$s1" > /dev/null; then
            echo "   stage 1 failed: $inst" >&2; failed=$((failed + 1)); continue
        fi
        if ! "$bin/stage2" "$s1/$inst.dat" "$s2" > /dev/null; then
            echo "   stage 2 failed: $inst" >&2; failed=$((failed + 1)); continue
        fi
        if [ $figures -eq 1 ]; then
            "$bin/stage3" "$s2/$inst.dat" "$s3" "$fig" > /dev/null
        else
            "$bin/stage3" "$s2/$inst.dat" "$s3" > /dev/null
        fi
        if [ $? -ne 0 ]; then
            echo "   stage 3 failed: $inst" >&2; failed=$((failed + 1)); continue
        fi
        total=$((total + 1))
    done < "$list"
done

echo
echo "converted $total instances, $failed failures"
[ $failed -eq 0 ] || exit 1
