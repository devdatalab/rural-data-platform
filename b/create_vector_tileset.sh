#!/bin/bash

# this script takes geojson district and shrid data and creates a vector tileset for pushing to mapbox.
# arguments passed in via Snakefile

# note: --generate-ids option is required for referencing feature ids in
# e.g. hover effects. from Mapbox: "mapbox/tippecanoe#615 adds the most
# basic --generate-ids option (using the input feature sequence for the
# ID), with the disclaimer that the IDs are not stable and that their
# format may change in the future."

# note: --simplification=10: tolerance for line and polygon simplification
#tippecanoe -o ~/Desktop/map-gl/state_dist.mbtiles --read-parallel --simplification=10 --coalesce-smallest-as-needed --detect-shared-borders --extend-zooms-if-still-dropping -z12 --generate-ids ~/Desktop/map-gl/districts.geojson ~/Desktop/map-gl/states.geojson
tippecanoe -o $1 --read-parallel --simplification=10 --coalesce-smallest-as-needed --detect-shared-borders --extend-zooms-if-still-dropping -z12 --generate-ids $2 $3
