#!/bin/bash
set -e

DATE="$(date +%F)"
GIT_REV="rev$(git rev-parse --short HEAD)"
REPOSLUG=ndr_plus_global_pipeline
REPO=https://github.com/phargogh/$REPOSLUG.git
NDR_REVISION=0e9dd91aefd2dfd2bdac143de9b5aca682c5e123

echo "***********************************************************************"
echo "Beginning NDR Batch"
echo "Including: "
echo "   LULC script processing"
echo "   N Application processing"
echo "   NDR scenarios"
echo "   Water Quality"
echo "Started $DATE"
echo "Sherlock repo rev: $GIT_REV"
echo "NDR repo rev: $NDR_REVISION"
echo "Extra args: $1 $2"
echo "***********************************************************************"

# - [X] sbatch the 2 scenario tasks
# - [X] make NDR scenarios dependent on the 2 scenario tasks
# - [ ] override the job name in the 2 scenario tasks
# - [ ] write the job scenario tasks to a single workspace


set -x
LULC_SCENARIOS_JOB=$(sbatch --job-name="NCI-WQ-LULC-scenarios-$GIT_REV" build-ndr-scenarios.sh)
N_APP_SCENARIOS_JOB=$(sbatch --job-name="NCI-WQ-N-application-$GIT_REV" build-n-app-scenarios.sh)

# Fetch the repository
if [ ! -d $REPOSLUG ]
then
    git clone $REPO
fi
pushd $REPOSLUG

# OK to always fetch the repo
git fetch
git checkout $NDR_REVISION
# Sherlock still has python2, so need to specify python3
module load python/3.9.0

# having the numpy module loaded causes problems at import time for the
# singularity container, where the system-loaded numpy will override the one in
# the container.
module unload numpy

# We only need the scenario names, not the keys.  We won't know all the files
# that are used in the scenarios until the `build-ndr-scenarios.sh` and
# `build-n-app-scenarios.sh` tasks finish.
SCENARIOS=$(python3 -c "import scenarios.nci_global_sept_2022_scenario_redesign as s; print('\n'.join(k for k in s.SCENARIOS))")
popd

# According to https://slurm.schedmd.com/sbatch.html#SECTION_PERFORMANCE,
# we're not supposed to call sbatch from within a loop.  A loop is the only way
# this makes sense, though, and it isn't usually very many.  I've added a sleep
# to help avoid a possible denial-of-service.
NDR_SLURM_DEPENDENCY_STRING="afterok:$LULC_SCENARIOS_JOB:$N_APP_SCENARIOS_JOB"
NOXN_SLURM_DEPENDENCY_STRING="afterok:"
for NCI_SCENARIO in $SCENARIOS
do
    # Can also redirect stdout/stderr if needed:
    #--output=$SCRATCH/NCI-$NCI_SCENARIO-%j.out
    #--error=$SCRATCH/NCI-$NCI_SCENARIO-%j.err

    WORKSPACE_DIR=NCI-NDRplus-$GIT_REV-$NCI_SCENARIO
    SCENARIO_JOB_ID=$(sbatch \
        --job-name="NCI-NDR-$NCI_SCENARIO-$DATE" \
        --chdir=$REPOSLUG \
        --dependency="$NDR_SLURM_DEPENDENCY_STRING" \
        execute-ndr-specific-scenario.sh \
        "$WORKSPACE_DIR" "$NCI_SCENARIO" "$DATE" "$GIT_REV" | grep -o [0-9]\\+)
    NOXN_SLURM_DEPENDENCY_STRING="$NOXN_SLURM_DEPENDENCY_STRING:$SCENARIO_JOB_ID"
    echo "$NCI_SCENARIO $SCENARIO_JOB_ID" >> scenario_jobs.txt

    # Give slurmctld a break for 2s just to be safe, in case they try to deny
    # our submission.
    sleep 2s
done

# --dependency=afterok:<jobid>
if [ "$1" = "--with-noxn" ]
then
    # --dependency=afterok:<id1>:<id2>... means that if the whole NDR pipeline
    # passes, then we'll trigger the NOXN pipeline.
    sbatch \
        --dependency="$NOXN_SLURM_DEPENDENCY_STRING" \
        ./execute-noxn.sh "$2" "$GIT_REV"
fi
