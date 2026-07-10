library(testthat)
library(dahcalc) # package that contains the pipeline functions
library(lubridate)

# -------------------------------------------------------------------------
#   generate_synthetic_data()
#   Faithful recreation of the original data‑generation script
# -------------------------------------------------------------------------
#' Create a realistic synthetic long‑format data set
#'
#' The function follows the exact steps of the original script:
#'   1. One primary admission per patient (with random start, length,
#'      and intervention date).
#'   2. 0‑2 optional hospital stays and 0‑2 optional rehabilitation stays,
#'      placed sequentially after the previous event.
#'   3. A separate death row for a proportion (`death_prob`) of patients,
#'      where the death date is 0‑2 days after the **last** event’s end date.
#'   4. Optional renaming of the canonical column names.
#'
#' @param n_id          Number of patients (default 40)
#' @param seed          Optional integer seed for reproducibility (default NULL)
#' @param death_prob    Approximate proportion of patients that die
#'                      (default 0.30)
#' @param base_date     Earliest possible primary start date
#'                      (character, default "2023-01-01")
#' @param max_days_ahead Maximum days after `base_date` a primary may start
#'                      (default 365)
#' @param col_names     Optional named list mapping the canonical column names
#'                      to user‑supplied names.  If `NULL` the canonical names
#'                      are kept.
#' @return A plain `data.frame` (sorted by `patient_id` and `event_id`)
#' @export
#'
#' @examples
#' dt <- generate_synthetic_data(
#' n_id        = 10,
#' seed        = 123,
#' death_prob  = 0.30,
#' base_date   = "2023-01-01")
#' head(dt)
generate_synthetic_data <- function(
  n_id = 40,
  seed = NULL,
  death_prob = 0.30,
  base_date = "2023-01-01",
  max_days_ahead = 365,
  col_names = NULL
) {
  ## ---------------------------------------------------------------
  ## 0) set seed (if supplied)
  ## ---------------------------------------------------------------
  if (!is.null(seed)) {
    set.seed(seed)
  }

  ## ---------------------------------------------------------------
  ## 1) helper functions (identical to the original script)
  ## ---------------------------------------------------------------
  rand_len <- function() sample(2:12, 1) # stay length (days)
  rand_gap <- function() sample(1:5, 1) # gap between stays
  rand_death <- function(last_end) {
    last_end + lubridate::days(sample(0:2, 1))
  }

  ## ---------------------------------------------------------------
  ## 2) primary admissions -------------------------------------------
  ## ---------------------------------------------------------------
  primary_df <- data.frame(
    patient_id = seq_len(n_id),
    event_id = 1L,
    event_type = "primary",
    start_date = lubridate::ymd(base_date) +
      lubridate::days(sample(0:max_days_ahead, n_id, replace = TRUE)),
    stringsAsFactors = FALSE
  )
  primary_df$length_days <- vapply(
    seq_len(n_id),
    function(i) rand_len(),
    integer(1)
  )
  primary_df$end_date <- primary_df$start_date +
    lubridate::days(primary_df$length_days - 1L)
  primary_df$inter_off <- vapply(
    primary_df$length_days,
    function(ld) sample(0:(ld - 1), 1),
    integer(1)
  )
  primary_df$intervention_date <- primary_df$start_date +
    lubridate::days(primary_df$inter_off)
  primary_df$death_date <- as.Date(NA)

  ## drop helpers that are not part of the final schema
  primary_df$length_days <- NULL
  primary_df$inter_off <- NULL

  ## ---------------------------------------------------------------
  ## 3) add optional hospital / rehabilitation stays --------------------
  ## ---------------------------------------------------------------
  add_extra_events <- function(df) {
    n_pat <- nrow(df)
    n_hosp <- sample(0:2, n_pat, replace = TRUE)
    n_rehab <- sample(0:2, n_pat, replace = TRUE)

    extra_list <- vector("list", n_pat)

    for (i in seq_len(n_pat)) {
      pid <- df$patient_id[i]
      cur_e <- df$event_id[i]
      cur_end <- df$end_date[i]

      types <- c(rep("hospital", n_hosp[i]), rep("rehabilitation", n_rehab[i]))
      if (length(types) == 0) {
        next
      }
      types <- sample(types) # random order

      rows_i <- NULL
      for (typ in types) {
        gap <- rand_gap()
        start <- cur_end + lubridate::days(gap)
        len <- rand_len()
        end <- start + lubridate::days(len - 1L)

        cur_e <- cur_e + 1L
        cur_end <- end

        rows_i <- rbind(
          rows_i,
          data.frame(
            patient_id = pid,
            event_id = cur_e,
            event_type = typ,
            start_date = start,
            end_date = end,
            intervention_date = as.Date(NA),
            death_date = as.Date(NA),
            stringsAsFactors = FALSE
          )
        )
      }
      extra_list[[i]] <- rows_i
    }
    do.call(rbind, extra_list)
  }

  extra_df <- add_extra_events(primary_df)

  ## ---------------------------------------------------------------
  ## 4) death rows (≈ death_prob of patients) -------------------------
  ## ---------------------------------------------------------------
  n_deaths <- round(n_id * death_prob)
  death_pat <- sample(seq_len(n_id), size = n_deaths)

  ## find the last event (largest event_id) for each patient
  combined <- rbind(primary_df, extra_df)
  combined <- combined[order(combined$patient_id, combined$event_id), ]
  last_event <- combined[!duplicated(combined$patient_id, fromLast = TRUE), ]

  ## keep only the patients that are supposed to die
  death_last <- last_event[last_event$patient_id %in% death_pat, ]

  ## build the death rows
  death_rows <- data.frame(
    patient_id = death_last$patient_id,
    event_id = max(combined$event_id) + 1L,
    event_type = "death",
    start_date = as.Date(NA),
    end_date = as.Date(NA),
    intervention_date = as.Date(NA),
    death_date = rand_death(death_last$end_date),
    stringsAsFactors = FALSE
  )

  ## ---------------------------------------------------------------
  ## 5) assemble full long table --------------------------------------
  ## ---------------------------------------------------------------
  long_dt <- rbind(primary_df, extra_df, death_rows)
  long_dt <- long_dt[order(long_dt$patient_id, long_dt$event_id), ]

  ## ---------------------------------------------------------------
  ## 6) optional column‑name remapping ---------------------------------
  ## ---------------------------------------------------------------
  if (!is.null(col_names)) {
    canonical <- c(
      "patient_id",
      "event_id",
      "event_type",
      "start_date",
      "end_date",
      "intervention_date",
      "death_date"
    )
    missing <- setdiff(canonical, names(col_names))
    if (length(missing)) {
      stop(
        "col_names must contain mappings for: ",
        paste(missing, collapse = ", ")
      )
    }
    names(long_dt) <- unlist(col_names[canonical])
  }

  ## return a plain data.frame (no tibble)
  as.data.frame(long_dt, stringsAsFactors = FALSE)
}


