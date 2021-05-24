#!/usr/bin/python

'''
Description:
Master Script to Generate DEMs for TX and West LA. 

Author:
Christopher Amante
Christopher.Amante@colorado.edu

Date:
9/18/2020

'''
#################################################################
#################################################################
#################################################################
####################### IMPORT MODULES ##########################
#################################################################
#################################################################
#################################################################
import os
import subprocess
import sys
import glob
#################################################################
#################################################################
#################################################################
###################### PROCESS VARIABLES ########################
#################################################################
#################################################################
#################################################################
conv_grd_process='no'
coast_process='no'
usace_dredge_process='no'
usace_dredge_process_reinterp='no'
mb_process='yes'
nos_process='no'
enc_process='no'
dc_lidar_process='no'
tnm_lidar_process='no'
canada_lidar_process='no'
ncei_dems_process='no'
topo_guide_process='no'
bathy_surf_process='no'
dem_process='no'
spatial_meta_process='no'
final_dem_format_process='no'
uncertainty_process='no'
#################################################################
#################################################################
#################################################################
###################### INITIAL VARIABLES ########################
#################################################################
#################################################################
#################################################################
#Project Area
basename="ne"
year=2021
version=1
#Main Directory Paths
main_dir='/media/sf_F_win_lx/COASTAL_Act/camante/'+basename
code_dir=main_dir+'/code/DEM_generation'+'_'+basename
auto_dir=main_dir+'/auto'
manual_dir=main_dir+'/manual'
#Main Subdirectory Paths
data_dir=auto_dir+'/data'
software_dir=auto_dir+'/software'
docs_dir=manual_dir+'/docs'
lastools_dir='/media/sf_C_win_lx/software/LAStools/bin/'
#Bathy Surface Variables
manual_name_cell_extents_bs=manual_dir+'/data/bathy/bathy_surf/'+basename+'_name_cell_extents_bs.csv'
name_cell_extents_bs=data_dir+'/bathy/bathy_surf/'+basename+'_name_cell_extents_bs.csv'
bs_topo_guide_dlist=data_dir+'/bathy/bathy_surf/topo_guide/topo_guide.datalist'
bs_dlist=data_dir+'/bathy/bathy_surf/'+basename+'_bs.datalist'
bs_ind_dlist=data_dir+'/bathy/bathy_surf/xyz/bathy_surf.datalist'
bs_tifs=data_dir+'/bathy/bathy_surf/tifs'
coast_shp=data_dir+'/coast/'+basename+'_coast'
#use files listed in existing mb1 files at datalist
bs_mb1_var='no'
#
#DEM Gridding Variables
manual_name_cell_extents_dem=manual_dir+'/software/gridding/'+basename+'_name_cell_extents_dem.csv'
manual_name_cell_extents_dem_all=manual_dir+'/software/gridding/'+basename+'_name_cell_extents_dem_all.csv'
name_cell_extents_dem=software_dir+'/gridding/'+basename+'_name_cell_extents_dem.csv'
name_cell_extents_dem_all=software_dir+'/gridding/tifs/smoothed/'+basename+'_name_cell_extents_dem_all.csv'
dem_dlist=software_dir+'/gridding/'+basename+'_dem.datalist'
dem_smooth_factor=5
#use files listed in existing mb1 files at datalist
dem_mb1_var='no'
#
#Spatial Metadata Datalist
sm_dlist=manual_dir+'/software/gridding/'+basename+'_spatial_meta.datalist'
name_cell_extents_sm=manual_dir+'/software/gridding/'+basename+'_name_cell_extents_sm.csv'
sm_res='0.3333333333s'
#
#Conversion Grid Variables
ivert='mllw'
overt='navd88'
conv_grd_name='cgrid_'+ivert+'2'+overt
conv_grd_path=data_dir+'/conv_grd/'+conv_grd_name+".tif"
conv_grd_path_cgvd2navd=manual_dir+'/data/conv_grd/cgvd2navd.tif'
#
#Manual Data Variables
#
#path to border dems to use in final formatting to ensure seamlessness
#manually place other NCEI tifs that aren't yet on Digital Coast
ncei_border_dems_path=manual_dir+'/data/grids/ncei/'
ncei_border_dems_csv=ncei_border_dems_path+'ncei_dems_download_process.csv'
resamp_res=0.00003086420
#Lidar Download Variables
dc_lidar_csv=manual_dir+'/data/dc_lidar/dc_lidar_download_process.csv'
tnm_lidar_man_path=manual_dir+'/data/topo/tnm_lidar/'
tnm_lidar_csv=tnm_lidar_man_path+'tnm_lidar_download_process.csv'
canada_lidar_csv=manual_dir+'/data/topo/canada/canada_lidar_download_process.csv'
#
#################################################################
###################### REGION OF INTEREST #######################
#################################################################
west_buff=-71.80
east_buff=-66.70
south_buff=40.70
north_buff=45.30
roi_str_gmt=str(west_buff)+'/'+str(east_buff)+'/'+str(south_buff)+'/'+str(north_buff)
roi_str_ogr=str(west_buff)+' '+str(south_buff)+' '+str(east_buff)+' '+str(north_buff)

