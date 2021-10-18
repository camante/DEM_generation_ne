#!/bin/bash -e

function help () {
echo "spatial_meta.sh - Script that creates spatial metadata for a DEM"
	echo "Usage: $0 name_cell_extents datalist sm_res year version"
	echo "* name_cell_extents: <csv file with name,target spatial resolution in decimal degrees,tile_exents in W,E,S,N>"
	echo "* datalist: <master datalist file that points to individual datasets datalists>"
	echo "* sm_res: <spatial metadata output resolution>
	0.1111111111s = 1/9th arc-second 
	0.3333333333s = 1/3rd arc-second
	1s = 1 arc-second"
	echo "* year: <year of generation>"
	echo "* version: <version of tile>"
}

#see if 5 parameters were provided
#show help if not
if [ ${#@} == 5 ]; 
then
name_cell_extents=$1
datalist=$2
sm_res=$3
year=$4
version=$5

# Get Tile Name, Cellsize, and Extents from name_cell_extents.csv
IFS=,
sed -n '/^ *[^#]/p' $name_cell_extents |
while read -r line
do
name=$(echo $line | awk '{print $1}')
cellsize_degrees=$(echo $line | awk '{print $2}')
west_quarter=$(echo $line | awk '{print $3}')
east_quarter=$(echo $line | awk '{print $4}')
south_quarter=$(echo $line | awk '{print $5}')
north_quarter=$(echo $line | awk '{print $6}')

echo
echo "Tile Name is" $name
echo "Cellsize in degrees is" $cellsize_degrees
echo "West is" $west_quarter
echo "East is" $east_quarter
echo "South is" $south_quarter
echo "North is" $north_quarter
echo


#############################################################################
#############################################################################
#############################################################################
######################      DERIVED VARIABLES     ###########################
#############################################################################
#############################################################################
#############################################################################
#Expand DEM extents by 6 cells to provide overlap between tiles
#six_cells_target=$(echo "$cellsize_degrees * 6" | bc -l)
#echo six_cells_target is $six_cells_target
#west=$(echo "$west_quarter - $six_cells_target" | bc -l)
#north=$(echo "$north_quarter + $six_cells_target" | bc -l)
#east=$(echo "$east_quarter + $six_cells_target" | bc -l)
#south=$(echo "$south_quarter - $six_cells_target " | bc -l)

#Take in a half-cell on all sides so that grid-registered raster edge aligns exactly on desired extent
#Don't need to do because Matt's script has a cell-registered option
# half_cell=$(echo "$cellsize_degrees / 2" | bc -l)
# #echo half_cell is $half_cell
# west_reduced=$(echo "$west + $half_cell" | bc -l)
# north_reduced=$(echo "$north - $half_cell" | bc -l)
# east_reduced=$(echo "$east - $half_cell" | bc -l)
# south_reduced=$(echo "$south + $half_cell" | bc -l)

#echo "West_reduced is" $west_reduced
#echo "East_reduced is" $east_reduced
#echo "South_reduced is" $south_reduced
#echo "North_reduced is" $north_reduced
#range=$west_reduced/$east_reduced/$south_reduced/$north_reduced


#range=$west/$east/$south/$north
range=$west_quarter/$east_quarter/$south_quarter/$north_quarter

#Determine number of rows and columns with the desired cell size, rounding up to nearest integer.
#i.e., 1_9 arc-second
north_degree=${north_quarter:0:2}
north_decimal=${north_quarter:3:2}
west_degree=${west_quarter:1:2}
west_decimal=${west_quarter:4:2}

if [ -z "$north_decimal" ]
then
	north_decimal="00"
else
	:
fi

size=${#north_decimal}
#echo "Number of North decimals is" $size
if [ "$size" = 1 ]
then
	north_decimal="$north_decimal"0
else
	:
fi

if [ -z "$west_decimal" ]
then
	west_decimal="00"
else
	:
fi

size=${#west_decimal}
#echo "Number of West decimals is" $size
if [ "$size" = 1 ]
then
	west_decimal="$west_decimal"0
else
	:
fi

#echo
#echo "Input Tile Name is" $basename_
#echo "Cellsize in degrees is" $cellsize_degrees

if [ "$cellsize_degrees" = 0.00003086420 ]
then
	cell_name=19
	#cellsize_degrees=0.1111111111s
	extend=2:0
elif [ "$cellsize_degrees" = 0.00009259259 ]
then
	cell_name=13
	#cellsize_degrees=0.3333333333s
	extend=6:0
else
	cell_name=unknown_cellsize
	extend=0:0
fi

#test
#extend=

echo "Starting Spatial Metadata Generation"
output_name="ncei"$cell_name"_n"$north_degree"x"$north_decimal"_w0"$west_degree"x"$west_decimal"_"$year"v"$version
echo "Output name is:"$output_name
echo "Command is: waffles -R $range -E $sm_res -V -O $output_name -M spat-meta $datalist -P 4269 -X $extend"

waffles -R $range -E $sm_res -V -O $output_name -M spat-meta $datalist -P 4269 -X $extend

echo
echo "Command used: waffles -R $range -E $sm_res -V -O $output_name -M spat-meta $datalist -P 4269 -X $extend"
echo
echo "Completed Spatial Metadata for " $output_name

echo "Checking for existing tiles"
./update_tile_version_sm.sh $output_name $year

done

else
	help
fi

