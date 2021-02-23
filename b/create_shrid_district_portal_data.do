/* assemble data for agricultural rural development platform */

/* FIXME:
TODOS:
- all fixmes below
- pull aggregation method and weights from google sheet https://docs.google.com/spreadsheets/d/1bmEtcyxhiPdZDxWY8yySJT8FUrmNxLtlmKZhEcAUc70/edit#gid=1517113052
  - note google sheet parsing method is also used in create_json_metadata as well
*/

/************/
/* PREAMBLE */
/************/

/* pull project globals and settings from config.yaml */
process_yaml_config ~/ddl/rural-data-platform/config/config.yaml

/* pull variable list from the gsheet metadata previously processed */
use $metadata_fn, clear
levelsof varname, local(varlist)

/* eliminate the compound quotes and classify variable types */
global all_tilevars
global meanvars
global maxvars
global sumvars
foreach var in `varlist' {
    /* add to complete varlist */
    global all_tilevars $all_tilevars `var'

    /* check aggregation method */
    levelsof aggmethod if varname == "`var'", local(aggmethod)
    if `aggmethod' == "sum" global sumvars $sumvars `var'
    if `aggmethod' == "mean" global meanvars $meanvars `var'
    if `aggmethod' == "max" global maxvars $maxvars `var'
}

/* shorten SHRIC descriptions for web */
use $shrug/keys/shric_descriptions.dta, clear
replace shric_desc = "Spinning, weaving, and finishing of textiles" if shric == 50
replace shric_desc = "Pipeline transport" if shric == 55
replace shric_desc = "Miscellaneous manufacturing" if shric == 72
replace shric_desc = "Miscellaneous business services" if shric == 87
save $tmp/shric_descriptions_amended.dta, replace



/*******************/
/* HELPER PROGRAMS */
/*******************/

/* helper program for % formatting */
cap prog drop convert_to_percentage
prog def convert_to_percentage

  /* takes a list of variables as input */
  syntax varlist
  
  /* format pctage vars to 0-100 with a single decimal place */
  foreach var in `varlist'  {
    assert inrange(`var', 0, 1) if !mi(`var')
    replace `var' = round(100 * `var', 0.1)
    assert inrange(`var', 0, 100) if !mi(`var')
  }
end

