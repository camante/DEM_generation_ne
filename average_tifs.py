import sys
from osgeo import gdal
import numpy as np
from gdalconst import *
from osgeo import osr

# Function to read the original file's projection:
def GetGeoInfo(FileName):
    SourceDS = gdal.Open(FileName, GA_ReadOnly)
    #NDV = SourceDS.GetRasterBand(1).GetNoDataValue()
    xsize = SourceDS.RasterXSize
    ysize = SourceDS.RasterYSize
    GeoT = SourceDS.GetGeoTransform()
    Projection = osr.SpatialReference()
    Projection.ImportFromWkt(SourceDS.GetProjectionRef())
    DataType = SourceDS.GetRasterBand(1).DataType
    DataType = gdal.GetDataTypeName(DataType)
    return xsize, ysize, GeoT, Projection, DataType

# Function to write a new file.
def CreateGeoTiff(Name, Array, driver,
                  xsize, ysize, GeoT, Projection, DataType):
    if DataType == 'Float32':
        DataType = gdal.GDT_Float32
    NewFileName = Name+'.tif'
    # Set nans to the original No Data Value
    #Array[np.isnan(Array)] = NDV
    # Set up the dataset
    DataSet = driver.Create( NewFileName, xsize, ysize, 1, DataType )
            # the '1' is for band 1.
    DataSet.SetGeoTransform(GeoT)
    
    wkt_proj = Projection.ExportToWkt()
    if wkt_proj.startswith("LOCAL_CS"):
        wkt_proj = wkt_proj[len("LOCAL_CS"):]
        wkt_proj = "PROJCS"+wkt_proj
    DataSet.SetProjection(wkt_proj)
    #DataSet.SetProjection( Projection.ExportToWkt() )
    
    # Write the array
    DataSet.GetRasterBand(1).WriteArray( Array )
    #DataSet.GetRasterBand(1).SetNoDataValue(NDV)
    return NewFileName

vrt=sys.argv[1]
moasic_output=vrt[:-4]+"_mosaic"
g = gdal.Open(vrt)
xsize, ysize, GeoT, Projection, DataType = GetGeoInfo(vrt) 

print xsize
print ysize

data = g.ReadAsArray() 
print np.shape(data)

#data = g.ReadAsArray()
mask_array = np.ma.array(data, mask=(data == -999999))
print np.shape(mask_array)
avg_array = mask_array.mean(axis=0)

print np.shape(avg_array)
#print mean_s0
driver = gdal.GetDriverByName('GTiff')
CreateGeoTiff(moasic_output, avg_array, driver, xsize, ysize, GeoT, Projection, DataType)
