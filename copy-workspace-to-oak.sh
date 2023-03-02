#!/bin/bash
#
#SBATCH --time=1:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI-copy-workspace-to-oak"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out

set -x

SOURCE_NCI_WQ_WORKSPACE="${1//$SCRATCH/}"  # replace $SCRATCH with empty string
BASENAME=$(basename "$1")

TARGET_PARENT_DIR="nci/wq-latest"
OAK_TARGET_PARENT_DIR="$OAK/$TARGET_PARENT_DIR"

# These are obtained by `globus bookmark list` from JD's globus bookmarks
GLOBUS_OAK_ENDPOINT="8b3a8b64-d4ab-4551-b37e-ca0092f769a7"
GLOBUS_SCRATCH_ENDPOINT="6881ae2e-db26-11e5-9772-22000b9da45e"

# We only want to keep the latest workspace around, so just delete the prior one.
# rm -r is super fast compared with using globus to delete the directory.
# There's so much to delete that the globus job will time out!
rm -r "${OAK_TARGET_PARENT_DIR:?}/*" || echo "Could not remove $OAK_TARGET_PARENT_DIR"

globus transfer "$GLOBUS_SCRATCH_ENDPOINT:$SOURCE_NCI_WQ_WORKSPACE" "$GLOBUS_OAK_ENDPOINT:/$TARGET_PARENT_DIR/$BASENAME"

echo "Transfer request submitted for $OAK_TARGET_PARENT_DIR/$BASENAME"
