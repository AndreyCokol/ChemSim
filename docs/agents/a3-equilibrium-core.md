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


## A1 consumer requirements — aqueous equilibrium inputs (2026-11-03)

This section answers A1's request for the minimum thermodynamic-data requirements consumed by A3. It is a model-specific consumer contract proposal, not an approval or freeze of shared DTOs. The current public functions still accept bare numeric constants; a future adapter must validate the typed records before converting them to the current scalar inputs.

### Equilibrium constants

All constants consumed by the current aqueous fixtures must be finite, positive, dimensionless values on the stated standard-state convention. A1's logical ThermoConstantRecord should expose, at minimum:

- stable constant/reaction identity and constant kind (Ka, Kw, Ksp; Kb only for a future explicit base-dissociation fixture);
- numeric value plus uncertainty and significant-figure/precision metadata;
- basis (activity or explicitly declared concentration approximation), dimensionless convention, and standard-state reference for every participating species;
- temperature at which the value applies, source-supported temperature interval, and pressure interval when the source/model says pressure is relevant;
- solvent/medium, phase assignment, and activity-model identifier or explicit ideal-model applicability statement;
- source identity/version/date/retrieval metadata, method, quality/status, and provenance classification.

Current fixture-specific semantics:

| Constant | Equilibrium represented | Current A3 convention |
|---|---|---|
| Ka (weak acid) | HA(aq) ⇌ H+(aq) + A−(aq) | Dimensionless activity constant approximated by concentration ratios using c° = 1 mol/L and gamma_i = 1 |
| Ka (ammonium) | NH4+(aq) ⇌ NH3(aq) + H+(aq) | Same ideal concentration convention; the implementation consumes Ka(NH4+), not Kb(NH3) |
| Kw | H2O(l) ⇌ H+(aq) + OH−(aq) | Dimensionless water-ionization constant on the same aqueous standard-state convention; water activity is treated as unity |
| Ksp (AgCl) | AgCl(s) ⇌ Ag+(aq) + Cl−(aq) | Dimensionless activity product approximated by ([Ag+]/c°)([Cl−]/c°); pure AgCl solid activity is unity |

A Kb record is not currently consumed by any public A3 fixture. Do not silently pass Kb where Ka is expected. A future adapter may derive Ka = Kw/Kb only when both records refer to the same temperature, solvent, standard-state/activity convention and compatible species reaction; it must preserve both source records and the derived-value provenance.

The current aqueous functions do not accept temperature as an argument. Therefore their numeric Ka/Kw/Ksp values are assumed already evaluated at one mutually compatible declared condition. This is a known API limitation, not permission to assume 25 °C or to ignore source applicability. Until a temperature-aware API exists, an adapter must reject records whose declared conditions do not match the selected calculation condition, and must not claim A3 has independently applied a temperature correction.

### Species identity and aqueous conventions

For the current fixtures, each species input/term needs a stable identity or unresolved FormulaAST descriptor, formula/composition, integer net charge, and phase. A3 specifically uses aqueous H+, OH−, A−, HA, NH4+, NH3, Ag+, Cl−, Na+, NO3− and the solid AgCl(s). Phase is chemically material: AgCl(aq) and AgCl(s) are not interchangeable.

The current numerical vocabulary uses H+ as the aqueous proton species (a conventional shorthand for hydrated proton); it does not separately model H3O+ or proton hydration clusters. It treats liquid water as the solvent with unit activity and does not include H2O as an explicit solved species. A future canonical identity layer may choose H3O+ as its display/identity convention, but any mapping to A3's H+ must be explicit and must preserve charge, reaction stoichiometry and the constant's standard-state convention. Do not silently count both H+ and H3O+ as independent species.

The AgCl precipitation fixture has an additional narrow feed constraint: neutral AgNO3 and NaCl analytical feeds, with Ag_total = nitrate_total and Na_total = chloride_total within the documented relative tolerance; one AgCl(s) phase; no initial solid inventory. It is not a general precipitation/speciation network.

### Activity model and supporting data

Current A3 aqueous fixtures support only an explicitly declared ideal-dilute model with gamma_i = 1 and concentration scale c° = 1 mol/L. No ionic-strength calculation, activity-coefficient correlation, ion-size parameter, solvent dielectric model, complexation model or salinity correction is consumed. Inputs whose intended basis requires a non-ideal activity model are not compatible with the current solver and must be rejected or routed to a future capable model; they must not be silently treated as ideal.

For a future non-ideal aqueous model, A3 will need the model identifier/version and the model-specific inputs needed to compute each activity coefficient at the stated T/P/medium (potentially ionic strength, solvent composition/dielectric properties, ion-size or interaction parameters, and species charge). The exact list depends on the selected activity model and must not be guessed in the generic ThermoConstantRecord.

### Provenance and calculation eligibility

A3 needs provenance/quality dimensions preserved separately from numerical convergence and model applicability. Curated/reference or experimental values can be eligible when their source, conditions, basis and uncertainty satisfy the selected model. Calculated/estimated values may be eligible only under an explicit model policy with method and uncertainty retained. User-defined values may be used in an explicitly exploratory scenario if clearly labelled and propagated to the result; they must not be upgraded to reference/verified status. Hypothetical or unknown-origin values must not silently qualify for a reference/validated result. License/redistribution status governs catalog packaging, not the mathematical validity of an already supplied value, and should remain a separate gate.

