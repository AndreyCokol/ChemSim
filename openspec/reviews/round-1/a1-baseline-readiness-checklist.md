# A1 baseline readiness and closure checklist

**Status:** DRAFT / review aid only  
**Branch:** `openspec/review-round-1`  
**Snapshot:** 2026-11-03  
**Purpose:** Trace the eight A1 ownership items to the current proposal, evidence, acceptance coverage, dependencies and decisions required before asking the product owner to approve the OpenSpec baseline.

This checklist is not an approval, implementation plan, shared DTO freeze, source-license approval or declaration that the A1 queue is complete. It is intended to make review gaps explicit and prevent a documentation proposal from being mistaken for an integrated contract.

## 1. Traceability matrix

| A1 ownership item | Current evidence | Acceptance coverage | External dependency / unresolved decision | Closure condition |
|---|---|---|---|---|
| Substance/Species identity and A2 boundary | `a1-data-contracts.md` §§1, 13–14; A2 PR #5 comment 6599229884; A2 DRAFT spec | unresolved formula; no formula-derived ID; explicit lookup; phase/UNSPECIFIED; duplicate source terms and locator preservation | Integrator selects shared phase enum/wire tokens and adapter call-site; A2/A1 agree final field semantics | A2 and integrator confirm exact boundary against approved canonical contract; no duplicate parser or competing DTO |
| PropertyRecord, provenance and DataQuality | `a1-data-contracts.md` §§2–4, 19; `a1-property-readiness-matrix.md` §§1–7 | finite numeric values; unit/dimension; basis/conditions; source-field provenance; unknown origin/license; review invalidation | Shared schema envelope, enum serialization, review-event and policy ownership | Required metadata and independent status dimensions accepted; positive/negative cases mapped to agreed test owner |
| Thermodynamic constants | `a1-data-contracts.md` §§5, 17; benchmark matrix §8; A3 PR #4 comment 6600097355 | bare K/Ka/Kb/Ksp/Kp rejected as calculation-ready; standard state, basis, phase/medium, activity model, T applicability and uncertainty required | A3 fixture contract confirmed; numeric source/value/license selection and GAS-02 iodine phase remain unresolved | Each benchmark constant has exact reaction, convention, applicability, source/value evidence and license disposition, or remains explicitly blocked |
| Units and dimensions | `a1-data-contracts.md` §§6, 15, 21; readiness matrix §2; A4 PR #6 comments 6601163898, 6601214425 | incompatible dimensions rejected; no unsupported molarity/molality conversion; fractional-order k exponent check | Integrator owns shared Unit Registry; A4 must still confirm exact RateConstant consumer contract | Shared unit vocabulary and conversion responsibility agreed; A4 confirms rate-law/order/basis/unit/conditions/rejection requirements |
| Origin, quality and model eligibility | `a1-data-contracts.md` §§3–4, 19; readiness matrix §§1, 7 | unknown/hypothetical/estimated/user-defined handling; no silent promotion; eligibility invalidation | Integrator/product owner decides policy/version authority and serialization | Origin, review, applicability, model eligibility and license remain independent and have agreed policy owners |
| Hazard completeness | `a1-data-contracts.md` §18; A5 PR #3 comments 6599360808 and 6601103475 | missing record/H/P statements not safe; absent requires assessment; completeness scoped; stale/conflict independent | A5 has not confirmed minimum consumer fields/statuses; no A5-04/05 integration yet | A5 confirms or corrects consumer minimum; presentation preserves scope, dates, missing sections, stale/conflict and non-safety qualifier |
| Offline catalog/import and redistribution | `a1-source-license-evidence.md`; benchmark matrix §§4–6 | field-level origin/license gate; local-only vs redistributable; unknown/restricted blocked; derived values inherit rights constraints | Exact current terms, source-component rights, intended distribution mode and legal review | Each source-record-field-purpose pair has documented rights and notices; only then allowlist entries can be approved |
| Schema versioning/migration and A1 tests | `a1-data-contracts.md` §§20–21; readiness matrix §7 | M01–M16 migration cases plus domain positive/negative cases | Integrator/product owner decides shared version envelope, registry/runner, unknown-field guarantee, bundle atomicity and error mapping | Shared version policy agreed; migration tests assigned; no migration invents scientific data or silently upgrades eligibility |

