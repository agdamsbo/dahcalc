# -------------------------------------------------------------------------
# Helper: coerce a vector to Date (accepts Date, POSIXct, character)
# -------------------------------------------------------------------------
.coerce_to_date <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(x))
  # try character → Date (default ISO format; users can set options)
  as.Date(x)
}

# Helper: convert integer day count (days since 1970‑01‑01) back to Date
.int_to_date <- function(x) {
  as.Date(x, origin = "1970-01-01")
}


# ---------------------------------------------------------------
#  1. validate_events()
# ---------------------------------------------------------------
#' Validate the long‑format event data
#'
#' Checks required columns, coerces all date columns to `Date`, validates a
#' single primary event per patient and that start ≤ end.  Overlap detection
#' is performed internally (required for merging) but **no overlap flag is
#' returned**.
#'
#' @param data `data.frame` (or coercible) containing the event records.
#' @param patient_id_col column name for patient ID (default `"patient_id"`).
#' @param event_id_col column name for event ID (default `"event_id"`).
#' @param event_type_col column name for event type (default `"event_type"`).
#' @param start_date_col column name for start date (default `"start_date"`).
#' @param end_date_col column name for end date (default `"end_date"`).
#' @param intervention_date_col column name for the primary intervention date
#'   (default `"intervention_date"`).
#' @param death_date_col column name for death date (default `"death_date"`).
#' @return A **cleaned data.frame** whose date columns are `Date` objects.
#' @export
validate_events <- function(data,
                            patient_id_col      = "patient_id",
                            event_id_col        = "event_id",
                            event_type_col      = "event_type",
                            start_date_col      = "start_date",
                            end_date_col        = "end_date",
                            intervention_date_col = "intervention_date",
                            death_date_col      = "death_date") {

  data <- as.data.frame(data, stringsAsFactors = FALSE)

  ## ----- required columns -------------------------------------------------
  req <- c(patient_id_col, event_id_col, event_type_col,
           start_date_col, end_date_col,
           intervention_date_col, death_date_col)
  miss <- setdiff(req, names(data))
  if (length(miss))
    stop("Missing required columns: ", paste(miss, collapse = ", "))

  ## ----- coerce all date columns to Date ----------------------------------
  date_cols <- c(start_date_col, end_date_col,
                 intervention_date_col, death_date_col)
  for (c in date_cols) {
    data[[c]] <- .coerce_to_date(data[[c]])
    if (!inherits(data[[c]], "Date"))
      stop("Column ", c, " could not be coerced to Date")
  }

  ## ----- exactly ONE primary per patient ---------------------------------
  prim_rows <- data[data[[event_type_col]] == "primary", ]
  if (nrow(prim_rows) == 0)
    stop("No primary event found")
  prim_cnt <- table(prim_rows[[patient_id_col]])
  if (any(prim_cnt != 1))
    stop("Each patient must have exactly ONE primary event")

  ## ----- start ≤ end ------------------------------------------------------
  bad_idx <- with(data,
                  !is.na(data[[start_date_col]]) &
                    !is.na(data[[end_date_col]]) &
                    data[[start_date_col]] > data[[end_date_col]])
  if (any(bad_idx))
    stop("Rows found with start_date > end_date")

  ## ----- overlapping institutional stays (still checked internally) ------
  ##    We keep the check but discard the result.
  inst <- data[data[[event_type_col]] %in% c("hospital", "rehabilitation"), ]
  inst <- inst[order(inst[[patient_id_col]], inst[[start_date_col]]), ]

  has_overlap <- function(df) {
    if (is.null(df) || nrow(df) < 2) return(FALSE)
    s <- as.integer(df[[start_date_col]])
    e <- as.integer(df[[end_date_col]])
    any(s[-1] <= e[-length(e)])
  }
  invisible(sapply(split(inst, inst[[patient_id_col]]), has_overlap))

  ## Return the cleaned data
  data
}


# ---------------------------------------------------------------
#  2. extract_primary()
# ---------------------------------------------------------------
#' Extract the primary admission record
#' @param data Output of `validate_events()` (canonical column names).
#' @param patient_id_col column name for patient ID (default `"patient_id"`).
#' @param event_type_col column name for event type (default `"event_type"`).
#' @param intervention_date_col column name for the primary intervention date
#'   (default `"intervention_date"`).
#' @param death_date_col column name for death date (default `"death_date"`).
#' @return Data.frame with `patient_id`, `intervention_date`, `death_date`.
#' @export
extract_primary <- function(data,
                            patient_id_col      = "patient_id",
                            event_type_col      = "event_type",
                            intervention_date_col = "intervention_date",
                            death_date_col      = "death_date") {

  prim <- data[data[[event_type_col]] == "primary", ]
  data.frame(
    patient_id        = prim[[patient_id_col]],
    intervention_date = prim[[intervention_date_col]],
    death_date        = prim[[death_date_col]],
    stringsAsFactors = FALSE
  )
}


