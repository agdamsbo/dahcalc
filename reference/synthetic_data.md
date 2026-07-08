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
#> 
#> === Validation summary ===
#>    patient_id overlap
#> 1           1   FALSE
#> 2           2   FALSE
#> 3           3   FALSE
#> 4           4   FALSE
#> 5           5   FALSE
#> 6           6   FALSE
#> 7           7   FALSE
#> 8           8   FALSE
#> 9           9   FALSE
#> 10         10   FALSE
#> 11         11   FALSE
#> 12         12   FALSE
#> 13         13   FALSE
#> 14         14   FALSE
#> 15         15   FALSE
#> 16         16   FALSE
#> 17         18   FALSE
#> 18         19   FALSE
#> 19         20   FALSE
#> 20         21   FALSE
#> 21         22   FALSE
#> 22         23   FALSE
#> 23         24   FALSE
#> 24         25   FALSE
#> 25         26   FALSE
#> 26         27   FALSE
#> 27         28   FALSE
#> 28         29   FALSE
#> 29         30   FALSE
#> 30         31   FALSE
#> 31         32   FALSE
#> 32         33   FALSE
#> 33         34   FALSE
#> 34         36   FALSE
#> 35         37   FALSE
#> 36         39   FALSE
#> 37         40   FALSE
#> 38         NA   FALSE
result$cohort_summary
#>     window_days n_patients mean_dah median_dah sd_dah q25_dah q75_dah
#> 25%          30         40    13.03       13.5   9.52       6   20.25
#>     pct_full_home mean_effective_window_days dah_per_100_pt_days
#> 25%             5                       26.9               48.42
```
