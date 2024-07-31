#!/bin/bash
#
#SBATCH --time=12:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu,iamadden@stanford.edu,rschmitt@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI-NOXN-prediction"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out
#
# This script assumes that the task name will be set by the calling sbatch command.
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.
set -e
set -x

PREDICTION_PICKLE_FILE="$1"

source "../env-sherlock.env"

singularity run "docker://$NOXN_DOCKER_CONTAINER" \
    python cli-wrap.py pipeline._wrapped_slurm_cmd_function \
    --target="pipeline.predict" \
    --kwargs_pickle_file="$PREDICTION_PICKLE_FILE"

echo "Completed prediction for $PREDICTION_PICKLE_FILE"
