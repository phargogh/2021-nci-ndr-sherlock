import argparse
import json
import logging
import os
import pathlib
import pprint
import shutil

import numpy
import numpy as np
import pygeoprocessing
import pygeoprocessing.symbolic
import taskgraph
from osgeo import gdal

logging.basicConfig(level=logging.INFO)
LOGGER = logging.getLogger(__name__)
N_APP_DTYPE = gdal.GDT_Float32
N_APP_NODATA = float(numpy.finfo(numpy.float32).min)
LULC_DTYPE = gdal.GDT_Byte
LULC_NODATA = 0


# These paths are relative to the NCI gdrive folder.
INPUT_FILES = {
    "base_lulc": "ESACCI-LC-L4-LCCS-Map-300m-P1Y-2015-v2.0.7_md5_1254d25f937e6d9bdee5779d377c5aa4.tif",
    "modified_lulc": "current_lulc/modifiedESA_2022_06_03.tif",
    "potential_vegetation": "scenario_construction/potential_vegetation/potential_vegetation.tif",
    "slope_threshold_expansion": "scenario_construction/ag_slope_exclusion_masks/expansion_full.tif",
    "slope_threshold_intensification": "scenario_construction/ag_slope_exclusion_masks/intensification_full.tif",
    "rainfed_suitability": "scenario_construction/ag_crop_suitability_maps/rainfed_mask_ESAaligned.tif",
    "irrigated_suitability": "scenario_construction/ag_crop_suitability_maps/irrigation_mask_ESAaligned.tif",
    "riparian_buffer": "scenario_construction/riparian_buffer_location/riparian_buffer_mask_md5_6184cf8ea3ce479e1a0538fc49df2175.tif",
    "sustainable_irrigation": "scenario_construction/ag_irrigation_potential/sustainable_irrigation_mask.tif",
    "soil_suitability": "scenario_construction/ag_natural_expansion_potential/suitability_expansion_potential_mask_ESAaligned.tif",
    "protected_areas": "scenario_construction/protected_areas/wdpa_merged.tif",
    "crop_value_current": "cropland/totalproductionvaluecurrentRevR_nolabor_machinerycosts.tif",
    "crop_value_intensified_rainfed": "cropland/totalproductionvaluerainfedRevR_nolabor_machinerycosts.tif",
    "crop_value_intensified_irrigated": "cropland/totalproductionvalueirrigatedRevR_nolabor_machinerycosts.tif",

    # Nitrogen application rasters from Jamie for Peter's scripts
    "n_background": "nitrogen/Background_Nload_restoration_md5_a77d99a607727668386a4ba0344f01d4.tif",
    "n_current": "nitrogen/finaltotalNfertratescurrentRevQ.tif",
    "n_rainfed": "nitrogen/finaltotalNfertratesrainfedRevQ.tif",
    "n_irrigated": "nitrogen/finaltotalNfertratesirrigatedRevQ.tif",
}

LULC_SCENARIOS = {
    "current_bmps",
    "current_lulc_masked",
    "intensification",
    "intensification_bmps",
    "intensification_expansion",
    "intensification_expansion_bmps",
    "extensification_current_practices",
    "extensification_current_practices_bmps",
    "intensification_optimized",
    "intensification_optimized_bmps",
    "intensification_optimized_expansion",
    "intensification_optimized_expansion_bmps",
}
OUTPUT_FILES = {
    **{key: f"{key}.tif" for key in LULC_SCENARIOS},
    **{f'{key}_n_app': f"{key}_n_app.tif" for key in LULC_SCENARIOS},
    "current_n_app": "current_n_app.tif",
    "intensified_irrigated_n_app": "intensified_irrigated_n_app.tif",
    "intensified_irrigated_bmps_n_app": "intensified_irrigated_bmps_n_app.tif",
    "intensified_rainfed_n_app": "intensified_rainfed_n_app.tif",
    "intensified_rainfed_bmps_n_app": "intensified_rainfed_bmps_n_app.tif",
}

