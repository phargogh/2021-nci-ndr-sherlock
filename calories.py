import argparse
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
from pygeoprocessing import geoprocessing

logging.basicConfig(level=logging.INFO)
LOGGER = logging.getLogger(__name__)
logging.getLogger('pygeoprocessing').setLevel(logging.DEBUG)
logging.getLogger('taskgraph').setLevel(logging.DEBUG)

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
AG_CURRENT = {10, 11, 12, 20, 30, 40}
AG_INTENSIFIED_IRRIGATED = {15, 25, 26}
AG_INTENSIFIED_RAINFED = {16}
assert (
    len(AG_CURRENT.intersection(AG_INTENSIFIED_IRRIGATED).intersection(
        AG_INTENSIFIED_RAINFED)) == 0)
assert (
    AG_CURRENT.union(AG_INTENSIFIED_IRRIGATED).union(AG_INTENSIFIED_RAINFED)
    == set(AG_INTENSITY.keys()))
TARGET_NODATA = float(numpy.finfo(numpy.float32).min)
FLOAT32_NODATA = TARGET_NODATA


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
            if ag_lucode in AG_INTENSIFIED_IRRIGATED:
                result[this_class] = irrigated_calories[this_class]
            elif ag_lucode in AG_INTENSIFIED_RAINFED:
                result[this_class] = rainfed_calories[this_class]
            else:  # Use the current calories
                result[this_class] = current_calories[this_class]
            result[this_class] *= ag_proportion

        return result

    pygeoprocessing.raster_calculator(
        [(lulc_raster_path, 1),
         (current_calories_raster_path, 1),
         (irrigated_calories_raster_path, 1),
         (rainfed_calories_raster_path, 1)],
        _get_calories, target_raster_path, gdal.GDT_Float32, TARGET_NODATA,
        use_shared_memory=True)


def _log_rmtree_error(function, path, excinfo):
    LOGGER.warning(
        f'{function}() could not remove path {path}: {excinfo}')


def _convert_to_from_density(source_raster_path, target_raster_path,
                             direction='to_density'):
    """Convert a raster to/from counts/pixel and counts/unit area.

    Args:
        source_raster_path (string): The path to a raster containing units that
            need to be converted.
        target_raster_path (string): The path to where the target raster with
            converted units should be stored.
        direction='to_density' (string): The direction of unit conversion.  If
            'to_density', then the units of ``source_raster_path`` must be in
            counts per pixel and will be converted to counts per square meter.
            If 'from_density', then the units of ``source_raster_path`` must be
            in counts per square meter and will be converted to counts per
            pixel.

    Returns:
        ``None``
    """
    LOGGER.info(f'Converting {direction} {source_raster_path} --> '
                f'{target_raster_path}')
    source_raster_info = pygeoprocessing.get_raster_info(source_raster_path)
    source_nodata = source_raster_info['nodata'][0]

    # Calculate the per-pixel area based on the latitude.
    _, miny, _, maxy = source_raster_info['bounding_box']
    pixel_area_in_m2_by_latitude = (
        geoprocessing._create_latitude_m2_area_column(
            miny, maxy, source_raster_info['raster_size'][1]))

    def _convert(array, pixel_area):
        out_array = numpy.full(array.shape, FLOAT32_NODATA,
                               dtype=numpy.float32)
        valid_mask = slice(None)
        if source_nodata is not None:
            valid_mask = ~numpy.isclose(array, source_nodata)

        if direction == 'to_density':
            out_array[valid_mask] = array[valid_mask] / pixel_area[valid_mask]
        elif direction == 'from_density':
            out_array[valid_mask] = array[valid_mask] * pixel_area[valid_mask]
        else:
            raise AssertionError(f'Invalid direction: {direction}')
        return out_array

    pygeoprocessing.raster_calculator(
        [(source_raster_path, 1), pixel_area_in_m2_by_latitude],
        _convert, target_raster_path, gdal.GDT_Float32, FLOAT32_NODATA)


def _align_pixel_counts_covariate_raster(
        source_covariate_raster_path, target_covariate_raster_path,
        target_pixel_size, target_bounding_box, target_srs_wkt, working_dir):
    temp_dir = tempfile.mkdtemp(dir=working_dir, prefix='align-covariate-')

    density_filepath = os.path.join(temp_dir, 'units_per_sq_m.tif')
    _convert_to_from_density(
        source_covariate_raster_path, density_filepath, 'to_density')

    warped_filepath = os.path.join(temp_dir, 'aligned_per_sq_m.tif')
    pygeoprocessing.geoprocessing.warp_raster(
        density_filepath, target_pixel_size, warped_filepath, 'bilinear',
        target_bounding_box, target_projection_wkt=target_srs_wkt,
        working_dir=temp_dir)

    _convert_to_from_density(
        warped_filepath, target_covariate_raster_path, 'from_density')

    shutil.rmtree(temp_dir, onerror=_log_rmtree_error)


def calories_pipeline(
        scenario_lulc_raster_list,
        source_calories_raster_list,
        target_workspace, n_workers=-1):
    pass







CALORIELAYERS = '/Users/jdouglass/Downloads/April21_2022_CalorieLayers'

if __name__ == '__main__':
    lulc = 'prep-ndr-inputs-workspace/intensification.tif'
    calories_layers = {
        'current': os.path.join(CALORIELAYERS, 'caloriemapscurrentRevQ.tif'),
        'irrigated': os.path.join(
            CALORIELAYERS, 'caloriemapsirrigatedRevQ.tif'),
        'rainfed': os.path.join(CALORIELAYERS, 'caloriemapsrainfedRevQ.tif'),
    }
