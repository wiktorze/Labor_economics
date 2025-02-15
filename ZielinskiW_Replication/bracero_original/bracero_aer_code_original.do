 
* This Stata code replicates the tables and figures in: Michael A. Clemens, Ethan G. Lewis, and Hannah M. Postel, 
* "Immigration Restrictions as Active Labor Market Policy: Evidence from the Mexican Bracero Exclusion"
* in the American Economic Review -- both in main text and in Online Appendix
 
version 15.1
clear all
set more off
capture log close
 
 
***** USER INSTRUCTIONS 
 
* Running this code requires 
* 1) installing the required .ado files: -grc1leg- by Vince Wiggins, -bspline- by Roger Newson, -sutex- by Antoine Terracol, -xtsemipar- by François Libois and Vincenzo Verardi, and -outtable- by Christopher Baum and Joao Pedro Azevedo
*    This can be done by entering each of the following at the Stata command prompt:
*         ssc install bspline
*         net install grc1leg, from(http://www.stata.com/users/vwiggins)
*         net install xtsemipar, from(http://fmwww.bc.edu/RePEc/bocode/x)
*         net install sutex, from(http://fmwww.bc.edu/RePEc/bocode/s)
*         net install outtable, from(http://fmwww.bc.edu/RePEc/bocode/o)
* 2) setting the filepath (below) to your working directory
* 3) creating a folder called "output" in the working directory
* 4) placing all six of the required, accompanying data files in the working directory. 
* The required data files are: bracero_aer_dataset.dta, bracero_outflows_from_mex_gonzalez.dta, cpi_data.dta, tomatoes_vandermeer_final.dta, total_braceros_by_year.dta, alston_ferrie_votes.dta 
 

***** READ DATA AND SET PATHS

global data_folder "/Users/mac/Documents/Labor/bracero/bracero_original" //INSERT PATH

global output_folder "$data_folder/output"

cd "$data_folder"
use "bracero_aer_dataset.dta", clear


* For graphs

global scheme_set "s1color"
global color_set "black"
global color_high "black"
global color_low "gs11"
global color_control "black"

sort State Year
* merge m:1 State Year using insured_unemployment.dta
* drop _merge

* Switch default directory to output folder, to store tables and figures
cd "$output_folder"


***** CLEAN AND PREPARE DATASET

* Clean miscoded cotton mechanization values
replace Cotton_machine = . if State=="FL" & Year>1969 & Cotton_machine == 0
replace Cotton_machine = . if State=="VA" & Year>1965 & Cotton_machine == 0

* Generate flags
gen january = Month == 1
gen april = Month == 4
gen july = Month == 7
gen october = Month == 10
gen quarterly_flag = inlist(Month,1,4,7,10)
gen quarter = 1 if inlist(Month,1,2,3)
replace quarter = 2 if inlist(Month,4,5,6)
replace quarter = 3 if inlist(Month,7,8,9)
replace quarter = 4 if inlist(Month,10,11,12)

* Generate time variables
gen time_m = ym(Year,Month)
format time_m %tm

gen time_q = yq(Year,quarter)
format time_q %tq

* Merge different Mexican series
gen Mexican = Mexican_final
gen ln_Mexican = ln(Mexican)

* Set panel
drop if time_m == .
drop if State_FIPS == .
xtset State_FIPS time_m
* xtline DailywoBoard_final, overlay

gen fulldata = ((Year>=1954 & Month>=7)|(Year>=1955))&(Year<=1972)     // Few states are covered in the employment data outside of this window
replace Mexican = 0 if Mexican==. & fulldata

* Non-Mexican workers
gen TotalHiredSeasonal = TotalHiredSeasonal_final
gen NonMexican = TotalHiredSeasonal - Mexican
gen ln_NonMexican = ln(NonMexican)
gen ln_HiredWorkersonFarms = ln( HiredWorkersonFarms_final )
gen mex_frac = Mexican/TotalHiredSeasonal				// Denominator is hired seasonal farmworkers

gen mex_frac_tot = Mexican/(Farmworkers_Hired*1000)		// Denominator is all hired farmworkers, seasonal and nonseasonal

sort State_FIPS time_m
cd "$data_folder"
merge m:1 State_FIPS time_m using cpi_data.dta
cd "$output_folder"
gen priceadjust = cpi/.1966401  // Divide by value of index in January 1965
gen realwage_daily = DailywoBoard_final/priceadjust
gen realwage_hourly = HourlyComposite_final/priceadjust
* drop year month 
drop cpi priceadjust _merge

* Generate employment data
sort State time_m
egen domestic_seasonal = rowtotal(Local_final Intrastate_final Interstate_final)   
gen ln_domestic_seasonal = ln(domestic_seasonal)
gen ln_foreign = ln(TotalForeign_final)
gen dom_frac = domestic_seasonal/TotalHiredSeasonal_final
gen for_frac = TotalForeign_final/TotalHiredSeasonal_final
gen ln_local = ln(Local_final)
gen ln_intrastate = ln(Intrastate_final)
gen ln_interstate = ln(Interstate_final)

replace domestic_seasonal=. if Year<1954 | Year>1973 | (Year==1973 & Month>7)    // No coverage in original sources outside Jan 1954 to Jul 1973
replace ln_domestic_seasonal=. if Year<1954 | Year>1973 | (Year==1973 & Month>7)    // No coverage in original sources outside Jan 1954 to Jul 1973

* Normalize by, respectively, data from the latest Census of Agriculture before 1955 and latest Census of Population before 1955:
gen mex_area = Mexican/(cropland_1954/1000)  			// Mexican seasonal workers per 1000 acres of (predetermined 1954) harvested cropland
gen dom_area = domestic_seasonal/(cropland_1954/1000)	// Domestic hired seasonal workers per 1000 acres of (predetermined 1954) harvested cropland
gen mex_pop = Mexican/(pop1950/1000)  			// Mexican seasonal workers per 1000 population
gen dom_pop = domestic_seasonal/(pop1950/1000)	// Domestic hired seasonal workers per 1000 population

gen Farmworkers_Hired_pop = (Farmworkers_Hired*1000)/(pop1950/1000)
gen Farmworkers_Hired_area = (Farmworkers_Hired*1000)/(cropland_1954/1000)

* For Appendix graph comparing Mexican to non-Mexican foreign
gen Mexican_zeros = Mexican
replace Mexican_zeros = 0 if Year>=1967 & Mexican_zeros == .
egen ForNonMexican = rowtotal(Jamaican_final Bahamian_final BWIOthers_final Canadian_final PuertoRican_final OtherForeign_final)
egen mextot = total(Mexican_zeros), by(time_m)
egen fornonmextot = total(ForNonMexican), by(time_m)

	
***** RESULTS

* Diffs in Diffs regressions

preserve

* First generate treatment intensity variable, denominator is hired seasonal workers
keep if Year==1955 
gen mex_frac_55 = Mexican/(Mexican+NonMexican)   // Fraction of hired seasonal workers who were Mexican for each month of 1955
gen mex_num_55 = Mexican
collapse (mean) mex_frac_55, by(State)

** APPENDIX TABLE A2

	************** export table of mex_frac_55 values
	gsort -mex_frac_55
	mkmat mex_frac_55, matrix(A) rownames(State)
	mat list A
	outtable using tables_bracero, mat(A) replace caption("APPENDIX TABLE A2: Mex fraction mid-1955") format(%04.3f )
	**************

sort State
save merge_util.dta, replace

restore

* Calculate nationwide totals of braceros vs. domestic
preserve
keep if Year==1955
collapse (sum) Mexican NonMexican, by(Month)	// For measuring the scale of the bracero program relative to the nationwide stock of hired seasonal agricultural labor
restore

sort State
merge m:1 State using merge_util.dta
erase merge_util.dta

gen post = Year>=1965
gen treatment_frac = post * mex_frac_55

gen post_2 = Year>=1962
gen treatment_frac_2 = post_2 * mex_frac_55


preserve
* Now generate denominator for scaling: total hired farm workers in average month of 1957
* Note that total farmworkers series only begins in 1957
keep if Year==1957 
gen farm_tot_57 = Farmworkers_Hired*1000
collapse (mean) farm_tot_57, by(State)

sort State
save merge_util.dta, replace
restore

sort State
capture drop _merge
merge m:1 State using merge_util.dta
erase merge_util.dta


* Groups by intensity of exposure to exclusion
gen none = mex_frac_55 == 0
gen low = (mex_frac_55 >0 & mex_frac_55 <0.2)
gen high = mex_frac_55 >=0.2 & mex_frac_55 <.     // This is: AR, AZ, CA, NM, SD, TX

gen exposure = 0 if none
replace exposure = 1 if low
replace exposure = 2 if high



** Quarterly analysis

preserve  // Use quarterly data
keep if quarterly_flag
xtset State_FIPS time_q

** APPENDIX FIGURE A6c
	
* Real wages
graph twoway lpoly realwage_daily time_q if none & Year>=1945, degree(1) bwidth(2) clcolor($color_control) clwidth(thin) clpattern(vshortdash)  ///
	|| lpoly realwage_daily time_q if low & Year>=1945, degree(1) bwidth(2) clcolor($color_low *.66) clwidth(medthick) clpattern(solid)  ///
	|| lpoly realwage_daily time_q if high & Year>=1945, degree(1) bwidth(2) clcolor($color_high *.66) clwidth(medthick) clpattern(solid)  ///
	xline(19.7, lcolor(black) lpattern(dot)) xline(9, lcolor(black) lpattern(dot)) scheme($scheme_set) plotregion(lcolor(none)) ///
	ytitle("Daily wage without board (1965 US$/day)", margin(medium)) xtitle("Year", margin(medium)) ///
	xlabel(-60(20)60,format(%tqCY)) xmtick(-60(4)60) ///
	legend(colfirst order (- "{it:Bracero} fraction ({it:B}/{it:L}) in 1955:" - - 1 2 3) cols(2) region(lstyle(none) margin(none)) ///
	label(1 "No exposure ({it:B}/{it:L} = 0)") label(2 "Low exposure (0 < {it:B}/{it:L} < 0.2)") label(3 "High exposure ({it:B}/{it:L} {&ge} 0.2)") size(small)) 

graph export dd_wage_real_daily_smooth.pdf, replace
	
** APPENDIX FIGURE A6a
	
graph twoway lpoly realwage_hourly time_q if none & Year>=1945, degree(1) bwidth(2) clcolor($color_control) clwidth(thin) clpattern(vshortdash)  ///
	|| lpoly realwage_hourly time_q if low & Year>=1945, degree(1) bwidth(2) clcolor($color_low *.66) clwidth(medthick) clpattern(solid)  ///
	|| lpoly realwage_hourly time_q if high & Year>=1945, degree(1) bwidth(2) clcolor($color_high *.66) clwidth(medthick) clpattern(solid)  ///
	xline(19.7, lcolor(black) lpattern(dot)) xline(9, lcolor(black) lpattern(dot)) scheme($scheme_set) plotregion(lcolor(none)) ///
	ytitle("Hourly wage, composite (1965 US$/hour)", margin(medium)) xtitle("Year", margin(medium)) ///
	xlabel(-60(20)60,format(%tqCY)) xmtick(-60(4)60) ylabel(,format(%03.1f)) ///
	legend(colfirst order (- "{it:Bracero} fraction ({it:B}/{it:L}) in 1955:" - - 1 2 3) cols(2) region(lstyle(none) margin(none)) ///
	label(1 "No exposure ({it:B}/{it:L} = 0)") label(2 "Low exposure (0 < {it:B}/{it:L} < 0.2)") label(3 "High exposure ({it:B}/{it:L} {&ge} 0.2)") size(small)) 

graph export dd_wage_real_hourly_smooth.pdf, replace
	
** APPENDIX FIGURE A6d

bysort time_q: egen realwage_daily_none = mean(realwage_daily) if none
bysort time_q: egen realwage_daily_low = mean(realwage_daily) if low
bysort time_q: egen realwage_daily_high = mean(realwage_daily) if high

graph twoway line realwage_daily_none time_q if Year>=1945, c(stairstep) clcolor($color_control) clwidth(thin) clpattern(vshortdash) ///
	|| line realwage_daily_low time_q if Year>=1945, c(stairstep) clcolor($color_low *.66) clwidth(medium) clpattern(solid)  ///
	|| line realwage_daily_high time_q if Year>=1945, c(stairstep) clcolor($color_high *.66) clwidth(medium) clpattern(solid) ///
	xline(19.7, lcolor(black) lpattern(dot)) xline(9, lcolor(black) lpattern(dot)) scheme($scheme_set) plotregion(lcolor(none)) ///
	ytitle("Daily wage without board (1965 US$/day)", margin(medium)) xtitle("Year", margin(medium)) ///
	xlabel(-60(20)60,format(%tqCY)) xmtick(-60(4)60) ///
	legend(colfirst order (- "{it:Bracero} fraction ({it:B}/{it:L}) in 1955:" - - 1 2 3) cols(2) region(lstyle(none) margin(none)) ///
	label(1 "No exposure ({it:B}/{it:L} = 0)") label(2 "Low exposure (0 < {it:B}/{it:L} < 0.2)") label(3 "High exposure ({it:B}/{it:L} {&ge} 0.2)") size(small)) 

graph export dd_wage_real_daily_step.pdf, replace

** APPENDIX FIGURE A6b

bysort time_q: egen realwage_hourly_none = mean(realwage_hourly) if none
bysort time_q: egen realwage_hourly_low = mean(realwage_hourly) if low
bysort time_q: egen realwage_hourly_high = mean(realwage_hourly) if high

graph twoway line realwage_hourly_none time_q if Year>=1945, c(stairstep) clcolor($color_control) clwidth(thin) clpattern(vshortdash) ///
	|| line realwage_hourly_low time_q if Year>=1945, c(stairstep) clcolor($color_low *.66) clwidth(medium) clpattern(solid)  ///
	|| line realwage_hourly_high time_q if Year>=1945, c(stairstep) clcolor($color_high *.66) clwidth(medium) clpattern(solid) ///
	xline(19.7, lcolor(black) lpattern(dot)) xline(9, lcolor(black) lpattern(dot)) scheme($scheme_set) plotregion(lcolor(none)) ///
	ytitle("Hourly wage, composite (1965 US$/hour)", margin(medium)) xtitle("Year", margin(medium)) ///
	xlabel(-60(20)60,format(%tqCY)) xmtick(-60(4)60) ///
	legend(colfirst order (- "{it:Bracero} fraction ({it:B}/{it:L}) in 1955:" - - 1 2 3) cols(2) region(lstyle(none) margin(none)) ///
	label(1 "No exposure ({it:B}/{it:L} = 0)") label(2 "Low exposure (0 < {it:B}/{it:L} < 0.2)") label(3 "High exposure ({it:B}/{it:L} {&ge} 0.2)") size(small)) 

graph export dd_wage_real_hourly_step.pdf, replace



** DD wages, quarterly

** TABLE 1

gen ln_realwage_hourly = ln(realwage_hourly)
gen ln_realwage_daily = ln(realwage_daily)
gen time_q_plus = time_q + 100   // Necessary because Stata factor variables cannot take negative values
fvset base 0 time_q_plus

eststo clear
eststo: qui xtreg realwage_hourly treatment_frac i.time_q_plus, fe vce(cluster State_FIPS)
eststo: qui xtreg realwage_daily treatment_frac i.time_q_plus, fe vce(cluster State_FIPS)
eststo: qui xtreg realwage_hourly treatment_frac i.time_q_plus if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
eststo: qui xtreg realwage_daily treatment_frac i.time_q_plus if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)

