/*
This .do file uses the processed EIA-923 data on monthly net generation by fuel
type from 2000 - 2019 and estimates a series of diff-in-diff regressions
based on the announcement of the ZEC program in IL and NY.
*/
clear all
set more off

cd .
global output "output_tex"

capture mkdir "$output"

global inter_EIA "EIA-923\intermediate"


***********************************

/*

Pre- and Post- Implementation of ZECs Program

*/

***********************************
use "$inter_EIA\state_month_00_19_LMPs", clear

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
gen neighbor = 1 if state == "IN"
replace neighbor = 1 if state == "IA"
replace neighbor = 1 if state == "KY"
replace neighbor = 1 if state == "MI"
replace neighbor = 1 if state == "MO"
replace neighbor = 1 if state == "WI"

replace neighbor = 1 if state == "CT"
replace neighbor = 1 if state == "MA"
replace neighbor = 1 if state == "NJ"
replace neighbor = 1 if state == "PA"
replace neighbor = 1 if state == "VT"

replace neighbor = 0 if neighbor == .

compress


*****************
* Illinois		*
*****************
drop if NY == 1
assert state != "NY"

drop if neighbor == 1

* Generate numeric state ID *
egen state_id = group(state)

** Generate state-year FE **
egen state_yr = group(state year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)

