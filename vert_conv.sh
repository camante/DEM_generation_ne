#!/bin/bash

function help () {
echo "vert_conv- Script that converts the vertical reference of all xyz data in a directoy based on a pre-generated conversion grid."
	echo "Usage: $0 conversion_grid output_dir input_delim "
	echo "* conversion grid name; if conversion is not in local directory, include full path."
	echo "* output directory name that indicates final vertical reference, e.g., navd88"
	echo "* xyz field delimiter"
}

#see if atleast 2 parameters were provided
#show help if not
if [ ${#@} -ge 2 ];
then
	#User inputs
	conversion_grid=$1
	output_dir=$2
	input_delim=$3

	if [ "$input_delim" == "" ]
	then
		echo
		echo "IMPORTANT:"
		echo "User did not provide delimiter information. Assuming space, output will be incorrect if not actually space."
		echo
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

	#make directory for output
	mkdir -p $output_dir

	for i in *.xyz;
	do
	echo "Converting vertical datum " $i
	echo 
	awk '{print $1,$2,$3}' $i | ./gdal_query.py $query_delim -s_format "0,1,2" -d_format "xyzg" $conversion_grid | awk $awk_delim '{if ($4!=-9999){print}}' | awk $awk_delim '{print $1,$2,$3+$4}' > $output_dir"/"$(basename $i .xyz)"_"$output_dir".xyz"
	echo
	done

else
	help

fi
