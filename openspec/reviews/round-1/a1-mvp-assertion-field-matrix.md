# A1 — MVP assertion field matrix and fail-closed gates

**Owner:** Agent A1 — Chemistry Data & Domain  
**Status:** P1 SPECIFICATION PROPOSAL / NOT AN IMPLEMENTED SCHEMA OR APPROVED DATASET  
**Date:** 2026-11-03  
**Branch:** `openspec/review-round-1`  
**Traceability:** A1 Issue #10, items 1–8; A1-P1-ASSERTION-01, A1-P1-CONSUMER-02 and A1-P1-FIRST-SLICE-03.

This document makes the minimum **logical** field obligations actionable for review and admission. Names below are descriptive, not approved wire keys, enums, a new FormulaAST, shared Unit Registry, serializer, ErrorEnvelope, or runtime API. Integrator chooses wire names/version/error forms; owner must approve OpenSpec before A1 implementation. The exact A3/A4 model decides which scientific quantities are mandatory. Do **not** treat a reference to a source or a passing numerical solver test as scientific validation or a redistribution license.

## 1. How to read field requirements

- **R (record-required):** needed to establish the stated kind of persistent assertion, or an explicit `unknown/not_reported/not_assessed` state must be recorded rather than silently omitted.
- **C (conditional):** needed **only** if a value is present, the selected property/model requires it, or the record is admitted for a particular use/distribution channel. If missing when its condition is true, fail closed for that use.
- **O (optional descriptive):** may be omitted without asserting any scientific default.
- **Gates:** D = permitted to store/display as incomplete with transparent labels; M = model-specific numerical use; R = permission for distribution within a named release channel. D does not imply M; M does not imply R.
- `not_reported`, `unknown`, `not_applicable`, and numeric zero are different. `unknown` on a field never silently becomes a permissive default. A missing uncertainty estimate is not zero uncertainty.
- A scientific assertion copied from a third party and a **user-supplied scenario input** are distinct. The latter may have `user_defined` origin without a third-party bibliographic source, but requires a declared user/local origin and does **not** become a curated reference or a redistributable catalog property.

## 2. Record-by-record minimum logical fields

