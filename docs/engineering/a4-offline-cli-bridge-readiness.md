# A4 offline CLI bridge — source-to-v0.1 mapping and acceptance gates

**Task:** A4-CLI-BOUNDARY-01 (P1 research checkpoint under A4-E2E-MVP). **Agent:** A4 — Kinetics & Numerical Solver. **Date:** 2026-11-03.  
**Status:** **DESIGN ONLY — implementation BLOCKED** until product owner explicitly approves OpenSpec baseline version/SHA, contract v0.1 and staged engineering smoke. No new public API, executable CLI project, transport protocol or producer adapter is introduced here.  
**Track:** [A4 Issue #12](https://github.com/AndreyCokol/ChemSim/issues/12), [Draft PR #6](https://github.com/AndreyCokol/ChemSim/pull/6); integrator sources in [Draft OpenSpec PR #1](https://github.com/AndreyCokol/ChemSim/pull/1): [cross-agent contract v0.1](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/contracts/mvp-cross-agent-contract-v0.1.md), [JSON Schema](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/contracts/interchange-envelope-v0.1.schema.json), [offline bridge/acceptance plan](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/contracts/mvp-bridge-and-acceptance-v0.1.md).

## 1. Actual executable inventory — no false bridge readiness

- `src/ChemSim.Kinetics/ChemSim.Kinetics.csproj` is a **C# calculation library project**, currently without an `OutputType=Exe` console entry point or `chemsim-solver.exe` host. Existing solution/test projects target .NET 10 through repo-wide settings. The A4 GitHub workflow verifies **library restore/build/tests only** on CI, not Windows x64 published standalone executable or Godot invocation.
- `KineticsSimulator.Run(SimulationRequest, CancellationToken)` is a **direct in-process C# method**. It does not parse JSON, read files, serialize a shared response, manage subprocess lifetime, or supply data provenance/phase/temperature/reaction revisions.
- The integrator's **proposed, not approved** bridge is GDScript A2 → application admission → **local, file-based UTF-8 JSON** → a self-contained .NET 10 Windows x64 CLI hosted by A4 → validated result envelope → Godot A5. Godot controls subprocess/UX; integrator owns shared envelope, flags/exit conventions and E2E fixtures. A4 must not invent a competing IPC contract or assume Godot's GDScript scene directly runs the .NET assembly.

**No runtime code should be added merely because the integrator selected a design candidate.** The integrator [closure note](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/reviews/round-1/integrator-closure-2026-11-03.md) explicitly states decisions are pending owner approval.

## 2. Candidate request → existing A4 method mapping (owner approval required)

| Proposed v0.1 interchange meaning | Actual A4 backend member | Admission validation & owner |
| --- | --- | --- |
| `Envelope.contract_version=0.1`, `message_id`, `kind=simulation_request`, JSON `payload` | **None** | Integrator/CLI must validate version, correlation UUID, payload type, schema and bounds. Do not deserialize arbitrary type names or run unvalidated JSON; unknown major/kind rejected. |
| Stable reaction ref+revision, signed reaction coefficients after A2 validation | `ReactionDefinition.Id` and `Stoichiometry: Dictionary<string,int>` | A2/integrator resolves stable species refs, aggregate canonical terms, verify integer/charge/element balance; persist reaction revision **outside backend**. Negative reactants / positive products. |
| Stable species refs+revisions, canonical model species set | `ReactionNetwork.SpeciesIds: IReadOnlyList<string>` | No aliases/source-text offsets as IDs. A4 sorts IDs internally; output maps by actual canonical IDs, not input term order. A1/A2/integrator validate phase/identity/revision. |
| `rate_law_id=irreversible_volumetric_power_law`, explicit kinetic-order map | `ReactionDefinition.KineticOrders` | A4 accepts only irreversible, closed, well-mixed constant volume/isothermal power law. Orders separately provided: no inference from stoichiometry or equilibrium `K`. |
| Typed kinetic k, rate dimension/basis/source applicability | `RateConstant(Value,ConcentrationExponent)` | A1/integrator adapter validates model/parameter provenance, rate basis, **temperature suitability** and source unit conversion. A4 numeric class checks only positive finite value and exponent approx `1−Σα`; it does **not** know a `unit_id`, `Ea`, `T_ref` or source. |
| All initial species amounts in typed `mol` | `SimulationRequest.InitialAmountsMol` | Must cover exact canonical species IDs, finite nonnegative values, numeric zero **distinct** from missing/unknown status, no ambiguity in unit conversions. |
| Typed positive fixed volume `m3` | `SimulationRequest.VolumeM3` | A4 validates finite positive m³; A1 unit conversion required upstream. |
| Fixed experiment T in typed K and allowed conditions | **No temperature input in current A4 `SimulationRequest`** | Admission checks source k applicability **at declared fixed temperature**, rejects Arrhenius-dependent/dynamic-T/unsupported models. Preserve scientific temperature as qualified application metadata; never pretend A4 has validated it. |
| Start/end time and output interval in s | `StartTimeSeconds,EndTimeSeconds,OutputIntervalSeconds` | Validation requires finite progressing timeline, representable output targets and no overflow in duration. |
| Typed `solver_policy` with tolerances and step budget | `SolverOptions.RelativeTolerance, AbsoluteToleranceMol, InitialStepSeconds, MinimumStepSeconds, MaximumStepSeconds, MaximumInternalSteps` | Finite bounds, correct units (absolute atol in mol), cancellation/timeout budget. No implicit global science tolerance. |
| A1/A2-verified element/charge rows and coverage | Optional `ReactionNetwork.ConservationLaws` | Source-validated atom/charge rows are **not** produced by A4. Missing laws may permit a numerical calculation but **must not** imply chemical verification. See [A4 invariant proposal](a4-conservation-invariant-handoff-proposal.md). |
| Reversible arrow, flow schedule, event ledger, finite mixing, dynamic T, replay, unsupported phase/stiff model | **Not supported by this backend** | **BLOCK before Run**; never silently downgrade to simple irreversible simulation. A3 equilibrium `K` cannot be interpreted as kinetic `k`. |

**Critical cross-runtime responsibility:** A4 owns the future engine-facing adapter *only after approval*; A1/A2/integrator own canonical chemistry, unit/provenance/identity predicates. Even a perfectly parsed JSON payload is **not** scientifically admissible until applicable input checks pass.

## 3. Result/status mapping — candidate, not a new wire enum

The A4 method returns `SimulationResult(Status, Samples, Diagnostics)`; `StateSample(TimeSeconds, AmountsMol)`; diagnostics are accepted/rejected step counts, RHS evaluation count and free-text `Message`. These are **not** the shared `ErrorEnvelope`, `GraphSeries`, `ReliabilityVector`, `request_message_id` or schema version.

| Existing A4 `SimulationStatus` | Suggested v0.1 `outcome` (review mapping) | Sample / completeness rule |
| --- | --- | --- |
| `Success` | `completed` | Complete **only** if request/response IDs, species set, monotonic finite samples and requested final time pass validation. Scientific applicability reported separately. |
| `InvalidInput` | `blocked` | Pre-validation may have **zero** samples; runtime time-representability error may include valid prefix. Preserve machine category and reason. |
| `StepSizeUnderflow` | `numerical_failure` | Valid completed-output prefix only, failure reason preserved. |
| `MaximumStepsExceeded` | `step_limit` | Valid prefix, even when some time segments completed; never mark complete. |
| `NonPhysicalState` | `numerical_failure` | Valid prefix; do not clamp, graph or extrapolate attempted negative stage. |
| `ConservationFailure` | `invariant_violation` | Violating target **not** published; previous validated output prefix only. |
| `Cancelled` | `cancelled` | Valid prefix; on mid-interval cancellation counters may **omit in-flight** work because no outcome returned. |
| `NumericalFailure` | `numerical_failure` | Valid prefix and original error message, not a fabricated finite output. |

The v0.1 candidate `Envelope.outcome` enum also includes `partial`, whereas the shared prose defines specific termination reasons and independent `ReliabilityVector.completeness=partial`. **Integrator must decide unambiguously** whether `outcome` records termination reason or generic completeness when samples are partial. A4 recommends **retain the specific reason** (e.g. `step_limit`) and set completeness to `partial` independently; do not overwrite the cause with `partial` and lose crucial diagnostic identity. This is an identified contract **ambiguity**, not an implemented mapping.

`last_valid_time` is **absent** for zero samples, otherwise the last strictly validated sample time, in seconds; it is **never silently 0**. `Success` requires final endpoint equal to requested end under the **agreed floating-point time policy**. A4 does not supply `last_valid_time` in its record; a validated adapter may derive it from its samples. Sample amounts `mol`; per-species concentration only if declared fixed positive volume and conversion is finite. No current A4 rate, computed temperature, graph event or replay series exists.

## 4. Specific schema-level gaps to resolve with integrator

The inspected `interchange-envelope-v0.1.schema.json` currently declares `Envelope` required keys `contract_version,message_id,kind,payload,errors`, but does **not** conditionally require `request_message_id` or `outcome` when `kind=simulation_result`. The accompanying prose **does** require these response fields. Therefore **schema-valid is not sufficient** to declare an accepted correlated response: implement semantic correlation checks after the owner-approved schema is corrected/ratified.

Also, `Envelope.payload` is only typed `object`, so the schema does **not yet** validate a complete typed `SimulationRequest`/result shape (species quantities, rate model, sample arrays, solver policy and temperature metadata). A4's numerical constructor validation remains downstream; malformed required cross-agent fields must be rejected *before* invoking it. The declared `GraphSeries` and `Sample` sub-schemas validate coarse structure; they do not themselves ensure finite/monotonically increasing sample times, correct units, correct species membership, no out-of-bound timestamps or no interpolation over gaps. These must be explicit producer/consumer acceptance tests.

**Risk of default JSON behavior:** ordinary UTF-8 JSON has no valid `NaN` or `Infinity` number tokens. Reject non-finite numeric values both on deserialization and **before** serialization; do not stringify them as fake scientific measurements or `null`. Require output payload bounds, named error codes, source correlation and fail-closed unknown versions even if a general JSON parser accepts the text.

## 5. A4 CLI boundary and Windows acceptance checklist (implementation deferred)

The integrator candidate invocation is `chemsim-solver.exe --request <absolute-file-path> --response <absolute-file-path>`, one bounded request per process. A4 future CLI must:

1. Be a separate **executable host** referencing the existing `ChemSim.Kinetics` library; do not turn the solver domain classes into a duplicate Godot model. The future `OutputType=Exe` project/entrypoint has **not** been created.
2. Validate provided absolute request/response paths are within integrator-approved per-invocation app sandbox and have unique nonces. Reject traversal, symlinks/reparse-point escape and unexpected pre-existing output targets under agreed Windows filesystem semantics; avoid shell interpolation. Bound request bytes, response bytes, number of species/reactions/samples, computation budget and wall-clock timeout. These are **requirements**, not currently enforced features.
3. Parse exact approved contract/version/kind and required IDs; map qualified, unit-converted data to `ReactionNetwork`/`SimulationRequest`. Reject scientific unknowns before numeric call; prevent unbounded sample explosion (e.g. huge duration / tiny output interval) before allocation. Return a structured **block** when invalid; do not convert solver errors into process crashes without diagnostics.
4. Call A4 numerical kernel on a dedicated worker/process with cancellation signal or kill handling agreed with A5/integrator. `CancellationToken` exists in A4, but current code does not implement IPC cancellation/kill/timeout rules. Capture stderr/exit status separately from the scientific result.
5. Write a complete validated response to a nonce-scoped temporary file and atomically rename under the approved same-volume policy after successful flush; do not leave a truncated success envelope. A5 checks response kind, contract version, `request_message_id`, nonce/correlation, output shape and finite series before graphing.
6. Publish a real Windows x64 **self-contained** .NET 10 executable with explicit process test in an offline clean Windows environment (Unicode paths, permissions, no preinstalled .NET/Python or network). Current Linux-only A4 unit CI is **not** such evidence.

**Scope/ownership:** integrator owns protocol/path/exit-code/timeout policy and cross-platform E2E fixture definitions; A4 owns the host-to-numeric mapping and internal A4 tests only **after owner signoff**; A5 owns UI-safe process launching, cancellation, file lifecycle and graph display. A1/A2 remain canonical data/chemistry owners.

## 6. Post-approval acceptance cases (specification only)

| Test ID | Test condition | Required verdict / owner |
| --- | --- | --- |
| CLI-A4-01 | Valid synthetic closed first-order A→B with explicit canonical refs, amounts mol, volume m³, k in `s⁻¹`, orders and verified **synthetic** total law | Completed analytic profile `n_A(t)=n_A(0)e^{-kt}` and law residual; must be labelled synthetic, not source-backed chemistry. A4 + integrator/A5. |
| CLI-A4-02 | Parsed chemical equation with no independent kinetic orders/k | Block before `Run`; do not infer from stoichiometry. A2/integrator/A4. |
| CLI-A4-03 | Wrong k dimension, unknown unit, missing volume or temperature applicability | Block with typed responsible field and no result series. A1/integrator/A4. |
| CLI-A4-04 | Reversible `K`-only, open flow, dynamic T, discrete event/replay | Block unsupported model, never silently downgrade to A4 closed irreversible. A4/integrator. |
| CLI-A4-05 | Global step budget stops after valid prefix | Specific `step_limit` plus completeness `partial`; last valid t and request end distinct; no invented tail. A4/A5. |
| CLI-A4-06 | Cancellation midway through interval; killed/timeout subprocess | No falsely successful response; distinct transport vs numerical cancellation, partial prefix only when validated/atomic file exists. Work counters caveat preserved. A4/integrator/A5. |
| CLI-A4-07 | Request/response correlation mismatch, unsupported version, missing `request_message_id`/`outcome`, invalid value status, non-finite amount | Reject even if generic Envelope schema otherwise accepts incomplete shape. Integrator/A4/A5. |
| CLI-A4-08 | Response contains duplicate/decreasing times, extra/missing species, wrong final timestamp, stale nonce | Reject series as structurally invalid; no graph. Integrator/A5. |
| CLI-A4-09 | Scientific law/provenance unavailable but numerically valid synthetic trajectory | Do not label `verified` or `chemistry_conserved`; display data quality and conservation coverage separately. A1/integrator/A5. |
| CLI-A4-10 | Real bundled Windows x64 offline file runner from clean folder with Unicode paths and user:// temporary directory | Required **actual Windows execution evidence** including artifact, hashes, steps, diagnostics and environment. Integrator/A4/A5. |

## 7. Requested decisions / evidence

**Integrator:** choose a single conditional response envelope validation rule (`kind=simulation_result` requires correlation/outcome), specify typed payload schemas, canonical rate dimensions and status mapping so `partial` never erases `step_limit` or `invariant_violation`; publish process security, resource limits and Windows exit-code policy. Existing candidate schema does **not** yet prove these rules.

**A1/A2:** approved stable canonical input IDs, composition/charge provenance and rate/quantity validity checks; parser-local offsets not persisted as IDs; scientific admission distinct from synthetic test data.

**A5:** confirm consumer accepts only same-request, structurally validated, bounded and fully flushed response; no graph for failed/unmatched payload, no invented rate/T/replay series, no blocking main-thread invocation.

**Product owner:** explicitly approve OpenSpec baseline SHA/version, integrator v0.1 contract/bridge and stage-one *synthetic engineering smoke* scope before **any** A4 CLI implementation. Integrator is not the owner-signoff substitute. Existing PR #1 remains Draft.

**Definition of done for this research checkpoint:** checked actual A4 library project and numeric API, read integrator v0.1 documents and schema, documented field/status/security/acceptance mapping, committed doc in A4 branch, exact-head CI checked and review requested. **Integrated CLI/E2E readiness remains BLOCKED**, not DONE.
