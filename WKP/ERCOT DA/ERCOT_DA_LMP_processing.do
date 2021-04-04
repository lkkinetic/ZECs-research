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

Import .xlsx files for ERCOT Day-Ahead LMP

*/
********************************************************************************

* 2010 - Dec_1 *
forvalues year = 2010/2010{
	* Dec *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Dec_1") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_12", replace
}
* 2011 - 2016 *
forvalues year = 2011/2016{
	* Jan *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Jan_1") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_1", replace
	* Feb *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Feb_2") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_2", replace
	* Mar *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Mar_3") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_3", replace
	* Apr *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Apr_4") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_4", replace
	* May *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("May_5") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_5", replace
	* Jun *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Jun_6") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_6", replace
	* Jul *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Jul_7") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_7", replace
	* Aug *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Aug_8") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_8", replace
	* Sep *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Sep_9") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_9", replace
	* Oct *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Oct_10") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_10", replace
	* Nov *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Nov_11") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_11", replace
	* Dec *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Dec_12") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_12", replace
}
*
* 2017 - 2019 *
forvalues year = 2017/2019{
	* Jan *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Jan") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_1", replace
	* Feb *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Feb") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_2", replace
	* Mar *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Mar") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_3", replace
	* Apr *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Apr") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_4", replace
	* May *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("May") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_5", replace
	* Jun *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Jun") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_6", replace
	* Jul *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Jul") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_7", replace
	* Aug *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Aug") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_8", replace
	* Sep *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Sep") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_9", replace
	* Oct *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Oct") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_10", replace
	* Nov *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Nov") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_11", replace
	* Dec *
	import excel using "$input\rpt.00013060.0000000000000000.DAMLZHBSPP_`year'.xlsx", sheet("Dec") firstrow case(l) clear
	save "$inter\ERCOT_DA_LMP_`year'_12", replace
}
*

** Append data into a single data file **
use "$inter\ERCOT_DA_LMP_2010_12", clear
forvalues year = 2011/2019{
	forvalues mo = 1/12 {
		append using "$inter\ERCOT_DA_LMP_`year'_`mo'"
	}
}
gen date = date(deliverydate, "MDY")
format date %td

gen he = substr(hourending,1,2)
destring he, replace
label var he "Hour Ending (1-24)"
drop hourending

ren settlementpointprice LMP
label var LMP "Price ($/MWh)"
compress
save "$inter\ERCOT_DA_LMP_2010_19", replace
*