INTERM_FILES = {
    **{f'{key}_raw_n_app': f"{key}_raw_n_app.tif" for key in LULC_SCENARIOS
       if key.startswith('intensification') and 'optimized' not in key},
    'crop_value_current_masked': "crop_value_current_masked.tif",
    'crop_value_intensified_rainfed_masked':
        "crop_value_intensified_rainfed_masked.tif",
    'crop_value_intensified_irrigated_masked':
        "crop_value_intensified_irrigated_masked.tif",
    'protected_areas_masked': "protected_areas_masked.tif",
    'cropland_current_practices_suitability': "current_practices.tif",
    'cropland_intensified_rainfed_suitability': "intensified_rainfed.tif",
    'cropland_intensified_irrigated_suitability': "intensified_irrigated.tif",
    'n_background_aligned': 'n_background_aligned.tif',
    'n_current_aligned': 'n_current_aligned.tif',
    'n_rainfed_aligned': 'n_rainfed_aligned.tif',
    'n_irrigated_aligned': 'n_irrigated_aligned.tif',
}
GRAZING_LU = [
    30, 34, 39, 40, 44, 49, 104, 109, 114, 119, 124, 125, 126, 134, 144, 154,
    156, 157, 184, 204, 205, 206
]
AG_LUCODES = [10, 11, 12, 15, 16, 20, 25, 26, 30, 40]  # I did not do anything with oil palm[29].


def intensification_op(clm, sti, cvcm, cvirm, cviim, ir, rfs, sir, ss):
    cvcm[np.isnan(cvcm)] = 0
    cvirm[np.isnan(cvirm)] = 0
    cviim[np.isnan(cviim)] = 0
    result = clm
    result[np.all([np.isin(clm, [10, 11, 12]), sti==1, cviim>0, ir==1, sir==1, ss==1], axis=0)] = 25
    result[np.all([np.isin(clm, [10, 11, 12]), sti==1, cvirm>0, rfs==1, np.any([ir!=1, sir!=1], axis=0), ss== 1], axis=0)] = 15
    result[np.all([np.isin(clm, [10, 11, 12]), sti!=1, cvcm>0, ir==1, sir==1, ss==1], axis=0)] = 20
    result[np.all([np.isin(clm, [20]), sti== 1, cviim>0], axis=0)] = 25
    return result


def intensification_expansion_op(ints, sti, cvirm, cviim, ir, rfs, sir, ss, pa):
    cvirm[np.isnan(cvirm)] = 0
    cviim[np.isnan(cviim)] = 0
    result = ints
    result[np.all([np.isin(ints, GRAZING_LU), sti==1, cviim>0, ir==1, sir==1, ss==1, pa==7], axis=0)] = 25
    result[np.all([np.isin(ints, GRAZING_LU), sti==1, cvirm>0, rfs==1, np.any([ir!=1, sir!=1], axis=0), ss==1, pa==7], axis=0)] = 15
    return result


def extensification_current_practices_op(clm, ste, cvcm, ir, rfs, sir, ss, pa):
    cvcm[np.isnan(cvcm)] = 0
    result = clm
    gr_20 = np.all([np.isin(clm, GRAZING_LU), ste==1, cvcm>0, ir==1, sir==1, ss==1, pa==7], axis=0)
    result[gr_20] = 20
    gr_10 = np.all([np.isin(clm, GRAZING_LU), ste==1, cvcm>0, rfs==1, np.any([ir!=1, sir!=1], axis=0), ss==1, pa==7], axis=0)
    result[gr_10] = 10
    return result


def bmp_op(lu, rb, pv):
    result = lu
    crop_rb = np.all(
        [np.isin(lu, [10, 11, 12, 15, 20, 25]),
         rb==1],
        axis=0)
    result[crop_rb] = pv[crop_rb]
    result[result==15] = 16
    result[result==25] = 26
    return result


def intensification_n_app(scenario_lulc, current_n_app,
                          intensification_raw_n_app, target_n_app):
    scenario_nodata = _get_nodata(scenario_lulc)
    current_n_app_nodata = _get_nodata(current_n_app)
    intensification_raw_n_app_nodata = _get_nodata(intensification_raw_n_app)

    def _intensification_n_app(lulc, current, intensification_raw):
        result = numpy.full(lulc.shape, N_APP_NODATA, dtype=numpy.float32)
        valid_pixels = (
            ~_equals_nodata(lulc, scenario_nodata) &
            ~_equals_nodata(current, current_n_app_nodata) &
            ~_equals_nodata(intensification_raw,
                            intensification_raw_n_app_nodata))

        # if non-ag, use given current (should be current n_app)
        result[valid_pixels] = current[valid_pixels]

        # if ag, use intensification_raw n_app
        ag = (numpy.isin(lulc, AG_LUCODES) & valid_pixels)
        result[ag] = numpy.maximum(intensification_raw[ag], current[ag])

        return result

    pygeoprocessing.raster_calculator(
        [(scenario_lulc, 1), (current_n_app, 1),
         (intensification_raw_n_app, 1)],
        _intensification_n_app, target_n_app, N_APP_DTYPE, N_APP_NODATA)


