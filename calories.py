import logging

import pygeoprocessing
from osgeo import gdal

logging.basicConfig(level=logging.INFO)

# Maps lucode to the proportion of calories produced.
AG_INTENSITY = {
    10: 1,     # Cropland, rainfed
    11: 1,     # Cropland, rainfed, herbaceous cover
    12: 1,     # Cropland, rainfed, tree or shrub cover
    15: 1,     # Intensified agriculture, irrigated
    16: 1,     # Intensified agriculture, with BMPs, rainfed
    20: 1,     # Cropland, irrigated or post-flooding
    25: 1,     # Intensified agriculture, irrigated
    26: 1,     # Intensified agriculture with BMPs, irrigated
    30: 0.75,  # Mosaic cropland (>50%)
    40: 0.25,  # Mosaic cropland (<50%)
}

def calories(lulc_raster_path, base_calories_raster_path,
             target_raster_path, scalar=1):
    lulc_nodata = pygeoprocessing.get_raster_info(
        lulc_raster_path)['nodata'][0]
    calories_nodata = pygeoprocessing.get_raster_info(
        base_calories_raster_path)['nodata'][0]
    target_nodata = gdal.GDT_Float32

    def _get_calories(lulc, calories):
        result = numpy.full(lulc.shape, target_nodata, dtype=numpy.float32)
        valid_mask = (
            ~numpy.isclose(lulc, lulc_nodata, equal_nan=True) &
            ~numpy.isclose(calories, calories_nodata, equal_nan=True))

        # Any non-ag pixels produce no calories.
        result[valid_mask] = 0
        for ag_lucode, ag_proportion in AG_INTENSITY.items():
            this_class = (lulc == ag_lucode)
            result[this_class] = calories[this_class] * ag_proportion * scalar

        return result

    pygeoprocessing.raster_calculator(
        [(lulc_raster_path, 1), (base_calories_raster_path, 1)],
        _get_calories, target_raster_path, target_nodata)
