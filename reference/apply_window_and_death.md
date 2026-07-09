# Add observation window and flag deaths inside the window

Add observation window and flag deaths inside the window

## Usage

``` r
apply_window_and_death(
  primary_data,
  window_days = 30L,
  intervention_date_col = "intervention_date",
  death_date_col = "death_date"
)
```

## Arguments

- primary_data:

  Data.frame from \`extract_primary()\`.

- window_days:

  Integer length of the observation window (default = 30).

- intervention_date_col:

  column name for the intervention date.

- death_date_col:

  column name for death date.

## Value

\`primary_data\` with integer \`window_start\`, \`window_end\` and
logical \`died_in_window\`. Original Date columns are untouched.
