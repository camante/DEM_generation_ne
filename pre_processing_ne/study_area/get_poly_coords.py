# Import arcpy module
import arcpy
# Local variables:
fcl = "F:\\COASTAL_Act\\camante\\ne\\manual\\data\\study_area\\ne_tiles.shp"

desc = arcpy.Describe(fcl)
shapefieldname = desc.ShapeFieldName

gebieden = arcpy.UpdateCursor(fcl)

coords=[]
coords_all=[]
for gebied in gebieden:
    polygoon = gebied.getValue(shapefieldname)
    name=gebied.getValue('NAME')
    res_name=gebied.getValue('res')
    if res_name == "1_3":
        res_tmp=0.00009259259
        res=format(res_tmp, '.11f')
    else:
        res_tmp=0.00003086420
        res=format(res_tmp, '.11f')
    #print "Tile name is ", name
    coords_x=[]
    coords_y=[]
    for punten in polygoon:
        for punt in punten:
            #print punt.X, punt.Y
            coords_x.append(punt.X)
            coords_y.append(punt.Y)
    west=min(coords_x)
    east=max(coords_x)
    south=min(coords_y)
    north=max(coords_y)
    print str(name)+"_"+str(res_name) + "," + res + "," + str(west)+ "," + str(east) + "," + str(south) + "," + str(north)


