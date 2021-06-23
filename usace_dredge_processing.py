#!/usr/bin/python
'''
Description:
Process USACE Dredge Surveys downloaded with fetch.
-Convert all gdb to shapefile, reproject to nad83, and convert pos ft to neg m
-First try creating it from SurveyPoint_HD, if that doesn't exist, use SurveyPoint.
-If SurveyPoint doesn't exist, print name to text file to investigate

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
import subprocess
import sys
import glob
######################## USACE DREDGE ###########################
study_area_shp=sys.argv[1]
conv_grd_path=sys.argv[2]
bs_dlist=sys.argv[3]
dem_dlist=sys.argv[4]
lastools_dir=sys.argv[5]
coast_shp=sys.argv[6]
coast_shp='/media/sf_F_win_lx/COASTAL_Act/camante/ne/auto/data/ne_landsat/landsat_all_NA'

print conv_grd_path

print "Current directory is ", os.getcwd()
print 'Downloading USACE Channel Surveys'
usace_download_cmd='''fetches -R {} usace -u'''.format(study_area_shp)
print "Command is", usace_download_cmd
os.system(usace_download_cmd)

print "moving zip files to directory"
move_zip_cmd="find . -name '*.ZIP' -exec mv {} zip/ \; 2>/dev/null"
os.system(move_zip_cmd)

print "unzipping all zip files"
os.chdir('zip')
unzip_cmd='unzip -o "*.ZIP"'
os.system(unzip_cmd)

os.chdir('..')

print "moving gdb files to directory"
print "Current directory is ", os.getcwd()
move_gdb_cmd="find . -name '*.gdb' -exec mv {} gdb/ \; 2>/dev/null"
os.system(move_gdb_cmd)

os.chdir('gdb')

for i in glob.glob('*gdb'):
	print "Processing File", i
	gdb_basename = i[:-4]
	print "gdb_basename is", gdb_basename
	print "Current directory is ", os.getcwd()
	#create SurveyPoint_HD or SurveyPoint shp
	try:
		create_usace_shp_cmd = 'ogr2ogr -f "ESRI Shapefile" {} {} SurveyPoint_HD -overwrite'.format(gdb_basename, i)
		subprocess.check_call(create_usace_shp_cmd, shell=True)
		print "Created SurveyPoint_HD Shp"
		os.chdir(gdb_basename)
		sp2nad83_cmd ='ogr2ogr -f "ESRI Shapefile" -t_srs EPSG:4269 {}_nad83.shp SurveyPoint_HD.shp'.format(gdb_basename)
		subprocess.call(sp2nad83_cmd, shell=True)
		print "Created NAD83 Shp"
		shp2csv_cmd = 'ogr2ogr -f "CSV" {}_nad83_mllw.csv {}_nad83.shp -lco GEOMETRY=AS_XY -select "Z_depth"'.format(gdb_basename,gdb_basename)
		subprocess.call(shp2csv_cmd, shell=True)
		print "Created CSV"
		os.chdir('..')
		hd_txt_cmd='echo "{}" >> gdb_surveypoints_HD.txt'.format(gdb_basename)
		subprocess.call(hd_txt_cmd, shell=True)
	except subprocess.CalledProcessError:
		print "No HD"
		try:
			create_usace_shp_cmd = 'ogr2ogr -f "ESRI Shapefile" {} {} SurveyPoint -overwrite'.format(gdb_basename, i)
			subprocess.check_call(create_usace_shp_cmd, shell=True)
			print "Created SurveyPoint Shp"
			os.chdir(gdb_basename)
			sp2nad83_cmd ='ogr2ogr -f "ESRI Shapefile" -t_srs EPSG:4269 {}_nad83.shp SurveyPoint.shp'.format(gdb_basename)
			subprocess.call(sp2nad83_cmd, shell=True)
			print "Created NAD83 Shp"
			shp2csv_cmd = 'ogr2ogr -f "CSV" {}_nad83_mllw.csv {}_nad83.shp -lco GEOMETRY=AS_XY -select "Z_depth"'.format(gdb_basename,gdb_basename)
			subprocess.call(shp2csv_cmd, shell=True)
			print "Created CSV"
			os.chdir('..')
			no_hd_txt_cmd='echo "{}" >> gdb_surveypoints_no_HD.txt'.format(gdb_basename)
			subprocess.call(no_hd_txt_cmd, shell=True)
		except subprocess.CalledProcessError:
			print "No Surveys"
			no_surveys_cmd='echo "{}" >> gdb_no_surveys.txt'.format(gdb_basename)
			subprocess.call(no_surveys_cmd, shell=True)
os.chdir('..')

print "moving csv files to directory"
move_csv_cmd="find . -name '*_nad83_mllw.csv' -exec mv {} csv/ \; 2>/dev/null"
os.system(move_csv_cmd)

print "Deleting gdb directories"
#os.system('''rm -rf zip''')
os.system('''rm -rf gdb''')

#most survey are in feet, positive down. But a few are negative.
#Calculate median depth. If positive, convert to negative.
print "Converting pos2neg if necessary, ft2m, and removing header"
os.chdir('csv')
ft2m_cmd = './usace_ft2m.sh .csv ,'
os.system(ft2m_cmd)

print "moving xyz files to xyz dir"
os.chdir('..')
move_xyz_cmd="find . -name '*_nad83_mllw_neg_m.xyz' -exec mv {} xyz/ \; 2>/dev/null"
os.system(move_xyz_cmd)

print "Converting xyz from mllw to navd88"
os.chdir('xyz')
usace_vert_conv_cmd='./vert_conv.sh '+ conv_grd_path + ' navd88'
os.system(usace_vert_conv_cmd)

print "Creating datalist"
os.chdir('navd88')
usace_datalist_cmd='./create_datalist.sh usace_dredge'
os.system(usace_datalist_cmd)

#print "Copying xyzs and infs to original USACE directory"
#just manually do this for now

current_dir=os.getcwd()
add_to_bmaster_cmd='echo ' + current_dir + '/usace_dredge.datalist -1 10 >> ' + bs_dlist
os.system(add_to_bmaster_cmd)

add_to_master_cmd='echo ' + current_dir + '/usace_dredge.datalist -1 10 >> ' + dem_dlist
os.system(add_to_master_cmd)

print "Creating Interpolated Points between Surveys" 
#./usace_interp.sh /media/sf_C_win_lx/software/LAStools/bin 0.015 0.00009259259 0.00003086420 20 5
#./usace_interp.sh /media/sf_C_win_lx/software/LAStools/bin 0.015 0.00009259259 0.00003086420 20 5 tx_w_la_coast
#./usace_interp.sh /media/sf_C_win_lx/software/LAStools/bin 0.015 0.00009259259 0.00003086420 20 5 /media/sf_F_win_lx/COASTAL_Act/camante/tx_w_la/data/coast/tx_w_la_coast
#./usace_interp.sh /media/sf_C_win_lx/software/LAStools/bin 0.015 0.00009259259 0.00003086420 /media/sf_F_win_lx/COASTAL_Act/camante/tx_w_la/data/coast/tx_w_la_coast
usace_interp_cmd='./usace_interp.sh ' + lastools_dir + ' 0.001 0.00009259259 0.00003086420 ' + coast_shp
os.system(usace_interp_cmd)

print "Creating datalist"
os.chdir('interp')
usace_interp_datalist_cmd='./create_datalist.sh usace_dredge_interp'
os.system(usace_interp_datalist_cmd)

current_dir=os.getcwd()
add_to_bmaster_cmd2='echo ' + current_dir + '/usace_dredge_interp.datalist -1 1 >> ' + bs_dlist
os.system(add_to_bmaster_cmd2)

add_to_master_cmd2='echo ' + current_dir + '/usace_dredge_interp.datalist -1 0.1 >> ' + dem_dlist
os.system(add_to_master_cmd2)
