#!/usr/bin/env sh

######################################################################
# @author      : jdouglass (jdouglass@$HOSTNAME)
# @file        : 2024-01-25-resample-marconi-and-rosa-2024
# @created     : Thursday Jan 25, 2024 16:56:25 PST
#
# @description : Resample
######################################################################

# executing on sherlock
cd $GROUP_HOME/nci-local-ecoshard-cache

# resample marconi and rosa 2024 to the resolution o f
# Using the dimensions of the baseline LULC, read using gdalinfo from the
# raster at /scratch/users/jadoug06/NCI-scenarios/current_lulc_masked.tif

module load physics gdal

gdalwarp -ts 129600 64800 -r bilinear -of GTiff -co COMPRESS=LZW -co TILED=YES marconi_and_rosa_2024_2020_synthetic_nitrogen_tonnes_md5_0727cbe08ff99a1516be52be91dbaae6.tif marconi_and_rosa_2024_2020_synthetic_nitrogen_tonnes_bilinear.tif

