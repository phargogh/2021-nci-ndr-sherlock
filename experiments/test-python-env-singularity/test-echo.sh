#!/bin/bash
#
#SBATCH --job-name=Test-singularity-environment-variable-passing
#
#SBATCH --time=00:02:30
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G

# Hypothesis:
#
# I should be able to pass environment variables to a python program through
# the singularity --env and assume a default if it hasn't been passed.

# Expected workspace: $HOME/some-workspace
srun singularity run docker://python:3.9.7-bullseye \
    --env WORKSPACE_DIR=$HOME/some-workspace \
    echo.py

# Expected workspace: default/workspace
srun singularity run docker://python:3.9.7-bullseye echo.py
