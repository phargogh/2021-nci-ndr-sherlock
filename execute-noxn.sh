#!/bin/bash
#
#SBATCH --time=2:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#BBATCH --job-name="NCI-NOXN-Mar-2022"
#
# This script assumes that the task name will be set by the calling sbatch command.
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.
set -e
set -x

# Container configuration
#
# NOTE: this is currently a private repository, so it'll be easier to cache
# this locally before the NOXN run.  I did this with:
#    $ singularity pull --docker-login docker://ghcr.io/natcap/natcap-noxn-levels
# which then prompted me for my username and GHCR password (authentication token).
# See the singularity docs on the subject for more info:
# https://sylabs.io/guides/3.0/user-guide/singularity_and_docker.html#making-use-of-private-images-from-docker-hub
CONTAINER=ghcr.io/natcap/natcap-noxn-levels
DIGEST=sha256:b6e7a1a251a4047a1c69fc253e3fde320eff2221ea55d90b155619702fefade3

# Fetch the repository
# NOTE: This repo is private and so requires that sherlock is configured for SSH access.
REPOSLUG=nci-noxn-levels
REPO=git@github.com:natcap/$REPOSLUG.git
REVISION=8df90d5599372449904518df3ea719290cb52185
if [ ! -d $REPOSLUG ]
then
    git clone $REPO
fi
pushd $REPOSLUG

# OK to always fetch the repo
git fetch
git checkout $REVISION

DATE="$(date +%F)"
GIT_REV="rev$(git rev-parse --short HEAD)"

# copy files from scratch workspaces to local machine.
NDR_OUTPUTS_DIR=$L_SCRATCH/NCI-ndr-plus-outputs
mkdir "$NDR_OUTPUTS_DIR"
for ndroutput in `find "$SCRATCH/2021-NCI*" -name "compressed_*.tif"`
do
    # Copy files, presreving permissions
    cp -pv "$ndroutput" "$NDR_OUTPUTS_DIR"
done

# run job
WORKSPACE_DIR=$L_SCRATCH/NCI-NOXN-workspace
singularity run \
    docker://$CONTAINER@$DIGEST \
    pipeline.py --n_workers=40 "$WORKSPACE_DIR" "$NDR_OUTPUTS_DIR"

# rsync the files back to $SCRATCH
# rsync -avz is equivalent to rsync -rlptgoDvz
# Preserves permissions, timestamps, etc, which is better for taskgraph.
rsync -avz "$WORKSPACE_DIR/*" "$SCRATCH/NCI-NOXN-workspace"

# rclone the files to google drive
# The trailing slash means that files will be copied into this directory.
# Don't need to name the files explicitly.
GDRIVE_DIR="$DATE-nci-noxn-$GIT_REV/"

# Copy geotiffs AND logfiles, if any.
# $file should be the complete path to the file (it is in my tests anyways)
module load system rclone
for file in `ls $WORKSPACE_DIR/*.{tif,log}`
do
    rclone copy --progress "$file" "nci-ndr-stanford-gdrive:$GDRIVE_DIR"
done
