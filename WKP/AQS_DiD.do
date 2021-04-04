/*
This .do file first prepares a dataset with monthly average daily maximum 
concentrations of several criteria pollutants from EPA's AQS database, to be used 
in our regression analysis. Next, it performs a difference-in-difference analysis
of changes in ambient pollutant concentrations after the announcement and 
implementation of the ZECs program in Illinois and New York.
*/

clear all
set type double
set more off

cd "EPA AQS"

global inter "inter_all"
global output "output_all"

capture mkdir "$inter"
capture mkdir "$output"

global inter_SO2 "SO2\output"
global inter_NO2 "NO2\output"
global inter_PM "PM2.5\output"

********************************************************************************

***********************************

/*

Prepare AQS merged Dataset (2000-2019)

*/

***********************************
use "$inter_PM\PM25_monthly_state_avg_00_19.dta", clear
merge 1:1 fipst month year using "$inter_SO2\SO2_monthly_state_avg_00_19.dta"
drop _m
merge 1:1 fipst month year using "$inter_NO2\NO2_monthly_state_avg_00_19.dta"
drop _m

gen my = ym(year, month)
format my %tm

* Generate state indicators for DiD *
gen IL = (statename == "Illinois")
gen NY = (statename == "New York")

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
save "$inter\state_month_AQS_00_19", replace

********************************************************************************





********************************************************************************


***********************************

/*

Pre- and Post- Implementation of ZECs Program

*/

***********************************

****************
/*
1) Illinois
*/
****************
use "$inter\state_month_AQS_00_19", clear

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
gen neighbor = 1 if statename == "Indiana"
replace neighbor = 1 if statename == "Iowa"
replace neighbor = 1 if statename == "Kentucky"
replace neighbor = 1 if statename == "Michigan"
replace neighbor = 1 if statename == "Missouri"
replace neighbor = 1 if statename == "Wisconsin"

replace neighbor = 1 if statename == "Connecticut"
replace neighbor = 1 if statename == "Massachusetts"
replace neighbor = 1 if statename == "New Jersey"
replace neighbor = 1 if statename == "Pennsylvania"
replace neighbor = 1 if statename == "Vermont"

replace neighbor = 0 if neighbor == .

compress

drop if NY == 1
assert statename != "New York"

drop if neighbor == 1

* Generate numeric state ID *
egen state_id = group(statename)

** Generate state-year FE **
egen state_yr = group(statename year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)


/*
* Regressions for local air pollutants *

NOTE - missing values for PM2.5 in Illinois from 6/1/2011 - 6/1/2014
*/

foreach outcome_var in "PM" "NO2" "SO2" {
	local output_file "$output\DiD_IL_`outcome_var'_2bins_no_neigh_cluster_styr.dta"

	reghdfe stmaxvalue_`outcome_var' ZEC_prop_IL_post_6 ZEC_start_IL_post ZEC_prop_inter_IL_6 ZEC_start_inter_IL i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
foreach outcome_var in "PM" "NO2" "SO2" {

	use "$output\DiD_IL_`outcome_var'_2bins_no_neigh_cluster_styr.dta", clear

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
	replace var = "State-by-Year FE" if exp_counter2 == 1
	replace var = "Season-by-Year FE" if exp_counter2 == 2
	forvalues i = 1/1 {
		replace reg`i' = "Yes" if var == "State-by-Year FE"
	}
	*
	replace reg1 = "Yes" if var == "Season-by-Year FE"

	drop exp_counter*

	* Prepare name for caption based on variable name *
	if "`outcome_var'" == "PM" {
		local name_var "PM2.5"
	} 
	else if "`outcome_var'" == "SO2" { 
		local name_var "SO2"
	}
	else if "`outcome_var'" == "NO2" { 
		local name_var "NO2"
	}
	*

	label var reg1 "`name_var'"
	ren reg1 `outcome_var'
	
	gen merge_id = _n
	
	save "$output\IL_DiD_`outcome_var'_2bins_formerge", replace
}
*

