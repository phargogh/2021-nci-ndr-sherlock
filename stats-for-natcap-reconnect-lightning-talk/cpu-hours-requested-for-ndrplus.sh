#!/bin/bash

for yyyy in {2021..2022}
do
    for mm in {01..12}
    do
        echo "sacct -u jadoug06 --starttime \"$yyyy-$mm-01\" --endtime \"$yyyy-$mm-31\" | grep NDR"
    done
done