/* define prog for getting top 3 shrics at different levels */
cap prog drop get_top_shrics
prog def get_top_shrics
  {

    /* syntax */
    syntax anything

    /* pull first word from input level (e.g. district_name state_name will become district) */
    local savename = subinstr("`anything'", "_", " ", .)
    local savename : word 1 of `savename'
    
    /* rename input (spatial var) for clarity) */
    local spatial `anything'

    /* reshape long */
    reshape long ec13_s, i(`spatial') j(sector)

    /* rank the products within districts */
    gen minusemp = -ec13_s
    bys `spatial' (minusemp): gen rank = _n
    drop minusemp

    /* keep top 3 sectors */
    keep if inrange(rank, 1, 3)

    /* drop if a rank has zero employment */
    drop if ec13_s == 0

    /* create new variables for these sectors */
    forval i = 1/3 {
      bys `spatial': gen sector`i' = sector if rank == `i'
      bys `spatial' (sector`i') : replace sector`i' = sector`i'[_n-1] if missing(sector`i') 
    }

    /* reduce back to uniqueness */
    keep if rank == 1
    drop ec13_s sector rank

    /* merge in shric descriptions for top 3 industries */
    forval i = 1/3 {
      gen shric = sector`i'
      merge m:1 shric using $tmp/shric_descriptions_amended.dta
      assert _merge != 1 if !mi(sector`i')
      drop if _merge == 2
      drop _merge
      drop sector`i'
      ren shric_desc sector`i'
      drop shric
    }

    /* save to $tmp for future merging */
    save $tmp/`savename'_json_shrics, replace
  }
end


/**********/
/* SHRICS */
/**********/

///* bring in sector data */
//clear
//useshrug
//
///* clear obs that have no ec13 emp data */
//get_shrug_var ec13_emp_all
//drop if mi(ec13_emp_all)
//drop ec13_emp_all
//
///* get sector data */
//forval i = 1/90 {
//  get_shrug_var ec13_s`i'
//}
//
///* save as input for shrid-level stats */
//save $tmp/shric_json_input, replace
//
///* collapse to districts and save */
//get_shrug_key state_name district_name
//collapse (sum) ec13_s*, by(state_name district_name)
//
///* run the prog to get top shrics, saved to $tmp/district_json_shrics */
//get_top_shrics district_name state_name
//
///* now get top shrics at shrid level, saved to $tmp/shrid_json_shrics */
//use $tmp/shric_json_input, clear
//get_top_shrics shrid


/***************/
/* SHRID-LEVEL */
/***************/

/* pc11: Agricultural power supply and other infrastructure,  Irrigation and agricultural areas under cultivation */
/* open pca */
use $shrug/data/shrug_pc11_pca, clear

/* merge in vd */
merge 1:1 shrid using $shrug/data/shrug_pc11_vd, gen(_m_vd)

/* create total agricultural land variable */
gen pc11_vd_land_ag_tot = pc11_vd_land_misc_trcp + pc11_vd_land_nt_swn
label var pc11_vd_land_ag_tot "total agricultural land"
drop pc11_vd_land_misc_trcp pc11_vd_land_nt_swn

/* keep shrid and desired variables */
keep shrid pc11_vd_land_src_irr pc11_vd_power_agr_sum pc11_vd_power_agr_win pc11_vd_p_sch pc11_vd_m_sch pc11_vd_s_sch pc11_vd_s_s_sch pc11_vd_tar_road pc11_vd_all_hosp pc11_vd_land_ag_tot pc11_pca_tot_p _m_vd 

/* ec13: Employment in agro-processing and warehousing/storage */
merge 1:1 shrid using $shrug/data/shrug_ec13, keepusing(ec13_s5 ec13_s6 ec13_s7 ec13_s8 ec13_s9 ec13_s10 ec13_s59 ec13_emp_all) gen(_m_ec13)

/* add NIC04 descriptions to labels */
lab var ec13_s5 "Production, processing and preserving of meat and meat products"
lab var ec13_s6 "Manufacture of vegetable and animal oils and fats"
lab var ec13_s7 "Manufacture of dairy product"
lab var ec13_s8 "Manufacture grain mill and starch products"
lab var ec13_s9 "Manufacture of prepared animal feeds"
lab var ec13_s10 "Manufacture of nuts, sugar, noodles, and other foods"
lab var ec13_s59 "Storage and warehousing"
cap lab var ec13_s43 "Wholesale of agricultural raw materials and live animals"

/* calculate total agroprocessing employment */
gen ec13_agro_share = ec13_s5 + ec13_s6 + ec13_s7 + ec13_s8 + ec13_s9 + ec13_s10

/* calculate agroprocessing as a share of total employment */
replace ec13_agro_share = ec13_agro_share / ec13_emp_all
lab var ec13_agro_share "share of total employment in agroprocessing"

/* calculate storage and warehouse services as a share of total employment */
gen ec13_storage_share =  ec13_s59 / ec13_emp_all
lab var ec13_storage_share "share of total employment in storage and warehousing"

/* secc: Share of workers/households working in agriculture */
merge 1:1 shrid using $shrug/data/shrug_secc, keepusing(nco2d_cultiv_share) gen(_m_secc)

/* ndvi: NDVI and EVI agricultural productivity estimates by season, NASA MODIS (2000-2017) */
merge 1:1 shrid using $iec/canals/clean/evi_ndvi_shrid_clean, keepusing(ndvi_delta_*_ln evi_delta_*_ln) gen (_m_evi)

/* get all ndvi/evi variables */
qui ds *vi_delta_*_ln
local vi_vars = "`r(varlist)'"

/* cycle through variables to add labels */
foreach var in `vi_vars' {

  /* get the year */
  local year = regexr("`var'", "[^0-9]*", "")
  local year = regexr("`year'", "[^0-9]+", "")

  /* get the particular index */
  local i = regexr("`var'", "_delta_[a-z]_[0-9]+_ln",  "")

  /* for all Kharif */
  if strpos("`var'", "_k_") != 0 {
    lab var `var' "`i': log diff between early season mean and season max, Kharif `year'"
  }

  /* for all Rabi */
  if strpos("`var'", "_r_") != 0 {
    lab var `var' "`i': log diff between early season average and season max, Rabi `year'"
  }

  /* for all Zaid */
  if strpos("`var'", "_z_") != 0 {
    lab var `var' "`i': log diff between early season average and season max, Zaid `year'"
  }
}

/* fao gaez: crop suitability, Food and Agriculture Organization (FAO) GAEZ - variables unlabeled, need some description here */
merge 1:1 shrid using $ag/gaez/high-rain-fed, gen(_m_hrf) keepusing(*mean*)
merge 1:1 shrid using $ag/gaez/low-rain-fed, gen(_m_lrf) keepusing(*mean*)
merge 1:1 shrid using $ag/gaez/intermediate-gravity, gen(_m_irf) keepusing(*mean*)

/* get all the gaez variables just merged in */
qui ds mean_*
local gaez_vars = "`r(varlist)'"

/* rename gaez variables to be clearer */
foreach var in `gaez_vars' {
  local i = subinstr("`var'", "mean", "gaez", .)
  ren `var' `i'

  /* isolate the crop name */
  local p0 = strpos("`var'", "_") + 1
  local name = substr("`var'", `p0', .)
  local p1 = strpos("`name'", "_") 
  local crop = substr("`name'", 1, `p1' - 1)

  /* get the last 3 letters of the variable */
  local suffix = substr("`name'", `p1' + 1, .)

  /* generate inputs and rainfall descriptors from suffix */
  if "`suffix'" == "hrf" local rainfall "rain-fed"
  if "`suffix'" == "lrf" local rainfall "rain-fed"
  if "`suffix'" == "igf" local rainfall "gravity irrigated"

  if "`suffix'" == "hrf" local inputs "high inputs"
  if "`suffix'" == "lrf" local inputs "low inputs"
  if "`suffix'" == "igf" local inputs "intermediate inputs"

  /* add a label */
  label var `i' "potential `crop' production (t/ha): `rainfall', `inputs'"
}

/* canals and command areas: proximity to major canals and command areas, WRIS */
merge 1:1 shrid using $minor/distances/shrid_distances, gen(_m_dist) keepusing(dist_km_river dist_km_canal)
lab var dist_km_river "distance to nearest river (km)"
lab var dist_km_canal "distance to nearest canal (km)"

/* merge in command area information */
merge 1:1 shrid using $iec/canals/clean/shrid_command_distances, gen(_m_comm) keepusing(near_comm_dist shrid_comm_overlap comm_dummy)

/* add a caveat here about what to do with shrids that are inside command areas */
ren near_comm_dist dist_km_command_area
lab var dist_km_command_area "distance to nearest command area (km)"
ren shrid_comm_overlap percent_in_command_area
lab var percent_in_command_area "percent of village area inside command area"

/* bring in shrid names to be passed into the web app */
merge 1:1 shrid using $shrug/keys/shrug_names, keepusing(place_name) nogen

/* drop unnecessary vars - keep code for merge vars above for future debugging, but we don't want them in the vector tileset */
drop _m*

/* order the merge variables at the end */
order shrid place_name, first

/* generate MIC variable placeholders for easier var manipulation in the web app */
foreach var in $micvars {
    gen `var' = .
}

/* convert to percentages */
convert_to_percentage percent_in_command_area ec13_storage_share mic5_diesel_wells_share ec13_agro_share

/* save the full data */
compress
save $iec/rural_platform/shrid_data.dta, replace

/* keep only tileset variables to cut down on file size */
keep shrid place_name $all_tilevars $micvars

/* adjust variable formats for the tileset as needed */
foreach var of varlist dist* {
  replace `var' = round(`var')
}

/* merge in top shric sectors */
merge 1:1 shrid using $tmp/shrid_json_shrics
drop _merge

/* save just the tileset variables for the smaller mapping dataset */
compress
save $iec/rural_platform/shrid_data_tileset.dta, replace

/* open the canals data, created in canals/b/clean_canals_data.do.
canals can be merged to the shapefile using the project_code */
use $iec/canals/raw/canal_construction/all_canals_data, clear

/* add additional labels */
lab var plan_start "Planning period project started, if known"
lab var plan_completed "Planning period project completed, if known"

/* drop old variables */
drop _merge

/* save canal-level dataset */
save $iec/rural_platform/canal_data.dta, replace


/************/
/* DISTRICT */
/************/

/* open the full data */
use $iec/rural_platform/shrid_data, clear

/* merge in the pc11 state and district variables */
merge m:1 shrid using $shrug/keys/shrug_pc11_district_key, keep(match master) keepusing(pc11_state_id pc11_state_name pc11_district_id pc11_district_name) nogen

/* merge in the shrid area */
merge 1:1 shrid using $shrug/data/shrug_spatial, keepusing(area_laea)
drop _merge

/* bring in population */
merge 1:1 shrid using $shrug/data/shrug_pc11_pca, keepusing(pc11_pca_tot_p)
drop _merge

/* drop if missing district */
drop if mi(pc11_district_id)

/* collapse to district level - NOTE: NOT ALL VARIABLES INCLUDED YET */
/* FIXME: EVI needs to be recreated from raw values, not logs */
/* FIXME: ec13*share and nco2d_cultiv_share should not be weighted by area, but by ec13_emp_all / reconstructed from raw counts */
/* FIXME: TEMP drop ec13_storage bc (a) needs to be rebuilt and (b) conflicts with ec13_s* shric wildcard in sumvars */
collapse_save_labels
if !mi("$maxvars") collapse (rawsum) pc11_pca_tot_p $sumvars (mean) $meanvars (max) $maxvars [pw=area_laea], by(pc11_state_id pc11_state_name pc11_district_id pc11_district_name) 
if mi("$maxvars") collapse (rawsum) pc11_pca_tot_p $sumvars (mean) $meanvars [pw=area_laea], by(pc11_state_id pc11_state_name pc11_district_id pc11_district_name) 
collapse_apply_labels

/* merge in minor irrigation census: irrigation by type */
merge m:1 pc11_state_id pc11_district_id using $iec/canals/clean/mic5_district_data, nogen keep(match master)

/* save the full dataset */
save $iec/rural_platform/district_data.dta, replace

/* round variables to integers */
foreach var of varlist dist_* pc11_vd_land* {
  replace `var' = round(`var')
}

/* merge in top shric sectors */
ren pc11_state_name state_name
ren pc11_district_name district_name
merge 1:1 state_name district_name using $tmp/district_json_shrics, keep(master match)
drop _merge

/* rename district variables for the web app */
ren pc11_district_id pc11_d_id
ren pc11_state_id pc11_s_id 

/* keep just the tileset variables, adding the district-only mic, for
the smaller mapping dataset. $all_tilevars asserts variable match
across dist and shrid tilesets */
keep pc11*id district_name pc11_pca_tot_p sector1 sector2 sector3 $all_tilevars

/* save the tileset */
compress
save $iec/rural_platform/district_data_tileset, replace

