#!/bin/bash
set -e
set -x

CONTAINER=ghcr.io/phargogh/inspring-no-gcloud-keys
DIGEST=sha256:66c4a760dece610f992ee2f2aa4fff6a8d9e96951bf6f9a81bf16779aa7f26c4

# Fetch the repository
REPOSLUG=ndr_plus_global_pipeline
REPO=https://github.com/phargogh/$REPOSLUG.git
REVISION=4bb34ec6032e828a7bc337f48ee56a2b68f6dfb3
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

for NCI_SCENARIO in $SCENARIOS
do
    WORKSPACE_DIR=NCI-NDRplus-$NCI_SCENARIO
    SCENARIO_JOB_ID=$(sbatch \
        --job-name=NCI-NDRplus-$NCI_SCENARIO-global-rerun-Oct-2021 \
        --chdir=$REPOSLUG \
        execute-ndr-specific-scenario.sh \
        $WORKSPACE_DIR $NCI_SCENARIO $DATE $GIT_REV | grep -o [0-9]\\+)
    echo "$NCI_SCENARIO $SCENARIO_JOB_ID" >> scenario_jobs.txt
done
