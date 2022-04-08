.PHONY: ndr-batch show-job-queue show-job-status noxn-1km noxn-10km all

JOBIDS := $(shell awk '{ print $2 }' scenario_jobs.txt | paste -sd ',' -)

ndr-batch:
	bash ./execute-ndr-scenario-batch.sh

noxn-1km:
	sbatch --time=8:00:00 ./execute-noxn.sh 1km

noxn-10km:
	sbatch --time=1:00:00 ./execute-noxn.sh 10km

noxn-100km:
	sbatch --time=0:10:00 ./execute-noxn.sh 100km

all:
	bash ./execute-ndr-scenario-batch.sh --with-noxn

show-job-queue:
	squeue --jobs=$(JOBIDS) --format="%A, %M, %j"

show-job-status:
	sacct --format="JOBIDRaw,Start,Elapsed,State" --jobs=$(JOBIDS)
