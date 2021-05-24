#!/usr/bin/python
import json
import sys

inf_file = sys.argv[1]
file = open("minmax.csv", "a") 
with open(inf_file, 'r') as inf:
    mm = json.load(inf)
name = mm['name']
min_z = mm['minmax'][4]
max_z = mm['minmax'][5]
print(name, min_z, max_z)

file.write(str(name) + ','+ "{:.2f}".format(min_z) + ',' + "{:.2f}".format(max_z)) 
file.write('\n')

file.close() 
