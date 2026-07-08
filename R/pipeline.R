# ==============================================================
#  DAH (Days‑At‑Home) pipeline – vectorised base‑R implementation
# ==============================================================

# ---------------------------------------------------------------
#  1. validate_events()
# ---------------------------------------------------------------
#' Validate the long‑format event data.
#'
#' Ensures required columns exist, that they are Dates, that each
#' patient has exactly one primary event, that start ≤ end, and flags
#' overlapping hospital/rehab stays (report‑only).
#'
#' @param data `data.frame` containing the events.
#' @param patient_id_col column name for patient ID (default `"patient_id"`).
#' @param event_id_col column name for event ID (default `"event_id"`).
#' @param event_type_col column name for event type (default `"event_type"`).
#' @param start_date_col column name for start date (default `"start_date"`).
#' @param end_date_col column name for end date (default `"end_date"`).
#' @param intervention_date_col column name for the primary intervention date
#'   (default `"intervention_date"`).
#' @param death_date_col column name for death date (default `"death_date"`).
#' @return List with `valid_data` (a copy of the input) and `overlap_flag`
#'   (data.frame: `patient_id`, `overlap` logical).
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

  ## ----- class checks ----------------------------------------------------
  for (c in c(start_date_col, end_date_col,
              intervention_date_col, death_date_col)) {
    if (!inherits(data[[c]], "Date"))
      stop("Column ", c, " must be of class Date")
  }

  ## ----- exactly ONE primary per patient ---------------------------------
  prim_rows <- data[data[[event_type_col]] == "primary", ]
  if (nrow(prim_rows) == 0)
    stop("No primary event found")

  prim_cnt <- table(prim_rows[[patient_id_col]])
  if (any(prim_cnt != 1))
    stop("Each patient must have exactly ONE primary event")

  ## ----- start ≤ end (when both are present) ----------------------------
  bad_idx <- with(data,
                  !is.na(data[[start_date_col]]) &
                    !is.na(data[[end_date_col]]) &
                    data[[start_date_col]] > data[[end_date_col]])
  if (any(bad_idx))
    stop("Rows found with start_date > end_date")

  ## ----- overlapping institutional stays (report only) --------------------
  inst <- data[data[[event_type_col]] %in% c("hospital", "rehabilitation"), ]

  # Order by patient then start date
  inst <- inst[order(inst[[patient_id_col]], inst[[start_date_col]]), ]

  # Helper that returns TRUE if any overlap exists for a patient's rows
  has_overlap <- function(df) {
    if (is.null(df) || nrow(df) < 2) return(FALSE)
    s <- as.integer(df[[start_date_col]])
    e <- as.integer(df[[end_date_col]])
    any(s[-1] <= e[-length(e)])   # overlap if next start ≤ previous end
  }

  # Split by patient (list may miss patients with no institutional rows)
  by_pat <- split(inst, inst[[patient_id_col]])

  # Add empty entries so every patient appears
  all_patients <- unique(data[[patient_id_col]])
  missing_pat <- setdiff(all_patients, names(by_pat))
  if (length(missing_pat) > 0) {
    by_pat[missing_pat] <- vector("list", length(missing_pat))
  }

  ov_vec <- sapply(by_pat, has_overlap)

  overlap_flag <- data.frame(
    patient_id = as.integer(names(ov_vec)),
    overlap    = as.logical(ov_vec),
    stringsAsFactors = FALSE
  )
  overlap_flag <- overlap_flag[order(overlap_flag$patient_id), ]

  list(valid_data = data, overlap_flag = overlap_flag)
}


# ---------------------------------------------------------------
#  2. extract_primary()
# ---------------------------------------------------------------
#' Extract the primary admission.
#' @param data validated data.frame.
#' @param patient_id_col column name for patient ID (default `"patient_id"`).
#' @param event_type_col column name for event type (default `"event_type"`).
#' @param intervention_date_col column name for intervention date
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
#' Extract hospital / rehabilitation stays.
#' @param data validated data.frame.
#' @param patient_id_col column name for patient ID.
#' @param event_type_col column name for event type.
#' @param start_date_col column name for start date.
#' @param end_date_col column name for end date.
#' @return Data.frame with `patient_id`, `start`, `end` (integer days).
#' @export
extract_institutional <- function(data,
                                  patient_id_col = "patient_id",
                                  event_type_col = "event_type",
                                  start_date_col = "start_date",
                                  end_date_col   = "end_date") {

  inst <- data[data[[event_type_col]] %in% c("hospital", "rehabilitation"), ]
  data.frame(
    patient_id = inst[[patient_id_col]],
    start      = as.integer(inst[[start_date_col]]),
    end        = as.integer(inst[[end_date_col]]),
    stringsAsFactors = FALSE
  )
}


