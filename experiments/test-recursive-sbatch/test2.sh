#!/bin/bash
#
#SBATCH --time=0:01:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="Test2-sbatch-recursive"
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.


set -e
set -x

echo "Test 2! ${SLURM_JOB_ID}"
