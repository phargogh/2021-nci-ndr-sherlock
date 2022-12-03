# assume that we're executing from the NCI_Score repo root.
import importlib.machinery
import importlib.util
import logging
import os
import sys

sys.path.append('NCI_Score')  # So we can import Saleh's water package.
logging.basicConfig(level=logging.INFO)

from water import scenario_generation

# Load Peter's script from source code.
loader = importlib.machinery.SourceFileLoader(
    'make_fertilizer_application_rasters',
    os.path.join(os.path.dirname(__file__), 'natural-capital-index', 'src',
                 'one-off', 'make_fertilizer_application_rasters.py'))
spec = importlib.util.spec_from_loader(loader.name, loader)
make_fertilizer_app_rasters = importlib.util.module_from_spec(spec)
loader.exec_module(make_fertilizer_app_rasters)

if __name__ == '__main__':
    scenario_generation.main(input_folder=sys.argv[1],
                             target_folder=sys.argv[2])
    make_fertilizer_app_rasters.main(
        run=True,
        input_folder=sys.argv[1],
        output_folder=os.path.join(sys.argv[2], 'N_application')
    )
