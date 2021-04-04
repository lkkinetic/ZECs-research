/*
This .do file processes raw MISO DA LMP data on (1) daily LMPs for 2005-2012,  
(2) daily data from quarterly files for Fall 2012-Fall 2013, and (3) daily data 
from quarterly files for 2014-2019 and combines them into a single dataset. It 
also exports monthly avg. LMPs for major hubs to be used in creating the 
Figures of generation and LMP in the main paper and appendix.
*/
clear all
set type double
set more off

cd .

global input "inputs"
global inter "intermediate"
global output "output"

capture mkdir "$input"
capture mkdir "$inter"
capture mkdir "$output"


********************************************************************************

/*
Import daily DA LMPs for 2005 - 2012
*/
forvalues year = 2005(1)2012 {
	if `year' == 2005 {
		forvalues mo = 4/12 {
			forvalues day = 1/31 {
				*
				if `mo' < 10 {
					if `day' < 10 {
						capture import delimited using "$input\\`year'0`mo'0`day'_da_lmp.csv", varn(1) clear
					}
					else {
						capture import delimited using "$input\\`year'0`mo'`day'_da_lmp.csv", varn(1) clear
					}
				}
				else {
				
					if `day' < 10 {
						capture import delimited using "$input\\`year'`mo'0`day'_da_lmp.csv", varn(1) clear
					}
					else {
						capture import delimited using "$input\\`year'`mo'`day'_da_lmp.csv", varn(1) clear
					}
				}	

				* Rename variables based on titular row *
				capture drop if v2 == ""
				foreach var of varlist * {
					capture replace `var' = strtoname(`var') in 1
					capture rename `var' `=`var'[1]'
				}
				capture drop in 1 
				capture destring *, replace
				*
				capture gen date = mdy(`mo', `day', `year')
				capture format date %td
				capture compress
				capture save "$inter\DA_LMP_`year'_`mo'_`day'", replace
				
			*
			}
			di "`mo'"
			
		}
	}

*
	else {
		di "`year'"
		forvalues mo = 1/12 {
			forvalues day = 1/31 {
				*
				if `mo' < 10 {
					if `day' < 10 {
						capture import delimited using "$input\\`year'0`mo'0`day'_da_lmp.csv", varn(1) clear
					}
					else {
						capture import delimited using "$input\\`year'0`mo'`day'_da_lmp.csv", varn(1) clear
					}
				}
				else {
				
					if `day' < 10 {
						capture import delimited using "$input\\`year'`mo'0`day'_da_lmp.csv", varn(1) clear
					}
					else {
						capture import delimited using "$input\\`year'`mo'`day'_da_lmp.csv", varn(1) clear
					}
				}	

				* Rename variables based on titular row *
				capture drop if v2 == ""
				foreach var of varlist * {
					capture replace `var' = strtoname(`var') in 1
					capture rename `var' `=`var'[1]'
				}
				capture drop in 1 
				capture destring *, replace
				*
				capture gen date = mdy(`mo', `day', `year')
				format date %td
				compress
				capture save "$inter\DA_LMP_`year'_`mo'_`day'", replace
				
			}
			di "`mo'"
		}
	}
}
*/

**************
/*
Append 2005-2012 files together
*/
**************
/*
First, append to Monthly Level
*/
clear all
forvalues year = 2005(1)2005 {
	clear
	forvalues mo = 4/12 {
		forvalues day = 1/31 {
			capture append using "$inter\DA_LMP_`year'_`mo'_`day'.dta"
		}
	* Remove observations for duplicate dates (e.g. Feb. 30th or June 31st) *
	drop if Node == ""
	capture drop AEBN* Interface*
	compress
	save "$inter\MISO_DA_LMP_`year'_`mo'.dta", replace
	clear
	}
}
*
forvalues year = 2006(1)2011 {
	clear
	forvalues mo = 1/12 {
		forvalues day = 1/31 {
			capture append using "$inter\DA_LMP_`year'_`mo'_`day'.dta"
		}
	* Remove observations for duplicate dates (e.g. Feb. 30th or June 31st) *
	drop if Node == ""
	capture drop AEBN* Interface*
	compress
	save "$inter\MISO_DA_LMP_`year'_`mo'.dta", replace
	clear
	}
}
*
forvalues year = 2012(1)2012 {
	clear
	forvalues mo = 1/9 {
		forvalues day = 1/31 {
			capture append using "$inter\DA_LMP_`year'_`mo'_`day'.dta"
		}
	* Remove observations for duplicate dates (e.g. Feb. 30th or June 31st) *
	drop if Node == ""
	capture drop AEBN* Interface*
	compress
	save "$inter\MISO_DA_LMP_`year'_`mo'.dta", replace
	clear
	}
}
*