# ---------------------------------------------------------------
#  4. merge_overlaps()
# ---------------------------------------------------------------
#' Merge overlapping / adjacent intervals.
#' @param inst_data data.frame with `patient_id`, `start`, `end`.
#' @return Data.frame with merged intervals per patient.
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

  # Order by patient then start
  inst_data <- inst_data[order(inst_data$patient_id, inst_data$start), ]

  # Split by patient and apply a merge routine via lapply
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
        if (df$start[i] <= cur_end + 1) {          # overlap or touch
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
#' Add observation window and death‑inside‑window flag.
#' @param primary_data data.frame from `extract_primary`.
#' @param window_days integer length of the observation window (default = 30).
#' @param intervention_date_col column name for intervention date.
#' @param death_date_col column name for death date.
#' @return `primary_data` with `window_start`, `window_end`,
#'   and `died_in_window` columns.
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
#' Count institutional days inside the window.
#' @param inst_data data.frame with merged intervals (`patient_id`, `start`, `end`).
#' @param win_data data.frame from `apply_window_and_death`
#'   (must contain `patient_id`, `window_start`, `window_end`).
#' @return Data.frame with `patient_id`, `institutional_days`.
#' @export
count_institutional_days <- function(inst_data, win_data) {
  # Prepare output vector
  result <- data.frame(
    patient_id        = win_data$patient_id,
    institutional_days = integer(length(win_data$patient_id)),
    stringsAsFactors = FALSE
  )

  # Use mapply to compute intersections patient‑wise (vectorised across patients)
  intersect_len <- mapply(function(pid, w_start, w_end) {
    intv <- inst_data[inst_data$patient_id == pid, ]
    if (nrow(intv) == 0) return(0L)
    inter <- pmax(0L,
                  pmin(intv$end, w_end) - pmax(intv$start, w_start) + 1L)
    sum(inter)
  },
  result$patient_id,
  win_data$window_start,
  win_data$window_end,
  USE.NAMES = FALSE)

  result$institutional_days <- intersect_len
  result
}


# ---------------------------------------------------------------
#  7. compute_dah()
# ---------------------------------------------------------------
#' Compute Days‑At‑Home per patient.
#' @param win_data output of `apply_window_and_death`.
#' @param inst_counts output of `count_institutional_days`.
#' @param window_days length of observation window (default = 30).
#' @return Data.frame with `patient_id`, `dah`,
#'   `effective_window`, `institutional_days`, `died_in_window`.
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

  merged$effective_window <- ifelse(merged$died_in_window,
                                    as.integer(merged$death_date) -
                                      as.integer(merged$intervention_date) + 1L,
                                    window_days)

  merged$window_start <- merged$window_end <- NULL
  merged
}


