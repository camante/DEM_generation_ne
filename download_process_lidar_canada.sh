#!/bin/bash
function help () {
echo "download_process_lidar_canada.sh Script to download and process lidar from Canada's Geo NB in a provided ROI shapefile"
	echo "Usage: $0 data_url roi_shapefile dem_dlist conv_grd_path"
	echo "* data_url: <csv w urls of bulk_download tileindex.zip>"
	echo "* roi_shp: <user-provided shp of your ROI>"
	echo "* dem_dlist: <path to dem master datalist>"
	echo "* conv_grd_path: <path to canada cgv2013 to navd88 conversion grid>"
}

#see if 2 parameters were provided
#show help if not
if [ ${#@} == 4 ]; 
then
data_url=$1
roi_shp=$2
dem_dlist=$3
conv_grd_path=$4

# Get URLs from csv
IFS=,
sed -n '/^ *[^#]/p' $data_url |
while read -r line
do
	data_url=$(echo $line | awk '{print $1}')
	weight=$(echo $line | awk '{print $2}')
	first_class=$(echo $line | awk '{print $3}')
	second_class=$(echo $line | awk '{print $4}')

	#dir_name=$(echo $(basename $(dirname $data_url)))
	#manually set dir name to
	dir_name="geonb_li-idl"
	echo "Creating directory for" $dir_name
	mkdir -p $dir_name

	mkdir -p $dir_name/xyz
	mkdir -p $dir_name/xyz/navd88
	cp laz2xyz_repro_latlon_m.sh $dir_name/xyz/laz2xyz_repro_latlon_m.sh
	cp vert_conv.sh $dir_name/xyz/vert_conv.sh
	cp gdal_query.py $dir_name/xyz/gdal_query.py
	cp create_datalist.sh $dir_name/xyz/navd88/create_datalist.sh

	cd $dir_name

	echo "Downloading Index Shp"
	wget $data_url

	echo "Unzipping Index Shp"
	unzip $dir_name"_shp.zip"

	#shp_name=$(ls *.shp)
	#manually specify shapefile
	shp_name="geonb_li_idl_cgvd2013"
	echo "Index Shp name is " $shp_name

	echo "Coverting Index Shp to NAD83"
	ogr2ogr -clipsrc $roi_shp $shp_name"_"clip_index.shp $shp_name".shp"
	ogr2ogr -f "ESRI Shapefile" -t_srs EPSG:4269 $shp_name"_nad83.shp" $shp_name".shp"

	echo "Clipping Index Shp to ROI shp"
	ogr2ogr -clipsrc $roi_shp $shp_name"_"clip_index.shp $shp_name"_nad83.shp"

	sql_var=$shp_name"_clip_index"
	echo "Dropping all Columns but URL"
	#echo ogr2ogr -f "ESRI Shapefile" -sql "SELECT URL FROM \"$sql_var\"" $shp_name"_"clip_index_url.shp $shp_name"_"clip_index.shp
	ogr2ogr -f "ESRI Shapefile" -sql "SELECT FILE_URL FROM \"$sql_var\"" $shp_name"_"clip_index_url.shp $shp_name"_"clip_index.shp

	echo "Converting SHP to CSV"
	ogr2ogr -f CSV $shp_name"_"clip_index_url.csv $shp_name"_"clip_index_url.shp

	echo "Removing Header and Quotes"
	sed '1d' $shp_name"_"clip_index_url.csv > tmpfile; mv tmpfile $shp_name"_"clip_index_url.csv
	sed 's/"//' $shp_name"_"clip_index_url.csv > tmpfile; mv tmpfile $shp_name"_"clip_index_url.csv

	mv $shp_name"_"clip_index_url.csv xyz/$shp_name"_"clip_index_url.csv
	cd xyz

	echo "Downloading Data"
	wget -N --no-if-modified-since --input-file $shp_name"_"clip_index_url.csv

	echo "Converting laz to xyz for class" $first_class
	./laz2xyz_repro_latlon_m.sh $first_class

	echo "Converting from CGVD2013 to NAVD88"
	./vert_conv.sh $conv_grd_path navd88

	cd navd88
	./create_datalist.sh $shp_name"_lidar"
	echo "$PWD/$shp_name"_lidar".datalist -1 "$weight >> $dem_dlist
	#rm *.laz
	
	echo "Finished Processing" $shp_name
	echo "Moving on to the next dataset"
	echo $PWD
	echo 

	cd ..
	cd ..
	cd ..

	echo $PWD

done
echo "Finished processing all Canada lidar datasets"


else
	help
fi
