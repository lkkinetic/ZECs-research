/*
This .do file prepares a series of graphs used to check for parallel trends
in the monthly data across our outcomes of interest.  These graphs are 
presented in the Appendix.
*/
clear all
set more off

cd .

global inter_EIA "EIA-923\intermediate"
global inter_LMP "intermediate_LMP"
global inter_861 "EIA-861\intermediate"
global inter_AQS "EPA AQS\inter_all"
global inter_CO2 "CEMS\qtly_intermediate"

global output "output_trends"

capture mkdir "$output"


*****************************************************************************
/*

Net Generation by Fuel Type

*/
*****************************************************************************


*****************
* Illinois		*
*****************
use "$inter_EIA\state_month_00_19_LMPs", clear

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

*** Illinois ***
drop if NY == 1
assert state != "NY"

drop if neighbor == 1
collapse (mean) nuclear coal gas renewables, by(IL my)

foreach outcome in nuclear coal gas renewables {

	twoway (line `outcome' my if IL == 0, lcolor(gs8) lpattern(longdash)) (line `outcome' my if IL == 1, lcolor(black)), xline(683) ///
	legend(label(1 "Control") label(2 "Illinois")) graphregion(fcolor(white)) ///
	xlabel(#6) xtitle("Month") ytitle("Avg. Monthly Generation (GWh)")
	graph export "$output\IL_`outcome'.pdf", replace
	graph export "$output\IL_`outcome'.png", replace
}
*


*****************
* New York		*
*****************
use "$inter_EIA\state_month_00_19_LMPs", clear

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

*** New York ***
drop if IL == 1
assert state != "IL"

drop if neighbor == 1

collapse (mean) nuclear coal gas renewables oil hydro, by(NY my)

foreach outcome in nuclear coal gas renewables oil hydro {

	twoway (line `outcome' my if NY == 0, lcolor(gs8) lpattern(longdash)) (line `outcome' my if NY == 1, lcolor(black)), xline(679) ///
	legend(label(1 "Control") label(2 "New York")) graphregion(fcolor(white)) ///
	xlabel(#6) xtitle("Month") ytitle("Avg. Monthly Generation (GWh)")
	graph export "$output\NY_`outcome'.pdf", replace
	graph export "$output\NY_`outcome'.png", replace
}
*



*****************************************************************************
/*

LMP

*/
*****************************************************************************

*****************
* New York		*
*****************

use "$inter_LMP\state_month_LMP_00_13_19", clear

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

* Limit to years with coverage across all ISOs *
keep if year >= 2013

collapse (mean) LMP, by(NY my)

foreach outcome in LMP {

	twoway (line `outcome' my if NY == 0, lcolor(gs8) lpattern(longdash)) (line `outcome' my if NY == 1, lcolor(black)), xline(679) ///
	legend(label(1 "Control") label(2 "NYISO")) graphregion(fcolor(white)) ///
	xlabel(#6) xtitle("Month") ytitle("Avg. LMP ($/MWh)")
	graph export "$output\NY_`outcome'.pdf", replace
	graph export "$output\NY_`outcome'.png", replace
}
*


****************
/*
2) Illinois
*/
****************
use "$inter_LMP\state_month_LMP_00_13_19", clear

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

* Limit to years with coverage across all ISOs *
keep if year >= 2013

collapse (mean) LMP, by(IL my)

foreach outcome in LMP {

	twoway (line `outcome' my if IL == 0, lcolor(gs8) lpattern(longdash)) (line `outcome' my if IL == 1, lcolor(black)), xline(683) ///
	legend(label(1 "Control") label(2 "MISO - Illinois Hub")) graphregion(fcolor(white)) ///
	xlabel(#6) xtitle("Month") ytitle("Avg. LMP ($/MWh)")
	graph export "$output\IL_MISO_`outcome'.pdf", replace
	graph export "$output\IL_MISO_`outcome'.png", replace
}
*


/*
** (B): PJM - Chicago Hub **
*/
restore
drop if IL == 1 & pnode != "CHICAGO HUB"

* Generate numeric hub ID *
egen hub_id = group(pnode)

* Limit to years with coverage across all ISOs *
keep if year >= 2013

collapse (mean) LMP, by(IL my)

foreach outcome in LMP {

	twoway (line `outcome' my if IL == 0, lcolor(gs8) lpattern(longdash)) (line `outcome' my if IL == 1, lcolor(black)), xline(683) ///
	legend(label(1 "Control") label(2 "PJM - Chicago Hub")) graphregion(fcolor(white)) ///
	xlabel(#6) xtitle("Month") ytitle("Avg. LMP ($/MWh)")
	graph export "$output\IL_PJM_`outcome'.pdf", replace
	graph export "$output\IL_PJM_`outcome'.png", replace
}
*

*****************************************************************************
/*

Retail Prices

*/
*****************************************************************************

****************
/*
1) Illinois
*/
****************

use "$inter_861\state_month_EIA_861_00_19", clear

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

collapse (mean) *_price, by(IL my)

foreach outcome in res com ind tot {

	twoway (line `outcome' my if IL == 0, lcolor(gs8) lpattern(longdash)) (line `outcome' my if IL == 1, lcolor(black)), xline(683) ///
	legend(label(1 "Control") label(2 "Illinois")) graphregion(fcolor(white)) ///
	xlabel(#6) xtitle("Month") ytitle("Avg. Price ($/MWh)")
	graph export "$output\IL_`outcome'_price.pdf", replace
	graph export "$output\IL_`outcome'_price.png", replace
}
*


****************
/*
2) New York
*/
****************
use "$inter_861\state_month_EIA_861_00_19", clear

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

collapse (mean) *_price, by(NY my)

foreach outcome in res com ind tot {

	twoway (line `outcome' my if NY == 0, lcolor(gs8) lpattern(longdash)) (line `outcome' my if NY == 1, lcolor(black)), xline(679) ///
	legend(label(1 "Control") label(2 "New York")) graphregion(fcolor(white)) ///
	xlabel(#6) xtitle("Month") ytitle("Avg. Price ($/MWh)")
	graph export "$output\NY_`outcome'_price.pdf", replace
	graph export "$output\NY_`outcome'_price.png", replace
}
*


*****************************************************************************
/*

Air Quality

*/
*****************************************************************************


****************
/*
1) Illinois
*/
****************
use "$inter_AQS\state_month_AQS_00_19", clear

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

collapse (mean) stmaxvalue*, by(IL my)
ren stmaxvalue_* *

foreach outcome in PM NO2 SO2 {

	if "`outcome'" == "PM" {
		local units "({&mu}/m{sup:3})"
	}
	else {
		local units "(ppb)"
	}

	twoway (line `outcome' my if IL == 0, lcolor(gs8) lpattern(longdash)) (line `outcome' my if IL == 1, lcolor(black)), xline(683) ///
	legend(label(1 "Control") label(2 "Illinois")) graphregion(fcolor(white)) ///
	xlabel(#6) xtitle("Month") ytitle("Avg. Concentration `units'")
	graph export "$output\IL_`outcome'_AQS.pdf", replace
	graph export "$output\IL_`outcome'_AQS.png", replace
}
*

****************
/*
2) New York
*/
****************
use "$inter_AQS\state_month_AQS_00_19", clear

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
egen state_id = group(state)

collapse (mean) stmaxvalue*, by(NY my)
ren stmaxvalue_* *

foreach outcome in PM NO2 SO2 {

	if "`outcome'" == "PM" {
		local units "({&mu}/m{sup:3})"
	}
	else {
		local units "(ppb)"
	}

	twoway (line `outcome' my if NY == 0, lcolor(gs8) lpattern(longdash)) (line `outcome' my if NY == 1, lcolor(black)), xline(679) ///
	legend(label(1 "Control") label(2 "New York")) graphregion(fcolor(white)) ///
	xlabel(#6) xtitle("Month") ytitle("Avg. Concentration `units'")
	graph export "$output\NY_`outcome'_AQS.pdf", replace
	graph export "$output\NY_`outcome'_AQS.png", replace
}
*


*****************************************************************************
/*

CO2 Emissions

*/
*****************************************************************************


****************
/*
1) Illinois
*/
****************
use "$inter_CO2\CEMS_monthly_noneighbors_00_19", clear

drop if year < 2010

drop if NY == 1
assert state != "NY"

collapse (mean) co2_thousandtons, by(IL my)

ren co2_thousandtons CO2
label var CO2 "Monthly CO2 emissions ('000 short tons)"

foreach outcome in CO2 {

	twoway (line `outcome' my if IL == 0, lcolor(gs8) lpattern(longdash)) (line `outcome' my if IL == 1, lcolor(black)), xline(683) ///
	legend(label(1 "Control") label(2 "Illinois")) graphregion(fcolor(white)) ///
	xlabel(#6) xtitle("Month") ytitle("Avg. CO2 Emissions ('000 tons)")
	graph export "$output\IL_`outcome'_CEMS.pdf", replace
	graph export "$output\IL_`outcome'_CEMS.png", replace
}
*

****************
/*
2) New York
*/
****************
use "$inter_CO2\CEMS_monthly_noneighbors_00_19", clear

drop if year < 2010

drop if IL == 1
assert state != "IL"

collapse (mean) co2_thousandtons, by(NY my)

ren co2_thousandtons CO2
label var CO2 "Monthly CO2 emissions ('000 short tons)"


foreach outcome in CO2 {

	twoway (line `outcome' my if NY ==0, lcolor(gs8) lpattern(longdash)) (line `outcome' my if NY ==1, lcolor(black)), xline(683) ///
	legend(label(1 "Control") label(2 "New York")) graphregion(fcolor(white)) ///
	xlabel(#6) xtitle("Month") ytitle("Avg. CO2 Emissions ('000 tons)")
	graph export "$output\NY_`outcome'_CEMS.pdf", replace
	graph export "$output\NY_`outcome'_CEMS.png", replace
}
*
