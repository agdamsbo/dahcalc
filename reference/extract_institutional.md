# Extract hospital / rehabilitation stays (as integer days)

Extract hospital / rehabilitation stays (as integer days)

## Usage

``` r
extract_institutional(
  data,
  patient_id_col = "patient_id",
  event_type_col = "event_type",
  start_date_col = "start_date",
  end_date_col = "end_date"
)
```

## Arguments

- data:

  Output of \`validate_events()\`.

- patient_id_col:

  column name for patient ID.

- event_type_col:

  column name for event type.

- start_date_col:

  column name for stay start date.

- end_date_col:

  column name for stay end date.

## Value

Data.frame with \`patient_id\`, \`start\`, \`end\` (both integer days).
