#!/bin/bash
#
#SBATCH --job-name=NCI-NDR-plus-for-BCK-and-Rafa
#
#SBATCH --time=10:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem-per-cpu=4G

NDR_WORKSPACE_NAME=ndr_plus_global_workspace

# put a softlink into scratch for the workspace, easier than changing the
# source code.
if [ ! -L $NDR_WORKSPACE_NAME ]
then
    ln -s $SCRATCH/$NDR_WORKSPACE_NAME
fi

CONTAINER=ghcr.io/phargogh/inspring-no-gcloud-keys
DIGEST=sha256:ff0fd8ea1594c35dc555273666a97d15340393772c95986097ffd826d22c0dc7

srun singularity run docker://$CONTAINER@$DIGEST \
	ndr_plus_global_pipeline/global_ndr_plus_pipeline.py scenarios.nci_global_1 --n_workers=32
