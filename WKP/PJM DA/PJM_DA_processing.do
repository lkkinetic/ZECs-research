/*
This .do file processes raw data for 2000 - 2019 on PJM DA LMPs for major hubs
and combines the files into a single Stata dataset. It also exports monthly
avg. LMPs for major hubs to be used in creating the Figures of generation and 
LMP in the main paper and appendix.
*/
clear all
set type double
set more off

cd .

global input "inputs"
global inter "intermediate"
global output "output"

global output_file "$output\PJM_Avg_DA_LMP.xlsx"

capture mkdir "$input"
capture mkdir "$inter"
capture mkdir "$output"


* 2000-2013 *
forvalues year = 2000(1)2013 {
	import delimited using "$input\da_hrl_lmps_`year'_HUB.csv", varn(1) clear
	
	assert voltage == .
	assert equipment == .
	assert zone == .
	assert row_is_current == "True"
	assert type == "HUB"
	
	drop voltage equipment zone row_is_current *_utc type
	
	gen date = date(datetime_beginning_ept, "MDY hms")
	format date %td
	
	gen date_clock = clock(datetime_beginning_ept, "MDY hms")
	format date_clock %tc
	
	gen hour = hh(date_clock)
	gen he = hour + 1
	drop hour date_clock

	compress
	save "$inter\PJM_hubs_`year'", replace
}
*

* 2014-2017 *
forvalues year = 2014(1)2017 {
	import delimited using "$input\da_hrl_lmps_PJM_Jan_Dec_`year'_HUB.csv", varn(1) clear
	
	assert voltage == .
	assert equipment == .
	assert zone == .
	assert row_is_current == "True"
	assert type == "HUB"
	
	drop voltage equipment zone row_is_current *_utc type
	
	gen date = date(datetime_beginning_ept, "MDY hms")
	format date %td
	
	gen date_clock = clock(datetime_beginning_ept, "MDY hms")
	format date_clock %tc
	
	gen hour = hh(date_clock)
	gen he = hour + 1
	drop hour date_clock

	compress
	save "$inter\PJM_hubs_`year'", replace
}
*

/*
Processing 2018 in parts due to issues downloading full year data
*/
* Apr-Dec. 2018 *
import delimited using "$input\da_hrl_lmps_PJM_Apr_Dec_2018_HUB.csv", varn(1) clear
assert voltage == .
assert equipment == .
assert zone == .
assert row_is_current == "True"
assert type == "HUB"

drop voltage equipment zone row_is_current *_utc type

gen date = date(datetime_beginning_ept, "MDY hms")
format date %td

gen date_clock = clock(datetime_beginning_ept, "MDY hms")
format date_clock %tc

gen hour = hh(date_clock)
gen he = hour + 1
drop hour date_clock

compress
save "$inter\PJM_hubs_2018_Apr_Dec", replace
*
* March 1-16 2018 *
import delimited using "$input\da_hrl_lmps_PJM_Mar1_Mar16_2018_HUB.csv", varn(1) clear
assert voltage == .
assert equipment == .
assert zone == .
assert row_is_current == "True"
assert type == "HUB"

drop voltage equipment zone row_is_current *_utc type

gen date = date(datetime_beginning_ept, "MDY hms")
format date %td

gen date_clock = clock(datetime_beginning_ept, "MDY hms")
format date_clock %tc

gen hour = hh(date_clock)
gen he = hour + 1
drop hour date_clock

compress
save "$inter\PJM_hubs_2018_Marchp1", replace

* March 17-31 2018 *
import delimited using "$input\da_hrl_lmps_PJM_Mar17_Mar31_2018_HUB.csv", varn(1) clear
assert voltage == .
assert equipment == .
assert zone == .
assert row_is_current == "True"
assert type == "HUB"

drop voltage equipment zone row_is_current *_utc type

gen date = date(datetime_beginning_ept, "MDY hms")
format date %td

