#!/bin/bash

# this script takes geojson district and shrid data and creates a vector tileset for pushing to mapbox.
# this requires tippecanoe and tile-join, which are installed in ~/iec/local/share/tippecanoe/

# note: --generate-ids option is required for referencing feature ids in
# e.g. hover effects. from Mapbox: "mapbox/tippecanoe#615 adds the most
# basic --generate-ids option (using the input feature sequence for the
# ID), with the disclaimer that the IDs are not stable and that their
# format may change in the future."

# note: --simplification=10: tolerance for line and polygon simplification
#tippecanoe --force -o $1 --read-parallel --simplification=10 --coalesce-smallest-as-needed --detect-shared-borders --extend-zooms-if-still-dropping -z9 --generate-ids $2 $3 
#tippecanoe --force -zg --minimum-zoom=5 -o $1 --read-parallel --simplification=10 --coalesce-smallest-as-needed --detect-shared-borders --extend-zooms-if-still-dropping --generate-ids $2 $3 

# create district tileset with zoom range of 5-8
tippecanoe --force -z9 -Z5 -o $TMP/dist_tile_tmp.mbtiles --read-parallel --simplification=5 --coalesce-smallest-as-needed --detect-shared-borders --generate-ids $IEC/rural_platform/district.geojson

# create shrid tileset with zoom range of 8-10
tippecanoe --force -z10 -Z9 -o $TMP/shrid_tile_tmp.mbtiles --read-parallel --simplification=20 --coalesce-smallest-as-needed --detect-shared-borders --generate-ids $IEC/rural_platform/shrid.geojson

# merge tilesets
tile-join --force -o $TMP/rural_portal_data.mbtiles $TMP/dist_tile_tmp.mbtiles $TMP/shrid_tile_tmp.mbtiles
