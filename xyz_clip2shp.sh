#!/bin/bash
function help () {
echo "xyz_clip2shp.sh- Script that clips xyz to shp"
	echo "Usage: $0 cellsize shp invert query_delim"
	echo "* cellsize: <coastline cell size in arc-seconds>
	0.0000102880663 = 1/27 arc-second
	0.000030864199 = 1/9th arc-second 
	0.000092592596 = 1/3rd arc-second"
	echo "* shp: <shapefile for clipping. Don't include .shp extension >"
	echo "* invert: <invert shapefile for clipping, yes or no. yes if want to keep values in polygons.>"
	echo "* query_delim: <xyz field delimiter>"
}

#see if 3 parameters were provided
#show help if not
if [ ${#@} -gt 3 ]; 
	then
	cellsize=$1
	shp=$2
	invert=$3
	query_delim=$4

	if [ "$invert" == "yes" ];
	then
		echo -- Inverting clip
		invert_param="-i"
	else
		echo -- Not Inverting clip
		invert_param=
	fi

	if [ "$input_delim" == "" ]
	then
		echo "IMPORTANT:"
		echo "User did not provide delimiter information. Assuming space, output will be incorrect if not actually space."
		query_delim=""
		awk_delim=""
		echo "gdal_query delim is" $query_delim
		echo "awk delim is" $awk_delim
		#exit 1
	else
		echo "User input delimiter is NOT space. Taking delimiter from user input"
		query_delim="-delimiter "$input_delim
		awk_delim="-F"$input_delim
		echo "gdal_query delim is" $query_delim
		echo "awk delim is" $awk_delim
		#exit 1
	fi

	for i in *.xyz;
	do
		echo "Processing" $i
		echo "Copying original to xyc"
		cp $i $(basename $i .xyz)".xyc"
		echo "Getting xyz bounding box"
		#Get minx, maxx, miny, maxy from temporary file
		minx_tmp="$(gmt gmtinfo  $i -C | awk '{print $1}')"
		maxx_tmp="$(gmt gmtinfo  $i -C | awk '{print $2}')"
		miny_tmp="$(gmt gmtinfo  $i -C | awk '{print $3}')"
		maxy_tmp="$(gmt gmtinfo  $i -C | awk '{print $4}')"
		echo "minx is $minx_tmp"
		echo "maxx is $maxx_tmp"
		echo "miny is $miny_tmp"
		echo "maxy is $maxy_tmp"
		echo "Clipping Shp to ROI"
		#Add on 4 more cells just to make sure there is no edge effects when burnining in shp.
		x_min=$(echo "$minx_tmp - $cellsize - $cellsize - $cellsize - $cellsize" | bc -l)
		x_max=$(echo "$maxx_tmp + $cellsize + $cellsize + $cellsize + $cellsize" | bc -l)
		y_min=$(echo "$miny_tmp - $cellsize - $cellsize - $cellsize - $cellsize" | bc -l)
		y_max=$(echo "$maxy_tmp + $cellsize + $cellsize + $cellsize + $cellsize" | bc -l)
		#echo $x_min $y_min $x_max $y_max
		echo -- Clipping shp to ROI
		ogr2ogr $(basename $i .xyz)".shp" $shp".shp" -clipsrc $x_min $y_min $x_max $y_max -overwrite
		echo -- Rasterizing Shp
		gdal_rasterize -te $x_min $y_min $x_max $y_max -tr $cellsize $cellsize -burn -99999999999999999 $invert_param -l $(basename $i .xyz) $(basename $i .xyz)".shp" $(basename $i .xyz)"_shp_tmp.tif"
		x_min2=$(echo "$minx_tmp - $cellsize - $cellsize" | bc -l)
		x_max2=$(echo "$maxx_tmp + $cellsize + $cellsize" | bc -l)
		y_min2=$(echo "$miny_tmp - $cellsize - $cellsize" | bc -l)
		y_max2=$(echo "$maxy_tmp + $cellsize + $cellsize" | bc -l)
		echo -- Removing outer rows
		gdal_translate -projwin $x_min2 $y_max2 $x_max2 $y_min2 $(basename $i .xyz)"_shp_tmp.tif" $(basename $i .xyz)"_shp.tif"
		echo -- Clipping xyz with raster
		awk '{print $1,$2,$3}' $i | ./gdal_query.py $query_delim -s_format "0,1,2" -d_format "xyzg" $(basename $i .xyz)"_shp.tif" | awk $awk_delim '{print $1,$2,$3+$4}' > $(basename $i .xyz)"_clipped_all.xyz"
		rm $i
		echo -- Extracting only valid values
		awk '{if ($3 > -999999) {printf "%.8f %.8f %.2f\n", $1,$2,$3}}' $(basename $i .xyz)"_clipped_all.xyz" > $i
		rm $(basename $i .xyz)".shp"
		rm $(basename $i .xyz)".shx"
		rm $(basename $i .xyz)".dbf"
		rm $(basename $i .xyz)".prj"
		rm $(basename $i .xyz)"_shp_tmp.tif"
		rm $(basename $i .xyz)"_shp.tif"
		rm $(basename $i .xyz)"_clipped_all.xyz"
		echo
	done

./create_datalist.sh 2557_lidar

else
	help
fi
