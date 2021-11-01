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
