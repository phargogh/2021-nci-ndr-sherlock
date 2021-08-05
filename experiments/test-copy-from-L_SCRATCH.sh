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
FILENAME=1GB-random-data.txt
SOURCE_FILENAME=$L_SCRATCH/$FILENAME
TARGET_FILENAME=$SCRATCH/$FILENAME
srun openssl rand -out $SOURCE_FILENAME -base64 $(( 2**30 * 3/4 ))

cp $SOURCE_FILENAME $TARGET_FILENAME

# Conclusion:
#
