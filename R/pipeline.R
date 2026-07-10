# =============================================================================
#   dahR – simplified, universal Days‑At‑Home pipeline (final version)
#   Author: <your name>
#   License: GPL‑3
# =============================================================================

# -------------------------------------------------------------------------
# Helper: coerce any object to Date (handles Date, POSIXct, character)
# -------------------------------------------------------------------------
.coerce_to_date <- function(x) {
  if (inherits(x, "Date"))      return(x)
  if (inherits(x, "POSIXt"))    return(as.Date(x))
  as.Date(x)                    # try character → Date
}

# Helper: integer (days since 1970‑01‑01) → Date
.int_to_date <- function(x) as.Date(x, origin = "1970-01-01")


# -------------------------------------------------------------------------
#' Validate input and coerce date columns
#'
#' Ensures required columns exist, adds optional columns if missing,
#' coerces all date columns to `Date`, and checks that `start_date`
#' never exceeds `end_date`.
#'
#' @param data A `data.frame` (or object coercible to one) containing the raw records.
#' @param patient_id_col Column name for patient identifier (default `"patient_id"`).
#' @param start_date_col Column name for start date (default `"start_date"`).
#' @param end_date_col Column name for end date (default `"end_date"`).
#' @param intervention_date_col Column name for the index/intervention date
#'   (default `"intervention_date"`).  If the column is absent it will be created
#'   and filled with `NA`.
#' @param death_date_col Column name for death date (default `"death_date"`).
#'   If the column is absent it will be created and filled with `NA`.
#'
#' @return A cleaned `data.frame` where all date columns are genuine `Date`
#'   objects and `start_date <= end_date` holds for every row.
#' @export
validate_and_prepare <- function(data,
                                 patient_id_col      = "patient_id",
                                 start_date_col      = "start_date",
                                 end_date_col        = "end_date",
                                 intervention_date_col = "intervention_date",
                                 death_date_col      = "death_date") {

  data <- as.data.frame(data, stringsAsFactors = FALSE)

  ## ----- required columns -------------------------------------------------
  req <- c(patient_id_col, start_date_col, end_date_col)
  miss <- setdiff(req, names(data))
  if (length(miss))
    stop("Missing required columns: ", paste(miss, collapse = ", "))

  ## ----- optional columns -------------------------------------------------
  if (!intervention_date_col %in% names(data))
    data[[intervention_date_col]] <- NA
  if (!death_date_col %in% names(data))
    data[[death_date_col]] <- NA

  ## ----- coerce to Date --------------------------------------------------
  for (c in c(start_date_col, end_date_col,
              intervention_date_col, death_date_col)) {
    data[[c]] <- .coerce_to_date(data[[c]])
  }

  ## ----- sanity check: start ≤ end ---------------------------------------
  bad <- !is.na(data[[start_date_col]]) &
    !is.na(data[[end_date_col]]) &
    data[[start_date_col]] > data[[end_date_col]]
  if (any(bad))
    stop("Rows found with start_date > end_date")

  data
}

# -------------------------------------------------------------------------
#' Merge overlapping intervals (all rows with a start_date are used)
#'
#' Intervals are merged **only when they truly overlap**
#' (`new_start <= current_end`).  Touching intervals (e.g. one ends on
#' day 5 and the next starts on day 6) are left separate.
#'
#' @param df A `data.frame` that must contain the columns `patient_id`,
#'   `start_date`, `end_date`.  `end_date` may be `NA` (open‑ended interval).
#' @return A `data.frame` with columns `patient_id`, `start`, `end`
#'   (both integer days since 1970‑01‑01).  One row per merged interval.
#' @export
merge_intervals <- function(df,
                            patient_id_col      = "patient_id",
                            start_date_col      = "start_date",
                            end_date_col        = "end_date") {

  ## ---- keep only rows that actually have a start date -----------------
  intv <- df[!is.na(df[[start_date_col]]), , drop = FALSE]

  if (nrow(intv) == 0L) {
    return(data.frame(
      patient_id = integer(),
      start      = integer(),
      end        = integer(),
      stringsAsFactors = FALSE
    ))
  }

  ## ---- convert dates to integer days ----------------------------------
  intv <- data.frame(
    patient_id = intv[[patient_id_col]],
    start      = as.integer(intv[[start_date_col]]),
    end        = as.integer(intv[[end_date_col]]),   # NA allowed (open‑ended)
    stringsAsFactors = FALSE
  )

  ## ---- sort -----------------------------------------------------------
  intv <- intv[order(intv$patient_id, intv$start), ]

  ## ---- treat missing ends as a far‑future integer for merging ----------
  intv$end[is.na(intv$end)] <- .Machine$integer.max

  ## ---- merge overlapping intervals only -------------------------------
  merged_list <- lapply(split(intv, intv$patient_id), function(d) {
    cur_start <- d$start[1]
    cur_end   <- d$end[1]
    out_start <- integer()
    out_end   <- integer()

    if (nrow(d) == 1) {
      out_start <- cur_start
      out_end   <- cur_end
    } else {
      for (i in 2:nrow(d)) {
        ## overlap only when new start ≤ current end
        if (d$start[i] <= cur_end) {
          cur_end <- max(cur_end, d$end[i])
        } else {
          out_start <- c(out_start, cur_start)
          out_end   <- c(out_end,   cur_end)
          cur_start <- d$start[i]
          cur_end   <- d$end[i]
        }
      }
      out_start <- c(out_start, cur_start)
      out_end   <- c(out_end,   cur_end)
    }

    data.frame(
      patient_id = d$patient_id[1],
      start      = out_start,
      end        = out_end,
      stringsAsFactors = FALSE
    )
  })

  merged <- do.call(rbind, merged_list)
  rownames(merged) <- NULL
  merged
}

