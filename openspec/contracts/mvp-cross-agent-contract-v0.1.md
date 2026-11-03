# ChemSim: integrator cross-agent contract v0.1 (candidate baseline)

**Date:** 2026-11-03. **Owner of cross-cutting decisions:** Chief Integrator (delegated by product owner for this task).  
**Status:** **INTEGRATOR-DECIDED / PENDING OWNER OPENSPEC APPROVAL**. Not an approved public runtime API, not an assertion that producers already implement the fields, not permission to write new implementation code. This contract is the proposed authoritative *interchange boundary* for A1–A5 after owner approval. The A1–A4 local classes and current A5 `chemsim_ui_draft` v1 remain separate until adapters and integration tests pass.

**Source:** `openspec/reviews/round-1/integrator-decision-register.md` (INT-01–48), A1 domain schema proposal, A2 FormulaAST proposal, A3 equilibrium/result proposal and actual fixture shape, A4 .NET 10 kinetics input/result notes, A5 consumer readiness. No speculative K/k/Ka/Ksp/uncertainty values or redistribution rights are introduced.

## 1. Versioning, identities and responsibility

1. Every interchange message includes `contract_version: "0.1"`, `message_id` (opaque UUID), `kind`, `payload`, `errors[]`; responses additionally include `request_message_id` and `outcome`. Unknown major version or unknown required kind -> `CONTRACT_UNSUPPORTED_VERSION` / `CONTRACT_UNSUPPORTED_KIND`, no fallback interpretation. `0.1` is a candidate, not an already deployed schema.
2. Each durable entity reference: `{id: string, record_revision: positive integer}`. A durable ID is opaque and stable across relabeling; document references include the exact revision. `schema_version` defines shape, `record_revision` entity content, `dataset_version` upstream dataset, `model_version` calculation assumptions, `contract_version` interchange protocol. None substitutes for another.
3. `FormulaAST` (A2) owns atom/isotope-composition semantics (only currently supported elements) and **signed integer** `net_charge`; no independent serialized `SubstanceRecord.formal_charge` truth. A1 may expose derived nonpersisted charge for display only. A2 resolves text to canonical AST; phase and quantity never live in AST.
4. `SubstanceRecord` (A1): `substance_id`, `record_revision`, `formula_ast_ref`, `origin`, `provenance`, optional verified properties. No experiment quantities or visual coordinates. `SpeciesRef` (A1/A2 agreement): `species_id`, `record_revision`, `formula_ast_ref`, `phase`. Phase enum: `s`, `l`, `g`, `aq`, `unspecified`. The `species_id` is assigned stable ID, not formula text or parse-local offset. Identity changes (formula/phase) yield a **new ID**; aliases are explicit and provenance-tracked, never a silent rewrite.
5. `ExperimentComponent` (application/A5 consumer): `component_id`, `species_ref`, `amount` as typed Quantity/Availability, and model-specific state. Visual `position` belongs only in separate `ui_layout`. Incomplete custom components can be saved; they block only models requiring missing fields.
6. `ReactionTerm`: stable `species_ref`, side `reactant|product`, positive integer `stoichiometric_coefficient`. `Reaction`: immutable `reaction_id`, `record_revision`, `reactants[]`, `products[]`, `arrow_type: forward|equilibrium`, `original_input` and source refs. Duplicate source terms retain original spans in the editor; canonical computation may aggregate terms by *exact same species ref* and side with overflow checks. Same species on both sides is permitted only if the downstream model explicitly handles it; cannot silently cancel chemically meaningful participants. A2 balance result is separate and immutable; applying it creates a new Reaction revision. Orders are **never** derived from stoichiometric coefficients.
7. Syntax for candidate v0.1: canonical explicit charges `^+`, `^-`, `^2-`, `^3+`; limited short aliases `H+`, `OH-`, `Ag+` accepted only by A2's unambiguous lexer; ambiguous `Fe3+` rejected. Canonical forward `->`, reversible `<->`; display Unicode arrows allowed only as normalized, tested aliases. Original text preserved. **Source spans** in wire messages use `utf8_byte_start` inclusive + `utf8_byte_end` exclusive over original UTF-8 bytes; UI must convert for caret selection; never assume Unicode codepoint offset equals byte offset. A2 must validate implementation mapping before acceptance.

## 2. Quantities, units and missing values (INT-13,14,40)

