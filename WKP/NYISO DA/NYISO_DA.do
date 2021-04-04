/*
This .do file imports .csv files for daily DA LMPs for the NYISO Reference Bus
from 2000-2019, and combines them into a single .dta file. It also exports monthly
avg. LMPs to be used in creating the Figures of generation and LMP in the main 
paper and appendix.
*/
clear all
set type double
set more off

cd .

global input "inputs"
global inter "intermediate_refbus"
global output "output"

capture mkdir "$input"
capture mkdir "$inter"
capture mkdir "$output"

/*
Import .csv files for NYISO Day-Ahead Reference Bus LMP
*/
forvalues year = 2000/2019 {

		forvalues mo = 1/12 {
			forvalues day = 1/31 {
				*
				if `mo' < 10 {
					if `day' < 10 {
						capture import delimited using "$input\\`year'0`mo'0`day'damlbmp_gen_refbus.csv", clear
					}
					else {
						capture import delimited using "$input\\`year'0`mo'`day'damlbmp_gen_refbus.csv", clear
					}
				}
				else {
				
					if `day' < 10 {
						capture import delimited using "$input\\`year'`mo'0`day'damlbmp_gen_refbus.csv", clear
					}
					else {
						capture import delimited using "$input\\`year'`mo'`day'damlbmp_gen_refbus.csv", clear
					}
				}	

				*
				capture gen date = mdy(`mo', `day', `year')
				format date %td
				compress
				capture save "$inter\DA_LMP_`year'_`mo'_`day'", replace
				
			}
			di "`mo'"
		}
}
*

forvalues year = 2000(1)2019 {
	clear
	forvalues mo = 1/12 {
		forvalues day = 1/31 {
			capture append using "$inter\DA_LMP_`year'_`mo'_`day'.dta"
		}
	* Remove observations for duplicate dates (e.g. Feb. 30th or June 31st) *
	duplicates drop
	
	label var v4 "LBMP ($/MWH)"
	label var v5 "Marginal Cost Losses ($/MWH)"
	label var v6 "Marginal Cost Congestion ($/MWH)"


	ren v1 timestamp
	ren v2 name
	ren v3 ptid
	ren v4 LMP
	ren v5 MCL
	ren v6 MCC
	
	compress
	save "$inter\NYISO_DA_LMP_`year'_`mo'.dta", replace
	clear
	}
}
*


/*
* Erase daily files now that they are duplicative *
*/
clear all
*
forvalues year = 2011(1)2019 {
	forvalues mo = 1/12 {
		forvalues day = 1/31 {
			capture erase "$inter\DA_LMP_`year'_`mo'_`day'.dta"
		}
	}
}
*


/*
Append monthly files into annual and overall datasets
*/
clear all
forvalues year = 2000(1)2000 {
	forvalues mo = 5/12 {
		append using "$inter\NYISO_DA_LMP_`year'_`mo'"
	}
	compress
	save "$inter\NYISO_DA_LMP_`year'", replace
}
*

clear all
forvalues year = 2001(1)2019 {
	forvalues mo = 1/12 {
		append using "$inter\NYISO_DA_LMP_`year'_`mo'"
	}
	compress
	save "$inter\NYISO_DA_LMP_`year'", replace
	clear
}
*

* Append into a single dataset *
clear
forvalues year = 2000(1)2019 {
	append using "$inter\NYISO_DA_LMP_`year'"
}
compress
save "$inter\NYISO_DA_LMP_2000_2019", replace


*********************************************************
/*

Collapse to Avg. LMPs by Year-Month

*/
*********************************************************

use "$inter\NYISO_DA_LMP_2000_2019", clear
* Generate hour ending variable *
gen clock = clock(timestamp, "MDYhm")
format clock %tc
gen hour = hh(clock)
replace hour = hour + 1
assert hour != 0
assert hour <= 24
label var hour "Hour Ending (1-24)"

gen year = year(date)
gen month = month(date)

** Collapse to monthly avg. hourly LMP by Node **
collapse (mean) LMP, by(hour year month)

gen my = ym(year, month)
format my %tm

sort my hour
export excel using "$output\NYISO_Avg_DA_LMP.xlsx", sheet("AvgHrlybyMonth_0019") firstrow(var) sheetreplace

use "$inter\NYISO_DA_LMP_2000_2019", clear

* Generate hour ending variable *
gen clock = clock(timestamp, "MDYhm")
format clock %tc
gen hour = hh(clock)
replace hour = hour + 1
assert hour != 0
assert hour <= 24
label var hour "Hour Ending (1-24)"

gen year = year(date)
gen month = month(date)

** Collapse to monthly avg. LMP by Node **
collapse (mean) LMP, by(year month)

gen my = ym(year, month)
format my %tm

sort my 

export excel using "$output\NYISO_Avg_DA_LMP.xlsx", sheet("AvgMonthly_0019") firstrow(var) sheetreplace