/*
* Nuclear *
*/
foreach outcome_var in "nuclear" {
	local output_file "$output\DiD_IL_`outcome_var'_2bins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' total_gen ZEC_prop_IL_post_6 ZEC_start_IL_post ZEC_prop_inter_IL_6 ZEC_start_inter_IL, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace

	reghdfe `outcome_var' total_gen ZEC_prop_IL_post_6 ZEC_start_IL_post ZEC_prop_inter_IL_6 ZEC_start_inter_IL i.season, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg2, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) append

	reghdfe `outcome_var' total_gen ZEC_prop_IL_post_6 ZEC_start_IL_post ZEC_prop_inter_IL_6 ZEC_start_inter_IL i.month, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg3, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) append

	reghdfe `outcome_var' total_gen ZEC_prop_IL_post_6 ZEC_start_IL_post ZEC_prop_inter_IL_6 ZEC_start_inter_IL i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg4, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) append
}
*


/*
* Coal, Gas, and Renewables *
*/
foreach outcome_var in "coal" "gas" "renewables" {
	local output_file "$output\DiD_IL_`outcome_var'_2bins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' nuclear total_gen ZEC_prop_IL_post_6 ZEC_start_IL_post ZEC_prop_inter_IL_6 ZEC_start_inter_IL i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

********************************************************************************

/*

Prepare tables from regression output

*/

** Nuclear **
local outcome_var "nuclear"
use "$output\DiD_IL_`outcome_var'_2bins_no_neigh_cluster_styr.dta", clear

** Limit to preferred specification **
keep var reg4
ren reg4 reg1

* Remove FEs from table output *
drop if regexm(var, "season_yr_") == 1
drop if regexm(var, "month_") == 1
drop if regexm(var, "season_") == 1

replace var = subinstr(var,"_coef","",.)
replace var = "" if strpos(var,"_stderr")!=0
replace var = "R-squared" if var == "r2"

* Rename variables for output *
replace var = "Nuclear Generation" if var == "nuclear"
replace var = "Total Load" if var == "total_gen"
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
local name_var "Nuclear"
label var reg1 "`name_var'"
ren reg1 `outcome_var'

gen merge_id = _n+2
save "$output\IL_DiD_`outcome_var'_2bins_formerge", replace



** Non-nuclear **
foreach outcome_var in "coal" "gas" "renewables" {
	use "$output\DiD_IL_`outcome_var'_2bins_no_neigh_cluster_styr.dta", clear
	
	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "Nuclear Generation" if var == "nuclear"
	replace var = "Total Load" if var == "total_gen"
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
	if "`outcome_var'" == "gas" {
		local name_var "Natural Gas"
	} 
	else if "`outcome_var'" == "renewables" { 
		local name_var "Non-Hydro Renewable"
	}
	else if "`outcome_var'" == "coal" { 
		local name_var "Coal"
	}
	else if "`outcome_var'" == "nuclear" { 
		local name_var "Nuclear"
	}
	*
	label var reg1 "`name_var'"
	ren reg1 `outcome_var'
	
	gen merge_id = _n
	
	save "$output\IL_DiD_`outcome_var'_2bins_formerge", replace
}
*

/*
Table - Nuclear and Non-Hydro Renewables
*/
use "$output\IL_DiD_nuclear_2bins_formerge", clear
foreach outcome_var in "renewables" {
	merge 1:1 merge_id using "$output\IL_DiD_`outcome_var'_2bins_formerge"
	drop _m
}
*
sort merge_id
drop merge_id

** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_2bins_genmain_state_yr.tex", frag varlabels nofix ///
title("Impacts on Generation (Illinois, Pre- and Post- Implementation)") size(3) marker("IL_nuclear_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is monthly nuclear generation by state in GWh from EIA Form 923 for 2000 - 2019. New York and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.65\textwidth) location(ht) autonumber hlines(-4 -6) replace



/*
Appendix - Coal and Gas
*/
use "$output\IL_DiD_coal_2bins_formerge", clear
foreach outcome_var in "gas" {
	merge 1:1 merge_id using "$output\IL_DiD_`outcome_var'_2bins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id
** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_2bins_nonnuc_state_yr.tex", frag varlabels nofix ///
title("Impacts on Other Generation (Illinois, Pre- and Post- Implementation)") size(3) marker("IL_nonnuc_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is monthly net generation by state in GWh from EIA Form 923 for 2000 - 2019. New York and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.65\textwidth) location(ht) autonumber hlines(-2 -4) replace


/*
Appendix - Alt. Time FEs for Nuclear
*/
local outcome_var "nuclear"
use "$output\DiD_IL_`outcome_var'_2bins_no_neigh_cluster_styr.dta", clear

* Remove FEs from table output *
drop if regexm(var, "season_yr_") == 1
drop if regexm(var, "month_") == 1
drop if regexm(var, "season_") == 1

replace var = subinstr(var,"_coef","",.)
replace var = "" if strpos(var,"_stderr")!=0
replace var = "R-squared" if var == "r2"

* Rename variables for output *
replace var = "Nuclear Generation" if var == "nuclear"
replace var = "Total Load" if var == "total_gen"
replace var = "6-mo. Post" if var == "ZEC_prop_IL_post_6"
replace var = "ZEC Start" if var == "ZEC_start_IL_post"
replace var = "6-mo. Post x Illinois" if var == "ZEC_prop_inter_IL_6"
replace var = "ZEC Start x Illinois" if var == "ZEC_start_inter_IL"

replace var = "Constant" if var == "_cons"

/*
Flag fixed effects
*/
expand 5 if var == "N", gen(exp_counter)
gen exp_counter2 = sum(exp_counter)

forvalues i = 1/4 {
	replace reg`i' = "" if exp_counter == 1
}
*
replace var = "State-by-Year FE" if exp_counter2 == 1
replace var = "Season FE" if exp_counter2 == 2
replace var = "Month FE" if exp_counter2 == 3
replace var = "Season-by-Year FE" if exp_counter2 == 4
forvalues i = 1/4 {
	replace reg`i' = "Yes" if var == "State-by-Year FE"
}
*
replace reg2 = "Yes" if var == "Season FE"
replace reg3 = "Yes" if var == "Month FE"
replace reg4 = "Yes" if var == "Season-by-Year FE"

*
drop exp_counter*

* Prepare name for caption based on variable name *
local name_var "Nuclear"
*
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_2bins_`outcome_var'_state_yr.tex", frag nonames nofix ///
title("`name_var' Generation (Illinois, Pre- and Post- Implementation)") size(3) marker("IL_`outcome_var'_all_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) with various time fixed effects, where the outcome variable is monthly nuclear generation by state in GWh from EIA Form 923 for 2000 - 2019. New York and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-4 -6) replace



********************************************************************************


********************************************************************************



****************
/*
2) New York
*/
****************
use "$inter_EIA\state_month_00_19_LMPs", clear

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
gen neighbor = 1 if state == "IN"
replace neighbor = 1 if state == "IA"
replace neighbor = 1 if state == "KY"
replace neighbor = 1 if state == "MI"
replace neighbor = 1 if state == "MO"
replace neighbor = 1 if state == "WI"

replace neighbor = 1 if state == "CT"
replace neighbor = 1 if state == "MA"
replace neighbor = 1 if state == "NJ"
replace neighbor = 1 if state == "PA"
replace neighbor = 1 if state == "VT"

replace neighbor = 0 if neighbor == .

compress


*****************
* New York		*
*****************
drop if IL == 1
assert state != "IL"

drop if neighbor == 1

* Generate numeric state ID *
egen state_id = group(state)

** Generate state-year FE **
egen state_yr = group(state year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)


/*
* Nuclear *
*/
foreach outcome_var in "nuclear" {
	local output_file "$output\DiD_NY_`outcome_var'_2bins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' total_gen ZEC_prop_NY_post_8 ZEC_start_NY_post ZEC_prop_inter_NY_8 ZEC_start_inter_NY, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace

	reghdfe `outcome_var' total_gen ZEC_prop_NY_post_8 ZEC_start_NY_post ZEC_prop_inter_NY_8 ZEC_start_inter_NY i.season, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg2, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) append

	reghdfe `outcome_var' total_gen ZEC_prop_NY_post_8 ZEC_start_NY_post ZEC_prop_inter_NY_8 ZEC_start_inter_NY i.month, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg3, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) append

	reghdfe `outcome_var' total_gen ZEC_prop_NY_post_8 ZEC_start_NY_post ZEC_prop_inter_NY_8 ZEC_start_inter_NY i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg4, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) append
}
*


/*
* Coal, Gas, and Renewables *
*/
foreach outcome_var in "coal" "gas" "renewables" "oil" "hydro" {
	local output_file "$output\DiD_NY_`outcome_var'_2bins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' nuclear total_gen ZEC_prop_NY_post_8 ZEC_start_NY_post ZEC_prop_inter_NY_8 ZEC_start_inter_NY i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

********************************************************************************

/*

Prepare tables from regression output

*/

** Nuclear **
local outcome_var "nuclear" 

use "$output\DiD_NY_`outcome_var'_2bins_no_neigh_cluster_styr.dta", clear

** Limit to preferred specification **
keep var reg4
ren reg4 reg1

* Remove FEs from table output *
drop if regexm(var, "season_yr_") == 1
drop if regexm(var, "month_") == 1
drop if regexm(var, "season_") == 1

replace var = subinstr(var,"_coef","",.)
replace var = "" if strpos(var,"_stderr")!=0
replace var = "R-squared" if var == "r2"

* Rename variables for output *
replace var = "Nuclear Generation" if var == "nuclear"
replace var = "Total Load" if var == "total_gen"
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
local name_var "Nuclear"
label var reg1 "`name_var'"
ren reg1 `outcome_var'

gen merge_id = _n+2
save "$output\NY_DiD_`outcome_var'_2bins_formerge", replace

** Non-nuclear **
foreach outcome_var in "coal" "gas" "renewables" "oil" "hydro" {
	use "$output\DiD_NY_`outcome_var'_2bins_no_neigh_cluster_styr.dta", clear
	
	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "Nuclear Generation" if var == "nuclear"
	replace var = "Total Load" if var == "total_gen"
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

	*
	drop exp_counter*
	

	* Prepare name for caption based on variable name *
	if "`outcome_var'" == "gas" {
		local name_var "Natural Gas"
	} 
	else if "`outcome_var'" == "renewables" { 
		local name_var "Non-Hydro Renewable"
	}
	else if "`outcome_var'" == "coal" { 
		local name_var "Coal"
	}
	else if "`outcome_var'" == "nuclear" { 
		local name_var "Nuclear"
	}
	else if "`outcome_var'" == "oil" { 
		local name_var "Fuel Oil"
	}
	else if "`outcome_var'" == "hydro" { 
		local name_var "Hydro"
	}
	*

	label var reg1 "`name_var'"
	ren reg1 `outcome_var'
	
	gen merge_id = _n
	
	save "$output\NY_DiD_`outcome_var'_2bins_formerge", replace
}
*


/*
Table - Nuclear and coal generation
*/
use "$output\NY_DiD_nuclear_2bins_formerge", clear
foreach outcome_var in "coal" {
	merge 1:1 merge_id using "$output\NY_DiD_`outcome_var'_2bins_formerge"
	drop _m
}
*
sort merge_id
drop merge_id

** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_2bins_genmain_state_yr.tex", frag varlabels nofix ///
title("Impacts on Generation (New York, Pre- and Post- Implementation)") size(3) marker("NY_nuclear_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is monthly nuclear generation by state in GWh from EIA Form 923 for 2000 - 2019. Illinois and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.7\textwidth) location(ht) autonumber hlines(-4 -6) replace


/*
Appendix - Non-nuclear or coal generation
*/
use "$output\NY_DiD_gas_2bins_formerge", clear
foreach outcome_var in "renewables" "oil" "hydro" {
	merge 1:1 merge_id using "$output\NY_DiD_`outcome_var'_2bins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id

** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_2bins_nonnuc_state_yr.tex", frag varlabels nofix ///
title("Impacts on Other Generation (New York, Pre- and Post- Implementation)") size(3) marker("NY_nonnuc_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is monthly net generation by state in GWh from EIA Form 923 for 2000 - 2019. Illinois and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-2 -4) replace


/*
Appendix - Alt. Time FEs for Nuclear
*/
local outcome_var "nuclear" 
use "$output\DiD_NY_`outcome_var'_2bins_no_neigh_cluster_styr.dta", clear

* Remove FEs from table output *
drop if regexm(var, "season_yr_") == 1
drop if regexm(var, "month_") == 1
drop if regexm(var, "season_") == 1

replace var = subinstr(var,"_coef","",.)
replace var = "" if strpos(var,"_stderr")!=0
replace var = "R-squared" if var == "r2"

* Rename variables for output *
replace var = "Nuclear Generation" if var == "nuclear"
replace var = "Total Load" if var == "total_gen"
replace var = "8-mo. Post" if var == "ZEC_prop_NY_post_8"
replace var = "ZEC Start" if var == "ZEC_start_NY_post"
replace var = "8-mo. Post x New York" if var == "ZEC_prop_inter_NY_8"
replace var = "ZEC Start x New York" if var == "ZEC_start_inter_NY"

replace var = "Constant" if var == "_cons"

/*
Flag fixed effects
*/
expand 5 if var == "N", gen(exp_counter)
gen exp_counter2 = sum(exp_counter)

forvalues i = 1/4 {
	replace reg`i' = "" if exp_counter == 1
}
*
replace var = "State-by-Year FE" if exp_counter2 == 1
replace var = "Season FE" if exp_counter2 == 2
replace var = "Month FE" if exp_counter2 == 3
replace var = "Season-by-Year FE" if exp_counter2 == 4
forvalues i = 1/4 {
	replace reg`i' = "Yes" if var == "State-by-Year FE"
}
*
replace reg2 = "Yes" if var == "Season FE"
replace reg3 = "Yes" if var == "Month FE"
replace reg4 = "Yes" if var == "Season-by-Year FE"

*
drop exp_counter*

* Prepare name for caption based on variable name *
local name_var "Nuclear"

** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_2bins_`outcome_var'_state_yr.tex", frag nonames nofix ///
title("`name_var' Generation (New York, Pre- and Post- Implementation)") size(3) marker("NY_`outcome_var'_all_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) with various time fixed effects, where the outcome variable is monthly nuclear generation by state in GWh from EIA Form 923 for 2000 - 2019. Illinois and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-4 -6) replace



********************************************************************************


********************************************************************************




***********************************

/*

Using 6-month bins for Post ZEC-start periods

*/

***********************************

****************
/*
1) Illinois
*/
****************

use "$inter_EIA\state_month_00_19_LMPs", clear

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
gen neighbor = 1 if state == "IN"
replace neighbor = 1 if state == "IA"
replace neighbor = 1 if state == "KY"
replace neighbor = 1 if state == "MI"
replace neighbor = 1 if state == "MO"
replace neighbor = 1 if state == "WI"

replace neighbor = 1 if state == "CT"
replace neighbor = 1 if state == "MA"
replace neighbor = 1 if state == "NJ"
replace neighbor = 1 if state == "PA"
replace neighbor = 1 if state == "VT"

replace neighbor = 0 if neighbor == .

compress


*****************
* Illinois		*
*****************
drop if NY == 1
assert state != "NY"

drop if neighbor == 1

* Generate numeric state ID *
egen state_id = group(state)

** Generate state-year FE **
egen state_yr = group(state year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)


/*
* Nuclear *
*/
foreach outcome_var in "nuclear" {
	local output_file "$output\DiD_IL_`outcome_var'_6mobins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' total_gen ZEC_prop_IL_post_6 ZEC_start_IL_post_6 ZEC_start_IL_post_7_12 ZEC_start_IL_post_13 ZEC_prop_inter_IL_6 ZEC_start_inter_IL_6 ZEC_start_inter_IL_7_12 ZEC_start_inter_IL_13, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace

	reghdfe `outcome_var' total_gen ZEC_prop_IL_post_6 ZEC_start_IL_post_6 ZEC_start_IL_post_7_12 ZEC_start_IL_post_13 ZEC_prop_inter_IL_6 ZEC_start_inter_IL_6 ZEC_start_inter_IL_7_12 ZEC_start_inter_IL_13 i.season, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg2, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) append

	reghdfe `outcome_var' total_gen ZEC_prop_IL_post_6 ZEC_start_IL_post_6 ZEC_start_IL_post_7_12 ZEC_start_IL_post_13 ZEC_prop_inter_IL_6 ZEC_start_inter_IL_6 ZEC_start_inter_IL_7_12 ZEC_start_inter_IL_13 i.month, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg3, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) append

	reghdfe `outcome_var' total_gen ZEC_prop_IL_post_6 ZEC_start_IL_post_6 ZEC_start_IL_post_7_12 ZEC_start_IL_post_13 ZEC_prop_inter_IL_6 ZEC_start_inter_IL_6 ZEC_start_inter_IL_7_12 ZEC_start_inter_IL_13 i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg4, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) append
}
*


/*
* Coal, Gas, and Renewables *
*/
foreach outcome_var in "coal" "gas" "renewables" {
	local output_file "$output\DiD_IL_`outcome_var'_6mobins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' nuclear total_gen ZEC_prop_IL_post_6 ZEC_start_IL_post_6 ZEC_start_IL_post_7_12 ZEC_start_IL_post_13 ZEC_prop_inter_IL_6 ZEC_start_inter_IL_6 ZEC_start_inter_IL_7_12 ZEC_start_inter_IL_13 i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

********************************************************************************


/*
Prepare tables from regression output
*/

** Nuclear **
local outcome_var "nuclear"
use "$output\DiD_IL_`outcome_var'_6mobins_no_neigh_cluster_styr.dta", clear

* Remove FEs from table output *
drop if regexm(var, "season_yr_") == 1
drop if regexm(var, "month_") == 1
drop if regexm(var, "season_") == 1

replace var = subinstr(var,"_coef","",.)
replace var = "" if strpos(var,"_stderr")!=0
replace var = "R-squared" if var == "r2"

* Rename variables for output *
replace var = "Nuclear Generation" if var == "nuclear"
replace var = "Total Load" if var == "total_gen"
replace var = "6-mo. Post" if var == "ZEC_prop_IL_post_6"
replace var = "ZEC Start (1-6mo.)" if var == "ZEC_start_IL_post_6"
replace var = "ZEC Start (7-12mo.)" if var == "ZEC_start_IL_post_7_12"
replace var = "ZEC Start (1 year+)" if var == "ZEC_start_IL_post_13"
replace var = "6-mo. Post x Illinois" if var == "ZEC_prop_inter_IL_6"
replace var = "ZEC Start (1-6mo.) x Illinois" if var == "ZEC_start_inter_IL_6"
replace var = "ZEC Start (7-12mo.) x Illinois" if var == "ZEC_start_inter_IL_7_12"
replace var = "ZEC Start (13mo.) x Illinois" if var == "ZEC_start_inter_IL_13"

replace var = "Constant" if var == "_cons"

/*
Flag fixed effects
*/
expand 5 if var == "N", gen(exp_counter)
gen exp_counter2 = sum(exp_counter)

forvalues i = 1/4 {
	replace reg`i' = "" if exp_counter == 1
}
*
replace var = "State-by-Year FE" if exp_counter2 == 1
replace var = "Season FE" if exp_counter2 == 2
replace var = "Month FE" if exp_counter2 == 3
replace var = "Season-by-Year FE" if exp_counter2 == 4
forvalues i = 1/4 {
	replace reg`i' = "Yes" if var == "State-by-Year FE"
}
*
replace reg2 = "Yes" if var == "Season FE"
replace reg3 = "Yes" if var == "Month FE"
replace reg4 = "Yes" if var == "Season-by-Year FE"

*
drop exp_counter*

* Prepare name for caption based on variable name *
local name_var "Nuclear"

** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_6mobins_`outcome_var'_state_yr.tex", frag nonames nofix ///
title("`name_var' Generation (Illinois, Short Term Breakdown)") size(3) marker("IL_`outcome_var'_6mobin") ///
footnote("Estimation of Equation (\ref{eq_DiD3}) with varying time fixed effects, where the outcome variable is monthly nuclear generation by state in GWh from EIA Form 923 for 2000 - 2019. New York and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-4 -6) replace
*

** Non-nuclear **
foreach outcome_var in "coal" "gas" "renewables" {

	use "$output\DiD_IL_`outcome_var'_6mobins_no_neigh_cluster_styr.dta", clear
	
	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "Nuclear Generation" if var == "nuclear"
	replace var = "Total Load" if var == "total_gen"
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
	if "`outcome_var'" == "gas" {
		local name_var "Natural Gas"
	} 
	else if "`outcome_var'" == "renewables" { 
		local name_var "Non-Hydro Renewables"
	}
	else if "`outcome_var'" == "coal" { 
		local name_var "Coal"
	}
	else if "`outcome_var'" == "nuclear" { 
		local name_var "Nuclear"
	}
	*

	label var reg1 "`name_var'"
	ren reg1 `outcome_var'
	
	gen merge_id = _n
	
	save "$output\IL_DiD_`outcome_var'_6mobins_formerge", replace
}
*

use "$output\IL_DiD_coal_6mobins_formerge", clear
foreach outcome_var in "gas" "renewables" {
	merge 1:1 merge_id using "$output\IL_DiD_`outcome_var'_6mobins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_6mobins_nonnuc_state_yr.tex", frag varlabels nofix ///
title("Impacts on Other Generation (Illinois, Short Term Breakdown)") size(3) marker("IL_nonnuc_6mobin") ///
footnote("Estimation of Equation (\ref{eq_DiD3}) where the outcome variable is monthly net generation by state in GWh from EIA Form 923 for 2000 - 2019. New York and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-2 -4) replace



*************************************************

****************
/*
2) New York
*/
****************

use "$inter_EIA\state_month_00_19_LMPs", clear

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
gen neighbor = 1 if state == "IN"
replace neighbor = 1 if state == "IA"
replace neighbor = 1 if state == "KY"
replace neighbor = 1 if state == "MI"
replace neighbor = 1 if state == "MO"
replace neighbor = 1 if state == "WI"

replace neighbor = 1 if state == "CT"
replace neighbor = 1 if state == "MA"
replace neighbor = 1 if state == "NJ"
replace neighbor = 1 if state == "PA"
replace neighbor = 1 if state == "VT"

replace neighbor = 0 if neighbor == .

compress


*****************
* New York		*
*****************
drop if IL == 1
assert state != "IL"

drop if neighbor == 1

* Generate numeric state ID *
egen state_id = group(state)

** Generate state-year FE **
egen state_yr = group(state year)

* Gen season indicator *
gen season = 1 if month >= 3 & month <= 5
replace season = 2 if month >= 6 & month <= 8
replace season = 3 if month >= 9 & month <= 11
replace season = 4 if season == .

egen season_yr = group(season year)


/*
* Nuclear *
*/
foreach outcome_var in "nuclear" {
	local output_file "$output\DiD_NY_`outcome_var'_6mobins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' total_gen ZEC_prop_NY_post_8 ZEC_start_NY_post_6 ZEC_start_NY_post_7_12 ZEC_start_NY_post_13 ZEC_prop_inter_NY_8 ZEC_start_inter_NY_6 ZEC_start_inter_NY_7_12 ZEC_start_inter_NY_13, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace

	reghdfe `outcome_var' total_gen ZEC_prop_NY_post_8 ZEC_start_NY_post_6 ZEC_start_NY_post_7_12 ZEC_start_NY_post_13 ZEC_prop_inter_NY_8 ZEC_start_inter_NY_6 ZEC_start_inter_NY_7_12 ZEC_start_inter_NY_13 i.season, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg2, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) append

	reghdfe `outcome_var' total_gen ZEC_prop_NY_post_8 ZEC_start_NY_post_6 ZEC_start_NY_post_7_12 ZEC_start_NY_post_13 ZEC_prop_inter_NY_8 ZEC_start_inter_NY_6 ZEC_start_inter_NY_7_12 ZEC_start_inter_NY_13 i.month, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg3, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) append

	reghdfe `outcome_var' total_gen ZEC_prop_NY_post_8 ZEC_start_NY_post_6 ZEC_start_NY_post_7_12 ZEC_start_NY_post_13 ZEC_prop_inter_NY_8 ZEC_start_inter_NY_6 ZEC_start_inter_NY_7_12 ZEC_start_inter_NY_13 i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg4, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) append
}
*


/*
* Coal, Gas, and Renewables *
*/
foreach outcome_var in "coal" "gas" "renewables" "oil" "hydro" {
	local output_file "$output\DiD_NY_`outcome_var'_6mobins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' nuclear total_gen ZEC_prop_NY_post_8 ZEC_start_NY_post_6 ZEC_start_NY_post_7_12 ZEC_start_NY_post_13 ZEC_prop_inter_NY_8 ZEC_start_inter_NY_6 ZEC_start_inter_NY_7_12 ZEC_start_inter_NY_13 i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

********************************************************************************


/*
Prepare tables from regression output
*/

** Nuclear **
local outcome_var "nuclear"

use "$output\DiD_NY_`outcome_var'_6mobins_no_neigh_cluster_styr.dta", clear

* Remove FEs from table output *
drop if regexm(var, "season_yr_") == 1
drop if regexm(var, "month_") == 1
drop if regexm(var, "season_") == 1

replace var = subinstr(var,"_coef","",.)
replace var = "" if strpos(var,"_stderr")!=0
replace var = "R-squared" if var == "r2"

* Rename variables for output *
replace var = "Nuclear Generation" if var == "nuclear"
replace var = "Total Load" if var == "total_gen"
replace var = "6-mo. Post" if var == "ZEC_prop_NY_post_8"
replace var = "ZEC Start (1-6mo.)" if var == "ZEC_start_NY_post_6"
replace var = "ZEC Start (7-12mo.)" if var == "ZEC_start_NY_post_7_12"
replace var = "ZEC Start (1 year+)" if var == "ZEC_start_NY_post_13"
replace var = "6-mo. Post x New York" if var == "ZEC_prop_inter_NY_8"
replace var = "ZEC Start (1-6mo.) x New York" if var == "ZEC_start_inter_NY_6"
replace var = "ZEC Start (7-12mo.) x New York" if var == "ZEC_start_inter_NY_7_12"
replace var = "ZEC Start (13mo.) x New York" if var == "ZEC_start_inter_NY_13"

replace var = "Constant" if var == "_cons"

/*
Flag fixed effects
*/
expand 5 if var == "N", gen(exp_counter)
gen exp_counter2 = sum(exp_counter)

forvalues i = 1/4 {
	replace reg`i' = "" if exp_counter == 1
}
*
replace var = "State-by-Year FE" if exp_counter2 == 1
replace var = "Season FE" if exp_counter2 == 2
replace var = "Month FE" if exp_counter2 == 3
replace var = "Season-by-Year FE" if exp_counter2 == 4
forvalues i = 1/4 {
	replace reg`i' = "Yes" if var == "State-by-Year FE"
}
*
replace reg2 = "Yes" if var == "Season FE"
replace reg3 = "Yes" if var == "Month FE"
replace reg4 = "Yes" if var == "Season-by-Year FE"

*
drop exp_counter*

* Prepare name for caption based on variable name *
local name_var "Nuclear"

** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_6mobins_`outcome_var'_state_yr.tex", frag nonames nofix ///
title("`name_var' Generation (New York, Short Term Breakdown)") size(3) marker("NY_`outcome_var'_6mobin") ///
footnote("Estimation of Equation (\ref{eq_DiD3}) where the outcome variable is monthly net generation by state in GWh from EIA Form 923 for 2000 - 2019. Illinois and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-4 -6) replace
*


** Non-nuclear **
foreach outcome_var in "coal" "gas" "renewables" "oil" "hydro" {

	use "$output\DiD_NY_`outcome_var'_6mobins_no_neigh_cluster_styr.dta", clear
	
	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "Nuclear Generation" if var == "nuclear"
	replace var = "Total Load" if var == "total_gen"
	replace var = "8-mo. Post" if var == "ZEC_prop_NY_post_8"
	replace var = "ZEC (1-6mo.)" if var == "ZEC_start_NY_post_6"
	replace var = "ZEC (7-12mo.)" if var == "ZEC_start_NY_post_7_12"
	replace var = "ZEC (1 year+)" if var == "ZEC_start_NY_post_13"
	replace var = "6-mo. Post x NY" if var == "ZEC_prop_inter_NY_8"
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
	if "`outcome_var'" == "gas" {
		local name_var "Natural Gas"
	} 
	else if "`outcome_var'" == "renewables" { 
		local name_var "Non-Hydro Renewables"
	}
	else if "`outcome_var'" == "coal" { 
		local name_var "Coal"
	}
	else if "`outcome_var'" == "nuclear" { 
		local name_var "Nuclear"
	}
	else if "`outcome_var'" == "oil" { 
		local name_var "Fuel Oil"
	}
	else if "`outcome_var'" == "hydro" { 
		local name_var "Hydro"
	}
	*

	label var reg1 "`name_var'"
	ren reg1 `outcome_var'
	
	gen merge_id = _n
	
	save "$output\NY_DiD_`outcome_var'_6mobins_formerge", replace
}
*

use "$output\NY_DiD_coal_6mobins_formerge", clear
foreach outcome_var in "gas" "renewables" "oil" "hydro" {
	merge 1:1 merge_id using "$output\NY_DiD_`outcome_var'_6mobins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_6mobins_nonnuc_state_yr.tex", frag varlabels nofix ///
title("Impacts on Other Generation (New York, Short Term Breakdown)") size(3) marker("NY_nonnuc_6mobin") ///
footnote("Estimation of Equation (\ref{eq_DiD3}) where the outcome variable is monthly net generation by state in GWh from EIA Form 923 for 2000 - 2019. Illinois and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-2 -4) replace
