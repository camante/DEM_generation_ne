#!/bin/bash

function help () {
echo "las2xyz - Converts all .laz files in a directory to .xyz files for a provided classification, blockmedians xyz to 1/10th arc-sec, and gzips original xyz"
	echo "Usage: $0 change_class output_class"
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

#see if 1 parameters were provided
#show help if not
if [ ${#@} == 2 ]; 
then
	#User inputs    	
	change_class=$1
	class=$2
	for i in *.laz;
	do
		#Create tmp text file of lasinfo for each lidar file
		echo "Processing File" $file_num "out of" $total_files

		if [ -f $(basename $i .laz)"_class_"$class"_bm.xyz" ]; then
		echo "bm xyz already exists, skipping..."
		else
		echo "Processing" $i
		#change_class=40
		#class=12
		echo "Changing class from" $change_class "to" $class
		las2las -i $i -change_classification_from_to $change_class $class -o $(basename $i .laz)"_change_class_"$class.laz
		echo "Converting new class" $class "to xyz"
		las2txt -i $(basename $i .laz)"_change_class_"$class.laz -keep_class $class -o $(basename $i .laz)"_class_"$class.xyz -parse xyz
		rm $(basename $i .laz)"_change_class_"$class.laz

		num_lines=$(< "$(basename $i .laz)"_class_"$class".xyz"" wc -l)
		echo "Number of lines in XYZ file is" $num_lines
			if (( $num_lines > 1000 )); then
			echo "Large file, running blockmedian"
			gmt blockmedian $(basename $i .laz)"_class_"$class.xyz -I0.1s $(gmt gmtinfo $(basename $i .laz)"_class_"$class.xyz -I-) -Q > $(basename $i .laz)"_class_"$class"_bm.xyz";
			else
			echo "Small file, skipping blockmedian"
			cp $(basename $i .laz)"_class_"$class.xyz $(basename $i .laz)"_class_"$class"_bm.xyz"
			fi
			echo "Gzipping original xyz"
			gzip $(basename $i .laz)"_class_"$class.xyz;
		fi
		file_num=$((file_num + 1))
		echo
	done
else
	help

fi