`Quantity = {value: finite JSON number, unit_id: registered ID, basis?: registered context, uncertainty?: typed Availability}`. `Availability = {status: present|unknown|not_reported|not_assessed|not_applicable|withheld, quantity?: Quantity}`; exactly one quantity iff status=`present`. **Measured zero** is `present` with `value:0`; unknown/absent is never zero. A JSON `null` is not an availability status. `invalid`, `stale`, `conflicting` are independent validation/freshness flags, not synonyms for missing.

Candidate common unit registry for interchange v0.1 (case-sensitive, all other IDs unsupported until registered):

| ID | Dimension / rule | Conversion |
|---|---|---|
| `1` | dimensionless | identity |
| `mol` | amount | base |
| `kg`, `g` | mass | `1 g = 0.001 kg`; mass→mol requires explicit verified molar mass, NOT a unit-only conversion |
| `m3`, `L` | volume | `1 L = 0.001 m3` |
| `s` | time | base |
| `K`, `degC` | temperature | `T[K] = T[degC] + 273.15` (affine; cannot be used for temperature *differences* without distinct unit semantics) |
| `Pa`, `bar` | pressure | `1 bar = 100000 Pa` |
| `mol/m3`, `mol/L` | concentration | `1 mol/L = 1000 mol/m3` |
| `mol/s`, `mol/(m3*s)` | amount rate, volumetric rate | rate basis must match model |
| `J/mol` | molar energy | for explicitly supported Arrhenius parameters only |

A4 current numeric backend uses **amount mol**, **volume m3**, **time s**, **concentration mol/m3**, **volumetric reaction rate mol/(m3*s)**. For explicit power-law orders sum `m`, `[k] = [mol/m3]^(1-m) * s^-1`: `k` is a *typed dimension expression*, not a universal `s^-1` unit. A1/A4 adapter validates source k dimension, basis, temperature, provenance, applicability and conversion before calling A4; none is inferred by A4's current RateConstant fields. Generalized quantity dimensions must use `dimension_exponents` (rational exponent keys) and `basis`, not a fabricated free-text unit ID.

## 3. Thermodynamics / equilibrium (INT-04–09, 34–39)

`ThermoConstantRef` must have `constant_id`, revision, reaction ref/direction, `dimensionless_value` (finite, positive), `basis`, `standard_state`, fixed `temperature`, `provenance`, `applicability`, `uncertainty_status`. Candidate MVP admissible pairs:
- `aqueous_ideal_dilute_activity_approximation`: activity ratios approximated by `c_i / c°`, with `c°=1 mol/L`, `gamma_i=1`; explicit model/version and applicability. This is **not** an independently validated nonideal activity model and must not be called universally accurate.
- `gas_ideal_partial_pressure`: dimensionless `p_i/p°` with `p°=100000 Pa` (1 bar), ideal gas `p_i=n_i RT/V`; no fugacity/nonideal corrections.

Never treat a raw numeric K, Kp, Ksp, Ka, Kb or empirical concentration constant as interchangeable. K at a different T requires validated K(T) relation and source or is blocked. Gas iodine phase must be explicitly `g` for the current H2/I2/HI fixture.

`EquilibriumProblem` specifies ordered species refs, analytical totals as quantities, chosen model/basis + standard state + conditions + constant refs. `EquilibriumResult` distinguishes species quantities `mol` versus `mol/L`, `aqueous|solid|gas` status, solid inventory vs reservoir, pH method `thermodynamic_activity|ideal_concentration_approximation|unavailable`, scaled residuals with **residual kind/units**, iteration/method, termination, data quality/applicability, warnings. `pH=-log10([H+]/c°)` is only explicitly ideal-concentration approximation. For precipitation, enforce mass/charge balance, solid nonnegative inventory or explicit infinite reservoir, and solid-saturation complementarity; one `Q/Ksp` comparison is insufficient. `ln(Q/K)` only for positive Q and K; zero boundary gets typed domain status, not `-Infinity` JSON or epsilon. An equilibrium result is **one state**, not a kinetic time series.

## 4. Kinetic request / result (INT-10–12,19,40–44)

`KineticModel`: immutable `kinetic_model_id`, revision, reaction ref/revision, `rate_law_id` (for A4 current v0.1 only `irreversible_volumetric_power_law`), `kinetic_orders[{species_ref,order}]`, `k` with dimension basis and `parameter_provenance`, temperature/phase validity. `K` is not `k`; no inferred orders; no automatic reverse rate from K. Current A4 adapter supports only closed, well-mixed, constant-volume, fixed-T **irreversible** case. Reject open flow, discrete events, reversible arrow, dynamic T, finite mixing, unsupported stiffs and missing model parameters; no silent fallback.