/*
* Erase daily files now that they are duplicative *
*/
clear all
forvalues year = 2005(1)2005 {
	forvalues mo = 4/12 {
		forvalues day = 1/31 {
			capture erase "$inter\DA_LMP_`year'_`mo'_`day'.dta"
		}
	}
}
*
forvalues year = 2006(1)2012 {
	forvalues mo = 1/12 {
		forvalues day = 1/31 {
			capture erase "$inter\DA_LMP_`year'_`mo'_`day'.dta"
		}
	}
}
*

**********

/*
Append monthly files into annual and overall datasets
*/
clear all
forvalues year = 2005(1)2005 {
	forvalues mo = 4/12 {
		append using "$inter\MISO_DA_LMP_`year'_`mo'"
	}
	compress
	save "$inter\MISO_DA_LMP_`year'", replace
}
*

clear all
forvalues year = 2006(1)2011 {
	forvalues mo = 1/12 {
		append using "$inter\MISO_DA_LMP_`year'_`mo'"
	}
	compress
	save "$inter\MISO_DA_LMP_`year'", replace
	clear
}
*

clear all
forvalues year = 2012(1)2012 {
	forvalues mo = 1/9 {
		append using "$inter\MISO_DA_LMP_`year'_`mo'"
	}
	compress
	save "$inter\MISO_DA_LMP_`year'", replace
	clear
}
*
* Append into a single dataset *
clear
forvalues year = 2005(1)2012 {
	append using "$inter\MISO_DA_LMP_`year'"
}
replace Node = strtrim(Node)
replace Type = strtrim(Type)
capture drop LMP - AECI_ALTW
compress
save "$inter\MISO_DA_LMP_2005_2012", replace

* Limit to Hubs *
keep if Type == "Hub"
keep if regexm(Node, "HUB") == 1
save "$inter\MISO_DA_LMP_Hubs_2005_2012", replace



**************************************************************************

/*

Fall 2012 and 2013 Processing

*/

* January - March *
forvalues year = 2013(1)2013 {
	import delimited using "$input\\`year'_JAN_MAR_DA_LMPs.csv", varn(1) clear
	* Keep only major state-level hubs *
	keep if regexm(node, ".HUB") == 1

	capture ren he0* he*

	reshape long he, i(market_day node type value) j(hour)
	compress
	save "$inter\Jan_Mar_`year'_hubs", replace
}
*
* April - June *
forvalues year = 2013(1)2013 {
	import delimited using "$input\\`year'_APR_JUN_DA_LMPs.csv", varn(1) clear
	* Keep only major state-level hubs *
	keep if regexm(node, ".HUB") == 1

	capture ren he0* he*

	reshape long he, i(market_day node type value) j(hour)
	compress
	save "$inter\Apr_Jun_`year'_hubs", replace
}
*
* July - Sept. *
forvalues year = 2013(1)2013 {
	import delimited using "$input\\`year'_JUL_SEP_DA_LMPs.csv", varn(1) clear
	* Keep only major state-level hubs *
	keep if regexm(node, ".HUB") == 1

	capture ren he0* he*

	reshape long he, i(market_day node type value) j(hour)
	compress
	save "$inter\Jul_Sep_`year'_hubs", replace
}
*

* Oct. - Dec. *
forvalues year = 2012(1)2013 {
	import delimited using "$input\\`year'_OCT_DEC_DA_LMPs.csv", varn(1) clear
	* Keep only major state-level hubs *
	keep if regexm(node, ".HUB") == 1

	capture ren he0* he*

	reshape long he, i(market_day node type value) j(hour)
	compress
	save "$inter\Oct_Dec_`year'_hubs", replace
}
*

