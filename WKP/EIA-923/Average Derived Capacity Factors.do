/*
This .do file takes as an input the processed, monthly EIA-923 data and derives
a measure of capacity based on the maximum monthly generation within a given 
year.  We then calculate the capacity factor based on this derived measure and
present a series of graphs in the Appendix.
*/
set type double
set more off
clear all

cd .

global inter "intermediate"
global output "output"

capture mkdir "$inter"
capture mkdir "$output"

/*
Monthly average capacity factor by fuel type
*/
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

/*
Calculate implied monthly capacity factor
*/
gen month_day1 = mdy(month, 1, year)
gen month_dayend = mdy(month+1, 1, year) - 1
replace month_dayend = mdy(1, 1, year+1) - 1 if month == 12
format month_day* %td

gen days_in_month = month_dayend - month_day1 + 1

gen CF_der = GEN / (days_in_month * 24 * capacity_der)

* Remove anomalous CFs based on near-zero capacity *
replace CF_der = . if capacity_der < .0001 & CF_der > 1
replace CF_der = . if capacity_der < .0001 & CF_der < -1

* Adjust for rounding to cap CF at 1 *
replace CF_der = 1 if CF_der > 1 & CF_der < 1.11
replace CF_der = -1 if CF_der <- 1

gen my = ym(year, month)
format my %tm

keep if year > 1999

preserve
** Collapse by fuel type and month-year **
collapse (mean) GEN CF_der, by(year month my Label)

twoway line CF_der my if Label == "Nuclear", lcolor(gs8) xlabel(480(48)719) ///
xtitle("Month-Year") ytitle("Derived Capacity Factor (%)") graphregion(fcolor(white))
graph export "$output\Monthly_CF_National_Nuclear.png", replace
graph export "$output\Monthly_CF_National_Nuclear.pdf", replace

restore

preserve
** Collapse by fuel type, state, and month-year **
collapse (mean) GEN CF_der, by(year month my state Label)

twoway line CF_der my if Label == "Nuclear" & state == "IL", lcolor(gs8) xlabel(480(48)719) ///
xline(683, lcolor(black) lwidth(medthick) lpattern(longdash)) ///
xtitle("Month-Year") ytitle("Derived Capacity Factor (%)") graphregion(fcolor(white))
graph export "$output\Monthly_CF_Illinois_Nuclear.png", replace
graph export "$output\Monthly_CF_Illinois_Nuclear.pdf", replace

twoway line CF_der my if Label == "Nuclear" & state == "IL" & year > 2013, lcolor(gs8) xlabel(#8) ///
xline(683, lcolor(black) lwidth(medthick) lpattern(longdash)) ///
ylabel(.8(.05)1) xtitle("Month-Year") ytitle("Derived Capacity Factor (%)") graphregion(fcolor(white))
graph export "$output\Monthly_CF_Illinois_Nuclear_14_19.png", replace
graph export "$output\Monthly_CF_Illinois_Nuclear_14_19.pdf", replace

twoway line CF_der my if Label == "Nuclear" & state == "NY", lcolor(gs8) xlabel(480(48)719) ///
xline(679, lcolor(black) lwidth(medthick) lpattern(longdash)) ///
xtitle("Month-Year") ytitle("Derived Capacity Factor (%)") graphregion(fcolor(white))
graph export "$output\Monthly_CF_NewYork_Nuclear.png", replace
graph export "$output\Monthly_CF_NewYork_Nuclear.pdf", replace

twoway line CF_der my if Label == "Nuclear" & state == "NY" & year > 2013, xlabel(#6) ///
lcolor(gs8) xline(683, lcolor(black) lwidth(medthick) lpattern(longdash)) ///
xtitle("Month-Year") ytitle("Derived Capacity Factor (%)") graphregion(fcolor(white))
graph export "$output\Monthly_CF_NewYork_Nuclear_14_19.png", replace
graph export "$output\Monthly_CF_NewYork_Nuclear_14_19.pdf", replace

restore

*******************************************************************************