# ---------------------------------------------------------------
#  3. extract_institutional()
# ---------------------------------------------------------------
#' Extract hospital / rehabilitation stays (as integer days)
#' @param data Output of `validate_events()`.
#' @param patient_id_col column name for patient ID.
#' @param event_type_col column name for event type.
#' @param start_date_col column name for stay start date.
#' @param end_date_col column name for stay end date.
#' @return Data.frame with `patient_id`, `start`, `end` (both integer days).
#' @export
extract_institutional <- function(data,
                                  patient_id_col = "patient_id",
                                  event_type_col = "event_type",
                                  start_date_col = "start_date",
                                  end_date_col   = "end_date") {

  inst <- data[data[[event_type_col]] %in% c("hospital", "rehabilitation"), ]
  data.frame(
    patient_id = inst[[patient_id_col]],
    start      = as.integer(inst[[start_date_col]]),   # integer days since 1970‑01‑01
    end        = as.integer(inst[[end_date_col]]),
    stringsAsFactors = FALSE
  )
}


# ---------------------------------------------------------------
#  4. merge_overlaps()
# ---------------------------------------------------------------
#' Merge overlapping or adjacent institutional intervals per patient
#' @param inst_data Data.frame with `patient_id`, `start`, `end` (integer days).
#' @return Data.frame with merged intervals (still integer days).
#' @export
merge_overlaps <- function(inst_data) {
  if (nrow(inst_data) == 0L) {
    return(data.frame(
      patient_id = integer(),
      start      = integer(),
      end        = integer(),
      stringsAsFactors = FALSE
    ))
  }
  inst_data <- inst_data[order(inst_data$patient_id, inst_data$start), ]

  merged_list <- lapply(split(inst_data, inst_data$patient_id), function(df) {
    cur_start <- df$start[1]
    cur_end   <- df$end[1]
    out_start <- integer()
    out_end   <- integer()
    if (nrow(df) == 1) {
      out_start <- cur_start
      out_end   <- cur_end
    } else {
      for (i in 2:nrow(df)) {
        if (df$start[i] <= cur_end + 1) {
          cur_end <- max(cur_end, df$end[i])
        } else {
          out_start <- c(out_start, cur_start)
          out_end   <- c(out_end,   cur_end)
          cur_start <- df$start[i]
          cur_end   <- df$end[i]
        }
      }
      out_start <- c(out_start, cur_start)
      out_end   <- c(out_end,   cur_end)
    }
    data.frame(
      patient_id = df$patient_id[1],
      start      = out_start,
      end        = out_end,
      stringsAsFactors = FALSE
    )
  })
  merged <- do.call(rbind, merged_list)
  rownames(merged) <- NULL
  merged
}


# ---------------------------------------------------------------
#  5. apply_window_and_death()
# ---------------------------------------------------------------
#' Add observation window and flag deaths inside the window
#' @param primary_data Data.frame from `extract_primary()`.
#' @param window_days Integer length of the observation window (default = 30).
#' @param intervention_date_col column name for the intervention date.
#' @param death_date_col column name for death date.
#' @return `primary_data` with integer `window_start`, `window_end`
#'   and logical `died_in_window`.  Original Date columns are untouched.
#' @export
apply_window_and_death <- function(primary_data,
                                   window_days = 30L,
                                   intervention_date_col = "intervention_date",
                                   death_date_col = "death_date") {

  primary_data$window_start <- as.integer(primary_data[[intervention_date_col]])
  primary_data$window_end   <- primary_data$window_start + window_days - 1L

  primary_data$died_in_window <-
    !is.na(primary_data[[death_date_col]]) &
    as.integer(primary_data[[death_date_col]]) >= primary_data$window_start &
    as.integer(primary_data[[death_date_col]]) <= primary_data$window_end

  primary_data
}


