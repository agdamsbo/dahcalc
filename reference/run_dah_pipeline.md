# Run the whole DAH pipeline.

Accepts a long‑format data.frame and optional column‑name mappings.

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

  raw data (\`data.frame\` or \`data.table\`).

- window_days:

  observation window length (default = 30).

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

  column name for intervention date (default \`"intervention_date"\`).

- death_date_col:

  column name for death date (default \`"death_date"\`).

- verbose:

  logical; print overlapping‑stay summary (default = TRUE).

- keep_original_names:

  logical; if TRUE, keep the user‑supplied column names in the
  per‑patient output.

## Value

List with \`per_patient\`, \`cohort_summary\`, \`plot\`,
\`overlap_flag\`, \`column_mapping\`.
