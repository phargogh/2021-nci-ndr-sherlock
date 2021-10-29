# 2021-nci-ndr-sherlock
Scripts to run the NDR analyses for Natural Capital Index work on Sherlock.

## Notes

* Sherlock doesn't support docker because running docker would allow root access to the host node.
  Instead, singularity is required.
   * When installing singularity on a local machine, be sure to use the architecture of your machine.
     In my case it was `arm64` (arm v8), which I forgot and is not the default option in the tutorials.
   * To convert `therealspring/inspring:latest` to singularity: `singularity pull docker://therealspring/inspring:latest`
   * The resulting `inspring_latest.sif` can then be uploaded to sherlock via a data transfer node:
     `scp ./inspring_latest.sif scp://$USER@dtn.sherlock.stanford.edu`.  When the file is uploaded via DTN, it
     will be written to $SCRATCH.
  * Arbitrary docker images _can_ be run via singularity without any extra conversion in advance.  For example:
    `singularity run docker://ghcr.io/phargogh/inspring-no-gcloud-keys@sha256:ff0fd8ea1594c35dc555273666a97d15340393772c95986097ffd826d22c0dc7`
* Sherlock executes tasks via the SLURM workload manager, which has its own abstractions.
   * Python's `multiprocessing.cpu_count()` will show the number of CPUs on the machine, not the number of cores available to the current process.
   * In SLURM lingo, "Task" is akin to "Process".  You could have one task that has lots of threads and so needs few tasks but many CPUs.
     For taskgraph, this will probably end up being `n` tasks, `2n` CPUs.
* For each job submitted, there will be a `slurm-{job_id}.out` file produced containing stdout.
  These appear to automatically delete, perhaps after each new job?
* While Sherlock nodes have ~150GB of local SSD scratch space (`$L_SCRATCH`), `$SCRATCH` appears to be an
  unexpectedly high-performance distributed filesystem.  In initial tests, I'll be attempting to run the entire
  analysis just on `$SCRATCH`.
  * Update: Runs of an NCI scenario that were taking 30+ hours in `$SCRATCH` are completing in about 15 hours
    in `$L_SCRATCH`.  Totally worth it to use `$L_SCRATCH` if possible.
  * `$L_SCRATCH` is purged at the end of a job, so be sure to `sbatch` a script that includes copying the data
    out of `$L_SCRATCH` and into `$SCRATCH` or somewhere else.
  * For CPU-bound operations, `$SCRATCH` is probably good enough!
* When running a job, you can see which node it's running in by using `squeue -u <username>`.  This will be a node name
  in the form `sh02-01n20`.  When you're running a job on that node, you can `ssh sh02-01n20` in order to poke
  around, run diagnostics, inspect things, etc.
* To see which jobs remain in the queue: `squeue -u <username>`
* To see the elapsed time for jobs, `sacct --format="JobID,Start,Elapsed,State"`
* If a job is producing a _ton_ of stdout or stderr, you can use the `--output` and `--error` parameters to `sbatch`
  to control where those files end up.
* Parameters (or `#SBATCH` directives) passed to `sbatch` propagate to any `srun` commands within an `sbatch` batch file.
  Thus, if your `srun` should only take a single CPU but your `sbatch` script calls for 20, you'll need to pass that
  1-CPU parameter to `srun`.
