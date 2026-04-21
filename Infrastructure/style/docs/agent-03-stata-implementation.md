# Agent 03: Stata Specialist (First Pass)

## Scope
Translate `docs/agent-01-design-spec.md` into reusable Stata patterns for:
- Core graph families (`twoway`, `graph bar`, `histogram`, `coefplot`-style outputs)
- Table outputs (`collect`, `etable`, `putdocx`)

## 1) Font Installation Prompts
Stata uses fonts installed at the OS level. Install fonts first, then reopen Stata.

```stata
* macOS prompt (requires Homebrew)
!brew tap homebrew/cask-fonts
!brew install --cask font-open-sans font-source-serif-pro
```

```stata
* Verify Stata can see fonts (manual check in Graph Editor preferred)
graph set window fontface "Open Sans"
graph set print  fontface "Open Sans"
graph set ps     fontface "Open Sans"
```

## 2) Design Tokens (globals)
```stata
* Core brand colors (RGB triples)
global EIG_TEAL_900   "4 65 64"
global EIG_GREEN_700  "26 101 77"
global EIG_GREEN_500  "94 156 134"
global EIG_BLUE_800   "25 79 139"
global EIG_BLUE_200   "179 214 221"
global EIG_CREAM_100  "254 236 214"
global EIG_PURPLE_800 "57 39 79"
global EIG_GOLD_600   "225 173 40"
global EIG_CYAN_700   "23 111 150"
global EIG_TAN_500    "214 147 111"
global EIG_TAN_300    "240 183 153"
global EIG_BLACK      "0 0 0"
global EIG_WHITE      "255 255 255"

* Legacy semantic palettes (for comparability use cases)
global EIG_DCI_DISTRESSED  "151 49 14"
global EIG_DCI_ATRISK      "249 125 30"
global EIG_DCI_MIDTIER     "159 210 192"
global EIG_DCI_COMFORTABLE "65 158 241"
global EIG_DCI_PROSPEROUS  "22 76 135"

* Sequential map scales
global EIG_SEQ_BLUE1 "22 76 135"
global EIG_SEQ_BLUE2 "35 107 183"
global EIG_SEQ_BLUE3 "65 158 241"
global EIG_SEQ_BLUE4 "121 197 253"
global EIG_SEQ_BLUE5 "193 220 253"
```

## 3) Graph Defaults Program
```stata
capture program drop eig_graph_defaults
program define eig_graph_defaults
    version 17.0
    set scheme s2color
    graph set window fontface "Open Sans"
    graph set print  fontface "Open Sans"
    graph set ps     fontface "Open Sans"
end
```

Run once per session:
```stata
eig_graph_defaults
```

## 4) Common Chart Patterns
### 4.1 `twoway` line/scatter
```stata
* Example: scatter with fitted line
sysuse auto, clear
twoway ///
    (scatter mpg weight, mcolor("$EIG_TEAL_900") msymbol(circle_hollow)) ///
    (lfit mpg weight, lcolor("$EIG_BLUE_800") lwidth(medthick)), ///
    title("Fuel Economy by Vehicle Weight", size(medium) color("$EIG_BLACK")) ///
    subtitle("EIG first-pass Stata styling", size(small) color("$EIG_TEAL_900")) ///
    xtitle("Weight", size(small)) ///
    ytitle("MPG", size(small)) ///
    legend(order(1 "Observed" 2 "Fitted") region(lstyle(none))) ///
    graphregion(color("$EIG_WHITE")) ///
    plotregion(color("$EIG_WHITE")) ///
    note("Source: Stata auto dataset", size(vsmall))
```

### 4.2 `graph bar`
```stata
graph bar (mean) mpg, over(foreign) ///
    bar(1, color("$EIG_TEAL_900")) ///
    bar(2, color("$EIG_BLUE_800")) ///
    title("Average MPG by Vehicle Origin", size(medium)) ///
    graphregion(color("$EIG_WHITE")) ///
    plotregion(color("$EIG_WHITE"))
```

### 4.3 Distribution plot
```stata
histogram mpg, ///
    color("$EIG_BLUE_200") ///
    lcolor("$EIG_BLUE_800") ///
    fcolor("$EIG_BLUE_200") ///
    title("Distribution of MPG", size(medium)) ///
    graphregion(color("$EIG_WHITE"))
```

## 5) Table Styling Patterns
### 5.1 `collect` + `table`
```stata
clear
sysuse auto, clear
collect clear
table (foreign) (), statistic(mean mpg) statistic(mean weight)
collect style cell, nformat(%9.1f)
collect style column, halign(right)
collect preview
```

### 5.2 Export styled table with `putdocx`
```stata
putdocx clear
putdocx begin
putdocx paragraph, style(Heading1)
putdocx text ("EIG Styled Table")

putdocx table t1 = data("Origin" "Mean MPG" "Mean Weight" ///
                        "Domestic" "19.8" "3318.5" ///
                        "Foreign"  "24.8" "2315.9"), varnames

* Header styling (dark fill, white text)
putdocx table t1(1,.), shading("024140") font("Open Sans", 10, "FFFFFF") bold

* Body styling
putdocx table t1(2/3,.), font("Open Sans", 9, "000000")

putdocx save "eig_table_example.docx", replace
```

## 6) Coverage Notes
- Graph families covered: `twoway`, `graph bar`, `histogram`.
- Event study and coefficient plots can inherit the same token globals and text rules.
- Table workflow covered for `collect` and Word export via `putdocx`.
- Legacy semantic colors included for continuity with older EIG data-viz semantics.
