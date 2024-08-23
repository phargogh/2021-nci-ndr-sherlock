#!/bin/bash
#
#SBATCH --time=2:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
#SBATCH --mem-per-cpu=16G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu,iamadden@stanford.edu,rschmitt@stanford.edu
#SBATCH --partition=serc,hns,normal
#SBATCH --job-name="NCI-NOXN-pipeline"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out
#
# This script assumes that the task name will be set by the calling sbatch command.
#
# --partition=serc,hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.
set -e
set -x
module load system jq

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

# load configuration for globus, singularity, etc.
source "env-sherlock.env"

REPOSLUG=nci-noxn-levels
pushd $REPOSLUG

DATE="$(date +%F)"
GIT_REV="rev$(git rev-parse --short HEAD)"

# copy files from scratch workspaces to local machine.
NDR_OUTPUTS_DIR="$NCI_WORKSPACE/ndr-plus-outputs"
mkdir -p "$NDR_OUTPUTS_DIR"

# Copy files, preserving permissions.
# Also only copy files over if they're newer than the ones already there.
# This should be faster than simply copying individual files.
find "$NCI_WORKSPACE" -regex ".*/NCI-NDRplus-.*" -name "compressed_*.tif" | parallel -j 10 rsync -avzm --update --no-relative --human-readable {} "$NDR_OUTPUTS_DIR"

ls -la "$NDR_OUTPUTS_DIR"

# run job
WORKSPACE_DIR="$NOXN_WORKSPACE"
mkdir -p "$WORKSPACE_DIR" || echo "could not create workspace dir"

DECAYED_FLOWACCUM_WORKSPACE_DIR=$WORKSPACE_DIR/decayed_flowaccum
singularity run \
    "docker://$NOXN_DOCKER_CONTAINER" \
    python pipeline-decayed-export.py --n_workers="$SLURM_CPUS_PER_TASK" "$DECAYED_FLOWACCUM_WORKSPACE_DIR" "$NDR_OUTPUTS_DIR"

CONFIG_FILE="pipeline.config-sherlock-$RESOLUTION.json"
singularity run \
    --env-file="../singularity-containers.env" \
    "docker://$NOXN_DOCKER_CONTAINER" \
    python pipeline.py \
    --n_workers="$SLURM_CPUS_PER_TASK" \
    --slurm \
    "$CONFIG_FILE" \
    "$WORKSPACE_DIR" \
    "$DECAYED_FLOWACCUM_WORKSPACE_DIR/outputs"

# The model analysis script can start any time after the NDR outputs are in the
# right place AND after the first NOXN phase has completed.
popd
sbatch execute-model-analysis.sh \
    "$NCI_WORKSPACE/noxn-model-analysis" \
    "$NCI_WORKSPACE" \
    "$RESOLUTION"
pushd $REPOSLUG

PREDICTION_PICKLES_FILE=$WORKSPACE_DIR/$(singularity run docker://$NOXN_DOCKER_CONTAINER python -c "import pipeline; print(pipeline.PREDICTION_SLURM_JOBS_FILENAME)")
PREDICTION_JOBS_STRING="afterok"
while read -r prediction_pickle_file; do
    sleep 3  # give the scheduler a break; lots of jobs to schedule
    PREDICTION_JOB_ID=$(sbatch \
        --time="$(jq -rj .prediction.prediction_runtime $CONFIG_FILE)" \
        --cpus-per-task="$(jq -rj .prediction.prediction_n_workers $CONFIG_FILE)" \
        --job-name="NCI-NOXN-prediction-$(basename $prediction_pickle_file)" \
        ../execute-noxn-prediction.sh "$prediction_pickle_file" | grep -o "[0-9]\\+")
    PREDICTION_JOBS_STRING="$PREDICTION_JOBS_STRING:$PREDICTION_JOB_ID"
done < "$PREDICTION_PICKLES_FILE"

# Execute post-prediction script
PHASE2_JOB_ID=$(sbatch \
    --dependency="$PREDICTION_JOBS_STRING" \
    --time=$(jq -rj .post_prediction.runtime $CONFIG_FILE) \
    ../execute-noxn-post-prediction.sh "$WORKSPACE_DIR" | grep -o "[0-9]\\+")

# Upload files to globus
sbatch \
    --dependency="afterok:$PHASE2_JOB_ID" \
    ../execute-noxn-upload-to-globus.sh \
    "$DATE" \
    "$GIT_REV" \
    "$RESOLUTION" \
    "$WORKSPACE_DIR" \
    "$NOXN_WORKSPACE" \
    "$NCI_WORKSPACE"

echo "Completed noxn sbatch script"
