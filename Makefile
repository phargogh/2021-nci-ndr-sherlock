.PHONY: ndr-batch show-job-queue show-job-status

ndr-batch:
	bash ./execute-ndr-scenario-batch.sh

show-job-queue:
	squeue --jobs=$(awk '{ print $2 }' scenario_jobs.txt | paste -sd "," -) --format="%A, %M, %j"

show-job-status:
	sacct --format="JOBIDRaw,Start,Elapsed,State" --jobs=$(awk '{ print $2 }' scenario_jobs.txt | paste -sd "," -)