| Assertion type | R — identity / always-recorded state | C — required when applicable or for model/release gate | O — additional description | Fail-closed decision |
|---|---|---|---|---|
| **SubstanceRecord (catalog identity)** | Stable `substance_id` assigned through explicit catalog creation/selection; record revision; identity-validation state and origin; formula or explicit incomplete draft state | For M/admitted catalog item: canonical formula validated by A2, exact elemental composition and integer net charge consistent with it; supported identity form; persisted schema version per integrator | Names/aliases, search labels, bibliographic cross-references | Formula text is not a unique catalog ID. Invalid/unresolved formula cannot be labeled validated; no auto-minted catalog ID from parsing. Phase is *not* part of phase-independent Substance identity. |
| **Species/ReactionTerm reference (A2 boundary, not a second A1 parser/DTO)** | A2 parsed descriptor / explicit occurrence reference with source locator; phase state preserved, including `UNSPECIFIED` | For selected catalog link: versioned substance reference after explicit lookup and identity match. For a model requiring a phase: explicit compatible phase; charge/composition validation; preserve duplicate source locators through any internal aggregation | Display formula/term labels | Unspecified/unknown phase is not silently mapped to `aq` or `g`. Parse-local `term_id` is not durable catalog identity. |
| **PropertyRecord (one assertion)** | `property_id`, subject identity/revision, property kind, assertion revision, explicit `value_state`, origin and quality state, review state (separate from quality), method/provenance state | For present numeric M value: finite real value (not boolean or string), explicit unit + physical dimension, compatible basis and conditions, phase/medium if property-dependent, applicability/range, uncertainty value **or** explicit not-reported marker, source/derivation lineage, model-specific eligibility | Display label, source note, additional precision metadata | Unknown value stays storable for D but is never numeric 0 for M. Descriptive validity is not calculation admission; a displayed value alone never certifies source/quality/rights. |
| **ThermoConstantRecord (reaction-specific A3 use)** | Assertion kind (`Ka`, `Kb`, `Kw`, `Ksp`, `Kp` etc.), exact reaction/species identity **and orientation**, phase and medium context, assertion revision, origin/quality/review/value states | For M: finite positive **dimensionless** constant, explicit basis/standard-state ID and referenced conventions (e.g. activities or supported ideal approximation), reaction direction, explicit T and required P applicability, activity/pressure model compatibility, uncertainty-or-not-reported, method/source/lineage, model/version-specific eligibility. A3's current aqueous fixtures use `gamma=1`, `c°=1 mol/L`, liquid-water/solid activity conventions; gas fixtures use ideal `p°=1 bar`. These are **fixture-local**, not global defaults | Literature name, alternate source representation | Reject bare numeric K, wrong reaction or direction, Kb supplied as Ka, incompatible basis/standard state, missing T, extrapolated T/P, unsupported activity/fugacity model. No automatic temperature correction; no K→k substitution. |
| **KineticRateConstant assertion (upstream A1→A4)** | Explicit `kinetic_rate_constant` assertion kind, linked rate-law/model version, reaction and rate-law identifiers, origin/quality/review/value states | For current A4 M: finite positive k, explicit concentration basis `c=n/V` in mol·m⁻³, volumetric rate definition, explicit nonnegative finite order vector α/reference, total order `m=Σα`, converted dimension `[k]=(mol·m⁻³)^(1−m)·s⁻¹`, compatible source unit, fixed-isothermal run T/applicability, uncertainty-or-not-reported, source/method and model eligibility. A4's actual numeric `RateConstant` currently contains only `Value` and `ConcentrationExponent` | Future temperature dependence/Arrhenius metadata, method details | Reject dimension/exponent mismatch, unknown rate-law or order, unsupported temperature adjustment, incomplete network/species mapping, any attempt to use equilibrium K as k. A4 numeric validation is *not* A1 provenance certification. |
| **HazardRecord (A1→A5 display)** | Stable substance/record identity + revision; explicit completeness state `not_assessed`, `absent`, `partial`, or `complete_for_declared_scope`; declared assessment/scope and origin status | If assessment exists: document/source identity/edition, jurisdiction or framework where applicable, reviewed sections and missing sections, publication/effective date if available, retrieval/assessment time, H/P statement provenance when provided, independently represented freshness and conflicts | Further precautions/transport hazards tied to their own scope/source | No record or missing H/P text never means safe. `absent` requires evidence of an assessed scope; `complete_for_declared_scope` means only scoped completeness. Stale/conflicting states remain visible independent of completeness. |
| **SourceRecord + per-assertion provenance** | Source ID and provenance relation for each external assertion, exact source/publisher identity; extraction/retrieval timestamp or explicit unavailable marker; source origin/type and validation status | For external assertion review: exact dataset/record/field locator, edition/version or publication date, scientific method, correction/derivation parent refs, license terms/version/evidence. For M: model-defined source and quality acceptance. For R: exact source-field rights evidence | Citation title, author note, supplemental references | A site/domain-only citation (e.g. an aggregator brand) does not establish the origin or rights of the exact value. Derived records preserve *all* parent assertions and transforms. |
| **RedistributionDecision (per source-field/use)** | Exact subject assertion/source-field reference, intended channel, disposition and evidence-review state | For distributable bundle: primary source/field, actual license/terms edition, permitted rights for that channel, attribution/notice/share-alike obligations, reviewer, date and reevaluation trigger | Human-readable rationale | Only `approved_for_redistribution` for that field/channel permits bundling. `local_review_only`, `blocked_unknown_license`, `blocked_restricted` are not release passes; no automatic promotion from publicly accessible API. |

