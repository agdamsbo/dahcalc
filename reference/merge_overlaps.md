# Merge overlapping or adjacent institutional intervals per patient

Merge overlapping or adjacent institutional intervals per patient

## Usage

``` r
merge_overlaps(inst_data)
```

## Arguments

- inst_data:

  Data.frame with \`patient_id\`, \`start\`, \`end\` (integer days).

## Value

Data.frame with merged intervals (still integer days).
