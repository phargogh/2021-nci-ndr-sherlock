#!/bin/bash
#
#SBATCH --time=4:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=6G
#SBATCH --mail-type=ALL
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI-NOXN-pipeline"
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
    --kwargs_pickle_file="$PREDICTION_PICKLE_FILE" | grep -o "[0-9]\\+"
