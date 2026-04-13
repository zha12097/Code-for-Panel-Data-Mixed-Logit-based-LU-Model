# Parcel-Level Land Use Supply Microsimulation Framework (Low Data Quality Version)

A modular, replicable framework for simulating land use (LU) supply decisions at the parcel level in large metropolitan regions. Developed and validated in Canada's Greater Toronto and Hamilton Area (GTHA), but designed for transferability to any jurisdiction with formal zoning systems.

> **Paper citation:** Zhang, J., Kiko, M., Miller, E.J. *Land Use Supply at the Parcel Level in the Metropolitan-Scale Area: Framework, Application, and Behavioural Insights.* Submitted to *Journal of Transport and Land Use*.
>
> **Thesis citation:** Zhang, J. (2026). *Decoding Urban Evolution: A Parcel-Level Blueprint for the ILUTE 2.0 Land Use Module.* Doctoral thesis, University of Toronto. ProQuest Dissertations Publishing.

---

## Overview

This repository implements the conceptual framework described in Section 3 & 4 of the associated paper. The framework models **what type** of commercial development (Retail, Industrial, Office, Mixed, or No Development) occurs on each land parcel using a **panel-data mixed logit** discrete choice model. Zoning by-law constraints define each parcel's feasible choice set, and a deep-learning saturation classifier filters out fully built parcels.

### Core Design Principles

| Principle | Description |
|---|---|
| **Spatial Fidelity** | Land parcels as the fundamental simulation unit (~1.4 M in the GTHA) |
| **Policy Awareness** | Real zoning by-law permissions constrain each parcel's feasible choice set |
| **Behavioural Integrity** | Econometric discrete choice models decode developer decision-making |
| **Operational Flexibility** | Adaptable to low-data (Version 1: type only) and high-data (Version 2: type + floorspace) environments |

This repository implements **Version 1 (Low Data Quality)**: the discrete choice of development type under common data constraints where building locations are known but floorspace data are unavailable.

### Platform Agnosticism

**Every stage in this framework is platform-agnostic.** The pseudo-code modules are written in a Python-like style for readability, but each stage can be implemented in any language, GIS platform, or toolchain that the researcher is comfortable with. For example, in the GTHA case study:

- **Spatial data processing** (Stages 1–5) was performed in **ArcGIS Pro**, **GeoPandas**, and **GeoPy**
- **Saturation classification** (Stage 6) was implemented in **TensorFlow/Keras** (Python)
- **Market disaggregation** (Stage 7) was conducted in **ArcGIS Pro** using the Field Calculator and spatial joins
- **Econometric estimation** (Stage 8) was executed in **R** using the `mlogit` package
- **Data manipulation** throughout used a mix of **Python (pandas)**, **R (tidyverse)**, and **ArcPy**

Equivalent results can be achieved using QGIS, PostGIS, Stata, Julia, MATLAB, or any other tools that support the required operations.

---

## Repository Structure

```
├── README.md                          # This file
├── LICENSE
├── config/
│   └── config.yaml                    # All user-configurable parameters
├── src/
│   ├── 00_pipeline_runner.py          # Master orchestrator (pseudo-code)
│   ├── 01_data_acquisition.py         # Stage 1: Raw data collection
│   ├── 02_zoning_landscape.py         # Stage 2: Digital zoning landscape
│   ├── 03_data_cleaning.py            # Stage 3: Cleaning and geocoding
│   ├── 04_spatiotemporal_panel.py     # Stage 4: Panel database construction
│   ├── 05_feature_engineering.py      # Stage 5: Attribute generation
│   ├── 06_availability_filtering.py   # Stage 6: Regulatory + saturation filters
│   ├── 07_market_disaggregation.py    # Stage 7: Spatial interaction downscaling
│   ├── 08_mixed_logit_estimation.R    # Stage 8: Panel mixed logit (EXECUTABLE)
│   └── 09_validation.py              # Stage 9: Simulation and validation
├── examples/
│   └── saturation_classifier.py       # Example: Keras binary classifier for parcel saturation
├── docs/
│   └── workflow.md                    # Detailed workflow documentation
└── requirements.txt                   # Python/R dependencies
```

### What Is Real Code vs. Pseudo-Code?

