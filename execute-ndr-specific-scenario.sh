#!/bin/bash
#
#SBATCH --time=40:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=5999M
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=serc,hns,normal
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out
#
# The script _should_ only take 13 hours to run, but on a machine where we're competing for SSD time, it might take up to about 25 hours.  30 should be plenty.
#
# This script assumes that the task name will be set by the calling sbatch command.
#
# --partition=serc,hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.

WORKSPACE_NAME="$1"
SCENARIO_NAME="$2"
DATE="$3"
GIT_REV="$4"
FINAL_RESTING_PLACE="$5"
SCENARIO_JSON_FILE="$6"
SCENARIO_MODULE="$7"

CONTAINER=ghcr.io/phargogh/inspring-no-gcloud-keys
DIGEST=sha256:66c4a760dece610f992ee2f2aa4fff6a8d9e96951bf6f9a81bf16779aa7f26c4
WORKSPACE_DIR="$L_SCRATCH/$WORKSPACE_NAME"

# This script is executed from within the ndr repo, so the globus config is one dir up.
source "../globus-endpoints.env"

source "./env-sherlock.env"

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

set -x  # Be eXplicit about what's happening.
FAILED=0
singularity run \
    --env WORKSPACE_DIR="$WORKSPACE_DIR" \
    --env TMPDIR="$L_SCRATCH" \
    --env NCI_SCENARIO_LULC_N_APP_JSON="$SCENARIO_JSON_FILE" \
    docker://$CONTAINER@$DIGEST \
    global_ndr_plus_pipeline.py $SCENARIO_MODULE \
    --n_workers=20 \
    --limit_to_scenarios "$SCENARIO_NAME" || FAILED=1

# copy results (regardless of job run status) to $SCRATCH
# Rsync will help to only copy the deltas; might be faster than cp.
# rsync -az is equivalent to rsync -rlptgoDz
# Preserves permissions, timestamps, etc, which is better for taskgraph.
# I've removed the -v flag because workspaces have a few hundred thousand files
# that don't all need to have their filenames printed to stdout.
#
# Excluding the ecoshards dir, should eliminate about 40GB
rsync -az \
    --exclude "$WORKSPACE_DIR/ecoshards" \
    "$WORKSPACE_DIR/" "$FINAL_RESTING_PLACE/$WORKSPACE_NAME"

# The trailing slash means that files will be copied into this directory.
# Don't need to name the files explicitly.
ARCHIVE_DIR="$DATE-nci-ndr-$GIT_REV/$SCENARIO_NAME"
GDRIVE_DIR="$(basename $FINAL_RESTING_PLACE)/$ARCHIVE_DIR"

# Copy geotiffs AND logfiles to google drive.
#$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$GDRIVE_DIR" "$WORKSPACE_DIR"/*.{tif,out}

# Only uploading logfiles to google drive.
# It turns out that Google Drive has a 750GB/day upload limit, which we are
# easily exceeding with 14 scenarios at 59GB/scenario, totaling 826GB.
#
# Only uploading the logfiles and the compressed geotiffs should keep things below our max limit,
# about 14 scenarios, 15 GB apiece, so 210GB for a complete NDR run.
module load system py-globus-cli
TEMPFILE="$FINAL_RESTING_PLACE/$WORKSPACE_NAME/globus-filerequest.txt"
find "$FINAL_RESTING_PLACE/$WORKSPACE_NAME" -maxdepth 1 -name "compressed_*.tif" -o -name "*.out" | xargs basename -a | awk '$2=$1' > "$TEMPFILE"
globus transfer --fail-on-quota-errors \
    --label="NCI WQ NDR rev$GIT_REV $SCENARIO_NAME" \
    --batch="$TEMPFILE" \
    "$GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID:$FINAL_RESTING_PLACE/$WORKSPACE_NAME" \
    "$GLOBUS_STANFORD_GDRIVE_COLLECTION_ID:$GLOBUS_STANFORD_GDRIVE_RUN_ARCHIVE/$(basename $FINAL_RESTING_PLACE)/$ARCHIVE_DIR" || echo "Globus transfer failed!"

#$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$GDRIVE_DIR" "$WORKSPACE_DIR"/*.out
#$(pwd)/../upload-to-googledrive.sh "nci-ndr-stanford-gdrive:$GDRIVE_DIR" "$WORKSPACE_DIR"/compressed_*.tif

# If NDR failed, we want that to be reflected in the email I get on exit.
if [ "$FAILED" -gt "0" ]
then
    exit 1
fi
