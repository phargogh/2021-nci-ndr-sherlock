#!/usr/bin/env sh

set -e  # fail on nonzero exit code

# load endpoint IDs, shared across scripts
source globus-endpoints.env

globus whoami  # exit code 4 if not logged in
globus collection show "$GLOBUS_OAK_COLLECTION_ID"  # exit code 4 if not logged in
globus endpoint show "$GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID"  # exit code 4 if not logged in (automatically logged in if on Sherlock)
globus collection show "$GLOBUS_STANFORD_GDRIVE_COLLECTION_ID"  # exit code 4 if not logged in

# If the script completed, then everything should be fine for copying files around later.
echo "Looks like everything is set up to copy files around for NCI"