`SimulationRequest`: `experiment_ref/revision`, exact species and reaction refs, `initial_amounts` (mol, all species), `volume` (m3), `temperature` (K, fixed), `time_start/time_end` (s), output step (s), `solver_policy` with named tolerances and budget. `SimulationResult` carries `request_ref`, `termination` (completed|blocked|out_of_domain|step_limit|numerical_failure|invariant_violation|cancelled), `last_valid_time` as explicit availability, `samples[]`, `diagnostics` (method, version, step counts and typed residuals), `reliability`. A4 backend `Success` maps to `completed` only after structural validation; backend failures may carry a **valid prefix** but not a completed trajectory. Counters can omit in-flight cancelled work: preserve that qualification. Missing conservation-law inputs must not be misreported as chemistry conservation proof.

`GraphSeries`: stable series ID + result revision, physical quantity key, species ref if applicable, unit ID/basis, `samples[{time_s, value_status, value?}]` where `value_status: valid|missing|invalid|out_of_domain`. Only valid finite samples have values; invalid samples are **gaps**, never zero and never connected across gaps; strictly increasing time, no fabricated interpolation. Partial results label requested end versus last valid sample. **No graph from one equilibrium state**. Isothermal temperature graph is constant only where a legitimately executed isothermal simulation and explicit model metadata justify it; no fictional thermal dynamics.

## 5. Shared errors and reliability (INT-15,20)

`ErrorEnvelope = {code: stable namespaced machine code, severity: info|warning|error|fatal, message_key: string, context: object, field_path?: string, source_ref?: typed ref, source_span?: UTF-8 byte range, recoverable: bool, responsible_module: A1|A2|A3|A4|A5|INTEGRATOR, details?: typed object}`. No silently discarded errors. Producers own their **namespaced codes**, integrator owns envelope semantics; UI owns Russian presentation and suggested recovery action, not scientific diagnosis.

`ReliabilityVector = {data_quality: verified|user_supplied|hypothetical|unknown|conflicting, model_applicability: applicable|approximate|out_of_domain|unsupported|not_assessed, numerical_status: not_run|completed|completed_with_warnings|failed|cancelled|not_applicable, completeness: complete_for_declared_scope|partial|absent|not_assessed, warnings: ErrorEnvelope[]}`. This is a **set of independent labels**, not a probability or a percentage of accuracy. `unknown` does not mean `safe`; `complete_for_declared_scope` is NOT universally safe. Hazard coverage, provenance, freshness and conflict must remain distinct.

## 6. Time, events, replay and persistence (INT-17,18,25,45,48)

**Future open-system protocol; current A4 implementation does not yet support it.** Events have stable `event_id`, `time_s`, unique `sequence` per timestamp, type `add|remove`, typed quantities and refs. Flow schedules are explicit piecewise constant **half-open** intervals `[start_s,end_s)`; a boundary modifies the RHS for the next interval without injecting an instantaneous quantity. At time t: integrate exactly *up to* t, close/open applicable flow intervals, apply all t events in explicit ascending `sequence` exactly once, then record the post-event checkpoint. If sequence missing/duplicated for events at same t: block. Never invent type-based tie-breaking. Actual event replay support is **P1 gated** until A4 implements/tests it.

A replay snapshot includes exact chemical state, canonical species/reaction/model/parameter refs+revisions, dataset version, solver class/version/settings/tolerances, initial conditions, time basis, sorted event ledger, flow schedule, output policy. Exclude visual coordinates, graph zoom, UI layout, display units. Candidate hash: SHA-256 of agreed canonical serialization; do not generate/compare hashes in production until cross-runtime canonicalization test vectors pass. Replay equivalence is in declared numeric tolerances, not guaranteed bitwise across platforms.

`ExperimentDocument` (future canonical document) and A5's existing `chemsim_ui_draft` v1 are **different formats**. Preserve old drafts until a separately tested, reversible migration exists. Unknown future version is read-only/blocked without destructive rewrite. Save state, user annotations and `ui_layout` separately from chemistry; A5 draft files are not solver snapshots.

## 7. OpenSpec approval gate

Integrator can decide the interoperability **shape** and propose these boundaries. Approval of product scope, numerical fixtures, source/license rights, science-model commitments, publication of final per-module DTOs, **OpenSpec baseline version** and transition to implementation remains separately recorded by the owner. This document is **not** that approval and not runtime bridge evidence. Contract mappings must be demonstrated by A1–A5 with tests before any adapter claims DONE.
