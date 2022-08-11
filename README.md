# 2021-nci-ndr-sherlock
Scripts to run the NDR analyses for Natural Capital Index work on Sherlock.

## To execute the NDR+ pipeline on sherlock:

1.  SSH into sherlock
2.  Set up rclone such that `nci-ndr-stanford-gdrive` refers to a google shared drive that you have write access to.
3.  Clone this repo
4.  Run `make ndr-batch`
5.  Wait 13-16 hours for everything to finish.


## Other useful operations

### To cancel all currently-scheduled jobs:

```shell
squeue -u jadoug06 --format "%A"  | tail -n +2 | xargs scancel
```


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
  * `STAT: /root/some-script.sh: permission denied` errors happen if/when your
    docker container put stuff into `/root`.  Singularity [restricts access](https://sylabs.io/guides/3.9/user-guide/singularity_and_docker.html#best-practices-for-docker-singularityce-compatibility)
    to `/root` when importing a docker container.  You can get around this by setting permissions in a custom
    singularity definition, but it's better to just avoid putting stuff you need into `/root`.
    Use `/opt/myapp` or similar instead, as recommended by [Filesystem Hierarchy Standard](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard).
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
* To see which jobs remain in the queue: `squeue -u <username>`.
* To see the elapsed time for jobs, `sacct --format="JobID,Start,Elapsed,State"`.
* If a job is producing a _ton_ of stdout or stderr, you can use the `--output` and `--error` parameters to `sbatch`
  to control where those files end up, such as writing the logfiles to `$SCRATCH`.
* Parameters (or `#SBATCH` directives) passed to `sbatch` propagate to any `srun` commands within an `sbatch` batch file.
  Thus, if your `srun` should only take a single CPU but your `sbatch` script calls for 20, you'll need to pass that
  1-CPU parameter to `srun`.
* Although we have access to the `hns` queue, NCI jobs are actually executed
  _much_ sooner when run in `normal`.  You can submit jobs to both queues with
  `--partition=normal,hns`, and whichever partition gets to it first will
  execute the job.
* According to the [slurm docs](https://slurm.schedmd.com/sbatch.html#SECTION_INPUT-ENVIRONMENT-VARIABLES), parameters may be
  passed to `sbatch` via command-line flags, `#SBATCH` directives in a script, and through environment variables.
  Command-line flags take priority over `#SBATCH` directives, which take priority over environment variables.
  Thus, it's probably good practice to define `#SBATCH` directives as defaults,
  but then override them with command-line flags when needed.  In NCI, for
  example, a standard run without any precomputation will take ~10 hours.  With
  precomputation, it'll probably take less and this can be provided to the
  script via a separate command-line flag.
* For future pipelines, it may be wise to include `taskgraph` tasks that upload
  completed, final outputs to a target directory, such as to google drive.  In
  the NDR+ pipeline script `execute-ndr-specific-scenario.sh`, I first run the
  python pipeline and then rsync files to `$SCRATCH` and _then_ `rclone` files up
  to google drive.  Same sort of setup for the `noxn` pipeline.  It might be a
  more efficient allocation of resources if the network-bound tasks could also
  be executed in parallel, once they are ready.  I haven't tried this, of
  course, but it seems like a good idea, especially for larger files that need
  some time to copy/transfer.
    * It's worth noting that although Sherlock nodes appear to be able to use
      Infiniband among the cluster, I've only gotten 1Gb/s upload speeds to
      google cloud.  This means that if the pipeline doesn't include tasks for
      uploading files as we go, we'll necessarily spend a fair amount of time
      waiting on the network at the end of the run and we could spend hours
      only uploading files.
* `pygeoprocessing` uses tempfiles and temporary directories for a lot of its
  computation, and those files are generally written somewhere on the local
  filesystem.  Setting the environment variable `TMPDIR=$L_SCRATCH` will allow
  those temporary files to be run on a high-bandwidth local SSD.
* Sherlock (and SLURM) allocate the number of CPUs based on a per-partition
  ratio of RAM-per-CPU in order to prevent a process from starving other
  processes of memory.  Consequence: If your job requests more RAM per CPU
  than the partition allows, then your job will be modified to allocate
  more CPUs to avoid this starvation situation.  In my NCI jobs, I requested
  8GB, which was more than the 8000MB allowed RAM/CPU limit on `normal`, so
  my requested number of CPUs was doubled.
   * To investigate this limit per partition, see
     `scontrol show partition <partition_name>`, specifically:
     * `DefMemPerCPU` - how much memory will be allocated with each requested CPU
     * `MaxMemPerCPU` - at which point requesting more memory will increase the number of allocated CPUs
* For jobs like the NOXN pipeline that spend almost all of their time being
  CPU-bound, it's helpful to just use the `$SLURM_CPUS_PER_TASK` environment
  variable.  More tasks than we need will only result in more context switches,
  which slow the whole job down.