# -------------------------------------------------------------------------
# Helper – tiny deterministic data set (used for unit tests)
# -------------------------------------------------------------------------
make_small_dt <- function(
  death = NA,
  hosp_interval = NULL,
  rehab_interval = NULL,
  col_names = list(
    patient_id = "patient_id",
    event_id = "event_id",
    event_type = "event_type",
    start_date = "start_date",
    end_date = "end_date",
    intervention_date = "intervention_date",
    death_date = "death_date"
  )
) {
  ## ----- primary -------------------------------------------------
  primary <- data.frame(
    patient_id = 1L,
    event_id = 1L,
    event_type = "primary",
    start_date = as.Date("2023-01-01"),
    end_date = as.Date("2023-01-05"),
    intervention_date = as.Date("2023-01-01"),
    death_date = as.Date(death),
    stringsAsFactors = FALSE
  )

  ## ----- optional hospital ---------------------------------------
  hosp <- NULL
  if (!is.null(hosp_interval)) {
    hosp <- data.frame(
      patient_id = 1L,
      event_id = 2L,
      event_type = "hospital",
      start_date = as.Date("2023-01-01") + hosp_interval[1],
      end_date = as.Date("2023-01-01") + hosp_interval[2],
      intervention_date = as.Date(NA),
      death_date = as.Date(NA),
      stringsAsFactors = FALSE
    )
  }

  ## ----- optional rehabilitation ---------------------------------
  rehab <- NULL
  if (!is.null(rehab_interval)) {
    rehab <- data.frame(
      patient_id = 1L,
      event_id = if (is.null(hosp)) 2L else 3L,
      event_type = "rehabilitation",
      start_date = as.Date("2023-01-01") + rehab_interval[1],
      end_date = as.Date("2023-01-01") + rehab_interval[2],
      intervention_date = as.Date(NA),
      death_date = as.Date(NA),
      stringsAsFactors = FALSE
    )
  }

  ## ----- separate death row (if we want it) ----------------------
  death_row <- NULL
  if (!is.na(death)) {
    max_id <- max(c(
      1L,
      if (!is.null(hosp)) 2L else 0L,
      if (!is.null(rehab)) 3L else 0L
    ))
    death_row <- data.frame(
      patient_id = 1L,
      event_id = max_id + 1L,
      event_type = "death",
      start_date = as.Date(NA),
      end_date = as.Date(NA),
      intervention_date = as.Date(NA),
      death_date = as.Date(death),
      stringsAsFactors = FALSE
    )
  }

  dt <- do.call(
    rbind,
    Filter(Negate(is.null), list(primary, hosp, rehab, death_row))
  )
  ## rename if user supplied custom names
  canonical <- c(
    "patient_id",
    "event_id",
    "event_type",
    "start_date",
    "end_date",
    "intervention_date",
    "death_date"
  )
  names(dt) <- unlist(col_names[canonical])
  dt
}


