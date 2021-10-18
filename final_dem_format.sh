#!/bin/bash
tile_extents=$1
smooth_factor=$2
year=$3
version=$4
border_dems_path=$5

#finest cell size resolution, e.g., 1/9th arc-sec, provided in gdalinfo
fine_cell=0.000030864197534
date=$(date --iso-8601=seconds)
echo date is $date

mkdir -p orig_res
mkdir -p deliverables
mkdir -p deliverables/thredds

# echo "Copying over any border dems to current directory"
# for file in $border_dems_path*.tif; 
# do
# 	echo "copying file to current directory:" $file
# 	#[ -e $file ] && rm $file
# 	cp $file $(basename $file)
# done

echo "Creating Shps of DEM Extents and any border DEMs"
for i in *.tif
do
	echo "Processing" $i
	if [ -f $(basename $i .tif)".shp" ]; then
		echo "Extents shp already exists, skipping generation..."
	else
		echo "Generating extents shp"
		gdal_calc.py -A $i --outfile=$(basename $i .tif)"_zero.tif"  --calc="A*0"
		gdal_polygonize.py $(basename $i .tif)"_zero.tif" -f "ESRI Shapefile" $(basename $i .tif)".shp"
		echo "Created shp for" $i
	fi

	raster_cellsize=`gdalinfo $i | grep -e "Pixel Size" | awk '{print $4}' | sed -e 's/.*(\(.*\),.*/\1/'`
	echo "raster cellsize is" $raster_cellsize

	if [ "$raster_cellsize" = "$fine_cell" ]
	then
		echo "cell size is already at the finest res, no resampling needed"
		#if at finest res, don't need to keep zero raster
		[ -f $(basename $i .tif)"_zero.tif"  ] && rm $(basename $i .tif)"_zero.tif" 
	else
		#Calculate zero grid if it doesn't exist
		echo "Processing" $i
		if [ -f $(basename $i .tif)"_zero.tif" ]; then
			echo "Zero grid already exists, skipping generation..."
		else
			echo "Generating zero grid"
			gdal_calc.py -A $i --outfile=$(basename $i .tif)"_zero.tif"  --calc="A*0"
		fi
		echo "Resampling to the finest resolution to use in mosaic"
		gdalwarp $(basename $i .tif)"_zero.tif" -tr $fine_cell $fine_cell $(basename $i .tif)"_zero_ninth.tif" -overwrite
		resamp_factor_flt=$(echo "$raster_cellsize / $fine_cell" | bc -l)
		echo "Resampling Factor float is" $resamp_factor_flt
		resamp_factor=$(echo "($resamp_factor_flt+0.5)/1" | bc)
		echo "Resampling factor is" $resamp_factor
		#note, below script many not work if resolution isn't an even factor of the finest res, ie., 1/3, 1, 3 arc-sec, etc.
		python ./resample.py $i $(basename $i .tif)"_zero_ninth.tif" $resamp_factor
		mv $i "orig_res/"$i
		mv $(basename $i .tif)"_resamp.tif" $i
		rm $(basename $i .tif)"_zero.tif"
		rm $(basename $i .tif)"_zero_ninth.tif"
	fi
	echo
done

echo "Merging Tifs in Name Cell Extents"
# Get Tile Name, Cellsize, and Extents from tile_extents_gridding.txt
IFS=,
sed -n '/^ *[^#]/p' $tile_extents |
while read -r line
do
name=$(echo $line | awk '{print $1}')
raster_name=$name"_DEM_smooth_"$smooth_factor".tif"
main_shp_name=$(basename $raster_name .tif)".shp"

cellsize_degrees=$(echo $line | awk '{print $2}')
west=$(echo $line | awk '{print $3}')
east=$(echo $line | awk '{print $4}')
south=$(echo $line | awk '{print $5}')
north=$(echo $line | awk '{print $6}')

north_degree=${north:0:2}
north_decimal=${north:3:2}

if [ -z "$north_decimal" ]
then
	north_decimal="00"
else
	:
fi

