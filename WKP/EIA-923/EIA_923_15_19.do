set type double
set more off
clear

cd .

global inter "intermediate"
global input "inputs"
global output "output"
global output_file "$output\Monthly_generation_96_19.xlsx"

capture mkdir inputs
capture mkdir intermediate
capture mkdir output

******************************************************

/*
1) 2015-2019 Data Processing 
*/

******************************************************

******************************************************

/*
Monthly Data Processing
*/

******************************************************

use "Monthly\Monthly2015UtilAndNonUtil.dta", clear
* Limit to relevant variables
keep year fipst fueltyp fuelnm fueldesc pmdesc *name pcode utilcode gen*
ren gen*2015 *

* Destring generation variables *
capture destring jan-dec, replace
compress
save "$inter\monthly_15_19", replace

* Append the annual files with monthly data from 2015-2019
forvalues year = 2016/2019 {
	use "Monthly\Monthly`year'UtilAndNonUtil.dta", clear
	keep year fipst fueltyp fuelnm fueldesc pmdesc *name pcode utilcode gen*
	ren gen*`year' *
	
	* Destring generation variables *
	capture destring jan-dec, replace

	append using "$inter\monthly_15_19", force
	save "$inter\monthly_15_19", replace
}
* Map fipst to state
use "$inter\monthly_15_19", clear
merge m:1 fipst using "$inter\state_mapping"
drop if _m != 3
drop _m
compress
save "$inter\monthly_15_19", replace


* Reshape data
use "$inter\monthly_15_19", clear
label var jan "GEN01"
ren (jan-dec) (GEN01 GEN02 GEN03 GEN04 GEN05 GEN06 ///
GEN07 GEN08 GEN09 GEN10 GEN11 GEN12)
* Collapse data to the plant level by fuel type
collapse (sum) GEN*, by( fipst fueltyp utilname pltname fuelnm ///
year pcode utilcode fueldesc pmdesc state region division)
* Calculate max gen in year
egen max_annual_gen = rowmax(GEN01-GEN12)

* Rename GEN vars for reshape
forvalues i = 1/9 {
	ren GEN0`i' GEN`i'
}
* Reshape the data long by month
order fipst fueltyp utilname pltname fuelnm year pcode fueldesc pmdesc state
reshape long GEN, i(fipst-state) j(month)
compress
save "$inter\monthly_15_19_reshaped", replace




******************************************************

/*
2) 1996-2019 Data Processing - Combine with 
prior data for 1996-2014
*/

******************************************************

******************************************************

/*
Monthly Data Processing
*/

******************************************************


** Append 1996-2014 and 2015-19 Monthly Data files **
use "$inter\monthly_reshaped_96_14", clear
append using "$inter\monthly_15_19_reshaped"

** REMOVE State and Fuel Totals **
drop if utilcode == 99999

compress
save "$inter\monthly_reshaped_96_19", replace

** Generate capacity variable by looking at month of max generation
use "$inter\monthly_reshaped_96_19", clear
gen max_ann_month = month if max_annual_gen == GEN & max_annual_gen > 0
gen max_beg = mdy(max_ann_month, 1, year)
format max_beg %td
drop max_ann_month
compress
save "$inter\monthly_reshaped_96_19_cap", replace

* Import date_hour mapping
import excel using "$inter\Date Hour Mapping.xlsx", firstrow clear
ren beg_month max_beg
drop if hours_in_month == .
compress
save "$inter\date_hour", replace

use "$inter\monthly_reshaped_96_19_cap", clear
merge m:1 max_beg using "$inter\date_hour"
assert _m == 3 if max_beg != .
drop _m

gen max_gen_cap = max_annual_gen/hours_in_month
compress
save "$inter\monthly_reshaped_96_19_v2", replace



******************
* Summary Tables *
******************

***
* Prepare summary tables of generation and capacity by fuel type

import excel using "Fuel Type Mapping.xlsx", firstrow clear
ren fueltypcode fueltyp
keep fueltyp Label
save "$inter\fueltypemapping", replace

use "$inter\monthly_reshaped_96_19_v2", clear
drop if fueltyp == .
* Generate derived capacity variable based on the maximum generated capacity 
* per year
bysort pcode year fueltyp pmdesc: egen capacity_der = max(max_gen_cap)

** Collapse to the state level **
collapse (sum) capacity_der capacity GEN, by(year month fueltyp state)

* Import fuel type mapping
merge m:1 fueltyp using "$inter\fueltypemapping"
assert _m != 1
drop if _m != 3
drop _m

* Remove other or purchased steam *
drop if Label == "PUR"
drop if Label == "OTH"

* Sum by fuel label type
collapse (sum) capacity_der capacity GEN, by(year month Label state)
* Re-scale vars to GWh or GW
replace GEN = GEN/10^6 if year < 1990
replace GEN = GEN/10^3 if year >= 1990

replace capacity = capacity/10^6 if year < 1990
replace capacity = capacity/10^3 if year >= 1990

replace capacity_der = capacity_der/10^6 if year < 1990
replace capacity_der = capacity_der/10^3 if year >= 1990

* Reshape wide
reshape wide capacity capacity_der GEN, i(year month state) j(Label) string

order year month capacity_der* capacity* GEN*

ren capacity_der* *_capacity_der
ren capacity* *_capacity
ren GEN* *_GEN
gen mdy = mdy(month, 1, year)
format mdy %td
order mdy year month
compress
save "$inter\monthly_totals", replace

export excel using "$output_file", sheet("Monthly_totals") firstrow(varl) sheetreplace

