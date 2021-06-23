#!/bin/bash
function help () {
echo "create_bs- Script that creates a bathy surface at 1 arc-sec for multiple DEM tiles and resamples it to 1/3rd or 1/9th arc-sec and then converts it xyz for TBDEMs."
	echo "Usage: $0 name_cell_extents datalist coastline mb1"
	echo "* name_cell_extents: <csv file with name,target spatial resolution in decimal degrees,tile_exents in W,E,S,N>"
	echo "* datalist: <master datalist file that points to individual datasets datalists>"
	echo "* coastline: <coastline shapefile for clipping. Don't include .shp extension >"
	echo "* mb1: <use mb1 from previous one as input datalist: yes or no >"
}

#see if 3 parameters were provided
#show help if not
if [ ${#@} == 4 ]; 
	then
	mkdir -p xyz
	mkdir -p topo_guide
	mkdir -p cmd
	mkdir -p save_mb1
	mkdir -p save_datalists
	mkdir -p tifs
	mkdir -p coast_shp
	mkdir -p nan_grds

	name_cell_extents=$1
	datalist_orig=$2
	coastline_full=$3
	mb1=$4

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
	echo "Original Datalist is" $datalist_orig
	echo

	#Add on additional cells at bathy_surf resolution to ensure complete coverage of each tile and alignment with 1/9th and 1/3rd res
	west=$(echo "$west_quarter - $bs_align_cells" | bc -l)
	north=$(echo "$north_quarter + $bs_align_cells" | bc -l)
	east=$(echo "$east_quarter + $bs_align_cells" | bc -l)
	south=$(echo "$south_quarter - $bs_align_cells" | bc -l)

	#if mb1 file already exists for tile, use that. This speeds up processing time if input data files didn't change.
	if [ $mb1 = "yes" ]; then
		echo "seeing if MB1 file is available to use"
		if [ -f $"save_mb1/"$name".mb-1" ]; then
			echo "MB1 file exists, using as datalist"
			cp "save_mb1/"$name".mb-1" $name".datalist"
			datalist=$(echo $name".datalist")
		else
			echo "MB1 file doesn't exist, using orig datalist"
			cp $datalist_orig $name".datalist"
		fi

	else
		echo "MB1 paramter is NO, so using original datalist"
		cp $datalist_orig $name".datalist"
	fi

	datalist=$(echo $name".datalist")

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
	if [[ "$target_res" = 0.00003086420 && ! -e "topo_guide/"$name"_tguide.xyz" ]]
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


	#############################################################################
	#############################################################################
	#############################################################################
	######################      BATHY SURFACE    		  #######################
	#############################################################################
	#############################################################################
	#############################################################################
	#echo -- Creating interpolated DEM for tile $name
	dem_name=$name
	grid_dem=$dem_name".grd"
	echo mb_range is $mb_range
	# Run mbgrid
	echo --Running mbgrid...
	mbgrid -I$datalist -O$dem_name \
	$mb_range \
	-A2 -D$x_dim_int/$y_dim_int -G3 -N \
	-C810000000/3 -S0 -F1 -T0.25 -X0.25

	#Check to see if any valid data
	z_min=`gmt grdinfo $grid_dem | grep -e "z_min" | awk '{print $3}'`
	z_max=`gmt grdinfo $grid_dem | grep -e "z_max" | awk '{print $5}'`
	echo "z_min is" $z_min
	echo "z_max is" $z_max

	gmt grdconvert $grid_dem $grid_dem".tif"=gd:GTiff

	if [ "$z_min" = "0" ] && [ "$z_max" = "0" ]
	then
	      	echo "Tile has no data, moving to nan_grds folder..."
	      	echo -- Reclasifying any NaNs to 0s
			gdal_calc.py -A $grid_dem".tif" --outfile=$grid_dem"_zeroes.tif" --calc="nan_to_num(A)" --overwrite
	      	rm $grid_dem".tif"
	      	mv $grid_dem"_zeroes.tif" nan_grds/$grid_dem"_zeroes.tif"
	      	rm $name".mb-1"
			rm $name"_coast.shp" 
			rm $name"_coast.dbf" 
			rm $name"_coast.prj" 
			rm $name"_coast.shx"
			rm $datalist
	else
	      	echo "tile has data, keeping..."

	      	echo -- Reclasifying any NaNs to 0s
	      	gdal_calc.py -A $grid_dem".tif" --outfile=$grid_dem"_fix_nan.tif" --calc="nan_to_num(A)" --overwrite
	      	
	      	echo -- Changing any 0 or above to -0.1m
			gdal_calc.py -A $grid_dem"_fix_nan.tif" --outfile=$grid_dem"_rc.tif" --calc="-0.1*(A >= 0.0)+A*(A < 0.0)" --format=GTiff --overwrite
			rm $grid_dem".tif"
			rm $grid_dem"_fix_nan.tif"

			if [ "$bs_target_factor_int" = 9 ]
			then 
				echo "Resampling to 1/9th Resolution"
				[ -e $grid_dem"_rc_tr_tmp.tif" ] && rm $grid_dem"_rc_tr_tmp.tif"
				gdalwarp $grid_dem"_rc.tif" -r cubicspline -tr $target_res $target_res -t_srs EPSG:4269 $grid_dem"_rc_tr_tmp.tif" -overwrite
				rm $grid_dem"_rc.tif"

				#subset image
				[ -e $grid_dem"_rc_tr_tmp2.tif" ] && rm $grid_dem"_rc_tr_tmp2.tif"
				gdal_translate $grid_dem"_rc_tr_tmp.tif" -srcwin $ninth_clip_factor $ninth_clip_factor $x_dim_int_grdsamp $y_dim_int_grdsamp -a_srs EPSG:4269 -a_nodata -9999 -co "COMPRESS=DEFLATE" -co "PREDICTOR=3" -co "TILED=YES" $grid_dem"_rc_tr_tmp2.tif"
				rm $grid_dem"_rc_tr_tmp.tif"

				echo -- Changing any 0 or above to -0.1m
				gdal_calc.py -A $grid_dem"_rc_tr_tmp2.tif" --outfile=$grid_dem"_rc_tr.tif" --calc="-0.1*(A >= 0.0)+A*(A < 0.0)" --format=GTiff --overwrite
				rm $grid_dem"_rc_tr_tmp2.tif"

			else
				echo "Resampling to 1/3rd Resolution"
				#don't need to take smaller area, take full extent
				[ -e $grid_dem"_rc_tr_tmp.tif" ] && rm $grid_dem"_rc_tr_tmp.tif"
				gdalwarp $grid_dem"_rc.tif" -r cubicspline -tr $target_res $target_res -t_srs EPSG:4269 $grid_dem"_rc_tr_tmp.tif" -overwrite
				rm $grid_dem"_rc.tif"

				#subset image
				[ -e $grid_dem"_rc_tr_tmp2.tif" ] && rm $grid_dem"_rc_tr_tmp2.tif"
				gdal_translate $grid_dem"_rc_tr_tmp.tif" -srcwin $third_clip_factor $third_clip_factor $x_dim_int_grdsamp $y_dim_int_grdsamp -a_srs EPSG:4269 -a_nodata -9999 -co "COMPRESS=DEFLATE" -co "PREDICTOR=3" -co "TILED=YES" $grid_dem"_rc_tr_tmp2.tif"
				rm $grid_dem"_rc_tr_tmp.tif"

				echo -- Changing any 0 or above to -0.1m
				gdal_calc.py -A $grid_dem"_rc_tr_tmp2.tif" --outfile=$grid_dem"_rc_tr.tif" --calc="-0.1*(A >= 0.0)+A*(A < 0.0)" --format=GTiff --overwrite
				rm $grid_dem"_rc_tr_tmp2.tif"

			fi

			if [[ "$target_res" = 0.00003086420 ]]
				then 
				echo -- Bathy Surface is 1/9th arc-sec
				echo -- Masking out topo
				#Create Shp for 1/9th
				echo -- Getting the extents of the raster
				x_min_tmp=`gmt grdinfo $grid_dem"_rc_tr.tif" | grep -e "x_min" | awk '{print $3}'`
				x_max_tmp=`gmt grdinfo $grid_dem"_rc_tr.tif" | grep -e "x_max" | awk '{print $5}'`
				y_min_tmp=`gmt grdinfo $grid_dem"_rc_tr.tif" | grep -e "y_min" | awk '{print $3}'`
				y_max_tmp=`gmt grdinfo $grid_dem"_rc_tr.tif" | grep -e "y_max" | awk '{print $5}'`

				#Add on 6 more cells just to make sure there is no edge effects when burnining in shp.
				x_min=$(echo "$x_min_tmp - $six_cells_target" | bc -l)
				x_max=$(echo "$x_max_tmp + $six_cells_target" | bc -l)
				y_min=$(echo "$y_min_tmp - $six_cells_target" | bc -l)
				y_max=$(echo "$y_max_tmp + $six_cells_target" | bc -l)

				#echo $x_min $y_min $x_max $y_max
				echo -- Clipping coastline shp to grid extents
				ogr2ogr $name"_coast.shp" $coastline_full".shp" -clipsrc $x_min $y_min $x_max $y_max -overwrite

				echo -- Masking out Topo
				gdal_rasterize -burn 1 -i -l $name"_coast" $name"_coast.shp" $grid_dem"_rc_tr.tif"
			
			else
				echo -- Bathy Suface is 1/3rd arc-sec
				echo -- No topo mask needed
			fi

			echo -- Compressing tif
			gdal_translate $grid_dem"_rc_tr.tif" -a_srs EPSG:4269 -a_nodata 999999 -co "COMPRESS=DEFLATE" -co "PREDICTOR=3" -co "TILED=YES" $name"_target_res.tif"
			rm $grid_dem"_rc_tr.tif"

			#If bathy mask file exists, mask out additional topo
			if [ -f $name"_DEM_bathy_1_0.tif" ]; then
				echo "Bathy Mask exists, masking out additional topo areas"
				echo -- Masking out additional topo from DEM
				gdal_calc.py -A $name"_target_res.tif" -B $name"_DEM_bathy_1_0.tif" --outfile=$name"_target_res_final_tmp.tif" --calc="A*B"
				gdal_translate $name"_target_res_final_tmp.tif" -a_srs EPSG:4269 -a_nodata -99999 -co "COMPRESS=DEFLATE" -co "PREDICTOR=3" -co "TILED=YES" $name"_bs.tif"
				rm $name"_target_res_final_tmp.tif"
			else
				echo "Bathy Mask doesn't exist, skipping..."
				mv $name"_target_res.tif" $name"_bs.tif"
			fi

			echo -- Tiling Bathy Surface and Converting to XYZ
			#Input parameters
			input_file=${name}"_bs.tif"

			cp $input_file tifs/$input_file
			mv $name".mb-1" save_mb1/$name".mb-1"
			mv $name"_coast.shp" coast_shp/$name"_coast.shp"
			mv $name"_coast.dbf" coast_shp/$name"_coast.dbf"
			mv $name"_coast.prj" coast_shp/$name"_coast.prj"
			mv $name"_coast.shx" coast_shp/$name"_coast.shx"
			mv $datalist save_datalists/$datalist

			#Convert tif to xyz for 1/9th arc-sec
			#8112 and 2712 are both divisible by 8, create 64 tiles
			#or by 12, create 144 tiles
			tile_x_div=12
			tile_y_div=12

			###################################################################################
			###################################################################################
			#tile_x_pct_tmp=$(echo "100 / $tile_x_pct" | bc -l)
			#tile_y_pct_tmp=$(echo "100 / $tile_y_pct" | bc -l)

			#get input grid dimensions
			x_dim=`gdalinfo $input_file | grep -e "Size is" | awk '{print $3}' | sed 's/.$//'`
			y_dim=`gdalinfo $input_file | grep -e "Size is" | awk '{print $4}'`

			#calculate tile grid dimensions
			tile_dim_x_tmp=$(echo "$x_dim / $tile_x_div" | bc -l)
			tile_dim_x_int=$(echo "($tile_dim_x_tmp+0.5)/1" | bc)

			tile_dim_y_tmp=$(echo "$y_dim / $tile_y_div" | bc -l)
			tile_dim_y_int=$(echo "($tile_dim_y_tmp+0.5)/1" | bc)

			#OR, you can just manually input the number of rows/cols you want
			#tile_dim_x_int=ENTER NUMBER OF COLUMNS HERE
			#tile_dim_y_int=ENTER NUMBER OF ROWS HERE
			#Example; to create 100 tiles when original dimensions are 475100, 61450:
			
			#tile_dim_x_int=1014
			#tile_dim_y_int=1014

			echo input grid is $input_file	

			echo input grid x_dim is $x_dim
			echo input grid y_dim is $y_dim

			echo tile x_dim is $tile_dim_x_int
			echo tile y_dim is $tile_dim_y_int

			echo
			echo -- Starting Tile Analysis on 1/9th arc-sec DEMs
			echo

			#initiate tile names with numbers, starting with 1
			tile_name="1"
			#remove file extension to get basename from input file
			input_name=${input_file::-4}

			#remove existing bathy surf xyzs bc coastline may have changed
			cd xyz
			rm *$input_name*.xyz
			rm *$input_name*.xyz.inf
			cd ..

			#starting point for tiling
			xoff=0
			yoff=0

			while [ "$(bc <<< "$xoff < $x_dim")" == "1"  ]; do
			    yoff=0
			    while [ "$(bc <<< "$yoff < $y_dim")" == "1"  ]; do
			    tile_name_full=$input_name"_tile_"$tile_name".tif"
			    echo creating tile $tile_name_full
			    echo xoff is $xoff
			    echo yoff is $yoff
			    echo tile_dim_x_int is $tile_dim_x_int
			    echo tile_dim_y_int $tile_dim_y_int
			    gdal_translate -of GTiff -a_nodata 999999 -srcwin $xoff $yoff $tile_dim_x_int $tile_dim_y_int $input_file $tile_name_full -stats
			    z_min=`gmt grdinfo $tile_name_full | grep -e "z_min" | awk '{print $3}'`
			    #valid_check=
			    #check to see if tile has data, and detele if no valid values.
			    #valid_check=`gdalinfo $tile_name_full | grep -e "STATISTICS_MAXIMUM"`
			    echo "z_min is" $z_min
			    if (( $(echo "$z_min > 0" | bc -l) ));
				then
				      echo "tile has no data, deleting..."
				      rm $tile_name_full
				else
				      echo "tile has data, keeping..."
				      echo -- Converting to xyz, only keeping negative values
				      gdal_translate -of XYZ $tile_name_full $tile_name_full"_tmp.xyz"
				      awk '{if ($3 < -0.00) {printf "%.7f %.7f %.2f\n", $1,$2,$3}}' $tile_name_full"_tmp.xyz" > $tile_name_full".xyz"
				      echo -- Converted to xyz
				      rm $tile_name_full
				      rm $tile_name_full"_tmp.xyz" 
				      mv $tile_name_full".xyz" xyz/$tile_name_full".xyz"
				fi
				yoff=$(echo "$yoff+$tile_dim_y_int" | bc)
			    tile_name=$((tile_name+1))
			    done
			  xoff=$(echo "$xoff+$tile_dim_x_int" | bc)
			done
			echo -- Creating Datalist for Bathy Surface XYZ
			cd xyz/
			ls *.xyz > temp
			awk '{print $1, 168}' temp > bathy_surf.datalist
			rm temp
			mbdatalist -F-1 -Ibathy_surf.datalist -O -V
			#
			echo
			echo "All done"
			cd ..
	fi

	rm $grid_dem".tif.aux.xml"
	rm $grid_dem
	rm $name"_bs.tif"

	if [ -f $name".grd.cmd" ]; then
		echo "cmd file exists, move to subdir"
		mv $name".grd.cmd" cmd/$name".grd.cmd"
	else
		echo "cmd file didn't exist"
	fi

	done

else
	help
fi
