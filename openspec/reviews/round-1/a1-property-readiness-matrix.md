# A1 — Property readiness and calculation-gate matrix

Status: **RESEARCH / PROPOSAL — NOT A FIXTURE, NOT A SHARED DTO, NOT AN IMPORT ALLOWLIST**  
Branch: `openspec/review-round-1`  
Scope: A1-owned data/domain requirements. A2 owns parsing/balancing; A3 owns equilibrium-model behavior; A4 owns kinetic-model behavior; A5 owns UI presentation; shared serialization/error/unit decisions belong to the integrator.

## 1. Purpose and decision rule

This matrix turns the seven owner-approved benchmark scenarios into field-level readiness gates. It deliberately distinguishes:
- **identity readiness** — can the entity/species be identified consistently;
- **descriptive readiness** — can a partial catalog/property record be stored or displayed with honest status;
- **calculation readiness** — does a particular model have every required compatible input;
- **redistribution readiness** — may the exact source field legally be bundled.

A record may be descriptively valid while calculation-ineligible or redistribution-blocked. No missing field is replaced with zero, a guessed phase, an assumed temperature, a default basis, or an inferred safety statement.

## 2. Cross-cutting property gates

| Field group | Required evidence / semantics | Missing or incompatible behavior | Current status |
|---|---|---|---|
| Subject identity | Stable catalog ID only after explicit lookup/selection; formula/composition/charge consistent; phase attached to species/reaction occurrence, not catalog identity | Keep unresolved FormulaAST/descriptor; do not mint an ID from formula or auto-register | A2 accepted A1 boundary in PR #5 comment 6599229884 |
| Numeric value | Finite numeric value; preserve source precision/significant figures | Reject NaN, ±Infinity, boolean-as-number, malformed string, and missing value for calculation | A1 proposal |
| Unit and dimension | Explicit unit and compatible physical dimension; conversion retains source and transformation provenance | Reject missing/incompatible unit; never convert between unlike dimensions by symbol/string matching | A1 proposal |
| Basis / standard state | Explicit property-specific basis and standard-state convention wherever model requires it | Calculation-ineligible if absent or incompatible; no silent activity↔concentration or pressure↔fugacity conversion | A3 supplied fixture convention; general rules remain model-specific |
| Conditions | Explicit T/P/phase/medium and applicability interval where relevant | Reject missing/out-of-range/incompatible conditions; no assumed 25 °C | A3 current fixture boundary |
| Uncertainty / precision | Reported uncertainty or explicit “not reported”; retain significant digits | Absence is unknown, not zero uncertainty; model policy decides eligibility | A1 proposal; source values not selected |
| Provenance | Source identity, exact record/field, version/date, retrieval time, method, source license evidence | Unknown provenance cannot be promoted to verified/reference; redistribution blocked if rights unclear | A1 source memo |
| Quality / origin | Keep origin, quality, applicability, convergence, and license as independent dimensions | User-defined remains visibly exploratory; hypothetical/unknown-origin cannot silently become validated | A1 proposal; A3 confirms adapter must enforce |
| Model applicability | Model/version, rate/equilibrium law, assumptions, supported domain | Unsupported model/condition rejected rather than silently simplified | A3 fixture constraints; A4 exact metadata response pending |

## 3. Benchmark-specific readiness

| Benchmark | Calculation-critical property/data | Additional conditions | Fail-closed condition | Evidence status |
|---|---|---|---|---|
| AQ-01 acetic acid | Ka for HA ⇌ H⁺ + A⁻; dimensionless ideal-dilute convention for current A3 fixture | c°=1 mol/L, gamma=1, compatible declared T and aqueous medium; H⁺ is current hydrated-proton shorthand | Reject bare Ka, incompatible basis, missing T/medium, or unsupported activity model | Convention clarified by A3; no numerical value/source/rights selected |
| AQ-02 neutralization (A3 W02) | Explicit fully dissociated HCl/NaOH input as finite nonnegative `hcl_mol_l` and `naoh_mol_l` (not both zero), spectator species mapping and **typed positive dimensionless Kw** | A3 `solve_strong_neutralization(hcl_mol_l, naoh_mol_l, kw)` requires Kw for water autoionization; `c°=1 mol/L`, `gamma=1`; compatible T/provenance/standard state and source eligibility must be validated upstream; no Ka/Kb invented | Reject absent/mismatched Kw, ambiguous molecular-vs-ionic feed mapping or incomplete initial state; never infer a default Kw | Exact A3 source signature verified 2026-11-03; no admissible Kw source/value/rights yet; A3 numeric tests are not catalog provenance |
| AQ-03 AgCl solubility | Ksp for AgCl(s) ⇌ Ag⁺ + Cl⁻; solid activity 1; Q approximation uses ([Ag⁺]/c°)([Cl⁻]/c°) | c°=1 mol/L, gamma=1, compatible T/medium; solid and dissolved species phases distinct | Reject bare/incompatible Ksp, wrong solid identity/phase, missing condition or non-ideal model | Convention clarified by A3; no numerical value/source/rights selected |
| AQ-04 ammonia | Current fixture consumes Ka(NH₄⁺) for NH₄⁺ ⇌ NH₃ + H⁺, not Kb(NH₃) | Compatible convention/conditions; any Ka derived from Kw/Kb must preserve derivation provenance and compatible conditions | Reject Kb supplied as if directly consumed, or derived Ka without validated compatible conversion | A3 clarified current fixture semantics; no value/source/rights selected |
| AQ-05 precipitation | Same AgCl Ksp semantics as AQ-03 plus initial salt-feed totals and spectator-ion bookkeeping | A3 current fixture assumes neutral AgNO₃/NaCl feeds; gamma=1; solid activity 1 | Reject incompatible AgCl Ksp record/conditions, ambiguous feed semantics, or silent generalization to arbitrary ionic feeds | A3 limitation documented; exact numerical/source data absent |
| GAS-01 NO₂/N₂O₄ | Dimensionless Kp | p°=1 bar; ideal-gas partial pressures pᵢ=nᵢRT/V; no fugacity coefficients | Reject non-dimensionless/unqualified Kp, missing standard pressure or unsupported non-ideal gas use | A3 convention clarified; no numerical value/source/rights selected |
| GAS-02 H₂/I₂/HI | Equilibrium K with the same explicitly documented pressure-standard-state convention for current gas core | p°=1 bar, ideal partial pressures; iodine phase at selected benchmark T must be explicitly confirmed | Reject I₂(s) data when I₂(g) is required, or phase/T mismatch | Kp convention clarified; iodine phase and selected T unresolved |