**************************************************************************

/*
Prepare 2005-2012 Hub data for append
*/
use "$inter\MISO_DA_LMP_Hubs_2005_2012", clear
ren Node node
ren Type type
ren Value value
forvalues i = 1/24 {
	ren HE_`i' he`i'
}
*
reshape long he, i(date node type value) j(hour)

/* 
Check only one row for observations prior to labeling values as 
LMP/MCC/Congestion
*/
preserve
keep if value == ""
duplicates tag date node hour, gen(dup)
assert dup == 0
restore

replace value = "LMP" if value == ""
gen month = month(date)
gen year = year(date)
gen day = day(date)
save "$inter\MISO_DA_LMP_Hubs_2005_2012", replace

/*
Append Fall 2012 through 2013 data
*/
use "$inter\Oct_Dec_2012_hubs", clear
forvalues year = 2013(1)2013 {
	append using "$inter\Jan_Mar_`year'_hubs"
	append using "$inter\Apr_Jun_`year'_hubs"
	append using "$inter\Jul_Sep_`year'_hubs"
	append using "$inter\Oct_Dec_`year'_hubs"
}
gen date = date(market_day, "MDY")
gen month = month(date)
gen year = year(date)
gen day = day(date)
compress
format date %td
save "$inter\MISO_DA_hubs_Oct12_13", replace



********************************************************************************
/*
Process data for 2014 - 2019
*/
********************************************************************************


* January - March *
forvalues year = 2014(1)2019 {
	import delimited using "$input\\`year'_Jan-Mar_DA_LMPs\\`year'_JAN-MAR_DA_LMPs.csv", varn(1) clear
	* Keep only major state-level hubs *
	keep if regexm(node, ".HUB") == 1

	capture ren he0* he*

	reshape long he, i(market_day node type value) j(hour)
	compress
	save "$inter\Jan_Mar_`year'_hubs", replace
}
*
* April - June *
forvalues year = 2014(1)2019 {
	import delimited using "$input\\`year'_Apr-Jun_DA_LMPs\\`year'_APR-JUN_DA_LMPs.csv", varn(1) clear
	* Keep only major state-level hubs *
	keep if regexm(node, ".HUB") == 1

	capture ren he0* he*

	reshape long he, i(market_day node type value) j(hour)
	compress
	save "$inter\Apr_Jun_`year'_hubs", replace
}
*
* July - Sept. *
forvalues year = 2014(1)2017 {
	import delimited using "$input\\`year'_Jul-Sep_DA_LMPs\\`year'_JUL-SEP_DA_LMPs.csv", varn(1) clear
	* Keep only major state-level hubs *
	keep if regexm(node, ".HUB") == 1

	capture ren he0* he*

	reshape long he, i(market_day node type value) j(hour)
	compress
	save "$inter\Jul_Sep_`year'_hubs", replace
}
*2018 (xlsx -> csv)*
forvalues year = 2018(1)2018 {
	import delimited using "$input\\`year'_Jul-Sep_DA_LMPs\\`year'_Jul-Sep_DA_LMPs.csv", varn(1) clear
	* Keep only major state-level hubs *
	keep if regexm(node, ".HUB") == 1

	capture ren he0* he*

	reshape long he, i(market_day node type value) j(hour)
	compress
	save "$inter\Jul_Sep_`year'_hubs", replace
}
*
forvalues year = 2019(1)2019 {
	import delimited using "$input\\`year'_Jul-Sep_DA_LMPs\\`year'_Jul-Sep_DA_LMPs.csv", varn(1) clear
	* Keep only major state-level hubs *
	keep if regexm(node, ".HUB") == 1

	capture ren he0* he*

	reshape long he, i(market_day node type value) j(hour)
	compress
	save "$inter\Jul_Sep_`year'_hubs", replace
}
*

