clear all
set type double
set more off
set maxvar 32767

cd .

global inter "intermediate"
global input "inputs"
global output "output"

capture mkdir "$input"
capture mkdir "$inter"
capture mkdir "$output"

* Import data into Stata format *
forvalues year = 2000(1)2019 {
	insheet using "$input\daily_42602_`year'.csv", comma names clear
	
	* Destring statecode variable where necessary *
	destring statecode, force replace
	drop if statecode == .
	
	* Create date variables *
	gen local_date = date(datelocal, "YMD")
	format local_date %td
	gen month = month(local_date)
	gen day = day(local_date)
	
	gen weekday = dow(local_date)
	
	* Generate counter of weekday (e.g. 1st Monday)?
	preserve
	keep month day weekday
	duplicates drop
	save "$inter\dates_`year'", replace

	forvalues i = 0/6 {	
		use "$inter\dates_`year'", clear
		keep if weekday == `i'
		sort month day
		bysort month: gen weekday_count = _n
		save "$inter\weekday_`year'_`i'", replace
	}
	use "$inter\weekday_`year'_0", clear
	forvalues i = 1/6 {	
		append using "$inter\weekday_`year'_`i'"
	}
	save "$inter\weekday_`year'", replace

	* Merge back in weekday_counter *
	restore
	merge m:1 month day weekday using "$inter\weekday_`year'"
	assert _m == 3
	drop _m
	
	forvalues i = 0/6 {	
		erase "$inter\weekday_`year'_`i'.dta"
	}
	*
	erase "$inter\dates_`year'.dta"
	erase "$inter\weekday_`year'.dta"
	
	* Drop unused variables *
	drop parametername unitsofmeasure methodname localsitename address eventtype
	drop pollutantstandard datum sampleduration observationcount observationpercent
	
	compress
	save "$inter\42602_daily_`year'", replace
}
*


********

/*
Append annual datasets
*/
clear all
forvalues year = 2000(1)2019 {
	append using "$inter\42602_daily_`year'"
}
*
gen year = year(local_date)
gen mdy = mdy(month, day, year)

ren statecode fipst

* limit to observations in US *
drop if fipst == 80
drop if fipst == 72
drop if fipst == 78


** Generate climate regions **
generate climreg = 1 if fipst==17 | fipst==18 | ///
	fipst==21 | fipst==29 | fipst==39 | ///
	fipst==47 | fipst==54
replace climreg = 2 if fipst==19 | fipst==26 | ///
	fipst==27 | fipst==55 
replace climreg = 3 if fipst==9 | fipst==10 | ///
	fipst==11 | fipst==23 | fipst==24 | ///
	fipst==25 | fipst==33 | fipst==34 | ///
	fipst==36 | fipst==42 | fipst==44 | ///
	fipst==50
replace climreg = 4 if fipst==16 |fipst==41 | ///
	fipst==53
replace climreg = 5 if fipst==5 | fipst==20 | ///
	fipst==22 | fipst==28 | fipst==40 | ///
	fipst==48
replace climreg = 6 if fipst==1 | fipst==12 | ///
	fipst==13 | fipst==37 | fipst==45 | ///
	fipst==51
replace climreg = 7 if fipst==4 |fipst==8 | ///
	fipst==35 |fipst==49
replace climreg = 8 if fipst==6 |fipst==32
replace climreg = 9 if fipst==30 | fipst==31 | ///
	fipst==38 | fipst==46 | fipst==56

label define climreg_s 1 "Ohio Valley" 2 "Upper Midwest" ///
					3 "Northeast" 4 "Northwest" 5 "South" ///
					6 "Southeast" 7 "Southwest" 8 "West" 9 "Rockies"
label values climreg climreg_s			

* Limit to lower 48 states *
drop if climreg == .

egen monitor = group(fipst countycode sitenum parametercode poc)

compress
save "$inter\NO2_daily_00_19", replace





/*
Prepare monthly, state-level dataset for analysis
*/

use "$inter\NO2_daily_00_19", clear

* Generate county_fips as state_fips and county code *
tostring countycode, gen(county_str)
replace county_str= "0" + county_str if strlen(county_str) == 2
replace county_str= "00" + county_str if strlen(county_str) == 1
tostring fipst, gen(state_str)
gen county_fips = state_str + county_str
drop *_str countycode
destring county_fips, replace

/*
Flag 1st and last year counties appear in the dataset
*/
bysort fipst county_fips: egen min_year = min(year)
bysort fipst county_fips: egen max_year = max(year)

* Collapse to county-level *
collapse (mean) stmaxvalue, by(local_date weekday climreg year month fipst state county_fips)
* Then, to state-level *
collapse (mean) stmaxvalue, by(local_date weekday climreg year month fipst state)
*export excel using "$output_file", sheet("Daily_state") firstrow(var) sheetreplace
* Then, by month *
collapse (mean) stmaxvalue, by(climreg year month fipst state)

*export excel using "$output_file", sheet("Monthly_state") firstrow(var) sheetreplace

ren stmaxvalue stmaxvalue_NO2
label var stmaxvalue_NO2 "Daily Avg. Maximum NO2 (parts per billion)"

compress
save "$output\NO2_monthly_state_avg_00_19", replace
