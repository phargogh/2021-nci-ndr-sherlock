#!/bin/bash
#
#SBATCH --job-name=Test-environment-vars-across-sruns
#
#SBATCH --time=00:00:30
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

TARGET_FILE=$HOME/out_file.txt

VARNAME=111
srun bash -c "echo $VARNAME >> $TARGET_FILE"

VARNAME=222
srun bash -c "echo $VARNAME >> $TARGET_FILE"

# Conclusion:
# The above is what's needed (possibly without the --export=ALL) in order to
# pass environment variables to an srun command like so.
#
# But also, since we're running a singularity command, `singularity run` can
# just take the --env option to pass environment variables into the contained
# process.  See the CLI reference for the currently-installed version at:
# https://sylabs.io/guides/3.8/user-guide/cli/singularity_run.html?highlight=--env
