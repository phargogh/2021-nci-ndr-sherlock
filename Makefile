.PHONY: ndr-batch show-job-queue show-job-status noxn-1km noxn-10km all

JOBIDS := $(shell awk '{ print $2 }' scenario_jobs.txt | paste -sd ',' -)

ndr-batch:
	bash ./execute-ndr-scenario-batch.sh

noxn-1km:
	sbatch ./execute-noxn.sh 1km --time=8:00:00

noxn-10km:
	sbatch ./execute-noxn.sh 10km --time=1:00:00

all:
	bash ./execute-ndr-scenario-batch.sh --with-noxn

show-job-queue:
	squeue --jobs=$(JOBIDS) --format="%A, %M, %j"

show-job-status:
	sacct --format="JOBIDRaw,Start,Elapsed,State" --jobs=$(JOBIDS)