/*
Table - SO2 and NO2
*/
use "$output\IL_DiD_SO2_2bins_formerge", clear
foreach outcome_var in "NO2" {
	merge 1:1 merge_id using "$output\IL_DiD_`outcome_var'_2bins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_2bins_AQS_state_yr.tex", frag varlabels nofix ///
title("Impacts on Air Quality (Illinois, Pre- and Post- Implementation)") size(3) marker("IL_AQS_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is monthly ambient concentrations of a local air pollutant by state from EPA's AQS Database for 2000 - 2019. New York and neighboring states to and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.65\textwidth) location(ht) autonumber hlines(-2 -4) replace


/*
Appendix - All Pollutants
*/
use "$output\IL_DiD_SO2_2bins_formerge", clear
foreach outcome_var in "NO2" "PM" {
	merge 1:1 merge_id using "$output\IL_DiD_`outcome_var'_2bins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_2bins_AQS_all_state_yr.tex", frag varlabels nofix ///
title("Impacts on Air Quality (Illinois, Pre- and Post- Implementation)") size(3) marker("IL_AQS_all_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is monthly ambient concentrations of a local air pollutant by state from EPA's AQS Database for 2000 - 2019. New York and neighboring states to and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-2 -4) replace


****************
/*
2) New York
*/
****************
use "$inter\state_month_AQS_00_19", clear

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
gen neighbor = 1 if statename == "Indiana"
replace neighbor = 1 if statename == "Iowa"
replace neighbor = 1 if statename == "Kentucky"
replace neighbor = 1 if statename == "Michigan"
replace neighbor = 1 if statename == "Missouri"
replace neighbor = 1 if statename == "Wisconsin"

replace neighbor = 1 if statename == "Connecticut"
replace neighbor = 1 if statename == "Massachusetts"
replace neighbor = 1 if statename == "New Jersey"
replace neighbor = 1 if statename == "Pennsylvania"
replace neighbor = 1 if statename == "Vermont"

replace neighbor = 0 if neighbor == .

compress


*****************
* New York		*
*****************
drop if IL == 1
assert statename != "Illinois"

drop if neighbor == 1

* Generate numeric state ID *
egen state_id = group(state)

** Generate state-year FE **
egen state_yr = group(statename year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)


/*
* Regressions for local air pollutants *
*/
foreach outcome_var in "PM" "NO2" "SO2" {
	local output_file "$output\DiD_NY_`outcome_var'_2bins_no_neigh_cluster_styr.dta"

	reghdfe stmaxvalue_`outcome_var' ZEC_prop_NY_post_8 ZEC_start_NY_post ZEC_prop_inter_NY_8 ZEC_start_inter_NY i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
foreach outcome_var in "PM" "NO2" "SO2" {

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
	replace var = "State-by-Year FE" if exp_counter2 == 1
	replace var = "Season-by-Year FE" if exp_counter2 == 2
	forvalues i = 1/1 {
		replace reg`i' = "Yes" if var == "State-by-Year FE"
	}
	*
	replace reg1 = "Yes" if var == "Season-by-Year FE"

	drop exp_counter*

	* Prepare name for caption based on variable name *
	if "`outcome_var'" == "PM" {
		local name_var "PM2.5"
	} 
	else if "`outcome_var'" == "SO2" { 
		local name_var "SO2"
	}
	else if "`outcome_var'" == "NO2" { 
		local name_var "NO2"
	}
	*

	label var reg1 "`name_var'"
	ren reg1 `outcome_var'
	
	gen merge_id = _n
	
	save "$output\NY_DiD_`outcome_var'_2bins_formerge", replace
}
*

/*
Table - SO2 and PM2.5
*/
use "$output\NY_DiD_SO2_2bins_formerge", clear
foreach outcome_var in "PM" {
	merge 1:1 merge_id using "$output\NY_DiD_`outcome_var'_2bins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_2bins_AQS_state_yr.tex", frag varlabels nofix ///
title("Impacts on Air Quality (New York, Pre- and Post- Implementation)") size(3) marker("NY_AQS_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is monthly ambient concentrations of a local air pollutant by state from EPA's AQS Database for 2000 - 2019. Illinois and neighboring states to and neighboring states to New York and Illinois are excluded from this analysis.  Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.65\textwidth) location(ht) autonumber hlines(-2 -4) replace


/*
Appendix - All Pollutants
*/
use "$output\NY_DiD_SO2_2bins_formerge", clear
foreach outcome_var in "NO2" "PM" {
	merge 1:1 merge_id using "$output\NY_DiD_`outcome_var'_2bins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_2bins_AQS_all_state_yr.tex", frag varlabels nofix ///
title("Impacts on Air Quality (New York, Pre- and Post- Implementation)") size(3) marker("NY_AQS_all_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is monthly ambient concentrations of a local air pollutant by state from EPA's AQS Database for 2000 - 2019. Illinois and neighboring states to and neighboring states to New York and Illinois are excluded from this analysis.  Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-2 -4) replace

****************************************************************************





***********************************

/*

Using 6-month bins for Post ZEC-start periods

*/

***********************************

****************
/*
3) Illinois
*/
****************

use "$inter\state_month_AQS_00_19", clear

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
gen neighbor = 1 if statename == "Indiana"
replace neighbor = 1 if statename == "Iowa"
replace neighbor = 1 if statename == "Kentucky"
replace neighbor = 1 if statename == "Michigan"
replace neighbor = 1 if statename == "Missouri"
replace neighbor = 1 if statename == "Wisconsin"

replace neighbor = 1 if statename == "Connecticut"
replace neighbor = 1 if statename == "Massachusetts"
replace neighbor = 1 if statename == "New Jersey"
replace neighbor = 1 if statename == "Pennsylvania"
replace neighbor = 1 if statename == "Vermont"

replace neighbor = 0 if neighbor == .

compress

drop if NY == 1
assert statename != "New York"

drop if neighbor == 1

* Generate numeric state ID *
egen state_id = group(statename)

** Generate state-year FE **
egen state_yr = group(statename year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)


/*
* Regressions for local air pollutants *
*/
foreach outcome_var in "PM" "NO2" "SO2" {
	local output_file "$output\DiD_IL_`outcome_var'_6mobins_no_neigh_cluster_styr.dta"

	reghdfe stmaxvalue_`outcome_var' ZEC_prop_IL_post_6 ZEC_start_IL_post_6 ZEC_start_IL_post_7_12 ZEC_start_IL_post_13 ZEC_prop_inter_IL_6 ZEC_start_inter_IL_6 ZEC_start_inter_IL_7_12 ZEC_start_inter_IL_13 i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
foreach outcome_var in "PM" "NO2" "SO2" {

	use "$output\DiD_IL_`outcome_var'_6mobins_no_neigh_cluster_styr.dta", clear
	
	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "6-mo. Post" if var == "ZEC_prop_IL_post_6"
	replace var = "ZEC (1-6mo.)" if var == "ZEC_start_IL_post_6"
	replace var = "ZEC (7-12mo.)" if var == "ZEC_start_IL_post_7_12"
	replace var = "ZEC (1 year+)" if var == "ZEC_start_IL_post_13"
	replace var = "6-mo. Post x IL" if var == "ZEC_prop_inter_IL_6"
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
	replace var = "State-by-Year FE" if exp_counter2 == 1
	replace var = "Season-by-Year FE" if exp_counter2 == 2
	forvalues i = 1/1 {
		replace reg`i' = "Yes" if var == "State-by-Year FE"
	}
	*
	replace reg1 = "Yes" if var == "Season-by-Year FE"

	*
	drop exp_counter*

	* Prepare name for caption based on variable name *
	if "`outcome_var'" == "PM" {
		local name_var "PM2.5"
	} 
	else if "`outcome_var'" == "SO2" { 
		local name_var "SO2"
	}
	else if "`outcome_var'" == "NO2" { 
		local name_var "NO2"
	}
	*

	label var reg1 "`name_var'"
	ren reg1 `outcome_var'
	
	gen merge_id = _n
	
	save "$output\IL_DiD_`outcome_var'_6mobins_formerge", replace
}
*

use "$output\IL_DiD_SO2_6mobins_formerge", clear
foreach outcome_var in "NO2" "PM" {
	merge 1:1 merge_id using "$output\IL_DiD_`outcome_var'_6mobins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id

** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_6mobins_AQS_state_yr.tex", frag varlabels nofix ///
title("Impacts on Air Quality (Illinois, Pre- and Post- Implementation)") size(3) marker("IL_AQS_6mobin") ///
footnote("Estimation of Equation (\ref{eq_DiD3}) where the outcome variable is monthly ambient concentrations of a local air pollutant by state from EPA's AQS Database for 2000 - 2019. New York and neighboring states to and neighboring states to New York and Illinois are excluded from this analysis.  Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-2 -4) replace


****************
/*
4) New York
*/
****************

use "$inter\state_month_AQS_00_19", clear

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
gen neighbor = 1 if statename == "Indiana"
replace neighbor = 1 if statename == "Iowa"
replace neighbor = 1 if statename == "Kentucky"
replace neighbor = 1 if statename == "Michigan"
replace neighbor = 1 if statename == "Missouri"
replace neighbor = 1 if statename == "Wisconsin"

replace neighbor = 1 if statename == "Connecticut"
replace neighbor = 1 if statename == "Massachusetts"
replace neighbor = 1 if statename == "New Jersey"
replace neighbor = 1 if statename == "Pennsylvania"
replace neighbor = 1 if statename == "Vermont"

replace neighbor = 0 if neighbor == .

compress

drop if IL == 1
assert statename != "Illinois"

drop if neighbor == 1

* Generate numeric state ID *
egen state_id = group(statename)

** Generate state-year FE **
egen state_yr = group(statename year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)

/*
* Regressions for local air pollutants *
*/
foreach outcome_var in "PM" "NO2" "SO2" {
	local output_file "$output\DiD_NY_`outcome_var'_6mobins_no_neigh_cluster_styr.dta"

	reghdfe stmaxvalue_`outcome_var' ZEC_prop_NY_post_8 ZEC_start_NY_post_6 ZEC_start_NY_post_7_12 ZEC_start_NY_post_13 ZEC_prop_inter_NY_8 ZEC_start_inter_NY_6 ZEC_start_inter_NY_7_12 ZEC_start_inter_NY_13 i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
foreach outcome_var in "PM" "NO2" "SO2" {

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
	replace var = "State-by-Year FE" if exp_counter2 == 1
	replace var = "Season-by-Year FE" if exp_counter2 == 2
	forvalues i = 1/1 {
		replace reg`i' = "Yes" if var == "State-by-Year FE"
	}
	*
	replace reg1 = "Yes" if var == "Season-by-Year FE"

	*
	drop exp_counter*

	* Prepare name for caption based on variable name *
	if "`outcome_var'" == "PM" {
		local name_var "PM2.5"
	} 
	else if "`outcome_var'" == "SO2" { 
		local name_var "SO2"
	}
	else if "`outcome_var'" == "NO2" { 
		local name_var "NO2"
	}
	*

	label var reg1 "`name_var'"
	ren reg1 `outcome_var'
	
	gen merge_id = _n
	
	save "$output\NY_DiD_`outcome_var'_6mobins_formerge", replace
}
*

use "$output\NY_DiD_SO2_6mobins_formerge", clear
foreach outcome_var in "NO2" "PM" {
	merge 1:1 merge_id using "$output\NY_DiD_`outcome_var'_6mobins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id

** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_6mobins_AQS_state_yr.tex", frag varlabels nofix ///
title("Impacts on Air Quality (New York, Pre- and Post- Implementation)") size(3) marker("NY_AQS_6mobin") ///
footnote("Estimation of Equation (\ref{eq_DiD3}) where the outcome variable is monthly ambient concentrations of a local air pollutant by state from EPA's AQS Database for 2000 - 2019. Illinois and neighboring states to and neighboring states to New York and Illinois are excluded from this analysis.  Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-2 -4) replace