gen date_clock = clock(datetime_beginning_ept, "MDY hms")
format date_clock %tc

gen hour = hh(date_clock)
gen he = hour + 1
drop hour date_clock

compress
save "$inter\PJM_hubs_2018_Marchp2", replace

* Append 2018 datasets *
clear all
append using "$inter\PJM_hubs_2018_Marchp1"
append using "$inter\PJM_hubs_2018_Marchp2"
append using "$inter\PJM_hubs_2018_Apr_Dec"
compress
save "$inter\PJM_hubs_2018", replace


* 2019 *
forvalues year = 2019(1)2019 {
	import delimited using "$input\da_hrl_lmps_PJM_Jan_Dec_`year'_HUB.csv", varn(1) clear
	
	assert voltage == .
	assert equipment == .
	assert zone == .
	assert type == "HUB"
	
	drop voltage equipment zone row_is_current *_utc type
	
	gen date = date(datetime_beginning_ept, "MDY hms")
	format date %td
	
	gen date_clock = clock(datetime_beginning_ept, "MDY hms")
	format date_clock %tc
	
	gen hour = hh(date_clock)
	gen he = hour + 1
	drop hour date_clock

	compress
	save "$inter\PJM_hubs_`year'", replace
}
*


** Append all into a single dataset **
clear all
forvalues year = 2000(1)2013 {
	append using "$inter\PJM_hubs_`year'"
}
gen month = month(date)
gen year = year(date)
gen day = day(date)

drop version_nbr 
append using "$inter\PJM_DA_hubs_2014_2019"
compress
save "$inter\PJM_DA_hubs_2000_2019", replace
*


*********************************************************
/*

Collapse to Avg. LMPs by Year-Month for Major PJM Hubs (2014-2019)

*/
*********************************************************

use "$inter\PJM_DA_hubs_2014_2019", clear
drop congestion marginal_loss system

ren total_lmp_da LMP
label var LMP "Day-Ahead Hourly LMP"
label var he "Hour Ending (1-24)"

** Collapse to monthly avg. hourly LMP by Node **
collapse (mean) LMP, by(he pnode_name year month)

gen my = ym(year, month)
format my %tm

sort pnode my he

export excel using "$output_file", sheet("AvgHrlybyMonth") firstrow(var) sheetreplace

use "$inter\PJM_DA_hubs_2014_2019", clear
drop congestion marginal_loss system

ren total_lmp_da LMP
label var LMP "Day-Ahead Hourly LMP"
label var he "Hour Ending (1-24)"

** Collapse to monthly avg. LMP by Node **
collapse (mean) LMP, by(pnode_name year month)

gen my = ym(year, month)
format my %tm

sort pnode my 

export excel using "$output_file", sheet("AvgMonthly") firstrow(var) sheetreplace




*********************************************************
/*

Collapse to Avg. LMPs by Year-Month for Major PJM Hubs (2000-2019)

*/
*********************************************************

use "$inter\PJM_DA_hubs_2000_2019", clear
drop congestion marginal_loss system

ren total_lmp_da LMP
label var LMP "Day-Ahead Hourly LMP"
label var he "Hour Ending (1-24)"

** Collapse to monthly avg. hourly LMP by Node **
collapse (mean) LMP, by(he pnode_name year month)

gen my = ym(year, month)
format my %tm

sort pnode my he

export excel using "$output_file", sheet("AvgHrlybyMonth_00") firstrow(var) sheetreplace

use "$inter\PJM_DA_hubs_2000_2019", clear
drop congestion marginal_loss system

ren total_lmp_da LMP
label var LMP "Day-Ahead Hourly LMP"
label var he "Hour Ending (1-24)"

** Collapse to monthly avg. LMP by Node **
collapse (mean) LMP, by(pnode_name year month)

gen my = ym(year, month)
format my %tm

sort pnode my 

export excel using "$output_file", sheet("AvgMonthly_00") firstrow(var) sheetreplace
