#!/bin/bash
#
# This script uploads files to a designated folder on a preconfigured rclone remote.
#
# Expected usage via bash:
#  $ bash ./upload-to-googledrive.sh "rclone-remote:target/directory" file1 file2 file3 ...
#
# For example:
#  $ sbatch --time=1:00:00 ./upload-to-googledrive.sh \
#        "nci-ndr-stanford-gdrive:2022-04-06-nci-noxn-rev526c591-slurm48859659-1km/ndrplus-outputs-1km" \
#        $(pwd)/aligned*{export,modified_load}.tif
#
# Or within an sbatch'ed script:
#  $(pwd)/upload-to-googledrive.sh \
#        "nci-ndr-stanford-gdrive:2022-04-06-nci-noxn-rev526c591-slurm48859659-1km/ndrplus-outputs-1km" \
#        $(pwd)/aligned*{export,modified_load}.tif


DEST_DIR="$1"

module load system rclone/1.59.1

# create the directory first so we can parallelize uploads into it.
# If we don't do this, then we'll get many folders with the same name.
rclone mkdir "$DEST_DIR"

# Loop through all of the remaining args and assume they are files.
for file in "${@:2}"
do
    rclone copy --progress "$file" "$DEST_DIR" &
done

# This strategy can be used instead if it's important to limit the number of
# uploads we're using.  So far, I haven't found that this is strictly needed.
# I did time it and parallel -j5 was about 30% slower than just launching all
# the rclone copy processes and waiting for the OS to handle them all however
# it saw fit.
# echo ${@:2} | tr " " "\n" | parallel -j5 rclone copy --progress {} "$DEST_DIR"

wait
echo 'done!'
