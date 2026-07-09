# Count institutional days that fall inside the (full) observation window

Count institutional days that fall inside the (full) observation window

## Usage

``` r
count_institutional_days(inst_data, win_data)
```

## Arguments

- inst_data:

  Data.frame with merged intervals (\`patient_id\`, \`start\`, \`end\`)
  – integer days.

- win_data:

  Data.frame from \`apply_window_and_death()\` that must contain
  \`patient_id\`, \`window_start\`, \`window_end\` and
  \`died_in_window\`.

## Value

Data.frame with \`patient_id\` and \`institutional_days\`. If a patient
died inside the window the count is forced to 0.
