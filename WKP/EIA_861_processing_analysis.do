/*
This .do file processes data from EIA-861 on monthly average retail prices by
state for 2000-2019 and estimates a series of diff-in-diff regressions
based on the announcement of the ZEC program in IL and NY
*/
clear all
set more off

cd "EIA-861"

global input "inputs"
global inter "intermediate"
global output "output"

capture mkdir "$inter"
capture mkdir "$output"

***********************


/*
Import EIA-861 data on monthly retail prices by state
*/

import excel using "$input\sales_revenue.xlsx", sheet("Monthly-States") cellrange("A3:AB18567") firstrow case(l) clear

destring *, replace
* Drop other/transportation sectors *
drop q - x

* Rename and label variables *
ren thousanddollars res_revenue
ren megawatthours res_sales
ren count res_count
ren centskwh res_price

label var res_revenue "Residential Revenue ($ thousand)"
label var res_sales "Residential Sales (MWh)"
label var res_count "Residential Customer Count"
label var res_price "Residential Price (cents/kWh)"

ren i com_revenue
ren j com_sales
ren k com_count
ren l com_price

label var com_revenue "Commercial Revenue ($ thousand)"
label var com_sales "Commercial Sales (MWh)"
label var com_count "Commercial Customer Count"
label var com_price "Commercial Price (cents/kWh)"

ren m ind_revenue
ren n ind_sales
ren o ind_count
ren p ind_price

label var ind_revenue "Industrial Revenue ($ thousand)"
label var ind_sales "Industrial Sales (MWh)"
label var ind_count "Industrial Customer Count"
label var ind_price "Industrial Price (cents/kWh)"

ren y tot_revenue
ren z tot_sales
ren aa tot_count
ren ab tot_price

label var tot_revenue "Total Revenue ($ thousand)"
label var tot_sales "Total Sales (MWh)"
label var tot_count "Total Customer Count"
label var tot_price "Total Price (cents/kWh)"

* Date range *
keep if year >= 2000 & year <= 2019

* Generate month-year variable and restrict to lower 48 states *
gen my = ym(year, month)
format my %tm

drop if state == "AK"
drop if state == "HI"

