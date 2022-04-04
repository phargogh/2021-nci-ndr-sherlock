# Test sbatch parameter precedence

I recently had a job run for the NCI NOXN pipeline where I had a default task
time limit but then attempted to override the time limit by passing in the
correct time limit via the `sbatch` cli.  I would like to confirm that this is
expected behavior.

## Setup

```shell
# Override the script's 5-minute time limit with a 10-minute time limit.
$ sbatch --time=0:10:00 test-options.sh
$ squeue -u <username> --long
```

## Results


