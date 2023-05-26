#!/bin/bash
#
#SBATCH --time=10:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=16G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI-NOXN-snakemake"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out
#
# This script assumes that the task name will be set by the calling sbatch command.
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.
set -e
set -x

#CONTAINER=ghcr.io/natcap/natcap-noxn-levels
#DIGEST=sha256:2a92ced1387bbfe580065ef98a61f6d360daf90f3afa54cf4383b0becf7480e8
#singularity run \
#    docker://$CONTAINER@$DIGEST \
#    snakemake \
#        calories \
#        --slurm \
#        --default-resources \
#            slurm_partition=normal,hns \

# goal: get calories to run within snakemake
cd nci-noxn-levels
snakemake --unlock
snakemake calories \
    --cores=4 \
    --slurm \
    --singularity-prefix="$SCRATCH/singularity-cache" \
    --jobs=10 \
    --configfile=Snakefile.config.sherlock.json \
    --use-singularity


