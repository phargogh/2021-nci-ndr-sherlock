#!/bin/bash
#
#SBATCH --time=10:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --job-name=RClone-NCI-files-to-gdrive


TARGET_DIR=2021-10-29-ndr-nci
module load system rclone

for file in `ls $SCRATCH/*NCI-NDRplus*/*.tif`
do
    SCENARIO=$(basename $(dirname $file) | sed 's/2021-NCI-NCI-NDRplus-//g')
    rclone copy --progress $file "nci-ndr-stanford-gdrive:$TARGET_DIR/$SCENARIO"
done
