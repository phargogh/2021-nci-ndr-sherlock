#!/bin/bash
#
#SBATCH --job-name=Test-Copying-from-$L_SCRATCH-at-end-of-job
#
#SBATCH --time=00:10:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G

# Hypothesis:
# If I'm reading the SLURM docs correctly, I should be able to finish an
# entire sbatch script before the $L_SCRATCH partition is erased at the end of
#the job.

# Generating a 1GB file with random data in it.
# Taken from https://superuser.com/a/470957
FILENAME=1GB-random-data.txt
SOURCE_FILENAME=$L_SCRATCH/$FILENAME
TARGET_FILENAME=$SCRATCH/$FILENAME
srun openssl rand -out $SOURCE_FILENAME -base64 $(( 2**30 * 3/4 )) && cp $SOURCE_FILENAME $TARGET_FILENAME

# Conclusion:
# A single `srun` command appears to be a single "job", so local scratch files
# MUST be copied out of $L_SCRATCH to a different filesystem within the
# same `srun` operation.
