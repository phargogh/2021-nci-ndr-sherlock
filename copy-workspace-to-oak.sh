#!/bin/bash
#
#SBATCH --time=4:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI-copy-workspace-to-oak"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out

SOURCE_NCI_WQ_WORKSPACE=$(cat $1 | sed "s|$SCRATCH||g")
BASENAME=$(basename "$1")

TARGET_PARENT_DIR="$OAK/nci/wq-latest"

# These are obtained by `globus bookmark list` from JD's globus bookmarks
GLOBUS_OAK_ENDPOINT=8b3a8b64-d4ab-4551-b37e-ca0092f769a7
GLOBUS_SCRATCH_ENDPOINT=6881ae2e-db26-11e5-9772-22000b9da45e

# We only want to keep the latest workspace around, so just delete the prior one.
# This globus call is blocking.
globus rm --ignore-missing "$GLOBUS_OAK_ENDPOINT:/nci/wq-latest/*"

globus transfer "$GLOBUS_SCRATCH_ENDPOINT:$SOURCE_NCI_WQ_WORKSPACE" "$GLOBUS_OAK_ENDPOINT:/nci/wq-latest/$BASENAME"

echo "Transfer request submitted for $TARGET_PARENT_DIR/$BASENAME"
