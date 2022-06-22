.PHONY: ndr-batch show-job-queue show-job-status noxn-1km noxn-10km all

JOBIDS := $(shell awk '{ print $2 }' scenario_jobs.txt | paste -sd ',' -)

ndr-batch:
	bash ./execute-ndr-scenario-batch.sh

noxn-1km:
	sbatch --time=16:00:00 ./execute-noxn.sh 1km

noxn-10km:
	sbatch --time=4:00:00 ./execute-noxn.sh 10km

# Useful as a smoke test
noxn-100km:
	sbatch --time=2:00:00 ./execute-noxn.sh 100km

all:
	bash ./execute-ndr-scenario-batch.sh --with-noxn

show-job-queue:
	squeue --jobs=$(JOBIDS) --format="%A, %M, %j"

show-job-status:
	sacct --format="JOBIDRaw,Start,Elapsed,State" --jobs=$(JOBIDS)
