# Run the complete DAH pipeline

Accepts any long‑format data that contains at least \`patient_id\`,
\`start_date\`, and \`end_date\`. Optional columns are
\`intervention_date\` (the anchor for the observation window) and
\`death_date\`. No event‑type handling is performed; every row with a
non‑\`NA\` \`start_date\` is treated as an admission interval.

## Usage

``` r
run_dah_pipeline(
  data_long,
  window_days = 30L,
  patient_id_col = "patient_id",
  start_date_col = "start_date",
  end_date_col = "end_date",
  intervention_date_col = "intervention_date",
  death_date_col = "death_date",
  verbose = TRUE
)
```

## Arguments

- data_long:

  Raw long‑format data (\`data.frame\` or \`data.table\`).

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

- verbose:

  Logical; retained for compatibility (no console output).

## Value

A list with three components: \`per_patient\` – per‑patient DAH table
(date columns are \`Date\`), \`cohort_summary\` – cohort‑level
statistics, \`plot\` – histogram of DAH values.
