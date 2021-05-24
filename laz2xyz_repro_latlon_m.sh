#!/bin/bash

function help () {
echo "las2xyz - A simple script that converts all .laz files in a directory to .xyz files and reprojects to geographic coords for a provided classification"
	echo "Usage: $0 class"
	echo "* class: <the desired lidar return>
	0 Never classified
	1 Unassigned
	2 Ground
	3 Low Vegetation
	4 Medium Vegetation
	5 High Vegetation
	6 Building
	7 Low Point
	8 Reserved
	9 Water
	10 Rail
	11 Road Surface
	12 Reserved
	13 Wire - Guard (Shield)
	14 Wire - Conductor (Phase)
	15 Transmission Tower
	16 Wire-Structure Connector (Insulator)
	17 Bridge Deck
	18 High Noise"
}

total_files=$(ls -1 | grep '\.laz$' | wc -l)
echo "Total number of laz files to process:" $total_files

file_num=1

#see if 1 parameters was provided
#show help if not
if [ ${#@} == 1 ]; 
then
	#User inputs    	
	class=$1
	for i in *.laz;
	do
		echo "Processing File" $file_num "out of" $total_files

		if [ -f $(basename $i .laz)"_class_"$class"_bm.xyz" ]; then
			echo "bm xyz already exists, skipping..."
		else
			echo "Selecting Class:" $i
			las2las -i $i -o $(basename $i .laz)"_class_"$class".laz" -keep_class $class
			echo "Reprojecting:" $i
			las2las -i $(basename $i .laz)"_class_"$class".laz" -o $(basename $i .laz)"_class_"$class"_latlon.laz" -target_longlat -target_meter
			echo "Converting to xyz:" $i
			las2txt -i $(basename $i .laz)"_class_"$class"_latlon.laz" -o $(basename $i .laz)"_class_"$class.xyz -parse xyz
			rm $(basename $i .laz)"_class_"$class".laz"
			rm $(basename $i .laz)"_class_"$class"_latlon.laz"

			num_lines=$(< "$(basename $i .laz)"_class_"$class".xyz"" wc -l)
			echo "Number of lines in XYZ file is" $num_lines

			if (( $num_lines > 1000 )); then
				echo "Running blockmedian"
				gmt blockmedian $(basename $i .laz)"_class_"$class.xyz -I0.1s $(gmt gmtinfo $(basename $i .laz)"_class_"$class.xyz -I-) -Q > $(basename $i .laz)"_class_"$class"_bm.xyz";
			else
				echo "Small file, skipping blockmedian"
				cp $(basename $i .laz)"_class_"$class.xyz $(basename $i .laz)"_class_"$class"_bm.xyz"
			fi
				echo "Gzipping original xyz"
				gzip $(basename $i .laz)"_class_"$class.xyz
		fi
		file_num=$((file_num + 1))
		echo
	done
else
	help
fi
