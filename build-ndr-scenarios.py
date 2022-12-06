# assume that we're executing from the NCI_Score repo root.
import logging
import sys

sys.path.append('NCI_Score')  # To import Saleh's water package.
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%m/%d/%Y %I:%M:%S %p'
)
LOGGER = logging.getLogger(__name__)

from water import scenario_generation

if __name__ == '__main__':
    scenario_generation.main(
        input_folder=sys.argv[1],
        target_folder=sys.argv[2])
    LOGGER.info("Finished build-ndr-scenarios script.")