## 2. Current cross-agent evidence snapshot

- **A2:** accepted A1's logical identity/phase/duplicate-term boundary in PR #5 comment 6599229884. Integrator decisions on canonical phase tokens, adapter ownership, shared DTO and ErrorEnvelope remain open. A2's top-level Reaction DTO schema-version serializer invariant is a separate A2-local proposal.
- **A3:** confirmed current aqueous/gas fixture semantics in PR #4 comment 6600097355. This narrows fixture applicability; it does not approve numeric constants, sources, licenses or a general speciation contract.
- **A4:** TOL-05 is now reported complete: corrected half-order fixture commit `32fa6797f58ce55c21d9072f04a016e95855c263` passed 36 tests in runs #41619703969 and #41619711656; A4 ledger records completion. The correction confirms the dimensional exponent in §21. It does **not** answer A1's RateConstant metadata question (PR #6 comment 6601102813) or A2's ReactionTerm/FormulaAST request (PR #6 comment 6600784044).
- **A5:** A5-04/A5-05 remain contract-gated in Issue #11. No response to A1's HazardRecord request (PR #3 comment 6601103475) is recorded in the checked discussion.
- **Integrator/product owner:** no shared phase enum, schema envelope, Unit Registry, ErrorEnvelope, ReliabilityVector, adapter call-site or baseline approval is assumed by A1.

## 3. Baseline review blockers

The following are release/approval blockers, not tasks A1 may resolve unilaterally:

1. Product owner explicitly approves or requests revisions to the OpenSpec baseline.
2. Integrator publishes decisions for shared DTO/schema version, phase vocabulary, Unit Registry, ErrorEnvelope, ReliabilityVector and adapter ownership.
3. A4 confirms its exact kinetic parameter consumer contract; A5 confirms HazardRecord presentation needs.
4. Exact benchmark numerical values, source records, scientific conditions and per-field license dispositions are evidenced before any data import or redistribution.
5. GAS-02 iodine phase/temperature and any other unresolved benchmark applicability assumptions are decided by the responsible owner.
6. Test ownership and execution boundary are agreed: A1 semantic acceptance vs A2/A3/A4/A5 adapter/implementation tests.

## 4. A1 review protocol

For each row, record one of: **proposed**, **cross-agent-confirmed**, **integrator-decided**, **owner-approved**, **implemented-and-validated**. Do not collapse these states.

A row can be closed only when:
- the contract text is internally consistent and has no unresolved A1-owned ambiguity;
- required positive and negative cases are explicit;
- the responsible consumer/integrator has confirmed the boundary where cross-agent behavior is involved;
- scientific applicability and redistribution rights are independently evidenced;
- the relevant approval gate is satisfied.

Until then, retain the ownership checkbox as open. A documentation commit alone does not close an ownership item. No implementation is authorized before explicit product-owner baseline approval.


## 5. A1 pre-test release sequence (operational closure plan)

This sequence narrows the A1 contribution to the minimum data/domain work needed for a controlled test build. It does not expand A1 into implementation owned by A2–A5.

### Gate A — contract authority
- Product owner explicitly approves the OpenSpec baseline or returns a bounded revision request.
- Integrator records the shared phase vocabulary, schema/version envelope, Unit Registry, ErrorEnvelope, ReliabilityVector and adapter ownership.
- A2 confirms the final identity/phase boundary against the approved contract.
- A4 confirms the exact rate-constant consumer requirements; A5 confirms the HazardRecord presentation minimum.
- Until these decisions exist, A1 may document requirements and test vectors, but must not publish competing wire tokens or DTOs.

### Gate B — test-scope manifest
For each of the seven current benchmarks (AQ-01..AQ-05, GAS-01..GAS-02), maintain one manifest row containing:
1. benchmark ID and exact reaction/equilibrium statement;
2. species identity references and phase for each occurrence;
3. consumed property/constant identity and required model convention;
4. numeric value and unit/dimension, where applicable;
5. standard state/basis, medium, temperature and pressure applicability;
6. source record, source field, source version/date and retrieval timestamp;
7. uncertainty/method and origin/quality/review state;
8. model eligibility decision and explicit reasons;
9. redistribution disposition for the intended test-build channel;
10. positive and negative validation case IDs.

