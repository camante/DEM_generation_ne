#!/bin/bash
function help () {
echo "process_lidar.sh Script to download and process lidar from NOAA's Digital Coast in a provided ROI shapefile"
	echo "Usage: $0 main_dir basename download_csv roi_shapefile "
	echo "* data_url: <csv w urls of bulk_download tileindex.zip>"
	echo "* roi_shp: <user-provided shp of your ROI>"
	echo "* bs_dlist: <path to bathy surface master datalist>"
	echo "* dem_dlist: <path to dem master datalist>"
}

#see if 2 parameters were provided
#show help if not
if [ ${#@} == 4 ]; 
then
data_url=$1
roi_shp=$2
bs_dlist=$3
dem_dlist=$4

# Get URLs from csv
IFS=,
sed -n '/^ *[^#]/p' $data_url |
while read -r line
do
	data_url=$(echo $line | awk '{print $1}')
	weight=$(echo $line | awk '{print $2}')
	first_class=$(echo $line | awk '{print $3}')
	second_class=$(echo $line | awk '{print $4}')

	dir_name=$(echo $(basename $(dirname $data_url)))
	echo "Creating directory for" $dir_name
	mkdir -p $dir_name

	if [ -z "$second_class" ]
	then
		echo "LAZ isn't topobathy and doesn't have second class"
		mkdir -p $dir_name/xyz
		cp create_datalist.sh  $dir_name/xyz/create_datalist.sh
		cp laz2xyz.sh $dir_name/xyz/laz2xyz.sh
	else
		echo "LAZ has valid second class"
		mkdir -p $dir_name/xyz
		mkdir -p $dir_name/xyz/pos
		mkdir -p $dir_name/xyz/neg
		cp laz2xyz.sh $dir_name/xyz/laz2xyz.sh
		cp separate_pos_neg.sh $dir_name/xyz/separate_pos_neg.sh
		cp create_datalist.sh  $dir_name/xyz/pos/create_datalist.sh
		cp create_datalist.sh  $dir_name/xyz/neg/create_datalist.sh
	fi


	cd $dir_name

	echo "Downloading Index Shp"
	wget $data_url

	echo "Unzipping Index Shp"
	unzip tileindex.zip

	shp_name=$(ls *.shp)
	echo "Index Shp name is " $shp_name

	echo "Clipping Index Shp to ROI shp"
	ogr2ogr -clipsrc $roi_shp $dir_name"_"clip_index.shp $shp_name

	sql_var=$dir_name"_clip_index"
	echo "Dropping all Columns but URL"
	#echo ogr2ogr -f "ESRI Shapefile" -sql "SELECT URL FROM \"$sql_var\"" $dir_name"_"clip_index_url.shp $dir_name"_"clip_index.shp
	ogr2ogr -f "ESRI Shapefile" -sql "SELECT URL FROM \"$sql_var\"" $dir_name"_"clip_index_url.shp $dir_name"_"clip_index.shp

	echo "Converting SHP to CSV"
	ogr2ogr -f CSV $dir_name"_"clip_index_url.csv $dir_name"_"clip_index_url.shp

	echo "Removing Header and Quotes"
	sed '1d' $dir_name"_"clip_index_url.csv > tmpfile; mv tmpfile $dir_name"_"clip_index_url.csv
	sed 's/"//' $dir_name"_"clip_index_url.csv > tmpfile; mv tmpfile $dir_name"_"clip_index_url.csv

	mv $dir_name"_"clip_index_url.csv xyz/$dir_name"_"clip_index_url.csv
	cd xyz

	echo "Downloading Data"
	wget -N --no-if-modified-since --input-file $dir_name"_"clip_index_url.csv

	echo "Converting laz to xyz for class" $first_class
	./laz2xyz.sh $first_class

	if [ -z "$second_class" ]
	then
		echo "LAZ isn't topobathy and doesn't have second class"
		./create_datalist.sh $dir_name"_lidar"
		echo "$PWD/$dir_name"_lidar".datalist -1 "$weight >> $dem_dlist
		#rm *.laz
	else
		echo "LAZ has valid second class"
		echo "Converting laz to xyz for class" $second_class
		./laz2xyz.sh $second_class
		echo "Separating Pos and Neg"
		./separate_pos_neg.sh
		cd pos
		./create_datalist.sh $dir_name"_lidar_pos"
		# comment out below if dont use positive topobathy data values because I have newer, better topo lidar
		echo "$PWD/$dir_name"_lidar_pos".datalist -1 "$weight >> $dem_dlist
		cd ..
		cd neg 
		./create_datalist.sh $dir_name"_lidar_neg"
		echo "$PWD/$dir_name"_lidar_neg".datalist -1 "$weight >> $bs_dlist
		echo "$PWD/$dir_name"_lidar_neg".datalist -1 "$weight >> $dem_dlist
		cd ..
		#rm *.laz
	fi

	echo "Finished Processing" $dir_name
	echo "Moving on to the next dataset"
	echo $PWD
	echo 

	cd ..
	cd ..

	echo $PWD

done
echo "Finished processing all dc lidar datasets"


else
	help
fi
