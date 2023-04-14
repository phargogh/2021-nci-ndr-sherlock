import logging
import os

import matplotlib.pyplot as plt
import numpy
import pygeoprocessing
from osgeo import gdal

logging.basicConfig(level=logging.DEBUG)
LOGGER = logging.getLogger(__name__)
gdal.SetCacheMax(2**30)  # about 1.1 GB

raster_path = f'{os.environ["SCRATCH"]}/NCI-WQ-full-2023-04-11-rev443-047031a/NCI-NDRplus-rev443-047031a-intensification/compressed_intensification_300.0_D8_export.tif'
raster_info = pygeoprocessing.get_raster_info(raster_path)
memmap_path = f'{os.environ["SCRATCH"]}/memmap.npym'
LOGGER.info("Creating memmapped array")

# Only load the file if it doesn't already exist -- takes some time
if not os.path.exists(memmap_path):
    memmapped_array = numpy.memmap(
        memmap_path, dtype=numpy.float32, mode='w+', shape=(
            raster_info['raster_size'][1], raster_info['raster_size'][0]))
    LOGGER.info("Opening raster")
    raster = gdal.OpenEx(raster_path)
    band = raster.GetRasterBand(1)
    LOGGER.info("Loading memmapped array")
    array = band.ReadAsArray(buf_obj=memmapped_array)
else:
    array = numpy.memmap(
        memmap_path, dtype=numpy.float32, mode='r+', shape=(
            raster_info['raster_size'][1], raster_info['raster_size'][0]))

LOGGER.info("Writing the array to the image")
plt.imshow(array)

LOGGER.info("Saving the figure")
plt.savefig('array.png', dpi=300)
