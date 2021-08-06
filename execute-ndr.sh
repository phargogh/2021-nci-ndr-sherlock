#!/bin/bash
#
#SBATCH --job-name=NCI-NDR-plus-for-BCK-and-Rafa
#
#SBATCH --time=30:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=4G

NDR_WORKSPACE_NAME=global_ndr_plus_workspace

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
if [ -L $NDR_WORKSPACE_NAME ]
then
    rm $NDR_WORKSPACE_NAME
fi

TARGET_WORKSPACE_FILESYSTEM=$L_SCRATCH
if [ ! -L $NDR_WORKSPACE_NAME ]
then
    ln -s $TARGET_WORKSPACE_FILESYSTEM/$NDR_WORKSPACE_NAME
fi

CONTAINER=ghcr.io/phargogh/inspring-no-gcloud-keys
DIGEST=sha256:66c4a760dece610f992ee2f2aa4fff6a8d9e96951bf6f9a81bf16779aa7f26c4

srun singularity run docker://$CONTAINER@$DIGEST \
	global_ndr_plus_pipeline.py scenarios.nci_global_1 --n_workers=40 && \
    cp -r $TARGET_WORKSPACE_FILESYSTEM/$NDR_WORKSPACE_NAME $SCRATCH/2021-NCI-$NDR_WORKSPACE_NAME
