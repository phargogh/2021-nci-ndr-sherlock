# assume that we're executing from the NCI_Score repo root.
import logging
import sys

logging.basicConfig(level=logging.INFO)

from water import scenario_generation

if __name__ == '__main__':
    scenario_generation.main(input_folder=sys.argv[1],
                             target_folder=sys.argv[2])
