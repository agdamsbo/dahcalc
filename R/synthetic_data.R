# R/synthetic_data -------------------------------------------------
#' Example synthetic long‑format clinical data
#'
#' A reproducible, synthetic data set that mimics the structure required by
#' the **DAH** (Days‑At‑Home) analysis pipeline.  The data are in *long*
#' format and contain the columns:
#' \describe{
#'   \item{patient_id}{Integer identifier of the patient.}
#'   \item{event_id}{Consecutive integer for each event per patient.}
#'   \item{event_type}{Character; one of `"primary"` (first admission),
#'                     `"hospital"` (sub‑sequent admission),
#'                     `"rehabilitation"` or `"death"`.}
#'   \item{start_date}{Date of the start of the event (NA for death rows).}
#'   \item{end_date}{Date of the end of the event (NA for death rows).}
#'   \item{intervention_date}{Date of the primary clinical intervention.
#'                     Only non‑NA for rows where \code{event_type == "primary"}.
#'                     }
#'   \item{death_date}{Date of death; NA for patients who survive the
#'                     observation period.  For death rows this is the
#'                     actual date of death; for all other rows it is NA.}
#' }
#' The data contain **40** simulated patients.  Approximately 30 % of the
#' patients have a separate death row; the remaining patients survive the
#' 45‑day observation horizon.  Hospital and rehabilitation stays are
#' randomly generated, may overlap, and are limited to a maximum of 45
#' days after the primary admission.
#'
#' @name synthetic_data
#' @format A **data.frame** with 131 rows and 7 columns (see description above).
#' @source Generated internally by the package using the script
#'   `data-raw/generate-synthetic_data.R`.  The random seed is set to `2026`
#'   for reproducibility.
#' @examples
#' ## Load the data set
#' data(synthetic_data, package = "dahcalc")
#'
#' ## Quick look at the first few rows
#' head(synthetic_data)
#'
#' ## Run the DAH pipeline on the synthetic data
#' result <- run_dah_pipeline(synthetic_data, window_days = 30)
#' result$cohort_summary
#' @keywords internal
NULL
