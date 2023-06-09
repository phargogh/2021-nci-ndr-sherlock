#!/bin/bash
#
#SBATCH --time=5:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=8G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI-NOXN-calories"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out
#
# This script assumes that the task name will be set by the calling sbatch command.
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.
set -e
set -x

# "${ENVVAR:-DEFAULT}" means use ENVVAR if present, DEFAULT if not.
WORKSPACE_DIR="${WORKSPACE_DIR:-$1}"  # The absolute path to where calories rasters should be written
NCI_WORKSPACE="${NCI_WORKSPACE:-$2}"  # Where the whole NCI workspace is located (absolute path)
CALORIES_DIR="${CALORIES_DIR:-$3}"    # Where the source calories rasters are located  (absolute path)
SCENARIO_JSON="${SCENARIO_JSON:-$4}"  # Where the Scenario JSON file is located (absolute path)
SPATIAL_CONFIG_FILE="${SPATIAL_CONFIG_FILE:-$5}"

source "./env-sherlock.env"

pushd nci-noxn-levels

singularity run \
    "docker://$NOXN_DOCKER_CONTAINER" \
    python calories.py \
        --n_workers="$SLURM_CPUS_PER_TASK" \
        --current="$CALORIES_DIR/caloriemapscurrentRevQ.tif" \
        --irrigated="$CALORIES_DIR/caloriemapsirrigatedRevQ.tif" \
        --rainfed="$CALORIES_DIR/caloriemapsrainfedRevQ.tif" \
        --scenario_json="$NCI_WORKSPACE/prepared-scenarios/scenario_rasters.json" \
        --spatial_config="$(basename $SPATIAL_CONFIG_FILE)" \
        "$WORKSPACE_DIR"

if [ "$NCI_USE_GLOBUS" = "1" ]
then
    # Copy geotiffs AND logfiles, if any, to google drive.
    # $file should be the complete path to the file (it is in my tests anyways)
    # This will upload to a workspace with the same dirname as $NOXN_WORKSPACE.
    module load system rclone
    module load system py-globus-cli
    module load system jq
    RESOLUTION=$(jq -r .resolution $SPATIAL_CONFIG_FILE)  # load resolution string from config
    ARCHIVE_DIR="$DATE-nci-calories-$GIT_REV-slurm$SLURM_JOB_ID-$RESOLUTION"
    globus transfer --fail-on-quota-errors --recursive \
        --label="NCI WQ Calories $GIT_REV" \
        "$GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID:$WORKSPACE_DIR" \
        "$GLOBUS_STANFORD_GDRIVE_COLLECTION_ID:$GLOBUS_STANFORD_GDRIVE_RUN_ARCHIVE/$(basename $NCI_WORKSPACE)/$ARCHIVE_DIR" || echo "Globus transfer failed!"
fi
