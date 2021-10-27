#!/bin/bash
#
#SBATCH --job-name=Test-singularity-environment-variable-passing
#
#SBATCH --time=00:10:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G

# Hypothesis:
#
# I should be able to pass environment variables to a python program through
# the singularity --env and assume a default if it hasn't been passed.

# Expected workspace: $HOME/some-workspace
TARGET_WORKSPACE=$L_SCRATCH/test-echo-workspace
srun singularity run docker://python:3.9.7-bullseye \
    --env WORKSPACE_DIR=$TARGET_WORKSPACE \
    echo.py > $TARGET_WORKSPACE/out.txt; \
    cp -r $TARGET_WORKSPACE $SCRATCH/test-echo-workspace

# Expected workspace: default/workspace
srun singularity run docker://python:3.9.7-bullseye echo.py