#print roi_str_gmt
roi_str_gmt='-71.80/-66.70/40.70/45.30'

#test areas here
# west_buff=-97.3
# east_buff=-96.95
# south_buff=27.7
# north_buff=28.05
# roi_str_gmt=str(west_buff)+'/'+str(east_buff)+'/'+str(south_buff)+'/'+str(north_buff)
# roi_str_ogr=str(west_buff)+' '+str(south_buff)+' '+str(east_buff)+' '+str(north_buff)

#study area with buffer
study_area_shp=manual_dir+'/data/study_area/'+basename+'_tiles_buff.shp'

#################################################################
#################################################################
#################################################################
###################### DIRECTORY MGMT ###########################
#################################################################
#################################################################
#################################################################
#Creating main directories
main_dir_list=[code_dir,data_dir,docs_dir,manual_dir,software_dir]
for i in main_dir_list:
	if not os.path.exists(i):
		print 'creating subdir', i
		os.makedirs(i)

#Creating main data subdirectories
data_dir_list=[data_dir+'/bathy',data_dir+'/coast',data_dir+'/conv_grd',data_dir+'/dc_lidar',data_dir+'/topo/tnm_lidar',data_dir+'/topo/canada_lidar',data_dir+'/grids/ncei']
for i in data_dir_list:
	if not os.path.exists(i):
		print 'creating subdir', i
		os.makedirs(i)

#Creating main bathy data subdirectories
bathy_dir_list=[data_dir+'/bathy/usace_dredge',data_dir+'/bathy/usace_dredge_reinterp', data_dir+'/bathy/mb', data_dir+'/bathy/nos', data_dir+'/bathy/enc', data_dir+'/bathy/bathy_surf']
for i in bathy_dir_list:
	if not os.path.exists(i):
		print 'creating subdir', i
		os.makedirs(i)

#Creating main docs subdirectories
docs_dir_list=[docs_dir+'/resources',docs_dir+'/report']
for i in docs_dir_list:
	if not os.path.exists(i):
		print 'creating subdir', i
		os.makedirs(i)

#Creating main manual subdirectories
manual_dir_list=[manual_dir+'/data/coast',manual_dir+'/data/study_area']
for i in manual_dir_list:
	if not os.path.exists(i):
		print 'creating subdir', i
		os.makedirs(i)

#Creating main software subdirectories
software_dir_list=[software_dir+'/gridding',software_dir+'/gridding/tifs',software_dir+'/gridding/tifs/smoothed',software_dir+'/gridding/tifs/smoothed/deliverables',software_dir+'/gridding/tifs/smoothed/deliverables/thredds',software_dir+'/gridding/tifs/smoothed/deliverables/spatial_meta']
for i in software_dir_list:
	if not os.path.exists(i):
		print 'creating subdir', i
		os.makedirs(i)

#################################################################
#################################################################
#################################################################
###################### MASTER DATALISTS #########################
#################################################################
#################################################################
#################################################################
#Create Empty Bathy Surface and DEM Master datalists if they don't exist
#Add topo guide to bathy surface datalist
create_bs_dlist='''if [ ! -e {} ] ; 
then touch {}
echo {} -1 0.01 >> {}
fi'''.format(bs_dlist,bs_dlist,bs_topo_guide_dlist,bs_dlist)
os.system(create_bs_dlist)

create_dem_dlist='''if [ ! -e {} ] ; 
then touch {}
echo {} -1 0.000001 >> {}
fi'''.format(dem_dlist,dem_dlist,bs_ind_dlist,dem_dlist)
os.system(create_dem_dlist)

