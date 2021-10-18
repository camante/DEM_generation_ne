mkdir -p v2_v1_diff

for i in *v2.tif;
do
	echo "Version 2 is" $i
	input_tile_base=${i%_*}
	v1_path=/media/sf_F_win_lx/COASTAL_Act/camante/tx_w_la/data/previous_version_grids/ncei/TX_2017/
	#echo "Input tile base is" $input_tile_base
	v1=$v1_path$input_tile_base"_2017v1.tif"
	echo "Version 1 is" $v1
	echo "Calculating Difference between V2 and V1"
	output="v2_v1_diff/"$input_tile_base"_v2_v1_diff.tif"
	echo "Output is" $output
	gdal_calc.py -A $i -B $v1 --calc="A-B" --outfile=$output --overwrite
	echo
done


cd v2_v1_diff
echo "Computing Final Stats"
rm -f minmax.csv
echo "Creating inf files"
datalists *.tif -r
for i in *.inf; 
do 
	minmax.py $i 
done
