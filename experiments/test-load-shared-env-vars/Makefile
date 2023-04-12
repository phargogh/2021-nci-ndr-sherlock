.PHONY: testme

testme-local:
	bash testme.sh

testme-sbatch:
	sbatch --time=00:05:00 --ntasks=1 --cpus-per-task=1 testme.sh
