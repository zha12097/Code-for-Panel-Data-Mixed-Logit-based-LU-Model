# Detailed Workflow Documentation

> See the associated paper for the complete theoretical derivation. Equation numbers
> below correspond to the paper. The spatial interaction model formulation is provided
> in the paper's Appendix. All computations described here are platform-agnostic.

## Mathematical Foundations

### Utility Function (Equation 1)

Each parcel agent *i* selects the alternative *j* in year *t* that maximises:

```
U_ijt = β_i · x_ijt + α_i · z_i^d + ε_ijt
```

| Symbol | Description |
|---|---|
| `x_ijt` | Alternative-specific attributes (vary by parcel, type, and year): lagged supply, market conditions, market inertia |
| `z_i^d` | Generic attributes (vary by parcel only): urban form, LU context, transport, socio-demographics within distance *d* |
| `β_i` | Random coefficients on AS attributes (normally distributed across agents) |
| `α_i` | Random coefficients on generic attributes |
| `ε_ijt` | iid Type-I Extreme Value (Gumbel) error |

### Choice Probability (Equations 2–4)

Conditional on the random coefficients:

```
P(j|i,t,β,α) = exp(β·x_ijt + α·z_i) / Σ_k exp(β·x_ikt + α·z_i)
```

Unconditional (integrated over the distribution of random coefficients):

```
P(j|i,t) = ∫∫ P(j|i,t,β,α) · f(β|θ_β) · f(α|θ_α) dβ dα
```

Approximated via simulation with *R* = 200 Halton draws:

```
P'(j|i,t) = (1/R) Σ_{r=1}^{R} P(j|i,t, β_r, α_r)
```

### Spatial Interaction Model for Market Disaggregation (Equation A.1)
```
RM_ij^{t-1} = [ Σ_{k≠i} M_kj^{t-1} / l_ik² ] / [ Σ_{k≠i} 1 / l_ik² ]
```

This is a distance-weighted average that converts meso-level (submarket) market data into a smooth, parcel-level surface.

### Market Inertia (Equation 7)

```
CM_ij^{t-1} = (M_ij^{t-1} - M_ij^{t-2}) / M_ij^{t-2} × 100%
```

Year-over-year percentage change captures market momentum.

---

## Variable Classification for mlogit

Understanding how variables enter the `mlogit()` formula is critical for correct specification:

### Generic Coefficients (before first `|`)

These are **alternative-specific variables** — they take different values for each alternative within a choice situation. The estimated coefficient is the **same across all alternatives** (generic).

In this model: `C_1Y`, `Rent_Adj`, `SalePrice_CHG`, `Cap_Rate_CHG`, `Lease_Deal_CHG`, `Sale_List`, `Main_Cost_CHG`

Example: `C_1Y` for Retail = count of nearby retail projects last year; `C_1Y` for Industrial = count of nearby industrial projects last year. Same coefficient β means "one more nearby project of your own type increases utility by β."

### Alternative-Specific Coefficients (between first and second `|`)

These are **individual-specific variables** — they have the same value regardless of which alternative is being evaluated. The estimated coefficient **differs by alternative** (with one alternative as reference — here, A_N_O).

In this model: `ParcelArea`, `Land_Use_Entropy`, ..., regional dummies

Example: `ParcelArea` has different coefficients for Retail (β_R), Industrial (β_I), Office (β_O), and Mixed (β_M), all relative to A_N_O (β = 0). This captures the finding that industrial developments prefer larger parcels than office developments.

---

## Key Findings Summary (GTHA Case Study)

| Finding | Evidence |
|---|---|
| Market trends > market levels | Sale price change significant; sale price level not significant |
| Lagged effects decay | 1-year coeff = 0.19; 3-year = 0.05; 5-year = 0.01 |
| Retail prefers mixed-use transit corridors | Positive: bus stop proximity, building density (100m). Negative: industrial zone proximity |
| Industrial extends existing clusters | Positive: low LU diversity, industrial zone proximity. Negative: road density, mixed-use areas |
| Office seeks emerging growth zones | Positive: LU entropy, mixed-use areas. Negative: established office/retail clusters |
| Scale matters (MAUP) | Most variables stronger at 1km than 100m; exceptions exist (rail, building count) |
