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
