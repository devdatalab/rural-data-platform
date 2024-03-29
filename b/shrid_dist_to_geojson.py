# take DTA data and joins with shapefiles for both shrid and dist
# outputs geojson, which will then be merged into a tileset using tippecanoe
# depends on py_spatial env (run from snakemake)


############
# Preamble #
############

# imports
import sys, os, importlib
import geopandas as gpd
import pandas as pd

# ddlpy imports
from ddlpy.geospatialtools.utils import import_vector_data

def import_tabular_data(fp):
    """
    Reads in tabular data with file extension checks
    fp: filepath for datafile to be imported, must bs shp/csv/dta/excel
    """
    # expand data filepath
    fp = os.path.expanduser(fp)

    # assert that the data file exists
    if not os.path.isfile(fp):
        raise OSError("Input file not found")

    # ensure that the data file is a readable format
    fp_ext = os.path.splitext(fp)[1]
    if fp_ext not in [".csv", ".dta", ".xls", ".xlsx"]:
        raise ValueError("Data must be .dta, .csv, .xlsx/.xls format")

    # read in csv
    if fp_ext == ".csv":
        target_df = pd.read_csv(fp)

    # read in excel
    if fp_ext in [".xls", "xlsx"]:
        target_df = pd.read_excel(fp)

    # read in dta
    if fp_ext == ".dta":
        target_df = pd.read_stata(fp)

    return target_df

# function to merge tabular data with a shapefile / gdf object
def table_geodataframe_join(poly_in, join_id, fp_table, fp_out=""):

    # expand filepaths
    fp_table = os.path.expanduser(fp_table)
    fp_out = os.path.expanduser(fp_out)

    # assert that the filepaths exist
    if not os.path.isfile(fp_table):
        raise OSError("Tabular data file not found")

    # read in the tabular data
    tab_data = import_tabular_data(fp_table)

    # execute the merge
    joined = poly_in.merge(tab_data, on=join_id, how='left')

    # convert any categorical columns to string (breaks to_file gpd method)
    for column in joined.select_dtypes(include='category').columns: joined[column] = joined[column].astype('string') 

    # write to geojson in desired location
    joined.to_file(fp_out, driver="GeoJSON")

    
##############
# Shrid data #
##############

# read in shrid shapefile
shrid_poly = import_vector_data('~/iec/rural_platform/shrids-simplified.shp')

# remove unnecessary fields to lighten the vector tileset
shrid_clean = shrid_poly.drop(columns=['pc11_s_id', 'pc11_d_id', 'pop_match', 'quality', 'PolygonTyp', 'point_lat', 'point_lon', 'LargePoly'])

# run the join
print("initiating shrid-level join")
table_geodataframe_join(poly_in=shrid_clean, join_id='shrid', fp_table='~/iec/rural_platform/shrid_data_tileset.dta', fp_out=os.path.expanduser('~/iec/rural_platform/shrid.geojson'))


#################
# District data #
#################

# read in district shapefile
dist_poly = import_vector_data('~/iec/rural_platform/districts-simplified.shp')

# remove unnecessary fields to lighten the vector tileset
dist_clean = dist_poly.drop(columns=['pc11_s_id'])

# run the join
print("initiating district-level join")
table_geodataframe_join(poly_in=dist_clean, join_id='pc11_d_id', fp_table='~/iec/rural_platform/district_data_tileset.dta', fp_out=os.path.expanduser('~/iec/rural_platform/district.geojson'))

