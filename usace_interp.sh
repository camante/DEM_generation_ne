#!/bin/bash

function help () {
echo "usace_interp - A simple script that converts all .xyz files in a directory to interpolated .tif files for a provided cell size, clips to the xyz boundary and coastline, resamples to finer resolution, and converts to xyz"
	echo "Usage: $0 lastools_path concavity_val initial_cellsize final_cellsize"
	echo "* lastools_path: <path to lastools bin with lasboundary64.exe>
	e.g., /media/sf_C_win_lx/software/LAStools/bin"
	echo "* concavity_val: <concavity value to generate shp to clip final xyz"
	echo "* initial_cellsize: <cell size in arc-seconds>
	0.00003086420 = 1/9th arc-second 
	0.00009259259 = 1/3rd arc-second
	0.00027777777 = 1 arc-second"
	echo "* final_cellsize: <cell size in arc-seconds>
	0.00003086420 = 1/9th arc-second 
	0.00009259259 = 1/3rd arc-second
	0.00027777777 = 1 arc-second"
	echo "* coast_shp: <coastline shp to clip survey to>"
	
}

#see if 5 parameters were provided
#show help if not
if [ ${#@} == 5 ]; 
then
	#User inputs    	
	lastools_path=$1
	concavity_val=$2
	initial_cellsize=$3
	final_cellsize=$4
	coast_shp=$5

	#./usace_interp.sh /media/sf_C_win_lx/software/LAStools/bin 0.015 0.00009259259 0.00003086420 /media/sf_F_win_lx/COASTAL_Act/camante/tx_w_la/data/coast/tx_w_la_coast
	echo "Copying LAStools license"
	cp $lastools_path/lastoolslicense.txt lastoolslicense.txt 

	echo "Copying lasboundary64.exe to current directory"
	cp $lastools_path/lasboundary64.exe lasboundary64.exe

	mkdir -p interp
	mkdir -p interp/shp

	for i in *.xyz;
	do

		#Get minx, maxx, miny, maxy from xyz
		minx="$(gmt gmtinfo  $i -C | awk '{print $1}')"
		maxx="$(gmt gmtinfo  $i -C | awk '{print $2}')"
		miny="$(gmt gmtinfo  $i -C | awk '{print $3}')"
		maxy="$(gmt gmtinfo  $i -C | awk '{print $4}')"
		#short_name = 

		echo "minx is $minx"
		echo "maxx is $maxx"
		echo "miny is $miny"
		echo "maxy is $maxy"

		echo "Creating Polygon for " $i
		wine ./lasboundary64.exe -i $i -o $(basename $i .xyz).shp -concavity $concavity_val

		echo "Interpolating within Polygon"
		#waffles -M surface:tension=1 $i 168 -E$initial_cellsize:$final_cellsize -R $(basename $i .xyz).shp -O $(basename $i .xyz)
		waffles -M linear:radius=-1 $i 168 -E$initial_cellsize:$final_cellsize -R $(basename $i .xyz).shp -O $(basename $i .xyz) -T1:5

		echo "Clipping to Survey Polygon"
		gdal_rasterize -i -burn nan -l $(basename $i .xyz) $(basename $i .xyz).shp $(basename $i .xyz).tif

		echo "Clipping Coastline to ROI"
		#Get minx, maxx, miny, maxy from temporary file
		minx="$(gmt grdinfo  $(basename $i .xyz).tif -C | awk '{print $2}')"
		maxx="$(gmt grdinfo  $(basename $i .xyz).tif -C | awk '{print $3}')"
		miny="$(gmt grdinfo  $(basename $i .xyz).tif -C | awk '{print $4}')"
		maxy="$(gmt grdinfo  $(basename $i .xyz).tif -C | awk '{print $5}')"
		# echo $x_min
		# echo $x_max
		# echo $y_min
		# echo $y_max

		#ogr2ogr -f "ESRI Shapefile" "coast_clip.shp" $coast_shp.shp -clipsrc $x_min $y_min $x_max $y_max
		ogr2ogr -f "ESRI Shapefile" "coast_clip.shp" $coast_shp.shp -clipsrc $minx $miny $maxx $maxy

		echo "Clipping to Coastline"
		gdal_rasterize -burn nan -l "coast_clip" "coast_clip.shp" $(basename $i .xyz).tif

		echo "Converting to XYZ"
		gdal_translate -of xyz $(basename $i .xyz).tif $(basename $i .xyz)_tmp.xyz
		
		echo "Removing Nodata values"
		grep -v nan $(basename $i .xyz)_tmp.xyz | awk '{printf "%.8f %.8f %.2f\n", $1,$2,$3}' > interp/$(basename $i .xyz)_interp.xyz

		rm $(basename $i .xyz)_tmp.xyz
		rm $(basename $i .xyz).tif

		mv $(basename $i .xyz).shp interp/shp/$(basename $i .xyz).shp
		mv $(basename $i .xyz).shx interp/shp/$(basename $i .xyz).shx
		mv $(basename $i .xyz).dbf interp/shp/$(basename $i .xyz).dbf
		#mv $(basename $i .xyz).prj interp/shp/$(basename $i .xyz).prj
		rm "coast_clip.shp"
		rm "coast_clip.dbf"
		rm "coast_clip.prj"
		rm "coast_clip.shx"
	
	done

echo "Moving Shps to subdirectory"


echo "Creating datalist"
cd interp
./create_datalist.sh usace_dredge_interp

else
	help

fi
