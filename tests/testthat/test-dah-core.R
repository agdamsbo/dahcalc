library(testthat)
library(dahcalc)
library(lubridate)

# ---------------------------------------------------------------
# Helper -----------------------------------------------------------------
# Tiny synthetic data set used by many tests (base‑R only)
# ---------------------------------------------------------------
make_small_dt <- function(death = NA,
                          hosp_interval = NULL,
                          rehab_interval = NULL,
                          col_names = list(
                            patient_id       = "patient_id",
                            event_id         = "event_id",
                            event_type       = "event_type",
                            start_date       = "start_date",
                            end_date         = "end_date",
                            intervention_date = "intervention_date",
                            death_date       = "death_date")) {

  ## ----- sanity check – user must supply all canonical names -----
  required <- c("patient_id","event_id","event_type",
                "start_date","end_date","intervention_date","death_date")
  # if (!?setequal(names(col_names), required))
  #   stop("col_names must contain all canonical column names")

  ## ----- primary -------------------------------------------------
  primary <- data.frame(
    patient_id        = 1L,
    event_id          = 1L,
    event_type        = "primary",
    start_date        = as.Date("2023-01-01"),
    end_date          = as.Date("2023-01-05"),
    intervention_date = as.Date("2023-01-01"),
    death_date        = as.Date(death),
    stringsAsFactors  = FALSE
  )

  ## ----- optional hospital ---------------------------------------
  hosp <- NULL
  if (!is.null(hosp_interval)) {
    hosp <- data.frame(
      patient_id        = 1L,
      event_id          = 2L,
      event_type        = "hospital",
      start_date        = as.Date("2023-01-01") + hosp_interval[1],
      end_date          = as.Date("2023-01-01") + hosp_interval[2],
      intervention_date = as.Date(NA),
      death_date        = as.Date(NA),
      stringsAsFactors  = FALSE
    )
  }

  ## ----- optional rehabilitation ---------------------------------
  rehab <- NULL
  if (!is.null(rehab_interval)) {
    rehab <- data.frame(
      patient_id        = 1L,
      event_id          = if (is.null(hosp)) 2L else 3L,
      event_type        = "rehabilitation",
      start_date        = as.Date("2023-01-01") + rehab_interval[1],
      end_date          = as.Date("2023-01-01") + rehab_interval[2],
      intervention_date = as.Date(NA),
      death_date        = as.Date(NA),
      stringsAsFactors  = FALSE
    )
  }

  ## ----- separate death row (if we want it) ----------------------
  death_row <- NULL
  if (!is.na(death)) {
    max_id <- max(c(1L,
                    if (!is.null(hosp)) 2L else 0L,
                    if (!is.null(rehab)) 3L else 0L))
    death_row <- data.frame(
      patient_id        = 1L,
      event_id          = max_id + 1L,
      event_type        = "death",
      start_date        = as.Date(NA),
      end_date          = as.Date(NA),
      intervention_date = as.Date(NA),
      death_date        = as.Date(death),
      stringsAsFactors  = FALSE
    )
  }

  ## ----- combine rows -------------------------------------------------
  pieces <- list(primary, hosp, rehab, death_row)
  pieces <- pieces[!sapply(pieces, is.null)]
  dt <- do.call(rbind, pieces)

  ## ----- rename columns to the *user‑supplied* names (if they differ) -----
  # the columns are currently in the canonical order; replace their names
  canonical_order <- required
  names(dt) <- unlist(col_names[canonical_order])

  dt
}


# ---------------------------------------------------------------
# 1. validate_events()
# ---------------------------------------------------------------
test_that("fails when required columns are missing", {
  dt <- data.frame(a = 1:2, b = 2:3)   # does not contain required cols
  expect_error(validate_events(data = dt),
               "Missing required columns")
})


# ---------------------------------------------------------------
# 2. extract_primary()
# ---------------------------------------------------------------
test_that("returns one row per patient with correct dates", {
  dt <- make_small_dt(death = "2023-01-15")
  prim <- extract_primary(data = dt)
  expect_equal(nrow(prim), 1L)
  expect_equal(prim$intervention_date, as.Date("2023-01-01"))
  expect_equal(prim$death_date, as.Date("2023-01-15"))
})


# ---------------------------------------------------------------
# 3. extract_institutional()
# ---------------------------------------------------------------
test_that("extracts hospital and rehab intervals as integer days", {
  dt <- make_small_dt(
    hosp_interval = c(5, 9),
    rehab_interval = c(12, 15)
  )
  inst <- extract_institutional(data = dt)
  expect_equal(nrow(inst), 2L)
  expect_true(all(c("patient_id","start","end") %in% names(inst)))

  # conversion to integer days
  expect_equal(inst$start[1],
               as.integer(as.Date("2023-01-01") + 5))
  expect_equal(inst$end[1],
               as.integer(as.Date("2023-01-01") + 9))
})


