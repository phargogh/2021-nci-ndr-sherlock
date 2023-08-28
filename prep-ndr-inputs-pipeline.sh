#!/bin/bash
#
#SBATCH --time=12:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI-build-scenario-rasters"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.

set -e
set -x
if [ "$1" = "" ]
then
    GDRIVE_INPUTS_DIR="$SCRATCH/nci-gdrive/inputs"
else
    GDRIVE_INPUTS_DIR="$1"
fi

if [ "$2" = "" ]
then
    SCENARIO_OUTPUTS_DIR="$SCRATCH/NCI-scenarios"
else
    SCENARIO_OUTPUTS_DIR="$2"
fi

# load configuration for globus, singularity, etc.
source "env-sherlock.env"

export APPTAINER_DOCKER_USERNAME="$GHCR_USERNAME"  # My github username
export APPTAINER_DOCKER_PASSWORD="$GHCR_TOKEN"     # My GHCR token
singularity run \
    --env GDAL_CACHEMAX=2048 \
    docker://$NOXN_DOCKER_CONTAINER \
    python prep-ndr-inputs-pipeline.py \
        --input-dir="$GDRIVE_INPUTS_DIR" \
        --output-dir="$SCENARIO_OUTPUTS_DIR" \
        --n-workers=$SLURM_CPUS_PER_TASK

module load system py-globus-cli
source "./globus-endpoints.env"
TEMPFILE="$SCENARIO_OUTPUTS_DIR/globus-filerequest.txt"
find "$SCENARIO_OUTPUTS_DIR" -maxdepth 1 -name "*.tif" -o -name "*.out" -o -name "*.json" | xargs basename -a | awk '$2=$1' > "$TEMPFILE"
if [ "$3" != "" ]
then
    FINAL_RESTING_PLACE="$3"
    GDRIVE_DIR=$(basename "$FINAL_RESTING_PLACE")
    #$(pwd)/upload-to-googledrive.sh \
    #    "nci-ndr-stanford-gdrive:$GDRIVE_DIR/prepared-scenarios" \
    #    "$SCENARIO_OUTPUTS_DIR"/*.{tif,json}
    globus transfer --fail-on-quota-errors \
        --batch="$TEMPFILE" \
        "$GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID:$SCENARIO_OUTPUTS_DIR/" \
        "$GLOBUS_STANFORD_GDRIVE_COLLECTION_ID:$GLOBUS_STANFORD_GDRIVE_RUN_ARCHIVE/$GDRIVE_DIR/prepared-scenarios"
else
    DATE="$(date +%F)"
    GIT_REV="rev$(git rev-list HEAD --count)-$(git rev-parse --short HEAD)"
    globus transfer --fail-on-quota-errors \
        --batch="$TEMPFILE" \
        "$GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID:$SCENARIO_OUTPUTS_DIR/" \
        "$GLOBUS_STANFORD_GDRIVE_COLLECTION_ID:$GLOBUS_STANFORD_GDRIVE_RUN_ARCHIVE/$DATE-$GIT_REV-prepared-scenarios"
fi

LINT_SCRIPT="$(pwd)/lint-ndr-scenario.py"
singularity run \
    --env NCI_SCENARIO_LULC_N_APP_JSON="$SCENARIO_OUTPUTS_DIR/scenario_rasters.json" \
    --env GDAL_CACHEMAX=2048 \
    docker://$NOXN_DOCKER_CONTAINER \
    python "$LINT_SCRIPT" "nci_global_dec_2022"
