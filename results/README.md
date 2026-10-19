# Results of the ILS-BCD

The best solution the ILS-BCD found on each of the 295 TSPN instances of this
repository, and on the instance of the city of São Paulo. Every instance was
solved in ten independent runs with different random seeds, with the
configuration listed in [`ils/README.md`](../ils/README.md). A run ends at its
CPU time limit or after 3,000 consecutive iterations without improving its
incumbent. The limit is 1,200 seconds for the 235 instances with at most 100
neighborhoods, which the table below reports, and 3,600 seconds for the 60
larger ones, reported in their own section.

The per-run data is under [`data/`](data/).

| Column | Meaning |
|---|---|
| `m` | number of polygonal neighborhoods |
| `GTSP tour length` | length of the best known tour of the GTSP instance the TSPN instance was built from |
| `Best tour length` | the shortest tour found across the ten runs |
| `Gap (%)` | 100 x (best - GTSP) / GTSP; negative means shorter than the GTSP tour |
| `Figure` | the best solution drawn: the tour in red, the visit points as red dots, the neighborhoods in grey |
| `Mean CPU time (s)` | mean total CPU time of the ten runs; a run stopped by the limit counts as 1,200 s |

The instances are ordered by the number of neighborhoods and, within each
value, by name, with the GTSP Lib and the MOM Lib ones together.

In six instances all the neighborhoods share a common point, so the shortest
tour has length zero and the gap is -100%. Those six are left out of the
average gap of the last row.