# ---------------------------------------------------------------
# 4. merge_overlaps()
# ---------------------------------------------------------------
test_that("merges overlapping intervals correctly", {
  dt <- make_small_dt(
    hosp_interval = c(5, 12),
    rehab_interval = c(10, 18)
  )
  merged <- merge_overlaps(extract_institutional(data = dt))
  expect_equal(nrow(merged), 1L)
  expect_equal(merged$start,
               as.integer(as.Date("2023-01-01") + 5))
  expect_equal(merged$end,
               as.integer(as.Date("2023-01-01") + 18))
})

test_that("leaves non‑overlapping intervals untouched", {
  dt <- make_small_dt(
    hosp_interval = c(5, 9),
    rehab_interval = c(12, 15)
  )
  merged <- merge_overlaps(extract_institutional(data = dt))
  expect_equal(nrow(merged), 2L)
  expect_equal(merged$start[1],
               as.integer(as.Date("2023-01-01") + 5))
  expect_equal(merged$end[1],
               as.integer(as.Date("2023-01-01") + 9))
  expect_equal(merged$start[2],
               as.integer(as.Date("2023-01-01") + 12))
  expect_equal(merged$end[2],
               as.integer(as.Date("2023-01-01") + 15))
})


# ---------------------------------------------------------------
# 5. apply_window_and_death()
# ---------------------------------------------------------------
test_that("creates correct window columns and flag", {
  dt <- make_small_dt(death = "2023-01-20")
  primary <- extract_primary(data = dt)
  win <- apply_window_and_death(primary, window_days = 30L)
  expect_equal(win$window_start,
               as.integer(as.Date("2023-01-01")))
  expect_equal(win$window_end,
               as.integer(as.Date("2023-01-01")) + 29L)
  expect_true(win$died_in_window)
})

test_that("death before window is NOT flagged", {
  dt <- make_small_dt(death = "2022-12-30")
  primary <- extract_primary(data = dt)
  win <- apply_window_and_death(primary, window_days = 30L)
  expect_false(win$died_in_window)
})

test_that("death after window is NOT flagged", {
  dt <- make_small_dt(death = "2023-02-15")
  primary <- extract_primary(data = dt)
  win <- apply_window_and_death(primary, window_days = 30L)
  expect_false(win$died_in_window)
})

test_that("NA death stays FALSE", {
  dt <- make_small_dt(death = NA)
  primary <- extract_primary(data = dt)
  win <- apply_window_and_death(primary, window_days = 30L)
  expect_false(win$died_in_window)
})


# ---------------------------------------------------------------
# 6. count_institutional_days()
# ---------------------------------------------------------------
test_that("counts days correctly when interval fully inside window", {
  dt <- make_small_dt(hosp_interval = c(5, 12))  # 8 days inclusive
  primary <- extract_primary(data = dt)
  win <- apply_window_and_death(primary, window_days = 30L)
  inst <- merge_overlaps(extract_institutional(data = dt))
  cnt <- count_institutional_days(inst, win)
  expect_equal(cnt$institutional_days, 8L)
})

test_that("truncates intervals that exceed the window", {
  dt <- make_small_dt(hosp_interval = c(20, 40))  # exceeds 30‑day window
  primary <- extract_primary(data = dt)
  win <- apply_window_and_death(primary, window_days = 30L)
  inst <- merge_overlaps(extract_institutional(data = dt))
  cnt <- count_institutional_days(inst, win)
  # overlap = days 20‑29 inclusive = 10 days
  expect_equal(cnt$institutional_days, 10L)
})

test_that("returns 0 when no institutional stays intersect the window", {
  dt <- make_small_dt()   # no extra stays
  primary <- extract_primary(data = dt)
  win <- apply_window_and_death(primary, window_days = 30L)
  inst <- merge_overlaps(extract_institutional(data = dt))   # empty
  cnt <- count_institutional_days(inst, win)
  expect_equal(cnt$institutional_days, 0L)
})


# ---------------------------------------------------------------
# 7. compute_dah()
# ---------------------------------------------------------------
test_that("full DAH when no death and no institutional days", {
  primary <- extract_primary(make_small_dt())
  win <- apply_window_and_death(primary, window_days = 30L)
  cnt <- data.frame(patient_id = 1L, institutional_days = 0L,
                    stringsAsFactors = FALSE)
  res <- compute_dah(win, cnt, window_days = 30L)
  expect_equal(res$dah, 30L)
  expect_equal(res$effective_window, 30L)
  expect_false(res$died_in_window)
})

test_that("dah = 0 when died_in_window is TRUE", {
  dt <- make_small_dt(death = "2023-01-15")
  primary <- extract_primary(data = dt)
  win <- apply_window_and_death(primary, window_days = 30L)
  cnt <- data.frame(patient_id = 1L, institutional_days = 0L,
                    stringsAsFactors = FALSE)
  res <- compute_dah(win, cnt, window_days = 30L)
  expect_true(res$died_in_window)
  expect_equal(res$dah, 0L)
})

