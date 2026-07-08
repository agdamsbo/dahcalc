## code to prepare `synthetic_data` dataset

library(purrr)
library(dplyr)

set.seed(2026)

rand_len  <- function() sample(2:12, 1)
rand_gap  <- function() sample(1:5, 1)
rand_death<- function(last_end){
  last_end + days(sample(0:2,1))
}

n_id <- 40

# Primary admission -------------------------------------------------
primary_df <- tibble(
  patient_id = 1:n_id,
  event_id   = 1L,
  event_type = "primary"
) |> mutate(
  start_date = ymd("2023-01-01") + days(sample(0:365,n_id,replace=TRUE)),
  length_days = map_int(1:n_id, ~rand_len()),
  end_date   = start_date + days(length_days-1),
  inter_off  = purrr::map_int(length_days, ~sample(0:(.x-1),1)),
  intervention_date = start_date + days(inter_off),
  death_date = as.Date(NA)
) |> select(-length_days, -inter_off)

# Additional hospital/rehab stays -----------------------------------
add_extra_events <- function(df){
  n_pat <- nrow(df)
  n_hosp  <- sample(0:2, n_pat, replace = TRUE)
  n_rehab <- sample(0:2, n_pat, replace = TRUE)

  extra <- vector("list", n_pat)
  for(i in seq_len(n_pat)){
    pid   <- df$patient_id[i]
    cur_e <- df$event_id[i]
    cur_end <- df$end_date[i]

    types <- c(rep("hospital", n_hosp[i]),
               rep("rehabilitation", n_rehab[i]))
    if(length(types)==0) next
    types <- sample(types)

    for(typ in types){
      gap   <- rand_gap()
      start <- cur_end + days(gap)
      len   <- rand_len()
      end   <- start + days(len-1)

      cur_e <- cur_e + 1L
      extra[[i]] <- dplyr::bind_rows(list(extra[[i]],
                                   data.frame(patient_id = pid,
                                              event_id   = cur_e,
                                              event_type = typ,
                                              start_date = start,
                                              end_date   = end,
                                              intervention_date = as.Date(NA),
                                              death_date = as.Date(NA))))
      cur_end <- end
    }
  }
  dplyr::bind_rows(extra)
}
extra_df <- add_extra_events(primary_df)

# Death rows (≈30% die) --------------------------------------------
death_pat <- sample(1:n_id, size = round(n_id*0.30))
death_rows <- tibble(patient_id = death_pat) |>
  left_join(
    bind_rows(primary_df, extra_df) |>
      group_by(patient_id)  |>
      slice_max(event_id, with_ties = FALSE) |>
      ungroup(),
    by = "patient_id") |>
  mutate(
    event_id   = max(event_id) + 1L,
    event_type = "death",
    start_date = as.Date(NA),
    intervention_date = as.Date(NA),
    death_date = rand_death(end_date),
    end_date   = as.Date(NA)
  ) |>
  select(names(primary_df))

# Assemble full long table -----------------------------------------
long_dt <- dplyr::bind_rows(list(
  primary_df,
  extra_df,
  death_rows
))

setorder(long_dt, patient_id, event_id)

synthetic_data <- long_dt


usethis::use_data(synthetic_data, overwrite = TRUE)
