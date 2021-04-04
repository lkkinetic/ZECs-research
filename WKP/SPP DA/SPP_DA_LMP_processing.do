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

Import .csv files for SPP Day-Ahead LMP

*/
********************************************************************************
* Daily data first **
forvalues year = 2014/2015 {

		forvalues mo = 1/12 {
			forvalues day = 1/31 {
				*
				if `mo' < 10 {
					if `day' < 10 {
						capture import delimited using "$input\\`year'\0`mo'\DA-LMP-SL-`year'0`mo'0`day'0100.csv", clear
					}
					else {
						capture import delimited using "$input\\`year'\0`mo'\DA-LMP-SL-`year'0`mo'`day'0100.csv", clear
					}
				}
				else {
				
					if `day' < 10 {
						capture import delimited using "$input\\`year'\\`mo'\DA-LMP-SL-`year'`mo'0`day'0100", clear
					}
					else {
						capture import delimited using "$input\\`year'\\`mo'\DA-LMP-SL-`year'`mo'`day'0100", clear
					}
				}	

				*
				capture gen date = mdy(`mo', `day', `year')
				format date %td
				
				* Limit to Hubs **
				capture keep if regexm(settlementlocation, "HUB") == 1
				
				compress
				capture save "$inter\SPP_DA_LMP_`year'_`mo'_`day'", replace
				
			}
			di "`mo'"
		}
}
*

clear
** Partial year for 2013 beginning on 5/29/2013 with alternate filepath **
forvalues year = 2013/2013 {

		forvalues mo = 1/12 {
			forvalues day = 1/31 {
				*
				if `mo' < 10 {
					if `day' < 10 {
						capture import delimited using "$input\\`year'\0`mo'\0`day'\DA-LMP-SL-`year'0`mo'0`day'0100.csv", clear
					}
					else {
						capture import delimited using "$input\\`year'\0`mo'\\`day'\DA-LMP-SL-`year'0`mo'`day'0100.csv", clear
					}
				}
				else {
				
					if `day' < 10 {
						capture import delimited using "$input\\`year'\\`mo'\0`day'\DA-LMP-SL-`year'`mo'0`day'0100", clear
					}
					else {
						capture import delimited using "$input\\`year'\\`mo'\\`day'\DA-LMP-SL-`year'`mo'`day'0100", clear
					}
				}	

				*
				capture gen date = mdy(`mo', `day', `year')
				format date %td
				
				* Limit to Hubs **
				capture keep if regexm(settlementlocation, "HUB") == 1
				
				compress
				capture save "$inter\SPP_DA_LMP_`year'_`mo'_`day'", replace
				
			}
			di "`mo'"
		}
}
*

clear
** 2016 through June **
forvalues year = 2016/2016 {

		forvalues mo = 1/6 {
			forvalues day = 1/31 {
				*
				if `mo' < 10 {
					if `day' < 10 {
						capture import delimited using "$input\\`year'\0`mo'\DA-LMP-SL-`year'0`mo'0`day'0100.csv", clear
					}
					else {
						capture import delimited using "$input\\`year'\0`mo'\DA-LMP-SL-`year'0`mo'`day'0100.csv", clear
					}
				}
				else {
				
					if `day' < 10 {
						capture import delimited using "$input\\`year'\\`mo'\DA-LMP-SL-`year'`mo'0`day'0100", clear
					}
					else {
						capture import delimited using "$input\\`year'\\`mo'\DA-LMP-SL-`year'`mo'`day'0100", clear
					}
				}	

				*
				capture gen date = mdy(`mo', `day', `year')
				format date %td
				
				* Limit to Hubs **
				capture keep if regexm(settlementlocation, "HUB") == 1
				
				compress
				capture save "$inter\SPP_DA_LMP_`year'_`mo'_`day'", replace
				
			}
			di "`mo'"
		}
}
*

clear
** Starting in July 2016, monthly data files available in subfolders **
forvalues year = 2016/2018 {

	forvalues mo = 1/12 {
			*
			if `mo' < 10 {
				capture import delimited using "$input\\`year'\0`mo'\DA-LMP-MONTHLY-SL-`year'0`mo'.csv", clear
			}
			else {
				capture import delimited using "$input\\`year'\\`mo'\DA-LMP-MONTHLY-SL-`year'`mo'.csv", clear			
			}
			
			capture gen date2 = ym(`year', `mo')
			format date2 %tm
			
			* Limit to Hubs **
			capture keep if regexm(settlementlocation, "HUB") == 1
			
			capture ren date date_str
			
			compress
			capture save "$inter\SPP_DA_LMP_`year'_`mo'", replace

	}
}
*
clear
** 2019 in main input folder **
forvalues year = 2019/2019 {

	forvalues mo = 1/12 {
			*
			if `mo' < 10 {
				capture import delimited using "$input\DA-LMP-MONTHLY-SL-`year'0`mo'.csv", clear
			}
			else {
				capture import delimited using "$input\DA-LMP-MONTHLY-SL-`year'`mo'.csv", clear			
			}
			
			* rename date variable
			capture ren date date_str

			capture gen date2 = ym(`year', `mo')
			format date2 %tm
			
			* Limit to Hubs **
			capture keep if regexm(settlementlocation, "HUB") == 1
			
			compress
			capture save "$inter\SPP_DA_LMP_`year'_`mo'", replace

	}
}
*



