#!/bin/bash
#
#SBATCH --job-name=NCI-NDR-plus-for-BCK-and-Rafa
#
#SBATCH --time=10:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem-per-cpu=4G

NDR_WORKSPACE_NAME=ndr_plus_global_workspace

REPOSLUG=ndr_plus_global_pipeline
REPO=https://github.com/phargogh/$REPOSLUG.git
REVISION=385243a649be27603af1b2ed8f3037c82ac87817
if [ ! -d $REPOSLUG ]
then
    git clone $REPO
fi

cd $REPOSLUG

# OK to always fetch the repo
git fetch
git checkout $REVISION

# put a softlink into scratch for the workspace, easier than changing the
# source code.
# this should be located within $HOME/$REPOSLUG
if [ ! -L $NDR_WORKSPACE_NAME ]
then
    ln -s $SCRATCH/$NDR_WORKSPACE_NAME
fi

CONTAINER=ghcr.io/phargogh/inspring-no-gcloud-keys
DIGEST=sha256:ff0fd8ea1594c35dc555273666a97d15340393772c95986097ffd826d22c0dc7

srun singularity run docker://$CONTAINER@$DIGEST \
	global_ndr_plus_pipeline.py scenarios.nci_global_1 --n_workers=32
