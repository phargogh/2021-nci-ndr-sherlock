import logging
import os
import sys

sys.path.append('natural-capital-index/src/one-off')  # For Peter's script
import make_fertilizer_application_rasters

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%m/%d/%Y %I:%M:%S %p'
)
LOGGER = logging.getLogger(__name__)


if __name__ == '__main__':
    make_fertilizer_application_rasters.main(
        input_folder=sys.argv[1],
        output_folder=os.path.join(sys.argv[2], 'N_application')
    )
    LOGGER.info("Finished build-n-app-scenarios script.")
