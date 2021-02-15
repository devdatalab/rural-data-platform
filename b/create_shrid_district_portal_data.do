/* assemble data for agricultural rural development platform */

/* define variable list to be kept for smaller mapping datasets */
global shrid_tilevars pc11_vd* ec13_emp_all ec13_agro_share ec13_storage_share evi_delta_k_*_ln gaez_maize_lrf dist_km_canal
global micvars mic5_st_total mic5_mt_total mic5_dt_total mic5_dw_total mic5_sl_total mic5_sf_total mic5_total mic5_diesel_wells mic5_diesel_wells_share
global all_tilevars $shrid_tilevars $micvars

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

/* save the full data */
save $iec/rural_platform/shrid_data.dta, replace

/* generate MIC variable placeholders for easier var manipulation in the web app */
foreach var in $micvars {
    gen `var' = .
}

/* keep only tileset variables to cut down on file size */
keep shrid place_name $all_tilevars

/* save just the tileset variables for the smaller mapping dataset */
save $iec/rural_platform/shrid_data_tileset.dta, replace

/* open the canals data, created in canals/b/clean_canals_data.do.
canals can be merged to the shapefile using the project_code */
use $iec/canals/raw/canal_construction/all_canals_data, clear

/* add additional labels */
lab var plan_start "Planning period project started, if known"
lab var plan_completed "Planning period project completed, if known"

/* drop old variables */
drop year_start_pdf year_completed_pdf year_approval_pdf _merge

/* save canal-level dataset */
save $iec/rural_platform/canal_data.dta, replace

/***********************/
/* District aggregates */
/***********************/

/* open the full data */
use $iec/rural_platform/shrid_data, clear

/* merge in the pc11 state and district variables */
merge m:1 shrid using $shrug/keys/shrug_pc11_district_key, keep(match master) keepusing(pc11_state_id pc11_district_id pc11_district_name) nogen

/* merge in the shrid area */
merge 1:1 shrid using $shrug/data/shrug_spatial, keepusing(area_laea)
drop _merge

/* drop if missing district */
drop if mi(pc11_district_id)

/* collapse to district level - NOTE: NOT ALL VARIABLES INCLUDED YET */
/* FIXME: EVI needs to be recreated from raw values, not logs */
/* FIXME: ec13*share and nco2d_cultiv_share should not be weighted by area, but by ec13_emp_all / reconstructed from raw counts */
/* TEMP drop ec13_storage bc (a) needs to be rebuilt and (b) conflicts with ec13_s* shric wildcard in sumvars */
drop ec13_storage_share
local sumvars pc11_vd_power_agr_sum pc11_vd_power_agr_win pc11_vd_all_hosp pc11_vd_land_src_irr pc11_vd_tar_road pc11_vd_p_sch pc11_vd_m_sch pc11_vd_s_sch pc11_vd_s_s_sch pc11_vd_land_ag_tot ec13_emp_all ec13_s* percent_in_command_area
local meanvars evi_delta_k* ndvi_delta_k* gaez_* nco2d_cultiv_share ec13*share dist_km_*
collapse (rawsum) `sumvars' (mean) `meanvars' [pw=area_laea], by(pc11_state_id pc11_district_id pc11_district_name) 

/* merge in minor irrigation census: irrigation by type */
merge m:1 pc11_state_id pc11_district_id using $iec/canals/clean/mic5_district_data, nogen keep(match master)

/* rename district variables for the web app */
ren pc11_district_id pc11_d_id
ren pc11_district_name district_name
ren pc11_state_id pc11_s_id 

/* save the full dataset */
save $iec/rural_platform/district_data.dta, replace

/* TEMP: gen blank storage share var (needs to be rebuilt, see above FIXME comment) */
gen ec13_storage_share = .

/* keep just the tileset variables, adding the district-only mic, for
the smaller mapping dataset. $all_tilevars asserts variable match
across dist and shrid tilesets */
keep pc11*id district_name $all_tilevars

/* save the tileset */
save $iec/rural_platform/district_data_tileset, replace
