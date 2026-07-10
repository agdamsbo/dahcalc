# Example synthetic long‑format clinical data

A reproducible, synthetic data set that mimics the structure required by
the \*\*DAH\*\* (Days‑At‑Home) analysis pipeline. The data are in
\*long\* format and contain the columns:

- patient_id:

  Integer identifier of the patient.

- event_id:

  Consecutive integer for each event per patient.

- event_type:

  Character; one of \`"primary"\` (first admission), \`"hospital"\`
  (sub‑sequent admission), \`"rehabilitation"\` or \`"death"\`.

- start_date:

  Date of the start of the event (NA for death rows).

- end_date:

  Date of the end of the event (NA for death rows).

- intervention_date:

  Date of the primary clinical intervention. Only non‑NA for rows where
  `event_type == "primary"`.

- death_date:

  Date of death; NA for patients who survive the observation period. For
  death rows this is the actual date of death; for all other rows it is
  NA.

The data contain \*\*40\*\* simulated patients. Approximately 30 
patients have a separate death row; the remaining patients survive the
45‑day observation horizon. Hospital and rehabilitation stays are
randomly generated, may overlap, and are limited to a maximum of 45 days
after the primary admission.

## Format

A \*\*data.frame\*\* with 131 rows and 7 columns (see description
above).

## Source

Generated internally by the package using the script
\`data-raw/generate-synthetic_data.R\`. The random seed is set to
\`2026\` for reproducibility.

## Examples

``` r
## Load the data set
data(synthetic_data, package = "dahcalc")

## Quick look at the first few rows
head(synthetic_data)
#> # A tibble: 6 × 7
#>   patient_id event_id event_type     start_date end_date   intervention_date
#>        <int>    <int> <chr>          <date>     <date>     <date>           
#> 1          1        1 primary        2023-08-09 2023-08-16 2023-08-13       
#> 2          1        2 rehabilitation 2023-08-20 2023-08-30 NA               
#> 3          1        3 rehabilitation 2023-09-01 2023-09-09 NA               
#> 4          2        1 primary        2023-05-01 2023-05-12 2023-05-05       
#> 5          2        2 rehabilitation 2023-05-13 2023-05-17 NA               
#> 6          2        3 rehabilitation 2023-05-22 2023-06-01 NA               
#> # ℹ 1 more variable: death_date <date>

## Run the DAH pipeline on the synthetic data
result <- run_dah_pipeline(synthetic_data, window_days = 30)
result$cohort_summary
#>     window_days n_patients n_deaths mean_dah median_dah sd_dah q25_dah q75_dah
#> 25%          30         40       12     9.68         10   8.72       0      18
#>     pct_full_home mean_effective_window_days dah_per_100_pt_days
#> 25%             0                         30               32.25
```