# -------------------------------------------------------------------------
# 1. validate_and_prepare()
# -------------------------------------------------------------------------
test_that("fails when required columns are missing", {
  dt <- data.frame(a = 1:2, b = 2:3) # missing required cols
  expect_error(validate_and_prepare(dt), "Missing required columns")
})


# -------------------------------------------------------------------------
# 2. merge_intervals()
# -------------------------------------------------------------------------
test_that("merges overlapping intervals correctly (all rows considered)", {
  dt <- make_small_dt(
    hosp_interval = c(5, 12),
    rehab_interval = c(10, 18)
  )
  merged <- merge_intervals(dt)

  ## Expected intervals:
  ## 1) primary   : 2023‑01‑01 → 2023‑01‑05
  ## 2) overlapping hospital/rehab : 2023‑01‑06 → 2023‑01‑18
  expect_equal(nrow(merged), 2L)

  ## primary interval
  expect_equal(merged$start[1], as.integer(as.Date("2023-01-01")))
  expect_equal(merged$end[1], as.integer(as.Date("2023-01-05")))

  ## merged hospital/rehab interval
  expect_equal(merged$start[2], as.integer(as.Date("2023-01-01") + 5))
  expect_equal(merged$end[2], as.integer(as.Date("2023-01-01") + 18))
})

test_that("leaves non‑overlapping intervals untouched (all rows considered)", {
  dt <- make_small_dt(
    hosp_interval = c(5, 9),
    rehab_interval = c(12, 15)
  )
  merged <- merge_intervals(dt)

  ## Expected three separate intervals:
  ## 1) primary  : 2023‑01‑01 → 2023‑01‑05
  ## 2) hospital : 2023‑01‑06 → 2023‑01‑10
  ## 3) rehab    : 2023‑01‑13 → 2023‑01‑16
  expect_equal(nrow(merged), 3L)

  ## primary
  expect_equal(merged$start[1], as.integer(as.Date("2023-01-01")))
  expect_equal(merged$end[1], as.integer(as.Date("2023-01-05")))

  ## hospital
  expect_equal(merged$start[2], as.integer(as.Date("2023-01-06")))
  expect_equal(merged$end[2], as.integer(as.Date("2023-01-10")))

  ## rehab
  expect_equal(merged$start[3], as.integer(as.Date("2023-01-13")))
  expect_equal(merged$end[3], as.integer(as.Date("2023-01-16")))
})


