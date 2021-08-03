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
* Sherlock executes tasks via the SLURM workload manager, which has its own abstractions.
   * Python's `multiprocessing.cpu_count()` will show the number of CPUs on the machine, not the number of cores available to the current process.
   * In SLURM lingo, "Task" is akin to "Process".  You could have one task that has lots of threads and so needs few tasks but many CPUs.
     For taskgraph, this will probably end up being `n` tasks, `2n` CPUs.
* For each job submitted, there will be a `slurm-{job_id}.out` file produced containing stdout.
  These appear to automatically delete, perhaps after each new job?
* While Sherlock nodes have 150GB of local SSD scratch space (`$L_SCRATCH`), `$SCRATCH` appears to be an
  unexpectedly high-performance distributed filesystem.  In initial tests, I'll be attempting to run the entire
  analysis just on `$SCRATCH`.
