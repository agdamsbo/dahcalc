# Compute Days‑At‑Home per patient.

Compute Days‑At‑Home per patient.

## Usage

``` r
compute_dah(win_data, inst_counts, window_days = 30L)
```

## Arguments

- win_data:

  output of \`apply_window_and_death\`.

- inst_counts:

  output of \`count_institutional_days\`.

- window_days:

  length of observation window (default = 30).

## Value

Data.frame with \`patient_id\`, \`dah\`, \`effective_window\`,
\`institutional_days\`, \`died_in_window\`.