# ---------------------------------------------------------------
#  6. count_institutional_days()
# ---------------------------------------------------------------
#' Count institutional days that fall inside the (full) observation window
#' @param inst_data Data.frame with merged intervals (`patient_id`, `start`,
#'   `end`) – integer days.
#' @param win_data Data.frame from `apply_window_and_death()` that must
#'   contain `patient_id`, `window_start`, `window_end` and `died_in_window`.
#' @return Data.frame with `patient_id` and `institutional_days`.  If a patient
#'   died inside the window the count is forced to 0.
#' @export
count_institutional_days <- function(inst_data, win_data) {
  result <- data.frame(
    patient_id        = win_data$patient_id,
    institutional_days = integer(length(win_data$patient_id)),
    stringsAsFactors = FALSE
  )

  intersect_len <- mapply(
    FUN = function(pid, w_start, w_end) {
      intv <- inst_data[inst_data$patient_id == pid, , drop = FALSE]
      if (nrow(intv) == 0) return(0L)

      inter <- pmax(0L,
                    pmin(intv$end, w_end) -
                      pmax(intv$start, w_start) + 1L)
      sum(inter)
    },
    result$patient_id,
    win_data$window_start,
    win_data$window_end,
    USE.NAMES = FALSE
  )

  ## Patients who died inside the window get 0 institutional days
  intersect_len[win_data$died_in_window] <- 0L
  result$institutional_days <- intersect_len
  result
}


# ---------------------------------------------------------------
#  7. compute_dah()
# ---------------------------------------------------------------
#' Compute Days‑At‑Home per patient
#' @param win_data Output of `apply_window_and_death()`.
#' @param inst_counts Output of `count_institutional_days()`.
#' @param window_days Length of the observation window (default = 30).
#' @return Data.frame with per‑patient results.  All date columns are `Date`.
#' @export
compute_dah <- function(win_data,
                        inst_counts,
                        window_days = 30L) {

  merged <- merge(win_data, inst_counts,
                  by = "patient_id", all.x = TRUE)

  merged$institutional_days[is.na(merged$institutional_days)] <- 0L

  merged$dah <- ifelse(merged$died_in_window,
                       0L,
                       pmax(0L, window_days - merged$institutional_days))

  merged$effective_window <- window_days   # constant for everybody

  ## ---- Ensure date columns are Date objects --------------------------------
  ## `intervention_date` is already a Date (it was never coerced to integer).
  ## `death_date` might have been turned into integer by a previous step,
  ## so we force it back to Date if necessary.
  if (!inherits(merged$death_date, "Date")) {
    merged$death_date <- .int_to_date(merged$death_date)
  }

  ## Drop the temporary integer window columns – they are not needed downstream
  merged$window_start <- merged$window_end <- NULL
  merged
}



# ---------------------------------------------------------------
#  8. summarise_cohort()
# ---------------------------------------------------------------
#' Summarise DAH at the cohort level (adds number of deaths)
#' @param data Per‑patient result returned by `compute_dah()`.
#' @param window_days Observation window length (default = 30).
#' @return One‑row data.frame with summary statistics, including `n_deaths`.
#' @importFrom stats median quantile sd
#' @export
summarise_cohort <- function(data, window_days = 30L) {
  n_deaths <- sum(data$died_in_window, na.rm = TRUE)

  total_pt_days <- sum(data$effective_window)
  total_dah     <- sum(data$dah)

  data.frame(
    window_days                = window_days,
    n_patients                 = nrow(data),
    n_deaths                   = n_deaths,
    mean_dah                   = round(mean(data$dah), 2),
    median_dah                 = median(data$dah),
    sd_dah                     = round(sd(data$dah), 2),
    q25_dah                    = quantile(data$dah, 0.25),
    q75_dah                    = quantile(data$dah, 0.75),
    pct_full_home              = round(100 * mean(data$dah == window_days), 1),
    mean_effective_window_days = round(mean(data$effective_window), 2),
    dah_per_100_pt_days        = round(100 * total_dah / total_pt_days, 2),
    stringsAsFactors = FALSE
  )
}


# ---------------------------------------------------------------
#  9. plot_dah_distribution()
# ---------------------------------------------------------------
#' Plot the distribution of Days‑At‑Home
#' @param data Per‑patient result from `compute_dah()`.
#' @param window_days Observation window length (default = 30).
#' @return A ggplot2 object (single‑colour histogram).
#' @import ggplot2
#' @export
plot_dah_distribution <- function(data, window_days = 30L) {
  ggplot(data,
         aes(x = dah)) +
    geom_histogram(binwidth = 1,
                   colour = "black",
                   fill = "#4C72B0",
                   boundary = -0.5) +
    geom_vline(xintercept = window_days,
               linetype = "dashed") +
    labs(
      title = paste0("Distribution of Days At Home (",
                     window_days,
                     "-day window)"),
      x = "Days At Home",
      y = "Number of patients"
    ) +
    theme_minimal()
}


