import argparse
import logging
import os
import pathlib
import pprint

import numpy
import numpy as np
import pygeoprocessing
import taskgraph
from osgeo import gdal

logging.basicConfig(level=logging.INFO)
LOGGER = logging.getLogger(__name__)

# These paths are relative to the NCI gdrive folder.
INPUT_FILES = {
    "base_lulc": "ESACCI-LC-L4-LCCS-Map-300m-P1Y-2015-v2.0.7_md5_1254d25f937e6d9bdee5779d377c5aa4.tif",
    "modified_lulc": "current_lulc/modifiedESA_2022_06_03.tif",
    "potential_vegetation": "scenario_construction/potential_vegetation/potential_vegation.tif",
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
}

OUTPUT_FILES = {
    "current_bmps": "current_bmps.tif",
    "current_lulc_masked": "current_lulc_masked.tif",
    "extensification_current_practices": "extensification_current_practices.tif",
    "extensification_current_practices_bmps": "extensification_current_practices_bmps.tif",
    "intensification": "intensification.tif",
    "intensification_bmps": "intensification_bmps.tif",
    "intensification_expansion": "intensification_expansion.tif",
    "intensification_expansion_bmps": "intensification_expansion_bmps.tif",
}

INTERM_FILES = {
    'crop_value_current_masked': "crop_value_current_masked.tif",
    'crop_value_intensified_rainfed_masked': "crop_value_intensified_rainfed_masked.tif",
    'crop_value_intensified_irrigated_masked': "crop_value_intensified_irrigated_masked.tif",
    'protected_areas_masked': "protected_areas_masked.tif",
    'cropland_current_practices_suitability': "current_practices.tif",
    'cropland_intensified_rainfed_suitability': "intensified_rainfed.tif",
    'cropland_intensified_irrigated_suitability': "intensified_irrigated.tif",
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
                                n_workers=int(n_workers))

    f_in = {key: gdrive/INPUT_FILES[key] for key in INPUT_FILES}
    f_out = {key: output_dir/OUTPUT_FILES[key] for key in OUTPUT_FILES}
    f_inter = {key: intermediate_dir/INTERM_FILES[key] for key in INTERM_FILES}
    files = {}
    files.update(f_in)
    files.update(f_out)
    files.update(f_inter)

    base_lulc_info = pygeoprocessing.get_raster_info(str(f_in['base_lulc']))

    warp_tasks = {}
    for input_key, warped_key in [
            ('modified_lulc', 'current_lulc_masked'),
            ('crop_value_current', 'crop_value_current_masked'),
            ('crop_value_intensified_rainfed',
                'crop_value_intensified_rainfed_masked'),
            ('crop_value_intensified_irrigated',
                'crop_value_intensified_irrigated_masked'),
            ('protected_areas', 'protected_areas_masked')]:
        warp_tasks[warped_key] = graph.add_task(
            pygeoprocessing.warp_raster,
            kwargs={
                'base_raster_path': str(files[input_key]),
                'target_pixel_size': base_lulc_info['pixel_size'],
                'target_raster_path': str(files[warped_key]),
                'resample_method': 'near',
                'target_bb': base_lulc_info['bounding_box'],
                'target_projection_wkt': base_lulc_info['projection_wkt'],
            },
            task_name=f'Warp {input_key}',
            target_path_list=[files[warped_key]]
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
    intensification_task = graph.add_task(
        pygeoprocessing.raster_calculator,
        kwargs={
            "base_raster_path_band_const_list": [
                (str(files[key]), 1) for key in intensification_keys],
            "local_op": intensification_op,
            "target_raster_path": str(f_out['intensification']),
            "datatype_target": base_lulc_info['datatype'],
            "nodata_target": base_lulc_info['nodata'][0],
            "calc_raster_stats": True,
        },
        task_name='intensification',
        target_path_list=[f_out['intensification']],
        dependent_task_list=[
            warp_tasks[key] for key in intensification_keys
            if key in warp_tasks
        ]
    )


    intensification_expansion_keys = [
        'intensification',
        'slope_threshold_intensification',
        'crop_value_intensified_rainfed_masked',
        'crop_value_intensified_irrigated_masked',
        'irrigated_suitability',
        'rainfed_suitability',
        'sustainable_irrigation',
        'soil_suitability',
        'protected_areas_masked'
    ]
    intensification_expansion_task = graph.add_task(
        pygeoprocessing.raster_calculator,
        kwargs={
            "base_raster_path_band_const_list": [
                (str(files[key]), 1) for key in intensification_expansion_keys],
            "local_op": intensification_expansion_op,
            "target_raster_path": str(f_out['intensification_expansion']),
            "datatype_target": base_lulc_info['datatype'],
            "nodata_target": base_lulc_info['nodata'][0],
            "calc_raster_stats": True,
        },
        task_name='intensification_expansion',
        target_path_list=[f_out['intensification_expansion']],
        dependent_task_list=[
            warp_tasks[key] for key in intensification_expansion_keys
            if key in warp_tasks
        ]
    )

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
    extensification_current_practices_task = graph.add_task(
        pygeoprocessing.raster_calculator,
        kwargs={
            "base_raster_path_band_const_list": [
                (str(files[key]), 1) for key in
                extensification_current_practices_keys],
            "local_op": extensification_current_practices_op,
            "target_raster_path": str(f_out['extensification_current_practices']),
            "datatype_target": base_lulc_info['datatype'],
            "nodata_target": base_lulc_info['nodata'][0],
            "calc_raster_stats": True,
        },
        task_name='extensification_current_practices',
        target_path_list=[f_out['extensification_current_practices']],
        dependent_task_list=[
            warp_tasks[key] for key in extensification_current_practices_keys
            if key in warp_tasks
        ]
    )






    graph.join()
    graph.close()








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
