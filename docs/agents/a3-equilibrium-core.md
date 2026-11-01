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
non-finite or zero stoichiometric coefficients.

Balance units:
- aqueous fixtures report concentration-balance residuals in mol/L;
- gas fixtures report extent-update residuals in mol.

The gas helper uses only the two fixed benchmark stoichiometries. It does not
perform a general elemental-matrix rank check; atom conservation follows from
those hard-coded balanced reactions. A future general reaction API must validate
stoichiometry and elemental conservation independently before solving.
