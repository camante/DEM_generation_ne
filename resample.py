''' 
Resample DEMs to finer resolution by repeating the same elevation values within each finer res cell
'''
#Modules
import os, sys
import glob
import numpy as np
from osgeo import gdal
from gdalconst import *
from osgeo import osr
#######################################################################################
#######################################################################################
################################### FUNCTIONS #########################################
#######################################################################################
#######################################################################################

# Get info from original rasters to use while creating final rasters from arrays
def GetGeoInfo(FileName):
	SourceDS = gdal.Open(FileName, GA_ReadOnly)
	xsize = SourceDS.RasterXSize
	ysize = SourceDS.RasterYSize
	GeoT = SourceDS.GetGeoTransform()
	
	Projection = osr.SpatialReference()
	Projection.ImportFromWkt(SourceDS.GetProjectionRef())
	
	#Projection = SourceDS.GetProjection()
	
	DataType = SourceDS.GetRasterBand(1).DataType
	DataType = gdal.GetDataTypeName(DataType)
	return xsize, ysize, GeoT, Projection, DataType

#Create geotiff from array. Use GetGeoInfo function to get required inputs
def CreateGeoTiff(Name, Array, driver,
				  xsize, ysize, GeoT, Projection, DataType):
	if DataType == 'Float32':
		DataType = gdal.GDT_Float32
	NewFileName = Name+'.tif'
	# Set up the dataset
	DataSet = driver.Create( NewFileName, xsize, ysize, 1, DataType )
			# the '1' is for band 1.
	DataSet.SetGeoTransform(GeoT)
	DataSet.SetProjection(Projection.ExportToWkt())
	# Write the array
	DataSet.GetRasterBand(1).WriteArray( Array )
	return NewFileName

# Resample a coarse resolution to a fine resolution. This simply puts the same value of the coarse cell in finer cells within the coarse footprint.
def resample(coarseArrayCellSize, fineArrayCellSize, coarseArray, fineArray):
	numCells = int((coarseArrayCellSize/fineArrayCellSize))
	for row in range(0,coarseArray.shape[0]):#This is number of rows, minus the last row (filter size). 0 refers to rows
		for col in range(0,coarseArray.shape[1]):#This is the number of columns, minus the last column (filter size). 1 refers to columns                       
			for z in range(0,numCells):
				for j in range (0,numCells): 
					fineArray[(row*numCells)+j][(col*numCells)+z] = coarseArray[(row)][(col)]
	return fineArray

coarse_dem=sys.argv[1]
fine_dem=sys.argv[2]
res_factor=int(sys.argv[3])
resamp_dem_tmp=str(coarse_dem)
resamp_dem=resamp_dem_tmp[:-4]+"_resamp"
print "Coarse DEM is", coarse_dem
print "Fine DEM is", fine_dem
print "Res Factor is", res_factor
print "Resampled DEM name is", resamp_dem

#xsize_coarse, ysize_coarse, GeoT_coarse, Projection_coarse, DataType_coarse = GetGeoInfo(coarse_dem)    
# Set up the GTiff driver
driver = gdal.GetDriverByName('GTiff')

dem_coarse_g = gdal.Open(coarse_dem)
dem_coarse_cols = dem_coarse_g.RasterXSize
dem_coarse_rows = dem_coarse_g.RasterYSize
dem_coarse_array = dem_coarse_g.GetRasterBand(1).ReadAsArray(0,0,dem_coarse_cols,dem_coarse_rows).astype(float).round(3)

dem_fine_g = gdal.Open(fine_dem)
dem_fine_cols = dem_fine_g.RasterXSize
dem_fine_rows = dem_fine_g.RasterYSize
dem_fine_array = dem_fine_g.GetRasterBand(1).ReadAsArray(0,0,dem_fine_cols,dem_fine_rows).astype(float).round(3)
xsize, ysize, GeoT, Projection, DataType = GetGeoInfo(fine_dem) 

fine_empty_array=np.empty_like(dem_fine_array)

dem_resampled2fine=resample(res_factor, 1, dem_coarse_array, fine_empty_array)
print "resampled DEM w ", res_factor, "times spatial res to finest resolution"

CreateGeoTiff(resamp_dem, dem_resampled2fine, driver, xsize, ysize, GeoT, Projection, DataType)
print "created resampled DEM tif"
