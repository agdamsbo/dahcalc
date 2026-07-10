# Validate input and coerce date columns

Ensures required columns exist, adds optional columns if missing,
coerces all date columns to \`Date\`, and checks that \`start_date\`
never exceeds \`end_date\`.

## Usage

``` r
validate_and_prepare(
  data,
  patient_id_col = "patient_id",
  start_date_col = "start_date",
  end_date_col = "end_date",
  intervention_date_col = "intervention_date",
  death_date_col = "death_date"
)
```

## Arguments

- data:

  A \`data.frame\` (or object coercible to one) containing the raw
  records.

- patient_id_col:

  Column name for patient identifier (default \`"patient_id"\`).

- start_date_col:

  Column name for start date (default \`"start_date"\`).

- end_date_col:

  Column name for end date (default \`"end_date"\`).

- intervention_date_col:

  Column name for the index/intervention date (default
  \`"intervention_date"\`). If the column is absent it will be created
  and filled with \`NA\`.

- death_date_col:

  Column name for death date (default \`"death_date"\`). If the column
  is absent it will be created and filled with \`NA\`.

## Value

A cleaned \`data.frame\` where all date columns are genuine \`Date\`
objects and \`start_date \<= end_date\` holds for every row.
