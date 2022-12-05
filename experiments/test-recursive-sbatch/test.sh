#!/bin/bash
#
#SBATCH --time=0:02:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="Test-sbatch-recursive "
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.

set -e
set -x

sbatch test2.sh --dependency=afterok:$SLURM_JOB_ID
sleep 60s
