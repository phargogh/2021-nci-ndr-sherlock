#!/usr/bin/env sh

set -e  # fail on nonzero exit code

# load endpoint IDs, shared across scripts
source globus-endpoints.env

globus login  # exit code 4 if not logged in
globus login --gcs "$GLOBUS_OAK_COLLECTION_ID"  # exit code 4 if not logged in
globus login "$GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID"  # exit code 4 if not logged in (automatically logged in if on Sherlock)
globus login --gcs "$GLOBUS_STANFORD_GDRIVE_COLLECTION_ID"  # exit code 4 if not logged in

# If the script completed, then everything should be fine for copying files around later.
echo "Looks like everything is set up to copy files around for NCI"
