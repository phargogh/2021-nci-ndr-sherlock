import importlib
import logging
import os
import pprint
import sys

import numpy
import pygeoprocessing

sys.path.append('ndr_plus_global_pipeline/scenarios')
logging.basicConfig(level=logging.INFO)
LOGGER = logging.getLogger(__name__)


def main(scenario_name):
    scenario = importlib.import_module(scenario_name)
    files_not_found_error = False
    invalid_files_error = False
    files_checked = set()
    for ndr_scenario_key, files_dict in scenario.SCENARIOS.items():
        for file_key, ecoshards_key in files_dict.items():
            try:
                file_path = scenario.ECOSHARDS[ecoshards_key]
            except KeyError:
                LOGGER.error(
                    "Key not found in ECOSHARDS: "
                    f"{ndr_scenario_key}:{file_key} ({ecoshards_key})")
                files_not_found_error = True
                continue

            if not os.path.exists(file_path):
                LOGGER.error(
                    "File not found: "
                    f"{ndr_scenario_key}:{file_key}:{file_path}")
                files_not_found_error = True

            if file_path.endswith('.tif'):
                n_valid_pixels = 0
                files_checked.add(file_path)
                nodata = pygeoprocessing.get_raster_info(
                    file_path)['nodata'][0]
                for _, array in pygeoprocessing.iterblocks((file_path, 1)):
                    if nodata is None:
                        valid_mask = numpy.ones(array.shape, dtype=bool)
                    elif numpy.issubdtype(array.dtype, numpy.integer):
                        valid_mask = ~(array == nodata)
                    else:  # defined nodata value, float array
                        valid_mask = (
                            ~numpy.isclose(array, nodata, equal_nan=True) &
                            ~numpy.isnan(array))

                    n_valid_pixels += numpy.count_nonzero(valid_mask)
                if n_valid_pixels == 0:
                    LOGGER.error(
                        f"Raster is fully nodata or nan: \n"
                        f"    NDR scenario: {ndr_scenario_key}\n"
                        f"    File key: {file_key}\n"
                        f"    Filepath: {file_path}")
                    invalid_files_error = True

    if files_not_found_error:
        LOGGER.info("The current state of ECOSHARDS looks like:\n"
                    f"{pprint.pformat(scenario.ECOSHARDS)}")
        raise AssertionError("One or more files/keys do not work as expected.")

    if invalid_files_error:
        raise AssertionError("One or more files are 100% nodata or NaN.")
    LOGGER.info("All OK")


if __name__ == '__main__':
    main(sys.argv[1])
