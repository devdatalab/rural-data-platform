# convert canal-related shapefiles to geojson for uploading to mapbox studio
# these will be used in the scrollyteller

import geopandas as gpd

# set file locations
command_fn = IEC / 'canals/clean/command_areas.shp'
canal_fn = IEC / 'canals/raw/wris/canal_line.shp'
command_out = TMP / 'command_areas.geojson'
canal_out = TMP / 'canal_lines.geojson'

# read in shapes to gpd
command_shp = gpd.read_file(command_fn)
canal_shp = gpd.read_file(canal_fn)

# remove unnecessary features
command_shp = command_shp[['canal_name','comm_id','area_ha', 'geometry']]
canal_shp = canal_shp[['CANNAME','OBJECTID', 'PRJNAME','geometry']]

# codify names
command_shp.rename(columns={'canal_name':'name', 'comm_id':'id'}, inplace=True)
canal_shp.rename(columns={'CANNAME':'name', 'OBJECTID':'id','PRJNAME':'projname'}, inplace=True)

# write out geojson
command_shp.to_file(command_out, driver="GeoJSON")
canal_shp.to_file(canal_out, driver="GeoJSON")
