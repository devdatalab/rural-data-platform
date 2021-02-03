/* assemble data for agricultural rural development platform */

/* pc11: Agricultural power supply and other infrastructure,  Irrigation and agricultural areas under cultivationK */
/* open pca */
use $shrug/data/shrug_pc11_pca, clear

/* merge in vd */
merge 1:1 shrid using $shrug/data/shrug_pc11_vd, gen(_m_vd)

/* create total agricultural land variable */
gen pc11_vd_land_ag_tot = pc11_vd_land_misc_trcp + pc11_vd_land_nt_swn
label var pc11_vd_land_ag_tot "total agricultural land"
drop pc11_vd_land_misc_trcp pc11_vd_land_nt_swn

/* keep shrid and desired variables */
keep shrid pc11_vd_land_src_irr pc11_vd_power_agr_sum pc11_vd_power_agr_win pc11_vd_p_sch pc11_vd_m_sch pc11_vd_s_sch pc11_vd_s_s_sch pc11_vd_tar_road pc11_vd_all_hosp pc11_vd_land_ag_tot

/* ec13: Employment in agro-processing and warehousing/storage */
merge 1:1 shrid using $shrug/data/shrug_ec13, keepusing(ec13_s8 ec13_s9 ec13_s10 ec13_s59)  gen(_m_ec13)

/* the above agro-processing selects the "grains" and "other" subcategories.
   to include livestock (dairy, meat) and beverages (alcohol) keep the following:
   ec13_s5 ec13_s6 ec13_s7 ec13_s8 ec13_s9 ec13_s10 ec13_s11 ec13_s59   
   one last one you may want is wholesale of ag. raw materials and live animals: ec13_s43
*/

/* add NIC04 descriptions to labels */
lab var ec13_s8 "Manufacture grain mill and starch products"
lab var ec13_s9 "Manufacture of prepared animal feeds"
lab var ec13_s10 "Manufacture of nuts, sugar, noodles, and other foods"
lab var ec13_s59 "Storage and warehousing"
cap lab var ec13_s5 "Production, processing and preserving of meat and meat products"
cap lab var ec13_s6 "Manufacture of vegetable and animal oils and fats"
cap lab var ec13_s7 "Manufacture of dairy product"
cap lab var ec13_s11 "Manufacture of beverages (mostly alcohol)"
cap lab var ec13_s43 "Wholesale of agricultural raw materials and live animals"

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

/* canals and command areas: proximity to major canals and command areas, WRIS */
merge 1:1 shrid using $minor/distances/shrid_distances, gen(_m_dist) keepusing(dist_km_river dist_km_canal)
lab var dist_km_river "distance to nearest river (km)"
lab var dist_km_canal "distance to nearest canal (km)"

/* merge in command area information */
merge 1:1 shrid using $iec/canals/clean/shrid_command_distances, gen(_m_comm) keepusing(near_comm_dist shrid_comm_overlap)
ren near_comm_dist dist_km_command_area
lab var dist_km_command_area "distance to nearest command area (km)"
ren shrid_comm_overlap percent_in_command_area
lab var percent_in_command_area "percent of village area inside command area"

/* minor irrigation census: irrigation by type - variables unlabeld, need some description here*/
/* merge in the pc11 state and district variables */
merge m:1 shrid using $shrug/keys/shrug_pc11_district_key, keep(match master) keepusing(pc11_state_id pc11_district_id) nogen

/* merge in mic */
merge m:1 pc11_state_id pc11_district_id using $iec/canals/clean/mic5_district_data, nogen keep(match master)

/* bring in shrid names to be passed into the web app */
merge 1:1 shrid using $shrug/keys/shrug_names, keepusing(place_name) nogen

/* order the merge variables at the end */
order _m*, last
order shrid place_name, first

/* save the data */
save $iec/rural_platform/shrid_data.dta, replace

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
/* Cost of Cultivation */
/***********************/

/* cost of cultivation: agricultural production, prices, and input usage data for 2,073 villages */
// use

/* save COC dataset */
//save $iec/rural_platform/coc_data.dta, replace


/***********************/
/* District aggregates */
/***********************/

/* we need district collapses for the shrid-level data above. */

/* be sure that district names exist in a variable called district_name */
/* please rename pc11_district_id to pc11_d_id to save a step on the shapefile merge */

/* output location: */
//save $iec/rural_platform/district_data.dta, replace