def intensification_optimized_n_app(intensification_n_app, target_n_app):
    def _intensification_optimized_n_app_op(intensification):
        result = numpy.full(intensification.shape, N_APP_NODATA,
                            dtype=numpy.float32)
        valid_pixels = ~_equals_nodata(intensification, N_APP_NODATA)
        result[valid_pixels] = intensification[valid_pixels] * 0.8
        return result

    pygeoprocessing.raster_calculator(
        [(intensification_n_app, 1)], _intensification_optimized_n_app_op,
        target_n_app, gdal.GDT_Float32, N_APP_NODATA)


def _get_nodata(raster_path):
    return pygeoprocessing.get_raster_info(raster_path)['nodata'][0]


def _equals_nodata(array, nodata):
    if nodata is None:
        return False
    return numpy.isclose(array, nodata, equal_nan=True)


def intensified_irrigated_n_app(
        background_path, current_path, rainfed_path, irrigated_path,
        target_path):
    background_nodata = _get_nodata(background_path)
    current_nodata = _get_nodata(current_path)
    rainfed_nodata = _get_nodata(rainfed_path)

    def local_op(background, current, rainfed, irrigated):
        result = irrigated.copy()
        ix = np.isnan(result) | _equals_nodata(rainfed, rainfed_nodata)
        result[ix] = rainfed[ix]
        ix = np.isnan(result) | _equals_nodata(current, current_nodata)
        result[ix] = current[ix]

        return result + background

    pygeoprocessing.raster_calculator(
        [(path, 1) for path in (
            background_path, current_path, rainfed_path, irrigated_path)],
        local_op, target_path, N_APP_DTYPE, current_nodata)


def intensified_rainfed_n_app(
        background_path, current_path, rainfed_path, target_path):
    background_nodata = _get_nodata(background_path)
    current_nodata = _get_nodata(current_path)
    rainfed_nodata = _get_nodata(rainfed_path)

    def local_op(background, current, rainfed):
        result = rainfed.copy()
        ix = np.isnan(result) | _equals_nodata(current, current_nodata)
        result[ix] = current[ix]

        return result + background

    pygeoprocessing.raster_calculator(
        [(path, 1) for path in (
            background_path, current_path, rainfed_path)],
        local_op, target_path, N_APP_DTYPE, current_nodata)


def n_app(
        scenario, background, current, rainfed, irrigated, output_file,
        all_bmps=False):
    current_codes = np.array([10, 11, 12, 19, 20, 29])
    rf_codes = np.array([15, 16])
    irr_codes = np.array([25, 26])
    intense_rf_code = 15
    intense_rf_bmp_code = 16
    intense_irr_code = 25
    intense_irr_bmp_code = 26

    scenario_raster_info = pygeoprocessing.get_raster_info(scenario)
    snd = scenario_raster_info["nodata"]
    output_nd = 0

    def local_op(s, b, c, r, i):
        result = np.zeros(s.shape, dtype=numpy.float32)
        if np.max(s) == 0:
            # skip ocean pixels
            return result

        land_ix = np.all([s != snd, s != 210], axis=0)
        result[land_ix] = b[land_ix]

        if all_bmps:
            ix = np.isin(s, current_codes)
            result[ix] += c[ix]
            ix = np.isin(s, rf_codes)
            result[ix] += r[ix]
            ix = np.isin(s, irr_codes)
            result[ix] += i[ix]
        else:
            ix = np.isin(s, current_codes)
            result[ix] += c[ix]
            ix = s == intense_rf_code
            result[ix] += r[ix]
            ix = s == intense_rf_bmp_code
            result[ix] += r[ix]
            ix = s == intense_irr_code
            result[ix] += i[ix]
            ix = s == intense_irr_bmp_code
            result[ix] += i[ix]

        return result

    src_rasters = [
        (r, 1) for r in [scenario, background, current, rainfed, irrigated]]

    pygeoprocessing.raster_calculator(
        src_rasters,
        local_op,
        output_file,
        N_APP_DTYPE,
        output_nd,
        calc_raster_stats=False
    )


