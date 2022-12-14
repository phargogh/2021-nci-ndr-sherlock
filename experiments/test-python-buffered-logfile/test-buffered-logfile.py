import logging
import logging.handlers
import os
import shutil
import sys
import tempfile
import time

N_LOOPS = 1000000

LOGGER = logging.getLogger(__name__)


def test_baseline_print():
    start_time = time.time()
    for i in range(N_LOOPS):
        print(f"Printing line {i} of {N_LOOPS}")
    return time.time() - start_time


def test_standard_logging(dirname):
    target_dir = tempfile.mkdtemp(dir=dirname)

    file_handler = logging.FileHandler(os.path.join(target_dir, 'log.txt'))
    LOGGER.addHandler(file_handler)

    start_time = time.time()
    for i in range(N_LOOPS):
        LOGGER.info(f"Logging line {i} of {N_LOOPS}")
    elapsed = time.time() - start_time
    LOGGER.removeHandler(file_handler)
    shutil.rmtree(target_dir)

    return elapsed


def test_buffered_logging(dirname):
    target_dir = tempfile.mkdtemp(dir=dirname)

    file_handler = logging.FileHandler(os.path.join(target_dir, 'log.txt'))
    mem_handler = logging.handlers.MemoryHandler(1000, target=file_handler)
    LOGGER.addHandler(mem_handler)

    start_time = time.time()
    for i in range(N_LOOPS):
        LOGGER.info(f"Logging line {i} of {N_LOOPS}")
    elapsed = time.time() - start_time
    LOGGER.removeHandler(file_handler)
    shutil.rmtree(target_dir)

    return elapsed


def main():
    row = []
    row.append(test_baseline_print())
    for env_var in ['SCRATCH', 'L_SCRATCH']:
        filepath = os.environ[env_var]
        row.append(test_standard_logging(filepath))
        row.append(test_buffered_logging(filepath))

    if not os.path.exists(sys.argv[1]):
        with open(sys.argv[1], 'w') as result_csv:
            result_csv.write(
                'baseline,std_scratch,buf_scratch,std_lscratch,buf_lscratch\n')

    with open(sys.argv[1], 'a') as result_csv:
        result_csv.write(','.join([str(val) for val in row]) + '\n')


if __name__ == '__main__':
    main()