/*
Append daily datasets to monthly level 
*/

* 2014 - 2015 *
forvalues year = 2014(1)2015 {
	clear
	forvalues mo = 1/12 {
		forvalues day = 1/31 {
			capture append using "$inter\SPP_DA_LMP_`year'_`mo'_`day'.dta"
		}
	* Remove observations for duplicate dates (e.g. Feb. 30th or June 31st) *
	duplicates drop
	
	label var lmp "LMP ($/MWH)"
	label var mlc "Marginal Loss Component($/MWH)"
	label var mcc "Marginal Congestion Component ($/MWH)"
	label var mec "Marginal Energy Component ($/MWH)"


	ren interval timestamp
	ren lmp LMP
	ren mlc MCL
	ren mcc MCC
	ren mec MEC
	
	compress
	save "$inter\SPP_DA_LMP_`year'_`mo'.dta", replace
	clear
	}
}
*

* 2013 *
forvalues year = 2013(1)2013 {
	clear
	forvalues mo = 5/12 {
		forvalues day = 1/31 {
			capture append using "$inter\SPP_DA_LMP_`year'_`mo'_`day'.dta"
		}
	* Remove observations for duplicate dates (e.g. Feb. 30th or June 31st) *
	duplicates drop
	
	label var lmp "LMP ($/MWH)"
	label var mlc "Marginal Loss Component($/MWH)"
	label var mcc "Marginal Congestion Component ($/MWH)"
	label var mec "Marginal Energy Component ($/MWH)"


	ren interval timestamp
	ren lmp LMP
	ren mlc MCL
	ren mcc MCC
	ren mec MEC
	
	compress
	save "$inter\SPP_DA_LMP_`year'_`mo'.dta", replace
	clear
	}
}
*

* 2016 *
forvalues year = 2016(1)2016 {
	clear
	forvalues mo = 1/6 {
		forvalues day = 1/31 {
			capture append using "$inter\SPP_DA_LMP_`year'_`mo'_`day'.dta"
		}
	* Remove observations for duplicate dates (e.g. Feb. 30th or June 31st) *
	duplicates drop
	
	label var lmp "LMP ($/MWH)"
	label var mlc "Marginal Loss Component($/MWH)"
	label var mcc "Marginal Congestion Component ($/MWH)"
	label var mec "Marginal Energy Component ($/MWH)"


	ren interval timestamp
	ren lmp LMP
	ren mlc MCL
	ren mcc MCC
	ren mec MEC
	
	compress
	save "$inter\SPP_DA_LMP_`year'_`mo'.dta", replace
	clear
	}
}
*


/*
* Erase daily files now that they are duplicative *
*/
clear all
*
forvalues year = 2013(1)2016 {
	forvalues mo = 1/12 {
		forvalues day = 1/31 {
			capture erase "$inter\SPP_DA_LMP_`year'_`mo'_`day'.dta"
		}
	}
}
*

/*
Reshape monthly datasets (July 2016 - end) to match daily
*/
* July - Dec. 2016 *
forvalues i = 7/12 {
	use "$inter\SPP_DA_LMP_2016_`i'", clear
	forvalues j = 1/9 {
		ren he0`j' he`j'
	}
	*
	reshape long he, i(date_str-pricetype date2) j(hour)
	ren he value
	
	reshape wide value, i(date_str-pnodename hour) j(pricetype) string
	ren value* *
	
	ren *name *

	gen date = date(date_str, "MDY")
	format date %td
	drop date2
	save "$inter\SPP_DA_LMP_2016_`i'", replace
}
* 2017-2019 *
forvalues year = 2017(1)2019 {
	forvalues mo = 1/12 {
		use "$inter\SPP_DA_LMP_`year'_`mo'", clear
		forvalues i = 1/9 {
			ren he0`i' he`i'
		}
		*
		reshape long he, i(date_str-pricetype date2) j(hour)
		ren he value

		reshape wide value, i(date_str-pnodename hour) j(pricetype) string
		ren value* *

		ren *name *
		
		gen date = date(date_str, "YMD")
		format date %td
		drop date2
		save "$inter\SPP_DA_LMP_`year'_`mo'", replace
	}
}
*


/*
Append monthly files into annual and overall datasets
*/
clear all
forvalues year = 2013(1)2013 {
	forvalues mo = 5/12 {
		append using "$inter\SPP_DA_LMP_`year'_`mo'"
	}
	compress
	save "$inter\SPP_DA_LMP_`year'", replace
}
*

clear all
forvalues year = 2014(1)2019 {
	forvalues mo = 1/12 {
		append using "$inter\SPP_DA_LMP_`year'_`mo'"
	}
	compress
	save "$inter\SPP_DA_LMP_`year'", replace
	clear
}
*

* Append into a single dataset *
clear
forvalues year = 2013(1)2019 {
	append using "$inter\SPP_DA_LMP_`year'"
}
* Combine MLC and MCL *
egen MLC2 = rowmax(MCL MLC)
drop MCL MLC
ren MLC2 MLC
label var MLC "Marginal Loss Component($/MWH)"

compress
save "$inter\SPP_DA_LMP_2013_2019", replace
