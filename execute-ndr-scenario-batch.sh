#!/bin/bash
set -e
set -x

# Fetch the repository
REPOSLUG=ndr_plus_global_pipeline
REPO=https://github.com/phargogh/$REPOSLUG.git
REVISION=7401d767c84fbe2fb1aa0b0d00eae44fb33637c0
if [ ! -d $REPOSLUG ]
then
    git clone $REPO
fi
pushd $REPOSLUG

# OK to always fetch the repo
git fetch
git checkout $REVISION
# Sherlock still has python2, so need to specify python3 (3.6 is installed)
SCENARIOS=$(python3 -c "import scenarios.nci_global as s; print('\n'.join(k for k in s.SCENARIOS))")
popd

DATE="$(date +%F)"
GIT_REV="rev$(git rev-parse --short HEAD)"

# According to https://slurm.schedmd.com/sbatch.html#SECTION_PERFORMANCE,
# we're not supposed to call sbatch from within a loop.  A loop is the only way
# this makes sense, though, and it isn't usually very many.  I've added a sleep
# to help avoid a possible denial-of-service.
SLURM_DEPENDENCY_STRING="afterok"
for NCI_SCENARIO in $SCENARIOS
do
    # Can also redirect stdout/stderr if needed:
    #--output=$SCRATCH/NCI-$NCI_SCENARIO-%j.out
    #--error=$SCRATCH/NCI-$NCI_SCENARIO-%j.err

    WORKSPACE_DIR=NCI-NDRplus-$NCI_SCENARIO
    SCENARIO_JOB_ID=$(sbatch \
        --job-name="NCI-NDRplus-$NCI_SCENARIO-global-$DATE" \
        --chdir=$REPOSLUG \
        execute-ndr-specific-scenario.sh \
        "$WORKSPACE_DIR" "$NCI_SCENARIO" "$DATE" "$GIT_REV" | grep -o [0-9]\\+)
    SLURM_DEPENDENCY_STRING="$SLURM_DEPENDENCY_STRING:$SCENARIO_JOB_ID"
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
        --dependency="$SLURM_DEPENDENCY_STRING" \
        ./execute-noxn.sh
fi
