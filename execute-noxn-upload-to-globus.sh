#!/bin/bash
#
#SBATCH --time=0:01:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu,iamadden@stanford.edu,rschmitt@stanford.edu
#SBATCH --partition=serc,hns,normal
#SBATCH --job-name="NCI-NOXN-globus-upload-to-gdrive"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out
#
# This script assumes that the task name will be set by the calling sbatch command.
#
# --partition=serc,hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.
set -ex

DATE="$1"
GIT_REV="$2"
RESOLUTION="$3"
WORKSPACE_DIR="$4"
NOXN_WORKSPACE="$5"
NCI_WORKSPACE="$6"

source "../env-sherlock.env"

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

gdrivedir=$(rclone lsjson "nci-ndr-stanford-gdrive:/" | jq -r --arg path "$(basename $NCI_WORKSPACE)/$ARCHIVE_DIR" '.[] | select(.Path==$path)'.ID)
echo "Files uploaded to GDrive available at https://drive.google.com/drive/u/0/folders/$gdrivedir"
echo "NCI NOXN done!"
