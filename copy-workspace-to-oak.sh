#!/bin/bash
#
#SBATCH --time=0:10:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI-copy-workspace-to-oak"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out

set -ex

GLOBUS_OAK_COLLECTION_ID="8b3a8b64-d4ab-4551-b37e-ca0092f769a7"  # as of writing, Oak uses GCS v5
GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID="6881ae2e-db26-11e5-9772-22000b9da45e"  # As of writing, Sherlock uses GCS v4

SOURCE_NCI_WQ_WORKSPACE="${1:Source path required as arg1?}"
BASENAME=$(basename "$1")


# We only want to keep the latest workspace around, so just delete the prior one.
# rm -r is super fast compared with using globus to delete the directory.
# There's so much to delete that the globus job will time out!
TARGET_PARENT_DIR="nci/wq-latest"
OAK_TARGET_PARENT_DIR="$OAK/$TARGET_PARENT_DIR"
rm -r "${OAK_TARGET_PARENT_DIR:?}/*" || echo "Could not remove $OAK_TARGET_PARENT_DIR"

globus transfer --fail-on-quota-errors --recursive \
    "$GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID:$SOURCE_NCI_WQ_WORKSPACE" \
    "$GLOBUS_OAK_COLLECTION_ID:$OAK/$TARGET_PARENT_DIR/$BASENAME"

echo "Transfer request submitted for $OAK_TARGET_PARENT_DIR/$BASENAME"
echo "Done!"