#Spatial Metadata
#At the end, manually populate spatial metadata master datalist
create_sm_dlist='''if [ ! -e {} ] ; 
then touch {}
fi'''.format(sm_dlist,sm_dlist)
os.system(create_sm_dlist)

#################################################################
#################################################################
#################################################################
###################### NAME CELL EXTENTS ########################
#################################################################
#################################################################
#################################################################
#Copy Name Cell Extents from Manual Directories
#delete csv if it exists
os.system('[ -e {} ] && rm {}'.format(name_cell_extents_bs,name_cell_extents_bs))
# copy csv from manual dir
os.system('cp {} {}'.format(manual_name_cell_extents_bs,name_cell_extents_bs)) 

#delete csv if it exists
os.system('[ -e {} ] && rm {}'.format(name_cell_extents_dem,name_cell_extents_dem))
# copy csv from manual dir
os.system('cp {} {}'.format(manual_name_cell_extents_dem,name_cell_extents_dem)) 

#delete csv if it exists
os.system('[ -e {} ] && rm {}'.format(name_cell_extents_dem_all,name_cell_extents_dem_all))
# copy csv from manual dir
os.system('cp {} {}'.format(manual_name_cell_extents_dem_all,name_cell_extents_dem_all)) 

#################################################################
#################################################################
#################################################################
####################### CONVERSION GRID #########################
#################################################################
#################################################################
#################################################################
#Create Conversion Grid -- MLLW to NAVD88
if conv_grd_process=='yes':
	os.system('cd')
	os.chdir(data_dir+'/conv_grd')
	print "Creating mllw2navd88 conversion grid"
	conv_grd_cmd='waffles -M vdatum:ivert=mllw:overt=navd88:region=3 -R {} -E 1s -P 4269 -O {} --verbose'.format(roi_str_gmt,conv_grd_name)
	print conv_grd_cmd
	os.system(conv_grd_cmd)
else:
	print "Skipping Conversion Grid Processing"

#################################################################
#################################################################
#################################################################
####################### DATA DOWNLOAD ###########################
#################################################################
#################################################################
#################################################################

#################################################################
####################### STUDY AREA ##############################
#################################################################
#manually created shp in Global Mapper / ArcGIS (tx_w_la_tiles.shp) 
#created name_cell_extents with arcpy get_poly_coords.py (name_cell_extents_bs.csv; name_cell_extents_DEM.csv) 
#manually created study area buffer in ArcMap (s_tx_tiles_buff.shp)
#manually created outer buffer to grab adjacent NCEI tiles DEMs (s_tx_tiles_buff_outer.shp) using arcmap erase(s_tx_tiles_buff.shp,s_tx_tiles.shp)
#
#This could all be automated in ogr?
#
##################################################################
######################### COASTLINE ##############################
##################################################################
if coast_process=='yes':
	os.chdir(data_dir+'/coast')
	print 'Current Directory is', os.getcwd()

	####### CODE MANAGEMENT ########
	#delete python script if it exists
	os.system('[ -e coast_processing.py ] && rm coast_processing.py')
	# copy python script from DEM_generation code
	os.system('cp {}/coast_processing.py coast_processing.py'.format(code_dir)) 

	print "executing coast_processing script"
	os.system('./coast_processing.py {} {} {} {} {} {} {}'.format(basename,main_dir,west_buff,east_buff,south_buff,north_buff,study_area_shp))
else:
	print "Skipping Coastline Processing"

