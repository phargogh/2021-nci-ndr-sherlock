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
            --format jobid,jobname,partition,account,alloccpus,state,exitcode,reserved | grep NDR >> $outfile
    done
done

CPUCORES=$(cat $outfile | awk '{ print $5 }' | paste -sd+ - | bc)
echo "Total cpu cores requested: $CPUCORES"

#REQUESTEDTIME=$(cat $outfile | awk '{ print $8 }'
#echo "

