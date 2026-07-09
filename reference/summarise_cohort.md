# Summarise DAH at the cohort level (adds number of deaths)

Summarise DAH at the cohort level (adds number of deaths)

## Usage

``` r
summarise_cohort(data, window_days = 30L)
```

## Arguments

- data:

  Per‑patient result returned by \`compute_dah()\`.

- window_days:

  Observation window length (default = 30).

## Value

One‑row data.frame with summary statistics, including \`n_deaths\`.
