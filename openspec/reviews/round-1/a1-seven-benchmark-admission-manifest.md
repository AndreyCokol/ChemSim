# A1 — Seven-benchmark data admission manifest (template)

Status: **TEMPLATE / PROPOSAL — NO BENCHMARK DATA ADMITTED**
Branch: `openspec/review-round-1`
Owner: A1 — Chemistry Data & Domain
Scope: admission evidence for the seven current aqueous/gas MVP benchmarks. This document is a blank manifest and gate definition, not a fixture file, numerical dataset, shared DTO, import allowlist, or baseline approval.

## 1. Admission rule

A benchmark row is admitted only when every model-critical field is backed by an exact source assertion (or an explicitly documented non-source input where the model requires one), its identity/units/basis/conditions are compatible with the named model version, uncertainty and provenance are represented honestly, the model-specific eligibility decision is recorded, and the intended distribution channel is permitted.

A row may be:
- `ready_for_local_validation`: scientific/model gates pass, but redistribution may still be blocked;
- `ready_for_redistributable_fixture`: scientific/model gates and rights for the exact fixture distribution channel both pass;
- `blocked_missing_evidence`: required value, identity, basis, condition, uncertainty, method, or provenance evidence is absent/ambiguous;
- `blocked_inapplicable`: evidence exists but does not apply to the selected model/version/conditions;
- `blocked_license`: intended use is not authorized or rights are unknown/restricted;
- `not_assessed`: admission review has not been performed.

These are logical review labels for this manifest only, not proposed shared wire enums.

## 2. Required fields for every benchmark row

| Field | Required content |
|---|---|
| benchmark_id / revision | Stable benchmark key and manifest revision |
| model_owner / model_version | A3 or A4 and exact consuming model/fixture version |
| reaction_or_scenario | Exact balanced reaction/scenario and declared model interpretation; do not infer it from a label |
| species_refs | Stable selected catalog refs, formula/composition/charge evidence, and phase per occurrence; unresolved identity blocks admission |
| required_assertions | Each required property/constant/initial feed value as a separate assertion reference |
| numeric_value | Finite numeric value and retained source precision; booleans/strings/NaN/infinity rejected |
| unit_dimension | Explicit unit and physical dimension; conversion path and contextual inputs if conversion is required |
| basis_standard_state | Property-specific basis, standard state and dimensionless convention where relevant |
| medium_phase | Explicit medium and phase applicability for every relevant assertion |
| conditions | Required T/P and applicability interval; never supply an assumed temperature or inferred phase |
| uncertainty_precision | Reported uncertainty/method or explicit not-reported state; never replace missing uncertainty with zero |
| provenance | Source, exact record/field, source version/edition, publication/effective date, retrieval timestamp, method and parent assertions for derived values |
| origin_quality_review | Independent origin, quality assessment and version-bound review decision |
| model_eligibility | Model/version-specific decision, policy version, reasons and checked conditions |
| redistribution | Exact intended channel, license evidence, attribution/share-alike obligations and disposition |
| tests | Positive and negative A1 test IDs with evidence/result |
| admission | Status, blocker reason, reviewer and review timestamp |

## 3. Seven benchmark rows — blank admission register

| ID | Scenario | Required data and explicit constraints | Current blocker / do not assume |
|---|---|---|---|
| AQ-01 | Acetic acid dissociation | Ka for HA ⇌ H⁺ + A⁻; current A3 convention: dimensionless ideal-dilute constant, c°=1 mol/L, gamma=1; compatible declared T and aqueous medium; H⁺ is A3's hydrated-proton shorthand | No numeric value/source/rights selected; no assumed 25 °C; no non-ideal applicability |
| AQ-02 | Strong-electrolyte neutralization | Explicit feed representation, dissociation/species mapping, initial analytical totals/amounts and spectator-ion bookkeeping required by the exact A3 scenario | Exact A3 feed-to-species contract still requires confirmation; do not invent a weak-acid/base constant or infer neutral-feed behavior |
| AQ-03 | AgCl solubility | Ksp for AgCl(s) ⇌ Ag⁺ + Cl⁻; solid activity 1; current quotient approximation ([Ag⁺]/c°)([Cl⁻]/c°); c°=1 mol/L, gamma=1 | No numeric value/source/rights selected; no phase or temperature substitution; no non-ideal model |
| AQ-04 | Ammonia acid/base equilibrium | Current A3 fixture consumes Ka(NH₄⁺) for NH₄⁺ ⇌ NH₃ + H⁺, not Kb(NH₃); any derived Ka must retain Kw/Kb parents, method and compatible conditions | No numeric value/source/rights selected; do not pass Kb as Ka or derive without compatible conditions |
| AQ-05 | AgCl precipitation | AgCl Ksp with same convention as AQ-03; explicit initial feed totals and spectator-ion bookkeeping; current A3 fixture assumes neutral AgNO₃/NaCl feeds | No numeric value/source/rights selected; do not generalize neutral feeds to arbitrary ionic feeds |
| GAS-01 | NO₂/N₂O₄ gas equilibrium | Dimensionless Kp; p°=1 bar; ideal partial pressures pᵢ=nᵢRT/V; no fugacity coefficients | No numeric value/source/rights selected; no non-ideal gas applicability |
| GAS-02 | H₂/I₂/HI gas equilibrium | Dimensionless pressure-standard-state equilibrium constant; p°=1 bar and ideal partial pressures for current A3 gas core; explicit iodine phase at selected benchmark temperature | No numeric value/source/rights selected; iodine phase and benchmark T unresolved; do not infer I₂(g) or I₂(s) |

