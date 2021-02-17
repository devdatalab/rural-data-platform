#!/usr/bin/env Rscript
# this needs to be called from the command line, e.g.:
# simplify_shape.r –i=~/iec/gis/pc11/pc11-district.shp –out=~/iec/rural_platform/dist-simplified.shp

# create parser object
parser <- ArgumentParser()

# specify our desired options 
# by default ArgumentParser will add an help option 
parser$add_argument("-i", "--input", help="Define input shapefile for simplification")
parser$add_argument("-o", "--output", help="Define output file location for simplified shapefile")
parser$add_argument("-k", "--keep", type="float", default=0.01)
parser$add_argument("-w", "--weighting", type="float", default=0.95)

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults, 
args <- parser$parse_args()

# spatial dependencies
library(rgdal)
library(raster)
library(rmapshaper)

# read in shapefile
in_shp <- shapefile(input)

# simplify shapefiles as defined
simp_shp <- ms_simplify(state_shp, keep = keep, weighting = weight)

# now write simplified states. remove old state shapefile and write
if (file.exists(output))
    print("WARNING: overwriting previous file")
shapefile(in_shp, filename=output, overwrite=TRUE)
#writeOGR(obj=simp_shp, , driver="ESRI Shapefile")