# ---------------------------------------------------------------
# 10. run_dah_pipeline()
# ---------------------------------------------------------------
#' Run the whole DAH pipeline (dates returned as `Date` objects)
#' @param data_long Raw long‑format data (`data.frame` or `data.table`).
#' @param window_days Observation window length (default = 30).
#' @param patient_id_col column name for patient ID (default `"patient_id"`).
#' @param event_id_col column name for event ID (default `"event_id"`).
#' @param event_type_col column name for event type (default `"event_type"`).
#' @param start_date_col column name for start date (default `"start_date"`).
#' @param end_date_col column name for end date (default `"end_date"`).
#' @param intervention_date_col column name for the primary intervention date
#'   (default `"intervention_date"`).
#' @param death_date_col column name for death date (default `"death_date"`).
#' @param verbose Logical; retained for backward compatibility but has no
#'   effect (default = \code{TRUE}).
#' @param keep_original_names If \code{TRUE}, the output keeps the user‑supplied
#'   column names (default = \code{FALSE}).
#' @return List with `per_patient`, `cohort_summary`, `plot`,
#'   and `column_mapping`.  All date columns in `per_patient` are `Date` objects.
#' @export
run_dah_pipeline <- function(
    data_long,
    window_days = 30L,

    # ----- column‑name arguments (canonical defaults) -----
    patient_id_col      = "patient_id",
    event_id_col        = "event_id",
    event_type_col      = "event_type",
    start_date_col      = "start_date",
    end_date_col        = "end_date",
    intervention_date_col = "intervention_date",
    death_date_col      = "death_date",

    # ----- extras -----------------------------------------
    verbose            = TRUE,
    keep_original_names = FALSE
) {

  ## 1) coerce ------------------------------------------------------------
  data <- as.data.frame(data_long, stringsAsFactors = FALSE)

  ## 2) rename to canonical names -----------------------------------------
  rename_map <- c(
    patient_id        = patient_id_col,
    event_id          = event_id_col,
    event_type        = event_type_col,
    start_date        = start_date_col,
    end_date          = end_date_col,
    intervention_date = intervention_date_col,
    death_date        = death_date_col
  )
  missing <- rename_map[!rename_map %in% names(data)]
  if (length(missing))
    stop("Missing columns in data: ", paste(missing, collapse = ", "))
  names(data)[match(rename_map, names(data))] <- names(rename_map)

  ## 3) core processing ----------------------------------------------------
  clean_data <- validate_events(
    data,
    patient_id_col      = "patient_id",
    event_id_col        = "event_id",
    event_type_col      = "event_type",
    start_date_col      = "start_date",
    end_date_col        = "end_date",
    intervention_date_col = "intervention_date",
    death_date_col      = "death_date"
  )

  ## primary admission -------------------------------------------------------
  primary_data <- extract_primary(
    clean_data,
    patient_id_col      = "patient_id",
    event_type_col      = "event_type",
    intervention_date_col = "intervention_date",
    death_date_col      = "death_date"
  )
  ## Merge a separate “death” row if present
  death_info <- clean_data[clean_data[[event_type_col]] == "death",
                           c("patient_id", "death_date")]
  if (nrow(death_info) > 0) {
    primary_data <- merge(primary_data, death_info,
                          by = "patient_id", all.x = TRUE)
    primary_data$death_date <- ifelse(is.na(primary_data$death_date.x),
                                      primary_data$death_date.y,
                                      primary_data$death_date.x)
    primary_data$death_date.x <- primary_data$death_date.y <- NULL
  }

  ## institutional stays ----------------------------------------------------
  inst_data_raw  <- extract_institutional(
    clean_data,
    patient_id_col = "patient_id",
    event_type_col = "event_type",
    start_date_col = "start_date",
    end_date_col   = "end_date"
  )
  inst_data_nonover <- merge_overlaps(inst_data_raw)

  ## observation window -----------------------------------------------------
  win_data <- apply_window_and_death(
    primary_data,
    window_days,
    intervention_date_col = "intervention_date",
    death_date_col      = "death_date"
  )

  ## count institutional days ------------------------------------------------
  inst_counts <- count_institutional_days(inst_data_nonover, win_data)

  ## per‑patient DAH --------------------------------------------------------
  per_pat <- compute_dah(win_data, inst_counts, window_days)

  ## cohort summary ---------------------------------------------------------
  cohort_sum <- summarise_cohort(per_pat, window_days)

  ## diagnostic plot --------------------------------------------------------
  dah_plot <- plot_dah_distribution(per_pat, window_days)

  ## 4) optional rename back to the user’s column names -----------------------
  if (keep_original_names) {
    present_canonical <- intersect(names(per_pat), names(rename_map))
    back_names <- rename_map[present_canonical]
    names(per_pat)[match(present_canonical, names(per_pat))] <- back_names
  }

  ## 5) return ---------------------------------------------------------------
  list(
    per_patient    = per_pat,      # all date columns are Date objects
    cohort_summary = cohort_sum,
    plot           = dah_plot,
    column_mapping = rename_map
  )
}
