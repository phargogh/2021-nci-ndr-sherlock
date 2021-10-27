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

CONTAINER=ghcr.io/phargogh/inspring-no-gcloud-keys
DIGEST=sha256:66c4a760dece610f992ee2f2aa4fff6a8d9e96951bf6f9a81bf16779aa7f26c4

# Expected workspace: $TARGET_WORKSPACE
TARGET_WORKSPACE=$L_SCRATCH/test-echo-workspace
srun mkdir $TARGET_WORKSPACE \
    && singularity run \
    --env WORKSPACE_DIR=$TARGET_WORKSPACE \
    docker://$CONTAINER@$DIGEST \
    echo-workspace.py > $TARGET_WORKSPACE/out.txt \
    ; cp -r $TARGET_WORKSPACE $SCRATCH/test-echo-workspace

# Expected workspace: default/workspace
singularity run \
    docker://$CONTAINER@$DIGEST echo-workspace.py
