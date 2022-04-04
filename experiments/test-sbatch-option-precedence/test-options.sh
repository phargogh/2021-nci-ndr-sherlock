#!/bin/bash
#SBATCH --time=00:05:00
#SBATCH --partition=hns,normal

for i in {0..100}
do
    echo "hello world $i"
    sleep 3
done