esttab using tables_bracero.tex, se ar2 nostar compress append keep(treatment_frac) ///
	booktabs alignment(D{.}{.}{-1}) title(TABLE 1: Differences-in-differences with continuous treatment, quarterly)  ///
	scalars(N_clust) 
	
esttab using "../../Replication_figures/tables_bracero.tex", se ar2 nostar compress append keep(treatment_frac) ///
	booktabs alignment(D{.}{.}{-1}) title(TABLE 1: Differences-in-differences with continuous treatment, quarterly)  ///
	scalars(N_clust) 

* Semielasticity
mat pvals = (.)
eststo clear
eststo: qui xtreg ln_realwage_hourly treatment_frac i.time_q_plus, fe vce(cluster State_FIPS)
test _b[treatment_frac]=.1
mat new_p = (r(p))
mat pvals = pvals\new_p
eststo: qui xtreg ln_realwage_daily treatment_frac i.time_q_plus, fe vce(cluster State_FIPS)
test _b[treatment_frac]=.1
mat new_p = (r(p))
mat pvals = pvals\new_p
eststo: qui xtreg ln_realwage_hourly treatment_frac i.time_q_plus if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
test _b[treatment_frac]=.1
mat new_p = (r(p))
mat pvals = pvals\new_p
eststo: qui xtreg ln_realwage_daily treatment_frac i.time_q_plus if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
test _b[treatment_frac]=.1
mat new_p = (r(p))
mat pvals = pvals\new_p

esttab using tables_bracero.tex, se ar2 nostar compress append keep(treatment_frac) ///
	booktabs alignment(D{.}{.}{-1}) title(TABLE 1: Semielasticities, DD with continuous treatment, quarterly)  ///
	scalars(N_clust) 

mat pvals = pvals[2...,1...]	// Drop leading blank
mat pvals = pvals'			// transpose for LaTeX conversion
outtable using "tables_bracero", mat(pvals) append norowlab nobox caption("TABLE 1: p vals of semielasticities") format(%5.4f %5.4f %5.4f %5.4f)



** APPENDIX TABLE A5

* Repeat with state-specific time-trends

eststo clear
eststo: qui xtreg realwage_hourly treatment_frac i.time_q_plus i.State_FIPS#c.time_q_plus, fe vce(cluster State_FIPS)
eststo: qui xtreg realwage_daily treatment_frac i.time_q_plus i.State_FIPS#c.time_q_plus, fe vce(cluster State_FIPS)
eststo: qui xtreg realwage_hourly treatment_frac i.time_q_plus i.State_FIPS#c.time_q_plus if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
eststo: qui xtreg realwage_daily treatment_frac i.time_q_plus i.State_FIPS#c.time_q_plus if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)

esttab using tables_bracero.tex, se ar2 nostar compress append keep(treatment_frac) ///
	booktabs alignment(D{.}{.}{-1}) title(APPENDIX TABLE A5: State-specific time trends: DD with continuous treatment, quarterly)  ///
	scalars(N_clust) 

* Semielasticity
mat pvals = (.)
eststo clear
eststo: qui xtreg ln_realwage_hourly treatment_frac i.time_q_plus i.State_FIPS#c.time_q_plus, fe vce(cluster State_FIPS)
test _b[treatment_frac]=.1
mat new_p = (r(p))
mat pvals = pvals\new_p
eststo: qui xtreg ln_realwage_daily treatment_frac i.time_q_plus i.State_FIPS#c.time_q_plus, fe vce(cluster State_FIPS)
test _b[treatment_frac]=.1
mat new_p = (r(p))
mat pvals = pvals\new_p
eststo: qui xtreg ln_realwage_hourly treatment_frac i.time_q_plus i.State_FIPS#c.time_q_plus if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
test _b[treatment_frac]=.1
mat new_p = (r(p))
mat pvals = pvals\new_p
eststo: qui xtreg ln_realwage_daily treatment_frac i.time_q_plus i.State_FIPS#c.time_q_plus if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
test _b[treatment_frac]=.1
mat new_p = (r(p))
mat pvals = pvals\new_p

esttab using tables_bracero.tex, se ar2 nostar compress append keep(treatment_frac) ///
	booktabs alignment(D{.}{.}{-1}) title(APPENDIX TABLE A5: State-specific time trends: Semielasticities, DD with continuous treatment, quarterly)  ///
	scalars(N_clust) 

mat pvals = pvals[2...,1...]	// Drop leading blank
mat pvals = pvals'			// transpose for LaTeX conversion
outtable using "tables_bracero", mat(pvals) append norowlab nobox caption("APPENDIX TABLE A5: State-specific time trends: p vals of semielasticities") format(%5.4f %5.4f %5.4f %5.4f)


** APPENDIX TABLE A7
	
* Robustness check, for Appendix: DD Wages with treatment in 1962

eststo clear
eststo: qui xtreg realwage_hourly treatment_frac_2 i.time_q_plus, fe vce(cluster State_FIPS)
margins, eydx(treatment_frac) post
test treatment_frac == .1
eststo: qui xtreg realwage_daily treatment_frac_2 i.time_q_plus, fe vce(cluster State_FIPS)
margins, eydx(treatment_frac) post
test treatment_frac == .1
eststo: qui xtreg realwage_hourly treatment_frac_2 i.time_q_plus if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
margins, eydx(treatment_frac) post
test treatment_frac == .1
eststo: qui xtreg realwage_daily treatment_frac_2 i.time_q_plus if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
margins, eydx(treatment_frac) post
test treatment_frac == .1

esttab using tables_bracero.tex, se ar2 nostar compress append  keep(treatment_frac_2) ///
	booktabs alignment(D{.}{.}{-1}) title(APPENDIX TABLE A7: 1962 treatment: DD wages, quarterly)  ///
	scalars(N_clust ) 
	
	
	

* FIXED-EFFECTS SPECIFICATION




** APPENDIX TABLE A3

eststo clear

eststo: xtreg realwage_hourly ln_Mexican i.time_q_plus, fe vce(cluster State_FIPS)
eststo: xtreg realwage_hourly ln_Mexican ln_NonMexican i.time_q_plus, fe vce(cluster State_FIPS)

