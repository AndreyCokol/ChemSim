# ChemSim A3 equilibrium core

This package currently implements the seven A3 benchmark fixtures as an isolated,
dependency-free reference core. It is not yet a general chemical-speciation engine.

## Scope

- W01: monoprotic weak acid with water autoionization.
- W02: fully dissociated HCl/NaOH with spectator ions.
- W03: AgCl solubility with excess solid reservoir.
- W04: NH3/NH4+ buffer with nitrogen and chloride totals.
- W05: one-phase AgCl precipitation using an active/inactive solid check.
- G01: 2 NO2(g) <=> N2O4(g), fixed T/V, ideal gas.
- G02: H2(g) + I2(g) <=> 2 HI(g), fixed T/V, ideal gas.

All aqueous calculations use the explicitly simplified ideal-dilute convention
(gamma_i = 1, concentration standard state 1 mol/L). Gas calculations use
ideal partial pressures with p° = 1 bar. Constants must be dimensionless and
must match those standard states. Temperature dependence is not inferred.

The module intentionally rejects missing/nonphysical inputs. It does not implement
complexation, non-ideal activity models, multiple solids, gas fugacity, phase
transitions, or a time integrator. The AgCl solubility fixture assumes an excess
solid reservoir and does not invent a remaining solid mass.

## Tests

From the repository root:

    python -m pip install -e .
    python -m unittest discover -s tests -v

## Numerical diagnostics

Each result carries the solver residual, iteration count, component-balance residual,
charge-balance residual, method, activity model, reliability status, and an explicit balance unit.
The current fixtures always report `idealized_approximation`: constants are supplied by the
caller, provenance is not yet attached to individual constants, and ideal activity/gas
models are not experimental validation. Downstream UI must preserve this status rather
than presenting the output as an unqualified exact result.

The scalar bisection validates its interval/tolerances and compares residual signs without
multiplication, avoiding overflow and indeterminate products for infinite endpoint residuals.
The internal gas extent solver also rejects mismatched species/stoichiometry keys and
non-finite or zero stoichiometric coefficients. Regression tests exercise infinite endpoint
residuals, invalid bisection bounds/tolerances, and unbracketed roots.

Balance units:
- aqueous fixtures report concentration-balance residuals in mol/L;
- gas fixtures report extent-update residuals in mol.

The gas helper uses only the two fixed benchmark stoichiometries. It does not
perform a general elemental-matrix rank check; atom conservation follows from
those hard-coded balanced reactions. A future general reaction API must validate
stoichiometry and elemental conservation independently before solving.


## Cross-agent integration boundary (reviewed 2026-11-02)

This branch is an executable **fixture prototype**, not the normative A3
EquilibriumProblem/EquilibriumResult contract. The repository's round-1 review
proposals and integrator decision register still leave public DTOs and several
shared contracts unapproved. In particular, INT-04–09, INT-13–16, INT-19–20,
INT-22, INT-34–39 must be resolved before this module can be promoted as the
application-facing equilibrium API.

### Important semantic gaps in this prototype

- `AqueousResult.pH` is calculated as `-log10([H+]/c°)` with gamma=1. It is
  only an **ideal concentration approximation**, not thermodynamic activity pH.
  The scalar field is retained for benchmark compatibility and must not be
  exposed as an unqualified pH value by UI or downstream adapters.
- `ka`, `kw`, `ksp`, and gas `kp` are currently plain numeric arguments.
  They do not carry the A1 ThermoConstantRecord reference, source, uncertainty,
  reference temperature, applicability interval, basis, or standard-state ID.
  The fixture caller is responsible for supplying compatible values.
- The aqueous solvers implement a deliberately narrow ideal-dilute convention
  (`gamma_i = 1`, molarity scale). They do not establish a general activity
  model or ionic-strength validity range.
- The precipitation fixture is specific to neutral AgNO3/NaCl feeds and one
  AgCl(s) phase. It is not a general complementarity solver for arbitrary
  reaction networks or multiple solids.
- `SolverDiagnostics.reliability_status` is a local prototype flag, not the
  A5 ReliabilityVector. Numerical convergence, conservation residuals, input
  data quality, model applicability, and result completeness remain separate
  dimensions in the integration contract.
- Gas calculations use dimensionless partial pressures relative to 1 bar and
  ideal-gas assumptions. They do not support fugacity or conversion from
  activity-basis K without an explicit thermodynamic transformation.

### Promotion gate

Do not use this module as the public application API until the owner/integrator
approves the OpenSpec baseline and the shared contracts. Before promotion,
replace bare constant arguments with typed, provenance-linked references;
introduce a typed pH result; align error/status envelopes and units with the
shared registries; and add independently sourced numeric benchmarks with
declared conditions, uncertainty, and benchmark-specific tolerances.

The current seven fixtures remain useful as isolated regression examples.
Passing them demonstrates implementation consistency for those assumptions,
not scientific validation outside their documented domains.
