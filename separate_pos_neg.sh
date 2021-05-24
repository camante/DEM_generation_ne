#!/bin/bash

function help () {
echo "separate_pos_neg - splits all xyz files in a directory into two separate directories and files based on if the z-value is <= 0 (neg) or > 0 (pos). User must specify the delimiter if XYZ file is not space dilimited"
	echo "Usage: $0 delimiter"
	echo "* delimiter: <input xyz file dilimeter if not space>"
}

delim=$1

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

total_files=$(ls -1 | grep '\.xyz$' | wc -l)
echo "Total number of xyz files to process:" $total_files
file_num=1

mkdir -p pos
mkdir -p neg

for i in *.xyz;
do
echo "Processing File" $file_num "out of" $total_files
echo "File name is " $i

echo -- Separating into positive and negative values
awk $param -v neg="neg/$(basename $i .xyz)_neg.xyz" -v pos="pos/$(basename $i .xyz)_pos.xyz" '{if($3<=0)print > neg;else print > pos}' $i

mv $i $(basename $i .xyz)".xyc"

file_num=$((file_num + 1))
done

#rm *.xyc
