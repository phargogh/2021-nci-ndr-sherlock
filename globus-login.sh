#!/usr/bin/env sh

set -e  # fail on nonzero exit code

# load endpoint IDs, shared across scripts
source globus-endpoints.env

echo "Checking to see if you're logged in to Globus"
globus login  # exit code 4 if not logged in

echo "Checking access to Globus:Oak"
globus collection show "$GLOBUS_OAK_COLLECTION_ID" || globus login --gcs "$GLOBUS_OAK_COLLECTION_ID"  # exit code 4 if not logged in

echo "Checking access to Globus:Scratch"
globus endpoint show "$GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID" || login "$GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID"  # exit code 4 if not logged in (automatically logged in if on Sherlock)

echo "Checking access to Globus:Stanford GDrive"
globus collection show "$GLOBUS_STANFORD_GDRIVE_COLLECTION_ID"  || login --gcs "$GLOBUS_STANFORD_GDRIVE_COLLECTION_ID"  # exit code 4 if not logged in

# If the script completed, then everything should be fine for copying files around later.
echo "Looks like everything is set up to copy files around for NCI"
