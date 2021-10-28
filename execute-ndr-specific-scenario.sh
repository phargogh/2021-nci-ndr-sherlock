#!/bin/bash
#
#SBATCH --time=30:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=4G
#
# This script assumes that the task name will be set by the calling sbatch command.

WORKSPACE_NAME="$1"
SCENARIO_NAME="$2"

CONTAINER=ghcr.io/phargogh/inspring-no-gcloud-keys
DIGEST=sha256:66c4a760dece610f992ee2f2aa4fff6a8d9e96951bf6f9a81bf16779aa7f26c4
WORKSPACE_DIR=$L_SCRATCH/$WORKSPACE_NAME

mkdir -p $WORKSPACE_DIR || echo "Could not create $WORKSPACE_DIR, maybe it already exists?"
echo `pwd`

singularity run \
    --env WORKSPACE_DIR=$WORKSPACE_DIR \
    docker://$CONTAINER@$DIGEST \
    global_ndr_plus_pipeline.py scenarios.nci_global \
    --n_workers=40 \
    --limit_to_scenarios $SCENARIO_NAME

# copy results (regardless of job run status) to $SCRATCH
cp -r $WORKSPACE_DIR $SCRATCH/2021-NCI-$WORKSPACE_NAME
