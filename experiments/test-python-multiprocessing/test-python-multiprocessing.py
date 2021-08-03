import logging
import multiprocessing

logging.basicConfig(level=logging.DEBUG)

LOGGER = logging.getLogger(__file__)


if __name__ == '__main__':
	LOGGER.debug(multiprocessing.cpu_count())
