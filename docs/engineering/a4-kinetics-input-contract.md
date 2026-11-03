# A4 kinetics input and rate-constant contract (implementation snapshot)

**Status:** A4 consumer-side contract note; not a shared DTO freeze and not an approval of the OpenSpec baseline.

This note describes the implemented A4 slice on `feature/a4-kinetics-core`. It is intended to answer the A1/A2 consumer questions without taking ownership of their domain or parser schemas.

## 1. Supported kinetic model

The current solver integrates a closed, well-mixed, constant-volume, isothermal system. Species state is represented as amounts (n_i) in mol; concentrations are (c_i=n_i/V) in mol·m⁻³. The reaction rate is a volumetric rate:

`r_j = k_j × ∏ c_i^{α_{ij}}`

where `r_j` is in mol·m⁻³·s⁻¹ and each `αᵢⱼ` is an explicit, finite, non-negative kinetic order. Kinetic orders are independent of stoichiometric coefficients and must never be inferred from a balanced equation, coefficient, or arrow.

For total kinetic order `m = Σ αᵢⱼ`, the required rate-constant dimension is:

`[k] = (mol·m⁻³)^(1−m)·s⁻¹`

Equivalently, the stored concentration exponent is `1−m`. Examples:
- zero order: `(mol·m⁻³)^1·s⁻¹`;
- first order: `s⁻¹`;
- second order: `(mol·m⁻³)^−1·s⁻¹`;
- half order: `(mol·m⁻³)^0.5·s⁻¹`.

The implementation's volume scaling converts volumetric rate to reaction extent rate (mol·s⁻¹). The state derivative is then assembled from stoichiometry. This is not a thermodynamic equilibrium constant and does not accept `K`, `Ka`, `Kb`, `Ksp`, or `Kp` as kinetic parameters.

## 2. Actual A4 API fields today

- `ReactionDefinition`: reaction identifier, stoichiometric coefficients, explicit kinetic-order map keyed by species ID, and `RateConstant`.
- `RateConstant`: `Value` and `ConcentrationExponent`. Validation checks finite positive value, finite exponent, and agreement with `1 − Σα` within the implementation tolerance.
- `SimulationRequest`: `ReactionNetwork`, exact initial amount for every network species in mol, positive volume in m³, finite start/end times in seconds, output interval in seconds, and solver tolerances/step limits.
- `SimulationResult`: status, published state samples (time in seconds and amounts in mol), and diagnostics (accepted/rejected steps, RHS evaluations, optional message). `IsSuccess` is true only for `Success`.

The current `RateConstant` is deliberately a narrow numerical value + dimensional exponent. It does **not** yet carry a unit symbol, explicit time-basis enum, temperature, activation energy, reference temperature, medium/phase, source/provenance, uncertainty, quality/review state, validity range, or redistribution disposition. Do not imply that those fields are present or validated by A4.

## 3. Required adapter checks before constructing A4 objects

An integration adapter must fail closed unless all of the following are established from upstream typed data:

1. Reaction/species identities are valid and unique for the request; every referenced kinetic-order species belongs to the network.
2. Stoichiometric coefficients are finite integers with the A4 sign convention (reactants negative, products positive); kinetic orders are separately supplied, finite and non-negative.
3. Initial amounts cover exactly the network species set, are finite and non-negative, and are converted to mol without silently assuming missing units.
4. Volume is finite, positive and explicitly converted to m³.
5. The parameter is explicitly identified as a kinetic rate constant for a volumetric power law, not an equilibrium constant or an unrelated empirical coefficient.
6. Its source unit is convertible to `(mol·m⁻³)^(1−Σα)·s⁻¹`; reject unknown/incompatible dimensions and reject mol/L, molality, pressure, or alternate time bases unless an explicit, dimensionally correct conversion is available.
7. Temperature/model applicability is compatible with the current fixed-isothermal run. The current A4 implementation does not apply Arrhenius or other temperature correction; no implicit default temperature or extrapolation is performed by A4.
8. Upstream provenance, uncertainty, quality/review state, validity range and license/redistribution eligibility are retained and checked by the owning domain/data layer. A4's current numeric type cannot certify these conditions.

Missing metadata must not be silently filled with guessed units, guessed reaction order, guessed temperature, or default scientific provenance.

## 4. Output and partial-result semantics

A4 can return samples together with a non-success status when a run stops after a valid prefix (for example, a step budget is exhausted after one completed output segment). Consumers must inspect `Status`; they must not treat a non-empty sample list or `IsSuccess == false` as a completed trajectory. The adapter/UI should preserve the terminal status and diagnostics and clearly mark the returned samples as partial. No extrapolation to the requested end time is implied.

The present result contract is solver-local. It is not yet the application-wide `ErrorEnvelope`, `ReliabilityVector`, graph-series, event-history, or replay contract. Those shared envelopes and mappings require integrator/owner decisions.

## 5. Explicit non-goals of this contract note

No shared DTOs, enum wire tokens, Unit Registry, parser AST, catalog schema, equilibrium API, Godot UI, or OpenSpec baseline are changed or frozen here. Reversible kinetics, Arrhenius dependence, variable volume/open systems, discrete events, and implicit stiff solvers remain outside this A4 implementation slice.
