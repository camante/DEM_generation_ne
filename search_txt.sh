#!/bin/bash
function help () {
echo "search_txt- Script that iterates through each line of input key file A and searches entire file B"
	echo "Usage: $0 key file"
	echo "* key: <text file with lines of strings to search for"
	echo "* file: <file to search in>"
}

rm -rf missing.txt
rm found
mdir missing
mkdir -p found
mkdir -p missing
#see if 3 parameters were provided
#show help if not
if [ ${#@} == 2 ]; 
	then
		key=$1
		file=$2
		# Get Tile Name, Cellsize, and Extents from name_cell_extents.csv
		IFS=,
		sed -n '/^ *[^#]/p' $key |
		while read -r line
		do
		key_word=$(echo $line | awk '{print $1}')
		echo "Searching for" $key_word "in file" $file
		#awk '/^$key_word/' $file > $key_word"_search_results.txt"
		grep $key_word $file > $key_word"_search_results.txt"
		if [ -s $key_word"_search_results.txt" ]; 
		then
        	echo "Found!"
        	mv $key_word"_search_results.txt" found/$key_word"_search_results.txt"
		else
        	echo "Did not find, adding to list."
        	echo $key_word >> missing.txt
        	mv $key_word"_search_results.txt" missing/$key_word"_search_results.txt"
		fi
		done
else
	help
fi

echo "Calculating differences between files"
grep -Fxvf $key $file > diff_file.txt
