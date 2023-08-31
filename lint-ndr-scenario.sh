#!/bin/bash
#
#SBATCH --time=0:10:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="NCI-lint-scenario-before-ndr-runs"
#SBATCH --output=/scratch/users/jadoug06/slurm-logfiles/slurm-%j.%x.out
#
# --partition=hns,normal means that this will be submitted to both queues, whichever gets to it first will be used.


CONTAINER=ghcr.io/natcap-nci/devstack
DIGEST=sha256:6c4a3233395b304a9d2eac57f954acf63b8dc477f5b997857a8a89f135cb5f34
export APPTAINER_DOCKER_USERNAME="$GHCR_USERNAME"  # My github username
export APPTAINER_DOCKER_PASSWORD="$GHCR_TOKEN"     # My GHCR token
LINT_SCRIPT="$(pwd)/lint-ndr-scenario.py"
SCENARIO_TO_LINT="nci_global_aug_2023_wq_paper"
singularity run \
    --pwd "ndr_plus_global_pipeline"
    --env NCI_NDR_LULC_JSON="$1" \
    --env NCI_NDR_N_APP_JSON="$2" \
    docker://$CONTAINER@$DIGEST \
    python "$LINT_SCRIPT" "$SCENARIO_TO_LINT"
