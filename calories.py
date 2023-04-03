import logging
import os
import shutil
import sys
import tempfile
import time

import numpy
import pygeoprocessing
from osgeo import gdal
from osgeo import osr

logging.basicConfig(level=logging.INFO)
LOGGER = logging.getLogger(__name__)
logging.getLogger('pygeoprocessing').setLevel(logging.DEBUG)

# Maps lucode to the proportion of calories produced.
AG_INTENSITY = {
    10: 1,     # Cropland, rainfed (TREAT AS CURRENT)
    11: 1,     # Cropland, rainfed, herbaceous cover (TREAT AS CURRENT)
    12: 1,     # Cropland, rainfed, tree or shrub cover (TREAT AS CURRENT)
    15: 1,     # Intensified agriculture, irrigated
    16: 1,     # Intensified agriculture, with BMPs, rainfed
    20: 1,     # Cropland, irrigated or post-flooding (TREAT AS CURRENT)
    25: 1,     # Intensified agriculture, irrigated
    26: 1,     # Intensified agriculture with BMPs, irrigated
    30: 0.75,  # Mosaic cropland (>50%)
    40: 0.25,  # Mosaic cropland (<50%)
}
AG_CURRENT = {10, 11, 12, 20}
AG_IRRIGATED = {15, 25, 26}
AG_RAINFED = {16}
assert (
    len(AG_CURRENT.intersection(AG_IRRIGATED).intersection(AG_RAINFED)) == 0)
assert (
    AG_CURRENT.union(AG_IRRIGATED).union(AG_RAINFED) ==
    set(AG_INTENSITY.keys()))
TARGET_NODATA = float(numpy.finfo(numpy.float32).min)


def calories(lulc_raster_path,
             current_calories_raster_path,
             irrigated_calories_raster_path,
             rainfed_calories_raster_path,
             target_raster_path,
             scalar=1):
    lulc_nodata = pygeoprocessing.get_raster_info(
        lulc_raster_path)['nodata'][0]
    current_calories_nodata = pygeoprocessing.get_raster_info(
        current_calories_raster_path)['nodata'][0]
    irrigated_calories_nodata = pygeoprocessing.get_raster_info(
        irrigated_calories_raster_path)['nodata'][0]
    rainfed_calories_nodata = pygeoprocessing.get_raster_info(
        rainfed_calories_raster_path)['nodata'][0]

    def _get_calories(lulc, current_calories, irrigated_calories,
                      rainfed_calories):
        result = numpy.full(lulc.shape, TARGET_NODATA, dtype=numpy.float32)
        valid_mask = ~numpy.isclose(lulc, lulc_nodata, equal_nan=True)

        # handle the likely case where nodata is represented by nan and the
        # nodata value is unset.
        for calories_array, calories_nodata in (
                (current_calories, current_calories_nodata),
                (irrigated_calories, irrigated_calories_nodata),
                (rainfed_calories, rainfed_calories_nodata)):
            if calories_nodata is None:
                valid_mask &= (~numpy.isnan(calories_array))
            else:
                valid_mask &= (~numpy.isclose(calories_array, calories_nodata,
                                              equal_nan=True))

        # Any non-ag pixels produce no calories.
        result[valid_mask] = 0

        # Ag pixels have calories, so pull from the correct rasters depending
        # on the case.
        for ag_lucode, ag_proportion in AG_INTENSITY.items():
            this_class = (lulc == ag_lucode)
            if ag_lucode in AG_IRRIGATED:
                result[this_class] = irrigated_calories[this_class]
            elif ag_lucode in AG_RAINFED:
                result[this_class] = rainfed_calories[this_class]
            else:  # Use the current calories
                result[this_class] = current_calories[this_class]
            result[this_class] *= (ag_proportion * scalar)

        return result

    pygeoprocessing.raster_calculator(
        [(lulc_raster_path, 1), (base_calories_raster_path, 1)],
        _get_calories, target_raster_path, gdal.GDT_Float32, TARGET_NODATA,
        use_shared_memory=True)


def main_vrt():
    lulc_path = sys.argv[1]
    base_calories_path = sys.argv[2]

    temp_dir = tempfile.mkdtemp(dir=os.getcwd(), prefix='aligned-calories-')
    temp_calories = os.path.join(temp_dir, "calories_aligned.vrt")
    LOGGER.info(f"Building temp calories raster at {temp_calories}")

    lulc_info = pygeoprocessing.get_raster_info(lulc_path)
    target_srs = osr.SpatialReference()
    target_srs.ImportFromWkt(lulc_info['projection_wkt'])

    times = []
    start_time = time.time()
    gdal.BuildVRT(
        temp_calories,
        [base_calories_path],
        outputBounds=lulc_info['bounding_box'],
        xRes=abs(lulc_info['pixel_size'][0]),
        yRes=abs(lulc_info['pixel_size'][1]),
        allowProjectionDifference=True,
        resampleAlg='near',
        VRTNodata=TARGET_NODATA,
        outputSRS=target_srs)
    times.append(time.time() - start_time)

    start_time = time.time()
    calories(lulc_path, temp_calories, 'calories.tif', scalar=1)
    times.append(time.time() - start_time)
    shutil.rmtree(temp_dir, ignore_errors=True)
    return times


if __name__ == '__main__':
    start_time = time.time()
    vrt_times_array = main_vrt()
    vrt_time = time.time() - start_time

    print(f"VRT time:  {vrt_time}")
    print(f"  * VRT:  {vrt_times_array[0]}")
    print(f"  * Calc: {vrt_times_array[1]}")
