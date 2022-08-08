.PHONY: ndr-batch show-job-queue show-job-status noxn-1km noxn-10km all

JOBIDS := $(shell awk '{ print $2 }' scenario_jobs.txt | paste -sd ',' -)
GIT_REV := rev$(shell git rev-parse --short HEAD)
DATE := $(shell date +%F)

print-%:
	@echo "$* = $($*)"

ndr-batch:
	bash ./execute-ndr-scenario-batch.sh >> $@-$(DATE)-$(GIT_REV).log 2>&1

noxn-1km:
	sbatch --time=16:00:00 ./execute-noxn.sh 1km

noxn-10km:
	sbatch --time=4:00:00 ./execute-noxn.sh 10km

all:
	bash ./execute-ndr-scenario-batch.sh --with-noxn 10km >> $@-$(DATE)-$(GIT_REV).log 2>&1

all-1km:
	bash ./execute-ndr-scenario-batch.sh --with-noxn 1km >> $@-$(DATE)-$(GIT_REV).log 2>&1

show-job-queue:
	squeue --jobs=$(JOBIDS) --format="%A, %M, %j"

show-job-status:
	sacct --format="JOBIDRaw,Start,Elapsed,State" --jobs=$(JOBIDS)
