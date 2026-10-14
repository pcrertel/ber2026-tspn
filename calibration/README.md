# Calibration instances

This folder contains the programs that generate random TSPN instances from the
cluster profiles of GTSP instances, and the instances used to calibrate the
parameters of the ILS-BCD.

To generate them:

    calibration/run-generation.sh

It writes 80 instances to `work/calibration/all/` and 40 to
`work/calibration/test/`.

| | |
|---|---|
| `train/` | the 20 instances used for the calibration, a subset of the 80 the generator produces |
| `test/` | the 40 instances of the test set |
| `seeds.csv` | the seed of each instance, and the GTSP instance its cluster sizes came from |
| `train-order.txt` | the names in `train/`, in the order irace reads them |
| `generate_calibration.f90` | the generator |
| `cluster-profiles.dat` | the cluster sizes it draws from |
| `validate-instance.awk` | checks one instance |
