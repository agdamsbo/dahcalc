# Run the whole DAH pipeline (dates returned as \`Date\` objects)

Run the whole DAH pipeline (dates returned as \`Date\` objects)

## Usage

``` r
run_dah_pipeline(
  data_long,
  window_days = 30L,
  patient_id_col = "patient_id",
  event_id_col = "event_id",
  event_type_col = "event_type",
  start_date_col = "start_date",
  end_date_col = "end_date",
  intervention_date_col = "intervention_date",
  death_date_col = "death_date",
  verbose = TRUE,
  keep_original_names = FALSE
)
```

## Arguments

- data_long:

  Raw long‑format data (\`data.frame\` or \`data.table\`).

- window_days:

  Observation window length (default = 30).

- patient_id_col:

  column name for patient ID (default \`"patient_id"\`).

- event_id_col:

  column name for event ID (default \`"event_id"\`).

- event_type_col:

  column name for event type (default \`"event_type"\`).

- start_date_col:

  column name for start date (default \`"start_date"\`).

- end_date_col:

  column name for end date (default \`"end_date"\`).

- intervention_date_col:

  column name for the primary intervention date (default
  \`"intervention_date"\`).

- death_date_col:

  column name for death date (default \`"death_date"\`).

- verbose:

  Logical; retained for backward compatibility but has no effect
  (default = `TRUE`).

- keep_original_names:

  If `TRUE`, the output keeps the user‑supplied column names (default =
  `FALSE`).

## Value

List with \`per_patient\`, \`cohort_summary\`, \`plot\`, and
\`column_mapping\`. All date columns in \`per_patient\` are \`Date\`
objects.