##################################################################
########################### BATHY ################################
##################################################################
######################## USACE DREDGE ############################
##################################################################
if usace_dredge_process=='yes':
	os.system('cd')
	os.chdir(data_dir+'/bathy/usace_dredge')
	print 'Current Directory is', os.getcwd()
	
	####### CODE MANAGEMENT #########
	os.system('mkdir -p zip')
	os.system('mkdir -p gdb')
	os.system('mkdir -p csv')
	os.system('mkdir -p xyz')
	os.system('mkdir -p xyz/navd88')
	os.system('mkdir -p xyz/navd88/interp')

	#delete python script if it exists
	os.system('[ -e usace_dredge_processing.py ] && rm usace_dredge_processing.py')
	#copy python script from DEM_generation code
	os.system('cp {}/usace_dredge_processing.py usace_dredge_processing.py'.format(code_dir)) 

	#delete shell script if it exists
	os.system('[ -e csv/usace_ft2m.sh ] && rm csv/usace_ft2m.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/usace_ft2m.sh csv/usace_ft2m.sh'.format(code_dir)) 

	#delete shell script if it exists
	os.system('[ -e xyz/vert_conv.sh ] && rm xyz/vert_conv.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/vert_conv.sh xyz/vert_conv.sh'.format(code_dir)) 

	#delete shell script if it exists
	os.system('[ -e xyz/gdal_query.py ] && rm xyz/gdal_query.py')
	#copy sh script from DEM_generation code
	os.system('cp {}/gdal_query.py xyz/gdal_query.py'.format(code_dir)) 

	#delete shell script if it exists
	os.system('[ -e xyz/navd88/create_datalist.sh ] && rm xyz/navd88/create_datalist.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/create_datalist.sh xyz/navd88/create_datalist.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e xyz/navd88/usace_interp.sh ] && rm xyz/navd88/usace_interp.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/usace_interp.sh xyz/navd88/usace_interp.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e xyz/navd88/interp/create_datalist.sh ] && rm xyz/navd88/interp/create_datalist.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/create_datalist.sh xyz/navd88/interp/create_datalist.sh'.format(code_dir)) 

	print "executing usace_dredge_processing script"
	os.system('./usace_dredge_processing.py {} {} {} {} {} {}'.format(study_area_shp, conv_grd_path, bs_dlist, dem_dlist, lastools_dir, coast_shp))
else:
	print "Skipping USACE Dredge Processing"


####### REINTERP New Surveys with parameter to better create shp
if usace_dredge_process_reinterp=='yes':
	os.system('cd')
	os.chdir(data_dir+'/bathy/usace_dredge_reinterp')
	print 'Current Directory is', os.getcwd()
	
	####### CODE MANAGEMENT #########
	os.system('mkdir -p zip')
	os.system('mkdir -p gdb')
	os.system('mkdir -p csv')
	os.system('mkdir -p xyz')
	os.system('mkdir -p xyz/navd88')
	os.system('mkdir -p xyz/navd88/interp')

	#delete python script if it exists
	os.system('[ -e usace_dredge_processing_reinterp.py ] && rm usace_dredge_processing_reinterp.py')
	#copy python script from DEM_generation code
	os.system('cp {}/usace_dredge_processing_reinterp.py usace_dredge_processing_reinterp.py'.format(code_dir)) 

	#delete shell script if it exists
	os.system('[ -e csv/usace_ft2m.sh ] && rm csv/usace_ft2m.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/usace_ft2m.sh csv/usace_ft2m.sh'.format(code_dir)) 

	#delete shell script if it exists
	os.system('[ -e xyz/vert_conv.sh ] && rm xyz/vert_conv.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/vert_conv.sh xyz/vert_conv.sh'.format(code_dir)) 

	#delete shell script if it exists
	os.system('[ -e xyz/gdal_query.py ] && rm xyz/gdal_query.py')
	#copy sh script from DEM_generation code
	os.system('cp {}/gdal_query.py xyz/gdal_query.py'.format(code_dir)) 

	#delete shell script if it exists
	os.system('[ -e xyz/navd88/create_datalist.sh ] && rm xyz/navd88/create_datalist.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/create_datalist.sh xyz/navd88/create_datalist.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e xyz/navd88/usace_interp_reinterp.sh ] && rm xyz/navd88/usace_interp_reinterp.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/usace_interp_reinterp.sh xyz/navd88/usace_interp_reinterp.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e xyz/navd88/interp/create_datalist.sh ] && rm xyz/navd88/interp/create_datalist.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/create_datalist.sh xyz/navd88/interp/create_datalist.sh'.format(code_dir)) 

	print "executing usace_dredge_processing script"
	os.system('./usace_dredge_processing_reinterp.py {} {} {} {} {} {}'.format(study_area_shp, conv_grd_path, bs_dlist, dem_dlist, lastools_dir, coast_shp))
else:
	print "Skipping USACE Dredge Processing REINTERP"



