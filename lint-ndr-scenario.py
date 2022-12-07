import importlib
import logging
import os
import sys

sys.path.append('ndr_plus_global_pipeline/scenarios')
logging.basicConfig(level=logging.INFO)
LOGGER = logging.getLogger(__name__)


def main(scenario_name):
    scenario = importlib.import_module(scenario_name)
    error = False
    for ndr_scenario_key, files_dict in scenario.SCENARIOS.items():
        for file_key, ecoshards_key in files_dict.items():
            try:
                file_path = scenario.ECOSHARDS[ecoshards_key]
            except KeyError:
                LOGGER.error(
                    "Key not found in ECOSHARDS: "
                    f"{ndr_scenario_key}:{file_key}")
                error = True

            if not os.path.exists(file_path):
                LOGGER.error(
                    "File not found: "
                    f"{ndr_scenario_key}:{file_key}:{file_path}")
                error = True

    if error:
        raise AssertionError("One or more files/keys do not work as expected.")
    LOGGER.info("All OK")


if __name__ == '__main__':
    main(sys.argv[1])