A row is test-data admitted only when all mandatory fields for that benchmark's current model are evidenced and validated. A row with no numerical value/source is blocked_missing_evidence; a row with unknown or restricted rights is blocked_license; an incompatible convention/phase/condition is blocked_inapplicable. These are proposed logical dispositions, not frozen serialized enum values.

### Gate C — fail-closed fixture admission
- Never fill a missing constant with a guessed value, generic textbook default or assumed 25 °C.
- Never infer I2 phase for GAS-02; the benchmark owner must select phase and temperature together.
- Never treat A3's gamma=1, proton, water or p°=1 bar conventions as universal chemistry defaults; they are scoped to the current fixture models.
- Never treat successful solver convergence as evidence that input data, provenance or licensing are valid.
- Keep local-review-only evidence out of redistributable test bundles unless the owner explicitly selects a local-only test channel and its storage/export boundaries are documented.
- Preserve blocked rows in the manifest so the test scope is auditable; do not silently omit a failed benchmark while reporting the full seven-case suite as ready.

### Gate D — A1 validation evidence
For every admitted row, attach:
- a positive case proving a valid, applicable, permitted record passes;
- negative cases for missing/unknown basis, phase or condition mismatch, incompatible unit/dimension, non-finite/non-numeric value, insufficient provenance, unresolved conflict and disallowed redistribution, as relevant to that model;
- exact test owner and evidence location (A1 semantic test vs consumer adapter test);
- exact contract/schema version against which the test was run.

A1 may certify the semantic data gate only. A2/A3/A4/A5 owners certify their adapters and implementations; integrator certifies cross-module compatibility.

### Gate E — release statement
A1's pre-test sign-off must report separately:
- admitted benchmark rows / total rows;
- blocked rows and reason categories;
- whether the bundle is local-only or redistributable;
- contract and schema versions tested;
- passing A1 semantic tests and unresolved consumer/integrator dependencies.

No percentage completion or blanket chemistry-data-ready statement substitutes for these facts. This sequence is a proposal pending baseline approval; it authorizes no imports, DTO freeze, implementation or redistribution.

## 6. P1 pre-test AQ-02/W02 source decision checkpoint (2026-11-03)

See `openspec/reviews/round-1/a1-kw-source-compatibility-review.md` (source/basis/license evidence) and `openspec/specs/chemistry-domain/a1-data-contracts.md` §28 (A3 consumer integration handoff).

- **P1 partial:** reviewed three classes of published Kw evidence. IAPWS molality and PHREEQC activity-model constants are not directly admissible for A3's concentration/ideal-dilute convention. OpenStax *Chemistry* **first edition** chapter 14.1 explicitly gives a **25 °C concentration approximation** with two significant figures and book-specific **CC BY 4.0**. *Chemistry 2e* instead states CC BY-NC-SA 4.0. No reference-backed Kw assertion has yet passed both scientific M and release R gates.
- **A3-09 newly confirmed:** `solve_strong_neutralization(hcl_mol_l, naoh_mol_l, kw)` takes final-mixture concentrations in mol/L (not separated-source concentrations/amounts). Exact A3 note `docs/agents/a3-w02-neutralization-acceptance.md`, commit `8800569688bb08427d26093b679eb5ff29545296`. Current W02 `component_balance_residual=0.0` is a hard-coded placeholder, not independent mass-balance validation. A1 must not present it as a source/data validation pass.
- **Decision now requested:** A3's scientific acceptance of normalized dimensionless OpenStax first-edition Kw for explicitly selected 298.15 K, gamma=1, c°=1 mol/L; owner policy for limited/rounded educational uncertainty-not-reported sources, baseline approval, and distribution channel; integrator Unit Registry/DTO/error/runtime bridge; A1 specific field provenance and attribution/release review.
- **No backdoor acceptance:** test numbers in A3 code and independent algebraic A3-09 acceptance cases are not an A1 catalog dataset; no default 25 °C, assumed water density, invented mixing volume or corrected W02 diagnostic is created by this checkpoint.

**Current A1 admission statement:** admitted W02 reference inputs = **0**; redistributable Kw fields = **0**; benchmark rows admitted = **0 / 7**. Source review is evidence for a targeted owner/integrator decision, not approval to implement A1 code.