## 4. A4 kinetic data admission sub-record

If a future manifest revision adds an A4 kinetic scenario, do not reuse an equilibrium-constant row. Record separately:
- rate-law/model version and volumetric rate definition;
- concentration basis cᵢ=nᵢ/V in mol·m⁻³ for the current A4 slice;
- explicit kinetic-order vector αᵢ, independent of stoichiometric coefficients;
- k value and concentration exponent 1−Σα, with time basis;
- fixed-volume/isothermal applicability for the current model;
- A1-owned source/provenance, uncertainty, origin, quality, review and redistribution evidence;
- exact A4 adapter validation evidence.

A4's current RateConstant implementation stores Value and ConcentrationExponent; it does not itself certify A1 provenance, uncertainty, quality or license. Equilibrium K/Ka/Kb/Ksp/Kp must never be substituted for kinetic k.

## 5. Test ID convention

Use stable IDs in a future populated manifest; IDs below define required coverage, not tests already executed.

### Positive
- `A1-MAN-IDENTITY-POS`: selected stable identity has matching formula/composition/charge and explicit phase occurrence.
- `A1-MAN-PROPERTY-POS`: finite value, unit/dimension, basis, conditions and provenance are complete and compatible.
- `A1-MAN-DERIVED-POS`: derived assertion retains all parents, method/version, transformations and uncertainty.
- `A1-MAN-ELIGIBILITY-POS`: named model/version policy accepts only after all required checks.
- `A1-MAN-LICENSE-POS`: exact field and intended distribution channel have documented permission/obligations.
- `A1-MAN-LOCAL-ONLY-POS`: scientifically eligible data may be used in an explicitly local-only validation path without entering a redistributable bundle.

### Negative
- `A1-MAN-IDENTITY-NEG`: unresolved formula, composition/charge mismatch or guessed phase blocks admission.
- `A1-MAN-NUMERIC-NEG`: missing, boolean, string, NaN or infinite numeric value blocks calculation.
- `A1-MAN-UNIT-NEG`: incompatible dimension or unsupported conversion (including molarity↔molality without required contextual data) blocks admission.
- `A1-MAN-BASIS-NEG`: bare K/Ka/Kb/Ksp/Kp or k without model-required basis/metadata blocks calculation.
- `A1-MAN-CONDITION-NEG`: missing/out-of-range T/P, medium or phase blocks the affected model.
- `A1-MAN-UNCERTAINTY-NEG`: unreported uncertainty is not silently set to zero or treated as verified.
- `A1-MAN-PROVENANCE-NEG`: unknown source field/version/origin blocks promotion to curated/verified.
- `A1-MAN-ELIGIBILITY-NEG`: model-inapplicable, conflicting, hypothetical or unknown-origin assertion is not silently accepted.
- `A1-MAN-LICENSE-NEG`: unknown/restricted license blocks redistributable bundle admission.
- `A1-MAN-HAZARD-NEG`: missing hazard record or H/P statement never implies safety.
- `A1-MAN-PHASE-GAS02-NEG`: unresolved iodine phase blocks GAS-02 admission.
- `A1-MAN-ASSUMPTION-NEG`: no assumed 25 °C, guessed constants, inferred phase, or silent default basis.

## 6. Population and sign-off protocol

For each row, populate the required fields with exact evidence references. If any required evidence is unavailable, retain the row and record a blocker; do not omit the benchmark or fabricate a value. The A1 reviewer signs only the semantic data/provenance/eligibility/license gate. A3/A4 sign their model adapters and model applicability; A2 signs parser/identity boundary behavior; integrator signs shared serialization/unit/error compatibility; product owner approves the OpenSpec baseline.

## 7. Current disposition

All seven rows are currently **not admitted**. This is an evidence status, not a claim that the chemistry is invalid. No numerical constants, source-field pairs, licenses, or fixture payloads are selected or approved by this template.
