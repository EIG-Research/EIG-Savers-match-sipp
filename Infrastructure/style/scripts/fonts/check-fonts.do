version 17.0

local mode "`1'"
local allow_fallback 0
if "`mode'" == "allow_fallback" local allow_fallback 1

capture noisily graph set window fontface "Open Sans"
local body_primary_ok = (_rc == 0)

capture noisily graph set window fontface "Source Serif Pro"
local headline_primary_ok = (_rc == 0)

if `allow_fallback' == 0 {
    if !`body_primary_ok' | !`headline_primary_ok' {
        di as error "ERROR: Required primary fonts are missing in Stata."
        di as error "Required: Open Sans, Source Serif Pro"
        exit 459
    }
    di as text "PASS: Primary EIG fonts are installed."
    exit 0
}

local body_ok 0
foreach f in "Open Sans" "Arial" "Helvetica Neue" "Helvetica" {
    capture noisily graph set window fontface `"`f'"'
    if _rc == 0 local body_ok 1
}

local headline_ok 0
foreach f in "Source Serif Pro" "Source Serif 4" "Source Serif 3" "Georgia" "Times New Roman" {
    capture noisily graph set window fontface `"`f'"'
    if _rc == 0 local headline_ok 1
}

if !`body_ok' | !`headline_ok' {
    di as error "ERROR: No valid font found for one or more required stacks."
    exit 459
}

di as text "PASS: Required EIG font stacks are available (primary or fallback)."
exit 0