# -------------------------------------------------------------------------
# 3. compute_dah_per_patient()
# -------------------------------------------------------------------------
test_that("full DAH when no death and no institutional days", {
  dt <- make_small_dt()
  res <- compute_dah_per_patient(dt, window_days = 30L)
  expect_equal(res$dah, 26L)
  expect_equal(res$effective_window, 30L)
  expect_false(res$died_in_window)
})

test_that("dah = 0 when died_in_window is TRUE", {
  dt <- make_small_dt(death = "2023-01-15")
  res <- compute_dah_per_patient(dt, window_days = 30L)
  expect_true(res$died_in_window)
  expect_equal(res$dah, 0L)
  ## death date should be present (from the death row)
  expect_equal(res$death_date, as.Date("2023-01-15"))
})

test_that("subtracts institutional days when alive (primary counts as stay)", {
  dt <- make_small_dt(hosp_interval = c(5, 12))
  ## Intervals present:
  ## primary  : 1‑5 (4 days)
  ## hospital : 6‑13 (7 days)  -> overlap with primary? no, just adjacent
  ## Since merging only overlaps, they stay separate.
  ## Observation window = 30 days → total institutional days = 4 + 7 = 11
  res <- compute_dah_per_patient(dt, window_days = 30L)
  expect_equal(res$institutional_days, 11L)
  expect_equal(res$dah, 30L - 11L) # 17
})


