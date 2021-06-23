#!/bin/bash

function help () {
echo "usace_ft2m - Script that converts usace hydro from feet to meters and positive to negative if necessary. "
	echo "Usage: $0 extension delim "
	echo "* extension: extension, Example: .csv or .xyz"
	echo "* delim: delimiter, if not provided then space is assumed"
}

extension=$1
delim=$2

if [ "$delim" == "" ]
then
	echo
	echo "IMPORTANT:"
	echo "User did not provide delimiter information. Assuming space, output will be incorrect if not actually space."
	echo
	param=""
else
	echo "User input delimiter is NOT space. Taking delimiter from user input"
	param="-F"$delim
fi

total_files=$(ls -lR *$extension | wc -l)

echo "Total number of xyz files to process:" $total_files
file_num=1

mkdir -p neg_m

for i in *$extension;
do
echo "Processing File" $file_num "out of" $total_files
echo "File name is " $i

echo "Calculating Median Value of Depth"
percentile=50
med_z=`awk $param '{print $3}' $i | sort -nr | awk -v var="$percentile" 'BEGIN{c=0} length($0){a[c]=$0;c++}END{pvar=(c/100*var); pvar=pvar%1?int(pvar)+1:pvar; print a[c-pvar-1]}'`

echo "Median Value of Depth is", $med_z
check_val=0

compare=`echo "$med_z > $check_val" | bc`

if [ $compare -eq 1 ]
then
	echo "Median Depth is Positive. Converting to negative and from feet to meter."
	awk $param '{if (NR!=1) {printf "%.8f %.8f %.3f\n", $1,$2,$3*-0.3048}}' $i > "neg_m/"$(basename $i $extension)"_neg_m.xyz"
	echo
else
	echo "Median Depth is Negative. Converting from feet to meter." 
	awk $param '{if (NR!=1) {printf "%.8f %.8f %.3f\n", $1,$2,$3*0.3048}}' $i > "neg_m/"$(basename $i $extension)"_neg_m.xyz"
	echo
fi

file_num=$((file_num + 1))
done

