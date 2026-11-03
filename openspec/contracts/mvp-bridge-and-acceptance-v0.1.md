# Integrator MVP: offline bridge, acceptance gates and A1–A5 handoff

**Date:** 2026-11-03. **Status:** architecture decision by delegated integrator, **pending product-owner OpenSpec approval and runtime verification**. Companion to [cross-agent contract v0.1](mvp-cross-agent-contract-v0.1.md). This does not assert a working Godot-to-.NET bridge or approve code.

## 1. Concrete transport choice for first integrated smoke test

The first executable user story should use **A2 native Godot parser → typed admission adapter → A4 standalone .NET 10 Windows x64 CLI → validated result envelope → A5 Godot presentation**. A1 data/identity, unit, provenance and applicability checks are mandatory in the admission adapter even for the synthetic fixture; the full A1 catalog and A3 runtime equilibrium coupling are not required to exercise a *synthetic closed irreversible kinetics* smoke. **This is a testing slice, not a reduction of the owner-approved aqueous/gas MVP scope.**

**Chosen candidate bridge:** local child-process invocation with **JSON UTF-8 request and response files** in application-specific `user://` temporary storage (not a remote service, no required network backend). Reason: avoids falsely assuming the existing GDScript Godot 4.3 project directly hosts A4 .NET 10 library; gives deterministic file ownership and an inspectable failure mode. A4 owns the CLI engine adapter to its numerics; A5 owns the Godot process controller/file UX; integrator owns the envelope, argument/exit conventions and end-to-end test vectors.

CLI contract proposal:
- `chemsim-solver.exe --request <absolute-request-path> --response <absolute-response-path>` (single bounded request per invocation). Both paths must be generated under the application's designated sandbox; never accept arbitrary model-supplied arguments. No shell command concatenation.
- Atomic request creation via unique nonce/UUID; response written to sibling temporary file then atomically renamed after a successful flush. No overwrite of pre-existing arbitrary user files. Cleanup on success/failure only for files owned by the active nonce.
- Maximum input/output bytes, execution timeout, cancellation/kill policy, process exit and stderr capture must be explicitly bounded. No synchronous OS.execute call on Godot UI main thread for long solves; implement/test a worker or nonblocking controller.
- Response must echo `request_message_id` and agreed `contract_version`. Reject mismatched id, version, corrupt/oversized JSON, missing response, stale nonce, wrong species mapping, nonfinite quantities, nonmonotonic time, invalid sample semantics, or nonzero process status not accompanied by a valid diagnostic.
- Package the solver **self-contained** for Windows x64; confirm architecture, runtime dependencies, path Unicode, no internet, no console window leakage, anti-virus/permissions, clean-folder startup and license notices. None of this is currently evidenced as passing.
- The CLI runner is an *application boundary*; it must not reimplement domain models or invent scientific validation that A1–A4 have not provided. A4 current library does **not** support open-system events, reversible kinetics, Arrhenius, replay or arbitrary stiffness; adapters must block such requests.

**A3 integration lane:** A3's current reference implementation is Python and its fixture dataclasses are not approved Godot DTOs. Integrator will only select its packaging/runner mode after owner approval and a *Windows offline deployment proof*. Options include a separately packaged A3 CLI or a validated port behind the same interchange contract. Do not silently treat Python availability on a user's Windows machine as guaranteed.

## 2. Minimal vertical slice and negative gates

1. **MVP-INT-01 synthetic positive (not a real chemical claim):** an intentionally defined, charge/element-balanced (A→B) model with declared stable species refs, revisions, explicit irreversible first-order kinetic law, synthetic test k with units `s^-1`, finite positive volume and initial mol amounts, exact T, time span/output policy and applicable data state. A2 represents reaction; adapter checks model identity and dimensionality; A4 computes first-order amount trajectory; A5 graphs amounts or explicitly converted concentrations. Reference analytical shape (n_A(t)=n_{A0}e^{-kt}); preserve amount conservation when the supplied invariant is actually verified. A manufactured toy constant is **test input**, not a source-backed physical kinetic property, and may not be used as a real substance's verified parameter.
2. **MVP-INT-02 missing required `k`**: no launch, typed `blocked`, A5 displays missing-field reason; no sample graph.
3. **MVP-INT-03 missing kinetic order or using a stoichiometric coefficient as order**: reject; explicitly entered order required.
4. **MVP-INT-04 bad unit / `mol/L` versus `mol/m3`**: conversion is registry-mediated; inconsistent dimensional k or missing volume rejects. Mass→amount without molar mass rejects.
5. **MVP-INT-05 unsupported arrow `<->` or open-flow request** against current A4: reject, never reinterpret as irreversible closed model.
6. **MVP-INT-06 A4 valid-prefix failure**: show partial series ending at last valid time; keep final status non-success, distinguish failed target/end; do not draw to requested end.
7. **MVP-INT-07 scientific provenance unavailable**: show `user_supplied` or `hypothetical` as declared, never `verified`; no claim of chemistry conservation without validated elemental source.
8. **MVP-INT-08 graph gaps**: invalid/non-finite/unknown values are not plotted or connected; never substitute zero.
9. **MVP-INT-09 phase/identity and parser Unicode spans**: unknown phase can remain in draft but phase-dependent models block; UTF-8 byte range over Cyrillic input highlights exactly the intended substring; parse-local term offsets never persist as IDs.
10. **MVP-INT-10 result vs equilibrium**: a single A3 equilibrium state must not be accepted as A4 time series; pH concentration approximation clearly marked.
11. **MVP-INT-11 replay/event future contract**: same-timestamp events ordered by explicit sequence, flow intervals half-open, no duplicate application; until implementation exists, replay controls remain disabled with an explanatory status.
12. **MVP-INT-12 offline Windows packaging**: from a clean Windows 10/11 x64 environment without .NET/Python/network preinstalled, launch Godot, run bundled solver sample, save and reopen a draft, inspect diagnostics and verify no external requests. **No pass until actual Windows execution evidence**.

