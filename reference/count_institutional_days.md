# Count institutional days inside the window.

Count institutional days inside the window.

## Usage

``` r
count_institutional_days(inst_data, win_data)
```

## Arguments

- inst_data:

  data.frame with merged intervals (\`patient_id\`, \`start\`, \`end\`).

- win_data:

  data.frame from \`apply_window_and_death\` (must contain
  \`patient_id\`, \`window_start\`, \`window_end\`).

## Value

Data.frame with \`patient_id\`, \`institutional_days\`.
