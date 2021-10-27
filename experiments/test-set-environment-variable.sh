#!/bin/bash
#
#SBATCH --job-name=Test-environment-vars-across-sruns
#
#SBATCH --time=00:10:00
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G

# Hypothesis:
# I expect to be able to set an environment variable as I would expect from bash.
#
# I also expect the output file to look like this:
#
# 111
# 222
#
# Meaning that each srun occupied only 1 slurm task.

TARGET_FILE = $HOME/out_file.txt

VARNAME=111
srun --export=ALL bash -c 'echo "$VARNAME" >> $TARGET_FILE'

VARNAME=222
srun --export=ALL bash -c 'echo "$VARNAME" >> $TARGET_FILE'
