# Add observation window and death‑inside‑window flag.

Add observation window and death‑inside‑window flag.

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

  data.frame from \`extract_primary\`.

- window_days:

  integer length of the observation window (default = 30).

- intervention_date_col:

  column name for intervention date.

- death_date_col:

  column name for death date.

## Value

\`primary_data\` with \`window_start\`, \`window_end\`, and
\`died_in_window\` columns.
