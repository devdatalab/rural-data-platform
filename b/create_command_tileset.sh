#!/bin/bash

# separate tileset of command areas and canal lines
# this will be used in the scrollytelling map

tippecanoe --force z12 -Z4 -o $TMP/canal-command.mbtiles --read-parallel --simplification=10 --coalesce-smallest-as-needed --detect-shared-borders --generate-ids $TMP/canal_lines.geojson $TMP/command_areas.geojson

