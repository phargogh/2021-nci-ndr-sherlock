#!/bin/bash
#
#SBATCH --job-name=test
#
#SBATCH --time=10:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=2G

srun python test-python-multiprocessing.py
