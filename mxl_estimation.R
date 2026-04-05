# Full Disclosure: Code cleaned and reorganized by Claude AI (Anthropic).
#
# Mixed Logit (MXL) Estimation for Development Type Choice
# Estimates a panel mixed logit model with random coefficients
# on market-condition variables, and exports results to CSV.

library(mlogit)
library(tidyverse)
library(lubridate)
library(scales)

set.seed(1)

# --- Data Loading and Preparation -------------------------------------------

sample_data <- read_csv("input_data.csv")

sample_data$id       <- as.integer(factor(sample_data$GTHA_ID))
sample_data$choiceid <- as.integer(factor(10000 * sample_data$GTHA_ID + sample_data$Year))
sample_data$choice   <- as.logical(sample_data$choice)

# Combine Downtown and Midtown Toronto into a single indicator
sample_data$Toronto_DTMid <- sample_data$DT + sample_data$Toronto_MidNorth

# Rescale built-form and land-use variables for coefficient readability
sample_data$BF_A_1km     <- sample_data$BF_A_1km / 1e4
sample_data$EPOI_1km     <- sample_data$EPOI_1km / 1e3
sample_data$ResAll_C_1km <- sample_data$ResAll_C_1km / 1e4

# --- Observed Choice Shares -------------------------------------------------

pivoted <- sample_data |>
  mutate(indivID = GTHA_ID, choice = as.integer(choice)) |>
  select(Dev_Type, CDNAME, indivID, CSDNAME, choice, choiceid, Year) |>
  pivot_wider(names_from = Dev_Type, values_from = choice, values_fill = NA) |>
  replace_na(list(A_N_O = 0, Retail = 0, Office = 0, Mixed = 0, Industrial = 0))

# Encode chosen alternative as integer: 1=A_N_O, 2=Industrial, 3=Mixed, 4=Office, 5=Retail
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

# --- Model Estimation -------------------------------------------------------

mlogit_data <- dfidx(
  sample_data,
  choice = "choice",
  idx    = list(c("choiceid", "id"), "Dev_Type")
)

start_time <- Sys.time()

mxl_model <- mlogit(
  choice ~
    # Generic (alternative-varying) coefficients
    C_1Y + Rent_Adj + SalePrice_CHG + Cap_Rate_CHG +
    Lease_Deal_CHG + Sale_List + Main_Cost_CHG |
    # Alternative-specific coefficients
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
  rpar   = c(C_1Y = "n", Rent_Adj = "n", Cap_Rate_CHG = "n",
             Lease_Deal_CHG = "n", SalePrice_CHG = "n"),
  R      = 200,
  halton = NA,
  panel  = TRUE
)

elapsed <- difftime(Sys.time(), start_time, units = "mins")
message(sprintf("Estimation completed in %.1f minutes", as.numeric(elapsed)))

# --- Export Coefficient Estimates --------------------------------------------

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

model_fit <- tibble(
  statistic = c("logLik", "AIC", "BIC",
                "n_individuals", "n_choice_sets", "n_observations"),
  value = c(
    as.numeric(logLik(mxl_model)),
    AIC(mxl_model),
    BIC(mxl_model),
    n_distinct(sample_data$id),
    n_distinct(sample_data$choiceid),
    nrow(sample_data)
  )
)

write_csv(model_fit, "mxl_model_fit_stats.csv")

message("Results exported: mxl_model_results.csv, mxl_model_fit_stats.csv")
