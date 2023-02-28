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

SOURCE_NCI_WQ_WORKSPACE="$1"
BASENAME=$(basename "$1")

TARGET_PARENT_DIR="$OAK/nci/wq-latest"

# We only want to keep the latest workspace around, so just delete the prior one
rm -r "${TARGET_PARENT_DIR:?}/*" || echo "Directory not found; skipping: $TARGET_PARENT_DIR"

mkdir -p "$TARGET_PARENT_DIR" || echo "Directory already exists: $TARGET_PARENT_DIR"
cp -rv "$SOURCE_NCI_WQ_WORKSPACE" "$TARGET_PARENT_DIR/$BASENAME"

echo "Copy complete!"
echo "View the outputs at $TARGET_PARENT_DIR/$BASENAME"
