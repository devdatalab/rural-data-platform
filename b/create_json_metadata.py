# prepare JSON blob with specific shape to automate the
# construction of the navbar in the web app. 

# imports
import sys, os, importlib
from pathlib import Path
import pandas as pd
import json
import re
import warnings

# ddlpy imports
from ddlpy.utils.tools import process_yaml_config
from ddlpy.utils.constants import TMP

# FIXME PULL FROM CONFIG.YAML INSTEAD: paths hack
pdata = Path(os.path.expanduser('~/iec/rural_platform'))

# FIXME PULL FROM CONFIG.YAML INSTEAD: set output JSON file location
web_out = Path(os.path.expanduser('~/ddl/ddl-web')) / 'main/static/main/assets/other/rural_portal_metadata.js'


############
# Preamble #
############

# set analysis vars 
config = process_yaml_config("~/ddl/rural-data-platform/config/config.yaml")
meta_fn = os.path.expanduser(config['globals']['metadata_fn'] + '.pkl')
# all_tilevars = config['globals']['micvars'] + config['globals']['shrid_tilevars']

# read in metadata from pickled gsheet dataframe
meta = pd.read_pickle(meta_fn)


########################
# Constructed metadata #
########################

# we need functions to define the axis ticks and range for each variable.
# first, a helper program for defining scale
def get_scale(input_val):
#    print(f'inval: {input_val}')
    if input_val > 1000000:
        divisor = 1000000
        py_round = -7
        unit = "M"
    elif 3000 < input_val <= 1000000:
        divisor = 1000
        py_round = -3
        unit = "K"
    elif 300 < input_val <= 3000:
        divisor = 100
        py_round = -2
        unit = ""
    elif 10 < input_val <= 300:
        divisor = 1
        py_round = 0
        unit = ""
    elif input_val <= 10:
        divisor = .01
        py_round = 2
        unit = ""
    return [divisor, py_round, unit]

# function to get sensible upper and lower bounds for a variable
def get_bounds(varname, vardf):
    
    # summarize this variable
    top = vardf[varname].quantile(.95)
    bottom = vardf[varname].quantile(.05)

    # replace NaNs with zeroes for the time being
    if pd.isnull(top): top = 0
    if pd.isnull(bottom): bottom = 0

    # get unit scale from 95th percentile top end
    [divisor, py_round, unit] = get_scale(top)

    # if we have zero or 1 as minimum value, set lower bound to 0 
    if (vardf[varname].min() == 0) | (vardf[varname].min == 1):
        lb = 0
    else:
        lb = round(bottom, py_round)
      
    # set the upper bound. need to round in a manner that makes the
    # spread divisible by six (our number of steps in the legend)
    ubstart = round(top, py_round)
    ub = ubstart
    stop = 0
    j = 1

    # convert values to integers if necessary
    if divisor < 1:
        ubstart = int(ubstart / divisor)
        ub = int(ub / divisor)
        lb = int(lb / divisor)

    # calculate reasonable splits for the legend
    while stop == 0:
        
        # check divisibility 
        if ((ub-lb) % (6 * divisor) == 0) | ((ub-lb) % (6) == 0):
            stop = 1

        # if not, modulate. need round to eliminate floating point errors
        else:
            ub = round(ubstart + (j * divisor), py_round)
            if j < 0: j = (j * -1) + 1
            if j > 0: j = j * -1

    # return scales for small divisors
    if divisor < 1:
        ub = ub * divisor
        lb = lb * divisor

    # hardcode skewed binary vars
    if ub == 0 and lb == 0:
        ub = 1
        
    # return upper and lower bounds
    return [ub, lb]

# now a function to return an array of axis points given min/max input pairs
def gen_var_axes(minval, maxval, nticks):

    #  set step value 
    step = (maxval - minval) / nticks
        
    # if our scale top-end is over 1 million, use X.XM format
    [divisor, py_round, unit] = get_scale(maxval)

    # if we haven't assigned a string unit (e.g. "K" or "M", don't abbreviate the axis ticks)
    if unit == "": divisor = 1 
      
    # define all tick values
    tickvals = []
    for i in range(0, nticks + 1):

        # set this tick's value 
        thisval = minval + (step * i)

        # reformat number - will have max 3 leading digits, may or may not need decimals 
        fmt = '{:3.1f}'
        if thisval % divisor == 0: fmt = '{:3.0f}'
        if divisor < 1: fmt = '{:3.2f}'
        tickval = fmt.format(thisval / divisor)
        if divisor < 1:
            tickval = fmt.format(thisval)
        else:
            tickval = fmt.format(thisval / divisor)

        # strip leading spaces if there are any 
        tickval = tickval.strip()
        
        # add unit 
        tickval = f'{tickval}{unit}'

        # add "+" if this is the last tick (and not 100 - assume this is a percentage amount) 
        if (i == nticks) & (tickval != 100): tickval = f'{tickval}+'
        
        # add to dict
        tickvals.append(tickval)

    # return the complete axis ticks
    return tickvals