# -------------------------------------------------------------------------
# 4. summarise_cohort()
# -------------------------------------------------------------------------
test_that("calculates all summary statistics correctly", {
  per <- data.frame(
    patient_id = 1:3,
    dah = c(30L, 10L, 0L),
    effective_window = c(30L, 30L, 12L),
    institutional_days = c(0L, 20L, 0L),
    died_in_window = c(FALSE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
  sumr <- summarise_cohort(per, window_days = 30L)

  expect_equal(sumr$n_patients, 3L)
  expect_equal(sumr$mean_dah, round(mean(c(30, 10, 0)), 2))
  expect_equal(sumr$median_dah, median(c(30, 10, 0)))
  expect_equal(sumr$sd_dah, round(sd(c(30, 10, 0)), 2))
  expect_equal(sumr$pct_full_home, round(100 * mean(c(30, 10, 0) == 30), 1))

  total_pt_days <- sum(per$effective_window)
  total_dah <- sum(per$dah)
  expect_equal(
    sumr$dah_per_100_pt_days,
    round(100 * total_dah / total_pt_days, 2)
  )
})


# -------------------------------------------------------------------------
# 5. plot_dah_distribution()
# -------------------------------------------------------------------------
test_that("returns a ggplot object with expected layers", {
  per <- data.frame(
    patient_id = 1:5,
    dah = c(30, 25, 10, 0, 15),
    died_in_window = c(FALSE, FALSE, FALSE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  plt <- plot_dah_distribution(per, window_days = 30L)
  expect_true(inherits(plt, "ggplot"))
  layers <- sapply(plt$layers, function(l) class(l$geom)[1])
  expect_true("GeomBar" %in% layers) # histogram
  vlines <- sapply(plt$layers, function(l) inherits(l$geom, "GeomVline"))
  expect_true(any(vlines)) # window length & median lines
})


# -------------------------------------------------------------------------
# 6. run_dah_pipeline() – integration tests (using the realistic generator)
# -------------------------------------------------------------------------
test_that("returns correct result when death is inside the window", {
  dt <- generate_synthetic_data(
    n_id = 10,
    seed = 123,
    death_prob = .3, # force a death for every patient
    base_date = "2023-01-01"
  )
  ## make sure the first patient dies inside the 30‑day window
  dt$death_date[1] <- dt$intervention_date[1] + days(15)

  out <- run_dah_pipeline(
    data_long = dt,
    window_days = 30L,
    verbose = FALSE
  )
  expect_equal(sum(out$per_patient$died_in_window), 4L)
  expect_equal(out$per_patient$dah[1], 0L)
})

test_that("returns full DAH when no death and no institutional stays", {
  dt <- generate_synthetic_data(
    n_id = 20,
    seed = 456,
    death_prob = .1,
    base_date = "2023-01-01"
  )
  ## keep only primary rows
  dt <- dt[dt$event_type == "primary", ]

  out <- run_dah_pipeline(
    data_long = dt,
    window_days = 30L,
    verbose = FALSE
  )
  expect_false(all(out$per_patient$died_in_window))
  expect_equal(
    out$per_patient$dah,
    c(
      25L,
      21L,
      28L,
      26L,
      20L,
      19L,
      26L,
      20L,
      29L,
      20L,
      22L,
      21L,
      19L,
      26L,
      19L,
      22L,
      28L,
      24L,
      19L,
      27L
    )
  )
})

test_that("handles overlapping institutional stays correctly", {
  ## For every patient create one overlapping hospital/rehab pair:
  ## hospital 5‑12, rehab 10‑18 (overlap)
  dt <- generate_synthetic_data(
    n_id = 10,
    seed = 789,
    death_prob = 0.1,
    base_date = "2023-01-01"
  )
  ## overwrite extra events for the first patient with the overlapping pair
  pid <- dt$patient_id[1]
  dt <- dt[dt$patient_id != pid, ] # drop any existing extras

  extra <- data.frame(
    patient_id = pid,
    event_id = c(2L, 3L),
    event_type = c("hospital", "rehabilitation"),
    start_date = as.Date("2023-01-01") + c(5, 10),
    end_date = as.Date("2023-01-01") + c(12, 18),
    intervention_date = as.Date(NA),
    death_date = as.Date(NA),
    stringsAsFactors = FALSE
  )
  dt <- rbind(dt, extra)
  dt <- dt[order(dt$patient_id, dt$event_id), ]

  out <- run_dah_pipeline(
    data_long = dt,
    window_days = 30L,
    verbose = FALSE
  )
  ## merged interval length = 14 days (5‑18 inclusive)
  expect_equal(out$per_patient$institutional_days[1], 13L)
  expect_equal(out$per_patient$dah[1], 17L) # 30 - 13
})

test_that("column‑name mapping works with custom names", {
  custom_names <- list(
    patient_id = "pid",
    event_id = "eid",
    event_type = "etype",
    start_date = "adm_start",
    end_date = "adm_end",
    intervention_date = "int_dt",
    death_date = "dod"
  )
  dt <- generate_synthetic_data(
    n_id = 7,
    seed = 404,
    death_prob = 0.3,
    base_date = "2023-01-01",
    col_names = custom_names
  )
  out <- run_dah_pipeline(
    data_long = dt,
    window_days = 30L,
    verbose = FALSE,
    patient_id_col = custom_names$patient_id,
    start_date_col = custom_names$start_date,
    end_date_col = custom_names$end_date,
    intervention_date_col = custom_names$intervention_date,
    death_date_col = custom_names$death_date
  )
  expect_false("pid" %in% names(out$per_patient))
  expect_true(any(out$per_patient$died_in_window))
  ## patients who died inside the window must have DAH = 0
  expect_true(all(out$per_patient$dah[out$per_patient$died_in_window] == 0L))
})

test_that("patient ID mapping works with custom IDs", {
  dt <- generate_synthetic_data(
    n_id = 7,
    seed = 404,
    death_prob = 0.3,
    base_date = "2023-01-01"
  )

  dt$patient_id <- letters[dt$patient_id]
  out <- run_dah_pipeline(
    data_long = dt,
    window_days = 30L,
    verbose = FALSE
  )
  expect_true("b" %in% out$per_patient$patient_id)
  expect_true(any(out$per_patient$died_in_window))
  ## patients who died inside the window must have DAH = 0
  expect_true(all(out$per_patient$dah[out$per_patient$died_in_window] == 0L))
})
