# Plot the distribution of Days‑At‑Home

A histogram where bars are coloured by death‑in‑window status, with a
vertical line for the window length and another for the median DAH. The
y‑axis shows only whole numbers.

## Usage

``` r
plot_dah_distribution(per_pat, window_days = 30L)
```

## Arguments

- per_pat:

  Data.frame produced by \`compute_dah_per_patient()\`.

- window_days:

  Observation window length (default = 30).

## Value

A \*\*ggplot2\*\* object.