Each scenario needs: owner, exact contract version, input fixture, expected behavior, linked CI run and output artifact. Unit tests of isolated modules are necessary but not sufficient for an E2E pass.

## 3. Ownership handoff matrix / ready criteria

| Boundary | Producer owner | Consumer owner | Current verified evidence | Required closure / status |
|---|---|---|---|---|
| A1 identity + property provenance | A1 | A2/A3/A4/A5 | A1 proposal, admission manifest blank | Stable species/record refs, formula charge derived only, exact dataset/rights/quantity metadata; **PROPOSED**, data gate **BLOCKED** |
| A2 parser → canonical reaction | A2 | A4/A5 | Isolated GDScript parser PR #5 | Map AST + source span, term identity and immutable reactions; runtime interop test **NOT DONE** |
| A3 thermodynamic state | A3 | A5; optional A4 for future coupling | Isolated Python fixture PR #4 | Versioned basis/model/result/solid/phase/diagnostic metadata, source-backed K; Windows runtime integration **BLOCKED** |
| A4 numeric core | A4 | A5 | Isolated .NET 10 PR #6, limited closed irreversible solver | CLI host, typed adapter and result partial/status mapping; **NOT IMPLEMENTED** |
| Godot UX and persistence | A5 | User / integrator | Isolated Godot workspace PR #3 (Draft) | Graph/Run stay disabled until actual result validation, Windows test and contracts pass; **PARTIAL** |
| Cross-module units/errors/versions | Integrator | All | Candidate contract v0.1 in OpenSpec PR #1 | Owner approval + producer/consumer mapping tests + runtime proof; **INTEGRATOR DECIDED, NOT APPROVED** |
| Scientific numeric benchmark data | A1 + A3/A4 | All | Seven-scenario A1 admission manifest is template only | Source/conditions/basis/rights/independent expected values/tolerances; **BLOCKED** |
| Owner OpenSpec baseline | Product owner | All | PR #1 Draft / owner approval item unchecked | Explicit accept/reject record with baseline SHA, scope and deferrals; **BLOCKED** |

## 4. Before implementation: contract verification plan

- **Schemas and migrations:** A1–A5 must independently map their existing local structures to the shared interchange names and report unsupported fields; don't imply A4 numeric RateConstant already contains provenance or units.
- **Safety and data correctness:** no K→k, no phase or unit inference, no missing→zero, no result reliability percentage, no hazard-free inference from empty data.
- **Versioned fixture set:** checked-in synthetic envelopes, parser source-span cases, status/error cases, missing/unit rejection, partial-series acceptance, schema-version refusal and cancellation/timeout tests. Approve and run once implementation gate opens.
- **CI gates:** pull-request scoped unit and schema tests; separate Godot 4.3 headless, .NET 10, Python/A3 fixture tests; final Windows x64 E2E offline runner check. A Linux runner by itself does not prove Windows packaging.
- **Acceptance reporting:** For every result record exact commit, CI run URL, model/contract revision, passed/failed checks and known limits. Don't change an issue to DONE based solely on prose.

## 5. Owner decisions required to advance

1. Explicitly **approve/reject** the v0.1 candidate contract, local CLI bridge strategy and phase-1 closed irreversible *synthetic test slice* while retaining the approved aqueous/gas MVP scope.
2. Authorize full or staged implementation **only after** the referenced OpenSpec baseline SHA and version are recorded; confirm whether already developed isolated prototypes may be used as inputs to subsequent adapter work.
3. Assign source-backed property/benchmark admission and redistribution/license review; no license guessing and no scientific benchmark success claims on toy fixtures.
4. Preserve requirement to support aqueous equilibrium, gas equilibria, open systems, rewind and encyclopedia as stated; any change in release-MVP versus interim engineering smoke must be an explicit product-owner decision, not a unilateral integrator deferral.

**Approval record template (owner must actually fill and commit/comment it):** `OpenSpec define-chemsim-mvp baseline <sha> version <version>: APPROVED / REJECTED; accepted contract version; accepted bridge; scope of implementation authorization; deferred features and acceptance conditions; date; approver.`

Approval must not be inferred from creating this document, writing comments or opening/merging a PR without an explicit record.
