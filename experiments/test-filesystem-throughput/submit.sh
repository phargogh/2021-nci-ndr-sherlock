#!/bin/bash

# $HOME is an NFS filesystem, but small
# $SCRATCH is a very large lustre filesystem
# $L_SCRATCH is local SSD storage
#
# Hypothesis:
# $L_SCRATCH will be the fastest for all read operations.
# $HOME will be next fastest.
# $SCRATCH will be slowest.

sbatch test-throughput.sh $HOME
sbatch test-throughput.sh $SCRATCH
sbatch test-throughput.sh $L_SCRATCH

# Results:
#         $HOME       $SCRATCH    $L_SCRATCH
# small files write
# real    0m4.367s    0m0.786s    0m0.050s
# user    0m0.042s    0m0.025s    0m0.019s
# sys     0m0.109s    0m0.160s    0m0.030s
#
# small files read
# real    0m2.037s    0m1.375s    0m0.772s
# user    0m0.373s    0m0.409s    0m0.368s
# sys     0m0.322s    0m0.523s    0m0.402s
#
# large file write
# real    0m23.780s   0m22.852s   0m20.164s
# user    0m18.876s   0m20.997s   0m19.418s
# sys     0m0.762s    0m1.605s    0m0.703s
#
# large file read
# real    0m8.926s    0m0.303s    0m0.217s
# user    0m0.000s    0m0.001s    0m0.002s
# sys     0m0.530s    0m0.278s    0m0.213s

# Conclusion
# $L_SCRATCH is the fastest storage across the board, followed by $SCRATCH, then $HOME.
# Particularly when reading/writing lots of small files, $L_SCRATCH is a clear choice,
# offering up to an order of magnitude speedup over $SCRATCH.  Based on these timings,
# $HOME should be avoided as a storage mechanism due to its slower performance.