######################### Multibeam #############################
if mb_process=='yes':
	os.system('cd')
	os.chdir(data_dir+'/bathy/mb')
	print 'Current Directory is', os.getcwd()
	
	######### CODE MANAGEMENT #########
	os.system('mkdir -p xyz')
	
	#delete python script if it exists
	os.system('[ -e mb_processing.py ] && rm mb_processing.py')
	#copy python script from DEM_generation code
	os.system('cp {}/mb_processing.py mb_processing.py'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e download_mb_roi.sh ] && rm download_mb_roi.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/download_mb_roi.sh download_mb_roi.sh'.format(code_dir)) 

	#delete shell script if it exists
	os.system('[ -e xyz/create_datalist.sh ] && rm xyz/create_datalist.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/create_datalist.sh xyz/create_datalist.sh'.format(code_dir)) 
	######## CODE MANAGEMENT #########
	#sys.exit()
	print "executing mb_processing script"
	os.system('./mb_processing.py {} {} {}'.format(study_area_shp, roi_str_gmt, bs_dlist))
	####
else:
	print "Skipping MB Processing"
# ########################## NOS/BAG ################################
if nos_process=='yes':
	os.system('cd')
	os.chdir(data_dir+'/bathy/nos')
	print 'Current Directory is', os.getcwd()
	
	######### CODE MANAGEMENT #########
	os.system('mkdir -p nos_hydro')
	os.system('mkdir -p nos_hydro/xyz')
	os.system('mkdir -p nos_hydro/xyz/neg_m')
	os.system('mkdir -p nos_hydro/xyz/neg_m/navd88')
	os.system('mkdir -p nos_bag')
	os.system('mkdir -p nos_bag/xyz')
	os.system('mkdir -p nos_bag/xyz/navd88')

	#delete python script if it exists
	os.system('[ -e nos_processing.py ] && rm nos_processing.py')
	#copy python script from DEM_generation code
	os.system('cp {}/nos_processing.py nos_processing.py'.format(code_dir)) 

	#NOS HYDRO
	#delete shell script if it exists
	os.system('[ -e nos_hydro/xyz/nos2xyz.sh ] && rm nos_hydro/xyz/nos2xyz.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/nos2xyz.sh nos_hydro/xyz/nos2xyz.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e nos_hydro/xyz/neg_m/vert_conv.sh ] && rm nos_hydro/xyz/neg_m/vert_conv.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/vert_conv.sh nos_hydro/xyz/neg_m/vert_conv.sh'.format(code_dir)) 

	#delete shell script if it exists
	os.system('[ -e nos_hydro/xyz/neg_m/gdal_query.py ] && rm nos_hydro/xyz/neg_m/gdal_query.py')
	#copy sh script from DEM_generation code
	os.system('cp {}/gdal_query.py nos_hydro/xyz/neg_m/gdal_query.py'.format(code_dir)) 

	#delete shell script if it exists
	os.system('[ -e nos_hydro/xyz/neg_m/navd88/create_datalist.sh ] && rm nos_hydro/xyz/neg_m/navd88/create_datalist.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/create_datalist.sh nos_hydro/xyz/neg_m/navd88/create_datalist.sh'.format(code_dir)) 

	#NOS BAG
	#delete shell script if it exists
	os.system('[ -e nos_bag/bag2tif2chunks2xyz.sh ] && rm nos_bag/bag2tif2chunks2xyz.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/bag2tif2chunks2xyz.sh nos_bag/bag2tif2chunks2xyz.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e nos_bag/xyz/vert_conv.sh ] && rm nos_bag/xyz/vert_conv.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/vert_conv.sh nos_bag/xyz/vert_conv.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e nos_bag/xyz/gdal_query.py ] && rm nos_bag/xyz/gdal_query.py')
	#copy sh script from DEM_generation code
	os.system('cp {}/gdal_query.py nos_bag/xyz/gdal_query.py'.format(code_dir)) 

	#delete shell script if it exists
	os.system('[ -e nos_bag/xyz/navd88/create_datalist.sh ] && rm nos_bag/xyz/navd88/create_datalist.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/create_datalist.sh nos_bag/xyz/navd88/create_datalist.sh'.format(code_dir))

	print "executing nos_processing script"
	os.system('./nos_processing.py {} {} {} {}'.format(study_area_shp, conv_grd_path, bs_dlist, dem_dlist))
else:
	print "Skipping NOS Processing"
