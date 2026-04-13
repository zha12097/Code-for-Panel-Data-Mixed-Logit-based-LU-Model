# ==============================================================================
# Stage 8: Panel-Data Mixed Logit Estimation
# ==============================================================================
# EXECUTABLE R CODE — the econometric engine of the framework.
#
# Purpose:
#     Estimate a panel mixed logit model for commercial land development
#     type choice at the parcel level. The model captures:
#       - Alternative-specific market effects (generic coefficients)
#       - Location-specific urban context effects (alternative-specific coefficients)
#       - Unobserved heterogeneity via normally distributed random coefficients
#       - Panel structure to account for repeated choices by the same parcel
#
# Reference:
#     See Section 3 of the associated paper for the model specification,
#     and the Appendix for the full mathematical formulation.
#
# Inputs:
#     - input_data.csv  (produced by Stages 1–7)
#       Required columns:
#         GTHA_ID   — Unique parcel identifier (original)
#         Year      — Simulation year
#         Dev_Type  — Alternative label: A_N_O | Retail | Industrial | Office | Mixed
#         choice    — Binary: 1 if this alternative was chosen, 0 otherwise
#         [features] — All explanatory variables (see Table 5.1)
#
# Outputs:
#     - mxl_model_results.csv   — Coefficient estimates with standard errors
#     - mxl_model_fit_stats.csv — Model fit statistics (LL, AIC, BIC, counts)
#
# Dependencies:
#     R >= 4.0, mlogit >= 1.1, tidyverse, lubridate, scales
# ==============================================================================

library(mlogit)
library(tidyverse)
library(lubridate)
library(scales)

set.seed(1)

# --- Data Loading and Preparation -------------------------------------------
# Load the consolidated panel database produced by the Python pipeline
# (Stages 1–7). Each row = one parcel × year × alternative combination.

sample_data <- read_csv("input_data.csv")

# Create integer identifiers required by mlogit's panel structure:
#   id       — Groups all observations for the SAME parcel across years.
#              Enables the mixed logit to draw a single set of random
#              coefficients per parcel, shared across all its choice occasions.
#   choiceid — Uniquely identifies each choice situation (parcel × year).
#              Within a choiceid, there is exactly one row per available alternative.
#   choice   — Boolean: TRUE for the alternative actually selected.

sample_data$id       <- as.integer(factor(sample_data$GTHA_ID))
sample_data$choiceid <- as.integer(factor(10000 * sample_data$GTHA_ID + sample_data$Year))
sample_data$choice   <- as.logical(sample_data$choice)

# Combine Downtown and Midtown Toronto into a single regional indicator.
# These two areas share similar development dynamics and are merged to
# avoid multicollinearity while preserving the core-periphery signal.
sample_data$Toronto_DTMid <- sample_data$DT + sample_data$Toronto_MidNorth

# Rescale large-magnitude variables for coefficient readability.
# This improves numerical stability during estimation and makes
# coefficient magnitudes interpretable.
sample_data$BF_A_1km     <- sample_data$BF_A_1km / 1e4       # m² → 10,000 m² units
sample_data$EPOI_1km     <- sample_data$EPOI_1km / 1e3       # count → thousands
sample_data$ResAll_C_1km <- sample_data$ResAll_C_1km / 1e4   # count → ten-thousands

# --- Observed Choice Shares (Descriptive) ------------------------------------
# Compute observed market shares for later comparison with model predictions.

pivoted <- sample_data |>
  mutate(indivID = GTHA_ID, choice = as.integer(choice)) |>
  select(Dev_Type, CDNAME, indivID, CSDNAME, choice, choiceid, Year) |>
  pivot_wider(names_from = Dev_Type, values_from = choice, values_fill = NA) |>
  replace_na(list(A_N_O = 0, Retail = 0, Office = 0, Mixed = 0, Industrial = 0))

# Encode the chosen alternative as an integer for tabulation:
#   1 = A_N_O, 2 = Industrial, 3 = Mixed, 4 = Office, 5 = Retail
pivoted$choice <- case_when(
  pivoted$A_N_O      == 1 ~ 1L,
  pivoted$Industrial  == 1 ~ 2L,
  pivoted$Mixed       == 1 ~ 3L,
  pivoted$Office      == 1 ~ 4L,
  TRUE                     ~ 5L
)

counts_overall  <- pivoted |> count(choice) |> mutate(prop = n / sum(n))
counts_by_cd    <- pivoted |> group_by(CDNAME) |> count(choice) |> mutate(prop = n / sum(n))
counts_by_year  <- pivoted |> group_by(Year) |> count(choice) |> mutate(prop = n / sum(n))
counts_by_cd_yr <- pivoted |> group_by(CDNAME, Year) |> count(choice) |> mutate(prop = n / sum(n))

# --- Prepare mlogit Data Object ----------------------------------------------
# Convert the long-format data into mlogit's indexed data frame (dfidx).
# The idx argument specifies:
#   c("choiceid", "id") — choice situation nested within decision-maker (panel)
#   "Dev_Type"          — the alternative identifier

mlogit_data <- dfidx(
  sample_data,
  choice = "choice",
  idx    = list(c("choiceid", "id"), "Dev_Type")
)

