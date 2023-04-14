import matplotlib.pyplot as plt
import numpy
from osgeo import gdal

gdal.SetCacheMax(2**30)  # about 1.1 GB

raster_path = '/scratch/users/jadoug06/NCI-WQ-full-2023-04-11-rev443-047031a/NCI-NDRplus-rev443-047031a-intensification/compressed_intensification_300.0_D8_export.tif'
raster = gdal.OpenEx(raster_path)
band = raster.GetRasterBand(1)
array = band.ReadAsArray()

plt.imshow(array)
plt.savefig('array.png', dpi=300)