# ########################## ENC ################################
if enc_process=='yes':
	os.system('cd')
	os.chdir(data_dir+'/bathy/enc')
	print 'Current Directory is', os.getcwd()

	######### CODE MANAGEMENT #########
	os.system('mkdir -p charts')
	os.system('mkdir -p charts/navd88')


	#delete python script if it exists
	os.system('[ -e enc_processing.py ] && rm enc_processing.py')
	#copy python script from DEM_generation code
	os.system('cp {}/enc_processing.py enc_processing.py'.format(code_dir)) 

	# #delete shell script if it exists
	# os.system('[ -e xyz/pos2neg.sh ] && rm xyz/pos2neg.sh')
	# #copy sh script from DEM_generation code
	# os.system('cp {}/pos2neg.sh xyz/pos2neg.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e charts/vert_conv.sh ] && rm charts/vert_conv.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/vert_conv.sh charts/vert_conv.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e charts/gdal_query.py ] && rm charts/gdal_query.py')
	#copy sh script from DEM_generation code
	os.system('cp {}/gdal_query.py charts/gdal_query.py'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e charts/navd88/create_datalist.sh ] && rm charts/navd88/create_datalist.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/create_datalist.sh charts/navd88/create_datalist.sh'.format(code_dir))

	print "executing enc_processing script"
	os.system('./enc_processing.py {} {} {}'.format(study_area_shp, conv_grd_path, bs_dlist))
else:
	print "Skipping ENC Processing"
#############################################################
################## DIGITAL COAST LIDAR ######################
#############################################################
if dc_lidar_process=='yes':
	os.system('cd')
	os.chdir(data_dir+'/dc_lidar')
	print 'Current Directory is', os.getcwd()
	
	######### CODE MANAGEMENT #########

	#delete shell script if it exists
	os.system('[ -e download_process_lidar.sh ] && rm download_process_lidar.sh')
	#copy shell script from DEM_generation code
	os.system('cp {}/download_process_lidar.sh download_process_lidar.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e laz2xyz.sh ] && rm laz2xyz.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/laz2xyz.sh laz2xyz.sh'.format(code_dir)) 

	os.system('[ -e separate_pos_neg.sh ] && rm separate_pos_neg.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/separate_pos_neg.sh separate_pos_neg.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e create_datalist.sh ] && rm create_datalist.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/create_datalist.sh create_datalist.sh'.format(code_dir)) 

	print "executing dc_lidar_processing script"
	os.system('./download_process_lidar.sh {} {} {} {}'.format(dc_lidar_csv,study_area_shp,bs_dlist,dem_dlist))
	####
else:
	print "Skipping DC Lidar Processing"

#############################################################
################## Canada LIDAR #############################
#############################################################
if canada_lidar_process=='yes':
	os.system('cd')
	os.chdir(data_dir+'/topo/canada_lidar')
	print 'Current Directory is', os.getcwd()
	
	######### CODE MANAGEMENT #########

	#delete shell script if it exists
	os.system('[ -e download_process_lidar_canada.sh ] && rm download_process_lidar_canada.sh')
	#copy shell script from DEM_generation code
	os.system('cp {}/download_process_lidar_canada.sh download_process_lidar_canada.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e laz2xyz_repro_latlon_m.sh ] && rm laz2xyz_repro_latlon_m.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/laz2xyz_repro_latlon_m.sh laz2xyz_repro_latlon_m.sh'.format(code_dir)) 

	#delete shell script if it exists
	os.system('[ -e vert_conv.sh ] && rm vert_conv.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/vert_conv.sh vert_conv.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e gdal_query.py ] && rm gdal_query.py')
	#copy sh script from DEM_generation code
	os.system('cp {}/gdal_query.py gdal_query.py'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e create_datalist.sh ] && rm create_datalist.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/create_datalist.sh create_datalist.sh'.format(code_dir)) 

	print "executing canada_lidar_processing script"
	os.system('./download_process_lidar_canada.sh {} {} {} {}'.format(canada_lidar_csv,study_area_shp,dem_dlist,conv_grd_path_cgvd2navd))
	####
else:
	print "Skipping Canada Lidar Processing"
