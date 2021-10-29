#!/bin/bash
#
#SBATCH --time=20:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#
# This script assumes that the task name will be set by the calling sbatch command.

WORKSPACE_NAME="$1"
SCENARIO_NAME="$2"
DATE="$3"
GIT_REV="$4"

CONTAINER=ghcr.io/phargogh/inspring-no-gcloud-keys
DIGEST=sha256:66c4a760dece610f992ee2f2aa4fff6a8d9e96951bf6f9a81bf16779aa7f26c4
WORKSPACE_DIR=$L_SCRATCH/$WORKSPACE_NAME

if [ -d $SCRATCH/$WORKSPACE_NAME ]
then
    # If there's already a workspace on $SCRATCH, then copy it into $L_SCRATCH
    # so we can reuse the task graph.
    cp -r $SCRATCH/$WORKSPACE_NAME $WORKSPACE_DIR
else
    # If the workspace isn't in $SCRATCH, then we'll be starting with an empty
    # workspace ("from scratch", one might say, if you'll pardon the pun)
    mkdir -p $WORKSPACE_DIR
fi

echo `pwd`

singularity run \
    --env WORKSPACE_DIR=$WORKSPACE_DIR \
    docker://$CONTAINER@$DIGEST \
    global_ndr_plus_pipeline.py scenarios.nci_global \
    --n_workers=40 \
    --limit_to_scenarios $SCENARIO_NAME

# copy results (regardless of job run status) to $SCRATCH
# TODO: make this rsync, to update the files instead?
cp -r $WORKSPACE_DIR $SCRATCH/2021-NCI-$WORKSPACE_NAME

# The trailing slash means that files will be copied into this directory.
# Don't need to name the files explicitly.
GDRIVE_DIR="$DATE-nci-ndr-$GIT_REV/$SCENARIO_NAME/$WORKSPACE_NAME/"

# Copy geotiffs AND logfiles.
# $file should be the complete path to the file (it is in my tests anyways)
module load system rclone
for file in `ls $WORKSPACE_DIR/*.{tif,log}`
do
    rclone copy --progress $file "nci-ndr-stanford-gdrive:$GDRIVE_DIR"
done
