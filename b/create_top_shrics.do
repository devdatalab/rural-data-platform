/* pull top 3 shric sectors at shrid and district level for the web app */

/* shorten SHRIC descriptions for web */
use $shrug/keys/shric_descriptions.dta, clear
replace shric_desc = "Spinning, weaving, and finishing of textiles" if shric == 50
replace shric_desc = "Pipeline transport" if shric == 55
replace shric_desc = "Miscellaneous manufacturing" if shric == 72
replace shric_desc = "Miscellaneous business services" if shric == 87
save $tmp/shric_descriptions_amended.dta, replace

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

/* bring in sector data */
clear
useshrug

/* clear obs that have no ec13 emp data */
get_shrug_var ec13_emp_all
drop if mi(ec13_emp_all)
drop ec13_emp_all

/* get sector data */
forval i = 1/90 {
  get_shrug_var ec13_s`i'
}

/* save as input for shrid-level stats */
save $tmp/shric_json_input, replace

/* collapse to districts and save */
get_shrug_key state_name district_name
collapse (sum) ec13_s*, by(state_name district_name)

/* run the prog to get top shrics, saved to $tmp/district_json_shrics */
get_top_shrics district_name state_name

/* now get top shrics at shrid level, saved to $tmp/shrid_json_shrics */
use $tmp/shric_json_input, clear
get_top_shrics shrid