#############################################################
################## TNM LIDAR ################################
#############################################################
if tnm_lidar_process=='yes':
	os.system('cd')
	os.chdir(data_dir+'/topo/tnm_lidar')
	print 'Current Directory is', os.getcwd()
	
	######### CODE MANAGEMENT #########

	#delete shell script if it exists
	os.system('[ -e tnm_download_process_lidar.sh ] && rm tnm_download_process_lidar.sh')
	#copy shell script from DEM_generation code
	os.system('cp {}/tnm_download_process_lidar.sh tnm_download_process_lidar.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e laz2xyz_repro_latlon_m.sh ] && laz2xyz_repro_latlon_m.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/laz2xyz_repro_latlon_m.sh laz2xyz_repro_latlon_m.sh'.format(code_dir)) 

	os.system('[ -e separate_pos_neg.sh ] && rm separate_pos_neg.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/separate_pos_neg.sh separate_pos_neg.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e create_datalist.sh ] && rm create_datalist.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/create_datalist.sh create_datalist.sh'.format(code_dir)) 

	print "executing tnm_lidar_processing script"
	os.system('./tnm_download_process_lidar.sh {} {} {} {}'.format(tnm_lidar_man_path,tnm_lidar_csv,bs_dlist,dem_dlist))
	####
else:
	print "Skipping TNM Lidar Processing"

#############################################################
################## NCEI DEMS ################################
#############################################################
# NOTE: THIS COMPONENT IS NOT YET IMPLEMENTED/TESTED
# Waiting on Stiller DEMs to be complete
#
if ncei_dems_process=='yes':
	os.system('cd')
	os.chdir(data_dir+'/grids/ncei')
	print 'Current Directory is', os.getcwd()
	
	######### CODE MANAGEMENT #########
	#delete shell script if it exists
	os.system('[ -e download_process_ncei_dems.sh ] && rm download_process_ncei_dems.sh')
	#copy shell script from DEM_generation code
	os.system('cp {}/download_process_ncei_dems.sh download_process_ncei_dems.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e tif2chunks2xyz.sh ] && rm tif2chunks2xyz.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/tif2chunks2xyz.sh tif2chunks2xyz.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e create_datalist.sh ] && rm create_datalist.sh')
	#copy sh script from DEM_generation code
	os.system('cp {}/create_datalist.sh create_datalist.sh'.format(code_dir))

	print "executing NCEI DEMs processing script"
	os.system('./download_process_ncei_dems.sh {} {} {} {} {} {}'.format(ncei_border_dems_path,ncei_border_dems_csv,study_area_buff_outer_shp,resamp_res,bs_dlist,dem_dlist))
	####
else:
	print "Skipping NCEI DEM Processing"


###################################################################
###################################################################
###################################################################
######################### TOPO GUIDE BATHY SURFACE ###########################
###################################################################
###################################################################
###################################################################
if topo_guide_process=='yes':
	os.system('cd')
	os.chdir(data_dir+'/bathy/bathy_surf')
	print 'Current Directory is', os.getcwd()
	
	######### CODE MANAGEMENT #########

	#delete shell script if it exists
	os.system('[ -e create_topo_guide.sh ] && rm create_topo_guide.sh')
	#copy shell script from DEM_generation code
	os.system('cp {}/create_topo_guide.sh create_topo_guide.sh'.format(code_dir))

	print "executing create_topo_guide.sh script"
	os.system('./create_topo_guide.sh {} {}'.format(name_cell_extents_bs,coast_shp))
	####
else:
	print "Skipping Topo Guide Bathy Surface Processing"

###################################################################
###################################################################
###################################################################
######################### BATHY SURFACE ###########################
###################################################################
###################################################################
###################################################################
if bathy_surf_process=='yes':
	os.system('cd')
	os.chdir(data_dir+'/bathy/bathy_surf')
	print 'Current Directory is', os.getcwd()
	
	######### CODE MANAGEMENT #########

	#delete shell script if it exists
	os.system('[ -e create_bs.sh ] && rm create_bs.sh')
	#copy shell script from DEM_generation code
	os.system('cp {}/create_bs.sh create_bs.sh'.format(code_dir))

	print "executing create_bs.sh script"
	os.system('./create_bs.sh {} {} {} {}'.format(name_cell_extents_bs,bs_dlist,coast_shp,bs_mb1_var))
	####
else:
	print "Skipping Bathy Surface Processing"