* Oct. - Dec. *
forvalues year = 2014(1)2017 {
	import delimited using "$input\\`year'_Oct-Dec_DA_LMPs\\`year'_OCT-DEC_DA_LMPs.csv", varn(1) clear
	* Keep only major state-level hubs *
	keep if regexm(node, ".HUB") == 1

	capture ren he0* he*

	reshape long he, i(market_day node type value) j(hour)
	compress
	save "$inter\Oct_Dec_`year'_hubs", replace
}
*
forvalues year = 2018(1)2019 {
	import delimited using "$input\\`year'_Oct-Dec_DA_LMPs\\`year'_Oct-Dec_DA_LMPs.csv", varn(1) clear
	* Keep only major state-level hubs *
	keep if regexm(node, ".HUB") == 1

	capture ren he0* he*

	reshape long he, i(market_day node type value) j(hour)
	compress
	save "$inter\Oct_Dec_`year'_hubs", replace
}
*

** Append all into a single dataset **
clear all
forvalues year = 2014(1)2019 {
	append using "$inter\Jan_Mar_`year'_hubs"
	append using "$inter\Apr_Jun_`year'_hubs"
	append using "$inter\Jul_Sep_`year'_hubs"
	append using "$inter\Oct_Dec_`year'_hubs"
}
gen date = date(market_day, "MDY")
format date %td
gen month = month(date)
gen year = year(date)
gen day = day(date)
compress
drop if node == "NSP.CHUBLK.MVP"
save "$inter\MISO_DA_hubs_2014_2019", replace
*


*********************************************************
/*

Collapse to Avg. LMPs by Year-Month for Major State Hubs

*/
*********************************************************

use "$inter\MISO_DA_hubs_2014_2019", clear
keep if value == "LMP"
drop value type market_day
ren he LMP
label var hour "Hour Ending (1-24)"

** Collapse to monthly avg. hourly LMP by Node **
collapse (mean) LMP, by(hour node year month)

gen my = ym(year, month)
format my %tm

sort node my hour
drop if node == "MS.HUB"

export excel using "$output\MISO_Avg_DA_LMP.xlsx", sheet("AvgHrlybyMonth") firstrow(var) sheetreplace

use "$inter\MISO_DA_hubs_2014_2019", clear
keep if value == "LMP"
drop value type market_day
ren he LMP
label var hour "Hour Ending (1-24)"

** Collapse to monthly avg. LMP by Node **
collapse (mean) LMP, by(node year month)

gen my = ym(year, month)
format my %tm

sort node my 
drop if node == "MS.HUB"

export excel using "$output\MISO_Avg_DA_LMP.xlsx", sheet("AvgMonthly") firstrow(var) sheetreplace


********************************************************************************


/*
Append 2005-2012 Hub data to Fall '12 - 2013
*/
use "$inter\MISO_DA_LMP_Hubs_2005_2012", clear
append using "$inter\MISO_DA_hubs_Oct12_13"
compress
save "$inter\MISO_DA_hubs_2005_2013", replace

* Then, append 2014 - 2019 data *
append using "$inter\MISO_DA_hubs_2014_2019"
compress
save "$inter\MISO_DA_hubs_2005_2019", replace



*********************************************************
/*

Collapse to Avg. LMPs by Year-Month for Major State Hubs

*/
*********************************************************

use "$inter\MISO_DA_hubs_2005_2019", clear
keep if value == "LMP"
drop value type market_day
ren he LMP
label var hour "Hour Ending (1-24)"

** Collapse to monthly avg. hourly LMP by Node **
collapse (mean) LMP, by(hour node year month)

gen my = ym(year, month)
format my %tm

sort node my hour
drop if node == "MS.HUB"

export excel using "$output\MISO_Avg_DA_LMP.xlsx", sheet("AvgHrlybyMonth_0519") firstrow(var) sheetreplace

use "$inter\MISO_DA_hubs_2005_2019", clear
keep if value == "LMP"
drop value type market_day
ren he LMP
label var hour "Hour Ending (1-24)"

** Collapse to monthly avg. LMP by Node **
collapse (mean) LMP, by(node year month)

gen my = ym(year, month)
format my %tm

sort node my 
drop if node == "MS.HUB"

export excel using "$output\MISO_Avg_DA_LMP.xlsx", sheet("AvgMonthly_0519") firstrow(var) sheetreplace
