#!/usr/bin/env sh

set -e  # fail on nonzero exit code

# load endpoint IDs, shared across scripts
source globus-endpoints.env

echo "Checking to see if you're logged in to Globus"
globus login  # exit code 4 if not logged in

echo "Checking your current session identity"
globus session show

echo "Checking access to Globus:Oak"
globus collection show "$GLOBUS_OAK_COLLECTION_ID" || globus login --gcs "$GLOBUS_OAK_COLLECTION_ID"  # exit code 4 if not logged in

echo "Checking scopes on Globus:Oak"
globus ls $GLOBUS_OAK_COLLECTION_ID --filter=abcd1234

echo "Checking access to Globus:Scratch"
globus collection show "$GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID" || globus login --gcs "$GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID"  # exit code 4 if not logged in (automatically logged in if on Sherlock)

echo "Checking scopes on Globus:Oak"
globus ls $GLOBUS_SHERLOCK_SCRATCH_ENDPOINT_ID --filter=abcd1234

echo "Checking access to Globus:Stanford GDrive"
globus collection show "$GLOBUS_STANFORD_GDRIVE_COLLECTION_ID"  || globus login --gcs "$GLOBUS_STANFORD_GDRIVE_COLLECTION_ID"  # exit code 4 if not logged in

echo "Checking scopes on Globus:Stanford GDrive"
globus ls $GLOBUS_STANFORD_GDRIVE_COLLECTION_ID --filter=abcd1234

# If the script completed, then everything should be fine for copying files around later.
echo "Looks like everything is set up to copy files around for NCI"
