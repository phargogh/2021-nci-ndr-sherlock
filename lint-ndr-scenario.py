import importlib
import logging
import os
import sys

logging.basicConfig(level=logging.INFO)
LOGGER = logging.getLogger(__name__)


def main(scenario_name):
    scenario = importlib.import_module(scenario_name)
    error = False
    for ndr_scenario_key, files_dict in scenario.SCENARIOS.items():
        for file_key, file_path in files_dict.items():
            if not os.path.exists(file_path):
                LOGGER.error(
                    "File not found: "
                    f"{ndr_scenario_key}:{file_key}:{file_path}")
                error = True
            if file_key not in scenario.ECOSHARDS:
                LOGGER.error(
                    "Key not found in ECOSHARDS: "
                    f"{ndr_scenario_key}:{file_key}")
                error = True

    if error:
        raise AssertionError("One or more files/keys do not work as expected.")
    LOGGER.info("All OK")


if __name__ == '__main__':
    main(sys.argv[1])