eststo: xtreg realwage_daily ln_Mexican i.time_q_plus, fe vce(cluster State_FIPS)
eststo: xtreg realwage_daily ln_Mexican ln_NonMexican i.time_q_plus, fe vce(cluster State_FIPS)

eststo: xtregar realwage_hourly ln_Mexican ln_NonMexican i.time_q_plus, fe
eststo: xtregar realwage_daily ln_Mexican ln_NonMexican i.time_q_plus, fe

esttab using tables_bracero.tex, se ar2 nostar compress append     ///
	keep(ln_Mexican ln_NonMexican  ) ///
	booktabs alignment(D{.}{.}{-1}) title(APPENDIX TABLE A3: FE regressions, quarterly)  ///
	scalars(N_clust ) // order(net_inflow_rate) )


** FIGURE 4a
	
xi: xtsemipar realwage_hourly i.time_q_plus, nonpar(ln_Mexican) cluster(State_FIPS) degree(1) nograph generate(fitted resids)

graph twoway lpolyci resids ln_Mexican if ln_Mexican<. & resids<., degree(1) bwidth(2) ///
	lcolor($color_low *.2) ciplot(rline) alpattern(shortdash) || ///
	scatter resids ln_Mexican if ln_Mexican<. & resids<., ///
	msymbol(smcircle) msize(*0.5) mcolor($color_set) legend(off) ///
	scheme($scheme_set) plotregion(lcolor(none)) xlabel(0(2)12) xtick(0(1)12) ylabel(,format(%03.1f)) ///
	xtitle("{it: ln} Mexican workers {stSymbol:|} state, quarter-by-year FE", margin(medium)) ///
	ytitle("Wage {stSymbol:|} state, quarter-by-year FE", margin(medium))

graph export semipar_wage.pdf, replace
	
drop fitted resids



** APPENDIX TABLE A1, first part

* Summary statistics table, quarterly

log using summ_stats.txt, replace
dis "Quarterly"
sutex Year quarter realwage_hourly realwage_daily ln_Mexican ln_NonMexican treatment_frac, minmax
log close



restore   // Back to monthly data
		
* DD domestic employment, monthly

* Because Stata factor variables cannot use negative values, generate a positive integer sequence corresponding to year-month
sort State_FIPS time_m
by State_FIPS: egen time_num = seq()	// required to prevent -esttab- error of 'too many base levels'

fvset base 0 Year
fvset base 0 Month
fvset base 0 time_num 					// required to prevent -esttab- error of 'too many base levels'


** TABLE 2

eststo clear
eststo: xtreg domestic_seasonal treatment_frac i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg ln_domestic_seasonal treatment_frac i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg domestic_seasonal treatment_frac i.time_num if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
eststo: xtreg ln_domestic_seasonal treatment_frac i.time_num if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
eststo: xtreg domestic_seasonal treatment_frac i.time_num if !none, fe vce(cluster State_FIPS)
eststo: xtreg ln_domestic_seasonal treatment_frac i.time_num if !none, fe vce(cluster State_FIPS)

esttab using tables_bracero.tex, se ar2 nostar compress append keep(treatment_frac) ///
	booktabs alignment(D{.}{.}{-1}) title(TABLE 2: Differences-in-differences with continuous treatment, monthly, Jan 1954--Jul 1973 only)  ///
	scalars(N_clust ) 

esttab using "../../Replication_figures/tables_bracero.tex", se ar2 nostar compress append keep(treatment_frac) ///
	booktabs alignment(D{.}{.}{-1}) title(TABLE 2: Differences-in-differences with continuous treatment, monthly, Jan 1954--Jul 1973 only)  ///
	scalars(N_clust ) 
	
	
** APPENDIX TABLE A10	
	
* Workers per 1000 acres of predetermined harvested cropland and workers per (predetermined) population

eststo clear
eststo: xtreg mex_area treatment_frac i.time_num if dom_area!=., fe vce(cluster State_FIPS)
eststo: xtreg dom_area treatment_frac i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg mex_pop treatment_frac i.time_num if dom_pop!=., fe vce(cluster State_FIPS)
eststo: xtreg dom_pop treatment_frac i.time_num, fe vce(cluster State_FIPS)

esttab using tables_bracero.tex, se ar2 nostar compress append keep(treatment_frac) ///
	booktabs alignment(D{.}{.}{-1}) title(APPENDIX TABLE A10: DD with continuous treatment, monthly, Jan 1954--Jul 1973 only, per 1000 acres cropland 1954 or per predetermined population)  ///
	scalars(N_clust ) 

	
	
******** Event study formulation


** APPENDIX FIGURE A2a

* Event study: Monthly ln domestic employment

