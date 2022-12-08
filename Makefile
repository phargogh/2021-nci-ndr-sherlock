.PHONY: ndr-batch show-job-queue show-job-status noxn-1km noxn-10km all sync-input-data update-submodules build-ndr-scenarios

JOBIDS := $(shell awk '{ print $2 }' scenario_jobs.txt | paste -sd ',' -)
GIT_REV := rev$(shell git rev-parse --short HEAD)
DATE := $(shell date +%F)

print-%:
	@echo "$* = $($*)"

update-submodules:
	git submodule init
	git submodule update

when-might-ndr-run:
	sbatch --test-only -p normal ./execute-ndr-specific-scenario.sh
	sbatch --test-only -p hns ./execute-ndr-specific-scenario.sh

when-might-noxn-run:
	sbatch --test-only -p normal ./execute-noxn.sh
	sbatch --test-only -p hns ./execute-noxn.sh

ndr-batch: update-submodules
	bash ./execute-ndr-scenario-batch.sh 2>&1 | tee -a $@-$(DATE)-$(GIT_REV).log

noxn-1km:
	sbatch --time=16:00:00 ./execute-noxn.sh 1km

noxn-10km:
	sbatch --time=2:00:00 ./execute-noxn.sh 10km

all: update-submodules
	bash ./execute-ndr-scenario-batch.sh --with-noxn 10km 2>&1 | tee -a $@-$(DATE)-$(GIT_REV).log

all-1km: update-submodules
	bash ./execute-ndr-scenario-batch.sh --with-noxn 1km 2>&1 | tee -a $@-$(DATE)-$(GIT_REV).log

show-job-queue:
	squeue --jobs=$(JOBIDS) --format="%A, %M, %j"

show-job-status:
	sacct --format="JOBIDRaw,Start,Elapsed,State" --jobs=$(JOBIDS)

sync-input-data:
	sbatch ./sync-nci-gdrive-to-scratch.sh

prep-ndr-inputs: update-submodules
	sbatch ./prep-ndr-inputs-pipeline.sh
