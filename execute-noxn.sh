#!/bin/bash
#
#SBATCH --time=4:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI-NOXN-May-2022"
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
DIGEST=sha256:6164b338bc3626e8994e2e0ffd50220fe2f66e7e904b794920749fa23360d7af

# Fetch the repository
# NOTE: This repo is private and so requires that sherlock is configured for SSH access.
REPOSLUG=nci-noxn-levels
REPO=git@github.com:natcap/$REPOSLUG.git
REVISION=ab9aff11266284e0cec12c8f38cd1381a2959d6f
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

singularity run \
    docker://$CONTAINER@$DIGEST \
    pipeline.py --cleanup --n_workers=20 --resolution="$RESOLUTION" "$WORKSPACE_DIR" "$NDR_OUTPUTS_DIR"

# rclone the files to google drive
# The trailing slash means that files will be copied into this directory.
# Don't need to name the files explicitly.
ARCHIVE_DIR="$DATE-nci-noxn-$GIT_REV-slurm$SLURM_JOB_ID-$RESOLUTION"

# Useful to back up the workspace to $SCRATCH for reference, even though we
# only need the drinking water rasters uploaded to GDrive.
# Create folders first so rsync only has to worry about files
find "$WORKSPACE_DIR/" -type d | sed "s|$WORKSPACE_DIR|$SCRATCH/$ARCHIVE_DIR/|g" | xargs mkdir -p

# rsync -avz is equivalent to rsync -rlptgoDvz
# Preserves permissions, timestamps, etc, which is better for taskgraph.
find "$WORKSPACE_DIR/" -type f | parallel -j 10 rsync -avzm --no-relative --human-readable {} "$SCRATCH/$ARCHIVE_DIR/"

# Copy geotiffs AND logfiles, if any.
# $file should be the complete path to the file (it is in my tests anyways)
module load system rclone
$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$ARCHIVE_DIR/" "$WORKSPACE_DIR"/*_noxn_in_drinking_water_$RESOLUTION.tif
$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$ARCHIVE_DIR/ndrplus-outputs-$RESOLUTION" "$WORKSPACE_DIR"/aligned_*_{export,modified_load}.tif
$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$ARCHIVE_DIR/ndrplus-outputs-$RESOLUTION" $(find "$WORKSPACE_DIR" -name "aligned_*_export.tif" -o -name "aligned_*_modified_load.tif")

module load system jq
gdrivedir=$(rclone lsjson "nci-ndr-stanford-gdrive:/" | jq ".[] | select('.Path==$ARCHIVE_DIR')".ID || echo "failed")
echo "Files uploaded to GDrive available at https://drive.google.com/drive/u/0/folders/$gdrivedir"
echo "NCI NOXN done!"
