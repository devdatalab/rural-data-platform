#!/bin/bash

# separate tileset of command areas and canal lines
# this will be used in the scrollytelling map

~/iec/local/share/tippecanoe/tippecanoe -o $TMP/canal-command.mbtiles --force z12 -Z4 --read-parallel --simplification=10 --coalesce-smallest-as-needed --detect-shared-borders --generate-ids $TMP/canal_lines.geojson $TMP/command_areas.geojson