# -------------------------------------------------------------------------
#' Compute Days‑At‑Home for each patient (early exit for deaths)
#'
#' All rows with a non‑`NA` `start_date` are treated as admission intervals.
#' Overlapping intervals are merged (see `merge_intervals`).  If a patient
#' dies inside the observation window the function returns `dah = 0` and
#' `institutional_days = 0` without performing interval counting.
#'
#' @param data_clean Output of `validate_and_prepare()`.
#' @param window_days Length of the observation window (default = 30 days).
#' @param patient_id_col Column name for patient identifier (default `"patient_id"`).
#' @param start_date_col Column name for admission start date (default `"start_date"`).
#' @param end_date_col Column name for admission end date (default `"end_date"`).
#' @param intervention_date_col Column name for the index/intervention date
#'   (default `"intervention_date"`).
#' @param death_date_col Column name for death date (default `"death_date"`).
#'
#' @return A `data.frame` (one row per patient) with columns
#'   `patient_id`, `index_date` (Date), `death_date` (Date or NA),
#'   `dah`, `institutional_days`, `effective_window` (always = `window_days`),
#'   `died_in_window` (logical).
#' @export
compute_dah_per_patient <- function(data_clean,
                                    window_days = 30L,
                                    patient_id_col      = "patient_id",
                                    start_date_col      = "start_date",
                                    end_date_col        = "end_date",
                                    intervention_date_col = "intervention_date",
                                    death_date_col      = "death_date") {

  ## ---------------------------------------------------------------
  ## 1) Determine the index (anchor) date for each patient
  ## ---------------------------------------------------------------
  first_start <- aggregate(data_clean[[start_date_col]],
                           by = list(pid = data_clean[[patient_id_col]]),
                           FUN = min, na.rm = TRUE)
  names(first_start)[2] <- "first_start"

  ## Replace missing intervention dates with the first start date of that patient
  idx_date <- data_clean[[intervention_date_col]]
  na_idx  <- is.na(idx_date)
  if (any(na_idx)) {
    idx_date[na_idx] <- first_start$first_start[match(
      data_clean[[patient_id_col]][na_idx], first_start$pid)]
  }
  data_clean[[intervention_date_col]] <- idx_date

  ## ---------------------------------------------------------------
  ## 2) Observation window per patient
  ## ---------------------------------------------------------------
  patient_ids <- unique(data_clean[[patient_id_col]])

  window_df <- data.frame(
    patient_id = patient_ids,
    index_date = as.integer(
      data_clean[[intervention_date_col]][match(patient_ids,
                                                data_clean[[patient_id_col]])]
    ),
    stringsAsFactors = FALSE
  )
  window_df$window_start <- window_df$index_date
  window_df$window_end   <- window_df$index_date + window_days - 1L

  ## ---------------------------------------------------------------
  ## 3) Extract death dates (first non‑NA per patient)
  ## ---------------------------------------------------------------
  death_vec_raw <- tapply(data_clean[[death_date_col]],
                          data_clean[[patient_id_col]],
                          function(x) {
                            nd <- x[!is.na(x)]
                            if (length(nd) == 0) NA else min(nd)
                          })
  death_vec <- as.Date(death_vec_raw[as.character(patient_ids)],
                       origin = "1970-01-01")

  ## ---------------------------------------------------------------
  ## 4) Identify patients who die inside the window
  ## ---------------------------------------------------------------
  died_in_window <- !is.na(death_vec) &
    as.integer(death_vec) >= window_df$window_start &
    as.integer(death_vec) <= window_df$window_end

  ## Initialise result vectors
  dah       <- integer(length(patient_ids))
  inst_days <- integer(length(patient_ids))

  ## ---------------------------------------------------------------
  ## 5) Early‑exit for patients who die inside the window
  ## ---------------------------------------------------------------
  dah[died_in_window]       <- 0L
  inst_days[died_in_window] <- 0L

  ## ---------------------------------------------------------------
  ## 6) Process only patients who are alive (or die after the window)
  ## ---------------------------------------------------------------
  alive_idx <- which(!died_in_window)
  if (length(alive_idx) > 0) {

    ## 6a) Merge overlapping intervals (all rows with a start_date)
    merged_int <- merge_intervals(data_clean,
                                  patient_id_col=patient_id_col,
                                  start_date_col=start_date_col,
                                  end_date_col=end_date_col)

    ## 6b) Count institutional days per alive patient
    merged_int$diff <- merged_int$end-merged_int$start

    inst_days <- split(merged_int,merged_int$patient_id) |> lapply(\(.x){
      sum(.x$diff)
    }) |> unlist()

    ## 6c) Compute DAH for alive patients
    dah[alive_idx] <- pmax(0L, window_days - inst_days[alive_idx])
  }

  ## ---------------------------------------------------------------
  ## 7) Assemble final per‑patient table
  ## ---------------------------------------------------------------
  out <- data.frame(
    patient_id        = patient_ids,
    index_date        = .int_to_date(window_df$index_date),
    death_date        = death_vec,
    dah               = dah,
    institutional_days = inst_days,
    effective_window   = window_days,
    died_in_window     = died_in_window,
    stringsAsFactors = FALSE
  )
  out
}

