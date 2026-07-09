# Plot the distribution of Days‑At‑Home

Plot the distribution of Days‑At‑Home

## Usage

``` r
plot_dah_distribution(data, window_days = 30L)
```

## Arguments

- data:

  Per‑patient result from \`compute_dah()\`.

- window_days:

  Observation window length (default = 30).

## Value

A ggplot2 object (single‑colour histogram).
