import topojson as tp
import geopandas as gpd

# paths hack
from pathlib import Path
import os
IEC1 = Path(os.environ.get('IEC1'))
IEC = Path(os.environ.get('IEC'))

# set paths
dist_in = IEC1 / 'gis/pc11/pc11-district-simplified.shp'
shrid_in = IEC1 / 'gis/shrug/shrids_corrected.shp'
dist_out = IEC / 'rural_platform/districts-simplified.shp'
shrid_out = IEC / 'rural_platform/shrids-simplified.shp'

# read in shapefiles
dist_shp = gpd.read_file(dist_in)
shrid_shp = gpd.read_file(shrid_in)

# run the simplifications using topojson package
dist_simp = tp.Topology(dist_shp, toposimplify=.1)
# FIXME: hack to fast-track around simplification
#shrid_simp = tp.Topology(dist_simp_shp, toposimplify=.1)

# convert back to geodataframe for writing to shp
# (not too worried about preserving topology as tippecanoe recreates it)
dist_gdf = dist_simp.to_gdf()
#shrid_gdf = shrid_simp.to_gdf()

# write out new shapefiles
dist_gdf.to_file(dist_out)
# FIXME: hack to fast-track around simplification
#shrid_gdf.to_file(shrid_out)
shrid_shp.to_file(shrid_out)
