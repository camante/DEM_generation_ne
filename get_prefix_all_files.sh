rm -rf all_tif.txt
echo "Getting Prefixes"
for i in *.tif
do
	tmp=${i:0:6}
	echo $tmp >> all_tif_names.txt
done
echo "Removing Duplicates"
sort all_tif_names.txt | uniq > all_tif_names_no_dups.txt
