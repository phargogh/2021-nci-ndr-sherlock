#!/bin/bash
#
#SBATCH --time=0:10:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4GB
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="Test-memmap"

CONTAINER=ghcr.io/natcap/devstack
DIGEST=sha256:961c937a55ac8ff99219afeffe0f8509e4f142061cd3302c8133dfbe94574657

singularity run docker://$CONTAINER@$DIGEST python test-numpy-memmap.py
