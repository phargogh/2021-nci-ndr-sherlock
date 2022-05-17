#!/bin/bash

outfile="ndr_runs.txt"
rm -f $outfile
for yyyy in {2021..2022}
do
    for mm in {01..12}
    do
        sacct -u jadoug06 \
            --starttime $yyyy-$mm-01 \
            --endtime $yyyy-$mm-31 \
            --format jobid,jobname%60,partition,account,alloccpus,state%40,exitcode,reserved,cputime >> $outfile
    done
done

CPUCORES=$(cat $outfile | grep NDR | awk '{ print $5 }' | paste -sd+ - | bc)
echo "Total NDR cpu cores requested: $CPUCORES"

CPUCORES=$(cat $outfile | grep noxn | awk '{ print $5 }' | paste -sd+ - | bc)
echo "Total NOXN cpu cores requested: $CPUCORES"

ELAPSEDTIME=$(cat $outfile | grep NDR | awk '{ print $9 }' | python sum_slurm_cputime.py)
echo "Total requested time: $ELAPSEDTIME"