| Instance | *m* | GTSP tour length | Best tour length | Gap (%) | Figure | Mean CPU time (s) |
|---|---:|---:|---:|---:|:---:|---:|
| `8berlin52-2x4` | 8 | 2,665.59 | 2,611.70 | -2.022 | [pdf](figures/sol-8berlin52-2x4-ils.pdf) | 2.89 |
| `8i1000a` | 8 | 160.87 | 0.00 | -100.000 | [pdf](figures/sol-8i1000a-ils.pdf) | 0.09 |
| `8i1000h` | 8 | 1,181.05 | 1,179.09 | -0.166 | [pdf](figures/sol-8i1000h-ils.pdf) | 8.65 |
| `8i1000x1` | 8 | 1,180.96 | 1,179.09 | -0.158 | [pdf](figures/sol-8i1000x1-ils.pdf) | 8.66 |
| `8i1000x2` | 8 | 1,181.16 | 1,179.09 | -0.175 | [pdf](figures/sol-8i1000x2-ils.pdf) | 8.66 |
| `8i1000z` | 8 | 1,224.88 | 1,224.36 | -0.043 | [pdf](figures/sol-8i1000z-ils.pdf) | 8.54 |
| `8i600a` | 8 | 231.17 | 0.00 | -100.000 | [pdf](figures/sol-8i600a-ils.pdf) | 0.10 |
| `8i600h` | 8 | 1,248.72 | 1,247.57 | -0.092 | [pdf](figures/sol-8i600h-ils.pdf) | 8.33 |
| `8i600x1` | 8 | 1,217.30 | 1,216.29 | -0.084 | [pdf](figures/sol-8i600x1-ils.pdf) | 9.34 |
| `8i600x2` | 8 | 1,217.30 | 1,216.29 | -0.084 | [pdf](figures/sol-8i600x2-ils.pdf) | 8.20 |
| `8i600z` | 8 | 1,217.50 | 1,216.29 | -0.099 | [pdf](figures/sol-8i600z-ils.pdf) | 9.08 |
| `9a280-3x3` | 9 | 416.25 | 413.13 | -0.749 | [pdf](figures/sol-9a280-3x3-ils.pdf) | 5.88 |
| `9eil101-3x3` | 9 | 138.25 | 137.34 | -0.661 | [pdf](figures/sol-9eil101-3x3-ils.pdf) | 5.92 |
| `9eil51-3x3` | 9 | 143.69 | 142.91 | -0.543 | [pdf](figures/sol-9eil51-3x3-ils.pdf) | 3.20 |
| `9eil76-3x3` | 9 | 121.45 | 121.19 | -0.212 | [pdf](figures/sol-9eil76-3x3-ils.pdf) | 4.13 |
| `9gil262-3x3` | 9 | 338.61 | 338.48 | -0.039 | [pdf](figures/sol-9gil262-3x3-ils.pdf) | 6.02 |
| `9lin318-3x3` | 9 | 5,794.10 | 5,793.46 | -0.011 | [pdf](figures/sol-9lin318-3x3-ils.pdf) | 6.67 |
| `9pcb442-3x3` | 9 | 5,876.82 | 5,871.04 | -0.098 | [pdf](figures/sol-9pcb442-3x3-ils.pdf) | 5.94 |
| `9pr439-3x3` | 9 | 19,238.16 | 19,173.29 | -0.337 | [pdf](figures/sol-9pr439-3x3-ils.pdf) | 4.49 |
| `9pr76-3x3` | 9 | 30,845.93 | 30,812.95 | -0.107 | [pdf](figures/sol-9pr76-3x3-ils.pdf) | 3.65 |
| `9st70-3x3` | 9 | 189.72 | 189.24 | -0.255 | [pdf](figures/sol-9st70-3x3-ils.pdf) | 4.10 |
| `10C1k.0` | 10 | 2,522,583.76 | 2,521,444.96 | -0.045 | [pdf](figures/sol-10C1k.0-ils.pdf) | 4.64 |
| `10C1k.1` | 10 | 2,459,553.28 | 2,459,350.19 | -0.008 | [pdf](figures/sol-10C1k.1-ils.pdf) | 9.33 |
| `10C1k.2` | 10 | 2,588,529.00 | 2,585,796.88 | -0.105 | [pdf](figures/sol-10C1k.2-ils.pdf) | 5.64 |
| `10C1k.3` | 10 | 2,738,976.08 | 2,738,970.90 | -0.000 | [pdf](figures/sol-10C1k.3-ils.pdf) | 5.68 |
| `10C1k.4` | 10 | 2,470,678.65 | 2,468,933.16 | -0.071 | [pdf](figures/sol-10C1k.4-ils.pdf) | 7.35 |
| `10C1k.5` | 10 | 2,165,332.93 | 2,163,545.92 | -0.083 | [pdf](figures/sol-10C1k.5-ils.pdf) | 9.91 |
| `10C1k.6` | 10 | 1,875,129.38 | 1,872,449.54 | -0.143 | [pdf](figures/sol-10C1k.6-ils.pdf) | 10.71 |
| `10C1k.7` | 10 | 2,091,613.24 | 2,090,284.21 | -0.064 | [pdf](figures/sol-10C1k.7-ils.pdf) | 8.98 |
| `10C1k.8` | 10 | 2,583,453.61 | 2,583,396.60 | -0.002 | [pdf](figures/sol-10C1k.8-ils.pdf) | 5.56 |
| `10C1k.9` | 10 | 2,242,795.80 | 2,241,859.90 | -0.042 | [pdf](figures/sol-10C1k.9-ils.pdf) | 4.52 |
| `10a280` | 10 | 429.91 | 429.55 | -0.082 | [pdf](figures/sol-10a280-ils.pdf) | 8.63 |
| `10att48` | 10 | 17,045.81 | 17,008.70 | -0.218 | [pdf](figures/sol-10att48-ils.pdf) | 5.42 |
| `10berlin52` | 10 | 3,223.39 | 3,216.83 | -0.203 | [pdf](figures/sol-10berlin52-ils.pdf) | 3.20 |
| `10berlin52-2x5` | 10 | 3,184.86 | 3,129.98 | -1.723 | [pdf](figures/sol-10berlin52-2x5-ils.pdf) | 2.34 |
| `10eil51` | 10 | 145.27 | 144.43 | -0.573 | [pdf](figures/sol-10eil51-ils.pdf) | 3.40 |
| `10eil76` | 10 | 128.65 | 126.78 | -1.455 | [pdf](figures/sol-10eil76-ils.pdf) | 4.57 |
| `10gil262` | 10 | 373.17 | 372.02 | -0.309 | [pdf](figures/sol-10gil262-ils.pdf) | 8.03 |
| `10i1000-407` | 10 | 2,261.40 | 2,259.80 | -0.071 | [pdf](figures/sol-10i1000-407-ils.pdf) | 5.84 |
| `10i120-46` | 10 | 2,412.13 | 2,403.97 | -0.338 | [pdf](figures/sol-10i120-46-ils.pdf) | 3.50 |
| `10i1400a` | 10 | 190.29 | 0.00 | -100.000 | [pdf](figures/sol-10i1400a-ils.pdf) | 0.11 |
| `10i1400h` | 10 | 1,409.42 | 1,407.87 | -0.110 | [pdf](figures/sol-10i1400h-ils.pdf) | 11.99 |
| `10i1400x1` | 10 | 1,409.56 | 1,407.87 | -0.120 | [pdf](figures/sol-10i1400x1-ils.pdf) | 11.88 |
| `10i1400x2` | 10 | 1,387.13 | 1,383.24 | -0.280 | [pdf](figures/sol-10i1400x2-ils.pdf) | 13.09 |
| `10i1400z` | 10 | 1,387.28 | 1,383.24 | -0.291 | [pdf](figures/sol-10i1400z-ils.pdf) | 11.90 |
| `10i1500-503` | 10 | 1,536.78 | 1,536.14 | -0.042 | [pdf](figures/sol-10i1500-503-ils.pdf) | 5.74 |
| `10i2000a` | 10 | 148.88 | 0.00 | -100.000 | [pdf](figures/sol-10i2000a-ils.pdf) | 0.17 |
| `10i2000h` | 10 | 1,283.77 | 1,279.84 | -0.306 | [pdf](figures/sol-10i2000h-ils.pdf) | 9.45 |
| `10i2000x1` | 10 | 1,297.29 | 1,291.25 | -0.465 | [pdf](figures/sol-10i2000x1-ils.pdf) | 11.60 |
| `10i2000x2` | 10 | 1,303.17 | 1,300.49 | -0.205 | [pdf](figures/sol-10i2000x2-ils.pdf) | 11.16 |
| `10i2000z` | 10 | 1,303.79 | 1,300.49 | -0.253 | [pdf](figures/sol-10i2000z-ils.pdf) | 10.46 |
| `10i30-17` | 10 | 1,527.51 | 1,495.61 | -2.088 | [pdf](figures/sol-10i30-17-ils.pdf) | 1.48 |
| `10i300-109` | 10 | 1,358.19 | 1,355.39 | -0.206 | [pdf](figures/sol-10i300-109-ils.pdf) | 4.95 |
| `10i400-206` | 10 | 1,981.51 | 1,976.07 | -0.274 | [pdf](figures/sol-10i400-206-ils.pdf) | 7.07 |
| `10i45-18` | 10 | 1,630.85 | 1,536.30 | -5.798 | [pdf](figures/sol-10i45-18-ils.pdf) | 4.33 |
| `10i500-305` | 10 | 2,199.91 | 2,198.35 | -0.071 | [pdf](figures/sol-10i500-305-ils.pdf) | 3.00 |
| `10i60-21` | 10 | 1,797.63 | 1,748.97 | -2.707 | [pdf](figures/sol-10i60-21-ils.pdf) | 4.79 |
| `10i65-21` | 10 | 1,757.94 | 1,694.31 | -3.619 | [pdf](figures/sol-10i65-21-ils.pdf) | 5.46 |
| `10i70-21` | 10 | 1,785.30 | 1,722.76 | -3.503 | [pdf](figures/sol-10i70-21-ils.pdf) | 6.74 |
| `10i75-22` | 10 | 2,784.07 | 2,758.09 | -0.933 | [pdf](figures/sol-10i75-22-ils.pdf) | 5.32 |
| `10i90-33` | 10 | 1,570.45 | 1,539.45 | -1.974 | [pdf](figures/sol-10i90-33-ils.pdf) | 10.98 |
| `10kroB100` | 10 | 5,921.39 | 5,910.43 | -0.185 | [pdf](figures/sol-10kroB100-ils.pdf) | 4.00 |
| `10lin318` | 10 | 6,890.69 | 6,875.83 | -0.216 | [pdf](figures/sol-10lin318-ils.pdf) | 6.92 |
| `10nrw1379-2x5` | 10 | 3,312.40 | 3,311.29 | -0.034 | [pdf](figures/sol-10nrw1379-2x5-ils.pdf) | 8.38 |
| `10pcb442` | 10 | 5,889.12 | 5,879.36 | -0.166 | [pdf](figures/sol-10pcb442-ils.pdf) | 6.55 |
| `10pr439` | 10 | 18,284.86 | 18,283.14 | -0.009 | [pdf](figures/sol-10pr439-ils.pdf) | 3.88 |
| `10pr76` | 10 | 35,794.88 | 35,745.19 | -0.139 | [pdf](figures/sol-10pr76-ils.pdf) | 4.43 |
| `10rat99` | 10 | 325.39 | 324.13 | -0.386 | [pdf](figures/sol-10rat99-ils.pdf) | 7.08 |
| `10st70` | 10 | 212.48 | 212.04 | -0.208 | [pdf](figures/sol-10st70-ils.pdf) | 3.37 |
| `11berlin52` | 11 | 4,039.76 | 4,028.73 | -0.273 | [pdf](figures/sol-11berlin52-ils.pdf) | 3.72 |
| `11eil51` | 11 | 174.58 | 173.37 | -0.696 | [pdf](figures/sol-11eil51-ils.pdf) | 5.63 |
| `12eil51-3x4` | 12 | 163.14 | 162.32 | -0.507 | [pdf](figures/sol-12eil51-3x4-ils.pdf) | 6.31 |
| `12eil76-3x4` | 12 | 154.29 | 153.64 | -0.420 | [pdf](figures/sol-12eil76-3x4-ils.pdf) | 8.56 |
| `12nrw1379-2x6` | 12 | 3,880.87 | 3,877.96 | -0.075 | [pdf](figures/sol-12nrw1379-2x6-ils.pdf) | 15.35 |
| `12nrw1379-3x4` | 12 | 4,200.21 | 4,198.94 | -0.030 | [pdf](figures/sol-12nrw1379-3x4-ils.pdf) | 17.89 |
| `12pr76-3x4` | 12 | 36,633.07 | 36,605.81 | -0.074 | [pdf](figures/sol-12pr76-3x4-ils.pdf) | 7.38 |
| `12st70-3x4` | 12 | 211.20 | 211.07 | -0.060 | [pdf](figures/sol-12st70-3x4-ils.pdf) | 5.49 |
| `14st70` | 14 | 317.58 | 316.15 | -0.451 | [pdf](figures/sol-14st70-ils.pdf) | 12.45 |
| `15berlin52` | 15 | 4,689.98 | 4,685.03 | -0.106 | [pdf](figures/sol-15berlin52-ils.pdf) | 9.27 |
| `15eil51` | 15 | 203.52 | 202.03 | -0.732 | [pdf](figures/sol-15eil51-ils.pdf) | 10.45 |
| `15eil76` | 15 | 185.81 | 184.31 | -0.808 | [pdf](figures/sol-15eil76-ils.pdf) | 13.96 |
| `15i300-110` | 15 | 1,972.26 | 1,970.06 | -0.111 | [pdf](figures/sol-15i300-110-ils.pdf) | 21.67 |
| `15i400-207` | 15 | 2,263.63 | 2,261.86 | -0.079 | [pdf](figures/sol-15i400-207-ils.pdf) | 11.69 |
| `15i500-306` | 15 | 2,489.88 | 2,475.56 | -0.575 | [pdf](figures/sol-15i500-306-ils.pdf) | 12.07 |
| `15pr76` | 15 | 52,154.84 | 52,109.69 | -0.087 | [pdf](figures/sol-15pr76-ils.pdf) | 16.47 |
| `15pr76-3x5` | 15 | 40,202.37 | 40,123.03 | -0.197 | [pdf](figures/sol-15pr76-3x5-ils.pdf) | 10.47 |
| `15st70` | 15 | 249.76 | 249.01 | -0.300 | [pdf](figures/sol-15st70-ils.pdf) | 7.27 |
| `16eil51-4x4` | 16 | 174.94 | 174.69 | -0.142 | [pdf](figures/sol-16eil51-4x4-ils.pdf) | 8.98 |
| `16eil76` | 16 | 209.89 | 208.01 | -0.897 | [pdf](figures/sol-16eil76-ils.pdf) | 16.54 |
| `16eil76-4x4` | 16 | 203.84 | 199.45 | -2.155 | [pdf](figures/sol-16eil76-4x4-ils.pdf) | 19.34 |
| `16lin105-4x4` | 16 | 5,959.58 | 5,918.61 | -0.688 | [pdf](figures/sol-16lin105-4x4-ils.pdf) | 13.89 |
| `16pr76` | 16 | 64,925.40 | 64,856.17 | -0.107 | [pdf](figures/sol-16pr76-ils.pdf) | 19.07 |
| `16st70-4x4` | 16 | 257.34 | 252.77 | -1.776 | [pdf](figures/sol-16st70-4x4-ils.pdf) | 13.72 |
| `18pr439-3x6` | 18 | 29,343.37 | 29,153.91 | -0.646 | [pdf](figures/sol-18pr439-3x6-ils.pdf) | 20.71 |
| `18pr76-3x6` | 18 | 44,135.50 | 43,776.79 | -0.813 | [pdf](figures/sol-18pr76-3x6-ils.pdf) | 19.02 |
| `20eil51-4x5` | 20 | 220.07 | 219.33 | -0.337 | [pdf](figures/sol-20eil51-4x5-ils.pdf) | 12.77 |
| `20eil76-4x5` | 20 | 220.98 | 220.80 | -0.080 | [pdf](figures/sol-20eil76-4x5-ils.pdf) | 26.34 |
| `20i1000-408` | 20 | 2,901.28 | 2,896.42 | -0.168 | [pdf](figures/sol-20i1000-408-ils.pdf) | 53.44 |
| `20i1500-504` | 20 | 2,744.31 | 2,742.15 | -0.079 | [pdf](figures/sol-20i1500-504-ils.pdf) | 41.07 |
| `20i2000-602` | 20 | 3,104.05 | 3,103.45 | -0.019 | [pdf](figures/sol-20i2000-602-ils.pdf) | 40.00 |
| `20i2400a` | 20 | 331.11 | 0.00 | -100.000 | [pdf](figures/sol-20i2400a-ils.pdf) | 1.44 |
| `20i2400h` | 20 | 1,688.82 | 1,686.41 | -0.143 | [pdf](figures/sol-20i2400h-ils.pdf) | 88.24 |
| `20i2400x1` | 20 | 1,708.38 | 1,704.91 | -0.203 | [pdf](figures/sol-20i2400x1-ils.pdf) | 63.27 |
| `20i2400x2` | 20 | 1,708.56 | 1,704.91 | -0.214 | [pdf](figures/sol-20i2400x2-ils.pdf) | 67.38 |
| `20i2400z` | 20 | 1,724.95 | 1,723.07 | -0.109 | [pdf](figures/sol-20i2400z-ils.pdf) | 86.83 |
| `20i2500-706` | 20 | 3,463.94 | 3,462.89 | -0.030 | [pdf](figures/sol-20i2500-706-ils.pdf) | 44.78 |
| `20i300-111` | 20 | 3,280.61 | 3,274.44 | -0.188 | [pdf](figures/sol-20i300-111-ils.pdf) | 75.24 |
| `20i3000-801` | 20 | 3,628.94 | 3,627.03 | -0.052 | [pdf](figures/sol-20i3000-801-ils.pdf) | 45.09 |
| `20i3000a` | 20 | 270.51 | 0.00 | -100.000 | [pdf](figures/sol-20i3000a-ils.pdf) | 1.41 |
| `20i3000h` | 20 | 1,714.21 | 1,708.86 | -0.312 | [pdf](figures/sol-20i3000h-ils.pdf) | 120.61 |
| `20i3000x1` | 20 | 1,674.72 | 1,671.49 | -0.193 | [pdf](figures/sol-20i3000x1-ils.pdf) | 62.68 |
| `20i3000x2` | 20 | 1,673.66 | 1,671.49 | -0.130 | [pdf](figures/sol-20i3000x2-ils.pdf) | 53.24 |
| `20i3000z` | 20 | 1,663.35 | 1,660.99 | -0.142 | [pdf](figures/sol-20i3000z-ils.pdf) | 60.17 |
| `20i400-208` | 20 | 2,931.25 | 2,925.76 | -0.187 | [pdf](figures/sol-20i400-208-ils.pdf) | 41.49 |
| `20i500-307` | 20 | 2,650.48 | 2,637.90 | -0.474 | [pdf](figures/sol-20i500-307-ils.pdf) | 49.02 |
| `20i550` | 20 | 524.48 | 521.74 | -0.521 | [pdf](figures/sol-20i550-ils.pdf) | 47.41 |
| `20i600` | 20 | 517.95 | 516.53 | -0.276 | [pdf](figures/sol-20i600-ils.pdf) | 45.99 |
| `20i650` | 20 | 505.45 | 503.68 | -0.350 | [pdf](figures/sol-20i650-ils.pdf) | 48.69 |
| `20i700` | 20 | 502.06 | 499.47 | -0.516 | [pdf](figures/sol-20i700-ils.pdf) | 49.36 |
| `20kroA100` | 20 | 9,712.41 | 9,692.81 | -0.202 | [pdf](figures/sol-20kroA100-ils.pdf) | 27.07 |
| `20kroB100` | 20 | 10,327.63 | 10,289.59 | -0.368 | [pdf](figures/sol-20kroB100-ils.pdf) | 28.94 |
| `20kroC100` | 20 | 9,554.08 | 9,529.96 | -0.252 | [pdf](figures/sol-20kroC100-ils.pdf) | 25.92 |
| `20kroD100` | 20 | 9,450.60 | 9,431.31 | -0.204 | [pdf](figures/sol-20kroD100-ils.pdf) | 30.53 |
| `20kroE100` | 20 | 9,522.93 | 9,485.06 | -0.398 | [pdf](figures/sol-20kroE100-ils.pdf) | 30.04 |
| `20pr439-4x5` | 20 | 26,399.72 | 26,398.66 | -0.004 | [pdf](figures/sol-20pr439-4x5-ils.pdf) | 40.66 |
| `20rat99` | 20 | 498.93 | 498.47 | -0.092 | [pdf](figures/sol-20rat99-ils.pdf) | 36.64 |
| `20rd100` | 20 | 3,648.27 | 3,644.48 | -0.104 | [pdf](figures/sol-20rd100-ils.pdf) | 22.17 |
| `20st70-4x5` | 20 | 298.06 | 295.18 | -0.968 | [pdf](figures/sol-20st70-4x5-ils.pdf) | 16.61 |
| `21eil101` | 21 | 249.62 | 246.78 | -1.141 | [pdf](figures/sol-21eil101-ils.pdf) | 36.00 |
| `21lin105` | 21 | 8,212.36 | 8,202.83 | -0.116 | [pdf](figures/sol-21lin105-ils.pdf) | 22.26 |
| `22pr107` | 22 | 27,898.12 | 27,879.67 | -0.066 | [pdf](figures/sol-22pr107-ils.pdf) | 19.43 |
| `25a280` | 25 | 648.62 | 643.13 | -0.848 | [pdf](figures/sol-25a280-ils.pdf) | 113.57 |
| `25a280-5x5` | 25 | 642.42 | 641.42 | -0.156 | [pdf](figures/sol-25a280-5x5-ils.pdf) | 83.47 |
| `25eil101` | 25 | 239.31 | 236.84 | -1.034 | [pdf](figures/sol-25eil101-ils.pdf) | 62.08 |
| `25eil101-5x5` | 25 | 257.03 | 254.95 | -0.809 | [pdf](figures/sol-25eil101-5x5-ils.pdf) | 69.50 |
| `25eil51-5x5` | 25 | 254.10 | 250.87 | -1.270 | [pdf](figures/sol-25eil51-5x5-ils.pdf) | 19.99 |
| `25eil76-5x5` | 25 | 258.50 | 257.19 | -0.509 | [pdf](figures/sol-25eil76-5x5-ils.pdf) | 40.17 |
| `25gil262` | 25 | 678.80 | 674.39 | -0.650 | [pdf](figures/sol-25gil262-ils.pdf) | 94.25 |
| `25gil262-5x5` | 25 | 613.79 | 610.54 | -0.529 | [pdf](figures/sol-25gil262-5x5-ils.pdf) | 131.85 |
| `25i300-112` | 25 | 2,660.51 | 2,617.92 | -1.601 | [pdf](figures/sol-25i300-112-ils.pdf) | 71.56 |
| `25i400-209` | 25 | 2,860.52 | 2,848.71 | -0.413 | [pdf](figures/sol-25i400-209-ils.pdf) | 87.22 |
| `25i500-308` | 25 | 3,000.25 | 2,990.64 | -0.320 | [pdf](figures/sol-25i500-308-ils.pdf) | 64.63 |
| `25i750` | 25 | 535.75 | 533.19 | -0.477 | [pdf](figures/sol-25i750-ils.pdf) | 102.78 |
| `25i850` | 25 | 524.88 | 521.35 | -0.673 | [pdf](figures/sol-25i850-ils.pdf) | 113.66 |
| `25i900` | 25 | 521.48 | 519.84 | -0.314 | [pdf](figures/sol-25i900-ils.pdf) | 113.59 |
| `25kroA100` | 25 | 10,430.45 | 10,391.04 | -0.378 | [pdf](figures/sol-25kroA100-ils.pdf) | 33.94 |
| `25kroB100-5x5` | 25 | 9,808.86 | 9,753.52 | -0.564 | [pdf](figures/sol-25kroB100-5x5-ils.pdf) | 40.58 |
| `25lin105` | 25 | 8,226.06 | 8,225.99 | -0.001 | [pdf](figures/sol-25lin105-ils.pdf) | 32.34 |
| `25lin318` | 25 | 11,722.53 | 11,716.23 | -0.054 | [pdf](figures/sol-25lin318-ils.pdf) | 87.09 |
| `25lin318-5x5` | 25 | 10,283.59 | 10,268.48 | -0.147 | [pdf](figures/sol-25lin318-5x5-ils.pdf) | 102.58 |
| `25pcb442` | 25 | 10,121.54 | 10,105.64 | -0.157 | [pdf](figures/sol-25pcb442-ils.pdf) | 125.43 |
| `25pcb442-5x5` | 25 | 10,063.00 | 10,060.34 | -0.026 | [pdf](figures/sol-25pcb442-5x5-ils.pdf) | 154.87 |
| `25pr124` | 25 | 36,605.82 | 36,564.91 | -0.112 | [pdf](figures/sol-25pr124-ils.pdf) | 46.18 |
| `25pr439` | 25 | 33,750.89 | 33,589.16 | -0.479 | [pdf](figures/sol-25pr439-ils.pdf) | 134.69 |
| `25rat99` | 25 | 510.40 | 506.00 | -0.863 | [pdf](figures/sol-25rat99-ils.pdf) | 39.08 |
| `25rat99-5x5` | 25 | 482.66 | 480.27 | -0.495 | [pdf](figures/sol-25rat99-5x5-ils.pdf) | 58.21 |
| `26bier127` | 26 | 72,416.01 | 72,298.09 | -0.163 | [pdf](figures/sol-26bier127-ils.pdf) | 43.91 |
| `26ch130` | 26 | 2,828.13 | 2,822.97 | -0.182 | [pdf](figures/sol-26ch130-ils.pdf) | 70.34 |
| `28kroA100-4x7` | 28 | 10,605.44 | 10,260.51 | -3.252 | [pdf](figures/sol-28kroA100-4x7-ils.pdf) | 36.17 |
| `28pr136` | 28 | 42,571.08 | 42,461.57 | -0.257 | [pdf](figures/sol-28pr136-ils.pdf) | 75.39 |
| `29pr144` | 29 | 45,887.24 | 45,875.04 | -0.027 | [pdf](figures/sol-29pr144-ils.pdf) | 27.74 |
| `30ch150` | 30 | 2,748.26 | 2,734.95 | -0.484 | [pdf](figures/sol-30ch150-ils.pdf) | 120.63 |
| `30i1000` | 30 | 555.09 | 552.75 | -0.421 | [pdf](figures/sol-30i1000-ils.pdf) | 225.83 |
| `30i950` | 30 | 559.25 | 557.82 | -0.255 | [pdf](figures/sol-30i950-ils.pdf) | 196.68 |
| `30kroA150` | 30 | 11,018.83 | 10,958.58 | -0.547 | [pdf](figures/sol-30kroA150-ils.pdf) | 66.01 |
| `30kroB100-5x6` | 30 | 11,459.24 | 11,240.44 | -1.909 | [pdf](figures/sol-30kroB100-5x6-ils.pdf) | 83.00 |
| `30kroB150` | 30 | 12,195.11 | 12,139.47 | -0.456 | [pdf](figures/sol-30kroB150-ils.pdf) | 75.34 |
| `31C3k.0` | 31 | 3,553,144.85 | 3,553,075.35 | -0.002 | [pdf](figures/sol-31C3k.0-ils.pdf) | 129.52 |
| `31pr152` | 31 | 51,573.74 | 51,463.73 | -0.213 | [pdf](figures/sol-31pr152-ils.pdf) | 60.04 |
| `32u159` | 32 | 22,664.06 | 22,615.99 | -0.212 | [pdf](figures/sol-32u159-ils.pdf) | 75.63 |
| `36eil101-6x6` | 36 | 306.14 | 301.96 | -1.367 | [pdf](figures/sol-36eil101-6x6-ils.pdf) | 103.42 |
| `36pcb442-6x6` | 36 | 11,470.47 | 11,461.84 | -0.075 | [pdf](figures/sol-36pcb442-6x6-ils.pdf) | 263.07 |
| `36pr1002-6x6` | 36 | 41,972.34 | 41,917.86 | -0.130 | [pdf](figures/sol-36pr1002-6x6-ils.pdf) | 550.37 |
| `39rat195` | 39 | 857.99 | 853.55 | -0.517 | [pdf](figures/sol-39rat195-ils.pdf) | 232.80 |
| `40d198` | 40 | 10,555.60 | 10,539.70 | -0.151 | [pdf](figures/sol-40d198-ils.pdf) | 150.45 |
| `40kroA200` | 40 | 13,408.22 | 13,358.59 | -0.370 | [pdf](figures/sol-40kroA200-ils.pdf) | 183.78 |
| `40kroB200` | 40 | 13,113.27 | 13,073.19 | -0.306 | [pdf](figures/sol-40kroB200-ils.pdf) | 249.49 |
| `42a280-6x7` | 42 | 887.02 | 884.79 | -0.251 | [pdf](figures/sol-42a280-6x7-ils.pdf) | 253.59 |
| `42pr1002-6x7` | 42 | 44,112.94 | 44,037.14 | -0.172 | [pdf](figures/sol-42pr1002-6x7-ils.pdf) | 688.22 |
| `42rat99-6x7` | 42 | 682.55 | 674.95 | -1.113 | [pdf](figures/sol-42rat99-6x7-ils.pdf) | 116.67 |
| `45ts225` | 45 | 68,340.09 | 68,088.60 | -0.368 | [pdf](figures/sol-45ts225-ils.pdf) | 160.45 |
| `45tsp225` | 45 | 1,607.75 | 1,604.52 | -0.201 | [pdf](figures/sol-45tsp225-ils.pdf) | 338.40 |
| `46pr226` | 46 | 64,007.16 | 64,007.16 | 0.000 | [pdf](figures/sol-46pr226-ils.pdf) | 73.11 |
| `49gil262-7x7` | 49 | 923.59 | 919.77 | -0.414 | [pdf](figures/sol-49gil262-7x7-ils.pdf) | 512.45 |
| `49lin318-7x7` | 49 | 16,724.53 | 16,698.24 | -0.157 | [pdf](figures/sol-49lin318-7x7-ils.pdf) | 367.23 |
| `49pcb1173-7x7` | 49 | 9,065.00 | 9,060.76 | -0.047 | [pdf](figures/sol-49pcb1173-7x7-ils.pdf) | 1,180.12 |
| `49pr1002-7x7` | 49 | 52,825.85 | 52,804.03 | -0.041 | [pdf](figures/sol-49pr1002-7x7-ils.pdf) | 934.25 |
| `49rat783-7x7` | 49 | 1,538.48 | 1,534.24 | -0.276 | [pdf](figures/sol-49rat783-7x7-ils.pdf) | 1,097.47 |
| `49vm1084-7x7` | 49 | 52,353.26 | 52,177.05 | -0.337 | [pdf](figures/sol-49vm1084-7x7-ils.pdf) | 933.02 |
| `50a280` | 50 | 1,022.89 | 1,016.55 | -0.621 | [pdf](figures/sol-50a280-ils.pdf) | 338.50 |
| `50eil101` | 50 | 401.68 | 399.48 | -0.549 | [pdf](figures/sol-50eil101-ils.pdf) | 110.07 |
| `50gil262` | 50 | 960.66 | 956.90 | -0.392 | [pdf](figures/sol-50gil262-ils.pdf) | 391.51 |
| `50i1000-409` | 50 | 4,224.54 | 4,203.45 | -0.499 | [pdf](figures/sol-50i1000-409-ils.pdf) | 521.58 |
| `50i1500-505` | 50 | 4,165.30 | 4,154.98 | -0.248 | [pdf](figures/sol-50i1500-505-ils.pdf) | 507.06 |
| `50i2000-603` | 50 | 4,332.26 | 4,319.61 | -0.292 | [pdf](figures/sol-50i2000-603-ils.pdf) | 623.04 |
| `50i2500-707` | 50 | 3,970.97 | 3,961.24 | -0.245 | [pdf](figures/sol-50i2500-707-ils.pdf) | 452.10 |
| `50i3000-802` | 50 | 4,080.35 | 4,076.57 | -0.093 | [pdf](figures/sol-50i3000-802-ils.pdf) | 527.42 |
| `50kroA100` | 50 | 15,943.69 | 15,922.35 | -0.134 | [pdf](figures/sol-50kroA100-ils.pdf) | 71.92 |
| `50kroB100` | 50 | 15,843.93 | 15,805.88 | -0.240 | [pdf](figures/sol-50kroB100-ils.pdf) | 89.94 |
| `50lin105` | 50 | 11,296.33 | 11,269.96 | -0.233 | [pdf](figures/sol-50lin105-ils.pdf) | 95.42 |
| `50lin318` | 50 | 18,164.25 | 18,117.51 | -0.257 | [pdf](figures/sol-50lin318-ils.pdf) | 409.00 |
| `50nrw1379` | 50 | 7,452.87 | 7,428.79 | -0.323 | [pdf](figures/sol-50nrw1379-ils.pdf) | 1,193.36 |
| `50pcb1173` | 50 | 9,386.23 | 9,379.75 | -0.069 | [pdf](figures/sol-50pcb1173-ils.pdf) | 1,151.30 |
| `50pcb442` | 50 | 14,433.71 | 14,399.79 | -0.235 | [pdf](figures/sol-50pcb442-ils.pdf) | 492.23 |
| `50pr1002` | 50 | 54,588.37 | 54,397.25 | -0.350 | [pdf](figures/sol-50pr1002-ils.pdf) | 955.98 |
| `50pr439` | 50 | 45,252.03 | 45,139.97 | -0.248 | [pdf](figures/sol-50pr439-ils.pdf) | 493.09 |
| `50rat783` | 50 | 1,631.61 | 1,624.65 | -0.426 | [pdf](figures/sol-50rat783-ils.pdf) | 1,107.38 |
| `50rat99` | 50 | 817.06 | 813.63 | -0.420 | [pdf](figures/sol-50rat99-ils.pdf) | 185.75 |
| `50vm1084` | 50 | 54,153.47 | 54,035.82 | -0.217 | [pdf](figures/sol-50vm1084-ils.pdf) | 743.90 |
| `53gil262` | 53 | 1,018.58 | 1,011.36 | -0.709 | [pdf](figures/sol-53gil262-ils.pdf) | 509.21 |
| `53pr264` | 53 | 29,546.39 | 29,509.27 | -0.126 | [pdf](figures/sol-53pr264-ils.pdf) | 285.32 |
| `56a280` | 56 | 1,082.83 | 1,074.98 | -0.725 | [pdf](figures/sol-56a280-ils.pdf) | 492.97 |
| `60pr299` | 60 | 22,617.72 | 22,555.92 | -0.273 | [pdf](figures/sol-60pr299-ils.pdf) | 579.74 |
| `64lin318` | 64 | 20,769.32 | 20,752.04 | -0.083 | [pdf](figures/sol-64lin318-ils.pdf) | 560.78 |
| `72vm1084-8x9` | 72 | 64,647.96 | 63,987.02 | -1.022 | [pdf](figures/sol-72vm1084-8x9-ils.pdf) | 1,200.00 |
| `75lin105` | 75 | 13,135.88 | 13,132.09 | -0.029 | [pdf](figures/sol-75lin105-ils.pdf) | 107.12 |
| `80rd400` | 80 | 6,357.87 | 6,345.87 | -0.189 | [pdf](figures/sol-80rd400-ils.pdf) | 1,170.36 |
| `81vm1084-9x9` | 81 | 69,661.05 | 69,398.05 | -0.378 | [pdf](figures/sol-81vm1084-9x9-ils.pdf) | 1,200.00 |
| `84fl417` | 84 | 9,662.20 | 9,658.52 | -0.038 | [pdf](figures/sol-84fl417-ils.pdf) | 491.94 |
| `88pr439` | 88 | 60,098.71 | 59,982.05 | -0.194 | [pdf](figures/sol-88pr439-ils.pdf) | 1,161.89 |
| `89pcb442` | 89 | 21,657.56 | 21,617.07 | -0.187 | [pdf](figures/sol-89pcb442-ils.pdf) | 1,192.33 |
| `99d493` | 99 | 20,022.42 | 19,996.60 | -0.129 | [pdf](figures/sol-99d493-ils.pdf) | 1,200.00 |
| `100C10k.0` | 100 | 6,158,997.46 | 6,153,418.28 | -0.091 | [pdf](figures/sol-100C10k.0-ils.pdf) | 1,200.00 |
| `100i1000-410` | 100 | 5,485.63 | 5,416.93 | -1.252 | [pdf](figures/sol-100i1000-410-ils.pdf) | 1,200.00 |
| `100i1500-506` | 100 | 5,098.26 | 5,051.46 | -0.918 | [pdf](figures/sol-100i1500-506-ils.pdf) | 1,200.00 |
| `100i2000-604` | 100 | 5,330.36 | 5,307.75 | -0.424 | [pdf](figures/sol-100i2000-604-ils.pdf) | 1,200.00 |
| `100i2500-708` | 100 | 5,312.87 | 5,286.66 | -0.493 | [pdf](figures/sol-100i2500-708-ils.pdf) | 1,200.00 |
| `100i3000-803` | 100 | 5,471.65 | 5,456.51 | -0.277 | [pdf](figures/sol-100i3000-803-ils.pdf) | 1,200.00 |
| `100nrw1379` | 100 | 10,567.21 | 10,552.41 | -0.140 | [pdf](figures/sol-100nrw1379-ils.pdf) | 1,200.00 |
| `100pcb1173` | 100 | 13,904.81 | 13,872.48 | -0.233 | [pdf](figures/sol-100pcb1173-ils.pdf) | 1,200.00 |
| `100pcb1173-10x10` | 100 | 12,647.12 | 12,619.98 | -0.215 | [pdf](figures/sol-100pcb1173-10x10-ils.pdf) | 1,200.00 |
| `100pr1002` | 100 | 74,270.06 | 73,995.15 | -0.370 | [pdf](figures/sol-100pr1002-ils.pdf) | 1,200.00 |
| `100rat783` | 100 | 2,505.22 | 2,496.73 | -0.339 | [pdf](figures/sol-100rat783-ils.pdf) | 1,200.00 |
| `100rat783-10x10` | 100 | 2,228.82 | 2,218.94 | -0.444 | [pdf](figures/sol-100rat783-10x10-ils.pdf) | 1,200.00 |
| `100vm1084` | 100 | 78,443.76 | 78,058.98 | -0.490 | [pdf](figures/sol-100vm1084-ils.pdf) | 1,200.00 |
| **Average** | **29** | **152,345.66** | **152,232.20** | **-0.441** | | **213.77** |