A1 distinguishes immutable assertion **origin** (`curated_reference`, `experimental`, `calculated`, `estimated`, `user_defined`, `hypothetical`, `unknown`), separate evidence **quality** (`verified`, `limited`, `unverified`, `conflicting`, `incomplete`, `unknown`), review workflow (`unreviewed`, `accepted`, `rejected`), model-specific eligibility, and redistribution. The earlier illustrative `reviewed` quality token in A1 §3.2 is superseded by §24 (review belongs to the independent workflow). Final enum wire spellings remain integrator/owner decisions.

## 3. P1 first-slice selection: AQ-02 / A3 W02 (candidate, **not admitted**)

A3's current W02 fixture is **fully dissociated HCl/NaOH with spectator ions**, not a generic aqueous-equilibrium API. It does not consume a weak-acid/base Ka/Kb property in that fixture. This makes it a useful candidate for the *first identity + user-input + unit/provenance + result-qualifier* integration slice, **without** first selecting a literature Ka/Ksp/Kp numerical record. This is a priority suggestion, not permission to omit any parameter W02 actually requires (including a water-ionization/temperature convention if the exact implementation needs one).

Before any smoke test or benchmark admission:
1. Verify actual W02 input parameter/required-constant contract on the exact A3 head, and record the model version. No assumption that W02 requires *zero* thermodynamic inputs.
2. A2 must validate formula, composition and charge; preserve explicit `aq` occurrence phase, spectator-ion mapping, source terms, and a reliable bridge between formula/term descriptors and selected catalog identities. A2 owns parsing; the integrator owns the adapter.
3. Explicitly specify nonnegative, finite input *scenario* quantities with units and source `user_defined` status, volume if needed to convert amount/concentration, and exact analytical total / electroneutrality constraints. Do not copy source-property provenance rules onto raw user-entered feed amounts or label the feeds reference data.
4. Preserve A3's `idealized_approximation`, concentration-based pH label, concentrations in mol/L, conservation/charge residual units and termination status. A3's one equilibrium state is **not** an A4 time trajectory or graph.
5. For a **reference-backed benchmark fixture** or redistributable catalog release, independently verify its input assertions, exact reference values and applicable field-specific rights; an exploratory user-input smoke test does not meet this evidence gate.
6. Integrator must approve one phase vocabulary, schema/version contract, Unit Registry, ErrorEnvelope, result reliability and call-site mapping; owner must approve OpenSpec baseline before implementation.

**Current status:** `AQ-02 / W02 = NOT ADMITTED`; no validated numeric inputs, source records, rights, adapter or E2E run are claimed. This is a scoped pathway for reducing P1 integration risk, not a replacement for the seven-row admission register.

## 4. Acceptance scenarios — specification only, **none executed**

| ID | Gate | Input/condition | Expected result |
|---|---|---|---|
| A1-FLD-P01 | D | Validated catalog identity with formula/composition/charge, revision and explicit source origin | Retain stable explicit ID; keep phase occurrence-scoped |
| A1-FLD-P02 | D | Incomplete user-defined property with `value_state=unknown` | Store/display unknown with provenance state; numeric M unavailable |
| A1-FLD-P03 | M | Compatible typed A3 reaction-specific K, same model standard state/T/phase and complete provenance | Eligible *only if* the model's quality policy also allows it |
| A1-FLD-P04 | M | A4 half-order rate law with `Σα=0.5` and k dimension `(mol·m⁻³)^0.5·s⁻¹` | Dimensional gate accepts, subject to all other input/eligibility conditions |
| A1-FLD-P05 | D | Partial scoped hazard record with dated sources and missing sections | Show covered and missing sections, preserving freshness/conflict indicators |
| A1-FLD-N01 | M | `NaN`, infinity, boolean or string numeric property | Reject numeric use |
| A1-FLD-N02 | M | Unknown value encoded as `0` or missing uncertainty encoded as exactly zero | Reject fabricated semantics |
| A1-FLD-N03 | Identity | Formula/composition/charge mismatch or formula-derived automatic catalog ID | Reject catalog identity resolution |
| A1-FLD-N04 | M | Occurrence phase `UNSPECIFIED` when selected model requires `aq` | Reject; do not infer phase |
| A1-FLD-N05 | M | `mol/L` ↔ `mol/kg` without required solution/context data | Reject unsupported basis conversion |
| A1-FLD-N06 | M | Ka/Kb supplied for a different dissociation direction, unknown standard state, or extrapolated temperature | Reject without invented conversion |
| A1-FLD-N07 | M | Equilibrium K used as kinetic k, or k order/exponent mismatch | Reject kinetic model input |
| A1-FLD-N08 | D | Missing HazardRecord/H or P statement treated as harmless | Reject such display mapping |
| A1-FLD-N09 | R | PubChem-style aggregator field with unknown contributor license, marked redistributable | Reject bundle admission |
| A1-FLD-N10 | R | Derived value whose parent has restricted release rights | Reject rights escalation |
| A1-FLD-N11 | M | Migrated old record missing source/basis silently promoted to verified | Reject eligibility; preserve incomplete metadata |
| A1-FLD-N12 | D | `complete_for_declared_scope` displayed as universal chemical safety | Reject UI claim |
| A1-FLD-N13 | M | A3 equilibrium output turned into A4 time series with synthesized points | Reject unsupported result semantics |

