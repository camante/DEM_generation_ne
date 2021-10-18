input_tile=$1
year=$2
existing_tiles=all_dc_tiles.csv
[ -e replace_files_sm.csv ] && rm replace_files_sm.csv
touch replace_files_sm.csv

#create all_dc_tiles.csv if it doesn't already exist
if test -f "$existing_tiles"; then
	echo "$existing_tiles exists, skipping downloading from digital coast"
else
	echo "Downloading Index Shp from Digital Coast"
	wget https://coast.noaa.gov/htdata/raster2/elevation/NCEI_ninth_Topobathy_2014_8483/tileindex_NCEI_ninth_Topobathy_2014.zip
	wget https://coast.noaa.gov/htdata/raster2/elevation/NCEI_third_Topobathy_2014_8580/tileindex_NCEI_third_Topobathy_2014.zip

	echo "Unzipping Index Shp"
	unzip tileindex_NCEI_ninth_Topobathy_2014.zip
	unzip tileindex_NCEI_third_Topobathy_2014.zip

	ninth_shp_name=tileindex_NCEI_ninth_Topobathy_2014
	third_shp_name=tileindex_NCEI_third_Topobathy_2014

	ninth_shp_name_url=tileindex_NCEI_ninth_Topobathy_2014_url
	third_shp_name_url=tileindex_NCEI_third_Topobathy_2014_url

	echo "Dropping all Columns but URL"
	ogr2ogr -f "ESRI Shapefile" -sql "SELECT URL FROM \"$ninth_shp_name\"" $ninth_shp_name_url.shp $ninth_shp_name.shp
	ogr2ogr -f "ESRI Shapefile" -sql "SELECT URL FROM \"$third_shp_name\"" $third_shp_name_url.shp $third_shp_name.shp

	echo "Converting SHP to CSV"
	ogr2ogr -f CSV $ninth_shp_name.csv $ninth_shp_name_url.shp
	ogr2ogr -f CSV $third_shp_name.csv $third_shp_name_url.shp

	echo "Removing Header and Quotes"
	sed '1d' $ninth_shp_name.csv > tmpfile; mv tmpfile $ninth_shp_name.csv
	sed 's/"//' $ninth_shp_name.csv > tmpfile; mv tmpfile $ninth_shp_name.csv

	echo "Removing Header and Quotes"
	sed '1d' $third_shp_name.csv > tmpfile; mv tmpfile $third_shp_name.csv
	sed 's/"//' $third_shp_name.csv > tmpfile; mv tmpfile $third_shp_name.csv

	echo "Combining ninth and third tiles indices"
	cat $ninth_shp_name.csv $third_shp_name.csv > all_dc_tiles.csv
fi

echo "Input tile is" $input_tile
input_tile_base=${input_tile%_*}
echo "Input tile base is" $input_tile_base



echo "Searching for" $input_tile_base "in" $existing_tiles
search_result=$(grep -iF "$input_tile_base" $existing_tiles)

echo "Search result is" $search_result
if [ -z "${search_result}" ]; 
then
	echo "No previous version found"

else
	echo "Previous version found"
	#add to csv
	echo $input_tile >> replace_files_sm.csv

	version=$(echo "$search_result" | sed -e 's/\(^.*v\)\(.*\)\(.tif.*$\)/\2/')
	echo "Version is" $version

	update_version=$(($version + 1))
	echo "Renaming File to Next Version Number, v"$update_version

	input_tile_base=${input_tile%_*}
	echo "Base is" $input_tile_base

	new_extension=${year}"v"${update_version}
	echo "New extension is" $new_extension

	echo "Renaming shp to new version name" $input_tile_base"_"$new_extension"_sm.shp"
	mv $input_tile"_sm.shp" $input_tile_base"_"$new_extension"_sm.shp"
	mv $input_tile"_sm.dbf" $input_tile_base"_"$new_extension"_sm.dbf"
	mv $input_tile"_sm.shx" $input_tile_base"_"$new_extension"_sm.shx"
	mv $input_tile"_sm.prj" $input_tile_base"_"$new_extension"_sm.prj"
fi
