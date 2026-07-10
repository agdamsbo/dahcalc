# Summarise DAH at the cohort level

Provides descriptive statistics for a cohort, including the number of
deaths that occurred inside the observation window.

## Usage

``` r
summarise_cohort(per_pat, window_days = 30L)
```

## Arguments

- per_pat:

  Data.frame returned by \`compute_dah_per_patient()\`.

- window_days:

  Length of the observation window (default = 30).

## Value

A one‑row data.frame with summary statistics: \`window_days\`,
\`n_patients\`, \`n_deaths\`, mean/median/SD, inter‑quartile range,
proportion with full home days, mean effective window, and DAH per 100
patient‑days.
