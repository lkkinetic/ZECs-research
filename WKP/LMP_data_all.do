/*
This .do file takes the processed LMP data for the ISOs as an input and first 
prepares a monthly average LMP for major hubs within each ISO. Next, it merges
together all of the standardized, monthly avg. LMP datasets. Finally, it 
performs a series of diff-in-diff analyses.
*/

clear all
set type double
set more off

cd .

global inter "intermediate_LMP"
global output "output_LMP_styr"

capture mkdir "$inter"
capture mkdir "$output"

global inter_spp "SPP DA\intermediate"
global inter_ercot "ERCOT DA\intermediate"
global inter_isone "ISO-NE DA\intermediate"

global inter_miso "MISO DA\intermediate"
global inter_pjm "PJM DA\intermediate"
global inter_nyiso "NYISO DA\intermediate_refbus"

**************************************************************
/*

Import Data and Prepare Monthly Avg.

*/
**************************************************************

*************
/*
SPP
*/
*************
use "$inter_spp\SPP_DA_LMP_2013_2019", clear

* Generate hour ending variable *
gen clock = clock(timestamp, "MDYhms")
format clock %tc
gen hour2 = hh(clock)
replace hour2 = hour2 + 1
replace hour = hour2 if hour == .
assert hour != 0
assert hour <= 24
label var hour "Hour Ending (1-24)"
drop hour2

gen year = year(date)
gen month = month(date)

** Collapse to monthly avg. hourly LMP by Node **
collapse (mean) LMP, by(pnode year month)

gen my = ym(year, month)
format my %tm

* drop missing or partial years *
drop if my == .
drop if year == 2020

* Limit to SPPNORTH and SPPSOUTH *
keep if regexm(pnode, "SPP") == 1

gen iso = "SPP"
compress
save "$inter\SPP_DA_LMP_monthly_13_19", replace


*************
/*
ISO-NE
*/
*************
use "$inter_isone\ISONE_DA_LMP_2013_19", clear

ren locationname pnode
ren dayaheadall LMP

** Collapse to monthly avg. hourly LMP by Node **
collapse (mean) LMP, by(pnode year month my)

* drop missing or partial years *
drop if my == .
drop if year == 2020

* Limit to state-level aggregates *
keep if regexm(pnode, ".Z.") == 1
replace pnode = regexr(pnode, ".Z.", "")

gen iso = "ISO-NE"
compress
save "$inter\ISONE_DA_LMP_monthly_13_19", replace

*************
/*
ERCOT
*/
*************

use "$inter_ercot\ERCOT_DA_LMP_2010_19", clear

gen year = year(date)
gen month = month(date)

ren settlementpoint pnode

** Collapse to monthly avg. hourly LMP by Node **
collapse (mean) LMP, by(pnode year month)

gen my = ym(year, month)
format my %tm

* drop missing or partial years *
drop if my == .
drop if year == 2020
drop if pnode == "HB_PAN"

* Limit to 4 major hubs *
keep if regexm(pnode, "HB_") == 1
drop if pnode == "HB_BUSAVG"
drop if pnode == "HB_HUBAVG"

gen iso = "ERCOT"
compress
save "$inter\ERCOT_DA_LMP_monthly_10_19", replace

*************
/*
MISO
*/
*************
use "$inter_miso\MISO_DA_hubs_2005_2019", clear

ren node pnode
keep if value == "LMP"
ren he LMP

** Collapse to monthly avg. hourly LMP by Node **
collapse (mean) LMP, by(pnode year month)

gen my = ym(year, month)
format my %tm

* drop missing or partial years *
drop if my == .
drop if year == 2020

gen iso = "MISO"
compress
save "$inter\MISO_DA_LMP_monthly_05_19", replace

*************
/*
PJM
*/
*************
use "$inter_pjm\PJM_DA_hubs_2000_2019", clear
ren pnode_name pnode
ren total_lmp_da LMP

** Collapse to monthly avg. hourly LMP by Node **
collapse (mean) LMP, by(pnode year month)

gen my = ym(year, month)
format my %tm

* drop missing or partial years *
drop if my == .
drop if year == 2020