test_that("subtracts institutional days when alive", {
  primary <- extract_primary(make_small_dt())
  win <- apply_window_and_death(primary, window_days = 30L)
  cnt <- data.frame(patient_id = 1L, institutional_days = 8L,
                    stringsAsFactors = FALSE)
  res <- compute_dah(win, cnt, window_days = 30L)
  expect_equal(res$dah, 22L)   # 30 - 8
})


# ---------------------------------------------------------------
# 8. summarise_cohort()
# ---------------------------------------------------------------
test_that("calculates all summary statistics correctly", {
  per <- data.frame(
    patient_id        = 1:3,
    dah               = c(30L, 10L, 0L),
    effective_window = c(30L, 30L, 12L),
    institutional_days = c(0L, 20L, 0L),
    died_in_window   = c(FALSE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
  sumr <- summarise_cohort(per, window_days = 30L)

  expect_equal(sumr$n_patients, 3L)
  expect_equal(sumr$mean_dah,
               round(mean(c(30,10,0)),2))
  expect_equal(sumr$median_dah,
               median(c(30,10,0)))
  expect_equal(sumr$sd_dah,
               round(sd(c(30,10,0)),2))
  expect_equal(sumr$pct_full_home,
               round(100 * mean(c(30,10,0) == 30),1))

  total_pt_days <- sum(per$effective_window)
  total_dah     <- sum(per$dah)
  expect_equal(sumr$dah_per_100_pt_days,
               round(100 * total_dah / total_pt_days,2))
})


# ---------------------------------------------------------------
# 9. plot_dah_distribution()
# ---------------------------------------------------------------
test_that("returns a ggplot object with the correct layers", {
  per <- data.frame(
    patient_id = 1:5,
    dah        = c(30, 25, 10, 0, 15),
    died_in_window = c(FALSE, FALSE, FALSE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
  plt <- plot_dah_distribution(per, window_days = 30L)
  expect_true(inherits(plt, "ggplot"))
  layers <- sapply(plt$layers, function(l) class(l$geom)[1])
  expect_true("GeomBar" %in% layers)   # histogram
  vlines <- sapply(plt$layers, function(l) inherits(l$geom, "GeomVline"))
  expect_true(any(vlines))
})


# ---------------------------------------------------------------
# 10. run_dah_pipeline() – integration tests
# ---------------------------------------------------------------
test_that("returns correct result when death is inside the window", {
  dt <- make_small_dt(death = "2023-01-15")
  out <- run_dah_pipeline(
    data_long               = dt,
    window_days             = 30L,
    verbose                 = FALSE,
    keep_original_names     = FALSE
  )
  expect_true(out$per_patient$died_in_window)
  expect_equal(out$per_patient$dah, 0L)
})

test_that("returns full DAH when no death and no institutional stays", {
  dt <- make_small_dt()
  out <- run_dah_pipeline(data_long = dt,
                          window_days = 30L,
                          verbose = FALSE)
  expect_false(out$per_patient$died_in_window)
  expect_equal(out$per_patient$dah, 30L)
})

test_that("handles overlapping institutional stays correctly", {
  dt <- make_small_dt(
    hosp_interval  = c(5, 12),
    rehab_interval = c(10, 18)   # overlap
  )
  out <- run_dah_pipeline(data_long = dt,
                          window_days = 30L,
                          verbose = FALSE)
  # merged interval 5‑18 inclusive = 14 days
  expect_equal(out$per_patient$institutional_days, 14L)
  expect_equal(out$per_patient$dah, 16L)   # 30 - 14
})

test_that("column‑name mapping works with custom names", {
  custom_names <- list(
    patient_id       = "pid",
    event_id         = "eid",
    event_type       = "etype",
    start_date       = "adm_start",
    end_date         = "adm_end",
    intervention_date = "int_dt",
    death_date       = "dod"
  )
  dt <- make_small_dt(
    death = "2023-01-20",
    col_names = custom_names
  )
  out <- run_dah_pipeline(
    data_long               = dt,
    window_days             = 30L,
    verbose                 = FALSE,
    keep_original_names     = TRUE,
    patient_id_col          = custom_names$patient_id,
    event_id_col            = custom_names$event_id,
    event_type_col          = custom_names$event_type,
    start_date_col          = custom_names$start_date,
    end_date_col            = custom_names$end_date,
    intervention_date_col   = custom_names$intervention_date,
    death_date_col          = custom_names$death_date
  )
  expect_true("pid" %in% names(out$per_patient))
  expect_true(out$per_patient$died_in_window)
  expect_equal(out$per_patient$dah, 0L)
})
