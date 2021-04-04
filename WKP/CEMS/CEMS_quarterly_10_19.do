/*
This .do file processes quarterly level data from EPA's CEMS database for the 
period 2010-2019 and performs a series of diff-in-diff regression analyses for
the announcement and implementation of the ZECs programs in Illinois and New 
York.
*/
set type double
set more off
clear all

cd .

global inter "qtly_intermediate"
global input "qtly_unzipped"
global output "output"

capture mkdir "$inter"
capture mkdir "$output"

** Import quarterly level CEMS data **
forvalues yr = 2010(1)2019 {
	foreach state in "al" "ar" "az" "ca" "co" "ct" "dc" "de" "fl" "ga" "ia" "id" "il" "in" ///
	"ks" "ky" "la" "ma" "md" "me" "mi" "mn" "mo" "ms" "mt" "nc" "nd" "ne" "nh" "nj" "nm" "nv" ///
	"ny" "oh" "ok" "or" "pa" "ri" "sc" "sd" "tn" "tx" "ut" "va" "vt" "wa" "wi" "wv" "wy" {
		forvalues qtr = 1(1)4 {
			import delimited using "$input\DLY_`yr'`state'Q`qtr'.csv", varnames(1) case(lower) clear
			tostring unitid, replace
			compress
			save "$inter\DLY_`yr'`state'Q`qtr'.dta", replace
		}
	}
}
*

clear all
forvalues yr = 2010(1)2019 {
	foreach state in "al" "ar" "az" "ca" "co" "ct" "dc" "de" "fl" "ga" "ia" "id" "il" "in" ///
	"ks" "ky" "la" "ma" "md" "me" "mi" "mn" "mo" "ms" "mt" "nc" "nd" "ne" "nh" "nj" "nm" "nv" ///
	"ny" "oh" "ok" "or" "pa" "ri" "sc" "sd" "tn" "tx" "ut" "va" "vt" "wa" "wi" "wv" "wy" {
		forvalues qtr = 1(1)4 {
			append using "$inter\DLY_`yr'`state'Q`qtr'.dta"
		}
	}
}
compress
save "$inter\CEMS_daily_10_19", replace


use "$inter\CEMS_daily_10_19", clear

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

* Drop neighboring states *
drop if neighbor == 1

/*
** Collapse data to monthly level **
*/
gen date = date(op_date, "MDY")
gen month = month(date)
gen year = year(date)

collapse (sum) *_masstons gloadmwh, by(state month year neighbor)

gen co2_thousandtons = co2_masstons / 10^3
label var co2_thousandtons "Monthly CO2 emissions ('000 short tons)"

gen my = ym(year, month)
format my %tm

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

compress

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
save "$inter\CEMS_monthly_noneighbors_10_19", replace



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
use "$inter\CEMS_monthly_noneighbors_10_19", clear

/*
Binned post-indicators 
*/

* Create post-indicators for after ZEC program was proposed up to implementation *
gen ZEC_prop_NY_post_8 = (my >= ym(2016, 8) & my < ym(2017, 4))
gen ZEC_prop_IL_post_6 = (my >= ym(2016, 12) & my < ym(2017, 6))

* Generate interactions between post indicators and state *
gen ZEC_prop_inter_IL_6 = ZEC_prop_IL_post_6 * IL
gen ZEC_prop_inter_NY_8 = ZEC_prop_NY_post_8 * NY


*****************
* Illinois		*
*****************
drop if NY == 1
assert state != "NY"

drop if neighbor == 1