drop if pnode == "CHICAGO GEN HUB"

gen iso = "PJM"
compress
save "$inter\PJM_DA_LMP_monthly_00_19", replace

*************
/*
NYISO
*/
*************
use "$inter_nyiso\NYISO_DA_LMP_2000_2019", clear

gen year = year(date)
gen month = month(date)
ren name pnode

** Collapse to monthly avg. hourly LMP by Node **
collapse (mean) LMP, by(pnode year month)

gen my = ym(year, month)
format my %tm

* drop missing or partial years *
drop if my == .
drop if year == 2020

gen iso = "NYISO"
compress
save "$inter\NYISO_DA_LMP_monthly_00_19", replace


**************************************************************
/*

Merge Together Monthly LMP Data

*/
**************************************************************

use "$inter\PJM_DA_LMP_monthly_00_19", clear
append using "$inter\NYISO_DA_LMP_monthly_00_19"
append using "$inter\MISO_DA_LMP_monthly_05_19"
append using "$inter\ERCOT_DA_LMP_monthly_10_19"
append using "$inter\ISONE_DA_LMP_monthly_13_19"
append using "$inter\SPP_DA_LMP_monthly_13_19"

save "$inter\DA_LMP_monthly_all", replace

use "$inter\DA_LMP_monthly_all", clear
* Generate state LMP indicators for DiD *
gen IL = (pnode == "CHICAGO HUB")
replace IL = 1 if pnode == "N ILLINOIS HUB"
replace IL = 1 if pnode == "ILLINOIS.HUB"

gen NY = (iso == "NYISO")

gen ZEC_proposed = 1 if my == ym(2016, 8) & NY == 1
replace ZEC_proposed = 1 if my == ym(2016, 12) & IL == 1

gen ZEC_start = 1 if my == ym(2017, 4) & NY == 1
replace ZEC_start = 1 if my == ym(2017, 6) & IL == 1

* Create post-indicators for after ZEC program was proposed *
gen ZEC_prop_NY_post = (my >= ym(2016, 8))
gen ZEC_prop_IL_post = (my >= ym(2016, 12))

* Create post-indicators for after ZEC program was implemented *
gen ZEC_start_NY_post = (my >= ym(2017, 4))
gen ZEC_start_IL_post = (my >= ym(2017, 6))

* Generate interactions between post indicators and state *
gen ZEC_prop_inter_IL = ZEC_prop_IL_post * IL
gen ZEC_start_inter_IL = ZEC_start_IL_post * IL

gen ZEC_prop_inter_NY = ZEC_prop_NY_post * NY
gen ZEC_start_inter_NY = ZEC_start_NY_post * NY

compress
save "$inter\state_month_LMP_00_13_19", replace


********************************************************************************


***********************************

/*

Pre- and Post- Implementation of ZECs Program

*/

***********************************

****************
/*
1) New York
*/
****************
use "$inter\state_month_LMP_00_13_19", clear

/*
Binned post-indicators 
*/
* Create post-indicators for after ZEC program was proposed up to implementation *
gen ZEC_prop_NY_post_8 = (my >= ym(2016, 8) & my < ym(2017, 4))
gen ZEC_prop_IL_post_6 = (my >= ym(2016, 12) & my < ym(2017, 6))

* Generate interactions between post indicators and state *
gen ZEC_prop_inter_IL_6 = ZEC_prop_IL_post_6 * IL
gen ZEC_prop_inter_NY_8 = ZEC_prop_NY_post_8 * NY

/*
Flag neighboring states
*/
gen neighbor = 1 if pnode == "INDIANA.HUB"
replace neighbor = 1 if pnode  == "MICHIGAN.HUB"

replace neighbor = 1 if pnode == "CONNECTICUT"
replace neighbor = 1 if pnode == "NEMASSBOST"
replace neighbor = 1 if pnode == "SEMASS"
replace neighbor = 1 if pnode == "WCMASS"
replace neighbor = 1 if pnode == "NEW JERSEY HUB"
replace neighbor = 1 if pnode == "WESTERN HUB"
replace neighbor = 1 if pnode == "WEST INT HUB"
replace neighbor = 1 if pnode == "VERMONT"

