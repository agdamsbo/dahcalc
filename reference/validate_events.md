# Validate the long‑format event data

Checks required columns, coerces all date columns to \`Date\`, validates
a single primary event per patient and that start ≤ end. Overlap
detection is performed internally (required for merging) but \*\*no
overlap flag is returned\*\*.

## Usage

``` r
validate_events(
  data,
  patient_id_col = "patient_id",
  event_id_col = "event_id",
  event_type_col = "event_type",
  start_date_col = "start_date",
  end_date_col = "end_date",
  intervention_date_col = "intervention_date",
  death_date_col = "death_date"
)
```

## Arguments

- data:

  \`data.frame\` (or coercible) containing the event records.

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

## Value

A \*\*cleaned data.frame\*\* whose date columns are \`Date\` objects.