## São Paulo

The instance of the 96 districts of the city of São Paulo, from
[\[3\]](../README.md#instance-references). The ten runs start from the initial
solution of the constructive heuristic of that paper, and the gap is measured
against the tour length reported there, since this instance does not come from
a GTSP instance.

| Instance | *m* | Reported tour length | Best tour length | Gap (%) | Figure | Mean CPU time (s) |
|---|---:|---:|---:|---:|:---:|---:|
| `96sp4966` | 96 | 212,292.01 | 199,362.73 | -6.090 | [pdf](figures/sol-96sp4966-ils.pdf) | 1,200.00 |

All ten runs reached the time limit. Eight returned a tour between 199,362.73 and 199,362.78, and the other two 199,390.36 and 199,637.10.

## Instances with more than 100 neighborhoods

The 60 instances with between 115 and 6,325 neighborhoods, each solved in ten
runs with a CPU time limit of 3,600 seconds. The columns are those of the table
above; a run stopped by the limit counts as 3,600 s in the mean CPU time. The
per-run data is in [`data/sweep_summary_large.csv`](data/sweep_summary_large.csv).

The ILS-BCD returns a shorter tour than the GTSP one on 28 of the 60. The gap
turns positive beyond about 220 neighborhoods and grows from there.

Figures are given up to 220 neighborhoods. Above that size the drawing is a
dense mass of polygons and shows nothing useful.

| Instance | *m* | GTSP tour length | Best tour length | Gap (%) | Figure | Mean CPU time (s) |
|---|---:|---:|---:|---:|:---:|---:|
| `115rat575` | 115 | 2,395.85 | 2,388.82 | -0.293 | [pdf](figures/sol-115rat575-ils.pdf) | 3,596.90 |
| `115u574` | 115 | 16,687.37 | 16,603.23 | -0.504 | [pdf](figures/sol-115u574-ils.pdf) | 3,492.84 |
| `131p654` | 131 | 27,434.58 | 27,415.32 | -0.070 | [pdf](figures/sol-131p654-ils.pdf) | 1,463.10 |
| `132d657` | 132 | 22,495.51 | 22,435.10 | -0.269 | [pdf](figures/sol-132d657-ils.pdf) | 3,600.00 |
| `144pcb1173-12x12` | 144 | 16,414.55 | 16,375.20 | -0.240 | [pdf](figures/sol-144pcb1173-12x12-ils.pdf) | 3,600.00 |
| `144rat783-12x12` | 144 | 2,824.15 | 2,801.90 | -0.788 | [pdf](figures/sol-144rat783-12x12-ils.pdf) | 3,600.00 |
| `145u724` | 145 | 17,264.24 | 17,223.18 | -0.238 | [pdf](figures/sol-145u724-ils.pdf) | 3,600.00 |
| `150i1000-411` | 150 | 6,304.26 | 6,094.99 | -3.319 | [pdf](figures/sol-150i1000-411-ils.pdf) | 3,539.94 |
| `150i1500-507` | 150 | 6,092.00 | 6,011.86 | -1.315 | [pdf](figures/sol-150i1500-507-ils.pdf) | 3,579.05 |
| `150i2000-605` | 150 | 5,955.01 | 5,908.67 | -0.778 | [pdf](figures/sol-150i2000-605-ils.pdf) | 3,600.00 |
| `150i2500-709` | 150 | 6,178.22 | 6,145.61 | -0.528 | [pdf](figures/sol-150i2500-709-ils.pdf) | 3,574.90 |
| `150i3000-804` | 150 | 6,573.91 | 6,533.05 | -0.621 | [pdf](figures/sol-150i3000-804-ils.pdf) | 3,580.39 |
| `150nrw1379` | 150 | 13,377.30 | 13,347.60 | -0.222 | [pdf](figures/sol-150nrw1379-ils.pdf) | 3,600.00 |
| `150pcb1173` | 150 | 17,086.53 | 17,040.54 | -0.269 | [pdf](figures/sol-150pcb1173-ils.pdf) | 3,600.00 |
| `150pr1002` | 150 | 92,967.16 | 92,760.02 | -0.223 | [pdf](figures/sol-150pr1002-ils.pdf) | 3,600.00 |
| `150rat783` | 150 | 3,142.29 | 3,127.19 | -0.481 | [pdf](figures/sol-150rat783-ils.pdf) | 3,600.00 |
| `150vm1084` | 150 | 95,924.17 | 95,608.96 | -0.329 | [pdf](figures/sol-150vm1084-ils.pdf) | 3,600.00 |
| `157rat783` | 157 | 3,276.81 | 3,256.09 | -0.632 | [pdf](figures/sol-157rat783-ils.pdf) | 3,600.00 |
| `200C1k.0` | 200 | 6,375,151.55 | 6,360,298.72 | -0.233 | [pdf](figures/sol-200C1k.0-ils.pdf) | 3,600.00 |
| `200E1k.0` | 200 | 9,662,860.40 | 9,675,458.53 | 0.130 | [pdf](figures/sol-200E1k.0-ils.pdf) | 3,600.00 |
| `200i2000-606` | 200 | 7,292.08 | 7,203.81 | -1.210 | [pdf](figures/sol-200i2000-606-ils.pdf) | 3,600.00 |
| `200i2500-710` | 200 | 7,210.60 | 7,115.54 | -1.318 | [pdf](figures/sol-200i2500-710-ils.pdf) | 3,600.00 |
| `200i3000-805` | 200 | 6,925.71 | 6,884.37 | -0.597 | [pdf](figures/sol-200i3000-805-ils.pdf) | 3,600.00 |
| `201pr1002` | 201 | 114,316.23 | 114,038.57 | -0.243 | [pdf](figures/sol-201pr1002-ils.pdf) | 3,600.00 |
| `212u1060` | 212 | 106,010.98 | 105,885.63 | -0.118 | [pdf](figures/sol-212u1060-ils.pdf) | 3,600.00 |
| `217vm1084` | 217 | 130,704.21 | 130,398.08 | -0.234 | [pdf](figures/sol-217vm1084-ils.pdf) | 3,600.00 |
| `235pcb1173` | 235 | 23,400.30 | 23,631.00 | 0.986 |  | 3,600.00 |
| `259d1291` | 259 | 28,416.31 | 28,425.74 | 0.033 |  | 3,600.00 |
| `261rl1304` | 261 | 150,464.16 | 150,626.30 | 0.108 |  | 3,600.00 |
| `265rl1323` | 265 | 154,020.77 | 154,198.29 | 0.115 |  | 3,600.00 |
| `276nrw1379` | 276 | 20,059.37 | 20,163.28 | 0.518 |  | 3,600.00 |
| `280fl1400` | 280 | 15,328.14 | 15,301.38 | -0.175 |  | 3,600.00 |
| `287u1432` | 287 | 54,483.50 | 54,671.59 | 0.345 |  | 3,600.00 |
| `316C31k.0` | 316 | 10,098,861.51 | 10,156,018.87 | 0.566 |  | 3,600.00 |
| `316fl1577` | 316 | 14,237.36 | 14,226.41 | -0.077 |  | 3,600.00 |
| `331d1655` | 331 | 29,442.49 | 29,661.57 | 0.744 |  | 3,600.00 |
| `350vm1748` | 350 | 185,454.12 | 186,217.02 | 0.411 |  | 3,600.00 |
| `364u1817` | 364 | 25,561.14 | 25,550.48 | -0.042 |  | 3,600.00 |
| `378rl1889` | 378 | 184,037.02 | 186,137.62 | 1.141 |  | 3,600.00 |
| `421d2103` | 421 | 40,073.89 | 40,392.90 | 0.796 |  | 3,600.00 |
| `431u2152` | 431 | 27,655.21 | 27,908.45 | 0.916 |  | 3,600.00 |
| `464u2319` | 464 | 65,780.21 | 67,833.77 | 3.122 |  | 3,600.00 |
| `479pr2392` | 479 | 169,886.33 | 173,484.38 | 2.118 |  | 3,600.00 |
| `608pcb3038` | 608 | 52,437.35 | 54,895.09 | 4.687 |  | 3,600.00 |
| `633C3k.0` | 633 | 10,255,046.16 | 10,416,214.19 | 1.572 |  | 3,600.00 |
| `633E3k.0` | 633 | 16,197,553.92 | 16,974,428.47 | 4.796 |  | 3,600.00 |
| `759fl3795` | 759 | 18,675.68 | 18,924.13 | 1.330 |  | 3,600.00 |
| `893fnl4461` | 893 | 63,195.36 | 67,905.15 | 7.453 |  | 3,600.00 |
| `1183rl5915` | 1183 | 309,246.13 | 326,174.84 | 5.474 |  | 3,600.00 |
| `1187rl5934` | 1187 | 295,765.53 | 312,849.83 | 5.776 |  | 3,600.00 |
| `2000C10k.0` | 2000 | 18,044,870.43 | 19,030,021.22 | 5.459 |  | 3,600.00 |
| `2000E10k.0` | 2000 | 28,769,023.11 | 31,103,910.28 | 8.116 |  | 3,600.00 |
| `2370rl11849` | 2370 | 428,014.21 | 467,658.09 | 9.262 |  | 3,600.00 |
| `2702usa13509` | 2702 | 10,080,731.95 | 10,806,030.15 | 7.195 |  | 3,600.00 |
| `2811brd14051` | 2811 | 176,773.39 | 196,358.08 | 11.079 |  | 3,600.00 |
| `3023d15112` | 3023 | 628,323.03 | 693,494.92 | 10.372 |  | 3,600.00 |
| `3703d18512` | 3703 | 235,062.11 | 267,013.52 | 13.593 |  | 3,600.00 |
| `4996sw24978` | 4996 | 417,659.01 | 452,631.29 | 8.373 |  | 3,600.00 |
| `6325C31k.0` | 6325 | 31,834,071.96 | 35,021,499.53 | 10.013 |  | 3,600.00 |
| `6325E31k.0` | 6325 | 50,503,477.42 | 57,009,123.27 | 12.882 |  | 3,600.00 |
| **Average** | **868** | **3,272,832.57** | **3,522,365.69** | **2.069** | | **3,560.45** |
