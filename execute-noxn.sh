#!/bin/bash
#
#SBATCH --time=4:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem-per-cpu=8G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI-NOXN-pipeline"
#
# This script assumes that the task name will be set by the calling sbatch command.
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.
set -e
set -x

RESOLUTION="$1"
if [ "$RESOLUTION" = "" ]
then
    RESOLUTION="10km"
fi

# Container configuration
#
# NOTE: this is currently a private repository, so it'll be easier to cache
# this locally before the NOXN run.  I did this with:
#    $ singularity pull --docker-login docker://ghcr.io/natcap/natcap-noxn-levels
# which then prompted me for my username and GHCR password (authentication token).
# See the singularity docs on the subject for more info:
# https://sylabs.io/guides/3.0/user-guide/singularity_and_docker.html#making-use-of-private-images-from-docker-hub
CONTAINER=ghcr.io/natcap/natcap-noxn-levels
DIGEST=sha256:a9e09ff873407ce9e315504b019c616bf59095d65dcff4f31e1d4886722c8b46

# Fetch the repository
# NOTE: This repo is private and so requires that sherlock is configured for SSH access.
REPOSLUG=nci-noxn-levels
REPO=git@github.com:natcap/$REPOSLUG.git
REVISION=857c827fbb5b2fa778f700891f9128be7094cac9
if [ ! -d $REPOSLUG ]
then
    git clone $REPO
fi
pushd $REPOSLUG

# OK to always fetch the repo
git fetch
git checkout $REVISION

DATE="$(date +%F)"
GIT_REV="rev$(git rev-parse --short HEAD)"

# copy files from scratch workspaces to local machine.
NDR_OUTPUTS_DIR=$SCRATCH/NCI-ndr-plus-outputs
mkdir -p "$NDR_OUTPUTS_DIR"

# Copy files, presreving permissions.
# This should be faster than simply copying individual files.
find "$SCRATCH" -path "$SCRATCH/2021-NCI-NCI-*" -name "compressed_*.tif" | parallel -j 10 rsync -avzm --no-relative --human-readable {} "$NDR_OUTPUTS_DIR"

ls -la "$NDR_OUTPUTS_DIR"

# run job
WORKSPACE_DIRNAME=NCI-NOXN-workspace-$DATE-$GIT_REV-slurm$SLURM_JOB_ID-$RESOLUTION
WORKSPACE_DIR=$SCRATCH/$WORKSPACE_DIRNAME
if [ -d "$SCRATCH/$WORKSPACE_DIRNAME" ]
then
    # if there's already a workspace on $SCRATCH, copy it into $L_SCRATCH so we
    # can reuse the task graph.  Preserve permissions and timestamps too during
    # copy.
    #find "$SCRATCH/$WORKSPACE_DIRNAME" | parallel -j 10 rsync -avzm --no-relative --human-readable {} "$WORKSPACE_DIR"
    echo "not worth it to copy files to $L_SCRATCH -- too big for what we need to compute."
else
    # Otherwise, create the new workspace, skipping if already there.
    mkdir -p "$WORKSPACE_DIR"
fi

DECAYED_FLOWACCUM_WORKSPACE_DIR=$WORKSPACE_DIR/decayed_flowaccum
singularity run \
    docker://$CONTAINER@$DIGEST \
    pipeline-decayed-export.py --n_workers="$SLURM_CPUS_PER_TASK" "$DECAYED_FLOWACCUM_WORKSPACE_DIR" "$NDR_OUTPUTS_DIR"

singularity run \
    docker://$CONTAINER@$DIGEST \
    pipeline.py --n_workers="$SLURM_CPUS_PER_TASK" --resolution="$RESOLUTION" "$WORKSPACE_DIR" "$DECAYED_FLOWACCUM_WORKSPACE_DIR/outputs"

# rclone the files to google drive
# The trailing slash means that files will be copied into this directory.
# Don't need to name the files explicitly.
ARCHIVE_DIR="$DATE-nci-noxn-$GIT_REV-slurm$SLURM_JOB_ID-$RESOLUTION"

# Check to see if the workspace is on scratch.  If it isn't, rsync the workspace over to scratch.
if [[ $WORKSPACE_DIR != $SCRATCH/* ]]
then
    # Useful to back up the workspace to $SCRATCH for reference, even though we
    # only need the drinking water rasters uploaded to GDrive.
    # Create folders first so rsync only has to worry about files
    find "$WORKSPACE_DIR/" -type d | sed "s|$WORKSPACE_DIR|$SCRATCH/$ARCHIVE_DIR/|g" | xargs mkdir -p

    # rsync -avz is equivalent to rsync -rlptgoDvz
    # Preserves permissions, timestamps, etc, which is better for taskgraph.
    # TODO: maybe don't copy the workspace directory to scratch if the workspace is already on scratch?
    find "$WORKSPACE_DIR/" -type f | parallel -j 10 rsync -avzm --no-relative --human-readable {} "$SCRATCH/$ARCHIVE_DIR/"
fi

# Echo out the latest git log to make what's in this commit a little more readable.
GIT_LOG_MSG_FILE="$WORKSPACE_DIR/_which_commit_is_this.txt"
git log -n1 > $GIT_LOG_MSG_FILE

# Copy geotiffs AND logfiles, if any, to google drive.
# $file should be the complete path to the file (it is in my tests anyways)
module load system rclone
$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$ARCHIVE_DIR/" $(find "$WORKSPACE_DIR" -name "*_noxn_in_drinking_water_$RESOLUTION.tif")
$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$ARCHIVE_DIR/predicted_noxn_in_surfacewater" $(find "$WORKSPACE_DIR" -name "*_surfacewater_predicted_noxn_$RESOLUTION.tif")
$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$ARCHIVE_DIR/predicted_noxn_in_groundwater" $(find "$WORKSPACE_DIR" -name "*_groundwater_predicted_noxn_$RESOLUTION.tif")
$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$ARCHIVE_DIR/predicted_noxn_in_drinkingwater" $(find "$WORKSPACE_DIR" -name "*_noxn_in_drinking_water_$RESOLUTION.tif")
$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$ARCHIVE_DIR/" $(find "$WORKSPACE_DIR" -name "*.png" -o -name "*.txt" -o -name "*.json")
#$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$ARCHIVE_DIR/ndrplus-outputs-raw" $(find "$NDR_OUTPUTS_DIR" -name "*.tif")  # SLOW - outputs are tens of GB
$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$ARCHIVE_DIR/ndrplus-outputs-aligned-to-flowdir" $(find "$DECAYED_FLOWACCUM_WORKSPACE_DIR" -name "aligned_export*.tif")
$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$ARCHIVE_DIR/ndrplus-decayed-accumulation" $(find "$DECAYED_FLOWACCUM_WORKSPACE_DIR/outputs" -name "*.tif")
$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$ARCHIVE_DIR/covariates-$RESOLUTION" $(find "$WORKSPACE_DIR/aligned" -name "*.tif")

module load system jq
gdrivedir=$(rclone lsjson "nci-ndr-stanford-gdrive:/" | jq -r --arg path "$ARCHIVE_DIR" '.[] | select(.Path==$path)'.ID)
echo "Files uploaded to GDrive available at https://drive.google.com/drive/u/0/folders/$gdrivedir"
echo "NCI NOXN done!"