/*
* C02 *
*/
foreach outcome_var in "co2_thousandtons" {
	local output_file "$output\DiD_IL_`outcome_var'_2bins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' ZEC_prop_IL_post_6 ZEC_start_IL_post ZEC_prop_inter_IL_6 ZEC_start_inter_IL i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
local outcome_var "co2_thousandtons"

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
local name_var "CO2"

label var reg1 "`name_var'"
ren reg1 `outcome_var'

	
** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_2bins_CO2_state_yr.tex", frag varlabels nofix ///
title("Impacts on CO2 Emissions (Illinois, Pre- and Post- Implementation)") size(5) marker("IL_CO2_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is monthly emissions ('000 short tons) of CO2 by state from EPA's CEMS Database for 2010 - 2019. New York and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.5\textwidth) location(ht) autonumber hlines(-2 -4) replace


****************
/*
2) New York
*/
****************

use "$inter\CEMS_monthly_noneighbors_10_19", clear

/*
Binned post-indicators 
*/

* Create post-indicators for after ZEC program was proposed up to implementation *
gen ZEC_prop_NY_post_8 = (my >= ym(2016, 8) & my < ym(2017, 4))
gen ZEC_prop_IL_post_6 = (my >= ym(2016, 12) & my < ym(2017, 6))

* Generate interactions between post indicators and state *
gen ZEC_prop_inter_IL_6 = ZEC_prop_IL_post_6 * IL
gen ZEC_prop_inter_NY_8 = ZEC_prop_NY_post_8 * NY

*****************
* New York		*
*****************
drop if IL == 1
assert state != "IL"

/*
* Regressions for local air pollutants *
*/
foreach outcome_var in "co2_thousandtons" {
	local output_file "$output\DiD_NY_`outcome_var'_2bins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' ZEC_prop_NY_post_8 ZEC_start_NY_post ZEC_prop_inter_NY_8 ZEC_start_inter_NY i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
local outcome_var "co2_thousandtons"

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
local name_var "CO2"

label var reg1 "`name_var'"
ren reg1 `outcome_var'

** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_2bins_CO2_state_yr.tex", frag varlabels nofix ///
title("Impacts on CO2 Emissions (New York, Pre- and Post- Implementation)") size(5) marker("NY_CO2_2bin") ///
footnote("Estimation of Equation (\ref{eq_DiD2}) where the outcome variable is monthly emissions ('000 short tons) of CO2 by state from EPA's CEMS Database for 2010 - 2019. Illinois and neighboring states to New York and Illinois are excluded from this analysis. Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.5\textwidth) location(ht) autonumber hlines(-2 -4) replace






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

use "$inter\CEMS_monthly_noneighbors_10_19", clear

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

compress

drop if NY == 1
assert state != "NY"

/*
* Regressions for local air pollutants *
*/
foreach outcome_var in "co2_thousandtons" {
	local output_file "$output\DiD_IL_`outcome_var'_6mobins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' ZEC_prop_IL_post_6 ZEC_start_IL_post_6 ZEC_start_IL_post_7_12 ZEC_start_IL_post_13 ZEC_prop_inter_IL_6 ZEC_start_inter_IL_6 ZEC_start_inter_IL_7_12 ZEC_start_inter_IL_13 i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
local outcome_var "co2_thousandtons"
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
local name_var "CO2"

label var reg1 "`name_var'"
ren reg1 `outcome_var'

** Use texsave to export with label **
texsave using "$output\Table_DiD_IL_6mobins_CO2_state_yr.tex", frag varlabels nofix ///
title("Impacts on Air Quality (Illinois, Pre- and Post- Implementation)") size(5) marker("IL_CO2_6mobin") ///
footnote("Estimation of Equation (\ref{eq_DiD3}) where the outcome variable is monthly emissions ('000 short tons) of CO2 by state from EPA's CEMS Database for 2010 - 2019. New York and neighboring states to New York and Illinois are excluded from this analysis.  Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.5\textwidth) location(ht) autonumber hlines(-2 -4) replace


****************
/*
4) New York
*/
****************

use "$inter\CEMS_monthly_noneighbors_10_19", clear

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

compress

drop if IL == 1
assert state != "IL"

/*
* Regressions for local air pollutants *
*/
foreach outcome_var in "co2_thousandtons" {
	local output_file "$output\DiD_NY_`outcome_var'_6mobins_no_neigh_cluster_styr.dta"

	reghdfe `outcome_var' ZEC_prop_NY_post_8 ZEC_start_NY_post_6 ZEC_start_NY_post_7_12 ZEC_start_NY_post_13 ZEC_prop_inter_NY_8 ZEC_start_inter_NY_6 ZEC_start_inter_NY_7_12 ZEC_start_inter_NY_13 i.season_yr, absorb(state_yr) cluster(state_yr)
	regsave using "`output_file'", table(reg1, format(%5.2f) parentheses(stderr) asterisk(10 5 1) order(regvars r2 N)) replace
}
*

/*
Prepare tables from regression output
*/
local outcome_var "co2_thousandtons"
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

label var reg1 "CO2"
ren reg1 `outcome_var'


** Use texsave to export with label **
texsave using "$output\Table_DiD_NY_6mobins_CO2_state_yr.tex", frag varlabels nofix ///
title("Impacts on Air Quality (New York, Pre- and Post- Implementation)") size(5) marker("NY_CO2_6mobin") ///
footnote("Estimation of Equation (\ref{eq_DiD3}) where the outcome variable is monthly emissions ('000 short tons) of CO2 by state from EPA's CEMS Database for 2010 - 2019. Illinois and neighboring states to New York and Illinois are excluded from this analysis.  Standard errors clustered by state-by-year in parentheses. ***, **, and * represent significance at 1\%, 5\%, and 10\%, respectively.") ///
width(.5\textwidth) location(ht) autonumber hlines(-2 -4) replace