The table is the **A1 acceptance requirements**, not a report of passing tests. A2/A3/A4/A5 own corresponding executable adapter/UI/solver tests; integrator owns shared-version/serialization compatibility. A1 will run owned data tests only after authorized implementation.

## 5. Cross-agent evidence and outstanding authority

| Boundary | Confirmed evidence | Still undecided / owner |
|---|---|---|
| A1↔A2 identity | A2 accepted phase-independent catalog identity, occurrence-scoped phase, explicit lookup, duplicate-locator preservation (PR #5, comment `6599229884`) | Canonical shared phase wire vocabulary, versioned catalog-ref adapter and cross-edit identity: integrator |
| A1↔A3 constants | A3 PR #4 comment `6600097355` and A3 docs: dimensionless fixture constants, aqueous `c°=1 mol/L`, ideal `gamma=1`, gas `p°=1 bar`, reaction-specific Ka/Kw/Ksp/Kp, T/phase/medium and rejection semantics. A3 Issue #10 asks explicit field coverage | A1 logical fields above address requested coverage; actual DTO, eligibility policy and error envelope: integrator/owner |
| A1↔A4 kinetic inputs | `docs/engineering/a4-kinetics-input-contract.md`, A4 PR #6 comment `6602212822`: model, amount/concentration/rate units, orders, k dimension, limited numeric `RateConstant` | A1 upstream model/quality/provenance gate; actual adapter and shared contract: integrator/owner |
| A1↔A5 hazard display | A5 PR #3 comment `6602863645` confirms completeness, scoped sources/sections, date, independent stale/conflict, stable ID/revision, no false safe inference. A5 artifact `openspec/agents/implementation/agent-05-integration-readiness.md` | Presentation wire DTO/rendering adapters only after normative contract: A5 + integrator/owner |
| Shared authority | `openspec/changes/define-chemsim-mvp/proposal.md` and `design.md` remain DRAFT and require owner approval | `schema_version`, Unit Registry, ErrorEnvelope, ReliabilityVector, phase enum, adapter ownership and review/eligibility allowlists: integrator/owner |

## 6. Completion criteria for this P1 specification slice

- [x] Define logical field minimums and conditional requirements per assertion type.
- [x] Map A3, A4 and A5 consumer statements to A1 source/identity/quality boundaries.
- [x] Prioritize one scientifically scoped candidate (AQ-02/W02) without declaring it admitted or skipping unknown model inputs.
- [x] Specify positive and negative acceptance cases with unambiguous fail-closed outcomes.
- [ ] Integrator/owner approve shared schema/version/units/error/reliability and OpenSpec baseline.
- [ ] Field-level numerical source/license evidence and model-specific scientific eligibility are admitted.
- [ ] Implemented A1 validation and cross-agent smoke tests pass on approved contracts.

**Sign-off:** A1 proposal only; do not mark Issue #10's eight ownership tasks DONE or infer a ready-to-ship chemical data catalog.
