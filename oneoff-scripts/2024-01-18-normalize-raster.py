"""Normalize a raster.

On 2024-01-18, Rafa asked to normalize ``current_n_app.tif`` so that we could
compare the spatial patterns of our n application raster against some other
fertilizer application rasters.

See https://stanford-natcap.slack.com/archives/C06DD6G5MBN/p1705600028229789?thread_ts=1705434240.205009&cid=C06DD6G5MBN

"""
import logging
import sys

import numpy
import pygeoprocessing
from osgeo import gdal

logging.basicConfig(level=logging.INFO)
gdal.SetCacheMax(512)


def normalize(raster_path, target_path):
    raster_max = pygeoprocessing.raster_reduce(
        lambda max_value, block:
            numpy.maximum(block.max(), max_value) if block.size else max_value,
        (raster_path, 1), float('-inf'))

    pygeoprocessing.raster_map(
        lambda block: block / raster_max,
        [raster_path], target_path)


if __name__ == '__main__':
    normalize(sys.argv[1], sys.argv[2])
