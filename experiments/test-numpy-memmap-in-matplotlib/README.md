# Test `numpy.memmap` and `matplotlib` in low-RAM SLURM run

## Background

While working on the NCI nitrate concentration pipeline at 1km resolution, it
turned out that one of the scripts was loading multiple full-resolution rasters
into memory before saving out a PNG file.  During execution, Sherlock ended up
killing the process because it consumed too much memory.  I was able to work
around this by using an overview layer (a smaller array), but this doesn't have
quite the same visual clarity as the full-resolution array.  It's sufficient
for our purposes, but it'd be great to do better.

`numpy.memmap` is supposed to allow for the sort of windowing that we would
normally like to do, but through an array-like object.  Would that work for our
purposes here?

## Hypothesis

I am expecting that `numpy.memmap` will work as expected and the memory for the
process will not be exhausted, even on a very fine resolution raster.

## Experiment

We will use these configuration constants:

1. Runtime will be the `natcap/devstack` docker image
2. The target raster will be one of the 300m NDR export rasters from the NCI WQ
   pipeline.  This raster is big enough to require about 32GB of RAM for all
   the float32 objects to be allocated.
3. Requested memory from SLURM will be 4GB
4. Everything will be executed within a single-threaded python program.

First, we need to verify that loading the array normally would invoke `oom-killer`:

1. `ReadAsArray` the whole raster.
2. Write the array to a 300dpi PNG in CWD.

Once we have verified `oom-killer` swooped in a terminated the job:

1. `ReadAsArray` the whole raster, but pass in a preallocated `numpy.memmap` object.
2. Write the array to a 300dpi PNG in CWD.

## Results

As expected, the `ReadAsArray` for the whole raster quickly caused `oom-killer`
to kill the process.

When I preallocated a `numpy.memmap` array and passed that to `ReadAsArray`,
GDAL needed to first _copy_ the entire array into the new numpy object.  This copy
operation took quite some time (about 10 minutes, probably due to network speeds
writing to SCRATCH).  While this copy operation _did_ allocate about 32 GB of
virtual memory, `oom-killer` didn't kill the process.  Once the memmapped array
had loaded, it was passed to `matplotlib` which was promptly killed by the
`oom-killer`.  So, matplotlib is loading the entire array.

I have not yet found a good workaround for this for plots like matplotlib,
except to use overviews or some other kind of downscaled derivative.