## 4. A3-specific adapter acceptance requirements

For the current aqueous reference core, the adapter-facing data checks must enforce:
1. finite, positive equilibrium constants;
2. explicit reaction/constant identity and compatible basis/standard state;
3. explicit compatible temperature and medium; A3 does not calculate temperature corrections or assume 25 °C;
4. explicit phase and integer charge with a stable identity or unresolved descriptor;
5. explicit ideal-dilute gamma=1 applicability; do not accept non-ideal/activity-basis records as interchangeable;
6. explicit proton convention: current H⁺ shorthand, OH⁻, liquid water as solvent with unit activity, and no independent H₃O⁺ species;
7. no defaulting missing values to zero or inventing proton mapping;
8. preserve origin, quality, applicability and license independently;
9. preserve derivation provenance for any compatible Ka derived from Kw/Kb;
10. map invalid input and numerical convergence failure distinctly at the future adapter boundary; shared ErrorEnvelope mapping remains an integrator decision.

Current low-level A3 error names are `EquilibriumInputError` and `EquilibriumConvergenceError`; these are evidence about current implementation, not a shared error schema.

## 5. A4 kinetic-property dependency — still open

The current A4 benchmark model documents nᵢ in mol, cᵢ=nᵢ/V in mol·m⁻³, fixed volume/isothermal scope, volumetric power-law rate and explicit non-negative real orders independent of stoichiometry. Consequently, a calculation-ready rate constant cannot be represented by an unqualified scalar `k`: its dimension depends on the rate-law form and sum of kinetic orders.

A1 asked A4 in PR #6 comment 6599428166 to confirm: rate-law/model version, concentration basis/unit, order vector or stable reference, resulting k dimension, applicability conditions, provenance/quality, and user-defined-value policy. No A4 confirmation or canonical contract path was present in the latest reviewed PR #6 comments. Until A4 responds, those are provisional A1 requirements, not a frozen RateConstant schema. No Arrhenius/T dependence should be presumed in the current fixed-isothermal baseline.

## 6. Hazard and redistribution cross-gates

- Hazard completeness remains `not_assessed`, `absent`, `partial`, or `complete_for_declared_scope`; the last state is bounded by declared source/jurisdiction/scope and never means universally safe.
- A5 has not yet answered A1's exact HazardRecord consumer question (PR #3 comment 6599360808). A1 therefore retains its proposed source/date/scope/missing-section semantics without claiming UI acceptance.
- Scientific/calculation eligibility does not grant redistribution rights. Every imported field needs exact source/record/field provenance and license disposition. Unknown/restricted license blocks bundling while allowing research notes to retain a citation.
- No source/property pair or numerical benchmark constant is approved for redistribution by this matrix.

## 7. A1 acceptance test inventory (specification-level)

Positive cases:
- a verified property with finite value, compatible unit/dimension, explicit basis/conditions, source field and permitted license is eligible only for a model whose requirements it satisfies;
- a user-defined value can be retained as descriptive/exploratory while carrying its user-defined origin into dependent outputs;
- a partial hazard record retains its declared scope and missing sections.

Negative cases:
- bare Ka/Kb/Ksp/Kp or k without model-specific basis/metadata is not calculation-ready;
- missing T, unsupported activity model, phase mismatch, or out-of-range applicability blocks the relevant calculation;
- boolean, string, NaN, infinity, missing value, incompatible unit/dimension, or unknown basis is rejected for numeric calculation;
- mol/L↔mol/kg, mass↔amount, amount↔concentration, or pressure↔activity conversion without required contextual data is rejected;
- unresolved formula does not receive a fabricated catalog ID;
- absent hazard data or absent H/P statements never produces “safe”;
- unknown/restricted license never enters a redistributable bundle;
- an A3 benchmark-local convention is never promoted to a universal chemistry default.

## 8. Explicit non-decisions

This matrix does not choose numerical values, sources, licenses, I₂ benchmark temperature/phase, common DTO field names, shared enum wire tokens, Unit Registry, ErrorEnvelope, schema version, solver behavior, or OpenSpec baseline approval.
