# Where these GTSP instances come from

The 295 files here are redistributed unchanged from two public benchmark
libraries for the Generalized Traveling Salesman Problem: 90 instances of the
GTSP Lib [\[1\]](../../README.md#instance-references) under `gtsplib/` and 205
of the MOM Lib [\[2\]](../../README.md#instance-references) under `momlib/`.
They are the input of `conversion/`.

The lists under `selected-instances/` name the files the conversion reads:
every instance of the two libraries that gives the coordinates of its points,
which the conversion needs, and has at least 8 clusters. Of the 295, 235 have
at most 100 clusters and 60 have more, up to 6,325.
