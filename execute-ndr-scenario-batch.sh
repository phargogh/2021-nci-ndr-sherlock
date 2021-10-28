#!/bin/bash
set -e
set -x

CONTAINER=ghcr.io/phargogh/inspring-no-gcloud-keys
DIGEST=sha256:66c4a760dece610f992ee2f2aa4fff6a8d9e96951bf6f9a81bf16779aa7f26c4

# Fetch the repository
REPOSLUG=ndr_plus_global_pipeline
REPO=https://github.com/phargogh/$REPOSLUG.git
REVISION=82c0f8b3ccc57614335eeb62c50f8261ed1ef171
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

for NCI_SCENARIO in $SCENARIOS
do
    SCENARIO_JOB_ID=$(sbatch --job-name=NCI-NDR-plus-global-rerun-Oct-2021-$NCI_SCENARIO \
        execute-ndr-specific-scenario.sh \
        NCI-NDRplus-$NCI_SCENARIO $NCI_SCENARIO | grep -o [0-9]\\+)
    echo "$NCI_SCENARIO $SCENARIO_JOB_ID" >> scenario_jobs.txt
done
