#!/usr/bin/python
'''
Description:
-clip landsat derived to study area

Author:
Chris Amante
Christopher.Amante@colorado.edu

Date:
6/5/2019

'''
#################################################################
#################################################################
#################################################################
####################### IMPORT MODULES ##########################
#################################################################
#################################################################
#################################################################
import os
import sys
import glob
######################## COASTLINE ####################################
#Params from master script:
basename=sys.argv[1]
main_dir=sys.argv[2]
west_buff=sys.argv[3]
east_buff=sys.argv[4]
south_buff=sys.argv[5]
north_buff=sys.argv[6]
study_area_shp=sys.argv[7]
roi_str_ogr=str(west_buff)+' '+str(south_buff)+' '+str(east_buff)+' '+str(north_buff)

dataset_dir=os.getcwd()
print "Current Directory is ", dataset_dir

#Additional Params:
landsat_shp='/media/sf_C_win_lx/data/coast/landsat_all_NA.shp'

print 'Clipping Landsat Shp to Study Area'
clip_landsat_cmd='''ogr2ogr -clipsrc {} {}_landsat {}'''.format(roi_str_ogr,basename,landsat_shp)
print clip_landsat_cmd
os.system(clip_landsat_cmd)

#print "Renaming clipped coastline"
#rn_landsat_cmd='''{}_landsat.shp {}_coast.shp'''.format(basename)