replace neighbor = 0 if neighbor == .

compress

drop if IL == 1
assert regexm(pnode, "ILLINOIS") != 1

drop if neighbor == 1

* Generate numeric hub ID *
egen hub_id = group(pnode)

** Generate hub-year FE **
egen hub_yr = group(pnode year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)

* Limit to years with coverage across all ISOs *
keep if year >= 2013

/*
* Regressions for price effect *
*/
foreach outcome_var in "LMP" {
	local output_file "$output\DiD_NY_`outcome_var'_2bins_no_neigh_cluster_styr.dta"
	
	reghdfe `outcome_var' ZEC_prop_NY_post_8 ZEC_start_NY_post ZEC_prop_inter_NY_8 ZEC_start_inter_NY i.season_yr, absorb(hub_yr) cluster(hub_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
foreach outcome_var in "LMP" {

	use "$output\DiD_NY_`outcome_var'_2bins_no_neigh_cluster_styr.dta", clear

	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "8-mo. Post" if var == "ZEC_prop_NY_post_8"
	replace var = "ZEC Start" if var == "ZEC_start_NY_post"
	replace var = "8-mo. Post x New York" if var == "ZEC_prop_inter_NY_8"
	replace var = "ZEC Start x New York" if var == "ZEC_start_inter_NY"

	replace var = "Constant" if var == "_cons"

	/*
	Flag fixed effects
	*/
	expand 3 if var == "N", gen(exp_counter)
	gen exp_counter2 = sum(exp_counter)

	forvalues i = 1/1 {
		replace reg`i' = "" if exp_counter == 1
	}
	*
	replace var = "Hub-by-Year FE" if exp_counter2 == 1
	replace var = "Season-by-Year FE" if exp_counter2 == 2
	forvalues i = 1/1 {
		replace reg`i' = "Yes" if var == "Hub-by-Year FE"
	}
	*
	replace reg1 = "Yes" if var == "Season-by-Year FE"

	drop exp_counter*

	* Prepare name for caption based on variable name *
	label var reg1 "NYISO Reference Hub"
	ren reg1 `outcome_var'
		
	save "$output\NY_DiD_`outcome_var'_2bins", replace
}
*
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_2bins_LMP_state_yr.tex", frag varlabels nofix ///
title("Impacts on LMP (New York)") size(5) marker("NY_LMP_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is the monthly average hub LMP. Monthly average LMP data from 2013 - 2019 for reference nodes in NYISO, SPP, ERCOT, ISO-NE, MISO, and PJM. Hub prices for Illinois and neighboring states to both Illinois and New York are excluded from this analysis. Standard errors clustered by hub-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.6\textwidth) autonumber hlines(-2 -4) replace


****************
/*
2) Illinois
*/
****************
use "$inter\state_month_LMP_00_13_19", clear

/*
Binned post-indicators 
*/

* Create post-indicators for after ZEC program was proposed up to implementation *
gen ZEC_prop_NY_post_8 = (my >= ym(2016, 8) & my < ym(2017, 4))
gen ZEC_prop_IL_post_6 = (my >= ym(2016, 12) & my < ym(2017, 6))

* Generate interactions between post indicators and state *
gen ZEC_prop_inter_IL_6 = ZEC_prop_IL_post_6 * IL
gen ZEC_prop_inter_NY_8 = ZEC_prop_NY_post_8 * NY

/*
Flag neighboring states
*/
gen neighbor = 1 if pnode == "INDIANA.HUB"
replace neighbor = 1 if pnode  == "MICHIGAN.HUB"

replace neighbor = 1 if pnode == "CONNECTICUT"
replace neighbor = 1 if pnode == "NEMASSBOST"
replace neighbor = 1 if pnode == "SEMASS"
replace neighbor = 1 if pnode == "WCMASS"
replace neighbor = 1 if pnode == "NEW JERSEY HUB"
replace neighbor = 1 if pnode == "WESTERN HUB"
replace neighbor = 1 if pnode == "WEST INT HUB"
replace neighbor = 1 if pnode == "VERMONT"

replace neighbor = 0 if neighbor == .

compress

drop if NY == 1
assert regexm(iso, "NYISO") != 1

drop if neighbor == 1

preserve

/*
** (A): MISO - Illinois Hub **
*/
drop if IL == 1 & pnode != "ILLINOIS.HUB"

* Generate numeric hub ID *
egen hub_id = group(pnode)

** Generate hub-year FE **
egen hub_yr = group(pnode year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)

* Limit to years with coverage across all ISOs *
keep if year >= 2013

/*
* Regressions for price effect *
*/
foreach outcome_var in "LMP" {
	local output_file "$output\DiD_IL_MISO_`outcome_var'_2bins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' ZEC_prop_IL_post_6 ZEC_start_IL_post ZEC_prop_inter_IL_6 ZEC_start_inter_IL i.season_yr, absorb(hub_yr) cluster(hub_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
foreach outcome_var in "LMP" {

	use "$output\DiD_IL_MISO_`outcome_var'_2bins_no_neigh_cluster_styr.dta", clear

	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "6-mo. Post" if var == "ZEC_prop_IL_post_6"
	replace var = "ZEC Start" if var == "ZEC_start_IL_post"
	replace var = "6-mo. Post x Illinois" if var == "ZEC_prop_inter_IL_6"
	replace var = "ZEC Start x Illinois" if var == "ZEC_start_inter_IL"

	replace var = "Constant" if var == "_cons"

	/*
	Flag fixed effects
	*/
	expand 3 if var == "N", gen(exp_counter)
	gen exp_counter2 = sum(exp_counter)

	forvalues i = 1/1 {
		replace reg`i' = "" if exp_counter == 1
	}
	*
	replace var = "Hub-by-Year FE" if exp_counter2 == 1
	replace var = "Season-by-Year FE" if exp_counter2 == 2
	forvalues i = 1/1 {
		replace reg`i' = "Yes" if var == "Hub-by-Year FE"
	}
	*
	replace reg1 = "Yes" if var == "Season-by-Year FE"

	drop exp_counter*

	* Prepare name for caption based on variable name *
	label var reg1 "Illinois Hub - MISO"
	ren reg1 `outcome_var'_MISO
	
	gen merge_id = _n
	compress
	
	save "$output\IL_MISO_DiD_`outcome_var'_2bins", replace
}
*

/*
** (B): PJM - Chicago Hub **
*/
restore
drop if IL == 1 & pnode != "CHICAGO HUB"

* Generate numeric hub ID *
egen hub_id = group(pnode)

** Generate hub-year FE **
egen hub_yr = group(pnode year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)

* Limit to years with coverage across all ISOs *
keep if year >= 2013

/*
* Regressions for price effect *
*/
foreach outcome_var in "LMP" {
	local output_file "$output\DiD_IL_PJM_`outcome_var'_2bins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' ZEC_prop_IL_post_6 ZEC_start_IL_post ZEC_prop_inter_IL_6 ZEC_start_inter_IL i.season_yr, absorb(hub_yr) cluster(hub_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
foreach outcome_var in "LMP" {

	use "$output\DiD_IL_PJM_`outcome_var'_2bins_no_neigh_cluster_styr.dta", clear

	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "6-mo. Post" if var == "ZEC_prop_IL_post_6"
	replace var = "ZEC Start" if var == "ZEC_start_IL_post"
	replace var = "6-mo. Post x Illinois" if var == "ZEC_prop_inter_IL_6"
	replace var = "ZEC Start x Illinois" if var == "ZEC_start_inter_IL"

	replace var = "Constant" if var == "_cons"

	/*
	Flag fixed effects
	*/
	expand 3 if var == "N", gen(exp_counter)
	gen exp_counter2 = sum(exp_counter)

	forvalues i = 1/1 {
		replace reg`i' = "" if exp_counter == 1
	}
	*
	replace var = "Hub-by-Year FE" if exp_counter2 == 1
	replace var = "Season-by-Year FE" if exp_counter2 == 2
	forvalues i = 1/1 {
		replace reg`i' = "Yes" if var == "Hub-by-Year FE"
	}
	*
	replace reg1 = "Yes" if var == "Season-by-Year FE"

	drop exp_counter*

	* Prepare name for caption based on variable name *
	label var reg1 "Chicago Hub - PJM"
	ren reg1 `outcome_var'_PJM
	
	gen merge_id = _n
	compress
	
	save "$output\IL_PJM_DiD_`outcome_var'_2bins", replace
}
*


/*
Merge together MISO and PJM
*/
use "$output\IL_PJM_DiD_LMP_2bins", clear
merge 1:1 merge_id using "$output\IL_MISO_DiD_LMP_2bins"
assert _m == 3
drop merge_id _m
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_2bins_LMP_state_yr.tex", frag varlabels nofix ///
title("Impacts on LMP (Illinois)") size(4) marker("IL_LMP_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is the monthly average hub LMP. Monthly average LMP data from 2013 - 2019 for reference nodes in NYISO, SPP, ERCOT, ISO-NE, MISO, and PJM. Hub prices for New York and neighboring states to both Illinois and New York are excluded from this analysis. Standard errors clustered by hub-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.8\textwidth) autonumber hlines(-2 -4) replace



****************************************************************************





***********************************

/*

Using 6-month bins for Post ZEC-start periods

*/

***********************************

****************
/*
3) New York
*/
****************

use "$inter\state_month_LMP_00_13_19", clear

/*
Binned post-indicators 
*/

* Create post-indicators for after ZEC program was proposed up to implementation *
gen ZEC_prop_NY_post_8 = (my >= ym(2016, 8) & my < ym(2017, 4))
gen ZEC_prop_IL_post_6 = (my >= ym(2016, 12) & my < ym(2017, 6))

gen ZEC_start_NY_post_6 = (my>=ym(2017,4) & my < ym(2017, 10))
gen ZEC_start_IL_post_6 = (my>=ym(2017,6) & my < ym(2017, 12))

gen ZEC_start_NY_post_7_12 = (my>=ym(2017,10) & my < ym(2018, 4))
gen ZEC_start_IL_post_7_12 = (my>=ym(2017,12) & my < ym(2018, 6))

gen ZEC_start_NY_post_13 = (my>=ym(2018,4))
gen ZEC_start_IL_post_13 = (my>=ym(2018,6))


* Generate interactions between post indicators and state *
gen ZEC_prop_inter_IL_6 = ZEC_prop_IL_post_6 * IL
gen ZEC_prop_inter_NY_8 = ZEC_prop_NY_post_8 * NY

gen ZEC_start_inter_IL_6 = ZEC_start_IL_post_6 * IL
gen ZEC_start_inter_NY_6 = ZEC_start_NY_post_6 * NY

gen ZEC_start_inter_IL_7_12 = ZEC_start_IL_post_7_12 * IL
gen ZEC_start_inter_NY_7_12 = ZEC_start_NY_post_7_12 * NY

gen ZEC_start_inter_IL_13 = ZEC_start_IL_post_13 * IL
gen ZEC_start_inter_NY_13 = ZEC_start_NY_post_13 * NY

/*
Flag neighboring states
*/
gen neighbor = 1 if pnode == "INDIANA.HUB"
replace neighbor = 1 if pnode  == "MICHIGAN.HUB"

replace neighbor = 1 if pnode == "CONNECTICUT"
replace neighbor = 1 if pnode == "NEMASSBOST"
replace neighbor = 1 if pnode == "SEMASS"
replace neighbor = 1 if pnode == "WCMASS"
replace neighbor = 1 if pnode == "NEW JERSEY HUB"
replace neighbor = 1 if pnode == "WESTERN HUB"
replace neighbor = 1 if pnode == "WEST INT HUB"
replace neighbor = 1 if pnode == "VERMONT"

replace neighbor = 0 if neighbor == .

compress

drop if IL == 1
assert regexm(pnode, "ILLINOIS") != 1

drop if neighbor == 1

* Generate numeric hub ID *
egen hub_id = group(pnode)

** Generate hub-year FE **
egen hub_yr = group(pnode year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)

* Limit to years with coverage across all ISOs *
keep if year >= 2013

/*
* Regressions for Price Effect *
*/
foreach outcome_var in "LMP" {
	local output_file "$output\DiD_NY_`outcome_var'_6mobins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' ZEC_prop_NY_post_8 ZEC_start_NY_post_6 ZEC_start_NY_post_7_12 ZEC_start_NY_post_13 ZEC_prop_inter_NY_8 ZEC_start_inter_NY_6 ZEC_start_inter_NY_7_12 ZEC_start_inter_NY_13 i.season_yr, absorb(hub_yr) cluster(hub_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
foreach outcome_var in "LMP" {

	use "$output\DiD_NY_`outcome_var'_6mobins_no_neigh_cluster_styr.dta", clear
	
	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "8-mo. Post" if var == "ZEC_prop_NY_post_8"
	replace var = "ZEC (1-6mo.)" if var == "ZEC_start_NY_post_6"
	replace var = "ZEC (7-12mo.)" if var == "ZEC_start_NY_post_7_12"
	replace var = "ZEC (1 year+)" if var == "ZEC_start_NY_post_13"
	replace var = "8-mo. Post x NY" if var == "ZEC_prop_inter_NY_8"
	replace var = "ZEC (1-6mo.) x NY" if var == "ZEC_start_inter_NY_6"
	replace var = "ZEC (7-12mo.) x NY" if var == "ZEC_start_inter_NY_7_12"
	replace var = "ZEC (1 year+) x NY" if var == "ZEC_start_inter_NY_13"

	replace var = "Constant" if var == "_cons"

	/*
	Flag fixed effects
	*/
	expand 3 if var == "N", gen(exp_counter)
	gen exp_counter2 = sum(exp_counter)

	forvalues i = 1/1 {
		replace reg`i' = "" if exp_counter == 1
	}
	*
	replace var = "Hub-by-Year FE" if exp_counter2 == 1
	replace var = "Season-by-Year FE" if exp_counter2 == 2
	forvalues i = 1/1 {
		replace reg`i' = "Yes" if var == "Hub-by-Year FE"
	}
	*
	replace reg1 = "Yes" if var == "Season-by-Year FE"

	*
	drop exp_counter*

	* Prepare name for caption based on variable name *
	label var reg1 "NYISO Reference Hub"
	ren reg1 `outcome_var'
	
	save "$output\NY_DiD_`outcome_var'_6mobins", replace
}
*

** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_6mobins_LMP_state_yr.tex", frag varlabels nofix ///
title("Impacts on LMP (New York, Short Term Breakdown)") size(5) marker("NY_LMP_6mobin") ///
footnote("Estimation of Equation (\ref{eq_DiD3}) where the outcome variable is the monthly average hub LMP. Monthly average LMP data from 2013 - 2019 for reference nodes in NYISO, SPP, ERCOT, ISO-NE, MISO, and PJM. Hub prices for Illinois and neighboring states to both Illinois and New York are excluded from this analysis. Standard errors clustered by hub-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.6\textwidth) autonumber hlines(-2 -4) replace



****************
/*
4) Illinois
*/
****************

use "$inter\state_month_LMP_00_13_19", clear

/*
Binned post-indicators 
*/

* Create post-indicators for after ZEC program was proposed up to implementation *
gen ZEC_prop_NY_post_8 = (my >= ym(2016, 8) & my < ym(2017, 4))
gen ZEC_prop_IL_post_6 = (my >= ym(2016, 12) & my < ym(2017, 6))

gen ZEC_start_NY_post_6 = (my>=ym(2017,4) & my < ym(2017, 10))
gen ZEC_start_IL_post_6 = (my>=ym(2017,6) & my < ym(2017, 12))

gen ZEC_start_NY_post_7_12 = (my>=ym(2017,10) & my < ym(2018, 4))
gen ZEC_start_IL_post_7_12 = (my>=ym(2017,12) & my < ym(2018, 6))

gen ZEC_start_NY_post_13 = (my>=ym(2018,4))
gen ZEC_start_IL_post_13 = (my>=ym(2018,6))


* Generate interactions between post indicators and state *
gen ZEC_prop_inter_IL_6 = ZEC_prop_IL_post_6 * IL
gen ZEC_prop_inter_NY_8 = ZEC_prop_NY_post_8 * NY

gen ZEC_start_inter_IL_6 = ZEC_start_IL_post_6 * IL
gen ZEC_start_inter_NY_6 = ZEC_start_NY_post_6 * NY

gen ZEC_start_inter_IL_7_12 = ZEC_start_IL_post_7_12 * IL
gen ZEC_start_inter_NY_7_12 = ZEC_start_NY_post_7_12 * NY

gen ZEC_start_inter_IL_13 = ZEC_start_IL_post_13 * IL
gen ZEC_start_inter_NY_13 = ZEC_start_NY_post_13 * NY

/*
Flag neighboring states
*/
gen neighbor = 1 if pnode == "INDIANA.HUB"
replace neighbor = 1 if pnode  == "MICHIGAN.HUB"

replace neighbor = 1 if pnode == "CONNECTICUT"
replace neighbor = 1 if pnode == "NEMASSBOST"
replace neighbor = 1 if pnode == "SEMASS"
replace neighbor = 1 if pnode == "WCMASS"
replace neighbor = 1 if pnode == "NEW JERSEY HUB"
replace neighbor = 1 if pnode == "WESTERN HUB"
replace neighbor = 1 if pnode == "WEST INT HUB"
replace neighbor = 1 if pnode == "VERMONT"

replace neighbor = 0 if neighbor == .

compress

drop if NY == 1
assert regexm(iso, "NYISO") != 1

drop if neighbor == 1

preserve

/*
** (A): MISO - Illinois Hub **
*/
drop if IL == 1 & pnode != "ILLINOIS.HUB"

* Generate numeric hub ID *
egen hub_id = group(pnode)

** Generate hub-year FE **
egen hub_yr = group(pnode year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)

* Limit to years with coverage across all ISOs *
keep if year >= 2013

/*
* Regressions for Price Effect *
*/
foreach outcome_var in "LMP" {
	local output_file "$output\DiD_IL_MISO_`outcome_var'_6mobins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' ZEC_prop_IL_post_6 ZEC_start_IL_post_6 ZEC_start_IL_post_7_12 ZEC_start_IL_post_13 ZEC_prop_inter_IL_6 ZEC_start_inter_IL_6 ZEC_start_inter_IL_7_12 ZEC_start_inter_IL_13 i.season_yr, absorb(hub_yr) cluster(hub_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
foreach outcome_var in "LMP" {

	use "$output\DiD_IL_MISO_`outcome_var'_6mobins_no_neigh_cluster_styr.dta", clear
	
	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "8-mo. Post" if var == "ZEC_prop_IL_post_6"
	replace var = "ZEC (1-6mo.)" if var == "ZEC_start_IL_post_6"
	replace var = "ZEC (7-12mo.)" if var == "ZEC_start_IL_post_7_12"
	replace var = "ZEC (1 year+)" if var == "ZEC_start_IL_post_13"
	replace var = "8-mo. Post x IL" if var == "ZEC_prop_inter_IL_6"
	replace var = "ZEC (1-6mo.) x IL" if var == "ZEC_start_inter_IL_6"
	replace var = "ZEC (7-12mo.) x IL" if var == "ZEC_start_inter_IL_7_12"
	replace var = "ZEC (1 year+) x IL" if var == "ZEC_start_inter_IL_13"

	replace var = "Constant" if var == "_cons"

	/*
	Flag fixed effects
	*/
	expand 3 if var == "N", gen(exp_counter)
	gen exp_counter2 = sum(exp_counter)

	forvalues i = 1/1 {
		replace reg`i' = "" if exp_counter == 1
	}
	*
	replace var = "Hub-by-Year FE" if exp_counter2 == 1
	replace var = "Season-by-Year FE" if exp_counter2 == 2
	forvalues i = 1/1 {
		replace reg`i' = "Yes" if var == "Hub-by-Year FE"
	}
	*
	replace reg1 = "Yes" if var == "Season-by-Year FE"

	*
	drop exp_counter*

	* Prepare name for caption based on variable name *
	label var reg1 "Illinois Hub - MISO"
	ren reg1 `outcome_var'_MISO
	
	gen merge_id = _n
	compress
	
	save "$output\IL_MISO_DiD_`outcome_var'_6mobins", replace
}
*

/*
** (B): PJM - Chicago Hub **
*/
restore
drop if IL == 1 & pnode != "CHICAGO HUB"

* Generate numeric hub ID *
egen hub_id = group(pnode)

** Generate hub-year FE **
egen hub_yr = group(pnode year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)

* Limit to years with coverage across all ISOs *
keep if year >= 2013

/*
* Regressions for Price Effect *
*/
foreach outcome_var in "LMP" {
	local output_file "$output\DiD_IL_PJM_`outcome_var'_6mobins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' ZEC_prop_IL_post_6 ZEC_start_IL_post_6 ZEC_start_IL_post_7_12 ZEC_start_IL_post_13 ZEC_prop_inter_IL_6 ZEC_start_inter_IL_6 ZEC_start_inter_IL_7_12 ZEC_start_inter_IL_13 i.season_yr, absorb(hub_yr) cluster(hub_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
foreach outcome_var in "LMP" {

	use "$output\DiD_IL_PJM_`outcome_var'_6mobins_no_neigh_cluster_styr.dta", clear
	
	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "8-mo. Post" if var == "ZEC_prop_IL_post_6"
	replace var = "ZEC (1-6mo.)" if var == "ZEC_start_IL_post_6"
	replace var = "ZEC (7-12mo.)" if var == "ZEC_start_IL_post_7_12"
	replace var = "ZEC (1 year+)" if var == "ZEC_start_IL_post_13"
	replace var = "8-mo. Post x IL" if var == "ZEC_prop_inter_IL_6"
	replace var = "ZEC (1-6mo.) x IL" if var == "ZEC_start_inter_IL_6"
	replace var = "ZEC (7-12mo.) x IL" if var == "ZEC_start_inter_IL_7_12"
	replace var = "ZEC (1 year+) x IL" if var == "ZEC_start_inter_IL_13"

	replace var = "Constant" if var == "_cons"

	/*
	Flag fixed effects
	*/
	expand 3 if var == "N", gen(exp_counter)
	gen exp_counter2 = sum(exp_counter)

	forvalues i = 1/1 {
		replace reg`i' = "" if exp_counter == 1
	}
	*
	replace var = "Hub-by-Year FE" if exp_counter2 == 1
	replace var = "Season-by-Year FE" if exp_counter2 == 2
	forvalues i = 1/1 {
		replace reg`i' = "Yes" if var == "Hub-by-Year FE"
	}
	*
	replace reg1 = "Yes" if var == "Season-by-Year FE"

	*
	drop exp_counter*

	* Prepare name for caption based on variable name *
	label var reg1 "Chicago Hub - PJM"
	ren reg1 `outcome_var'_PJM
	
	gen merge_id = _n
	compress
	
	save "$output\IL_PJM_DiD_`outcome_var'_6mobins", replace
}
*

/*
Merge together MISO and PJM
*/
use "$output\IL_PJM_DiD_LMP_6mobins", clear
merge 1:1 merge_id using "$output\IL_MISO_DiD_LMP_6mobins"
assert _m == 3
drop merge_id _m
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_6mobins_LMP_state_yr.tex", frag varlabels nofix ///
title("Impacts on LMP (Illinois, Short Term Breakdown)") size(4) marker("IL_LMP_6mobin") ///
footnote("Estimation of Equation (\ref{eq_DiD3}) where the outcome variable is the monthly average hub LMP. Monthly average LMP data from 2013 - 2019 for reference nodes in NYISO, SPP, ERCOT, ISO-NE, MISO, and PJM. Hub prices for New York and neighboring states to both Illinois and New York are excluded from this analysis. Standard errors clustered by hub-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.8\textwidth) autonumber hlines(-2 -4) replace
