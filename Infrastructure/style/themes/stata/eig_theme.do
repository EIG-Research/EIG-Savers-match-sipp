version 17.0

capture program drop eig_load_tokens
program define eig_load_tokens
    args tokenfile
    if "`tokenfile'" == "" local tokenfile "themes/stata/eig_tokens.do"
    capture confirm file "`tokenfile'"
    if _rc {
        di as error "ERROR: Token file not found: `tokenfile'"
        exit 601
    }
    quietly do "`tokenfile'"
end

capture program drop eig_assert_fonts
program define eig_assert_fonts
    syntax [, ALLOWFALLBACK]
    local mode ""
    if "`allowfallback'" != "" local mode "allow_fallback"

    capture confirm file "scripts/fonts/check-fonts.do"
    if _rc {
        di as error "ERROR: Missing scripts/fonts/check-fonts.do"
        exit 601
    }
    quietly do "scripts/fonts/check-fonts.do" `mode'
    if _rc {
        di as error "ERROR: EIG font validation failed."
        exit _rc
    }
end

capture program drop eig_graph_defaults
program define eig_graph_defaults
    syntax [, TITLEFONT(string) BODYFONT(string)]

    if "`bodyfont'" == "" local bodyfont "$EIG_FONT_BODY"
    if "`titlefont'" == "" local titlefont "$EIG_FONT_HEADLINE"

    set scheme s2color
    graph set window fontface "`bodyfont'"
    graph set print  fontface "`bodyfont'"
    graph set ps     fontface "`bodyfont'"

    * Convenience globals for common chart styling
    global EIG_CHART_TITLE_FONT "`titlefont'"
    global EIG_CHART_TEXT_FONT  "`bodyfont'"
    global EIG_CHART_BG "$EIG_HEX_EIG_WHITE"
    global EIG_CHART_TEXT "$EIG_HEX_EIG_BLACK"
end

capture program drop eig_palette_discrete
program define eig_palette_discrete, rclass
    return local colors "$EIG_DISCRETE_HEX"
end

capture program drop eig_palette_legacy
program define eig_palette_legacy, rclass
    syntax, SET(string)
    if "`set'" == "dci_quintile" {
        return local colors "$EIG_LEGACY_DCI_QUINTILE_DISTRESSED $EIG_LEGACY_DCI_QUINTILE_AT_RISK $EIG_LEGACY_DCI_QUINTILE_MID_TIER $EIG_LEGACY_DCI_QUINTILE_COMFORTABLE $EIG_LEGACY_DCI_QUINTILE_PROSPEROUS"
        exit
    }
    di as error "ERROR: Unsupported legacy set: `set'"
    exit 198
end

* Typical startup sequence:
*   do themes/stata/eig_theme.do
*   eig_load_tokens
*   eig_assert_fonts
*   eig_graph_defaults
