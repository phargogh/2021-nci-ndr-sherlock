#!/bin/bash
set -e

DATE="$(date +%F)"
GIT_REV="rev$(git rev-list HEAD --count)-$(git rev-parse --short HEAD)"
REPOSLUG=ndr_plus_global_pipeline
REPO=https://github.com/phargogh/$REPOSLUG.git

echo "***********************************************************************"
echo "Beginning NDR Batch"
echo "Including: "
echo "   LULC script processing"
echo "   N Application processing"
echo "   NDR scenarios"
echo "   Water Quality"
echo "Started $DATE"
echo "Sherlock repo rev: $GIT_REV"
echo "NDR repo rev: $(git -C $REPOSLUG rev-parse HEAD)"
echo "Extra args: $1 $2"
echo "***********************************************************************"

set -x
LOCAL_GDRIVE_INPUTS_DIR="$SCRATCH/nci-gdrive/inputs"  # A local rsync clone of the NCI google drive
LOCAL_GDRIVE_CALORIES_DIR="$SCRATCH/nci-gdrive/calories"  # A local rsync clone of the NCI google drive

FULL_WQ_PIPELINE_WORKSPACE="$SCRATCH/NCI-WQ-full-${DATE}-${GIT_REV}"
rm -r "$FULL_WQ_PIPELINE_WORKSPACE" || echo "Cannot remove directory that isn't there."
mkdir -p "$FULL_WQ_PIPELINE_WORKSPACE" || echo "Cannot create directory that exists."

# Fetch the repository
if [ ! -d $REPOSLUG ]
then
    git clone $REPO
fi
pushd $REPOSLUG

# Sherlock still has python2, so need to specify python3
module load python/3.9.0

# having the numpy module loaded causes problems at import time for the
# singularity container, where the system-loaded numpy will override the one in
# the container.
module unload numpy

# We only need the scenario names, not the keys.  We won't know all the files
# that are used in the scenarios until the `build-ndr-scenarios.sh` and
# `build-n-app-scenarios.sh` tasks finish.
SCENARIOS=$(python3 -c "import scenarios.nci_global_dec_2022 as s; print('\n'.join(k for k in s.SCENARIOS))")
popd

SCENARIOS_WORKSPACE="$FULL_WQ_PIPELINE_WORKSPACE/prepared-scenarios"
PREPROCESSED_SCENARIOS_JOB=$(sbatch \
    --job-name="NCI-WQ-create-scenarios-$GIT_REV" \
    prep-ndr-inputs-pipeline.sh \
    "$LOCAL_GDRIVE_INPUTS_DIR" \
    "$SCENARIOS_WORKSPACE" \
    "$FULL_WQ_PIPELINE_WORKSPACE" | grep -o "[0-9]\\+")

# According to https://slurm.schedmd.com/sbatch.html#SECTION_PERFORMANCE,
# we're not supposed to call sbatch from within a loop.  A loop is the only way
# this makes sense, though, and it isn't usually very many.  I've added a sleep
# to help avoid a possible denial-of-service.
NOXN_SLURM_DEPENDENCY_STRING="afterok"
for NCI_SCENARIO in $SCENARIOS
do
    # Can also redirect stdout/stderr if needed:
    #--output=$SCRATCH/NCI-$NCI_SCENARIO-%j.out
    #--error=$SCRATCH/NCI-$NCI_SCENARIO-%j.err

    WORKSPACE_DIR=NCI-NDRplus-$GIT_REV-$NCI_SCENARIO
    SCENARIO_JOB_ID=$(sbatch \
        --job-name="NCI-NDR-$NCI_SCENARIO-$DATE" \
        --chdir=$REPOSLUG \
        --dependency="afterok:$PREPROCESSED_SCENARIOS_JOB" \
        execute-ndr-specific-scenario.sh \
        "$WORKSPACE_DIR" \
        "$NCI_SCENARIO" \
        "$DATE" \
        "$GIT_REV" \
        "$FULL_WQ_PIPELINE_WORKSPACE" \
        "$SCENARIOS_WORKSPACE/scenario_rasters.json" | grep -o "[0-9]\\+")
    NOXN_SLURM_DEPENDENCY_STRING="$NOXN_SLURM_DEPENDENCY_STRING:$SCENARIO_JOB_ID"
    echo "$NCI_SCENARIO $SCENARIO_JOB_ID" >> scenario_jobs.txt

    # Give slurmctld a break for 2s just to be safe, in case they try to deny
    # our submission.
    sleep 2s
done

# --dependency=afterok:<jobid>
if [ "$1" = "--with-noxn" ]
then
    if [ "$2" = "1km" ]
    then
        NOXN_TIME="10:00:00"
        NOXN_SPATIAL_CONFIG_FILE="nci-noxn-levels/pipeline.config-sherlock-1km.json"
    else
        NOXN_TIME="5:00:00"
        NOXN_SPATIAL_CONFIG_FILE="nci-noxn-levels/pipeline.config-sherlock-10km.json"
    fi
    # --dependency=afterok:<id1>:<id2>... means that if the whole NDR pipeline
    # passes, then we'll trigger the NOXN pipeline.
    NOXN_JOB_ID=$(sbatch \
        --dependency="$NOXN_SLURM_DEPENDENCY_STRING" \
        --time="$NOXN_TIME" \
        ./execute-noxn.sh \
        "$2" \
        "$GIT_REV" \
        "$FULL_WQ_PIPELINE_WORKSPACE/noxn" \
        "$FULL_WQ_PIPELINE_WORKSPACE" \
        "$LOCAL_GDRIVE_CALORIES_DIR" \
        "$SCENARIOS_WORKSPACE/scenario_rasters.json" | grep -o "[0-9]\\+")

    # Calories relies only on the preprocessed scenarios job.
    CALORIES_JOB=$(sbatch \
        --job-name="NCI-WQ-calories-$GIT_REV" \
        execute-calories.sh \
        "$FULL_WQ_PIPELINE_WORKSPACE/calories" \
        "$FULL_WQ_PIPELINE_WORKSPACE" \
        "$LOCAL_GDRIVE_CALORIES_DIR" \
        "$SCENARIOS_WORKSPACE/scenario_rasters.json" \
        "$NOXN_SPATIAL_CONFIG_FILE" | grep -o "[0-9]\\+")

fi

# copy the whole job over to oak once it's all complete.
sbatch \
    --dependency="afterok:$NOXN_JOB_ID:$CALORIES_JOB" \
    ./copy-workspace-to-oak.sh "$FULL_WQ_PIPELINE_WORKSPACE"
