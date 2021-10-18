#!/bin/bash
function help () {
echo "create_topo_guide- Script that creates topo guide for a bathy surface"
	echo "Usage: $0 name_cell_extents datalist coastline mb1"
	echo "* name_cell_extents: <csv file with name,target spatial resolution in decimal degrees,tile_exents in W,E,S,N>"
	echo "* coastline: <coastline shapefile for clipping. Don't include .shp extension >"
}

#see if 3 parameters were provided
#show help if not
if [ ${#@} == 2 ]; 
	then
	mkdir -p topo_guide
	mkdir -p coast_shp
	name_cell_extents=$1
	coastline_full=$2

	#Create BS at 1 arc-sec
	bs_res=0.00027777777
	bs_extend=2

	#############################################################################
	#############################################################################
	#############################################################################
	######################      DERIVED VARIABLES     ###########################
	#############################################################################
	#############################################################################
	#############################################################################

	#This is used to eventually resample back to target resolution of 1/9 or 1/3rd
	ninth_clip_factor=$(echo "((8100+(9*$bs_extend*2))-8112) / 2" | bc )
	third_clip_factor=$(echo "((2700+(3*$bs_extend*2))-2712) / 2" | bc )
	bs_align_cells=$(echo "$bs_res * $bs_extend" | bc -l)

	# Get Tile Name, Cellsize, and Extents from name_cell_extents.csv
	IFS=,
	sed -n '/^ *[^#]/p' $name_cell_extents |
	while read -r line
	do
	name=$(echo $line | awk '{print $1}')
	target_res=$(echo $line | awk '{print $2}')
	west_quarter=$(echo $line | awk '{print $3}')
	east_quarter=$(echo $line | awk '{print $4}')
	south_quarter=$(echo $line | awk '{print $5}')
	north_quarter=$(echo $line | awk '{print $6}')


	echo
	echo "Tile Name is" $name
	echo "Cellsize in degrees is" $target_res
	echo "West is" $west_quarter
	echo "East is" $east_quarter
	echo "South is" $south_quarter
	echo "North is" $north_quarter
	echo

	#Add on additional cells at bathy_surf resolution to ensure complete coverage of each tile and alignment with 1/9th and 1/3rd res
	west=$(echo "$west_quarter - $bs_align_cells" | bc -l)
	north=$(echo "$north_quarter + $bs_align_cells" | bc -l)
	east=$(echo "$east_quarter + $bs_align_cells" | bc -l)
	south=$(echo "$south_quarter - $bs_align_cells" | bc -l)

	#Take in a half-cell on all sides so that grid-registered raster edge aligns exactly on desired extent
	half_cell=$(echo "$bs_res / 2" | bc -l)
	west_reduced=$(echo "$west + $half_cell" | bc -l)
	north_reduced=$(echo "$north - $half_cell" | bc -l)
	east_reduced=$(echo "$east - $half_cell" | bc -l)
	south_reduced=$(echo "$south + $half_cell" | bc -l)
	mb_range="-R$west_reduced/$east_reduced/$south_reduced/$north_reduced"

	#Determine number of rows and columns with the desired cell size, rounding up to nearest integer.
	#i.e., 1_9 arc-second
	x_diff=$(echo "$east - $west" | bc -l)
	y_diff=$(echo "$north - $south" | bc -l)
	x_dim=$(echo "$x_diff / $bs_res" | bc -l)
	y_dim=$(echo "$y_diff / $bs_res" | bc -l)
	x_dim_int=$(echo "($x_dim+0.5)/1" | bc)
	y_dim_int=$(echo "($y_dim+0.5)/1" | bc)

	#Target Resolution
	#Take orig extents, add on 6 cells at target resolution. All DEM tiles have 6 cell overlap.
	six_cells_target=$(echo "$target_res * 6" | bc -l)

	west_grdsamp=$(echo "$west_quarter - $six_cells_target" | bc -l)
	north_grdsamp=$(echo "$north_quarter + $six_cells_target" | bc -l)
	east_grdsamp=$(echo "$east_quarter + $six_cells_target" | bc -l)
	south_grdsamp=$(echo "$south_quarter - $six_cells_target " | bc -l)
	mb_range_grdsamp="-R$west_grdsamp/$east_grdsamp/$south_grdsamp/$north_grdsamp"

	#echo grdsamp range is $mb_range_grdsamp
	x_diff_grdsamp=$(echo "$east_grdsamp - $west_grdsamp" | bc -l)
	y_diff_grdsamp=$(echo "$north_grdsamp - $south_grdsamp" | bc -l)

	x_dim_grdsamp=$(echo "$x_diff_grdsamp / $target_res" | bc -l)
	y_dim_grdsamp=$(echo "$y_diff_grdsamp / $target_res" | bc -l)
	x_dim_int_grdsamp=$(echo "($x_dim_grdsamp+0.5)/1" | bc)
	y_dim_int_grdsamp=$(echo "($y_dim_grdsamp+0.5)/1" | bc)
	#echo x_dim_int_grdsamp is $x_dim_int_grdsamp
	#echo y_dim_int_grdsamp is $y_dim_int_grdsamp

	#bathy surf to target res factor
	bs_target_factor=$(echo "$bs_res / $target_res" | bc -l)
	bs_target_factor_int=$(echo "($bs_target_factor+0.5)/1" | bc)

	#echo bs_target_factor_int is $bs_target_factor_int

	#############################################################################
	#############################################################################
	#############################################################################
	######################      Topo Guide     		  ###########################
	#############################################################################
	#############################################################################
	#############################################################################

	#Create Topo Guide for 1/9th Arc-Sec Topobathy DEMs
	#This adds in values of -0.1 to constain interpolation in inland areas without data.
	#if [[ "$target_res" = 0.00003086420 ]]
	if [[ "$target_res" = 0.00003086420 ]]
		then 
		echo -- Creating Topo Guide...
		#Add on 6 more cells just to make sure there is no edge effects when burnining in shp.
		x_min=$(echo "$west_grdsamp - $six_cells_target" | bc -l)
		x_max=$(echo "$east_grdsamp + $six_cells_target" | bc -l)
		y_min=$(echo "$south_grdsamp - $six_cells_target" | bc -l)
		y_max=$(echo "$north_grdsamp + $six_cells_target" | bc -l)

		echo -- Clipping coastline shp to grid extents
		ogr2ogr $name"_coast.shp" $coastline_full".shp" -clipsrc $x_min $y_min $x_max $y_max

		echo -- Rasterizing Inverse Polygon
		gdal_rasterize -burn 1 -i -l $name"_coast" $name"_coast.shp" $name"_coast.tif" -tr 0.00009259259 0.00009259259 -te $x_min $y_min $x_max $y_max

		echo -- Re-polygonizing raster
		gdal_polygonize.py $name"_coast.tif" -8 -f "ESRI Shapefile" $name"_coast_rc.shp"
		
		echo -- Selecting Land
		poly_var=$(basename $name"_coast_rc" .shp)
		poly_var_shp=$(basename $name"_coast_rc" .shp)".shp"
		final_poly_shp=$(basename $name"_coast_rc" .shp)"_land.shp"
		ogr2ogr -dialect SQLITE -sql "SELECT * FROM '$poly_var' WHERE DN='1'" $final_poly_shp $poly_var_shp

		rm $name"_coast.tif"

		rm $(basename $name"_coast_rc" .shp)".shp"
		rm $(basename $name"_coast_rc" .shp)".dbf"
		rm $(basename $name"_coast_rc" .shp)".shx"
		rm $(basename $name"_coast_rc" .shp)".prj"

		echo -- Densifying Coastline Shapefile
		#ogr2ogr -f "ESRI Shapefile" -segmentize 0.000001 tmp.shp $name"_coast.shp"
		#less dense so that it doesn't crash
		ogr2ogr -f "ESRI Shapefile" -segmentize 0.00001 tmp.shp $(basename $name"_coast_rc" .shp)"_land.shp"
		#even less dense so it doesn't override bathy data
		#ogr2ogr -f "ESRI Shapefile" -segmentize 0.0001 tmp.shp $(basename $name"_coast_rc" .shp)"_land.shp"

		mv $(basename $name"_coast_rc" .shp)"_land.shp" coast_shp/$(basename $name"_coast_rc" .shp)"_land.shp"
		mv $(basename $name"_coast_rc" .shp)"_land.dbf" coast_shp/$(basename $name"_coast_rc" .shp)"_land.dbf"
		mv $(basename $name"_coast_rc" .shp)"_land.shx" coast_shp/$(basename $name"_coast_rc" .shp)"_land.shx"
		mv $(basename $name"_coast_rc" .shp)"_land.prj" coast_shp/$(basename $name"_coast_rc" .shp)"_land.prj"

		echo -- Converting to CSV
		ogr2ogr -f CSV -dialect sqlite -sql "select AsGeoJSON(geometry) AS geom, * from tmp" tmp.csv tmp.shp
		echo -- Formatting XYZ
		#original
		#sed 's/],/\n/g' tmp.csv | sed 's|[[]||g' | sed 's|[]]||g' | sed 's/}","0"//g' | sed 's/geom,DN//g' | sed 's/"{""type"":""Polygon"",""coordinates""://g' | sed '/^$/d' | sed 's/$/,-0.1/' > topo_guide/$name"_tguide.xyz"
		#after editing coastline shp, above no longer worked.
		#editted below to work with edited coastline shp
		#sed 's/],/\n/g' tmp.csv | sed 's|[[]||g' | sed 's|[]]||g' | sed 's/}","0"//g' | sed 's/geom,DN//g' | sed 's/"{""type"":""Polygon"",""coordinates""://g' | sed '/^$/d' | sed 's/$/,-0.1/' | awk -F, '{print $1,$2,$4}' | awk '{if (NR!=1) {print}}' > topo_guide/$name"_tguide.xyz"
		#editted again below to work with edited coastline shp
		sed 's/],/\n/g' tmp.csv | sed 's|[[]||g' | sed 's|[]]||g' | sed 's/}","0"//g' | sed 's/geom,DN//g' | sed 's/"{""type"":""Polygon"",""coordinates""://g' | sed '/^$/d' | sed 's/$/,-0.1/' | awk 'NR > 2 { print }' | sed '$d' > topo_guide/$name"_tguide.xyz"
		rm tmp.shp
		rm tmp.dbf
		rm tmp.prj
		rm tmp.shx
		rm tmp.csv

		echo -- Creating Datalist for Topo Guide
		cd topo_guide
		ls *.xyz > temp
		awk '{print $1, 168}' temp > topo_guide.datalist
		rm temp
		mbdatalist -F-1 -Itopo_guide.datalist -O -V
		#
		echo
		echo "All done"
		cd .. 

	else
		echo "DEM is bathy 1/3rd, no need for topo guide"
	fi

	done

else
	help
fi
