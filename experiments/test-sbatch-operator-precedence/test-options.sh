#!/bin/bash
#SBATCH --time=00:00:05
#SBATCH --partition=hns,normal

for i in {0..100}
do
    echo $i
    sleep 3
done