size=${#north_decimal}
#echo "Number of North decimals is" $size
if [ "$size" = 1 ]
then
	north_decimal="$north_decimal"0
else
	:
fi

west_degree=${west:1:2}
west_decimal=${west:4:2}

if [ -z "$west_decimal" ]
then
	west_decimal="00"
else
	:
fi

size=${#west_decimal}
if [ "$size" = 1 ]
then
	west_decimal="$west_decimal"0
else
	:
fi

echo
echo "Input Tile Name is" $name

if [ "$cellsize_degrees" = 0.00003086420 ]
then
	cell_name=19
else
	cell_name=13
fi

#add raster to vrt list
ls $raster_name >> $name"_dem_list.txt"
#Create txt for all other shps

#list all shps to text
ls *.shp > $name"_shp_list.txt"
#remove shp in question
sed -i "/$main_shp_name/d" $name"_shp_list.txt"

# #go through generated txt and clip each shp in file to the main shp
# # Get Tile Name, Cellsize, and Extents from tile_extents_gridding.txt
IFS=,
sed -n '/^ *[^#]/p' $name"_shp_list.txt" |
while read -r line
do
shp_name=$(echo $line | awk '{print $1}')

echo "Clipping" $shp_name "overlaps with main shp" $main_shp_name
output_name=$(basename $main_shp_name .shp)"_"$(basename $shp_name .shp)"_clipped.shp"
ogr2ogr $output_name $main_shp_name -clipsrc $shp_name
gdalwarp -cutline $output_name -crop_to_cutline -of GTiff -dstnodata -999999 $(basename $shp_name .shp)".tif" $(basename $output_name .shp)".tif"

rm $output_name
rm $(basename $output_name .shp)".shx"
rm $(basename $output_name .shp)".dbf"
rm $(basename $output_name .shp)".prj"

#add name to vrt list
echo "Creating VRT"
ls $(basename $output_name .shp)".tif" >> $name"_dem_list.txt"
echo "building VRT"
gdalbuildvrt -separate -input_file_list $name"_dem_list.txt" -allow_projection_difference -resolution highest $name".vrt" -overwrite
done

echo "Creating Mosaic Raster"
python ./average_tifs.py $name".vrt"

echo "Converting DEM to target cell size"
gdalwarp -dstnodata -999999 -tr $cellsize_degrees $cellsize_degrees $name"_mosaic.tif" $name"_final_tmp.tif"

echo "Completing Final Formating of DEM"
gdal_translate $name"_final_tmp.tif" -of GTiff -a_srs EPSG:4269 -a_nodata -999999 -mo TIFFTAG_COPYRIGHT="DOC/NOAA/NESDIS/NCEI > National Centers for Environmental Information, NESDIS, NOAA, U.S. Department of Commerce" -mo TIFFTAG_IMAGEDESCRIPTION="Topography-Bathymetry; NAVD88" -mo TIFFTAG_DATETIME=$date -co TILED=YES -co COMPRESS=DEFLATE -co PREDICTOR=3 "deliverables/ncei"$cell_name"_n"$north_degree"x"$north_decimal"_w0"$west_degree"x"$west_decimal"_"$year"v"$version".tif" -stats
rm $name"_final_tmp.tif"
rm $name"_final_tmp.tif.aux.xml"

echo "Checking for existing tiles"
input_tile="ncei"$cell_name"_n"$north_degree"x"$north_decimal"_w0"$west_degree"x"$west_decimal"_"$year"v"$version".tif"
./update_tile_version.sh $input_tile $year

#Added below code to update_tile_version.sh
#
#echo "Converting to NetCDF for thredds"
#below method causes half cell shift in global mapper but not in arcgis
#when converted to xyz, it appears in right place in global mapper
#gmt grdconvert "deliverables/ncei"$cell_name"_n"$north_degree"x"$north_decimal"_w0"$west_degree"x"$west_decimal"_"$year"v"$version".tif" "deliverables/thredds/ncei"$cell_name"_n"$north_degree"x"$north_decimal"_w0"$west_degree"x"$west_decimal"_"$year"v"$version".nc" -fg -V

echo "Removing Clipped tifs"
sed 1d $name"_dem_list.txt" |
while read -r line
do
clipped_tif=$(echo $line | awk '{print $1}')
echo "removing" $clipped_tif
rm $clipped_tif
done

echo "Removing intermediate files"
rm $name"_shp_list.txt"
rm $name"_dem_list.txt"
rm $name".vrt"
rm $name"_mosaic.tif"

echo
echo

done

# echo "Removing all shps"
# rm *.shp
# rm *.shx
# rm *.dbf
# rm *.prj

cd deliverables
echo "Computing Final Stats"
rm -f minmax.csv
echo "Creating inf files"
datalists *.tif -r
for i in *.inf; 
do 
	./minmax.py $i 
done

#moved below to create_dem.sh
# echo "Identifying Potential Outliers"
# for i in *.tif; 
# do 
# 	echo "DEM is" $i
# 	rm -f thresholds.csv
# 	echo "Calculating min and max thresholds from percentiles"
# 	percentiles_minmax.py $i
# 	min_threshold=`awk -F, '{print $2}' thresholds.csv`
# 	max_threshold=`awk -F, '{print $3}' thresholds.csv`
# 	echo "Creating outliers shapefiles"
# 	outliers_shp.sh $i $min_threshold $max_threshold yes
# 	echo 
# done

