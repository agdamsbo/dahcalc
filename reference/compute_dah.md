# Compute Days‑At‑Home per patient

Compute Days‑At‑Home per patient

## Usage

``` r
compute_dah(win_data, inst_counts, window_days = 30L)
```

## Arguments

- win_data:

  Output of \`apply_window_and_death()\`.

- inst_counts:

  Output of \`count_institutional_days()\`.

- window_days:

  Length of the observation window (default = 30).

## Value

Data.frame with per‑patient results. All date columns are \`Date\`.
