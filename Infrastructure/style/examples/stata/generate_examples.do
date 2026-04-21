version 17.0

capture mkdir "examples"
capture mkdir "examples/outputs"
capture mkdir "examples/outputs/stata"

do "themes/stata/eig_theme.do"
eig_load_tokens "themes/stata/eig_tokens.do"

capture noisily eig_assert_fonts, allowfallback
if _rc {
    di as error "WARNING: Font check failed; proceeding with available fonts."
}

eig_graph_defaults

sysuse auto, clear
twoway ///
    (scatter mpg weight, mcolor("$EIG_RGB_EIG_TEAL_900") msymbol(circle_hollow)) ///
    (lfit mpg weight, lcolor("$EIG_RGB_EIG_BLUE_800") lwidth(medthick)), ///
    title("Fuel Economy by Vehicle Weight", size(medium) color("$EIG_RGB_EIG_BLACK")) ///
    subtitle("EIG token-driven Stata example", size(small) color("$EIG_RGB_EIG_TEAL_900")) ///
    xtitle("Weight", size(small)) ///
    ytitle("MPG", size(small)) ///
    legend(order(1 "Observed" 2 "Fitted") region(lstyle(none))) ///
    graphregion(color("$EIG_RGB_EIG_WHITE")) ///
    plotregion(color("$EIG_RGB_EIG_WHITE")) ///
    note("Source: Stata auto dataset", size(vsmall))
graph export "examples/outputs/stata/twoway_scatter.png", replace width(1600)

graph bar (mean) mpg, over(foreign) ///
    bar(1, color("$EIG_RGB_EIG_TEAL_900")) ///
    bar(2, color("$EIG_RGB_EIG_BLUE_800")) ///
    title("Average MPG by Vehicle Origin", size(medium) color("$EIG_RGB_EIG_BLACK")) ///
    graphregion(color("$EIG_RGB_EIG_WHITE")) ///
    plotregion(color("$EIG_RGB_EIG_WHITE"))
graph export "examples/outputs/stata/bar_chart.png", replace width(1600)

putdocx clear
putdocx begin
putdocx paragraph, style(Heading1)
putdocx text ("EIG Styled Table Example")

putdocx table t1 = data("Origin" "Mean MPG" "Mean Weight" ///
                        "Domestic" "19.8" "3318.5" ///
                        "Foreign"  "24.8" "2315.9"), varnames

putdocx table t1(1,.), shading("024140") font("Open Sans", 10, "FFFFFF") bold
putdocx table t1(2/3,.), font("Open Sans", 9, "000000")
putdocx save "examples/outputs/stata/eig_table_example.docx", replace

display as text "Wrote Stata example outputs to examples/outputs/stata"
