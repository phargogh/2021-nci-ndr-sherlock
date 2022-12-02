#!/bin/bash
#
#SBATCH --time=2:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out
#SBATCH --job-name="NCI-sync-gdrive"
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.

set -e
set -x
module load system rclone
rclone sync nci-whole-project-stanford-gdrive:/inputs/ "$SCRATCH/nci-gdrive/inputs/"
echo "Finished syncing NCI gdrive inputs to SCRATCH"
