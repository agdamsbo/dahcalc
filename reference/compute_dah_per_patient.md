# Compute Days‑At‑Home for each patient (early exit for deaths)

All rows with a non‑\`NA\` \`start_date\` are treated as admission
intervals. Overlapping intervals are merged (see \`merge_intervals\`).
If a patient dies inside the observation window the function returns
\`dah = 0\` and \`institutional_days = 0\` without performing interval
counting.

## Usage

``` r
compute_dah_per_patient(
  data_clean,
  window_days = 30L,
  patient_id_col = "patient_id",
  start_date_col = "start_date",
  end_date_col = "end_date",
  intervention_date_col = "intervention_date",
  death_date_col = "death_date"
)
```

## Arguments

- data_clean:

  Output of \`validate_and_prepare()\`.

- window_days:

  Length of the observation window (default = 30 days).

- patient_id_col:

  Column name for patient identifier (default \`"patient_id"\`).

- start_date_col:

  Column name for admission start date (default \`"start_date"\`).

- end_date_col:

  Column name for admission end date (default \`"end_date"\`).

- intervention_date_col:

  Column name for the index/intervention date (default
  \`"intervention_date"\`).

- death_date_col:

  Column name for death date (default \`"death_date"\`).

## Value

A \`data.frame\` (one row per patient) with columns \`patient_id\`,
\`index_date\` (Date), \`death_date\` (Date or NA), \`dah\`,
\`institutional_days\`, \`effective_window\` (always = \`window_days\`),
\`died_in_window\` (logical).
