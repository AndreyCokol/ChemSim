# A1 Chemistry Data & Domain — first implementation slice

**Owner:** A1 (Issue #10; Draft PR #15)  
**Approved architecture:** owner sign-off `main:openspec/changes/define-chemsim-mvp/APPROVAL.md`, OpenSpec v0.1 source `02b8b31706807279ee31a78772383e31f425f7d3`.  
**Scope:** A1-local strict *structural preflight* — not a shared wire DTO, not source validation, not formula parsing, not a complete offline catalog.

## Components

- `a1_property_gate.gd`: numeric reference-assertion metadata and separate per-field/per-channel release-declaration structural checks. Missing values are not zero; unregistered units, mismatched basis, unqualified temperatures, unsigned quality/review or missing provenance do not pass the calculation metadata preflight. A syntactically complete `approved_for_redistribution` declaration remains an **unverified claim** until a rights reviewer checks the source.
- `a1_identity_gate.gd`: validates the binding of caller-selected stable Substance, Species and FormulaAST **IDs plus record revisions** against the shape of a *trusted result produced by A2*. FormulaAST owns composition and net charge. Phase is occurrence-scoped; an A2 `UNSPECIFIED` phase is not automatically aqueous. It accepts `user_defined` and `hypothetical` identity without making a reference-quality claim.

These methods return `{ok,errors,scope,...}` for A1-local preflight; error strings are not the approved shared `ErrorEnvelope` wire schema. The integrator owns their mapping into v0.1 envelopes.

## Integrator / producer boundary

The **integrator** must: (1) call the A2 parser on actual input, (2) authenticate/trust the resulting A2 `ok/formula_ast/phase` data (the helper cannot tell fabricated dictionaries from real parser calls), (3) resolve and lock immutable `{id,record_revision}` for Substance, Species and FormulaAST from its persistent identity store, (4) pass the selected refs and actual A2 result to A1, and (5) enforce that changed formula or phase creates a fresh identity ID and historical revisions remain immutable. The helper cannot prove revision monotonicity or historical identity from one snapshot.

A2 currently returns an AST with `schema_version: 1`, `element_counts`, `net_charge`, `nodes`, `source_text`, and a separate phase token such as `AQUEOUS` or `UNSPECIFIED`. **A2's parser does not currently issue durable FormulaAST record IDs or revisions.** The selection/binding must be supplied by an approved integrator adapter; an A2 local term index or formula text must never be silently used as catalog identity.

For the A1 local identity preflight, the caller passes:

| Parameter | Contract subset |
|---|---|
| `substance` | `substance_id`, positive `record_revision`, `formula_ast_ref`, declared `origin`; **no** independently serialized `formal_charge`, `net_charge`, `element_counts`, `phase` |
| `species` | `species_id`, positive `record_revision`, same `formula_ast_ref`, phase `s/l/g/aq/unspecified` |
| `a2_parse_result` | `ok: true`; AST `schema_version: 1`, nonempty `nodes`, exact positive-integer sparse element counts, integer charge, `source_text`; A2 phase |
| `selection` | explicit three ref pairs `substance_ref`, `species_ref`, `formula_ast_ref`, each with `id` and positive `record_revision` |
| `model` | `required_phase` (`unspecified` for descriptive-only) and `explicit_occurrence_phase_confirmed` when A2 source phase is unspecified and a phase-specific model is requested |

**Important:** parser output must be supplied by a trusted A2 invocation, not accepted as raw user assertions. Presence of element counts is only a **shape/coverage** check: a missing element in an independently complete A2 AST is a known zero; a missing or unsupported AST is *unknown* and cannot be treated as a zero row. A1 does not derive element or charge balancing, mass, isotope corrections or equilibrium constants.

## Current implementation gaps / integration stop conditions

- Existing `implementation/bootstrap:scripts/domain/substance_record.gd` contains denormalized `element_counts`, `net_charge` and a local formula-parse routine. It does **not** map as-is to the v0.1 canonical record. The A1 helper intentionally rejects a second independent persisted chemistry truth; **no bootstrap/A2 file has been altered**. Integration requires an owner-reviewed migration/adapter and corresponding tests.
- A2 parser's ephemeral AST still needs durable identity binding, identity-change handling and trustworthy call-site semantics from the integrator. Static reference equality is **not** a cryptographic/content verification of a claimed AST.
- A1 origin preservation is separate from quality, review, model eligibility and redistribution. A1 `ok` is not a permission to label a trajectory `chemically_verified`; A4 needs independently proved full element/charge coverage, exact balance and applicable kinetics before using generated invariant rows.
- No numeric chemical constants, source-proven values, licensed catalog bundle or scientific benchmark have been admitted (**0/7**). A3 W02 requires source-backed, basis-qualified Kw, final-mixture concentration inputs and independent A3 adapter evidence.
- Overall bootstrap Godot editor import still reports existing parser/balancer script errors on the independent A1 job; passing isolated A1 tests is not a clean full-app build.

## Tests

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/a1/test_a1_property_gate.gd
godot --headless --path . --script res://tests/a1/test_a1_identity_gate.gd
```

These are **synthetic contract tests**, not scientific validation fixtures or an end-to-end A2→A1→A4 run. Exact-head GitHub Actions evidence must be recorded in PR #15 / Issue #10 after each meaningful change.


## A1 local user/hypothetical substance draft catalog (P1)

`a1_user_catalog.gd` is an A1 **private offline draft store**, not the v0.1 interchange envelope, A5 experiment persistence, a verified built-in catalog or a migration of `scripts/domain/substance_record.gd`.

- Only `user_defined` and `hypothetical` origins are accepted. Every draft is explicitly `identity_status: incomplete`, and its hazard coverage is `not_assessed`. Presence of a selected `formula_ast_ref` is **not** an A2 authenticity proof; historical scientific identity binding remains an integrator/A2 task.
- Caller supplies a stable opaque `substance_id` and `record_revision`. First revision is `1`; append requires the caller's `expected_previous_revision` and a consecutive revision. Every old revision is stored unchanged. Under one ID, `origin`, `formula_ast_ref`, and provenance creation timestamp are immutable; changing formula identity requires **a new catalog ID**, not an overwrite.
- `properties[]` are explicitly `quality: unverified` with matching local origin. `value_state: unknown/not_reported/not_applicable/withheld` carries no numeric `value`; `value_state: present` permits a finite numeric value (including **0**) only with explicit `unit_id` and `basis`. Neither structure nor numeric presence confers calculation eligibility.
- Arbitrary `quality: verified`, `redistribution`, `model_eligibility`, serialized `phase`, `net_charge` or `element_counts` are rejected in the local draft format. Do **not** use this store to ingest licensed reference fields, hazards or A2 formula/charge snapshots.
- Versioned `schema_version: 1` JSON, bounded record/property/file sizes and strict field allowlist. **Before every save**, compare the validated on-disk history against the proposed snapshot: saved revisions must be an exact prefix. Stale writers, altered historical rows, unreadable/future-version primaries or orphaned `.tmp`/`.bak` evidence are blocked with typed A1-local error codes; an identical save is a no-op. This is fail-closed loss prevention, **not** a cross-process transactional lock.
- A fixed local file `user://a1_substance_drafts_v1.json` is written through a validated `.tmp` stage, with prior snapshot at `.bak`. `load_local_backup()` is **read-only preview**, never an automatic restore; a failed write preserves/reports recovery evidence. A corrupt primary is never silently replaced by an older backup. Actual restore, multi-process locking, migrations and recovery UI require explicit owner/integrator decisions.
- Test writes use **only** `user://a1_substance_drafts_test_v1.json` (plus test tmp/bak). It is never the production catalog. The store is not yet wired into UI, an authenticated A2 adapter or the shared Save/Replay document. No real chemical value/benchmark is imported.

Exact tests:

```sh
godot --headless --path . --script res://tests/a1/test_a1_user_catalog.gd
```

**Known limitations:** this is a local implementation slice. It does not validate literal UTC timestamps beyond structural presence, independently prove provenance truth, enforce scientific unit dimensions, guarantee atomicity under power loss, or resolve concurrent processes on Windows. A5/integrator must specify migration/export/backup UX and cross-module locking before shipping persistent data. No full-app E2E or scientific benchmark admission is implied.


## A1 scoped HazardRecord metadata preflight (P1)

`a1_hazard_gate.gd` validates only the **structure and evidence claims** of hazard records. It never certifies a substance safe, issues a warning's scientific truth, issues redistribution rights, or supplies laboratory handling instructions. It returns `ok`, A1-local `errors[]`, `warnings[]`, `completeness`, `safety_assurance: false` and `scope: a1_hazard_metadata_preflight_only`. These are **not** shared ErrorEnvelope/UX string IDs; integrator+A5 must map and localize them.

- `record = null` produces a displayable `not_assessed` status and warning **A1_HAZARD_NOT_ASSESSED**. A record marked `not_assessed` must not smuggle in claimed assessment, H/P statements or a confirmed source.
- `absent` means a scoped **record-absence finding** in a clearly declared framework/jurisdiction/source, with explicit `absence_evidence_field` and all scoped sections reviewed. **It does not mean “no hazards”, “safe”, “no warning required” or “SDS absent”.**
- `partial` requires explicitly separated reviewed versus missing sections; the union must match the declared scope, without overlapping or duplicated sections.
- `complete_for_declared_scope` means only that all **declared** sections were reviewed. It does not certify safety outside that source, framework, jurisdiction or retrieval/assessment date. Empty H/P lists do not prove hazard absence.
- Scoped assessments have a pinned Substance reference `{id,record_revision}`, source ID/version/record locator/retrieval time, assessment timestamp, framework/version/jurisdiction and explicit H/P statement source-field locators. `freshness` (`current|stale|unknown`) and `conflict_status` (`none_reported|conflicting|not_assessed`) remain independent of completeness.
- Unknown metadata, claimed `safe` and arbitrary release approval fields are rejected. Source metadata strings and H/P text **are not authenticated against a third-party SDS**; no actual hazards were imported into this repository. Field/channel redistribution must be approved independently through A1 rights process, **not** by this validator.
- The current user-draft store intentionally has only `hazard_completeness: not_assessed`. Real assessed HazardRecord storage and A5 card/encyclopedia rendering remain separate integration tasks requiring an approved schema/adaptor and source/licensing evidence.

Run the A1 test (synthetic H/P strings, not actual safety guidance):

```sh
godot --headless --path . --script res://tests/a1/test_a1_hazard_gate.gd
```

**Not covered:** external source authenticity, applicable regulatory classification, accurate hazard statements, age/version freshness policy, SDS-specific requirements, dangerous-material handling, Windows distribution, and UI accessibility/localization. A1 does not generate safety advice from missing fields.


## A1 strict registered-unit dimension gate (P1)

`a1_unit_gate.gd` implements an **A1-local**, pure numerical conversion helper for explicitly supported *integrator v0.1* unit IDs only. It is not a replacement for the scientific model's typed basis, kinetics-specific rate-law dimensions, provenance, applicability, or shared interchange `Quantity` DTO.

- Registered symbols: `1`, `mol`, `kg`, `g`, `m3`, `L`, `s`, `K`, `degC`, `Pa`, `bar`, `mol/m3`, `mol/L`, `mol/s`, `mol/(m3*s)`, `J/mol`. Case-sensitive, no extra aliases.
- Exact dimensional conversions: `1000 g = 1 kg`, `1000 L = 1 m3`, `1 bar = 100000 Pa`, `1 mol/L = 1000 mol/m3`. Celsius ↔ Kelvin is accepted **only with `temperature_kind: absolute`**, with affine offset `T[K] = T[degC] + 273.15` and rejection of below-absolute-zero values.
- Caller must supply `required.dimension_id` matching **both** source and destination. For concentration, dimensionless constants, pressure, amount/volumetric rates and molar energy, caller and quantity must supply the same explicit `basis`. If either side supplies a basis for other units, it must match too. A unit conversion never authenticates that basis — the trusted A2/A3/A4 integrator still owns model and data provenance.
- `convert_availability` preserves `unknown|not_reported|not_assessed|not_applicable|withheld` **without fabricating a quantity or zero**, but still validates the *requested destination* and expected dimension. `present` requires a complete numeric Quantity; a known numerical zero remains `present, value: 0`.
- Optional Quantity `uncertainty` is **typed Availability**, not a scalar or implicit zero. For `present` uncertainty in linear units, the declared source unit and basis must match, and both value and uncertainty are converted by the same scale. Unknown/not-reported uncertainty remains unknown/not-reported; malformed uncertainty is rejected. Temperature with numeric uncertainty is blocked until an approved **temperature-difference unit** exists (v0.1 `degC` describes absolute temperature; do not use a Celsius offset for error bars).
- Rejects mass→mol without a trusted molar mass and explicit domain calculation, amount-rate→volumetric-rate without a volume/model, molality `mol/kg`→molarity `mol/L`, mismatched molar versus free-ion basis, overflow/underflow to zero, non-finite numbers, fake unit aliases, and a purported “unit conversion” between equilibrium K and kinetic k.
- This helper **does not calculate** kinetic rate-law `k` dimensions from reaction orders, thermodynamic K vs k model eligibility, concentration mixing, gas standard-state transformations, temperature dependence, chemical sources/rights, or a `ReliabilityVector`. It cannot certify a K/k mismatch solely from a unit symbol — the required **basis/model identity** is established independently and must be provided by the integrator.

The local preflight requires a Quantity `{value, unit_id, basis?, uncertainty?: Availability}` and a requirement such as `{dimension_id: "concentration", basis: "final_mixture_analytical"}`. Godot tests:

```sh
godot --headless --path . --script res://tests/a1/test_a1_unit_gate.gd
```

The A1 suite is synthetic, not a source-backed chemistry benchmark or an approved shared DTO. Windows execution and cross-agent adapter validation are still outstanding.


## A1 independent science/source/rights admission boundary (P1)

`a1_source_admission_gate.gd` is a deliberately **fail-closed** local admission boundary for the seven A3 fixture keys `AQ-01`…`AQ-05` and `GAS-01`/`GAS-02`. It runs the existing `A1PropertyGate.validate_numeric_contract` (scientific *metadata assertions*) and `validate_distribution_declaration` (claimed *rights metadata*) but **does not trust either result as independent approval**.

The code-owned `REVIEWED_MODEL_ASSERTIONS` and `REVIEWED_RELEASE_ASSERTIONS` allowlists are both **empty**: currently **0/7** benchmark data bundles are scientifically admitted or cleared for redistribution. User-supplied `origin=curated_reference`, `quality=verified`, `review=accepted`, `model_eligibility=accepted`, `redistribution.disposition=approved_for_redistribution` and even fake `reviewed_by` values never create allowlist entries. An actual future admission requires **an A1-owned, independently reviewed code change**, exact pinned record and model requirements, independent scientific reviewer evidence, exact source/version/field provenance, and a separate channel-specific legal/release review. An entry cannot be supplied as runtime input. These allowlists are not a trusted release chain until independently populated and reviewed; they are no-op blockers by design.

`assess_assertion(record, required, benchmark_id, requested_channel)` returns local-only booleans `metadata_preflight_ok`, `rights_declaration_preflight_ok`, `reference_admitted`, `redistribution_approved`, `scientific_data_ready` and `release_ready`, plus diagnostic `errors[]`. Only an **independent allowlist match** can move an admission flag. A benchmark typically requires **multiple** assertions, species refs and scientific fixtures: one property passing cannot certify the whole scenario. It is neither the approved interchange `ReliabilityVector` nor a substitute for model-owned numerical validation.

### Current concrete source blocker: AQ-02/W02 water Kw candidate

A3 [review of OpenStax *Chemistry* first edition §14.1](https://github.com/AndreyCokol/ChemSim/pull/4#issuecomment-6607758791) confirms only **conditional educational model compatibility** for 298.15 K, ideal dilute `c°=1 mol/L`, `gamma=1`, hydrated-H+ shorthand and final-mixture analytical feeds. It does not endorse nonideal thermodynamic accuracy, default T, published uncertainty, general applicability or fixture admission. This book's [edition-specific preface](https://openstax.org/books/chemistry/pages/preface) currently contains a historical `CC BY 4.0` statement alongside later restrictive `CC BY-NC-SA`/noncommercial and LLM/AI reuse wording; [OpenStax licensing help](https://help.openstax.org/s/article/Openstax-textbook-licensing-and-customization) also describes the restrictive library policy. This is **a license/edition/channel conflict requiring authoritative clarification**, not a permit to redistribute the constant. Original scientific explanation is at [§14.1](https://openstax.org/books/chemistry/pages/14-1-bronsted-lowry-acids-and-bases).

**A1 decision:** `M = conditional_candidate_only`, `R = blocked_unknown_license`, `scientific_reference_admitted = false`, `offline_bundle_approved = false`. No numeric Kw, real H/P safety statement or imported third-party property has been copied into A1 runtime or test fixtures. A3’s synthetic W02 model preflight and the A1 source-review process are separate; neither can promote the other. The project owner/integrator must approve the intended fixture use and obtain exact source/rights evidence before a reviewed allowlist change.

Godot regression:

```sh
godot --headless --path . --script res://tests/a1/test_a1_source_admission_gate.gd
```

This verifies that fabricated approval declarations **cannot bypass** the empty reviewed allowlist. It is not a legal conclusion, scientific validation, test of OpenStax content accuracy, or full-app source ingestion pipeline.