####################################################################
####################################################################
####################################################################
########################## DEM GENERATION ##########################
####################################################################
####################################################################
####################################################################
if dem_process=='yes':
	os.system('cd')
	os.chdir(software_dir+'/gridding')
	print 'Current Directory is', os.getcwd()
	
	######### CODE MANAGEMENT #########

	#delete shell script if it exists
	os.system('[ -e create_dem.sh ] && rm create_dem.sh')
	#copy shell script from DEM_generation code
	os.system('cp {}/create_dem.sh create_dem.sh'.format(code_dir))

	#delete py script if it exists
	os.system('[ -e smooth_dem_bathy.py ] && rm smooth_dem_bathy.py')
	#copy py script from DEM_generation code
	os.system('cp {}/smooth_dem_bathy.py smooth_dem_bathy.py'.format(code_dir))

	#delete py script if it exists
	os.system('[ -e percentiles_minmax.py ] && rm percentiles_minmax.py')
	#copy py script from DEM_generation code
	os.system('cp {}/percentiles_minmax.py percentiles_minmax.py'.format(code_dir))

	#delete py script if it exists
	os.system('[ -e minmax.py ] && rm minmax.py')
	#copy py script from DEM_generation code
	os.system('cp {}/minmax.py minmax.py'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e outliers_shp.sh ] && rm outliers_shp.sh')
	#copy shell script from DEM_generation code
	os.system('cp {}/outliers_shp.sh outliers_shp.sh'.format(code_dir))

	print "executing create_dem.sh script"
	os.system('./create_dem.sh {} {} {} {}'.format(name_cell_extents_dem,dem_dlist,dem_smooth_factor,dem_mb1_var))
	####
else:
	print "Skipping DEM Processing"

####################################################################
####################################################################
####################################################################
########################## SPATIAL METADATA ########################
####################################################################
####################################################################
####################################################################
if spatial_meta_process=='yes':
	os.system('cd')
	os.chdir(software_dir+'/gridding/tifs/smoothed/deliverables/spatial_meta')
	print 'Current Directory is', os.getcwd()
	
	######### CODE MANAGEMENT #########
	#delete shell script if it exists
	os.system('[ -e create_spatial_meta.sh ] && rm create_spatial_meta.sh')
	#copy shell script from DEM_generation code
	os.system('cp {}/create_spatial_meta.sh create_spatial_meta.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e update_tile_version_sm.sh ] && rm update_tile_version_sm.sh')
	#copy shell script from DEM_generation code
	os.system('cp {}/update_tile_version_sm.sh update_tile_version_sm.sh'.format(code_dir))

	print "executing create_spatial_meta.sh script"
	os.system('./create_spatial_meta.sh {} {} {} {} {}'.format(name_cell_extents_sm,sm_dlist,sm_res,year,version))
	####

else:
	print "Skipping Spatial Metadata Generation"


####################################################################
####################################################################
####################################################################
########################## FINAL DEM FORMATTING ####################
####################################################################
####################################################################
####################################################################
if final_dem_format_process=='yes':
	os.system('cd')
	os.chdir(software_dir+'/gridding/tifs/smoothed')
	print 'Current Directory is', os.getcwd()
	
	######### CODE MANAGEMENT #########

	#delete shell script if it exists
	os.system('[ -e final_dem_format.sh ] && rm final_dem_format.sh')
	#copy shell script from DEM_generation code
	os.system('cp {}/final_dem_format.sh final_dem_format.sh'.format(code_dir))

	#delete shell script if it exists
	os.system('[ -e update_tile_version.sh ] && rm update_tile_version.sh')
	#copy shell script from DEM_generation code
	os.system('cp {}/update_tile_version.sh update_tile_version.sh'.format(code_dir))

	#delete py script if it exists
	os.system('[ -e resample.py ] && rm resample.py')
	#copy py script from DEM_generation code
	os.system('cp {}/resample.py resample.py'.format(code_dir))

	#delete py script if it exists
	os.system('[ -e average_tifs.py ] && rm average_tifs.py')
	#copy py script from DEM_generation code
	os.system('cp {}/average_tifs.py average_tifs.py'.format(code_dir))

	#delete py script if it exists
	os.system('[ -e /deliverables/minmax.py ] && rm /deliverables/minmax.py')
	#copy py script from DEM_generation code
	os.system('cp {}/minmax.py {}/gridding/tifs/smoothed/deliverables/minmax.py'.format(code_dir,software_dir))

	print "executing final_dem_format.sh script"
	os.system('./final_dem_format.sh {} {} {} {} {}'.format(name_cell_extents_dem_all,dem_smooth_factor,year,version,ncei_border_dems_path))
	####
else:
	print "Skipping DEM Formatting Processing"
