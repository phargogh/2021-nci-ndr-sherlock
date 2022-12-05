# assume that we're executing from the NCI_Score repo root.
import logging
import os
import sys

sys.path.append('NCI_Score')  # To import Saleh's water package.
sys.path.append('natural-capital-index/src/one-off')  # For Peter's script
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%m/%d/%Y %I:%M:%S %p'
)
LOGGER = logging.getLogger(__name__)

import make_fertilizer_application_rasters
from water import scenario_generation

if __name__ == '__main__':
    scenario_generation.main(
        input_folder=sys.argv[1],
        target_folder=sys.argv[2])
    make_fertilizer_application_rasters.main(
        input_folder=sys.argv[1],
        output_folder=os.path.join(sys.argv[2], 'N_application')
    )
    LOGGER.info("Finished build-ndr-scenarios script.")
