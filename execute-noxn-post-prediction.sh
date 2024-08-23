#!/bin/bash
#
#SBATCH --time=1:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=16G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu,iamadden@stanford.edu,rschmitt@stanford.edu
#SBATCH --partition=serc,hns,normal
#SBATCH --job-name="NCI-NOXN-post-prediction"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out
#
# This script assumes that the task name will be set by the calling sbatch command.
#
# --partition=serc,hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.
set -e
set -x

WORKSPACE="$1"

# load configuration for globus, singularity, etc.
source "../env-sherlock.env"

singularity run \
    "docker://$NOXN_DOCKER_CONTAINER" \
    python cli-wrap.py pipeline.execute_phase2 \
    --workspace="$WORKSPACE" \
    --n_workers="$SLURM_CPUS_PER_TASK"

echo "Completed noxn post-prediction"