The current fixture API has no provenance parameter and cannot enforce these policies itself. Until the typed adapter and result metadata are approved, the caller is responsible for not passing ineligible constants; the result must continue to be labelled as an idealized prototype result.

### Failure semantics required at the A3 boundary

Before calling the scalar solver, the adapter must reject a missing constant, non-finite/non-positive value, non-dimensionless or incompatible basis, absent/ambiguous standard state, incompatible solvent/phase, incompatible temperature/applicability interval, unsupported activity model, or invalid species charge/phase identity. Unit/basis conversion is allowed only when the required conversion data and validated thermodynamic transformation are present. No default basis, 25 °C, gamma=1, H+/H3O+ mapping, or missing value = zero may be inferred from an incomplete record.

The existing low-level EquilibriumInputError is the current fixture's input-failure signal; mapping it to the shared ErrorEnvelope is an integrator decision. Numerical non-representability/non-convergence remains EquilibriumConvergenceError. This mapping is provisional and does not define the shared application error DTO.

### Gas benchmark note

For completeness, G01/G02 consume dimensionless Kp on p° = 100,000 Pa (1 bar), using ideal-gas partial pressures p_i = n_i RT/V and no fugacity coefficients. The reaction quotient is formed from p_i/p°. Kp must therefore declare pressure standard state, reaction stoichiometry, temperature/applicability and ideal-gas model. The current gas functions accept T and V, but do not perform fugacity or non-ideal gas corrections.


## A2 parser/balancer consumer boundary (2026-11-03)

A3 consumes reaction semantics, not reaction text. The current seven fixture functions do not yet accept A2 DTOs; they take explicit analytical totals and scalar constants. A future adapter between A2 and a generalized A3 problem should require:

- validated FormulaAST/species descriptor with elemental composition and integer net charge;
- phase as a separate occurrence-level field (AQUEOUS, SOLID, LIQUID, GAS, or explicitly UNSPECIFIED); do not infer UNSPECIFIED;
- positive integer stoichiometric coefficient, side/direction, and preserved source-term identity/duplicate-term provenance;
- validated reaction balance (element and charge) from A2, or an independently repeated validation at the A3 boundary before constructing a closed-system equilibrium problem;
- explicit equilibrium-constant reference and its direction/basis/standard-state metadata from the thermodynamic-data layer. A reversible arrow is not itself a K value, and A3 must not infer K from the arrow or stoichiometric coefficients.

A3 does not require a catalog Substance ID for every parsed species: unresolved parsed descriptors can participate in a hypothetical calculation if the formula, composition, charge and phase are valid and the model has the required thermodynamic data. If a model requires a catalog-backed constant/species property, the adapter must report that unresolved lookup as a missing required input rather than fabricate an identity.

The A2 parser's current term_id is parse-local (source-offset based), not a stable cross-edit identity. A3 must not use it as a persistent species/reaction key. Duplicate terms must preserve source-term mapping when A2 aggregates them; A3's stoichiometric matrix may aggregate chemically identical species only after phase and identity equivalence are established, and must retain the mapping needed for diagnostics/provenance.

For aqueous fixture compatibility, the adapter must map the A2 phase vocabulary explicitly and preserve the current A3 conventions: H+ is the solver's hydrated-proton shorthand, OH− is explicit, liquid water has unit activity and is not a solved species, and the current AgCl precipitation fixture only supports AgNO3/NaCl neutral feeds plus one AgCl(s) phase. A2 syntax support alone does not establish that a species or reaction is supported by an A3 thermodynamic model. In particular, unsupported complexes/hydrates/radicals or unknown phase must fail explicitly.

No A2 files or DTOs are changed by this consumer-boundary note. Canonical phase enum, persistent reaction/term IDs, DTO versioning and the parser-to-solver adapter call site remain integrator decisions.


## A5 presentation/consumption boundary (2026-11-03)

The current Python prototype exposes AqueousResult with species_mol_l, concentration-based pH, SolverDiagnostics, and optional solid_mol_l; gas fixtures expose GasResult with species amounts, partial pressures in Pa, total pressure in Pa, extent in mol, and diagnostics. These are implementation dataclasses, not stable Godot DTOs or an approved serialization contract.

For any future A5 adapter, preserve at least:

- each species identity and phase, numeric value, explicit unit/basis, and whether it is dissolved/solid/solvent;
- pH value together with its basis/model qualifier (current value is -log10([H+]/c°) under gamma=1, not thermodynamic activity pH);
- solid amount and active/inactive phase status, without fabricating a solid inventory where none was supplied;
- equilibrium residual, component-balance residual, charge-balance residual, their units/scaling, solver method and iteration count;
- input-data provenance/quality and model applicability separately from numerical convergence;
- warnings/limitations and a typed termination/error status; do not map missing diagnostics or non-finite results to zero or success.

An equilibrium solve produces a single equilibrium state, not a time series. A5 must not synthesize a time axis, graph series or kinetic history from an A3 result. Parameter sweeps or scenario comparisons, if later requested, need their own explicit input dimensions and result metadata and are not interchangeable with A4 kinetic trajectories.

Until shared DTOs, Unit Registry, ErrorEnvelope, schema version and ReliabilityVector are approved, A5 should treat these outputs as unavailable for normative integration; a presentation prototype may show clearly labelled placeholders or a specifically versioned local adapter, but must not claim compatibility with the final API. A3 does not define A5 UI behavior or change A5-owned files.
