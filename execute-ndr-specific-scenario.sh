#!/bin/bash
#
#SBATCH --time=20:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=8G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#
# This script assumes that the task name will be set by the calling sbatch command.
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.

WORKSPACE_NAME="$1"
SCENARIO_NAME="$2"
DATE="$3"
GIT_REV="$4"

CONTAINER=ghcr.io/phargogh/inspring-no-gcloud-keys
DIGEST=sha256:66c4a760dece610f992ee2f2aa4fff6a8d9e96951bf6f9a81bf16779aa7f26c4
WORKSPACE_DIR="$L_SCRATCH/$WORKSPACE_NAME"

if [ -d "$SCRATCH/$WORKSPACE_NAME" ]
then
    # If there's already a workspace on $SCRATCH, then copy it into $L_SCRATCH
    # so we can reuse the task graph.
    # cp -rp will recurse and also copy permissions and timestamps (needed for better taskgraph performance)
    cp -rp "$SCRATCH/$WORKSPACE_NAME" "$WORKSPACE_DIR"
else
    # If the workspace isn't in $SCRATCH, then we'll be starting with an empty
    # workspace ("from scratch", one might say, if you'll pardon the pun)
    mkdir -p "$WORKSPACE_DIR"
fi

echo `pwd`

singularity run \
    --env WORKSPACE_DIR="$WORKSPACE_DIR" \
    --env TMPDIR="$L_SCRATCH" \
    docker://$CONTAINER@$DIGEST \
    global_ndr_plus_pipeline.py scenarios.nci_global \
    --n_workers=30 \
    --limit_to_scenarios "$SCENARIO_NAME"

# copy results (regardless of job run status) to $SCRATCH
# Rsync will help to only copy the deltas; might be faster than cp.
# rsync -az is equivalent to rsync -rlptgoDz
# Preserves permissions, timestamps, etc, which is better for taskgraph.
# I've removed the -v flag because workspaces have a few hundred thousand files
# that don't all need to have their filenames printed to stdout.
rsync -az "$WORKSPACE_DIR/*" "$SCRATCH/2021-NCI-$WORKSPACE_NAME"

# The trailing slash means that files will be copied into this directory.
# Don't need to name the files explicitly.
GDRIVE_DIR="$DATE-nci-ndr-$GIT_REV/$SCENARIO_NAME/"

# Copy geotiffs AND logfiles to google drive.
#$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$GDRIVE_DIR" "$WORKSPACE_DIR"/*.{tif,out}

# Only uploading logfiles to google drive.
# It turns out that Google Drive has a 750GB/day upload limit, which we are
# easily exceeding with 14 scenarios at 59GB/scenario, totaling 826GB.
# So I'm updating this now to not upload anything at all because it'll just time out.
# Later on, I can see about uploading these files again.
#$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$GDRIVE_DIR" "$WORKSPACE_DIR"/*.out
