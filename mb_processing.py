#!/usr/bin/python
'''
Description:
-Download MB with fetch
-Process by resampling to X cell size


Author:
Chris Amante
Christopher.Amante@colorado.edu

Date:
5/23/2019

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
######################## MB ###########################
study_area_shp=sys.argv[1]
roi_str_gmt=sys.argv[2]
bs_dlist=sys.argv[3]
#other params
#1 arc-sec
#bm_cell=0.00027777777
#1/9 arc-sec res
bm_cell='0.11111111111s'
min_val=-1000
max_val= 0

print "Current directory is ", os.getcwd()
print 'Downloading MB Surveys'
#os.system('fetches -R {} -p -E {} -Z {}/{} mb'.format(roi_str_gmt, bm_cell, min_val, max_val))

#old method below
#os.system('./download_mb_roi.sh {} {} {} {}'.format(roi_str_gmt, bm_cell, min_val, max_val))

#Copy if you want to keep copy of xyz separated by surveys
# print 'Copying all files to xyz directory'
# cp_xyz_cmd="find . -name '*.xyz' -exec cp {} xyz/ \; 2>/dev/null"
# os.system(cp_xyz_cmd)

#Move if you dont want to keep copy of xyz separated by surveys
print 'Moving all files to xyz directory'
mv_xyz_cmd="find . -name '*.xyz' -exec mv {} xyz/ \; 2>/dev/null"
os.system(mv_xyz_cmd)

print "Creating datalist"
os.chdir('xyz')

mb_datalist_cmd='./create_datalist.sh mb'
os.system(mb_datalist_cmd)

current_dir=os.getcwd()
add_to_bmaster_cmd='echo ' + current_dir + '/mb.datalist -1 0.01 >> ' + bs_dlist
os.system(add_to_bmaster_cmd)
