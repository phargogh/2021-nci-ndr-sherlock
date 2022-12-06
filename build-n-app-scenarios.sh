#!/bin/bash
#
#SBATCH --time=1:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=6
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI build n app rasters"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.

set -e
set -x

SCENARIO_OUTPUTS_DIR="$SCRATCH/NCI-n-app-scenarios"
rm -r $SCENARIO_OUTPUTS_DIR || echo "Cannot delete a folder that doesn't exist"
mkdir -p $SCENARIO_OUTPUTS_DIR

CONTAINER=ghcr.io/natcap-nci/devstack
DIGEST=sha256:6c4a3233395b304a9d2eac57f954acf63b8dc477f5b997857a8a89f135cb5f34

export APPTAINER_DOCKER_USERNAME="$GHCR_USERNAME"  # My github username
export APPTAINER_DOCKER_PASSWORD="$GHCR_TOKEN"     # My GHCR token
singularity run \
    --env GDAL_CACHEMAX=1024 \
    docker://$CONTAINER@$DIGEST \
    python build-n-app-scenarios.py \
    "$SCRATCH/nci-gdrive/inputs" \
    "$SCENARIO_OUTPUTS_DIR"


