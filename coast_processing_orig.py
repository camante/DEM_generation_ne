#!/usr/bin/python
'''
Description:
-Download USGS NHDPlus with fetch
-unzip
-convert gdb to shp Hydrography/NHDArea
-merge shp
-clip landsat derived to study area
-erase nhd areas from landsat derived data

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
roi_str_gmt=str(west_buff)+'/'+str(east_buff)+'/'+str(south_buff)+'/'+str(north_buff)
roi_str_ogr=str(west_buff)+' '+str(south_buff)+' '+str(east_buff)+' '+str(north_buff)
coast_res=0.00003086420

dataset_dir=os.getcwd()
print "Current Directory is ", dataset_dir

#Additional Params:
landsat_shp='/media/sf_C_win_lx/coastal_act/data/coast/landsat_all_NA.shp'

#script removes disconnected rivers by only keep the largest poly (num_nhd_polys=1). 
#If need large disconnected rivers,esp. on tile edges that got cut off, make value higher, e.g. num_nhd_polys=2.
num_nhd_polys='1'

############ ANALYSIS ##################

print "Rasterizing Study Area w Buff"
rast_study_area_cmd = '''gdal_rasterize -tr {} {} -te {} -burn 0 -ot Int16 -co COMPRESS=DEFLATE {} {}_tiles_buff.tif'''.format(coast_res,coast_res,roi_str_ogr,study_area_shp,basename)
os.system(rast_study_area_cmd)

print "Copying Raster to burn Landsat"
cp_cmd = '''cp {}_tiles_buff.tif landsat/{}_landsat.tif'''.format(basename,basename)
os.system(cp_cmd)

print "Copying Raster to burn NHD"
cp_cmd2 = '''cp {}_tiles_buff.tif nhd/{}_nhd.tif'''.format(basename,basename)
os.system(cp_cmd2)

print "Copying Raster to burn clean NHD"
cp_cmd3 = '''cp {}_tiles_buff.tif nhd/{}_nhd_clean.tif'''.format(basename,basename)
os.system(cp_cmd3)

########### LANDSAT ##################
os.chdir('landsat')

print 'Clipping Landsat Shp to Study Area'
clip_landsat_cmd='''ogr2ogr -clipsrc {} {}_landsat {}'''.format(roi_str_ogr,basename,landsat_shp)
print clip_landsat_cmd
os.system(clip_landsat_cmd)

#move shp to current directory
mv_cmd1='''mv {}/data/coast/landsat/{}_landsat/landsat_all_NA.shp {}/data/coast/landsat/{}_landsat.shp'''.format(main_dir,basename,main_dir,basename) 
os.system(mv_cmd1)

mv_cmd2='''mv {}/data/coast/landsat/{}_landsat/landsat_all_NA.shx {}/data/coast/landsat/{}_landsat.shx'''.format(main_dir,basename,main_dir,basename) 
os.system(mv_cmd2)

mv_cmd3='''mv {}/data/coast/landsat/{}_landsat/landsat_all_NA.dbf {}/data/coast/landsat/{}_landsat.dbf'''.format(main_dir,basename,main_dir,basename) 
os.system(mv_cmd3)

mv_cmd4='''mv {}/data/coast/landsat/{}_landsat/landsat_all_NA.prj {}/data/coast/landsat/{}_landsat.prj'''.format(main_dir,basename,main_dir,basename) 
os.system(mv_cmd4)

print "Rasterizing Landsat Shp"
raster_shp_cmd = '''gdal_rasterize -tr {} {} -te {} -i -burn 1 -l {}_landsat {}_landsat.shp {}_landsat.tif'''.format(coast_res,coast_res,roi_str_ogr,basename,basename,basename)
os.system(raster_shp_cmd)


os.chdir('..')
########### NHD ##################
os.chdir('nhd')

print 'Downloading nhd from USGS'
nhd_download_cmd='''fetches -R {} tnm:ds=6:formats=FileGDB:extent='HU-4 Subregion' '''.format(roi_str_gmt)
print nhd_download_cmd
#sys.exit()
os.system(nhd_download_cmd)

print 'Moving all zip folders to main nhd dir'
move_zip_cmd="find . -name '*.zip*' -exec mv {} zip/ \; 2>/dev/null"
os.system(move_zip_cmd)

print "Unzipping NHD GDB"
os.chdir('zip')
unzip_cmd='unzip -o "*.zip"'
os.system(unzip_cmd)
os.chdir('..')

print "Moving all gdb files to gdb dir"
move_gdb_cmd="find . -name '*.gdb' -exec mv {} gdb/ \; 2>/dev/null"
os.system(move_gdb_cmd)
os.chdir('gdb')

print "Converting NHD GDB to Shapefile"
for i in glob.glob("*gdb"):
	print "Processing File", i
	gdb_basename = i[:-4]
	create_nhd_shp_cmd = 'ogr2ogr -f "ESRI Shapefile" {} {} NHDArea -overwrite'.format(gdb_basename, i)
	os.system(create_nhd_shp_cmd)
	#rename files
	rename_shp_cmd = 'mv {}/NHDArea.shp {}/{}_NHDArea.shp'.format(gdb_basename, gdb_basename, gdb_basename)
	os.system(rename_shp_cmd)
	rename_dbf_cmd = 'mv {}/NHDArea.dbf {}/{}_NHDArea.dbf'.format(gdb_basename, gdb_basename, gdb_basename)
	os.system(rename_dbf_cmd)
	rename_shx_cmd = 'mv {}/NHDArea.shx {}/{}_NHDArea.shx'.format(gdb_basename, gdb_basename, gdb_basename)
	os.system(rename_shx_cmd)
	rename_prj_cmd = 'mv {}/NHDArea.prj {}/{}_NHDArea.prj'.format(gdb_basename, gdb_basename, gdb_basename)
	os.system(rename_prj_cmd)

	create_nhd_shp_cmd2 = 'ogr2ogr -f "ESRI Shapefile" {} {} NHDPlusBurnWaterbody -overwrite'.format(gdb_basename, i)
	os.system(create_nhd_shp_cmd2)
	#rename files
	rename_shp_cmd = 'mv {}/NHDPlusBurnWaterbody.shp {}/{}_NHDPlusBurnWaterbody.shp'.format(gdb_basename, gdb_basename, gdb_basename)
	os.system(rename_shp_cmd)
	rename_dbf_cmd = 'mv {}/NHDPlusBurnWaterbody.dbf {}/{}_NHDPlusBurnWaterbody.dbf'.format(gdb_basename, gdb_basename, gdb_basename)
	os.system(rename_dbf_cmd)
	rename_shx_cmd = 'mv {}/NHDPlusBurnWaterbody.shx {}/{}_NHDPlusBurnWaterbody.shx'.format(gdb_basename, gdb_basename, gdb_basename)
	os.system(rename_shx_cmd)
	rename_prj_cmd = 'mv {}/NHDPlusBurnWaterbody.prj {}/{}_NHDPlusBurnWaterbody.prj'.format(gdb_basename, gdb_basename, gdb_basename)
	os.system(rename_prj_cmd)


print 'Moving all shp files to shp dir'
os.chdir('..')
move_shp_cmd="find . -name '*.shp*' -exec mv {} shp/ \; 2>/dev/null"
os.system(move_shp_cmd)
move_dbf_cmd="find . -name '*.dbf*' -exec mv {} shp/ \; 2>/dev/null"
os.system(move_dbf_cmd)
move_shx_cmd="find . -name '*.shx*' -exec mv {} shp/ \; 2>/dev/null"
os.system(move_shx_cmd)
move_prj_cmd="find . -name '*.prj*' -exec mv {} shp/ \; 2>/dev/null"
os.system(move_prj_cmd)

print "Merging NHD Shapefiles"
os.chdir('shp')
merge_shp_cmd='for f in *.shp; do ogr2ogr -update -append merge/nhdArea_merge.shp $f -f "ESRI Shapefile"; done;'
os.system(merge_shp_cmd)


os.chdir('..')

print "Clipping Merged NHD Shp to Study Area"
clip_nhd_cmd='''ogr2ogr -clipsrc {} {}_nhd.shp shp/merge/nhdArea_merge.shp'''.format(roi_str_ogr,basename)
#ogr2ogr -clipsrc -88.5 30.25 -88.25 30.5 w_fl_nhd_test.shp shp/merge/nhdArea_merge.shp
os.system(clip_nhd_cmd)

print "Rasterizing Shp"
raster_shp_cmd2 = '''gdal_rasterize -tr {} {} -te {} -burn 1 -ot Int16 -co COMPRESS=DEFLATE {}_nhd.shp {}_nhd.tif'''.format(coast_res,coast_res,roi_str_ogr,basename,basename)
#gdal_rasterize -te roi_str_ogr -tr 0.00003086420 0.00003086420 -burn 1 -ot Int16 -co COMPRESS=DEFLATE w_fl_nhd_test.shp w_fl_nhd_test.tif
os.system(raster_shp_cmd2)

print "Polygonizing Raster"
poly_rast_cmd = '''gdal_polygonize.py -8 -f 'ESRI Shapefile' {}_nhd.tif {}_nhd_rast.shp'''.format(basename,basename)
#gdal_polygonize.py -8 -f 'ESRI Shapefile' w_fl_nhd_test.tif w_fl_nhd_rast_test.shp
os.system(poly_rast_cmd)

print "Removing Disconnected Rivers"
rm_polys_cmd = '''ogr2ogr -dialect SQLITE -sql "SELECT * FROM {}_nhd_rast WHERE DN='1' order by ST_AREA(geometry) desc limit {}" {}_nhd_clean.shp {}_nhd_rast.shp'''.format(basename,num_nhd_polys,basename,basename)
#ogr2ogr -dialect SQLITE -sql "SELECT * FROM w_fl_nhd_rast_test WHERE DN='1' order by ST_AREA(geometry) desc limit 2" w_fl_nhd_clean_test.shp w_fl_nhd_rast_test.shp
os.system(rm_polys_cmd)

print "Re-Rasterizing Shp"
raster_shp_cmd = '''gdal_rasterize -tr {} {} -te {} -burn 1 -l {}_nhd_clean {}_nhd_clean.shp {}_nhd_clean.tif'''.format(coast_res,coast_res,roi_str_ogr,basename,basename,basename)
os.system(raster_shp_cmd)

print "Deleting zips and gdb directories"
os.system('''rm -rf zip''')
os.system('''rm -rf gdb''')

os.chdir('..')


############ Combining Coastline Rasters ##################

print "Combining Coastline Rasters"
#add_rasts_cmd = '''gdal_calc.py -A nhd/{}_nhd_clean.tif -B landsat/{}_landsat.tif --outfile={}_coast_sum.tif --calc="A + B" --format=GTiff --overwrite'''.format(basename,basename,basename)
add_rasts_cmd = '''gdal_calc.py -A nhd/{}_nhd_clean.tif -B landsat/{}_landsat.tif --outfile={}_coast_sum.tif --calc="A + B" --format=GTiff --overwrite'''.format(basename,basename,basename)
#gdal_calc.py -A nhd/w_fl_nhd_clean_test.tif -B landsat/w_fl_landsat_test.tif --outfile=w_fl_coast_sum_test.tif --calc="A + B" --format=GTiff --overwrite
os.system(add_rasts_cmd)

print "Reclassifying Rasters"
rc_rast_cmd2 = '''gdal_calc.py -A {}_coast_sum.tif --outfile={}_coast_rc_tmp.tif --calc="1*(A > 0)" --format=GTiff --overwrite'''.format(basename,basename)
#gdal_calc.py -A w_fl_coast_sum_test.tif --outfile=w_fl_coast_rc_test.tif --calc="1*(A > 0)" --format=GTiff --overwrite
os.system(rc_rast_cmd2)

rm_rast_cmd = '''rm {}_coast_sum.tif'''.format(basename)
os.system(rm_rast_cmd)

print "Compressing Tif"
compress_tif_cmd = '''gdal_translate {}_coast_rc_tmp.tif -co "COMPRESS=DEFLATE" -co "TILED=YES" {}_coast_rc.tif'''.format(basename,basename)
os.system(compress_tif_cmd)

rm_rast_cmd2 = '''rm {}_coast_rc_tmp.tif'''.format(basename)
os.system(rm_rast_cmd2)

print "Polygonizing Re-classified Raster"
poly_rc_rast_cmd = "gdal_polygonize.py -8 -f 'ESRI Shapefile' {}_coast_rc.tif {}_coast_all.shp".format(basename,basename)
#gdal_polygonize.py -8 -f 'ESRI Shapefile' w_fl_coast_rc_test.tif w_fl_coast_all_test.shp
os.system(poly_rc_rast_cmd)

print "Removing Bathy Areas"
rm_bathy_cmd = '''ogr2ogr -dialect SQLITE -sql "SELECT * FROM {}_coast_all WHERE DN='0'" {}_coast.shp {}_coast_all.shp'''.format(basename,basename,basename)
#ogr2ogr -dialect SQLITE -sql "SELECT * FROM w_fl_coast_all_test WHERE DN='0'" w_fl_coast_test.shp w_fl_coast_all_test.shp
os.system(rm_bathy_cmd)