# -------------------------------------------------------------------------
#' Summarise DAH at the cohort level
#'
#' Provides descriptive statistics for a cohort, including the number of
#' deaths that occurred inside the observation window.
#'
#' @param per_pat Data.frame returned by `compute_dah_per_patient()`.
#' @param window_days Length of the observation window (default = 30).
#'
#' @return A one‑row data.frame with summary statistics:
#'   `window_days`, `n_patients`, `n_deaths`, mean/median/SD,
#'   inter‑quartile range, proportion with full home days,
#'   mean effective window, and DAH per 100 patient‑days.
#' @importFrom stats median quantile sd
#' @export
summarise_cohort <- function(per_pat, window_days = 30L) {
  n_deaths <- sum(!is.na(per_pat$death_date) &
                    per_pat$dah == 0, na.rm = TRUE)

  total_pt_days <- sum(per_pat$effective_window)
  total_dah     <- sum(per_pat$dah)

  data.frame(
    window_days                = window_days,
    n_patients                 = nrow(per_pat),
    n_deaths                   = n_deaths,
    mean_dah                   = round(mean(per_pat$dah), 2),
    median_dah                 = median(per_pat$dah),
    sd_dah                     = round(sd(per_pat$dah), 2),
    q25_dah                    = quantile(per_pat$dah, 0.25),
    q75_dah                    = quantile(per_pat$dah, 0.75),
    pct_full_home              = round(100 * mean(per_pat$dah == window_days), 1),
    mean_effective_window_days = round(mean(per_pat$effective_window), 2),
    dah_per_100_pt_days        = round(100 * total_dah / total_pt_days, 2),
    stringsAsFactors = FALSE
  )
}

