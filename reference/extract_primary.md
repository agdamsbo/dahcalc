# Extract the primary admission record

Extract the primary admission record

## Usage

``` r
extract_primary(
  data,
  patient_id_col = "patient_id",
  event_type_col = "event_type",
  intervention_date_col = "intervention_date",
  death_date_col = "death_date"
)
```

## Arguments

- data:

  Output of \`validate_events()\` (canonical column names).

- patient_id_col:

  column name for patient ID (default \`"patient_id"\`).

- event_type_col:

  column name for event type (default \`"event_type"\`).

- intervention_date_col:

  column name for the primary intervention date (default
  \`"intervention_date"\`).

- death_date_col:

  column name for death date (default \`"death_date"\`).

## Value

Data.frame with \`patient_id\`, \`intervention_date\`, \`death_date\`.