mat year = 1954								// create vector of all years
foreach num of numlist 1955/1973 {	
	mat year_add = `num'
	mat year = year\year_add
}
mat year_short = year[1..19,1]				// needed below

foreach m of numlist 6 {
	preserve
	keep if Year >=1954 & Year<=1973  			// keep only cells with non-missing wages
*	keep if mex_frac_55>0						// only exposed states
	keep if Month==`m'
	collapse (mean) ln_domestic_seasonal mex_frac_55 treatment_frac Month, by(State_FIPS Year)
	tsset State_FIPS Year
	xtreg ln_domestic_seasonal ib1964.Year##c.mex_frac_55, fe vce(cluster State_FIPS)
	matrix coeffs = r(table)
	matrix coeffs = coeffs'
	mat coeffs = coeffs[22..41,1...]		// rows with interaction terms
	mat coeffs1 = coeffs[1...,1]			// coefficient estimates
	mat coeffs2 = coeffs[1...,5..6]			// upper and lower bounds
	mat mon = J(20,1,`m')					// Create vector of containing the value of the quarter
	mat coeffs_`m' = coeffs1,coeffs2,year,mon	// create submatrix of results containing only coefficient estimates and upper and lower bounds
	restore
}

foreach m of numlist 7/10 {					// Why a separate subroutine for months August and after: because 1973 months after July are missing worker data, so matrix one row smaller
	preserve
	keep if Year >=1954 & Year<=1973  			// keep only cells with non-missing wages
*	keep if mex_frac_55>0						// only exposed states
	keep if Month==`m'
	collapse (mean) ln_domestic_seasonal mex_frac_55 treatment_frac Month, by(State_FIPS Year)
	tsset State_FIPS Year
	xtreg ln_domestic_seasonal ib1964.Year##c.mex_frac_55, fe vce(cluster State_FIPS)
	matrix coeffs = r(table)
	matrix coeffs = coeffs'
	mat coeffs = coeffs[21..39,1...]		// rows with interaction terms
	mat coeffs1 = coeffs[1...,1]			// coefficient estimates
	mat coeffs2 = coeffs[1...,5..6]			// upper and lower bounds
	mat mon = J(19,1,`m')					// Create vector of containing the value of the quarter
	mat coeffs_`m' = coeffs1,coeffs2,year_short,mon	// create submatrix of results containing only coefficient estimates and upper and lower bounds
	mat missing=(.,.,.,1973,`m')
	mat coeffs_`m' = coeffs_`m'\missing		// for conformability with matrices from 1st and 2nd quarters, which have one additional year (1971)
	restore
}

mat coeffs_full = coeffs_6\coeffs_7\coeffs_8\coeffs_9\coeffs_10

svmat coeffs_full

rename coeffs_full1 interaction
rename coeffs_full2 lower_bound
rename coeffs_full3 upper_bound
rename coeffs_full4 year_es
rename coeffs_full5 mon_es

gen time_m_es = ym(year_es,mon_es)
format time_m_es %tm

graph twoway rspike lower_bound upper_bound time_m_es if mon_es==6, lcolor(gs10) lwidth(*.5) ///
	|| scatter interaction time_m_es if mon_es==6, msymbol(O) mcolor(white) mlcolor(black) msize(*.7) mlwidth(*.4) ///
	|| rspike lower_bound upper_bound time_m_es if mon_es==9, lcolor(gs10) lwidth(*.5) ///
	|| scatter interaction time_m_es if mon_es==9, msymbol(O) mcolor(black) mlcolor(black) msize(*.7) mlwidth(*.5) ///
	scheme(s1color) xline(26, lcolor(black) lpattern(vshortdash) lwidth(thin)) ///
	xline(59, lcolor(black) lpattern(vshortdash) lwidth(thin)) plotregion(lcolor(none)) yline(0, lcolor(gs14) lwidth(vthin)) ///
	ytitle("{it:coeff} (Year `=uchar(0215)' 1955 {it:bracero} stock)", margin(medium)) xtitle("Year", margin(small))  ///
	xlabel(-60(60)150,format(%tmCY)) xmtick(-72(12)162) ylabel(,format(%03.1f)) ///
	legend( order(- "Month:" 2 4) rows(1) region(lstyle(none) margin(none)) ///
	label(2 "June") label(4 "September") size(small) span)
	
graph export event_study_lwkr_month.pdf, replace

drop interaction lower_bound upper_bound year_es mon_es time_m_es 
	

** APPENDIX FIGURE A2b	
	
* Repeat event study for exposed states


mat year = 1954								// create vector of all years
foreach num of numlist 1955/1973 {	
	mat year_add = `num'
	mat year = year\year_add
}
mat year_short = year[1..19,1]				// needed below

foreach m of numlist 6 {
	preserve
	keep if Year >=1954 & Year<=1973  			// keep only cells with non-missing wages
	keep if mex_frac_55>0						// only exposed states
	keep if Month==`m'
	collapse (mean) ln_domestic_seasonal mex_frac_55 treatment_frac Month, by(State_FIPS Year)
	tsset State_FIPS Year
	xtreg ln_domestic_seasonal ib1964.Year##c.mex_frac_55, fe vce(cluster State_FIPS)
	matrix coeffs = r(table)
	matrix coeffs = coeffs'
	mat coeffs = coeffs[22..41,1...]		// rows with interaction terms
	mat coeffs1 = coeffs[1...,1]			// coefficient estimates
	mat coeffs2 = coeffs[1...,5..6]			// upper and lower bounds
	mat mon = J(20,1,`m')					// Create vector of containing the value of the quarter
	mat coeffs_`m' = coeffs1,coeffs2,year,mon	// create submatrix of results containing only coefficient estimates and upper and lower bounds
	restore
}

foreach m of numlist 7/10 {					// Why a separate subroutine for months August and after: because 1973 months after July are missing worker data, so matrix one row smaller
	preserve
	keep if Year >=1954 & Year<=1973  			// keep only cells with non-missing wages
	keep if mex_frac_55>0						// only exposed states
	keep if Month==`m'
	collapse (mean) ln_domestic_seasonal mex_frac_55 treatment_frac Month, by(State_FIPS Year)
	tsset State_FIPS Year
	xtreg ln_domestic_seasonal ib1964.Year##c.mex_frac_55, fe vce(cluster State_FIPS)
	matrix coeffs = r(table)
	matrix coeffs = coeffs'
	mat coeffs = coeffs[21..39,1...]		// rows with interaction terms
	mat coeffs1 = coeffs[1...,1]			// coefficient estimates
	mat coeffs2 = coeffs[1...,5..6]			// upper and lower bounds
	mat mon = J(19,1,`m')					// Create vector of containing the value of the quarter
	mat coeffs_`m' = coeffs1,coeffs2,year_short,mon	// create submatrix of results containing only coefficient estimates and upper and lower bounds
	mat missing=(.,.,.,1973,`m')
	mat coeffs_`m' = coeffs_`m'\missing		// for conformability with matrices from 1st and 2nd quarters, which have one additional year (1971)
	restore
}

mat coeffs_full = coeffs_6\coeffs_7\coeffs_8\coeffs_9\coeffs_10

svmat coeffs_full

rename coeffs_full1 interaction
rename coeffs_full2 lower_bound
rename coeffs_full3 upper_bound
rename coeffs_full4 year_es
rename coeffs_full5 mon_es

gen time_m_es = ym(year_es,mon_es)
format time_m_es %tm

	
graph twoway rspike lower_bound upper_bound time_m_es if mon_es==6, lcolor(gs10) lwidth(*.5) ///
	|| scatter interaction time_m_es if mon_es==6, msymbol(O) mcolor(white) mlcolor(black) msize(*.7) mlwidth(*.4) ///
	|| rspike lower_bound upper_bound time_m_es if mon_es==9, lcolor(gs10) lwidth(*.5) ///
	|| scatter interaction time_m_es if mon_es==9, msymbol(O) mcolor(black) mlcolor(black) msize(*.7) mlwidth(*.5) ///
	scheme(s1color) xline(26, lcolor(black) lpattern(vshortdash) lwidth(thin)) ///
	xline(59, lcolor(black) lpattern(vshortdash) lwidth(thin)) plotregion(lcolor(none)) yline(0, lcolor(gs14) lwidth(vthin)) ///
	ytitle("{it:coeff} (Year `=uchar(0215)' 1955 {it:bracero} stock)", margin(medium)) xtitle("Year", margin(small))  ///
	xlabel(-60(60)150,format(%tmCY)) xmtick(-72(12)162) ylabel(,format(%03.1f)) ///
	legend( order(- "Month:" 2 4) rows(1) region(lstyle(none) margin(none)) ///
	label(2 "June") label(4 "September") size(small) span)
	
graph export event_study_lwkr_month_exp.pdf, replace

drop interaction lower_bound upper_bound year_es mon_es time_m_es 
	

	
** APPENDIX FIGURE A3	
	
* Visual check for pre-trends in heaviest treatment states

foreach x in "New Mexico" "Nebraska" "Arizona" "Texas" "California" "South Dakota" "Nevada" "Arkansas" "Wyoming" {

	line ln_domestic_seasonal ln_Mexican time_m if State_name=="`x'" & time_m > ym(1954,1) & time_m < ym(1973,3), cmissing(n n) ///
		lcolor(black gs12) scheme(s1color) xline(26, lcolor(black) lpattern(vshortdash) lwidth(thin)) ///
		xline(59, lcolor(black) lpattern(vshortdash) lwidth(thin)) plotregion(lcolor(none)) ///
		ytitle("{it:ln} Seasonal workers", margin(small) size(large)) ylabel(#4, format(%3.0f) labsize(large)) ///
		xtitle("Year", margin(small) size(large)) xlabel(-60(60)150,format(%tmCY) labsize(large)) xmtick(-72(12)162) aspect(.5) ///
		legend(order(1 2) rows(1) region(lstyle(none) margin(none)) ///
		label(1 "Domestic") label(2 "Mexican") size(vsmall) span) title(`"`x'"', margin(medsmall))
	graph save "dom_mex_raw_`x'.gph", replace
	*graph export "dom_mex_raw_`x'.pdf", replace

}
	
grc1leg "dom_mex_raw_New Mexico.gph" "dom_mex_raw_Nebraska.gph" "dom_mex_raw_Arizona.gph" ///
	"dom_mex_raw_Texas.gph" "dom_mex_raw_California.gph" "dom_mex_raw_South Dakota.gph"   ///
	"dom_mex_raw_Nevada.gph" "dom_mex_raw_Arkansas.gph" "dom_mex_raw_Wyoming.gph", ///
	rows(3) scale(1.2) xsize(3.8) fysize(120) scheme(s1color) altshrink name(resized, replace)
graph export dom_mex_raw_combined.pdf, replace
	
erase "dom_mex_raw_New Mexico.gph"
erase "dom_mex_raw_Nebraska.gph" 
erase "dom_mex_raw_Arizona.gph"
erase "dom_mex_raw_Texas.gph"
erase "dom_mex_raw_California.gph"
erase "dom_mex_raw_South Dakota.gph"
erase "dom_mex_raw_Nevada.gph" 
erase "dom_mex_raw_Arkansas.gph" 
erase "dom_mex_raw_Wyoming.gph"


** APPENDIX TABLE A6

* Repeat with state-specific time trends

fvset base 0 time_num
fvset base 0 State_FIPS

eststo clear
eststo: xtreg domestic_seasonal treatment_frac i.time_num i.State_FIPS#c.time_num, fe vce(cluster State_FIPS)
eststo: xtreg ln_domestic_seasonal treatment_frac i.time_num i.State_FIPS#c.time_num, fe vce(cluster State_FIPS)
eststo: xtreg domestic_seasonal treatment_frac i.time_num i.State_FIPS#c.time_num if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
eststo: xtreg ln_domestic_seasonal treatment_frac i.time_num i.State_FIPS#c.time_num if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
eststo: xtreg domestic_seasonal treatment_frac i.time_num i.State_FIPS#c.time_num if !none, fe vce(cluster State_FIPS)
eststo: xtreg ln_domestic_seasonal treatment_frac i.time_num i.State_FIPS#c.time_num if !none, fe vce(cluster State_FIPS)

esttab using tables_bracero.tex, se ar2 nostar compress append keep(treatment_frac) ///
	booktabs alignment(D{.}{.}{-1}) title(APPENDIX TABLE A6: DD with continuous treatment and state-specific T trends, monthly, Jan 1954--Jul 1973 only)  ///
	scalars(N_clust ) 
	

** APPENDIX TABLE A7
	
* Robustness check, for Appendix: DD Wages with treatment in 1962
eststo clear
eststo: xtreg domestic_seasonal treatment_frac_2 i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg ln_domestic_seasonal treatment_frac_2 i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg domestic_seasonal treatment_frac_2 i.time_num if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
eststo: xtreg ln_domestic_seasonal treatment_frac_2 i.time_num if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
eststo: xtreg domestic_seasonal treatment_frac_2 i.time_num if !none, fe vce(cluster State_FIPS)
eststo: xtreg ln_domestic_seasonal treatment_frac_2 i.time_num if !none, fe vce(cluster State_FIPS)

esttab using tables_bracero.tex, se ar2 nostar compress append  keep(treatment_frac_2) ///
	booktabs alignment(D{.}{.}{-1}) title(APPENDIX TABLE A7: 1962 treatment: DD employment, monthly)  ///
	scalars(N_clust ) 


** APPENDIX TABLE A11
	
gen domestic_seasonal_missing = domestic_seasonal
replace domestic_seasonal_missing = . if domestic_seasonal_missing==0
gen IHSdomestic_seasonal = ln(domestic_seasonal + sqrt(1+(domestic_seasonal^2)))

eststo clear
eststo: xtreg domestic_seasonal_missing treatment_frac i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg IHSdomestic_seasonal treatment_frac i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg domestic_seasonal_missing treatment_frac i.time_num if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)
eststo: xtreg IHSdomestic_seasonal treatment_frac i.time_num if Year>=1960 & Year<=1970, fe vce(cluster State_FIPS)

esttab using tables_bracero.tex, se ar2 nostar compress append  keep(treatment_frac) ///
	booktabs alignment(D{.}{.}{-1}) title(APPENDIX TABLE A11: Differences-in-differences with continuous treatment, monthly, Jan 1954--Jul 1973 only, alternative treatment of zeros)  ///
	scalars(N_clust ) 

	
** TABLE 3

replace Local_final = 0 if Local_final==.
replace Intrastate_final = 0 if Local_final==.
replace Interstate_final = 0 if Local_final==.

replace Local_final=. if Year<1954 | Year>1973 | (Year==1973 & Month>7)    // No coverage in original sources outside Jan 1954 to Jul 1973
replace Intrastate_final=. if Year<1954 | Year>1973 | (Year==1973 & Month>7)    // No coverage in original sources outside Jan 1954 to Jul 1973
replace Interstate_final=. if Year<1954 | Year>1973 | (Year==1973 & Month>7)    // No coverage in original sources outside Jan 1954 to Jul 1973

eststo clear
eststo: xtreg Local_final treatment_frac i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg Intrastate_final treatment_frac i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg Interstate_final treatment_frac i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg ln_local treatment_frac i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg ln_intrastate treatment_frac i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg ln_interstate treatment_frac i.time_num, fe vce(cluster State_FIPS)

esttab using tables_bracero.tex, se ar2 nostar compress append  keep(treatment_frac) ///
	booktabs alignment(D{.}{.}{-1}) title(TABLE 3: Differences-in-differences with continuous treatment, monthly)  ///
	scalars(N_clust ) 
	

* Employment numbers are highly seasonal, complicating graphical display. Simple smoothing clarifies annual trends, but blurs important discontinuities
* Compromise: calculate maximum for spring/summer (March-July) and for fall (August-November)

gen semester = 1
replace semester = 2 if Month>=7 & Month<=12
gen time_h = yh(Year,semester)
format time_h %th

gen springsummer = inlist(Month,3,4,5,6,7)
gen fall = inlist(Month,8,9,10,11)

foreach var of varlist mex_frac Mexican domestic_seasonal dom_area mex_area Local_final Intrastate_final Interstate_final IHSdomestic_seasonal mextot fornonmextot {   // Generate cross-state averages of seasonal peaks
	sort State_FIPS Year Month
	by State_FIPS Year: egen springmax_`var' = max(`var') if springsummer
	by State_FIPS Year: egen fallmax_`var' = max(`var') if fall
	gen seamax_`var' = springmax_`var'									// season max
	replace seamax_`var' = fallmax_`var' if seamax_`var'==.			// season max
	
	by State_FIPS Year: egen yrmax_`var' = max(`var') 

	bysort time_h: egen seamax_`var'_none = mean(seamax_`var') if none
	bysort time_h: egen seamax_`var'_low = mean(seamax_`var') if low
	bysort time_h: egen seamax_`var'_high = mean(seamax_`var') if high
	
	bysort Year: egen yrmax_`var'_none = mean(yrmax_`var') if none
	bysort Year: egen yrmax_`var'_low = mean(yrmax_`var') if low
	bysort Year: egen yrmax_`var'_high = mean(yrmax_`var') if high
}

foreach var of varlist realwage_daily realwage_hourly {
	sort State_FIPS Year Month
	by State_FIPS Year: egen spring_`var' = mean(`var') if Month<=6
	by State_FIPS Year: egen fall_`var' = mean(`var') if Month>=7
	gen season_`var' = spring_`var'
	replace season_`var' = fall_`var' if season_`var'==.
	bysort time_h: egen season_`var'_none = mean(season_`var') if none
	bysort time_h: egen season_`var'_low = mean(season_`var') if low
	bysort time_h: egen season_`var'_high = mean(season_`var') if high
}


* FIGURE 2b: Stairstep graphs of wages	

graph twoway line season_realwage_hourly_none time_h if Year>=1948 & Year<=1972, c(stairstep) clcolor($color_control) clwidth(thin) clpattern(shortdash) ///
	|| line season_realwage_hourly_low time_h if Year>=1948 & Year<=1972, c(stairstep) clcolor($color_low *.66) clwidth(medium) clpattern(solid)  ///
	|| line season_realwage_hourly_high time_h if Year>=1948 & Year<=1972, c(stairstep) clcolor($color_high *.66) clwidth(medium) clpattern(solid)  ///
	xline(9.8, lcolor(black) lpattern(dot)) xline(4.7, lcolor(black) lpattern(dot)) scheme($scheme_set) plotregion(lcolor(none)) ///
	ytitle("Hourly wage, composite (1965 US$/hour)", margin(medium)) xtitle("Year", margin(medium))  ///
	xlabel(-20(10)20,format(%thCY)) xmtick(-24(2)26) ylabel(, format(%03.1f)) ///
	legend(colfirst order (- "{it:Bracero} fraction ({it:B}/{it:L}) in 1955:" - - 1 2 3) cols(2) region(lstyle(none) margin(none)) ///
	label(1 "No exposure ({it:B}/{it:L} = 0)") label(2 "Low exposure (0 < {it:B}/{it:L} < 0.2)") label(3 "High exposure ({it:B}/{it:L} {&ge} 0.2)")  ///
	size(small) span) aspect(.5)
	
graph export dd_wage_real_hourly_season.pdf, replace	



******** Event study formulation

** APPENDIX FIGURE A1

* Event study: Quarterly wage

mat year = 1948								// create vector of all years
foreach num of numlist 1949/1971 {	
	mat year_add = `num'
	mat year = year\year_add
}
mat year_short = year[1..23,1]				// needed below

foreach q of numlist 1/2 {
	preserve
	*collapse (mean) realwage_hourly mex_frac_55 treatment_frac Year quarter, by(State_FIPS time_q)
	keep if Year >=1948 & Year<=1971  			// keep only cells with non-missing wages
	keep if quarter==`q'
	collapse (mean) realwage_hourly mex_frac_55 treatment_frac quarter, by(State_FIPS Year)
	tsset State_FIPS Year
	xtreg realwage_hourly ib1964.Year##c.mex_frac_55, fe vce(cluster State_FIPS)
	matrix coeffs = r(table)
	matrix coeffs = coeffs'
	mat coeffs = coeffs[26..49,1...]		// rows with interaction terms
	mat coeffs1 = coeffs[1...,1]			// coefficient estimates
	mat coeffs2 = coeffs[1...,5..6]			// upper and lower bounds
	mat qtr = J(24,1,`q')					// Create vector of containing the value of the quarter
	mat coeffs_`q' = coeffs1,coeffs2,year,qtr	// create submatrix of results containing only coefficient estimates and upper and lower bounds
	restore
}

foreach q of numlist 3/4 {					// Why a separate subroutine for quarters 3 and 4: because 1971 quarters 3 and 4 are missing wage data, so matrix one row smaller
	preserve
	*collapse (mean) realwage_hourly mex_frac_55 treatment_frac Year quarter, by(State_FIPS time_q)
	keep if Year >=1948 & Year<=1971  			// keep only cells with non-missing wages
	keep if quarter==`q'
	collapse (mean) realwage_hourly mex_frac_55 treatment_frac quarter, by(State_FIPS Year)
	tsset State_FIPS Year
	xtreg realwage_hourly ib1964.Year##c.mex_frac_55, fe vce(cluster State_FIPS)
	matrix coeffs = r(table)
	matrix coeffs = coeffs'
	mat coeffs = coeffs[25..47,1...]		// rows with interaction terms
	mat coeffs1 = coeffs[1...,1]			// coefficient estimates
	mat coeffs2 = coeffs[1...,5..6]			// upper and lower bounds
	mat qtr = J(23,1,`q')					// Create vector of containing the value of the quarter
	mat coeffs_`q' = coeffs1,coeffs2,year_short,qtr	// create submatrix of results containing only coefficient estimates and upper and lower bounds
	mat missing=(.,.,.,1971,`q')
	mat coeffs_`q' = coeffs_`q'\missing		// for conformability with matrices from 1st and 2nd quarters, which have one additional year (1971)
	restore
}

mat coeffs_full = coeffs_1\coeffs_2\coeffs_3\coeffs_4

svmat coeffs_full

rename coeffs_full1 interaction
rename coeffs_full2 lower_bound
rename coeffs_full3 upper_bound
rename coeffs_full4 year_es
rename coeffs_full5 qtr_es

gen time_q_es = yq(year_es,qtr_es)
format time_q_es %tq


graph twoway rspike lower_bound upper_bound time_q_es if qtr_es==1, lcolor(gs10) lwidth(*.5) ///
	|| scatter interaction time_q_es if qtr_es==1, msymbol(S) mcolor(white) mlcolor(black) msize(*.4) mlwidth(*.4) ///
	|| rspike lower_bound upper_bound time_q_es if qtr_es==2, lcolor(gs10) lwidth(*.5) ///
	|| scatter interaction time_q_es if qtr_es==2, msymbol(S) mcolor(black) mlcolor(black) msize(*.4) mlwidth(*.4) ///
	|| rspike lower_bound upper_bound time_q_es if qtr_es==3, lcolor(gs10) lwidth(*.5) ///
	|| scatter interaction time_q_es if qtr_es==3, msymbol(O) mcolor(white) mlcolor(black) msize(*.5) mlwidth(*.5) ///
	|| rspike lower_bound upper_bound time_q_es if qtr_es==4, lcolor(gs10) lwidth(*.5) ///
	|| scatter interaction time_q_es if qtr_es==4, msymbol(O) mcolor(black) mlcolor(black) msize(*.5) mlwidth(*.5) ///
	scheme(s1color) xline(19.7, lcolor(black) lpattern(vshortdash) lwidth(thin)) ///
	xline(9, lcolor(black) lpattern(vshortdash) lwidth(thin)) plotregion(lcolor(none)) yline(0, lcolor(gs14) lwidth(vthin)) ///
	ytitle("{it:coeff} (Year `=uchar(0215)' 1955 {it:bracero} stock)", margin(medium)) xtitle("Year", margin(small))  ///
	xlabel(-60(20)60,format(%tqCY)) xmtick(-60(4)60) ylabel(,format(%03.1f)) ///
	legend( order(- "Quarter:" 2 4 6 8) rows(1) region(lstyle(none) margin(none)) ///
	label(2 "1{superscript:st}") label(4 "2{superscript:nd}") label(6 "3{superscript:rd}") label(8 "4{superscript:th}") size(small) span)
	
graph export event_study_wage_qtr.pdf, replace

drop interaction lower_bound upper_bound year_es qtr_es time_q_es 

******************************************************
	
	
** FIGURE 2a
	
* Stairstep graphs of worker stocks
	
graph twoway line seamax_mex_frac_none time_h if fulldata, c(stairstep) clcolor($color_control) clwidth(thin) clpattern(shortdash) ///
	|| line seamax_mex_frac_low time_h if fulldata, c(stairstep) clcolor($color_low *.66) clwidth(medium) clpattern(solid)  ///
	|| line seamax_mex_frac_high time_h if fulldata, c(stairstep) clcolor($color_high *.66) clwidth(medium) clpattern(solid)  ///
	xline(9.8, lcolor(black) lpattern(dot)) xline(4.7, lcolor(black) lpattern(dot)) scheme($scheme_set) plotregion(lcolor(none)) ///
	ytitle("Average Mexican fraction (season peak)", margin(medium)) xtitle("Year", margin(medium))  ///
	xlabel(-20(10)20,format(%thCY)) xmtick(-24(2)26) ylabel(0(.1).5, format(%03.1f)) ///
	legend(colfirst order (- "{it:Bracero} fraction ({it:B}/{it:L}) in 1955:" - - 1 2 3) cols(2) region(lstyle(none) margin(none)) ///
	label(1 "No exposure ({it:B}/{it:L} = 0)") label(2 "Low exposure (0 < {it:B}/{it:L} < 0.2)") label(3 "High exposure ({it:B}/{it:L} {&ge} 0.2)")  ///
	size(small) span) aspect(.5)

graph export dd_mex_frac.pdf, replace
graph export "../../Replication_figures/Figure1_Replication_dd_mex_frac.pdf", replace


** FIGURE 3a

graph twoway line yrmax_Mexican_none Year if fulldata, c(stairstep) clcolor($color_control) clwidth(thin) clpattern(shortdash) ///
	|| line yrmax_Mexican_low Year if fulldata, c(stairstep) clcolor($color_low *.66) clwidth(medium) clpattern(solid)  ///
	|| line yrmax_Mexican_high Year if fulldata, c(stairstep) clcolor($color_high *.66) clwidth(medium) clpattern(solid)  ///
	xline(1964.9, lcolor(black) lpattern(dot)) xline(1962.3, lcolor(black) lpattern(dot)) scheme($scheme_set) plotregion(lcolor(none)) ///
	ytitle("Avg. Mexican workers per state (year peak)", margin(medium)) xtitle("Year", margin(medium)) title("Mexican workers", margin(medium) size(medium))  ///
	xlabel(1955(5)1970) xmtick(1954(1)1973) ylabel(0(40000)80000, format(%6.0fc)) ytick(0(10000)80000) ///
	legend(colfirst order (- "{it:Bracero} fraction ({it:B}/{it:L}) in 1955:" - - 1 2 3) cols(2) region(lstyle(none) margin(none)) ///
	label(1 "No exposure ({it:B}/{it:L} = 0)") label(2 "Low exposure (0 < {it:B}/{it:L} < 0.2)") label(3 "High exposure ({it:B}/{it:L} {&ge} 0.2)")  ///
	size(vsmall) span) aspect(1.1)
	
graph save dd_mexican, replace
*graph export dd_mexican.pdf, replace	
	
graph twoway line yrmax_domestic_seasonal_none Year if fulldata, c(stairstep) clcolor($color_control) clwidth(thin) clpattern(shortdash) ///
	|| line yrmax_domestic_seasonal_low Year if fulldata, c(stairstep) clcolor($color_low *.66) clwidth(medium) clpattern(solid)  ///
	|| line yrmax_domestic_seasonal_high Year if fulldata, c(stairstep) clcolor($color_high *.66) clwidth(medium) clpattern(solid)  ///
	xline(1964.9, lcolor(black) lpattern(dot)) xline(1962.3, lcolor(black) lpattern(dot)) scheme($scheme_set) plotregion(lcolor(none)) ///
	ytitle("Avg. domestic workers per state (year peak)", margin(medium)) xtitle("Year", margin(medium))  ///
	xlabel(1955(5)1970) xmtick(1954(1)1973) ylabel(0(40000)80000, format(%6.0fc)) ytick(0(10000)80000) title("Domestic workers", margin(medium) size(medium))  ///
	legend(colfirst order (- "{it:Bracero} fraction ({it:B}/{it:L}) in 1955:" - - 1 2 3) cols(2) region(lstyle(none) margin(none)) ///
	label(1 "No exposure ({it:B}/{it:L} = 0)") label(2 "Low exposure (0 < {it:B}/{it:L} < 0.2)") label(3 "High exposure ({it:B}/{it:L} {&ge} 0.2)")  ///
	size(vsmall) span) aspect(1.1)	

graph save dd_domestic, replace
*graph export dd_domestic.pdf, replace

grc1leg dd_mexican.gph dd_domestic.gph, rows(1)  fysize(95) scheme($scheme_set) plotregion(lcolor(none))  imargin(0 0 0 0)
graph export dd_employ.pdf, replace
graph export "../../Replication_figures/Figure2_Replication_dd_employ.pdf", replace	

erase "dd_mexican.gph"
erase "dd_domestic.gph"
	

** FIGURE 3b
	
graph twoway line yrmax_Local_final_none Year if fulldata, c(stairstep) clcolor($color_control) clwidth(thin) clpattern(shortdash) ///
	|| line yrmax_Local_final_low Year if fulldata, c(stairstep) clcolor($color_low *.66) clwidth(medium) clpattern(solid)  ///
	|| line yrmax_Local_final_high Year if fulldata, c(stairstep) clcolor($color_high *.66) clwidth(medium) clpattern(solid)  ///
	xline(1964.9, lcolor(black) lpattern(dot)) xline(1962.3, lcolor(black) lpattern(dot)) scheme($scheme_set) plotregion(lcolor(none)) ///
	ytitle("Avg. local workers (year peak)", margin(medium)) xtitle("Year", margin(medium)) title("Local", margin(medium) size(medium))  ///
	xlabel(1955(5)1970) xmtick(1954(1)1973) ylabel(0(30000)60000, format(%6.0fc)) ytick(0(10000)60000) ///
	legend(colfirst order (- "{it:Bracero} fraction ({it:B}/{it:L}) in 1955:" - - 1 2 3) cols(2) region(lstyle(none) margin(none)) ///
	label(1 "No exposure ({it:B}/{it:L} = 0)") label(2 "Low exposure (0 < {it:B}/{it:L} < 0.2)") label(3 "High exposure ({it:B}/{it:L} {&ge} 0.2)")  ///
	size(vsmall) span) aspect(1.1)
	
	graph save dd_local.gph, replace

	
graph twoway line yrmax_Intrastate_final_none Year if fulldata, c(stairstep) clcolor($color_control) clwidth(thin) clpattern(shortdash) ///
	|| line yrmax_Intrastate_final_low Year if fulldata, c(stairstep) clcolor($color_low *.66) clwidth(medium) clpattern(solid)  ///
	|| line yrmax_Intrastate_final_high Year if fulldata, c(stairstep) clcolor($color_high *.66) clwidth(medium) clpattern(solid)  ///
	xline(1964.9, lcolor(black) lpattern(dot)) xline(1962.3, lcolor(black) lpattern(dot)) scheme($scheme_set) plotregion(lcolor(none)) ///
	ytitle("Avg. intrastate workers (year peak)", margin(medium)) xtitle("Year", margin(medium))  title("Intrastate", margin(medium) size(medium)) ///
	xlabel(1955(5)1970) xmtick(1954(1)1973) ylabel(0(30000)60000, format(%6.0fc)) ytick(0(10000)60000) ///
	legend(colfirst order (- "{it:Bracero} fraction ({it:B}/{it:L}) in 1955:" - - 1 2 3) cols(2) region(lstyle(none) margin(none)) ///
	label(1 "No exposure ({it:B}/{it:L} = 0)") label(2 "Low exposure (0 < {it:B}/{it:L} < 0.2)") label(3 "High exposure ({it:B}/{it:L} {&ge} 0.2)")  ///
	size(vsmall) span) aspect(1.1)
	
	graph save dd_intra.gph, replace
	
graph twoway line yrmax_Interstate_final_none Year if fulldata, c(stairstep) clcolor($color_control) clwidth(thin) clpattern(shortdash) ///
	|| line yrmax_Interstate_final_low Year if fulldata, c(stairstep) clcolor($color_low *.66) clwidth(medium) clpattern(solid)  ///
	|| line yrmax_Interstate_final_high Year if fulldata, c(stairstep) clcolor($color_high *.66) clwidth(medium) clpattern(solid)  ///
	xline(1964.9, lcolor(black) lpattern(dot)) xline(1962.3, lcolor(black) lpattern(dot)) scheme($scheme_set) plotregion(lcolor(none)) ///
	ytitle("Avg. interstate workers (year peak)", margin(medium)) xtitle("Year", margin(medium))  title("Interstate", margin(medium) size(medium)) ///
	xlabel(1955(5)1970) xmtick(1954(1)1973) ylabel(0(30000)60000, format(%6.0fc)) ytick(0(10000)60000) ///
	legend(colfirst order (- "{it:Bracero} fraction ({it:B}/{it:L}) in 1955:" - - 1 2 3) cols(2) region(lstyle(none) margin(none)) ///
	label(1 "No exposure ({it:B}/{it:L} = 0)") label(2 "Low exposure (0 < {it:B}/{it:L} < 0.2)") label(3 "High exposure ({it:B}/{it:L} {&ge} 0.2)")  ///
	size(vsmall) span) aspect(1.1)
	
	graph save dd_inter.gph, replace

grc1leg dd_local.gph dd_intra.gph dd_inter.gph, rows(1) scheme($scheme_set) plotregion(lcolor(none)) imargin(0 0 0 0) plotregion(margin(b=0)) fysize(75)
graph export dd_employ_sep.pdf, replace
	
erase "dd_local.gph"
erase "dd_intra.gph"
erase "dd_inter.gph"
	
	
** APPENDIX FIGURE A9: graph comparing Mexicans to non-Mexican foreign (Jamaica, etc.)

graph twoway line yrmax_mextot Year , c(stairstep) clcolor(black) clpattern(solid) ///
	|| line yrmax_fornonmextot Year , c(stairstep) clcolor(black) clpattern(shortdash)  ///
	scheme($scheme_set) plotregion(lcolor(none)) ///
	ytitle("Total worker stock, all states (peak month)", margin(medium)) xtitle("Year", margin(medium))  ///
	xlabel(1945(5)1975) xmtick(1942(1)1975) ylabel(0(100000)300000, format(%6.0fc))   ///
	legend(colfirst cols(1) region(lcolor(none) margin(zero)) label(1 "Mexican") label(2 "Non-Mexican foreign") size(small) span) 

graph export nonmex.pdf, replace
	

** APPENDIX TABLE A4: FE specification

* log Mexican workers
eststo clear
eststo: xtreg ln_domestic_seasonal ln_Mexican i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg ln_local ln_Mexican i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg ln_intrastate ln_Mexican i.time_num, fe vce(cluster State_FIPS)
eststo: xtreg ln_interstate ln_Mexican i.time_num, fe vce(cluster State_FIPS)

esttab using tables_bracero.tex, se compress nostar append     ///
	keep(ln_Mexican) booktabs alignment(D{.}{.}{-1}) title(APPENDIX TABLE A4: Employment FE regressions, monthly)  ///
	scalars(N_clust ) // order(net_inflow_rate) )

	
** FIGURE 4b	
	
xi: xtsemipar ln_domestic_seasonal i.time_num, nonpar(ln_Mexican) cluster(State_FIPS) degree(1) nograph generate(fitted resids)
	
graph twoway lpolyci resids ln_Mexican if ln_Mexican<. & resids<., degree(1) bwidth(2) ///
	lcolor($color_low *.2) ciplot(rline) alpattern(shortdash) || ///
	scatter resids ln_Mexican if ln_Mexican<. & resids<., ///
	msymbol(smcircle) msize(*0.2) mcolor($color_set) legend(off) ///
	scheme($scheme_set) plotregion(lcolor(none)) xlabel(0(2)12) xtick(0(1)12) ///
	xtitle("{it: ln} Mexican workers {stSymbol:|} state, month-by-year FE", margin(medium)) ///
	ytitle("{it: ln} Domestic workers {stSymbol:|} state, month-by-year FE", margin(medium))

graph export semipar_domestic.pdf, replace	
	
	
** APPENDIX TABLE A9

gen all_farm_tot = (Farmworkers_Hired*1000)/farm_tot_57
gen mex_tot = Mexican/farm_tot_57
tsset State_FIPS time_m
eststo clear
eststo: xtreg all_farm_tot mex_tot i.time_num if all_farm_tot != . & mex_tot != ., fe vce(cluster State_FIPS)
eststo: xtreg Farmworkers_Hired_pop mex_pop i.time_num if Farmworkers_Hired_pop != . & mex_pop != ., fe vce(cluster State_FIPS)	
eststo: xtreg Farmworkers_Hired_area mex_area i.time_num if Farmworkers_Hired_area != . & mex_area != ., fe vce(cluster State_FIPS)	

esttab using tables_bracero.tex, se compress nostar append     ///
	keep(mex_tot mex_pop mex_area) booktabs alignment(D{.}{.}{-1}) title(APPENDIX TABLE A9: All hired farm workers, 1957-1973, monthly)  ///
	scalars(N_clust ) // order(net_inflow_rate) )
	
	
** APPENDIX TABLE A1, second part	
	
* Summary statistics table, monthly

log using summ_stats.txt, append
dis ""
dis ""
dis "Monthly"
dis ""
sutex Year Month domestic_seasonal Local_final Intrastate_final Interstate_final ln_domestic_seasonal ln_local ln_intrastate ln_interstate ln_Mexican treatment_frac, minmax
log close
	
	
** APPENDIX TABLE A13	
	
* Technology adoption

preserve
collapse (mean) Cotton_machine Sugarbeet_machine Sugarbeet_monogerm ln_Mexican ln_NonMexican mex_frac_55 treatment_frac high low none, by(State_FIPS Year)
keep if Year>1950
xtset State_FIPS Year

* Normalize adoption (0,1) interval
replace Cotton_machine = Cotton_machine/100
replace Sugarbeet_machine = Sugarbeet_machine/100
replace Sugarbeet_monogerm = Sugarbeet_monogerm/100

label var Cotton_machine "Cotton"
label var Sugarbeet_machine "Sugar beets (mech. thinning)"
label var Sugarbeet_monogerm "Sugar beets (monogerm seed)"

eststo clear
eststo: xtreg Cotton_machine treatment_frac, fe vce(cluster State_FIPS)
eststo: xtreg Sugarbeet_machine treatment_frac, fe vce(cluster State_FIPS)
*eststo: xtreg Sugarbeet_monogerm treatment_frac, fe vce(cluster State_FIPS)
*esttab, stats(N N_clust)

*eststo clear
eststo: xtreg Cotton_machine ln_Mexican, fe vce(cluster State_FIPS)
eststo: xtreg Cotton_machine ln_Mexican ln_NonMexican, fe vce(cluster State_FIPS)
eststo: xtreg Sugarbeet_machine ln_Mexican, fe vce(cluster State_FIPS)
eststo: xtreg Sugarbeet_machine ln_Mexican ln_NonMexican, fe vce(cluster State_FIPS)
*eststo: xtreg Sugarbeet_monogerm ln_Mexican, fe vce(cluster State_FIPS)
*eststo: xtreg Sugarbeet_monogerm ln_Mexican ln_NonMexican, fe vce(cluster State_FIPS)
	
esttab using tables_bracero.tex, se ar2 nostar compress append		///
	keep(treatment_frac ln_Mexican ln_NonMexican) booktabs alignment(D{.}{.}{-1})			/// 
	title(APPENDIX TABLE A13: Cotton and sugar beet mechanization) scalars(N_clust ) 

	
** APPENDIX FIGURE A7	
	
xtreg ln_Mexican, fe 
predict res_x, e
xtreg Cotton_machine, fe 
predict res_c, e
xtreg Sugarbeet_machine, fe 
predict res_sma, e
*xtreg Sugarbeet_monogerm, fe 
*predict res_smo, e

graph twoway lfitci res_c res_x, ciplot(rline) lcolor($color_low *.2) alpattern(shortdash) ///
	|| scatter res_c res_x, scheme(s1color) msymbol(smcircle) msize(*0.5) mcolor($color_set) ///
	legend(off) plotregion(lcolor(none)) xtitle("{it: ln} Mexican workers {stSymbol:|} state FE", margin(medium)) ///
	ytitle("Fraction cotton machine-harvested {stSymbol:|} state FE", margin(medium)) aspect(1) ///
	title("Cotton, 1951`=uchar(8211)'1967", margin(medium))
graph save cotton.gph, replace
graph twoway lfitci res_sma res_x, ciplot(rline) lcolor($color_low *.2) alpattern(shortdash)  ///
	|| scatter res_sma res_x, scheme(s1color) msymbol(smcircle) msize(*0.5) mcolor($color_set) ///
	legend(off) plotregion(lcolor(none)) xtitle("{it: ln} Mexican workers {stSymbol:|} state FE", margin(medium)) ///
	ytitle("Fraction sugar beets machine-thinned {stSymbol:|} state FE", margin(medium)) aspect(1) ///
	title("Sugar beets, 1960`=uchar(8211)'1965", margin(medium))
graph save sugarbeets.gph, replace
graph combine cotton.gph sugarbeets.gph, rows(1) fysize(95) scheme($scheme_set) plotregion(lcolor(none))
graph export adoption.pdf, replace

erase cotton.gph 
erase sugarbeets.gph


** APPENDIX TABLE A1, third part

* Summary stats, mechanization
log using summ_stats.txt, append
dis ""
dis ""
dis "Mechanization, annual"
dis ""
sutex Year Cotton_machine Sugarbeet_machine ln_Mexican treatment_frac, minmax
log close

restore	


** FIGURE 6: Crop production

preserve
collapse (mean) SugarBeets Cotton Tomatoes_total Lettuce Strawberries_total Citrus Cantaloupes BrusselsSprouts Asparagus_total Celery Cucumbers_pickle Tomatoes_fresh Tomatoes_proc Strawberries_fresh Strawberries_proc Asparagus_fresh Asparagus_proc ln_Mexican ln_NonMexican mex_frac_55 treatment_frac high low none, by(State_FIPS Year)
tsset State_FIPS Year

global crops "SugarBeets Cotton Tomatoes_total Tomatoes_fresh Tomatoes_proc Strawberries_fresh Strawberries_proc Strawberries_total Asparagus_total Lettuce Citrus Celery Cucumbers_pickle"
global crops1 "SugarBeets Cotton Tomatoes_total Tomatoes_fresh Tomatoes_proc Strawberries_fresh Strawberries_proc"
global crops2 "Strawberries_total Asparagus_total Lettuce Citrus Celery Cucumbers_pickle"

replace Citrus = . if State_FIPS==22  // Lousiana produced only a negligible few hundred boxes, compare to Florida's 150,000 -- throws off production index
replace Cucumbers_pickle = . if Year<=1960  // Trivial values near zero

* Normalize 1964 production to 100
foreach var of varlist $crops {
	gen `var'64_util = `var' if Year == 1964
	by State_FIPS: egen `var'64 = mean(`var'64_util)
	gen `var'64_rel = 100*`var'/`var'64
	drop `var'64 `var'64_util
}

label var SugarBeets64_rel "Sugar beets"
label var Cotton64_rel "Cotton"
label var Tomatoes_total64_rel "Tomatoes"
label var Tomatoes_fresh64_rel "Tomatoes (fresh)"
label var Tomatoes_proc64_rel "Tomatoes (processing)"
label var Strawberries_fresh64_rel "Strawberries (fresh)"
label var Strawberries_proc64_rel "Strawberries (processing)"
label var Strawberries_total64_rel "Strawberries (total)"
label var Asparagus_total64_rel "Asparagus"
label var Lettuce64_rel "Lettuce"
label var Citrus64_rel "Citrus"
label var Celery64_rel "Celery"
label var Cucumbers_pickle64_rel "Cucumbers (pickling)"


* Event study regressions

fvset base 1964 Year		// omitted base group
xi i.Year*mex_frac_55 		// interaction term for event study regressions
drop _IYeaXmex_1964			// omitted base group
gen prod_year = 1942+_n		// year for graphs
replace prod_year=. if prod_year<1955 | prod_year>1970

foreach var of varlist SugarBeets64_rel Cotton64_rel Tomatoes_total64_rel Strawberries_fresh64_rel Asparagus_total64_rel Lettuce64_rel Citrus64_rel Celery64_rel Cucumbers_pickle64_rel {
	bysort State_FIPS: egen nonmiss = count(`var')		// to balance the panel
	xtreg `var' _IYeaXmex_1943-_IYeaXmex_1975 b1964.Year if nonmiss>5, fe
	matrix coeffs = r(table)		// extract coefficients from interaction terms
	matrix coeffs = coeffs'
	matrix coeffs = coeffs[1...,1]
	matrix zero = 0
	matrix coeffs_full = coeffs[1..21,1]\zero					// coefficient for 1964 (base group) is zero
	matrix coeffs_full = coeffs_full[1..22,1]\coeffs[22...,1]
	svmat coeffs_full, n(production)
	matrix drop coeffs coeffs_full
	replace production1=. if prod_year<1955 | prod_year>1970
	replace production1 = 220 if prod_year==1969 & production1>220 // topcoding citrus so that all graphs can have same y-scale
	replace production1 = . if prod_year==1970 & production1>220 // topcoding citrus so that all graphs can have same y-scale
	replace production1 = -220 if prod_year==1969 & production1<-220 // bottom-coding cucumbers so that all graphs can have same y-scale
	replace production1 = . if prod_year==1970 & production1<-220 // bottom-coding cucumbers so that all graphs can have same y-scale
	line production1 prod_year if prod_year>=1960, lcolor(black) c(stairstep) ///
		xline(1964.85, lcolor(black) lpattern(dot) lwidth(thin)) xline(1962.3, lcolor(black) lpattern(dot) lwidth(thin)) /// 
		scheme(s1color) plotregion(lcolor(none)) ylabel(-200(100)200, labsize(medium)) xmtick(1960(1)1970) xlabel(, labsize(medium)) ///
		ytitle("Event study coefficient", size(medlarge) margin(medsmall)) xtitle("Year", size(medlarge) margin(medsmall)) aspect(.5) ///
		title("`: variable label `var''", size(vlarge) margin(medsmall)) ///
		legend(off)
	graph save `var'.gph, replace
	drop production1 nonmiss
}


graph combine Tomatoes_total64_rel.gph Cotton64_rel.gph SugarBeets64_rel.gph Asparagus_total64_rel.gph Strawberries_fresh64_rel.gph Lettuce64_rel.gph Celery64_rel.gph Cucumbers_pickle64_rel.gph Citrus64_rel.gph, rows(3) scale(1.2) xsize(3.8) fysize(60) scheme(s1color) altshrink name(resized, replace)
graph export crops_combined.pdf, replace 
graph combine SugarBeets64_rel.gph Strawberries_fresh64_rel.gph, rows(2) scheme(s1color)
graph export "../../Replication_figures/Figure9_Replication_crops_beets_strawberries.pdf", replace

erase Tomatoes_total64_rel.gph
erase Cotton64_rel.gph 
erase SugarBeets64_rel.gph 
erase Asparagus_total64_rel.gph 
erase Strawberries_fresh64_rel.gph 
erase Lettuce64_rel.gph 
erase Celery64_rel.gph 
erase Cucumbers_pickle64_rel.gph 
erase Citrus64_rel.gph



** APPENDIX TABLE A1, fourth part

* Summary stats, production
log using summ_stats.txt, append
dis ""
dis ""
dis "Crop production, annual"
dis ""
sutex Year Tomatoes_total64_rel Cotton64_rel SugarBeets64_rel Asparagus_total64_rel Strawberries_fresh64_rel Lettuce64_rel Celery64_rel Cucumbers_pickle64_rel Citrus64_rel ln_Mexican treatment_frac, minmax
log close


restore


** APPENDIX FIGURE A10: graph of bracero stocks by month

cd "$data_folder"
use "bracero_aer_dataset.dta", clear

* Switch default directory to output folder, to store tables and figures
cd "$output_folder"
sort Month

by Month: egen mex_tot_month_40 = total(Mexican_final) if Year>=1940 & Year<1950
egen mex_max_40 = max(mex_tot_month_40)
by Month: gen mex_max_frac_40 = mex_tot_month_40/ mex_max_40

by Month: egen mex_tot_month_50 = total(Mexican_final) if Year>=1950 & Year<1960
egen mex_max_50 = max(mex_tot_month_50)
by Month: gen mex_max_frac_50 = mex_tot_month_50/ mex_max_50

by Month: egen mex_tot_month_60 = total(Mexican_final) if Year>=1960 & Year<1970
egen mex_max_60 = max(mex_tot_month_60)
by Month: gen mex_max_frac_60 = mex_tot_month_60/ mex_max_60

graph twoway line mex_max_frac_40 mex_max_frac_50 mex_max_frac_60  Month, xlab(1(1)12, valuelabel) scheme($scheme_set) plotregion(lcolor(none)) ylabel(0(.2)1, format(%03.1f)) lcolor($color_set $color_set $color_set) lpattern(shortdash dash solid) legend(label(1 "1940s") label(2 "1950s") label(3 "1960s") cols(1) region(lcolor(none))) xtitle("Month", margin(medium)) ytitle("Fraction of annual max. present", margin (medium))

graph export monthly_stocks.pdf, replace


** APPENDIX FIGURE A5: graph comparing Mexico bracero outflows with U.S. bracero stocks

preserve
sort Year
collapse (sum) Mexican_final, by(Month Year)
cd "$data_folder"
merge m:1 Year using "bracero_outflows_from_mex_gonzalez.dta"
drop  _merge
cd "$output_folder"

label var bracero_outflow "Flow measure of braceros departing Mexico during entire year"
destring bracero_outflow, replace

cd "$output_folder"
graph twoway scatter bracero_outflow Year if Month==10, connect(l) clcolor(black) clpattern(shortdash) cmissing(n) scheme($scheme_set) xlabel(1940(5)1975, labsize(small)) msymbol(none) plotregion(lcolor(none)) ytitle("Flow of {it: braceros} out of Mexico, entire year", margin(medium)) xtitle("Year", margin(medium)) ylab(0(100000)500000,format(%7.0fc) labsize(small) )   aspect(1) ysc(range(0 550000))
graph export outflows_mex.pdf, replace

graph twoway scatter Mexican_final Year if Month==10, connect(l) clpattern(solid) clcolor($color_set) cmissing(n) msymbol(none) || scatter Mexican_final Year if Month==7, connect(l) clpattern(solid) clcolor(gs6) cmissing(n) msymbol(none) || scatter Mexican_final Year if Month==4, connect(l) clpattern(solid) clcolor(gs10) cmissing(n) msymbol(none) scheme($scheme_set) xlabel(1940(5)1975, labsize(small)) msymbol(none) plotregion(lcolor(none)) ytitle("Stock of {it: braceros} in the U.S., snapshot", margin(medium)) xtitle("Year", margin(medium)) ylab(0(100000)500000, format(%7.0fc) labsize(small) ) legend(off) text(300000 1957 "October", size(small) color($color_set)) text(170000 1957 "July", size(small) color(gs6)) text(85000 1957 "April", size(small) color(gs10)) aspect(1)  ysc(range(0 550000))
graph export stocks_comparison.pdf, replace

restore


** APPENDIX FIGURE A4: Graph of total bracero arrivals vs. apprehensions

cd "$data_folder"
use total_braceros_by_year.dta, clear
cd "$output_folder"

* line guestwork year, scheme(s1rcolor) ylabel(0(250000)500000, format(%9.0fc)) ytitle("Total {it:bracero} workers", margin(medium)) xtitle("Year", margin(medium)) plotregion(lcolor(none))
* graph export braceros_total.png, replace width(1600)

graph twoway line guestwork year, lcolor(black) c(stairstep) yaxis(1) ylabel(0(250000)500000, format(%9.0fc) axis(1)) ///
	ytitle("Total {it:bracero} arrivals", margin(medium) axis(1)) ///
	|| line apprehensions year, lcolor(black) c(stairstep) lpattern(shortdash) yaxis(2) ylabel(#3, format(%9.0fc) axis(2)) /// 
	ytitle("Apprehensions of Mexicans", margin(medium) axis(2)) ///
	xtitle("Year", margin(medium)) plotregion(lcolor(none)) scheme(s1color) aspect(.6) ///
	legend(label (1 "{it:Bracero} arrivals, US total (left axis)") label(2 "Apprehensions (right axis)") cols(1) region(lcolor(none))) ///
	xline(1964.85, lcolor(black) lpattern(dot) lwidth(thin)) xline(1962.3, lcolor(black) lpattern(dot) lwidth(thin))
	
graph export braceros_apprehensions.pdf, replace 


** FIGURE 5: tomato graph

cd "$data_folder"
use tomatoes_vandermeer_final.dta, clear
cd "$output_folder"

graph twoway line braceros Year if State=="CA", yaxis(1) lcolor(black) c(stairstep)  /// 
	|| line tomato_mech Year if State=="CA", lcolor(black) c(stairstep) lpattern(shortdash) yaxis(2) /// 
	scheme(s1color) ylabel(0 50000 100000, axis(1) format(%7.0fc)) ///
	ylabel(0 50 100, axis(2)) ytitle("Peak {it:bracero} stock, California", margin(medium) axis(1)) ///
	ytitle("Tomato harvest mechnization, California (%)", margin(medium) axis(2)) ///
	xtitle("Year", margin(medium)) plotregion(lcolor(none)) ///
	legend(label (1 "Peak annual {it:bracero} stock (left axis)") label(2 "Tomato harvest mechnization (right axis)") cols(1) region(lcolor(none))) aspect(.5)  ///
	xline(1964.85, lcolor(black) lpattern(dot) lwidth(thin)) xline(1962.3, lcolor(black) lpattern(dot) lwidth(thin))

graph export bracero_tomato_ca.pdf, replace

graph twoway line braceros Year if State=="OH", yaxis(1) lcolor(black) c(stairstep)  /// 
	|| line tomato_mech Year if State=="OH", lcolor(black) c(stairstep) lpattern(shortdash) yaxis(2) /// 
	scheme(s1color) ylabel(0 50000 100000, axis(1) format(%7.0fc)) ///
	ylabel(0 50 100, axis(2)) ytitle("Peak {it:bracero} stock, Ohio", margin(medium) axis(1)) ///
	ytitle("Tomato harvest mechnization, Ohio (%)", margin(medium) axis(2)) ///
	xtitle("Year", margin(medium)) plotregion(lcolor(none)) ///
	legend(label (1 "Peak annual {it:bracero} stock (left axis)") label(2 "Tomato harvest mechnization (right axis)") cols(1) region(lcolor(none))) aspect(.5)  ///
	xline(1964.85, lcolor(black) lpattern(dot) lwidth(thin)) xline(1962.3, lcolor(black) lpattern(dot) lwidth(thin))

graph export bracero_tomato_oh.pdf, replace


** APPENDIX FIGURE A8

cd "$data_folder"

use "alston_ferrie_votes", clear

cd "$output_folder"

reshape long y n a, i(state_code state type) j(year)
gen exposure = "N"
replace exposure = "H" if inlist(state_code,"NM","NE","AZ","TX","CA","SD")
replace exposure = "L" if inlist(state_code,"NV","AR","WY","CO","MI","UT","MT","IN")
replace exposure = "L" if inlist(state_code,"MO","ID","MN","WI","IL","WA","TN","OR","GA")
preserve
collapse (sum) y n a, by(type year)
reshape wide y n a, i(year) j(type) string
graph twoway scatter yB year, connect(l) xlabel(1953(2)1963, labsize(large)) xtick(1952(1)1964) ytick(0(25)110) ylabel(0(25)100, labsize(large)) scheme(s1manual) ///
	 plotregion(lcolor(none)) xtitle("Year", margin(small) size(large)) ytitle("Yes votes", margin(small) size(large)) title("{it:Bracero} states", size(vlarge) margin(small))
graph save B.gph, replace
graph twoway scatter yN year, connect(l) xlabel(1953(2)1963, labsize(large)) xtick(1952(1)1964) ytick(0(25)110) ylabel(0(25)100, labsize(large)) scheme(s1manual) ///
	 plotregion(lcolor(none)) xtitle("Year", margin(small) size(large)) ytitle("Yes votes", margin(small) size(large)) title("Non-{it:bracero} states", size(vlarge) margin(small))
graph save N.gph, replace
graph twoway scatter yS year, connect(l) xlabel(1953(2)1963, labsize(large)) xtick(1952(1)1964) ytick(0(25)110) ylabel(0(25)100, labsize(large)) scheme(s1manual) ///
	 plotregion(lcolor(none)) xtitle("Year", margin(small) size(large)) ytitle("Yes votes", margin(small) size(large)) title("Southern states", size(vlarge) margin(small))
graph save S.gph, replace
graph twoway scatter yO year, connect(l) xlabel(1953(2)1963, labsize(large)) xtick(1952(1)1964) ytick(0(25)110) ylabel(0(25)100, labsize(large)) scheme(s1manual) ///
	 plotregion(lcolor(none)) xtitle("Year", margin(small) size(large)) ytitle("Yes votes", margin(small) size(large)) title("Other states", size(vlarge) margin(small))
graph save O.gph, replace
graph combine B.gph N.gph S.gph O.gph, rows(2) scale(1.2) xsize(3.8) fysize(120) scheme(s1manual) altshrink 
graph export votes_alston_cat.pdf, replace
restore

collapse (sum) y n a, by(exposure year)
reshape wide y n a, i(year) j(exposure) string
graph twoway scatter yH year, connect(l) xlabel(1953(2)1963, labsize(large)) xtick(1952(1)1964) ytick(0(25)150) ylabel(0(50)150, labsize(large)) scheme(s1manual) ///
	 plotregion(lcolor(none)) xtitle("Year", margin(small) size(large)) ytitle("Yes votes", margin(small) size(large)) title("High-exposure states", size(vlarge) margin(small))
graph save H.gph, replace
graph twoway scatter yL year, connect(l) xlabel(1953(2)1963, labsize(large)) xtick(1952(1)1964) ytick(0(25)150) ylabel(0(50)150, labsize(large)) scheme(s1manual) ///
	 plotregion(lcolor(none)) xtitle("Year", margin(small) size(large)) ytitle("Yes votes", margin(small) size(large)) title("Low-exposure states", size(vlarge) margin(small))
graph save L.gph, replace
graph twoway scatter yN year, connect(l) xlabel(1953(2)1963, labsize(large)) xtick(1952(1)1964) ytick(0(25)150) ylabel(0(50)150, labsize(large)) scheme(s1manual) ///
	 plotregion(lcolor(none)) xtitle("Year", margin(small) size(large)) ytitle("Yes votes", margin(small) size(large)) title("No-exposure  states", size(vlarge) margin(small))
graph save N.gph, replace
graph combine H.gph L.gph N.gph, rows(2) scale(1.2) xsize(3.8) fysize(120) scheme(s1manual) altshrink 
graph export votes_CLP_cat.pdf, replace

erase O.gph
erase S.gph
erase B.gph
erase N.gph
erase L.gph
erase H.gph

** END


