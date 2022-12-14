#!/bin/bash
#
#SBATCH --time=0:10:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=jdouglass@stanford.edu
#SBATCH --partition=hns,normal
#SBATCH --job-name="Test-logging-throughput"

set -x
module load python/3.9.0
PYTHON=python3
$PYTHON --version

RESULTS_CSV="results.csv"
for _ in {0..100}
do
    $PYTHON test-buffered-logfile.py $RESULTS_CSV
done
echo "done!"
