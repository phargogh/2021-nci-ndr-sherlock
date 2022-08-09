.PHONY: ndr-batch show-job-queue show-job-status noxn-1km noxn-10km all

JOBIDS := $(shell awk '{ print $2 }' scenario_jobs.txt | paste -sd ',' -)
GIT_REV := rev$(shell git rev-parse --short HEAD)
DATE := $(shell date +%F)

print-%:
	@echo "$* = $($*)"

when-might-ndr-run:
	sbatch --test-only -p normal ./execute-ndr-specific-scenario.sh
	sbatch --test-only -p hns ./execute-ndr-specific-scenario.sh

ndr-batch:
	bash ./execute-ndr-scenario-batch.sh 2>&1 | tee -a $@-$(DATE)-$(GIT_REV).log

noxn-1km:
	sbatch --time=16:00:00 ./execute-noxn.sh 1km

noxn-10km:
	sbatch --time=4:00:00 ./execute-noxn.sh 10km

all:
	bash ./execute-ndr-scenario-batch.sh --with-noxn 10km 2>&1 | tee -a $@-$(DATE)-$(GIT_REV).log

all-1km:
	bash ./execute-ndr-scenario-batch.sh --with-noxn 1km 2>&1 | tee -a $@-$(DATE)-$(GIT_REV).log

show-job-queue:
	squeue --jobs=$(JOBIDS) --format="%A, %M, %j"

show-job-status:
	sacct --format="JOBIDRaw,Start,Elapsed,State" --jobs=$(JOBIDS)
