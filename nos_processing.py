#!/usr/bin/python
'''
Description:
-Download NOS with fetch
-separate between NOS and BAGs
-unzip any gz
-remove NOS header and convert to X,Y,Negative Z and then to NAVD88
-convert BAG to tif and chunk, and convert to NAVD88
-bag2tif2chunks2xyz.sh and vert_conv.sh and create_datalist.sh

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
######################## NOS ####################################
roi_str_gmt=sys.argv[1]
conv_grd_path=sys.argv[2]
bs_dlist=sys.argv[3]
dem_dlist=sys.argv[4]
#other params
chunk_size=500
resamp_bag='yes'
resamp_res=0.000030864199
#test
#roi_str_gmt='-71/-70/40/41'
#roi_str_gmt='-71/-70/42/43'
#roi_str_gmt='-75/-74/36/37'

print "Current directory is ", os.getcwd()
print 'Downloading NOS / BAG Surveys'
print 'Downloading in roi', roi_str_gmt	
nos_download_cmd='''fetches -R {} nos '''.format(roi_str_gmt)
print nos_download_cmd
os.system(nos_download_cmd)

print "Separating NOS and BAG Surveys"
move_xyz_gz_cmd="find . -name '*.xyz.gz' -exec mv {} nos_hydro/ \; 2>/dev/null"
os.system(move_xyz_gz_cmd)

move_bag_cmd="find . -name '*.bag*' -exec mv {} nos_bag/ \; 2>/dev/null"
os.system(move_bag_cmd)

move_bag_gz_cmd="find . -name '*.bag.gz' -exec mv {} nos_bag/ \; 2>/dev/null"
os.system(move_bag_gz_cmd)

print "Unzipping NOS"
os.chdir('nos_hydro')
os.system('gunzip *.xyz.gz')

print "Moving all xyz files to xyz directory"
move_xyz_cmd="find . -name '*.xyz' -exec mv {} xyz/ \; 2>/dev/null"
os.system(move_xyz_cmd)

print "Converting NOS to X,Y,Negative Z"
os.chdir('xyz')
neg_z_cmd=('./nos2xyz.sh')
os.system(neg_z_cmd)

print "Converting NOS to NAVD88"
os.chdir('neg_m')
nos2navd88_cmd="./vert_conv.sh " + conv_grd_path + "  navd88"
os.system(nos2navd88_cmd)

print "Creating NOS Datalist"
os.chdir('navd88')
nos_datalist_cmd='./create_datalist.sh nos_hydro'
os.system(nos_datalist_cmd)

current_dir=os.getcwd()
add_to_bmaster_cmd='echo ' + current_dir + '/nos_hydro.datalist -1 1 >> ' + bs_dlist
os.system(add_to_bmaster_cmd)


os.chdir('../../../..')


os.chdir('nos_bag')

print "Converting BAG to tif and to XYZ"
bag2tif2chunks2xyz_cmd='''./bag2tif2chunks2xyz.sh {} {} {}'''.format(chunk_size,resamp_bag,resamp_res)
os.system(bag2tif2chunks2xyz_cmd)

print "Converting BAG to NAVD88"
os.chdir('xyz')
bag2navd88_cmd="./vert_conv.sh " + conv_grd_path + "  navd88"
#vert_conv.sh /media/sf_external_hd/al_fl/data/conv_grd/cgrid_mllw2navd88.tif navd88
os.system(bag2navd88_cmd)

print "Creating BAG Datalist"
os.chdir('navd88')
bag_datalist_cmd='./create_datalist.sh nos_bag'
os.system(bag_datalist_cmd)

current_dir=os.getcwd()
add_to_bmaster_cmd='echo ' + current_dir + '/nos_bag.datalist -1 10 >> ' + bs_dlist
os.system(add_to_bmaster_cmd)

add_to_master_cmd='echo ' + current_dir + '/nos_bag.datalist -1 10 >> ' + dem_dlist
os.system(add_to_master_cmd)
