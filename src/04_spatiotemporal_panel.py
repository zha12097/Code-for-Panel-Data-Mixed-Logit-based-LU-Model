"""
================================================================================
Stage 4: Spatio-Temporal Panel Database Construction
================================================================================
PSEUDO-CODE — documents how the parcel × year panel is assembled, including
the "project" concept for grouping co-located, co-temporal developments.

Purpose:
    Expand the static parcel inventory into a longitudinal panel dataset where
    each row represents one parcel in one year, annotated with the development
    decision (choice) made in that year.

Reference:
    See Section 3 of the associated paper for the panel construction logic,
    the "project" concept, and the choice set definition.
    This stage can be implemented in any data manipulation tool
    (Python/pandas, R/tidyverse, SQL, etc.).

Inputs:
    - Cleaned buildings with parcel assignments (from Stage 3)
    - Land parcel geometries with permitted uses (from Stages 2–3)
    - config.yaml (temporal scope, choice set definition)

Outputs:
    - data/intermediate/panel_database.csv
        Columns: parcel_id, year, Dev_Type, choice (0/1), parcel attributes
        One row per parcel × year × alternative combination
        (long format required by mlogit / discrete choice estimators)
================================================================================
"""


def run(config):

    start_year = config["temporal"]["start_year"]       # e.g., 2015
    end_year   = config["temporal"]["end_year"]          # e.g., 2023
    lag_years  = config["temporal"]["lag_initialization_years"]  # e.g., 2
    alternatives = config["choice_set"]["alternatives"]  # [Retail, Industrial, Office, Mixed, A_N_O]

    # ══════════════════════════════════════════════════════════════════════
    # STEP 1: DEFINE "PROJECTS" — GROUP BUILDINGS BY PARCEL AND YEAR
    # ══════════════════════════════════════════════════════════════════════
    #
    # A "project" is defined as ALL development actions occurring on a single
    # parcel within a single timestep (Chapter 4, §4.3.3, Figure 4.5).
    #
    # Rules:
    #   - If parcel P has 2 retail buildings built in 2018 → 1 Retail project
    #   - If parcel P has 1 retail + 1 office built in 2018 → 1 Mixed project
    #   - If parcel P has 1 retail in 2018 + 1 office in 2019 → 2 separate projects
    #   - If parcel P has no buildings built in 2020 → A_N_O (No Development)
    #
    # Mixed-use classification (for this case study):
    #   - "Mixed" = any combination of {Retail, Industrial, Office} on the
    #     same parcel in the same year
    #   - Residential components are absorbed into A_N_O since residential
    #     is outside the target choice set

    # buildings = load(config["paths"]["cleaned_buildings"])
    #
    # projects = (
    #     buildings
    #     .groupby(["parcel_id", "year_built"])
    #     .agg(lu_types=("lu_type", lambda x: set(x)))
    # )
    #
    # def classify_project(lu_set):
    #     """Assign a project to one of the 5 choice alternatives."""
    #     commercial_types = lu_set & {"Retail", "Industrial", "Office"}
    #     if len(commercial_types) == 0:
    #         return "A_N_O"            # Only residential or other non-target types
    #     elif len(commercial_types) == 1:
    #         return commercial_types.pop()  # Single commercial type
    #     else:
    #         return "Mixed"            # Two or more commercial types on same parcel+year
    #
    # projects["project_type"] = projects["lu_types"].apply(classify_project)

    # ══════════════════════════════════════════════════════════════════════
    # STEP 2: EXPAND PARCELS INTO PANEL (PARCEL × YEAR)
    # ══════════════════════════════════════════════════════════════════════
    #
    # Create one record per parcel per simulation year. For each parcel-year:
    #   - If a project occurred → choice = project_type
    #   - If no project occurred → choice = "A_N_O"
    #
    # Note: A parcel that has been classified as "saturated" and exited the
    # model is handled in Stage 6. At this point, we keep ALL parcels.

    # parcels = load(config["paths"]["parcels_shapefile"])
    # years = range(start_year, end_year + 1)
    #
    # panel_rows = []
    # for parcel in parcels:
    #     for year in years:
    #         if (parcel.id, year) in projects.index:
    #             chosen = projects.loc[(parcel.id, year), "project_type"]
    #         else:
    #             chosen = "A_N_O"
    #         panel_rows.append({
    #             "parcel_id": parcel.id,
    #             "year": year,
    #             "chosen_alternative": chosen,
    #             # ... parcel-level static attributes appended here
    #         })

    # ══════════════════════════════════════════════════════════════════════
    # STEP 3: CONVERT TO LONG FORMAT (PARCEL × YEAR × ALTERNATIVE)
    # ══════════════════════════════════════════════════════════════════════
    #
    # Discrete choice estimation requires data in "long" format:
    # For each parcel-year observation, there is one row per available
    # alternative, with a binary 'choice' indicator (1 for the selected
    # alternative, 0 for all others).
    #
    # Example for parcel P in year 2018 (chosen = Retail):
    #   parcel_id | year | Dev_Type    | choice
    #   P         | 2018 | A_N_O       | 0
    #   P         | 2018 | Retail      | 1       ← chosen
    #   P         | 2018 | Industrial  | 0
    #   P         | 2018 | Office      | 0
    #   P         | 2018 | Mixed       | 0
    #
    # IMPORTANT: Not all 5 alternatives may be available to every parcel.
    # Zoning restrictions remove infeasible options (handled in Stage 6).
    # At this stage, include ALL alternatives; filtering comes later.

    # long_panel = []
    # for obs in panel_rows:
    #     for alt in alternatives:
    #         long_panel.append({
    #             "parcel_id":  obs["parcel_id"],
    #             "year":       obs["year"],
    #             "Dev_Type":   alt,
    #             "choice":     1 if alt == obs["chosen_alternative"] else 0,
    #             # ... static attributes repeated for each alternative row
    #         })

    # ══════════════════════════════════════════════════════════════════════
    # STEP 4: GENERATE UNIQUE IDENTIFIERS FOR MLOGIT
    # ══════════════════════════════════════════════════════════════════════
    #
    # The R mlogit package requires specific indexing:
    #   - id       : Identifies the decision-maker (parcel agent).
    #                 Constant across all years for the same parcel.
    #                 Enables the "panel" structure in mixed logit.
    #   - choiceid : Identifies a unique choice situation (parcel × year).
    #                 Each parcel-year combination gets a distinct integer.
    #   - Dev_Type : Identifies the alternative within a choice situation.
    #
    # Encoding scheme used:
    #   choiceid = 10000 * parcel_integer_id + year
    #   (ensures uniqueness assuming < 10000 years in the study period)

    # panel["id"] = integer_encode(panel["parcel_id"])
    # panel["choiceid"] = 10000 * panel["id"] + panel["year"]

    # ══════════════════════════════════════════════════════════════════════
    # STEP 5: ATTACH PARCEL-LEVEL STATIC ATTRIBUTES
    # ══════════════════════════════════════════════════════════════════════
    #
    # Merge in parcel geometry metrics and administrative identifiers:
    #   - ParcelArea      : Parcel area in m² (or rescaled units)
    #   - municipality     : CSDNAME (Census Subdivision name)
    #   - region           : CDNAME (Census Division name)
    #   - centroid_x/y     : For distance calculations in later stages
    #
    # These do NOT vary by alternative — they are "generic" attributes.
    # Alternative-specific attributes (market vars) are added in Stage 7.

    # panel = panel.merge(parcels[["parcel_id", "ParcelArea", "CSDNAME",
    #                              "CDNAME", "centroid_x", "centroid_y"]],
    #                     on="parcel_id")

    # ══════════════════════════════════════════════════════════════════════
    # STEP 6: SATURATION EXIT LOGIC (CONCEPTUAL)
    # ══════════════════════════════════════════════════════════════════════
    #
    # After a parcel completes a project and becomes fully developed
    # (saturated), it should EXIT the simulation in subsequent years.
    #
    # Implementation (Chapter 5, Figure 5.4):
    #   After each timestep t:
    #     if parcel chose something other than A_N_O at time t:
    #         check saturation status (from Stage 6 classifier)
    #         if saturated:
    #             remove parcel from panel for years t+1, t+2, ...
    #         else:
    #             parcel continues to participate
    #
    # This filtering is applied in Stage 6 after the saturation classifier
    # has been trained. Here, we retain all rows.

    # ══════════════════════════════════════════════════════════════════════
    # STEP 7: EXPORT PANEL DATABASE
    # ══════════════════════════════════════════════════════════════════════

    # panel.to_csv(config["paths"]["panel_database"], index=False)
    # log(f"Panel database: {len(panel)} rows, "
    #     f"{panel['parcel_id'].nunique()} parcels, "
    #     f"{panel['year'].nunique()} years")

    pass