| Script | Status | Language |
|---|---|---|
| `src/08_mixed_logit_estimation.R` | **Executable** — the actual econometric engine | R |
| `examples/saturation_classifier.py` | **Example** — a reference implementation for the saturation classifier; adapt architecture and features to your own data | Python (TensorFlow/Keras) |
| All other `src/*.py` files | **Pseudo-code** — detailed, annotated blueprints documenting each stage's logic, inputs, outputs, and key algorithms | Python-like |

The pseudo-code modules are written as richly commented, structurally valid Python-like scripts. They document every methodological decision so that researchers can implement equivalent pipelines using their preferred tools and platforms.

---

## Pipeline Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    STAGE 1: DATA ACQUISITION                        │
│  Collect: parcels, buildings, market data, POIs, transport, census  │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│                STAGE 2: DIGITAL ZONING LANDSCAPE                    │
│  Extract ZBL permissions → Unified taxonomy → ML imputation         │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│              STAGE 3: DATA CLEANING & GEOCODING                     │
│  Validate geometries → Geocode addresses → Assign to parcels        │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│            STAGE 4: SPATIO-TEMPORAL PANEL CONSTRUCTION               │
│  Expand parcels × years → Tag builds → Define project units         │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│               STAGE 5: FEATURE ENGINEERING                          │
│  Spatial buffers → Temporal lags → Market signals → Site metrics     │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│              STAGE 6: AVAILABILITY FILTERING                        │
│  Zoning filter → Saturation classifier → Active agent pool          │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│            STAGE 7: MARKET DATA DISAGGREGATION                      │
│  Spatial interaction model: meso-level → parcel-level market vars    │
│  (See Appendix of the paper for the mathematical formulation)       │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│        STAGE 8: PANEL MIXED LOGIT ESTIMATION  [EXECUTABLE]          │
│  R mlogit: random coefficients, panel structure, Halton draws       │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────┐
│             STAGE 9: VALIDATION & SIMULATION                        │
│  McFadden R² → Market share trajectories → Sensitivity analysis     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Data Requirements

> **Note:** Primary datasets used in the GTHA case study are proprietary and cannot be redistributed. This section documents the required schema so researchers can assemble equivalent data for their own study areas.

### Minimum Inputs

| Dataset | Key Fields | Source (GTHA example) |
|---|---|---|
| Land parcels | geometry, unique ID, area | Provincial assessment parcels |
| Building inventory | address, year built, LU type, lifecycle status | CoStar Group or municipal rolls |
| Zoning by-laws | zone code, permitted uses per parcel | Municipal open data / ZBL documents |
| Market indicators | rent, sale price, cap rate, vacancy, operating cost | CoStar Group or equivalent |
| Points of interest | type, coordinates | DMTI Spatial / OpenStreetMap |
| Transport network | roads, bus stops, rail stations, routes | Municipal open data / GTFS |
| Census variables | population, employment, vehicle ownership | Statistics Canada / national census |
| Satellite imagery | high-resolution, multi-year | Google Earth / Esri World Imagery |

---

## Quick Start

### 1. Review the configuration
```bash
# Edit config/config.yaml to set paths, study area bounds,
# temporal range, buffer distances, and model parameters.
```

### 2. Implement the data pipeline
```
# Each stage is documented as a standalone, annotated pseudo-code module.
# These are NOT directly executable — they serve as detailed blueprints.
# Implement each stage using your preferred tools (Python, R, ArcGIS, QGIS, etc.)
# following the logic documented in:
#
#   src/01_data_acquisition.py       → raw data inventory
#   src/02_zoning_landscape.py       → permitted_uses.shp
#   src/03_data_cleaning.py          → cleaned buildings + parcels
#   src/04_spatiotemporal_panel.py   → panel_parcels_years.csv
#   src/05_feature_engineering.py    → feature_matrix.csv
#   src/06_availability_filtering.py → active_agents.csv
#   src/07_market_disaggregation.py  → parcel_market_vars.csv
```

### 3. Run the econometric model (executable R code)
```r
# In R (requires: mlogit, tidyverse)
Rscript src/08_mixed_logit_estimation.R
# Outputs: mxl_model_results.csv, mxl_model_fit_stats.csv
```

### 4. Validate
```
# Follow the logic in src/09_validation.py using your preferred tools.
```

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgements

This framework was developed as part of a doctoral dissertation at the University of Toronto. The authors gratefully acknowledge CoStar Group for providing proprietary commercial real estate data, DMTI Spatial for business establishment records, and the municipalities of the GTHA for sharing zoning by-law data.

---

## Disclosure

Code in this repository was cleaned and reorganised with the assistance of Claude AI (Anthropic).
