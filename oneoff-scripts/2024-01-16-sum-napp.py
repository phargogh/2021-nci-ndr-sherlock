import os
import sys

import numpy
import pygeoprocessing
import pygeoprocessing.geoprocessing
from osgeo import gdal
from osgeo import osr

gdal.SetCacheMax(512)  # low enough number, assumes in MB

raster_info = pygeoprocessing.get_raster_info(sys.argv[1])
_, raster_min_lat, _, raster_max_lat = raster_info['bounding_box']
pixel_x_size, pixel_y_size = raster_info['pixel_size']

srs = osr.SpatialReference(wkt=raster_info['projection_wkt'])
srs_epsg = srs.GetAttrValue('AUTHORITY', 1)
assert str(srs_epsg) == '4326', (
    f"This function is designed to work on WGS84 only, not EPSG:{srs_epsg}")

raster = gdal.Open(sys.argv[1])
band = raster.GetRasterBand(1)

pixel_sum = 0
pixel_sum_adjusted_by_area = 0
for offsets in pygeoprocessing.iterblocks((sys.argv[1], 1), offset_only=True):
    block = band.ReadAsArray(**offsets)
    valid_mask = ~pygeoprocessing.array_equals_nodata(
        block, raster_info['nodata'][0])

    if not valid_mask.size:
        continue

    block_max_lat = raster_max_lat - (offsets['yoff'] * pixel_y_size)
    block_min_lat = block_max_lat - (offsets['win_ysize'] * pixel_y_size)

    m2_area_column = pygeoprocessing.geoprocessing._create_latitude_m2_area_column(
        block_min_lat, block_max_lat, n_pixels=offsets['win_ysize'])

    pixel_sum += numpy.sum(block[valid_mask])
    pixel_sum_adjusted_by_area += numpy.sum(
        (block * m2_area_column)[valid_mask])


print(f"Values for {os.path.basename(sys.argv[1])}")
print(f"Pixel sum: {pixel_sum:,}")
print(f"Pixel sum adjusted by area: {pixel_sum_adjusted_by_area:,}")
