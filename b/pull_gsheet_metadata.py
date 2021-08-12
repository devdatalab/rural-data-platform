# imports
import sys, os, importlib
from pathlib import Path
import pandas as pd
import requests

# ddlpy imports
from ddlpy.utils.tools import process_yaml_config
from ddlpy.utils.constants import TMP

# settings from config.yaml
config = process_yaml_config("~/ddl/rural-data-platform/config/config.yaml")
gsheet_path = os.path.expanduser(config['globals']['metadata_fn'])

# retrive get the google sheet download endpoint
gsheet_endpoint = config['globals']['arddp_gsheet']

# pull down google metadata sheet that contains variable specifications
dict_out = TMP / 'dict_tmp.csv'
req = requests.get(gsheet_endpoint)
open(dict_out , 'wb').write(req.content)

# read in the minimally cleaned metadata table and drop blank rows
meta = pd.read_csv(dict_out, skiprows=1)
meta = meta.dropna(how = 'all')

# remove explanatory / non-data rows
meta = meta[meta['varname'].str.contains('^[#]+') == False]

# replace nans with empty strings
meta.fillna('', inplace=True)

# assert variable name is unique in the table
if not meta.varname.dropna().is_unique:
    raise ValueError("input metadata has duplicate entries in the varname column")

# pickle for preservation of variable formatting
meta.to_pickle(gsheet_path + '.pkl')

# replace bracketed wildcards with * for stata processing
meta = meta.replace(to_replace ='\[.*\]', value = '*', regex = True) 

# keep only variable names for determining varlist in DTA build
meta = meta[['varname', 'aggmethod', 'web_cat']]
meta.to_stata((gsheet_path + '.dta'), write_index=False)
