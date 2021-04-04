/*
This .do file processes raw data on monthly LMP indices for ISO-NE. The data 
begins in July 2013, and presents the average monthly LMP for both the DA and 
RT markets by reference hubs (primarily state-level).  
*/
clear all
set type double
set more off

cd .

global input "inputs"
global inter "intermediate"

capture mkdir "$input"
capture mkdir "$inter"


********************************************************************************
/*

Import .csv files for ISO-NE Monthly Day-Ahead LMP Indices

*/
********************************************************************************

** 2013-2019 (data begins in 2013; all missing for years prior) **
forvalues year = 2013/2019 {
	import delimited using "$input\dartmonthlylmpindex_`year'.csv", varnames(5) case(l) clear
	drop in 1
	drop h
	destring *, replace
	drop if locationid == .
	compress
	save "$inter\ISONE_DA_LMP_`year'", replace
}
*


clear
** Append data into a single data file **
forvalues year = 2013/2019{
	append using "$inter\ISONE_DA_LMP_`year'"
}
gen date = date(monthbegin, "MDY")
format date %td

gen year = year(date)
gen month = month(date)
gen my = ym(year, month)
drop date year month
format my %tm

compress
save "$inter\ISONE_DA_LMP_2013_19", replace