/*
Prepare dataset for analyses
*/
* Generate state indicators for DiD *
gen IL = (state == "IL")
gen NY = (state == "NY")

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
save "$inter\state_month_EIA_861_00_19", replace


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
use "$inter\state_month_EIA_861_00_19", clear

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
* Retail Price Regressions *
*/
foreach outcome_var in "res" "com" "ind" "tot" {
	local output_file "$output\DiD_IL_`outcome_var'_2bins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var'_price `outcome_var'_sales ZEC_prop_IL_post_6 ZEC_start_IL_post ZEC_prop_inter_IL_6 ZEC_start_inter_IL i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
foreach outcome_var in "res" "com" "ind" "tot" {

	use "$output\DiD_IL_`outcome_var'_2bins_no_neigh_cluster_styr.dta", clear

	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "Sales (MWh)" if var == "`outcome_var'_sales"
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
	if "`outcome_var'" == "res" {
		local name_var "Residential"
	} 
	else if "`outcome_var'" == "com" { 
		local name_var "Commercial"
	}
	else if "`outcome_var'" == "ind" { 
		local name_var "Industrial"
	}
	else if "`outcome_var'" == "tot" { 
		local name_var "Total"
	}
	*

	label var reg1 "`name_var'"
	ren reg1 `outcome_var'
	
	gen merge_id = _n
	
	save "$output\IL_DiD_`outcome_var'_2bins_formerge", replace
}
*

/*
Table - Residential Retail Prices
*/
use "$output\IL_DiD_res_2bins_formerge", clear
drop merge_id
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_2bins_retail_state_yr.tex", frag varlabels nofix ///
title("Impacts on Retail Prices (Illinois, Pre- and Post- Implementation)") size(3) marker("IL_retail_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is the monthly average retail price. Data from EIA's Form 861 for 2000 - 2019 on monthly average retail prices by state. New York and neighboring states to both Illinois and New York are excluded from this analysisis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.4\textwidth) location(ht) autonumber hlines(-2 -4) replace

/*
Appendix - All Retail Price Categories
*/
use "$output\IL_DiD_res_2bins_formerge", clear
foreach outcome_var in "com" "ind" "tot" {
	merge 1:1 merge_id using "$output\IL_DiD_`outcome_var'_2bins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_2bins_retail_all_state_yr.tex", frag varlabels nofix ///
title("Impacts on Retail Prices (Illinois, Pre- and Post- Implementation)") size(3) marker("IL_retail_all_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is the monthly average retail price. Data from EIA's Form 861 for 2000 - 2019 on monthly average retail prices by state. New York and neighboring states to both Illinois and New York are excluded from this analysisis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-2 -4) replace


*************************************************


****************
/*
2) New York
*/
****************
use "$inter\state_month_EIA_861_00_19", clear

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
* Retail Price Regressions *
*/
foreach outcome_var in "res" "com" "ind" "tot" {
	local output_file "$output\DiD_NY_`outcome_var'_2bins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var'_price `outcome_var'_sales ZEC_prop_NY_post_8 ZEC_start_NY_post ZEC_prop_inter_NY_8 ZEC_start_inter_NY i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
foreach outcome_var in "res" "com" "ind" "tot" {

	use "$output\DiD_NY_`outcome_var'_2bins_no_neigh_cluster_styr.dta", clear

	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "Sales (MWh)" if var == "`outcome_var'_sales"
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
	if "`outcome_var'" == "res" {
		local name_var "Residential"
	} 
	else if "`outcome_var'" == "com" { 
		local name_var "Commercial"
	}
	else if "`outcome_var'" == "ind" { 
		local name_var "Industrial"
	}
	else if "`outcome_var'" == "tot" { 
		local name_var "Total"
	}
	*

	label var reg1 "`name_var'"
	ren reg1 `outcome_var'
	
	gen merge_id = _n
	
	save "$output\NY_DiD_`outcome_var'_2bins_formerge", replace
}
*

/*
Table - Residential, Commercial, and Total
*/
use "$output\NY_DiD_res_2bins_formerge", clear
foreach outcome_var in "com" "tot" {
	merge 1:1 merge_id using "$output\NY_DiD_`outcome_var'_2bins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_2bins_retail_state_yr.tex", frag varlabels nofix ///
title("Impacts on Retail Prices (New York, Pre- and Post- Implementation)") size(3) marker("NY_retail_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is the monthly average retail price. Data from EIA's Form 861 for 2000 - 2019 on monthly average retail prices by state. Illinois and neighboring states to both Illinois and New York are excluded from this analysisis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.85\textwidth) location(ht) autonumber hlines(-2 -4) replace

/*
Appendix - All Retail Price Categories
*/
use "$output\NY_DiD_res_2bins_formerge", clear
foreach outcome_var in "com" "ind" "tot" {
	merge 1:1 merge_id using "$output\NY_DiD_`outcome_var'_2bins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id
	
** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_2bins_retail_all_state_yr.tex", frag varlabels nofix ///
title("Impacts on Retail Prices (New York, Pre- and Post- Implementation)") size(3) marker("NY_retail_all_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is the monthly average retail price. Data from EIA's Form 861 for 2000 - 2019 on monthly average retail prices by state. Illinois and neighboring states to both Illinois and New York are excluded from this analysisis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-2 -4) replace



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

use "$inter\state_month_EIA_861_00_19", clear

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
* Retail Price Regressions *
*/
foreach outcome_var in "res" "com" "ind" "tot" {
	local output_file "$output\DiD_IL_`outcome_var'_6mobins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var'_price `outcome_var'_sales ZEC_prop_IL_post_6 ZEC_start_IL_post_6 ZEC_start_IL_post_7_12 ZEC_start_IL_post_13 ZEC_prop_inter_IL_6 ZEC_start_inter_IL_6 ZEC_start_inter_IL_7_12 ZEC_start_inter_IL_13 i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*


/*
Prepare tables from regression output
*/
foreach outcome_var in "res" "com" "ind" "tot" {
	use "$output\DiD_IL_`outcome_var'_6mobins_no_neigh_cluster_styr.dta", clear

	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "Sales (MWh)" if var == "`outcome_var'_sales"
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
	if "`outcome_var'" == "res" {
		local name_var "Residential"
	} 
	else if "`outcome_var'" == "com" { 
		local name_var "Commercial"
	}
	else if "`outcome_var'" == "ind" { 
		local name_var "Industrial"
	}
	else if "`outcome_var'" == "tot" { 
		local name_var "Total"
	}
	*

	label var reg1 "`name_var'"
	ren reg1 `outcome_var'
	
	gen merge_id = _n
	
	save "$output\IL_DiD_`outcome_var'_6mobins_formerge", replace
}
*

use "$output\IL_DiD_res_6mobins_formerge", clear
foreach outcome_var in "com" "ind" "tot" {
	merge 1:1 merge_id using "$output\IL_DiD_`outcome_var'_6mobins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id

** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_6mobins_retail_state_yr.tex", frag varlabels nofix ///
title("Impacts on Retail Prices (Illinois, Short Term Breakdown)") size(3) marker("IL_retail_6mobin") ///
footnote("Estimation of Equation (\ref{eq_DiD3}) where the outcome variable is the monthly average retail price. Data from EIA's Form 861 for 2000 - 2019 on monthly average retail prices by state. New York and neighboring states to both Illinois and New York are excluded from this analysisis.  Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-2 -4) replace



*************************************************

****************
/*
4) New York
*/
****************

use "$inter\state_month_EIA_861_00_19", clear

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
* Retail Price Regressions *
*/
foreach outcome_var in "res" "com" "ind" "tot" {
	local output_file "$output\DiD_NY_`outcome_var'_6mobins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var'_price `outcome_var'_sales ZEC_prop_NY_post_8 ZEC_start_NY_post_6 ZEC_start_NY_post_7_12 ZEC_start_NY_post_13 ZEC_prop_inter_NY_8 ZEC_start_inter_NY_6 ZEC_start_inter_NY_7_12 ZEC_start_inter_NY_13 i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace

}
*

/*
Prepare tables from regression output
*/
foreach outcome_var in "res" "com" "ind" "tot" {
	use "$output\DiD_NY_`outcome_var'_6mobins_no_neigh_cluster_styr.dta", clear
	
	* Remove FEs from table output *
	drop if regexm(var, "season_yr_") == 1
	drop if regexm(var, "month_") == 1
	drop if regexm(var, "season_") == 1

	replace var = subinstr(var,"_coef","",.)
	replace var = "" if strpos(var,"_stderr")!=0
	replace var = "R-squared" if var == "r2"

	* Rename variables for output *
	replace var = "Sales (MWh)" if var == "`outcome_var'_sales"
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
	if "`outcome_var'" == "res" {
		local name_var "Residential"
	} 
	else if "`outcome_var'" == "com" { 
		local name_var "Commercial"
	}
	else if "`outcome_var'" == "ind" { 
		local name_var "Industrial"
	}
	else if "`outcome_var'" == "tot" { 
		local name_var "Total"
	}
	*

	label var reg1 "`name_var'"
	ren reg1 `outcome_var'
	
	gen merge_id = _n
	
	save "$output\NY_DiD_`outcome_var'_6mobins_formerge", replace
}
*

use "$output\NY_DiD_res_6mobins_formerge", clear
foreach outcome_var in "com" "ind" "tot" {
	merge 1:1 merge_id using "$output\NY_DiD_`outcome_var'_6mobins_formerge"
	assert _m == 3
	drop _m
}
*
drop merge_id

** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_6mobins_retail_state_yr.tex", frag varlabels nofix ///
title("Impacts on Retail Prices (New York, Short Term Breakdown)") size(3) marker("NY_retail_6mobin") ///
footnote("Estimation of Equation (\ref{eq_DiD3}) where the outcome variable is the monthly average retail price. Data from EIA's Form 861 for 2000 - 2019 on monthly average retail prices by state. Illinois and neighboring states to both Illinois and New York are excluded from this analysisis.  Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
location(ht) autonumber hlines(-2 -4) replace
