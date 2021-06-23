#!/bin/bash
function help () {
echo "nos2xyz - Script that removes header and converts to XYZ, negative down for NOS files downloaded using nos_fetch.py"
	echo "Usage: $0 extension delim "
}

total_files=$(ls -lR *.xyz | wc -l)
echo "Total number of xyz files to process:" $total_files
file_num=1

mkdir -p neg_m

for i in *.xyz;
do
echo "Processing File" $file_num "out of" $total_files
echo "File name is " $i
awk -F, '{if (NR!=1 && $6 == 1) {printf "%.8f %.8f %.3f\n", $3,$2,$4*-1}}' $i > "neg_m/"$(basename $i .xyz)"_neg_m.xyz"
echo

file_num=$((file_num + 1))
done