# -------------------------------------------------------------------------
#' Plot the distribution of Days‑At‑Home
#'
#' A histogram where bars are coloured by death‑in‑window status, with a
#' vertical line for the window length and another for the median DAH.
#' The y‑axis shows only whole numbers.
#'
#' @param per_pat Data.frame produced by `compute_dah_per_patient()`.
#' @param window_days Observation window length (default = 30).
#' @return A **ggplot2** object.
#' @import ggplot2
#' @export
plot_dah_distribution <- function(per_pat, window_days = 30L) {

  ## annotation string ---------------------------------------------------
  n_pat   <- nrow(per_pat)
  n_dead  <- sum(per_pat$died_in_window, na.rm = TRUE)
  pct_dead <- round(100 * n_dead / n_pat, 1)

  mean_dah   <- round(mean(per_pat$dah), 2)
  median_dah <- median(per_pat$dah)

  annotation_txt <- sprintf(
    "n = %d patients\nDeaths = %d (%.1f%%)\nMean DAH = %0.1f\nMedian DAH = %0.1f",
    n_pat, n_dead, pct_dead, mean_dah, median_dah
  )

  ggplot(per_pat, aes(x = dah, fill = died_in_window)) +
    geom_histogram(binwidth = 1,
                   colour = "black",
                   boundary = -0.5) +
    scale_fill_manual(
      values = c("FALSE" = "#4C72B0", "TRUE" = "#C44E52"),
      name   = "Died inside window"
    ) +
    ## window length line ------------------------------------------------
  geom_vline(xintercept = window_days,
             linetype = "dashed", colour = "darkgray") +
    ## median DAH line ----------------------------------------------------
  geom_vline(xintercept = median_dah,
             linetype = "solid", colour = "steelblue") +
    ## y‑axis: whole numbers only ----------------------------------------
  scale_y_continuous(
    breaks = function(lims) {
      max_cnt <- ceiling(lims[2])
      seq(0, max_cnt, by = 1)
    },
    expand = expansion(mult = c(0, 0.05))
  ) +
    labs(
      title    = paste0("Distribution of Days At Home (",
                        window_days,
                        "-day window)"),
      subtitle = "Bars coloured by death‑in‑window status; median DAH shown",
      x        = "Days At Home",
      y        = "Number of patients"
    ) +
    annotate(
      "text", x = Inf, y = Inf,
      label = annotation_txt,
      hjust = 1.1, vjust = 1.1,
      size  = 3.5,
      colour = "black",
      fontface = "plain",
      family = "sans"
    ) +
    theme_minimal() +
    theme(legend.position = "top",
          plot.subtitle   = element_text(face = "italic"))
}

# -------------------------------------------------------------------------
#' Run the complete DAH pipeline
#'
#' Accepts any long‑format data that contains at least `patient_id`,
#' `start_date`, and `end_date`.  Optional columns are `intervention_date`
#' (the anchor for the observation window) and `death_date`.  No event‑type
#' handling is performed; every row with a non‑`NA` `start_date` is treated
#' as an admission interval.
#'
#' @param data_long Raw long‑format data (`data.frame` or `data.table`).
#' @param window_days Length of the observation window (default = 30 days).
#' @param patient_id_col Column name for patient identifier (default `"patient_id"`).
#' @param start_date_col Column name for admission start date (default `"start_date"`).
#' @param end_date_col Column name for admission end date (default `"end_date"`).
#' @param intervention_date_col Column name for the index/intervention date
#'   (default `"intervention_date"`).
#' @param death_date_col Column name for death date (default `"death_date"`).
#' @param verbose Logical; retained for compatibility (no console output).
#'
#' @return A list with three components:\n
#'   `per_patient` – per‑patient DAH table (date columns are `Date`),\n
#'   `cohort_summary` – cohort‑level statistics,\n
#'   `plot` – histogram of DAH values.
#' @export
run_dah_pipeline <- function(
    data_long,
    window_days = 30L,

    patient_id_col      = "patient_id",
    start_date_col      = "start_date",
    end_date_col        = "end_date",
    intervention_date_col = "intervention_date",
    death_date_col      = "death_date",

    verbose            = TRUE   # kept for compatibility; no output
) {

  ## 1) Validate and coerce -------------------------------------------------
  clean_data <- validate_and_prepare(
    data_long,
    patient_id_col      = patient_id_col,
    start_date_col      = start_date_col,
    end_date_col        = end_date_col,
    intervention_date_col = intervention_date_col,
    death_date_col      = death_date_col
  )

  ## 2) Compute per‑patient DAH --------------------------------------------
  per_pat <- compute_dah_per_patient(
    clean_data,
    window_days = window_days,
    patient_id_col      = patient_id_col,
    start_date_col      = start_date_col,
    end_date_col        = end_date_col,
    intervention_date_col = intervention_date_col,
    death_date_col      = death_date_col
  )

  ## 3) Cohort summary ------------------------------------------------------
  cohort_sum <- summarise_cohort(per_pat, window_days)

  ## 4) Plot ---------------------------------------------------------------
  dah_plot <- plot_dah_distribution(per_pat, window_days)

  ## 5) Return ---------------------------------------------------------------
  list(
    per_patient    = per_pat,
    cohort_summary = cohort_sum,
    plot           = dah_plot
  )
}