def prepare_ndr_inputs(nci_gdrive_inputs_dir, target_outputs_dir,
                       n_workers=None):
    gdrive = pathlib.Path(nci_gdrive_inputs_dir)
    output_dir = pathlib.Path(target_outputs_dir)
    intermediate_dir = output_dir/'intermediate'

    for dirname in [output_dir, intermediate_dir]:
        if not os.path.exists(dirname):
            os.makedirs(dirname)

    if n_workers is None:
        n_workers = -1
    graph = taskgraph.TaskGraph(output_dir/'.taskgraph',
                                n_workers=int(n_workers),
                                reporting_interval=10)

    ####################
    # Saleh's scenario generation scripts
    ####################
    f_in = {key: gdrive/INPUT_FILES[key] for key in INPUT_FILES}
    f_out = {key: output_dir/OUTPUT_FILES[key] for key in OUTPUT_FILES}
    f_inter = {key: intermediate_dir/INTERM_FILES[key] for key in INTERM_FILES}
    files = {}
    files.update(f_in)
    files.update(f_out)
    files.update(f_inter)

    n_app_raster_info = pygeoprocessing.get_raster_info(str(f_in['n_current']))
    base_lulc_raster_info = pygeoprocessing.get_raster_info(str(f_in['base_lulc']))
    target_pixel_size = base_lulc_raster_info['pixel_size']

    warp_tasks = {}
    for input_key, warped_key in [
            ('modified_lulc', 'current_lulc_masked'),
            ('crop_value_current', 'crop_value_current_masked'),
            ('crop_value_intensified_rainfed',
                'crop_value_intensified_rainfed_masked'),
            ('crop_value_intensified_irrigated',
                'crop_value_intensified_irrigated_masked'),
            ('protected_areas', 'protected_areas_masked'),
            ('n_background', 'n_background_aligned'),
            ('n_current', 'n_current_aligned'),
            ('n_rainfed', 'n_rainfed_aligned'),
            ('n_irrigated', 'n_irrigated_aligned')]:
        warp_tasks[warped_key] = graph.add_task(
            pygeoprocessing.warp_raster,
            kwargs={
                'base_raster_path': str(files[input_key]),
                'target_pixel_size': target_pixel_size,
                'target_raster_path': str(files[warped_key]),
                'resample_method': 'near',
                'target_bb': n_app_raster_info['bounding_box'],
                'target_projection_wkt': n_app_raster_info['projection_wkt'],
            },
            task_name=f'Warp {input_key}',
            target_path_list=[str(files[warped_key])]
        )

    intensification_keys = [
        'current_lulc_masked',
        'slope_threshold_intensification',
        'crop_value_current_masked',
        'crop_value_intensified_rainfed_masked',
        'crop_value_intensified_irrigated_masked',
        'irrigated_suitability',
        'rainfed_suitability',
        'sustainable_irrigation',
        'soil_suitability',
    ]
    intensification_expansion_keys = [
        'intensification_optimized',
        'slope_threshold_intensification',
        'crop_value_intensified_rainfed_masked',
        'crop_value_intensified_irrigated_masked',
        'irrigated_suitability',
        'rainfed_suitability',
        'sustainable_irrigation',
        'soil_suitability',
        'protected_areas_masked'
    ]
    extensification_current_practices_keys = [
        'current_lulc_masked',
        'slope_threshold_expansion',
        'crop_value_current_masked',
        'irrigated_suitability',
        'rainfed_suitability',
        'sustainable_irrigation',
        'soil_suitability',
        'protected_areas_masked',
    ]
    lulc_tasks = {}  # key: task
    for lulc_key, raster_calculator_op, input_keys in [
            ('intensification_optimized',
                intensification_op,
                intensification_keys),
            ('intensification_optimized_expansion',
                intensification_expansion_op,
                intensification_expansion_keys),
            ('extensification_current_practices',
                extensification_current_practices_op,
                extensification_current_practices_keys)]:
        LOGGER.info(f"LULC key: {lulc_key}")

        lulc_tasks[lulc_key] = graph.add_task(
            pygeoprocessing.raster_calculator,
            kwargs={
                "base_raster_path_band_const_list": [
                    (str(files[key]), 1) for key in input_keys],
                "local_op": raster_calculator_op,
                "target_raster_path": str(f_out[lulc_key]),
                "datatype_target": LULC_DTYPE,
                "nodata_target": LULC_NODATA,
                "calc_raster_stats": True,
            },
            task_name=lulc_key,
            target_path_list=[str(f_out[lulc_key])],
            dependent_task_list=[
                *[warp_tasks[key] for key in input_keys if key in warp_tasks],
                *[lulc_tasks[key] for key in input_keys if key in lulc_tasks],
            ]
        )

    # These LULCs are just copies.
    for source_key, target_key in (
            ('intensification_optimized', 'intensification'),
            ('intensification_optimized_expansion', 'intensification_expansion')):
        LOGGER.info(f"LULC key: {target_key}")
        lulc_tasks[target_key] = graph.add_task(
            shutil.copyfile,
            args=(str(files[source_key]), files[target_key]),
            task_name=target_key,
            target_path_list=[str(files[target_key])],
            dependent_task_list=[lulc_tasks[source_key]]
        )

    for source_key, target_key in [
            ('current_lulc_masked', 'current_bmps'),
            ('intensification', 'intensification_bmps'),
            ('intensification_expansion', 'intensification_expansion_bmps'),
            ('intensification_optimized', 'intensification_optimized_bmps'),
            ('intensification_optimized_expansion', 'intensification_optimized_expansion_bmps'),
            ('extensification_current_practices', 'extensification_current_practices_bmps')]:
        input_keys = [source_key, 'riparian_buffer', 'potential_vegetation']
        lulc_tasks[target_key] = graph.add_task(
            pygeoprocessing.raster_calculator,
            kwargs={
                "base_raster_path_band_const_list": [
                    (str(files[key]), 1) for key in input_keys],
                "local_op": bmp_op,
                "target_raster_path": str(files[target_key]),
                "datatype_target": LULC_DTYPE,
                "nodata_target": LULC_NODATA,
                "calc_raster_stats": True,
            },
            task_name=target_key,
            target_path_list=[str(files[target_key])],
            dependent_task_list=[
                *[warp_tasks[key] for key in input_keys if key in warp_tasks],
                *[lulc_tasks[key] for key in input_keys if key in lulc_tasks],
            ]
        )

    # Lazy, but clearly separates LULC scenarios from the n_app steps.
    LOGGER.info("Waiting for LULC tasks to finish")
    graph.join()
    LOGGER.info("Starting n_app tasks")

    ####################
    # Peter's N Application scripts
    #
    # N application input rasters have already been aligned by this point.
    ####################
    current_n_app_raster_info = pygeoprocessing.get_raster_info(
        str(files['n_current']))
    current_n_app_nodata = current_n_app_raster_info['nodata'][0]
    if current_n_app_nodata is None:
        current_n_app_nodata = N_APP_NODATA

    current_n_app_task = graph.add_task(
        pygeoprocessing.symbolic.evaluate_raster_calculator_expression,
        kwargs={
            "expression": "background + current",
            "symbol_to_path_band_map": {
                "background": (str(files['n_background_aligned']), 1),
                "current": (str(files['n_current_aligned']), 1),
            },
            "target_nodata": current_n_app_nodata,
            "target_raster_path": str(files['current_n_app']),
            "default_nan": current_n_app_nodata,
            "default_inf": None,
        },
        task_name='current_n_app',
        target_path_list=[files['current_n_app']],
        dependent_task_list=[
            warp_tasks['n_background_aligned'],
            warp_tasks['n_current_aligned'],
        ]
    )
    for use_bmps in [False, True]:
        bmps_string = ''
        if use_bmps:
            bmps_string = '_bmps'
        intensified_irrigated_key = f'intensified_irrigated{bmps_string}_n_app'
        intensified_irrigated_task = graph.add_task(
            intensified_irrigated_n_app,
            kwargs={
                'background_path': str(files['n_background_aligned']),
                'current_path': str(files['n_current_aligned']),
                'rainfed_path': str(files['n_rainfed_aligned']),
                'irrigated_path': str(files['n_irrigated_aligned']),
                'target_path': str(files[intensified_irrigated_key]),
            },
            task_name=intensified_irrigated_key,
            target_path_list=[
                files[intensified_irrigated_key],
            ],
            dependent_task_list=[
                warp_tasks['n_background_aligned'],
                warp_tasks['n_current_aligned'],
                warp_tasks['n_rainfed_aligned'],
                warp_tasks['n_irrigated_aligned'],
            ]
        )

        intensified_rainfed_key = f'intensified_rainfed{bmps_string}_n_app'
        intensified_rainfed_task = graph.add_task(
            intensified_rainfed_n_app,
            kwargs={
                'background_path': str(files['n_background_aligned']),
                'current_path': str(files['n_current_aligned']),
                'rainfed_path': str(files['n_rainfed_aligned']),
                'target_path': str(files[intensified_rainfed_key]),
            },
            task_name=f'intensified_rainfed_bmps_{use_bmps}',
            target_path_list=[
                files[intensified_rainfed_key],
            ],
            dependent_task_list=[
                warp_tasks['n_background_aligned'],
                warp_tasks['n_current_aligned'],
                warp_tasks['n_rainfed_aligned'],
            ]
        )

    lulc_scenario_dependent_task_list = [
            warp_tasks['current_lulc_masked'],
            warp_tasks['n_background_aligned'],
            warp_tasks['n_current_aligned'],
            warp_tasks['n_rainfed_aligned'],
            warp_tasks['n_irrigated_aligned']
        ]

    for lulc_scenario in filter(
            lambda scenario: not scenario.startswith('intensification'),
            LULC_SCENARIOS):
        graph.add_task(
            n_app,
            kwargs={
                'scenario': str(files[lulc_scenario]),
                'background': str(files['n_background_aligned']),
                'current': str(files['n_current_aligned']),
                'rainfed': str(files['n_rainfed_aligned']),
                'irrigated': str(files['n_irrigated_aligned']),
                'output_file': str(files[f'{lulc_scenario}_n_app']),
                'all_bmps': 'bmp' in lulc_scenario,
            },
            task_name=f'{lulc_scenario}_n_app',
            target_path_list=[files[f'{lulc_scenario}_n_app']],
            dependent_task_list=[
                *lulc_scenario_dependent_task_list]
        )

    for lulc_scenario in filter(
            lambda scenario: (
                scenario.startswith('intensification')
                and 'optimized' not in scenario),
            LULC_SCENARIOS):
        intensification_raw_task = graph.add_task(
            n_app,
            kwargs={
                'scenario': str(files[lulc_scenario]),
                'background': str(files['n_background_aligned']),
                'current': str(files['n_current_aligned']),
                'rainfed': str(files['n_rainfed_aligned']),
                'irrigated': str(files['n_irrigated_aligned']),
                'output_file': str(files[f'{lulc_scenario}_raw_n_app']),
            },
            task_name=f'{lulc_scenario}_raw_n_app',
            target_path_list=[files[f'{lulc_scenario}_raw_n_app']],
            dependent_task_list=[
                *lulc_scenario_dependent_task_list]
        )
        intensification_task = graph.add_task(
            intensification_n_app,
            kwargs={
                'scenario_lulc': str(files[lulc_scenario]),
                'current_n_app': str(files['current_n_app']),
                'intensification_raw_n_app':
                    str(files[f'{lulc_scenario}_raw_n_app']),
                'target_n_app': str(files[f'{lulc_scenario}_n_app']),
            },
            task_name=f'{lulc_scenario}_n_app',
            target_path_list=[files[f'{lulc_scenario}_n_app']],
            dependent_task_list=[
                intensification_raw_task,
                *lulc_scenario_dependent_task_list]
        )
        optimized_scenario = lulc_scenario.replace(
            'intensification', 'intensification_optimized')
        _ = graph.add_task(
            intensification_optimized_n_app,
            kwargs={
                'intensification_n_app': str(files[f'{lulc_scenario}_n_app']),
                'target_n_app': str(files[f'{optimized_scenario}_n_app']),
            },
            task_name=f'{optimized_scenario}_n_app',
            target_path_list=[files[f'{optimized_scenario}_n_app']],
            dependent_task_list=[intensification_task]
        )
    graph.join()
    graph.close()

    with open(output_dir/'scenario_rasters.json', 'w') as json_file:
        json_data = {}
        for key in OUTPUT_FILES:
            filepath = files[key]
            if 'n_app' not in key:
                json_data[f'{key}_lulc'] = str(filepath)
            else:
                json_data[key] = str(filepath)

        json.dump(json_data, json_file, indent=4)


def main(args=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--input-dir')
    parser.add_argument('--output-dir')
    parser.add_argument('--n-workers')

    args = parser.parse_args(args)
    prepare_ndr_inputs(
        nci_gdrive_inputs_dir=args.input_dir,
        target_outputs_dir=args.output_dir,
        n_workers=args.n_workers)


if __name__ == '__main__':
    main()
