# A3 general equilibrium core: contract draft

Status: design contract for review; not an application-facing API. The benchmark functions in `src/chemsim/equilibrium.py` remain the supported implementation until this contract is accepted and tested.

## Scope

The next generalization should cover a closed, isothermal, homogeneous ideal-mixture equilibrium system. It must not silently imply support for activity coefficients, multiple phases, kinetics, or arbitrary thermodynamic models. Phase appearance is a separate extension.

## Core objects

- **Species**: stable identifier, phase, charge, and an elemental-composition map. Thermodynamic activity construction belongs to a model adapter, not to the species identity.
- **Reaction**: signed stoichiometric coefficients keyed by species ID; reactants negative, products positive; dimensionless equilibrium constant with an explicit standard-state/basis descriptor and source/provenance.
- **System**: ordered species and reactions, initial analytical totals, optional charge constraint, and a declared thermodynamic model.
- **Result**: species amounts/concentrations, reaction extents, residual diagnostics, termination status, and model/reliability metadata. Do not collapse numerical convergence, conservation, input-data quality, and model applicability into one boolean.

## Required pre-solve validation

1. Every reaction coefficient is finite and nonzero; every referenced species exists.
2. For every reaction and every element, the stoichiometric sum of elemental counts is zero. If charges are modeled, reaction charge sum must also be zero.
3. Each initial amount/total is finite and non-negative; units and basis are explicit and consistent.
4. Each equilibrium constant is finite, positive, dimensionless, and carries its standard-state/basis metadata.
5. Reject underdetermined or rank-deficient constraints explicitly, or report the rank deficiency and require an explicit policy. Never silently regularize.
6. A species absent from the initial mixture may still be a product; positivity must be enforced by the solver, not by rejecting that species at input.

## Mathematical formulation

Let `N` be the species-by-reaction stoichiometric matrix, `n0` the initial species-amount vector, and `ξ` the reaction-extent vector:

`n = n0 + N ξ`.

For a closed system, elemental conservation is `A n = b`, where `A` is the element-by-species composition matrix and `b = A n0`. Charge balance is an additional constraint only when the declared system requires electroneutrality; it must not be inferred for arbitrary isolated gas systems.

At equilibrium, each independent reaction satisfies:

`ln Q_r = Σ_i N[i,r] ln(a_i) = ln K_r`.

Activities `a_i` must be dimensionless and derived from the declared model and standard state. The ideal-dilute aqueous and ideal-gas benchmark assumptions are adapters, not universal defaults.

## Numerical and diagnostic requirements

- Maintain feasible non-negative species amounts; use a positivity-preserving parameterization or a constrained method.
- Check element and charge residuals independently from equilibrium residuals.
- Report convergence status, iteration count, method, scaled residuals, and any active constraints.
- Detect dependent reactions / redundant equations before solving; report the independent reaction rank.
- A successful numerical solve does not establish that the chosen thermodynamic model is physically applicable.
- Keep units explicit in diagnostics. Do not label concentration-based ideal pH as thermodynamic activity pH.

## Phase equilibrium boundary

A solid phase requires an explicit inventory/reservoir model and complementarity conditions. For a candidate solid, define amount `s >= 0` and saturation index `SI = ln(Q/Ksp)`. The active-set conditions are `s >= 0`, `SI <= 0` for absent solid, and `s * SI = 0` at equilibrium (with sign convention documented consistently). A solid cannot be created or consumed without a defined inventory and component balance.

This contract does not yet specify multiple solids, aqueous complexation, nonideal activity models, or gas fugacity. Those require separate model and validation work.

## Acceptance tests for the general core

- Reject a reaction that violates any elemental balance, even if its scalar equilibrium equation has a root.
- Reject a charge-nonconserving reaction when charge is declared.
- Accept a valid reaction that creates a product absent initially.
- Verify `A n = b` and `Nᵀ ln(a) = ln(K)` within documented scaled tolerances.
- Detect linearly dependent reactions and produce a stable, explicit diagnostic.
- Reject missing/inconsistent standard-state metadata.
- Exercise near-zero inventories without producing negative amounts or silently clipping material.
- For a phase extension, test both inactive and active solid cases and verify component balances and complementarity.

## Integration gate

Before exposing this as a public ChemSim DTO/API, reconcile species IDs, units, error envelopes, reliability metadata, and ownership of thermodynamic data with the A1 data contract, A2 parser output, and A5 UI/integration contract. Until then, keep this as a design boundary and preserve the fixture API.
