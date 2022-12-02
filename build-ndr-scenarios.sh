#!/bin/bash
#
#SBATCH --time=1:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI build scenario rasters"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.

set -e
set -x

CONTAINER=ghcr.io/natcap-nci/devstack
DIGEST=sha256:6c4a3233395b304a9d2eac57f954acf63b8dc477f5b997857a8a89f135cb5f34
singularity run \
    --env GDAL_CACHEMAX=1024 \
    docker://$CONTAINER@$DIGEST \
    python build-ndr-scenarios.py \
    "$SCRATCH/nci-gdrive/inputs" \
    "$SCRATCH/NCI-generated-scenarios"