# ---------------------------------------------------------------
#  8. summarise_cohort()
# ---------------------------------------------------------------
#' Summarise DAH at the cohort level.
#' @param data per‑patient result from `compute_dah`.
#' @param window_days observation window length (default = 30).
#' @return One‑row data.frame with summary statistics.
#' @importFrom stats median quantile sd
#' @export
summarise_cohort <- function(data, window_days = 30L) {
  total_pt_days <- sum(data$effective_window)
  total_dah     <- sum(data$dah)

  data.frame(
    window_days                = window_days,
    n_patients                 = nrow(data),
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
#' Plot the DAH distribution.
#' @param data per‑patient result from `compute_dah`.
#' @param window_days observation window length (default = 30).
#' @return A `ggplot2` object.
#' @import ggplot2
#' @export
plot_dah_distribution <- function(data, window_days = 30L) {
  ggplot(data,
                  aes(x = dah, fill = died_in_window)) +
    geom_histogram(binwidth = 1,
                            colour = "black",
                            boundary = -0.5) +
    scale_fill_manual(
      values = c("FALSE" = "#4C72B0", "TRUE" = "#C44E52"),
      name = "Died in window"
    ) +
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
#' Run the whole DAH pipeline.
#'
#' Accepts a long‑format data.frame and optional column‑name mappings.
#'
#' @param data_long raw data (`data.frame` or `data.table`).
#' @param window_days observation window length (default = 30).
#' @param patient_id_col column name for patient ID (default `"patient_id"`).
#' @param event_id_col column name for event ID (default `"event_id"`).
#' @param event_type_col column name for event type (default `"event_type"`).
#' @param start_date_col column name for start date (default `"start_date"`).
#' @param end_date_col column name for end date (default `"end_date"`).
#' @param intervention_date_col column name for intervention date
#'   (default `"intervention_date"`).
#' @param death_date_col column name for death date (default `"death_date"`).
#' @param verbose logical; print overlapping‑stay summary (default = TRUE).
#' @param keep_original_names logical; if TRUE, keep the user‑supplied column
#'   names in the per‑patient output.
#' @return List with `per_patient`, `cohort_summary`, `plot`,
#'   `overlap_flag`, `column_mapping`.
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

  ## ---- 1) rename to canonical names ---------------------------------
  data <- as.data.frame(data_long, stringsAsFactors = FALSE)

  rename_map <- c(
    patient_id        = patient_id_col,
    event_id          = event_id_col,
    event_type        = event_type_col,
    start_date        = start_date_col,
    end_date          = end_date_col,
    intervention_date = intervention_date_col,
    death_date        = death_date_col
  )
  # sanity check
  missing <- rename_map[!rename_map %in% names(data)]
  if (length(missing))
    stop("Missing columns in data: ", paste(missing, collapse = ", "))
  # rename to canonical
  names(data)[match(rename_map, names(data))] <- names(rename_map)

  ## ---- 2) run core steps -------------------------------------------
  val <- validate_events(
    data,
    patient_id_col      = "patient_id",
    event_id_col        = "event_id",
    event_type_col      = "event_type",
    start_date_col      = "start_date",
    end_date_col        = "end_date",
    intervention_date_col = "intervention_date",
    death_date_col      = "death_date"
  )
  if (verbose) {
    cat("\n=== Validation summary ===\n")
    print(val$overlap_flag)
  }

  ## primary admission (may already contain death date)
  primary_data <- extract_primary(
    data,
    patient_id_col      = "patient_id",
    event_type_col      = "event_type",
    intervention_date_col = "intervention_date",
    death_date_col      = "death_date"
  )
  ## add death info from a separate “death” row, if present
  death_info <- data[data[[event_type_col]] == "death",
                     c("patient_id", "death_date")]
  if (nrow(death_info) > 0) {
    primary_data <- merge(primary_data, death_info,
                        by = "patient_id", all.x = TRUE)
    # keep the death date from the primary row if it exists
    primary_data$death_date <- ifelse(is.na(primary_data$death_date.x),
                                    primary_data$death_date.y,
                                    primary_data$death_date.x)
    primary_data$death_date.x <- primary_data$death_date.y <- NULL
  }

  ## institutional stays -------------------------------------------------
  inst_data_raw <- extract_institutional(
    data,
    patient_id_col = "patient_id",
    event_type_col = "event_type",
    start_date_col = "start_date",
    end_date_col   = "end_date"
  )
  inst_data_nonover <- merge_overlaps(inst_data_raw)

  ## observation window --------------------------------------------------
  win_data <- apply_window_and_death(
    primary_data,
    window_days,
    intervention_date_col = "intervention_date",
    death_date_col      = "death_date"
  )

  ## count institutional days -------------------------------------------
  inst_counts <- count_institutional_days(inst_data_nonover, win_data)

  ## per‑patient DAH ----------------------------------------------------
  per_pat <- compute_dah(win_data, inst_counts, window_days)

  ## cohort summary ------------------------------------------------------
  cohort_sum <- summarise_cohort(per_pat, window_days)

  ## diagnostic plot ----------------------------------------------------
  dah_plot <- plot_dah_distribution(per_pat, window_days)

  ## ---- 3) optional rename back to user column names -------------------
  if (keep_original_names) {
    present_canonical <- intersect(names(per_pat), names(rename_map))
    back_names <- rename_map[present_canonical]
    names(per_pat)[match(present_canonical, names(per_pat))] <- back_names
  }

  ## ---- 4) return ------------------------------------------------------
  list(
    per_patient    = per_pat,
    cohort_summary = cohort_sum,
    plot           = dah_plot,
    overlap_flag   = val$overlap_flag,
    column_mapping = rename_map
  )
}
