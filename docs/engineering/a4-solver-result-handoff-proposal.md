# A4 solver-result → A5 graph/timeline handoff (P1 design proposal)

**Agent:** A4 — Kinetics & Numerical Solver. **Task:** A4-RESULT-MVP (research checkpoint). **Date:** 2026-11-03.  
**Status:** A4 implementation-aligned proposal, **not** a versioned public `SolverResult`, `GraphSeries`, `ReliabilityVector` or `ErrorEnvelope` freeze; not permission to implement the A5 adapter.  
**Tracking:** [Issue #12](https://github.com/AndreyCokol/ChemSim/issues/12) and [Draft PR #6](https://github.com/AndreyCokol/ChemSim/pull/6); sources `src/ChemSim.Kinetics/Simulation/SimulationContracts.cs`, `KineticsSimulator.cs` and existing `KineticsSimulatorTests.cs` on `feature/a4-kinetics-core`. Cross-check: [A5 mapping proposal](https://github.com/AndreyCokol/ChemSim/blob/agent/a5-ux-integration-review/openspec/agents/reviews/agent-05-presentation-mapping-draft.md) and [A5 round-3 review](https://github.com/AndreyCokol/ChemSim/blob/agent/a5-ux-integration-review/openspec/agents/reviews/agent-05-round-3-dataflow-contract-review.md); INT-15/19/20/22 and GraphSeries decision remain unresolved.

## 1. What the current A4 code actually returns

```text
SimulationResult:
  Status: SimulationStatus
  Samples: IReadOnlyList<StateSample>
  Diagnostics: SimulationDiagnostics
  IsSuccess: (Status == Success)

StateSample:
  TimeSeconds: double
  AmountsMol: IReadOnlyDictionary<string, double>  // species ID -> mol

SimulationDiagnostics:
  AcceptedSteps: int
  RejectedSteps: int
  RightHandSideEvaluations: int
  Message: string?  // human-readable, not a stable machine error code
```

These are **in-process C# records**, not JSON/wire DTOs; the current Godot GDScript shell does not consume them. There is no schema version, canonical result/reaction revision, last-good-time field, per-sample quality/reliability flag, residual array, local error per point, current rate series, temperature time series, event ledger, replay identity/hash, or a structured error code in the current result type. Do not claim otherwise.

**Publication rule observed in `Run`:** A validated request starts with a single initial-state sample at `StartTimeSeconds`. It integrates each full output interval, adds its accepted/rejected/RHS diagnostic work, then checks optional conservation laws; only **after successful integration and conservation check** is a sample appended at the target time. A failed/incomplete interval never publishes its intermediate or failed endpoint as a new `StateSample`. `Success` returns the initial sample plus all completed intervals through `EndTimeSeconds`. Pre-validation `ArgumentException` returns `InvalidInput`, **zero samples** and zero counters. The public method's `Run(null!)` guard throws `ArgumentNullException`; a boundary adapter must not assume *every* invalid public invocation returns `InvalidInput`.

**Important counter caveat:** on an integrator **outcome** that reports failure, work counters from that failed integration attempt are added to `SimulationDiagnostics`. However, when cancellation raises `OperationCanceledException` inside the currently executing integrator interval, the `Run` catch returns the counters accumulated before that interval (the integrator did not return an outcome). Thus cancellation counters are **not guaranteed to include all in-flight attempted work**. Do not describe those counters as exact lifetime totals for mid-interval cancellation without a code change and regression test. The existing public pre-cancel test only asserts the initial sample, not all cancellation work paths.

## 2. Eight current statuses and proposed consumer interpretation (NOT final wire codes)

| A4 `SimulationStatus` | A4 completion | Valid-prefix shape (observed/possible) | Safe UI proposal |
| --- | --- | --- | --- |
| `Success` | Sole nominal complete status | Initial sample + each completed output target, final endpoint published | **Completed** only after adapter validates sample structure and endpoint, with model/data applicability reported separately. |
| `InvalidInput` | Not complete | **Empty** for pre-run validation; **nonempty prefix** is possible for a representable-time failure discovered at a later output interval | **Blocked/Failed** by actual machine reason; do not infer sample count solely from status. |
| `StepSizeUnderflow` | Not complete | Valid prefix, possibly initial only | **Numerical stop**, show reason and last validated time, no future points. |
| `MaximumStepsExceeded` | Not complete | Valid prefix, including previously completed output segments | **Budget stop**, not a successful shortened trajectory. |
| `NonPhysicalState` | Not complete | Valid prefix | **Numerical/domain stop**, never clip negative values to zero for the graph. |
| `ConservationFailure` | Not complete | Valid prefix **excluding** the segment that triggered the invariant failure | **Invariant stop**; do not publish or draw invalid target, preserve diagnostic. |
| `Cancelled` | Not complete | At least initial sample if request valid; valid completed output segments may precede cancellation | **Cancelled**, prefix only; warn that mid-interval work counters may omit abandoned work. |
| `NumericalFailure` | Not complete | Valid prefix; non-finite attempted RHS or arithmetic state not published | **Numerical stop**, preserve original diagnostic message, never interpolate failure state. |

A valid prefix can be rendered **as a partial trajectory**, not as a completed result. `IsSuccess` is true **only** when `Status == Success`; neither `Samples.Count > 0` nor an apparent late timestamp overrides a failure status. A partial trajectory is not automatically scientifically valid: model applicability, initial-data quality and actual conservation-law coverage remain separate checks.

## 3. Proposed adapter admission and output metadata (no implementation)

**Source/request association:** carry an approved `experiment_id`, exact simulation-input revision/hash (once INT-18 is settled), stable species/reaction/model revisions, requested start/end times in seconds, solver class/version/settings and declared fixed volume in m³. The current A4 record does **not** include this; the integration layer must attach/validate it without pretending the solver returned it.

**Validate result before graphing or exporting:**

1. Require one authoritative numerical status and distinguish **requested end** from **last published validated timestamp**. For zero samples, last time is **absent**, not zero. The presence of an initial sample alone means **no completed output segment**, not numerical progress.
2. Every sample time must be finite, within requested bounds, and strictly increasing for this **no-event** solver slice. A4 uses absolute model time (s); current output has no same-timestamp event snapshots. Do not impose this strict rule on a future event model without revisiting INT-17.
3. Every published `AmountsMol` dictionary must exactly cover the approved canonical species IDs, with finite nonnegative values. Verify `Success` includes the requested final timestamp under an approved floating-point comparison policy. Failure results must not be upgraded to completed even if they contain a timestamp equal/near the requested end.
4. In the **fixed-volume** case only, a concentration GraphSeries may use `c_i = n_i / V` [mol·m⁻³] after validated unit conversion. The adapter must reject non-finite concentration arithmetic even when amount and volume are finite. A5 itself uses the approved Unit Registry for display conversion; it must not invent physical conversion rules.
5. For failure/cancellation, render validated prefix points only, stop the line at the last valid timestamp, and mark the gap/uncomputed remainder. No zero filling, extrapolation, smoothing across invalid/missing segments, or hidden failure reason.
6. A4 currently supplies no per-output **rate** or **computed temperature** series. Do not create one by differentiating amounts or reusing the numerical solver's internal RHS work counters. A5 may display a constant declared isothermal model T as **input metadata**, not as a computed thermal curve, if approved upstream.
7. A4 does not return event/rewind snapshots; graph cursor movement through completed sample history is **not** event-driven replay, and no bitwise deterministic rewind promise is warranted.
8. Accept `SimulationDiagnostics` counters as nonnegative **observed work telemetry**, not a direct error estimate or scientific validity indicator. `Message` is unstructured; only the approved shared `ErrorEnvelope` and its controlled code set can drive stable UI localization and recoverability rules.

**Proposed shared completeness concept, not enum:** `complete` iff status is `Success` **and** the adapter's structural/final-time validation succeeds; `partial` iff status is non-success and at least one validated sample exists; `no_result` iff status is non-success and no validated sample exists. Separately represent `cancelled`, `blocked_invalid_input`, `numerical_stop`, or `invariant_stop` as termination categories, and independently `model_validity`, `data_quality`, `conservation_coverage`. These words are **review labels**, not approved wire tokens or A5 UX enum names.

## 4. Existing executable evidence and proposed P1 negative tests

Existing isolated tests in `tests/ChemSim.Kinetics.Tests/KineticsSimulatorTests.cs` cover:

| Case | Existing test and asserted evidence | Consumer expectation after approval |
| --- | --- | --- |
| RES-01 | `FirstOrderReaction_MatchesAnalyticalSolution_AndConservesAmount` | Success yields completed time series; future adapter confirms exact species/endpoint and units. |
| RES-02 | `MissingInitialSpecies_IsRejectedBeforeIntegration` | InvalidInput must not be displayed as a complete empty experiment. Proposed follow-up: explicitly assert no sample/counters when pre-validation rejects input. |
| RES-03 | `MaximumInternalSteps_IsSharedAcrossOutputIntervals`: step budget 1, samples at t=0 and 0.1 s; requested end 0.2 s, `MaximumStepsExceeded` | Valid prefix is visibly incomplete; never draw 0.1→0.2 s as computed. |
| RES-04 | `MaximumInternalSteps_CountsRejectedTrialsAgainstGlobalBudget`: zero accepted, one rejected, seven RHS evaluations, **initial sample only** | Initial-only sample is not evidence of completed integration. |
| RES-05 | `PreCancelledRequest_ReturnsCancelledWithoutAdvancingState`: `Cancelled` with initial sample | Display Cancelled, not Completed; future mid-interval cancellation test should characterize counter accounting. |
| RES-06 | `NonFiniteReactionRate_ReturnsNumericalFailureWithoutPublishingInvalidSample`: 1 RHS invocation and only initial sample | No NaN point or synthetic zero; diagnostic preserved. |
| RES-07 | `ConservationEvaluation_OverflowReturnsNumericalFailure`: only initial sample, no non-finite target | Distinguish numerical arithmetic failure from a successful constant result. |
| RES-08 | `OutputInterval_ThatStopsAdvancingAfterUlpBoundary_IsRejectedUpFront`: `InvalidInput`, empty samples | No graph and no default t=0 point; representable model-time policy is explicit. |

**Suggested P1 tests not yet implemented:** (a) A5 adapter receives a valid-prefix error and preserves status/time/counts; (b) corrupted transport result with duplicate/decreasing timestamps or missing/NaN amounts is rejected; (c) statuses never collapse into one `success` flag; (d) a valid `Success` is not called scientifically verified absent A1 conservation laws and applicability; (e) mid-interval cancellation work accounting is documented or made exact through A4 code + regression **only after approval**; (f) user-facing graph does not invent rate, temperature, rewind or event data.

## 5. Decisions requested from owners

- **Integrator / INT-15, INT-19, INT-20, INT-22:** Approve versioned `SolverResult`/typed `GraphSeries`, endpoint/time/sampling policy, shared `ErrorEnvelope` with stable machine code, separate reliability/completeness statuses and error-mapping ownership. Define which layer validates serialized series and carries input/model revisions.
- **A5:** Confirm graph-gap/partial-series representation and source/result version association; keep Run/Step/rewind disabled until actual runtime bridge and contracts exist. UI does **not** become solver/calculation owner.
- **A1:** Define source of validated elemental/charge conservation invariants and applicability/provenance needed before numerical success can be promoted to a scientifically admitted experiment.
- **A4:** After approval, add exact consumer-facing tests/implementation in A4-owned code only; no proprietary wire enum/DTO or cross-agent edits before contract freeze.

**Gate:** `main` OpenSpec remains DRAFT, owner sign-off and Stage 1–2 still unchecked. This document addresses the **research phase** only. Nothing here authorizes a runtime adapter, claims integrated CI or certifies a launch-ready ChemSim build.
