/*
This .do file prepares a dataset with monthly net generation from EIA-923 and 
average monthly day-ahead hub LMPs (processed in other .do files), to be used 
in our regression analysis.
*/
clear all
set type double
set more off

cd .

global output "output"

global inter_EIA "EIA-923\intermediate"
global inter_MISO "MISO DA\intermediate"
global inter_PJM "PJM DA\intermediate"
global inter_NYISO "NYISO DA\intermediate_refbus"


****************
/*
Prepare PJM DA for merge (Illinois)
*/
****************
use "$inter_PJM\PJM_DA_hubs_2000_2019.dta", clear
drop marginal congestion system datetime pnode_id

ren total_lmp_da LMP
label var LMP "Day-Ahead Hourly LMP"
label var he "Hour Ending (1-24)"

keep if pnode_name == "CHICAGO HUB" | pnode_name == "N ILLINOIS HUB"

** Collapse to avg. hourly LMP by Node **
collapse (mean) LMP, by(he pnode_name date year month day)

replace pnode_name = strtoname(pnode_name)
reshape wide LMP, i(he date year month day) j(pnode_name) string

ren LMPCHI* LMP_CHICAGO
ren LMPN_ILL* LMP_N_ILLINOIS

** Collapse to monthly level **
collapse (mean) LMP_*, by(year month)

label var LMP_CHICAGO "Avg. DA LMP (PJM; Chicago Hub)"
label var LMP_N_ILLINOIS "Avg. DA LMP (PJM; N Illinois Hub)"

gen my = ym(year, month)
format my %tm

gen state = "IL"

compress
save "$inter_PJM\PJM_DA_ILL_2000_2019_formerge", replace


****************
/*
Prepare MISO DA for merge (Illinois)
*/
****************
use "$inter_MISO\MISO_DA_hubs_2005_2019.dta", clear

keep if value == "LMP"

drop value type market_day

ren he LMP
ren hour he
label var LMP "Day-Ahead Hourly LMP"
label var he "Hour Ending (1-24)"

keep if node == "ILLINOIS.HUB"

** Collapse to monthly level **
collapse (mean) LMP, by(year month)

ren LMP LMP_MISO_ILLINOIS
label var LMP_MISO_ILLINOIS "Avg. DA LMP (MISO, Illinois Hub)"

gen my = ym(year, month)
format my %tm

gen state = "IL"

compress
save "$inter_MISO\MISO_DA_ILL_2000_2019_formerge", replace


****************
/*
Prepare NYISO DA for merge
*/
****************
use "$inter_NYISO\NYISO_DA_LMP_2000_2019.dta", clear

* Generate hour ending variable *
gen clock = clock(timestamp, "MDYhm")
format clock %tc
gen hour = hh(clock)
replace hour = hour + 1
assert hour != 0
assert hour <= 24
label var hour "Hour Ending (1-24
ren hour he

drop timestamp clock MCL MCC ptid name

gen year = year(date)
gen month = month(date)


** Collapse to monthly level **
collapse (mean) LMP, by(year month)

ren LMP LMP_NYISO
label var LMP_NYISO "Avg. DA LMP (NYISO, NYISO Ref. Hub)"

gen my = ym(year, month)
format my %tm

gen state = "NY"

compress
save "$inter_NYISO\NYISO_DA_2000_2019_formerge", replace




********************************************************************************


/*
Merge LMP data with monthly data on net generation from EIA-923 - All States
*/

use "$inter_EIA\state_month_96_19", clear

keep if year >= 2000 /// limiting to 2000 onwards based on LMP data availability

merge 1:1 my state using "$inter_PJM\PJM_DA_ILL_2000_2019_formerge"
assert _m != 2
drop _m

merge 1:1 my state using "$inter_MISO\MISO_DA_ILL_2000_2019_formerge"
assert _m != 2
drop _m

merge 1:1 my state using "$inter_NYISO\NYISO_DA_2000_2019_formerge"
assert _m != 2
drop _m

gen ZEC_proposed = 1 if my == ym(2016, 8) & state == "NY"
replace ZEC_proposed = 1 if my == ym(2016, 12) & state == "IL"

gen ZEC_start = 1 if my == ym(2017, 4) & state == "NY"
replace ZEC_start = 1 if my == ym(2017, 6) & state == "IL"

* Create post-indicators for after ZEC program was proposed *
gen ZEC_prop_NY_post = (my >= ym(2016, 8))
gen ZEC_prop_IL_post = (my >= ym(2016, 12))

* Create post-indicators for after ZEC program was implemented *
gen ZEC_start_NY_post = (my >= ym(2017, 4))
gen ZEC_start_IL_post = (my >= ym(2017, 6))

* Generate state indicators for DiD *
gen IL = (state == "IL")
gen NY = (state == "NY")

* Generate interactions between post indicators and state *
gen ZEC_prop_inter_IL = ZEC_prop_IL_post * IL
gen ZEC_start_inter_IL = ZEC_start_IL_post * IL

gen ZEC_prop_inter_NY = ZEC_prop_NY_post * NY
gen ZEC_start_inter_NY = ZEC_start_NY_post * NY

compress
save "$inter_EIA\state_month_00_19_LMPs", replace
