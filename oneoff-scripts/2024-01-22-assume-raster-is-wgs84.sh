#!/usr/bin/env sh

######################################################################
# @author      : jdouglass (jdouglass@$HOSTNAME)
# @file        : 2024-01-22-assume-raster-is-wgs84
# @created     : Monday Jan 22, 2024 11:08:48 PST
#
# @description : Use gdel_edit.py to assume the target raster is WGS84 covering the whole globe.
#
# The context for this is that Rafa sent me an HDF5 file of global nitrate
# application rates, so I wanted to add a spatial reference and make it a
# geotiff for normalization.
######################################################################

if [[ $1 == *.tif ]]
then
    GTIFF_PATH="$1.tif"
    gdal_translate -of GTiff -co COMPRESS=LZW -co TILED=YES "$1" "$GTIFF_PATH"
else
    GTIFF_PATH="$1"
fi

gdal_edit.py -a_srs EPSG:4326 -a_ullr -180 90 180 -90 "$GTIFF_PATH"
