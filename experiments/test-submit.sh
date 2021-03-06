#!/bin/bash
#
#Copied from the sherlock tutorial https://www.sherlock.stanford.edu/docs/getting-started/submitting/#how-to-submit-a-job
#
#SBATCH --job-name=test
#
#SBATCH --time=10:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G

srun hostname
srun sleep 60
