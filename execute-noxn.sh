#!/bin/bash
#
#SBATCH --time=4:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=16G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI-NOXN-pipeline"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out
#
# This script assumes that the task name will be set by the calling sbatch command.
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.
set -e
set -x

RESOLUTION="$1"
if [ "$RESOLUTION" = "" ]
then
    echo "Parameter 1 must be the resolution"
    exit 1
fi

# "${ENVVAR:-DEFAULT}" means use ENVVAR if present, DEFAULT if not.
SHERLOCK_REPO_REV="${SHERLOCK_REPO_REV:-$2}"
NOXN_WORKSPACE="${NOXN_WORKSPACE:-$3}"  # final location of pipeline outputs
NCI_WORKSPACE="${NCI_WORKSPACE:-$4}"
CALORIES_DIR="${CALORIES_DIR:-$5}"
SCENARIO_JSON="${SCENARIO_JSON:-$6}"

# load configuration for globus
source "./globus-endpoints.env"

# Container configuration
#
# NOTE: this is currently a private repository, so it'll be easier to cache
# this locally before the NOXN run.  I did this with:
#    $ singularity pull --docker-login docker://ghcr.io/natcap/natcap-noxn-levels
# which then prompted me for my username and GHCR password (authentication token).
# See the singularity docs on the subject for more info:
# https://sylabs.io/guides/3.0/user-guide/singularity_and_docker.html#making-use-of-private-images-from-docker-hub
CONTAINER=ghcr.io/natcap/natcap-noxn-levels
DIGEST=sha256:2a92ced1387bbfe580065ef98a61f6d360daf90f3afa54cf4383b0becf7480e8

REPOSLUG=nci-noxn-levels
pushd $REPOSLUG

# OK to always fetch the repo
git fetch
git checkout $REVISION

DATE="$(date +%F)"
GIT_REV="rev$(git rev-parse --short HEAD)"

# copy files from scratch workspaces to local machine.
NDR_OUTPUTS_DIR="$NCI_WORKSPACE/ndr-plus-outputs"
mkdir -p "$NDR_OUTPUTS_DIR"

# Copy files, preserving permissions.
# Also only copy files over if they're newer than the ones already there.
# This should be faster than simply copying individual files.
find "$NCI_WORKSPACE" -name "compressed_*.tif" | parallel -j 10 rsync -avzm --update --no-relative --human-readable {} "$NDR_OUTPUTS_DIR"

ls -la "$NDR_OUTPUTS_DIR"

# run job
WORKSPACE_DIR="$NOXN_WORKSPACE"
mkdir -p "$WORKSPACE_DIR" || echo "could not create workspace dir"

DECAYED_FLOWACCUM_WORKSPACE_DIR=$WORKSPACE_DIR/decayed_flowaccum
singularity run \
    docker://$CONTAINER@$DIGEST \
    python pipeline-decayed-export.py --n_workers="$SLURM_CPUS_PER_TASK" "$DECAYED_FLOWACCUM_WORKSPACE_DIR" "$NDR_OUTPUTS_DIR"

singularity run \
    docker://$CONTAINER@$DIGEST \
    python pipeline.py --n_workers="$SLURM_CPUS_PER_TASK" --resolution="$RESOLUTION" \
    "$WORKSPACE_DIR" \
    "$DECAYED_FLOWACCUM_WORKSPACE_DIR/outputs" \
    "$CALORIES_DIR" \
    "$SCENARIO_JSON"

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
    find "$WORKSPACE_DIR/" -type d | sed "s|$WORKSPACE_DIR|$NOXN_WORKSPACE/$ARCHIVE_DIR/|g" | xargs mkdir -p

    # rsync -avz is equivalent to rsync -rlptgoDvz
    # Preserves permissions, timestamps, etc, which is better for taskgraph.
    # TODO: maybe don't copy the workspace directory to scratch if the workspace is already on scratch?
    find "$WORKSPACE_DIR/" -type f | parallel -j 10 rsync -avzm --no-relative --human-readable {} "$NOXN_WORKSPACE/$ARCHIVE_DIR/"
fi

# Echo out the latest git log to make what's in this commit a little more readable.
GIT_LOG_MSG_FILE="$WORKSPACE_DIR/_which_commit_is_this.txt"
git remote -v >> "$GIT_LOG_MSG_FILE"
git log -n1 >> "$GIT_LOG_MSG_FILE"

# Copy geotiffs AND logfiles, if any, to google drive.
# $file should be the complete path to the file (it is in my tests anyways)
# This will upload to a workspace with the same dirname as $NOXN_WORKSPACE.
module load system rclone
module load system py-globus-cli
GDRIVE_DIR="nci-ndr-stanford-gdrive:$(basename $NCI_WORKSPACE)/$ARCHIVE_DIR"
globus transfer --fail-on-quota-errors --recursive \
    --label="NCI WQ NOXN $GIT_REV" \
    "$GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID:$WORKSPACE_DIR" \
    "$GLOBUS_STANFORD_GDRIVE_COLLECTION_ID:$GLOBUS_STANFORD_GDRIVE_RUN_ARCHIVE/$(basename $NCI_WORKSPACE)/$ARCHIVE_DIR" || echo "Globus transfer failed!"

#$(pwd)/../upload-to-googledrive.sh "$GDRIVE_DIR/" $(find "$WORKSPACE_DIR")  # just upload the whole workspace.
#$(pwd)/../upload-to-googledrive.sh "$GDRIVE_DIR/ndrplus-outputs-raw" $(find "$NDR_OUTPUTS_DIR" -name "*.tif")  # SLOW - outputs are tens of GB

module load system jq
gdrivedir=$(rclone lsjson "nci-ndr-stanford-gdrive:/" | jq -r --arg path "$(basename $NCI_WORKSPACE)/$ARCHIVE_DIR" '.[] | select(.Path==$path)'.ID)
echo "Files uploaded to GDrive available at https://drive.google.com/drive/u/0/folders/$gdrivedir"
echo "NCI NOXN done!"