use "$inter\monthly_totals", clear
keep if state == "IL"
order mdy state
export excel using "$output_file", sheet("Monthly_totals_IL") firstrow(varl) sheetreplace

use "$inter\monthly_totals", clear
keep if state == "NY"
order mdy state
export excel using "$output_file", sheet("Monthly_totals_NY") firstrow(varl) sheetreplace


******************

/*
Additional Monthly Data Processing
*/

* Add processed monthly nuclear data back into overall monthly dataset
use "$inter\monthly_reshaped_96_19", clear

* Limit to continental US
drop if state == "HI" | state == "AK"

* Fill in fueltyp for observations missing fueltyp *
/* Here, fueltyp is replaced for observations where all other units with given
fuel name or pm description are a single fueltyp in the data */
replace fueltyp = 11 if fuelnm == "WOOD" & fueltyp == .
replace fueltyp = 11 if fuelnm == "INERT GAS" & fueltyp == .
replace fueltyp = 13 if pmdesc == "WI" & fueltyp == .

* Map Biomass - Waste units to fueltyp (12)
replace fueltyp = 12 if fuelnm == "TIRES" & fueltyp == .
replace fueltyp = 12 if fuelnm == "REFUSE" & fueltyp == .
replace fueltyp = 12 if fuelnm == "WASTE HT" & fueltyp == .
replace fueltyp = 12 if fuelnm == "RDF" & fueltyp == .

replace fueltyp = 12 if fueldesc == "MSB" & fueltyp == .
replace fueltyp = 12 if fueldesc == "MSN" & fueltyp == .

* Other missing - See "data.dictionaryeia.9232009.doc" *
replace fueltyp = 2 if fuelnm == "JET FUEL" & fueltyp == . 
replace fueltyp = 6 if fueldesc == "COL" & fueltyp == .
replace fueltyp = 19 if fueldesc == "SC" & fueltyp == .
replace fueltyp = 16 if fueldesc == "HPS" & fueltyp == .
replace fueltyp = 22 if fueldesc == "OOG" & fueltyp == .

* Other missing based on pltname *
replace fueltyp = 16 if regexm(pltname, "Hydro") == 1 & fueltyp == . & GEN > 0
replace fueltyp = 17 if regexm(pltname, "Solar") == 1 & fueltyp == . & GEN > 0
replace fueltyp = 17 if regexm(pltname, "SOLAR") == 1 & fueltyp == . & GEN > 0

* Based on pmdesc *
replace fueltyp = 16 if pmdesc == "HY" & fueltyp == . & GEN > 0

* Other missing - NY *
*replace fueltyp = 16 if pltname == "Curtis Palmer Hydroelectric"
replace fueltyp = 16 if pltname == "Kodak Park Site" & fueltyp == .

* Currently, being dropped *
drop if fueltyp == .

* Import fuel type mapping
merge m:1 fueltyp using "$inter\fueltypemapping"
assert _m != 1
drop if _m != 3
drop _m

* Re-scale vars to GWh or GW
replace GEN = GEN/10^6 if year < 1990
replace GEN = GEN/10^3 if year >= 1990

* Create Generation variables by fuel type
gen coal = GEN if Label == "Coal"
gen oil = GEN if Label == "Fuel_Oil"
gen gas = GEN if Label == "Natural_Gas"
gen nuclear = GEN if Label == "Nuclear"
gen hydro = GEN if Label == "Water"
gen renewables = GEN if Label == "Biomass" | Label == "Geothermal"| ///
	Label == "Solar" | Label == "Wind"

compress
save "$inter\monthly_processed_96_19", replace


/*
Prepare Data at the State-Month level
*/
use "$inter\monthly_processed_96_19", clear
collapse (sum) GEN coal-renewables, by(state year month)
ren GEN total_gen
* Generate log generation variables *
gen l_coal = ln(coal)
gen l_oil = ln(oil)
gen l_gas = ln(gas)
gen l_nuclear = ln(nuclear)
gen l_hydro = ln(hydro)
gen l_renewables = ln(renewables)
gen l_total = ln(total_gen)
* Generate date and month of sample variables *
gen my = ym(year, month)
format my %tm

* Merge in region mapping
merge m:1 state using "$inter\state_mapping"
drop if _m != 3
drop _m

compress
save "$inter\state_month_96_19", replace


**************************



** Summary of annual gen by fuel type 1996-2019
use "$inter\monthly_processed_96_19", clear

collapse (sum) coal-renewables GEN, by (year state)

* Convert Generation values  to TWh
foreach var in "coal" "oil" "gas" "nuclear" "hydro" "renewables" {
	replace `var' = `var' / 10^3
}

ren coal Coal
ren oil Fuel_Oil
ren gas Natural_Gas
ren nuclear Nuclear
ren hydro Water
ren renewables Renewable

export excel using "$output_file", sheet("Gen_by_Type") sheetreplace firstrow(var)

* Prepare summary as market shares *
use "$inter\monthly_processed_96_19", clear

collapse (sum) coal-renewables GEN, by (year state)

foreach var in "coal" "oil" "gas" "nuclear" "hydro" "renewables" {
	gen `var'_share = `var' / GEN
	replace `var' = `var'_share
	drop `var'_share
}
*
drop GEN

ren coal Coal
ren oil Fuel_Oil
ren gas Natural_Gas
ren nuclear Nuclear
ren hydro Water
ren renewables Renewable

export excel using "$output_file", sheet("Shares_by_Type") sheetreplace firstrow(var)


*********************************
