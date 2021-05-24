#!/usr/bin/python
'''
Description:
-Manually Download ENCs SoundingsP at each scale (approach, harbour) via https://encdirect.noaa.gov/
-don't use overview, general, coastal, berthing scales.
-unzip folders
-move shp to same directory
-convert to xyz, negative
-convert mllw to navd88
-create_datalist

Author:
Chris Amante
Christopher.Amante@colorado.edu

Date:
1/14/2020

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
######################## ENC ####################################
print "Current directory is ", os.getcwd()

study_area_shp=sys.argv[1]
conv_grd_path=sys.argv[2]
bs_dlist=sys.argv[3]

print 'Downloading ENCs'
enc_download_cmd='''fetches -R {} charts -p --where "DataType = 'ENC'" '''.format(study_area_shp)

print enc_download_cmd
os.system(enc_download_cmd)

# new method
os.chdir('charts')

mllw2navd88_cmd="./vert_conv.sh " + conv_grd_path + "  navd88"
os.system(mllw2navd88_cmd)

print "Creating ENC Datalist"
os.chdir('navd88')
enc_datalist_cmd='./create_datalist.sh enc'
os.system(enc_datalist_cmd)

current_dir=os.getcwd()
add_to_bmaster_cmd='echo ' + current_dir + '/enc.datalist -1 0.0001 >> ' + bs_dlist
os.system(add_to_bmaster_cmd)



### OLD METHOD ###
# old method, before using Matt's processing option
# move_xyz_cmd="find . -name '*.xyz' -exec mv {} xyz/ \; 2>/dev/null"
# os.system(move_xyz_cmd)

# print "Converting ENC to Negative Z"
# os.chdir('xyz')
# pos2neg_cmd=('./pos2neg.sh')
# os.system(pos2neg_cmd)

# print "Converting ENC to NAVD88"
# os.chdir('neg')
# mllw2navd88_cmd="./vert_conv.sh " + conv_grd_path + "  navd88"
# os.system(mllw2navd88_cmd)

# print "Creating ENC Datalist"
# os.chdir('navd88')
# enc_datalist_cmd='./create_datalist.sh enc'
# os.system(enc_datalist_cmd)

# current_dir=os.getcwd()
# add_to_bmaster_cmd='echo ' + current_dir + '/enc.datalist -1 0.0001 >> ' + bs_dlist
# os.system(add_to_bmaster_cmd)
### OLD METHOD ###