#################################
# Corroborate data and metadata #
#################################

# get shrid-level data - for calculating display bounds
shrid = pd.read_stata(pdata / 'shrid_data_tileset.dta')

# get district-level data
dist = pd.read_stata(pdata / 'district_data_tileset.dta')

# define helper function to fill out wildcard regex match pieces to label columns
def fill_wildcard_across_rows(search, target_col, df):
    df['tmp'] = df['varname'].str.extract(search, expand=False).fillna('').astype(str)
    tmpdf = df[df['varname'].str.contains(search, regex=True)]
    df.loc[df['varname'].str.contains(search, regex=True), target_col] = tmpdf.apply(lambda x: x[target_col].replace(re.search("\[.*\]", x[target_col]).group(0), x['tmp']), axis=1)
    df.drop('tmp', axis=1, inplace=True)

# assert that all metadata variables are present in the dist and shrid data
# note that this also expands wildcards in the metadata table
def check_cols_and_expand(df, cols, meta):

    # part out the wildcarded vars
    wildcards = [col for col in list(cols) if "[" in col]
    cols = [col.strip() for col in cols if col not in wildcards]

    # expand wildcards to match the dataframe
    for wildcard in wildcards:
        search = re.sub(r'\[.*\]', '(.*)', wildcard)
        match = df.filter(regex=search).columns
        if len(match) == 0:
            raise ValueError(f'{wildcard} was not found in the dataframe')
        else:
            # explode the list and remove string artifacts
            meta.loc[meta.varname == wildcard, 'varname'] = str(list(match))
            meta = meta.assign(varname=meta['varname'].str.split(',')).explode('varname')
            meta.varname = meta.varname.str.strip("[]").str.replace("\'", "")

            # now replace the wildcarded component
            fill_wildcard_across_rows(search=search, target_col='lab_short', df=meta)
            fill_wildcard_across_rows(search=search, target_col='lab_med', df=meta)
            fill_wildcard_across_rows(search=search, target_col='lab_long', df=meta)
            
    # now check the non-wildcarded vars
    if not set(cols).issubset(set(df.columns)):
        raise ValueError(f"{' and '.join(set(cols).difference(df.columns))} are not available in the dataframe")
    print(f'All columns are available in the dataframe')
    return meta

# run the tests on shrid and dist data
meta = check_cols_and_expand(shrid, meta.varname.dropna(), meta)
meta = check_cols_and_expand(dist, meta.varname.dropna(), meta)

# remove any leading / trailing strings in the variable name column
meta.varname = meta.varname.apply(lambda x: x.strip())


###############
# Create JSON #
###############

# initialize dict that we'll populate and write to JSON
jsonmeta = {}

# heirarchy will be: category -> variable -> variable details
# we'll loop over category then variables within that category
catlist = meta.web_cat.dropna().unique()
for cat in catlist:

    # pull list of variables within this cat
    varlist = meta[meta.web_cat == cat].varname.dropna()

    # initialize a dict for all variables in this category
    catdict = {}
    
    # loop over variables
    for var in varlist:

        # create the dictionary for this variable. initialize as empty
        vardict = {}

        # pull the row for this variable
        varrow = meta[meta.varname == var.strip()]

        # add dict values
        vardict["label_short"] = varrow["lab_short"].iloc[0]
        vardict["label_medium"] = varrow["lab_med"].iloc[0]
        vardict["label_long"] = varrow["lab_long"].iloc[0]
        vardict["colors"] = pd.eval(varrow["colors"].iloc[0])
        vardict["suffix"] = varrow["suffix"].iloc[0]
        vardict["unit"] = varrow["unit"].iloc[0]
        vardict["source"] = varrow["source"].iloc[0]

        # ids just prepend shrid and dist levels to varname in list
        vardict["ids"] = [f"shrid-{var}", f"district-{var}"]

        # get district and shrid upper- and lower-bounds for this variable from the raw data
        [d_ub, d_lb] = get_bounds(var, dist)
        [s_ub, s_lb] = get_bounds(var, shrid)
        vardict["stops"] = {"district": [str(d_lb), str(d_ub)], "shrid": [str(s_lb), str(s_ub)]}

        # axis ticks now
        d_ticks = gen_var_axes(d_lb, d_ub, 6)
        s_ticks = gen_var_axes(s_lb, s_ub, 6)
        vardict["axes"] = {"district": d_ticks, "shrid": s_ticks}

        # now that we have the variable dict, add it to the category dict
        catdict[var] = vardict

    # add the contents of this category to the JSON blob
    jsonmeta[cat] = catdict


###############
# Export JSON #
###############

# get string with all double quotes
jsonmeta = json.dumps(jsonmeta)

# alright, we've got our JSON! package it up into a JS object 
meta_out = f'portalMeta = `[{jsonmeta}]`;'

# write it out
text_file = open(web_out, "w")
text_file.write(meta_out)
text_file.close()

# notify
print(f'JSON metadata written to JS object at: {web_out}')
print("WARNING: now you need to manually push changes in the ddl-web repository")
