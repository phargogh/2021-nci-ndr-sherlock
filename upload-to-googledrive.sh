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

DEST_DIR="$1"

# Loop through all of the remaining args and assume they are files.
module load system rclone
rclone mkdir "$DEST_DIR"

for file in "${@:2}"
do
    rclone copy --progress "$file" "$DEST_DIR" &
done

# This strategy can be used instead if it's important to limit the number of
# uploads we're using.  So far, I haven't found that this is strictly needed.
# echo ${@:2} | tr " " "\n" | parallel -j5 rclone copy --progress {} "$DEST_DIR"

wait
echo 'done!'
