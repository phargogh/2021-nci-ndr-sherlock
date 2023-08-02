#!/bin/bash
#
#SBATCH --time=2:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
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

CONTAINER=ghcr.io/natcap-nci/devstack
DIGEST=sha256:6c4a3233395b304a9d2eac57f954acf63b8dc477f5b997857a8a89f135cb5f34

export APPTAINER_DOCKER_USERNAME="$GHCR_USERNAME"  # My github username
export APPTAINER_DOCKER_PASSWORD="$GHCR_TOKEN"     # My GHCR token
singularity run \
    --env GDAL_CACHEMAX=1024 \
    docker://$CONTAINER@$DIGEST \
    python prep-ndr-inputs-pipeline.py \
        --input-dir="$GDRIVE_INPUTS_DIR" \
        --output-dir="$SCENARIO_OUTPUTS_DIR" \
        --n-workers=10

if [ "$3" != "" ]
then
    FINAL_RESTING_PLACE="$3"
    GDRIVE_DIR=$(basename "$FINAL_RESTING_PLACE")
    #$(pwd)/upload-to-googledrive.sh \
    #    "nci-ndr-stanford-gdrive:$GDRIVE_DIR/prepared-scenarios" \
    #    "$SCENARIO_OUTPUTS_DIR"/*.{tif,json}
    module load system py-globus-cli
    source "./globus-endpoints.env"
    TEMPFILE="$SCENARIO_OUTPUTS_DIR/globus-filerequest.txt"
    find "$SCENARIO_OUTPUTS_DIR" -maxdepth 1 -name "*.tif" -o -name "*.out" -o -name "*.json" | xargs basename -a | awk '$2=$1' > "$TEMPFILE"
    globus transfer --fail-on-quota-errors \
        --batch="$TEMPFILE" \
        "$GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID:$SCENARIO_OUTPUTS_DIR/" \
        "$GLOBUS_STANFORD_GDRIVE_COLLECTION_ID:$GLOBUS_STANFORD_GDRIVE_RUN_ARCHIVE/$GDRIVE_DIR/prepared-scenarios"
fi

LINT_SCRIPT="$(pwd)/lint-ndr-scenario.py"
singularity run \
    --env NCI_SCENARIO_LULC_N_APP_JSON="$SCENARIO_OUTPUTS_DIR/scenario_rasters.json" \
    docker://$CONTAINER@$DIGEST \
    python "$LINT_SCRIPT" "nci_global_dec_2022"
