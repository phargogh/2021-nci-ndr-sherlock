.PHONY: ndr-batch show-job-queue show-job-status noxn all

JOBIDS := $(shell awk '{ print $2 }' scenario_jobs.txt | paste -sd ',' -)

ndr-batch:
	bash ./execute-ndr-scenario-batch.sh

noxn:
	sbatch ./execute-noxn.sh

all:
	bash ./execute-ndr-scenario-batch.sh --with-noxn

show-job-queue:
	squeue --jobs=$(JOBIDS) --format="%A, %M, %j"

show-job-status:
	sacct --format="JOBIDRaw,Start,Elapsed,State" --jobs=$(JOBIDS)
