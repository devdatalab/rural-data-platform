# Master build management file for rural data portal datasets.

##########
# CONFIG #
##########

# imports
import os

# set master config file with paths and globals
configfile: 'config/config.yaml'

# pull paths from ENV vars
# FIXME: elegantly pull env vars to snakefile
envvars:
    'IEC',
    'IEC1',
    'TMP'
    
# set paths, leveraging settings in the config file
CODE=os.path.expanduser(config['globals']['pcode'])
DATA=os.path.expanduser(config['globals']['pdata'])
SHRUG=os.path.expanduser(config['globals']['shrug'])
AG=os.path.expanduser(config['globals']['ag'])
MINOR=os.path.expanduser(config['globals']['minor'])
MBTOKEN=os.path.expanduser(config['globals']['mb_token'])
TMP=os.path.expanduser(os.environ['TMP'])
IEC=os.path.expanduser(os.environ['IEC'])
IEC1=os.path.expanduser(os.environ['IEC1'])


#########
# RULES #
#########

# master rule to define the final output
rule all:
    input:
        f'{TMP}/tileset_push.log',
        '~/ddl/ddl-web/main/static/main/assets/other/rural_portal_metadata.js',
        f'{TMP}/canal-command.mbtiles'

# creation of tabular shrid and district datasets
rule create_shrid_district_portal_data:
    input:
        f'{SHRUG}/data/shrug_pc11_pca.dta',
        f'{SHRUG}/data/shrug_pc11_vd.dta',
        f'{SHRUG}/data/shrug_ec13.dta',
        f'{SHRUG}/data/shrug_secc.dta',
        f'{IEC}/canals/clean/evi_ndvi_shrid_clean.dta',
        f'{AG}/gaez/high-rain-fed.dta',
        f'{AG}/gaez/low-rain-fed.dta',
        f'{AG}/gaez/intermediate-gravity.dta',
        f'{MINOR}/distances/shrid_distances.dta',
        f'{IEC}/canals/clean/shrid_command_distances.dta',
        f'{SHRUG}/keys/shrug_pc11_district_key.dta',
        f'{IEC}/canals/clean/mic5_district_data.dta',
        f'{SHRUG}/keys/shrug_names.dta',
        f'{CODE}/b/create_shrid_district_portal_data.do'
    output:
        f'{IEC}/rural_platform/shrid_data.dta',
        f'{IEC}/rural_platform/district_data.dta'
    shell: f'stata -b {CODE}/b/create_shrid_district_portal_data.do'

# create JSON metadata
rule create_json_metadata:
    input:
        rules.create_shrid_district_portal_data.output,
        f'{CODE}/config/config.yaml',
        f'{CODE}/b/create_json_metadata.py'
    output:
        '~/ddl/ddl-web/main/static/main/assets/other/rural_portal_metadata.js'
    shell: f'python {CODE}/b/create_json_metadata.py'

# simplify shapefiles 
rule simplify_shapes:
    input:
        f'{IEC1}/gis/pc11/pc11-district.shp',
        f'{IEC1}/gis/shrug/shrids.shp',
        f'{CODE}/b/simplify_shapes.py'
    output:
        f'{IEC}/rural_platform/shrids-simplified.shp',
        f'{IEC}/rural_platform/districts-simplified.shp',
    conda: 'config/portal_spatial.yaml'
    shell: f'python {CODE}/b/simplify_shapes.py'
           
# creation of geojson from tabular district and shrid data
rule shrid_dist_to_geojson:
    input:
        rules.create_shrid_district_portal_data.output,        
        rules.simplify_shapes.output,        
        f'{CODE}/b/shrid_dist_to_geojson.py'
    output:
        f'{IEC}/rural_platform/district.geojson',
        f'{IEC}/rural_platform/shrid.geojson'
    conda: 'config/portal_spatial.yaml'
    shell: f'python {CODE}/b/shrid_dist_to_geojson.py '

# creation of vector tileset from geojson
rule create_vector_tileset:
    input:
        rules.shrid_dist_to_geojson.output,
        f'{CODE}/b/create_vector_tileset.sh'
    output: f'{TMP}/rural_portal_data.mbtiles'
    shell: '{CODE}/b/create_vector_tileset.sh'
        
# export GEOJSON canal command area and line shapes for use in scrolly
rule prep_canal_command_geojson:
    input:
        f'{IEC}/canals/clean/command_areas.shp',
        f'{IEC}/canals/raw/wris/canal_line.shp',
        f'{CODE}/b/prep_canal_command_geojson.py'
    output:
        f'{TMP}/canal_lines.geojson',
        f'{TMP}/command_areas.geojson'
    shell: f'python {CODE}/b/prep_canal_command_geojson.py'
        

# creation of command area / canal lines tileset for scrollyteller
rule create_command_tileset:
    input:
        rules.prep_canal_command_geojson.output,
        f'{CODE}/b/create_command_tileset.sh'
    output: f'{TMP}/canal-command.mbtiles'
    shell: '{CODE}/b/create_command_tileset.sh'

# upload of mbtiles to mapbox studio
rule push_vector_tileset:
    input:
        rules.create_vector_tileset.output,
        f'{CODE}/b/push_vector_tileset.py',
    log: f'{TMP}/tileset_push.log'
    conda: 'config/portal.yaml'
    shell: f'python {CODE}/b/push_vector_tileset.py --file {rules.create_vector_tileset.output} --token {MBTOKEN} > {{log}}'


########
# TODO #
########

# push_public_data.py - take all atlas data as well as all additional data (e.g. CoC) and:
#  - zip sensibly
#  - push to AWS for download by users

# add cost of cultivation data
# this build file needs to be written (b/create_cost_of_cultivation_portal_data.do)




############
# COMMANDS #
############

# running
#snakemake --cores 7 --use-conda
#snakemake --cores 7

# dry run:
#snakemake -n

# viewing DAG:
#snakemake --forceall --dag | dot -Tpdf > ~/public_html/png/dag.pdf
#snakemake --forceall --rulegraph | dot -Tpdf > ~/public_html/png/dag.pdf

# Report
# note: snakemake --report ~/public_html/report.html
# viewable here: https://caligari.dartmouth.edu/~lunt/report.html