# --- Model Specification and Estimation --------------------------------------
# The utility function follows Equation 5.1:
#
#   U_ijt = β_i · x_ijt + α_i · z_i^d + ε_ijt
#
# Where:
#   x_ijt : Alternative-specific (AS) variables — vary by both parcel and type.
#           These receive GENERIC coefficients (same β across all alternatives).
#           Placed BEFORE the first "|" in the mlogit formula.
#
#   z_i   : Generic (location-specific) variables — vary by parcel only.
#           These receive ALTERNATIVE-SPECIFIC coefficients (different α per type).
#           Placed BETWEEN the first and second "|" in the formula.
#           A_N_O is the reference category (its α is normalised to 0).
#
#   The "| 0" at the end suppresses alternative-specific constants (ASCs)
#   because the regional dummy variables serve an equivalent role.
#
# Random coefficients (rpar):
#   Five market-condition variables are specified as normally distributed
#   random coefficients to capture unobserved heterogeneity in how different
#   parcels/developers respond to market signals:
#     C_1Y            — 1-year lagged supply count
#     Rent_Adj        — Relative rent level (disaggregated)
#     Cap_Rate_CHG    — Year-over-year change in capitalisation rate
#     Lease_Deal_CHG  — Year-over-year change in leasing activity
#     SalePrice_CHG   — Year-over-year change in sale price
#
# Estimation:
#   R = 200 Halton draws for simulated maximum likelihood
#   panel = TRUE enables the panel structure (draws shared within a parcel)

start_time <- Sys.time()

mxl_model <- mlogit(
  choice ~
    # ── Generic coefficients (alternative-varying variables) ──────────
    # These are the market and supply-inertia variables from Eq. 5.7.
    # They capture how market conditions for each LU type affect choice.
    C_1Y + Rent_Adj + SalePrice_CHG + Cap_Rate_CHG +
    Lease_Deal_CHG + Sale_List + Main_Cost_CHG |

    # ── Alternative-specific coefficients (location-varying variables) ─
    # These capture how the same parcel characteristic (e.g., area)
    # differently affects the probability of Retail vs. Industrial, etc.
    # A_N_O is the baseline; coefficients for other types are relative to it.
    ParcelArea + Land_Use_Entropy + CoStar_Entropy +
    a_AM_OFC + a_MD_IND + a_PM_RTL + EPOI_1km +
    ResAll_C_1km + BF_A_1km + BUID_C_100m +
    MJLC_RDS_L_1km + RAILRTS_A_1km + RAILRTS_L_100m +
    AIRP_DIST + BSTP_DIST + LOS_DIST + LU_COM +
    LU_IND + LU_RTL + LU_RES + Toronto_DTMid +
    Air + Bramp + CaleMilton + CoreDurham + Missi +
    OakBurling + Out_York + Outlying_Durham +
    Toronto_East + Toronto_West + York_South +
    OS_A_1km + NBSTP_DIST | 0,

  data   = mlogit_data,

  # Normally distributed random coefficients for market variables
  rpar   = c(C_1Y = "n", Rent_Adj = "n", Cap_Rate_CHG = "n",
             Lease_Deal_CHG = "n", SalePrice_CHG = "n"),
  R      = 200,       # Number of Halton draws for simulation
  halton = NA,        # Use Halton sequences (quasi-random) for efficiency
  panel  = TRUE       # Panel structure: same draws for same parcel across years
)

elapsed <- difftime(Sys.time(), start_time, units = "mins")
message(sprintf("Estimation completed in %.1f minutes", as.numeric(elapsed)))

# --- Extract and Export Coefficient Estimates ---------------------------------
# Build a tidy table of all estimated parameters with inference statistics.

est    <- coef(mxl_model)
se     <- sqrt(diag(vcov(mxl_model)))
z_val  <- est / se
p_val  <- 2 * pnorm(abs(z_val), lower.tail = FALSE)

model_results <- tibble(
  term       = names(est),
  estimate   = as.numeric(est),
  std_error  = as.numeric(se),
  z_value    = as.numeric(z_val),
  p_value    = as.numeric(p_val),
  ci_95_low  = as.numeric(est - 1.96 * se),
  ci_95_high = as.numeric(est + 1.96 * se)
)

write_csv(model_results, "mxl_model_results.csv")

# --- Export Model Fit Statistics ---------------------------------------------
# Key metrics:
#   logLik         — Maximised log-likelihood
#   AIC / BIC      — Information criteria for model comparison
#   McFadden Rho²  — Pseudo R² (target: >= 0.2 for good fit)
#   n_individuals  — Number of unique parcel agents
#   n_choice_sets  — Number of parcel × year observations
#   n_observations — Total rows (parcels × years × alternatives)

ll_model <- as.numeric(logLik(mxl_model))
ll_null  <- as.numeric(logLik(update(mxl_model, . ~ 1)))  # Null model
rho2     <- 1 - (ll_model / ll_null)

model_fit <- tibble(
  statistic = c("logLik", "logLik_null", "McFadden_Rho2", "AIC", "BIC",
                "n_individuals", "n_choice_sets", "n_observations"),
  value = c(
    ll_model,
    ll_null,
    rho2,
    AIC(mxl_model),
    BIC(mxl_model),
    n_distinct(sample_data$id),
    n_distinct(sample_data$choiceid),
    nrow(sample_data)
  )
)

write_csv(model_fit, "mxl_model_fit_stats.csv")

message("Results exported: mxl_model_results.csv, mxl_model_fit_stats.csv")
message(sprintf("McFadden Rho-squared: %.4f", rho2))
