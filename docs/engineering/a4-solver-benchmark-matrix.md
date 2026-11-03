# A4 Solver Benchmark Matrix

Status: research/validation plan. This document does not authorize a new solver method or expand the implemented model.

## Purpose

Establish reproducible evidence for the current explicit Dormand–Prince 5(4) solver, define its useful non-stiff operating envelope, and identify when a separately scoped stiff solver investigation is justified. Benchmarks must separate numerical correctness from runtime performance.

## Model boundary for the current baseline

The implemented baseline is a closed, constant-volume, isothermal species-amount ODE:

- State: species amounts (n_i), mol.
- Concentration: (c_i=n_i/V), mol m⁻³.
- Volumetric power law: (r_j=k_j\prod_i c_i^{\alpha_{ij}}), mol m⁻³ s⁻¹.
- Extent rate: (\dot\xi_j=V r_j), mol s⁻¹.
- Species derivative: (\dot n_i=\sum_j\nu_{ij}\dot\xi_j).
- Kinetic orders are explicit non-negative real inputs and are independent of stoichiometric coefficients.
- Rate-constant concentration exponent is (1-\sum_i\alpha_{ij}), consistent with the current `RateConstant` contract.

Open-system feeds/events, temperature dependence, reversible kinetics, finite-rate mixing and equilibrium coupling are not part of these benchmarks.

## Correctness benchmark matrix

| ID | Case | Model / reference | Primary purpose |
|---|---|---|---|
| KIN-01 | First-order A → B | (\dot n_A=-kn_A); (n_A(t)=n_{A0}e^{-kt}), (n_B=n_{A0}-n_A) | Baseline order, units, analytical accuracy |
| KIN-02 | Zero-order A → B | (\dot n_A=-kV); use only an interval before depletion, (n_A=n_{A0}-kVt) | Zero-order law and volume scaling |
| KIN-03 | Second-order 2A → B | (\dot n_A=-2k n_A^2/V); (n_A=n_{A0}/(1+2kn_{A0}t/V)) | Kinetic order distinct from stoichiometry |
| KIN-04 | Fractional-order A → B, order 1/2 | (\dot n_A=-kV^{1/2}n_A^{1/2}); while positive, (\sqrt{n_A}=\sqrt{n_{A0}}-kV^{1/2}t/2) | Fractional-order evaluation and scale robustness |
| KIN-05 | Consecutive A → B → C, equal first-order constants | (A=e^{-kt}), (B=kt e^{-kt}), (C=1-A-B) for unit initial A | Coupled reaction network and transient intermediate |
| KIN-06 | Parallel A → B and A → C | (A=e^{-(k_1+k_2)t}); (B=k_1(1-A)/(k_1+k_2)); (C=k_2(1-A)/(k_1+k_2)) | Multiple pathways and shared-reactant coupling |
| KIN-07 | Large timestamp / short elapsed interval | Same first-order analytic case, with large absolute start time and representable short duration | Time-coordinate precision and reproducibility |
| KIN-08 | Fractional-order extreme scale | Existing regression: (n_{A0}=10^{-300}) mol, (V=10^{100}) m³, order 1/2 | Prevent intermediate concentration/rate underflow |

For each analytic case, use SI units and publish the exact input parameters, output times and closed-form reference values with the benchmark result. Avoid testing zero-order depletion exactly at the discontinuity: the current solver models a smooth ODE and does not define a separate depletion event.

## Stiff reference cases

These cases are diagnostic stress tests, not current RK45 pass guarantees.

### STIFF-01 — Robertson kinetics

Use three species A, B, C and the following irreversible power-law reactions:

1. A → B, (r_1=0.04[A]).
2. B + C → A + C, with C acting as a catalyst (zero net stoichiometric coefficient for C, so C appears in the kinetic orders but not the net stoichiometry), (r_2=10^4[B][C]).
3. 2B → B + C, (r_3=3\times10^7[B]^2).

Initial state: A=1 mol, B=0 mol, C=0 mol; volume 1 m³. The sum A+B+C is invariant. This is a standard stiff kinetic structure with a fast transient and widely separated reaction time scales. The reference trajectory must come from an independently validated high-accuracy implementation or published reference values, not from the solver under test.

### STIFF-01 reference data — provisional cross-check

A static reference trajectory is stored in `docs/engineering/benchmarks/robertson-stiff-reference.csv`. It was generated offline with SciPy 1.17.0 `solve_ivp` using both `Radau` and `BDF`, each with `rtol=1e-12`, `atol=1e-15`, initial state (1,0,0), integration interval [0, 1e6] s, and requested samples at 0, 0.4, 4, 40, 1e3, 1e5 and 1e6 s. The one-time generation does not add a Python dependency to ChemSim.

Recorded work counters:

| Method | nfev | njev | nlu |
|---|---:|---:|---:|
| Radau | 45,978 | 11 | 252 |
| BDF | 6,520 | 9 | 501 |

The maximum absolute disagreement between the two trajectories at the requested samples is `2.1886270573645561e-11` in the state units (mol; V=1 m³). Maximum `|A+B+C-1|` across the requested samples is below `4.8e-15` for both methods. Both methods reached the final time successfully.

**Reference status:** provisional computational cross-check, not a published authoritative reference. Radau and BDF are distinct stiff integration algorithms from the same SciPy release, not independent software implementations. Preserve the method/version/tolerances with the CSV; do not silently replace these values. Before using them as strict CI acceptance thresholds, cross-check against a separate implementation or published reference and document any differences.

### STIFF-02 — Separated first-order time scales

Use A → B with (k_f=10^6\ s^{-1}) and B → C with (k_s=1\ s^{-1}), initial A=1 mol, B=C=0, volume 1 m³. The analytic solution is:

- (A(t)=e^{-k_ft})
- (B(t)=\frac{k_f}{k_f-k_s}(e^{-k_st}-e^{-k_ft}))
- (C(t)=1-A(t)-B(t))

This provides a stiff transient with an independent closed-form reference and exact total-amount invariant.

For both stiff cases, record whether RK45 succeeds within the configured step budget, how many steps/rejections/RHS evaluations it uses, and whether the requested accuracy is achieved. A budget exhaustion or excessive work is a valid finding about the explicit method's applicability; do not weaken correctness criteria to make it pass.

### STIFF-02 diagnostic execution — separated first-order time scales

Added `StiffBenchmarkTests.SeparatedFirstOrderTimeScales_MatchesAnalyticalProfileAndReportsWork` for A→B→C with `kf=1e6 s⁻¹`, `ks=1 s⁻¹`, initial state (1,0,0) mol and V=1 m³. The test uses the closed-form trajectory:

- `A(t)=exp(-kf t)`
- `B(t)=kf/(kf-ks) * (exp(-ks t)-exp(-kf t))`
- `C(t)=1-A(t)-B(t)`

Two schedules cover complementary regions without generating millions of uniformly spaced output points: a fast-layer window [0, 1e-5] s sampled every 1e-6 s, and a slow-tail window [0, 5] s sampled every 0.5 s. Both runs completed successfully with the current explicit RK45 solver under a 100,000 internal-step budget. Every requested sample is checked against the closed form (absolute tolerance 5e-7 mol); non-negativity and the A+B+C=1 invariant are checked separately. The test also verifies that accepted-step and RHS-evaluation diagnostics are populated. It does not assert a wall-clock threshold or claim that RK45 is generally suitable for stiff systems.

.NET 10 Restore, Build and all 30 tests passed on exact source/test commit `91d9af535b79f119e45a2d2a794b4c315463f95a` in GitHub Actions run [41612899661](https://github.com/AndreyCokol/ChemSim/actions/runs/41612899661).

## Tolerance-convergence protocol

Run each correctness case with at least three tolerance pairs, for example:

- Loose: rtol=1e-4, atol=1e-9 mol.
- Baseline: rtol=1e-6, atol=1e-12 mol.
- Tight: rtol=1e-8, atol=1e-14 mol.

These are starting points for the benchmark, not universal recommended settings. Ensure the chosen absolute tolerance is meaningful for the scale of each case; add a scale-adjusted sweep for very small or very large amounts.

At each requested output time, compare every species amount with the analytic or independent reference. Report:
- maximum absolute error;
- maximum component-scaled error using the same declared atol/rtol convention;
- error trend as tolerances tighten;
- minimum amount reached and any non-physical/numerical status;
- maximum conservation-law drift.

Do not require the global error to be ≤1 times the local error tolerance without calibration: the integrator's embedded estimate controls local steps, while accumulated global error is problem-dependent. Instead, establish expected convergence trends and calibrated case-specific acceptance thresholds. A tighter run must not silently produce a materially worse result; investigate any non-monotone result rather than automatically failing on roundoff-level variation.

## Performance and diagnostics

For every run, record:

- solver/library commit SHA, .NET SDK/runtime, OS and CPU;
- exact network, initial state, volume, interval, output schedule and solver options;
- elapsed wall-clock time (Release build; warm-up followed by repeated runs; report median and spread);
- accepted steps, rejected steps and RHS evaluations;
- peak allocated bytes if measured by the harness;
- termination status and diagnostic message.

Keep wall-clock thresholds out of ordinary CI until the execution environment is controlled. Correctness, conservation, positivity and deterministic diagnostics are CI gates; runtime and allocation data are initially trend metrics.

## Candidate-method comparison gate

Do not select or implement an implicit solver based on reputation or convenience alone. If STIFF-01/02 show that RK45 cannot meet the accuracy and step-budget targets, compare candidate families on the same validated cases:

- BDF (variable order, nonlinear solve and Jacobian costs);
- Radau IIA (implicit collocation, high stability for stiff systems);
- Rosenbrock/W-methods (linearly implicit stages, Jacobian-related costs).

The comparison must include accuracy against independent references, positivity behavior, conservation drift, work counters (RHS/Jacobian evaluations and linear solves), memory and wall-clock time. Record implementation/library versions and configuration. A candidate is eligible for a separate implementation proposal only if it materially improves stiff-case feasibility without regressing the non-stiff baseline or weakening failure reporting.

## Acceptance checklist

- [ ] Every analytic case has a machine-readable or otherwise unambiguous reference definition.
- [ ] Loose/baseline/tight tolerance runs and convergence evidence are recorded.
- [ ] Positivity and conservation are checked independently of the solver's success status.
- [ ] Stiff reference cases have independent reference trajectories and declared resource budgets.
- [ ] Performance reports include exact commit/runtime/hardware metadata.
- [ ] Solver-family selection, if any, is supported by comparative measurements and a separate approved scope.

## Output-interval controller continuity

The simulator previously created a fresh Dormand–Prince integrator for every requested output segment and supplied the configured initial step each time. That reset discarded the controller's next-step suggestion at every sample boundary, even though output sampling does not change the underlying ODE.

The simulator now carries the accepted controller's suggested next step into the next segment. The suggestion is bounded below by the configured minimum step so a short final clipped step cannot make the following segment fail solely because its inherited starting step is below the minimum. Output timestamps, state samples, error tolerances and ODE semantics are unchanged.

Regression: `OutputSamplingInterval_DoesNotResetAdaptiveStepController` compares the same first-order A→B trajectory over 0–10 s with 1 s and 0.125 s output intervals (11 versus 81 samples). It checks the common-time analytical profiles and directly compares accepted-step and RHS-evaluation diagnostics, allowing the fine schedule its unavoidable additional segment-boundary steps but not a repeated controller warm-up at every boundary. No wall-clock performance claim is made.

The source/test commit `47019845d487b52bed81945af7e796e788934f84` passed .NET 10 Restore, Build and Test in GitHub Actions run [41612326223](https://github.com/AndreyCokol/ChemSim/actions/runs/41612326223).

## Implementation coverage checkpoint (2026-11-03)

The following analytic/non-stiff cases now have executable regression coverage in the A4 test project:

| Case | Regression test | Coverage |
|---|---|---|
| KIN-01 | FirstOrderReaction_MatchesAnalyticalSolution_AndConservesAmount; FirstOrderReaction_MatchesAnalyticalProfileAtEveryOutputSample | First-order analytical endpoint plus every output sample, positivity and amount invariant |
| KIN-02 | ZeroOrderReaction_MatchesAnalyticalProfileAndVolumeScalingBeforeDepletion | Full output profile, non-unit volume, positivity and conservation before depletion |
| KIN-03 | SecondOrderReaction_UsesKineticOrderNotStoichiometricCoefficient; SecondOrderReaction_MatchesAnalyticalProfileAtEveryOutputSample | Second-order analytical endpoint plus every output sample, positivity, A+2B invariant and stoichiometric/kinetic-order distinction |
| KIN-04 | FractionalOrderHalfReaction_MatchesAnalyticalProfileAtNonUnitVolume | Half-order full profile at non-unit volume, positivity and conservation |
| KIN-05 | ConsecutiveFirstOrderNetwork_MatchesAnalyticalProfileAndConservesAmount | Equal-rate consecutive network, all output samples, positivity and invariant |
| KIN-06 | ParallelFirstOrderPathways_MatchAnalyticalProfileAndBranchingRatio | Competing pathways, all output samples, positivity, invariant and branching ratio |
| KIN-07 | Integrator_DoesNotTruncateIntervalAtLargeAbsoluteTime | Large absolute timestamp / short elapsed interval |
| KIN-08 | FractionalOrder_ExtentRateDoesNotUnderflowThroughIntermediateConcentration | Extreme-scale fractional-order extent-rate underflow regression |
| TOL-01 | FirstOrderReaction_ProfileErrorDecreasesAsTolerancesTighten | First-order loose/baseline/tight relative-tolerance sweep; maximum analytical profile error decreases without wall-clock thresholds |
| TOL-02 | SecondOrderReaction_ProfileErrorDecreasesAsTolerancesTighten | Second-order 2A → B analytic endpoint sweep at rtol 1e-2, 1e-4 and 1e-6; maximum endpoint error decreases without wall-clock thresholds |

Exact validated A4 source/test head for the initial KIN/TOL-01 coverage: a417ef73fbf96366cbacd4f2b7c9223365a9cece. GitHub Actions run 41608390859 passed .NET 10 Restore, Build and Test on that head. TOL-02 extends the sweep to the second-order 2A → B analytic solution; it uses a deliberately coarser output horizon so the step controller, rather than repeated output-segment clipping, determines the tolerance response. Exact source/test head `4b7f31fdf796835a98803fc6d761877836d667b6` passed .NET 10 Restore, Build and all 32 tests in run [41614568333](https://github.com/AndreyCokol/ChemSim/actions/runs/41614568333). The test cases establish correctness coverage for the listed individual fixtures; they do not yet constitute the full tolerance-convergence campaign or a measured performance report.

STIFF-01 now has a provisional Radau/BDF cross-check stored in `docs/engineering/benchmarks/robertson-stiff-reference.csv`; STIFF-02 has a closed-form analytic reference. No controlled performance comparison or implicit-method selection is claimed at this checkpoint.

## Limitations

This matrix does not validate thermodynamic equilibrium, Arrhenius temperature dependence, reversible kinetics, gas equations of state, open-system forcing, discrete events, finite-rate mixing or Godot presentation. It does not claim that RK45 is appropriate for stiff chemical systems. Those capabilities require their own models, data contracts and validation evidence.


### STIFF-01 diagnostic execution — Robertson / explicit RK45

Added `RobertsonStiffBenchmarkTests.RobertsonStiffSystem_ReportsExplicitSolverFeasibilityAgainstProvisionalReference`. The test builds the canonical three-reaction Robertson network (including the catalytic `B + C → A + C` step), starts from (A,B,C)=(1,0,0) mol at V=1 m³, and attempts the [0, 1e6] s horizon with rtol=1e-7, atol=1e-12 mol and a 50,000 internal-step budget. The terminal comparison values are taken from the stored provisional SciPy 1.17.0 Radau/BDF cross-check; they are used only if RK45 reaches the requested endpoint.

Observed on .NET 10 CI: RK45 returned `MaximumStepsExceeded` at t=38.841706914185899 s, after 33,349 accepted and 16,651 rejected steps (50,000 total) and 350,000 RHS evaluations. It therefore did not reach the 1e6 s reference checkpoint, and no terminal accuracy claim is made. The regression asserts the explicit failure status, exact budget accounting, populated RHS work, and positivity/conservation for all states returned by the simulator. This is a concrete feasibility limitation of the current explicit method under the declared budget, not a solver defect by itself and not authorization to add an implicit method.

Source/test commits: `45b1fe3aa562baf24aed06ca87426cf30e3ddba7` (initial diagnostic) and `b5f0a10100011afe15a456b8a0720f812ab38b07` (work-counter output), followed by returned-state assertions in `863aac8f4a432be71f5ee05a78587f27d514ac5b`. The .NET 10 Restore, Build and all 31 tests passed on the exact final source/test commit in GitHub Actions run [41613973771](https://github.com/AndreyCokol/ChemSim/actions/runs/41613973771). The CI test output recorded the status and counters above. The provisional Radau/BDF reference remains a cross-check, not a published authoritative trajectory.


### TOL-02 execution — second-order analytic convergence

Added `ToleranceConvergenceBenchmarkTests.SecondOrderReaction_ProfileErrorDecreasesAsTolerancesTighten` for 2A → B with kinetic order 2, initial A=2 mol, V=1 m³ and k=0.1 in the declared SI rate-constant contract. The exact profile is (A(t)=A_0/(1+2kA_0t/V)), (B(t)=(A_0-A(t))/2). The test compares the maximum endpoint amount error for rtol 1e-2, 1e-4 and 1e-6, with atol=1e-14 mol, and requires a clear reduction at each tightening. A single requested terminal sample over the 10 s horizon avoids clipping every internal step at short output intervals, which had masked the tolerance response in the initial calibration attempts.

Exact source/test commit `4b7f31fdf796835a98803fc6d761877836d667b6` passed .NET 10 Restore, Build and all 32 tests in GitHub Actions run [41614568333](https://github.com/AndreyCokol/ChemSim/actions/runs/41614568333). No wall-clock threshold is used.


### TOL-03 execution — consecutive first-order network

Added `ToleranceConvergenceBenchmarkTests.ConsecutiveFirstOrderNetwork_ProfileErrorDecreasesAsTolerancesTighten` for the coupled equal-rate sequence A → B → C, with k=0.4 s⁻¹, initial (A,B,C)=(1,0,0) mol, V=1 m³ and a 5 s integration horizon. The analytical reference is A(t)=exp(-kt), B(t)=kt exp(-kt), C(t)=1-A(t)-B(t). The test compares the maximum absolute species-amount error at the requested terminal profile across rtol=1e-2, 1e-4 and 1e-6 (atol=1e-14 mol), requires at least a factor-of-two error reduction at each tightening, and independently checks positivity and A+B+C conservation. The terminal-only output schedule deliberately avoids segment-boundary clipping masking the tolerance response, as encountered during initial calibration; it does not claim a full time-profile sweep.

Exact source/test commit `6d5f252bb12bc1c3761f96ff460ecba9258a4e34` passed .NET 10 Restore, Build and all 33 tests in GitHub Actions run [41617006331](https://github.com/AndreyCokol/ChemSim/actions/runs/41617006331). Two earlier calibration attempts exposed that this coupled case did not produce the required reduction under the first output schedule; those assertions were not weakened. The final schedule was changed to one terminal segment and the broader tolerances were re-calibrated; the passing test retains the explicit factor-of-two convergence gates.


### BENCH-PERF-01 execution — first non-stiff Release baseline

Added `KineticsPerformanceBenchmarkTests.RepresentativeNonStiffCases_ReportPerformanceAndSolverWorkWithoutTimingGate`. It runs three representative cases (first-order A→B, second-order 2A→B, and equal-rate consecutive A→B→C) with rtol=1e-8, atol=1e-12 mol over 0–10 s. Each case receives two warm-up runs and nine measured runs. The harness records median and min/max wall-clock time, median current-thread allocated bytes, accepted/rejected steps, RHS evaluations and status. Timing is diagnostic only; no wall-clock assertion is present. GC collection is requested before each measured run.

Initial GitHub Actions runner baseline (Release, .NET 10.0.14, Ubuntu 24.04.5 LTS, linux-x64, 4 logical processors; CPU model was not exposed by the runtime):

| Case | Median | Range (min–max) | Median allocated | Accepted | Rejected | RHS |
|---|---:|---:|---:|---:|---:|---:|
| First-order A→B | 1.1258 ms | 1.0132–1.3110 ms | 153,976 B | 56 | 0 | 392 |
| Second-order 2A→B | 0.7324 ms | 0.6637–0.9201 ms | 97,024 B | 35 | 0 | 245 |
| Consecutive A→B→C | 1.6192 ms | 1.5940–1.6530 ms | 215,408 B | 59 | 0 | 413 |

Exact source/test commit `e86c50ebe52d10c704d73ff8497dc84859f1ba27` passed .NET 10 Restore, Build and all 34 tests in GitHub Actions run [41617331272](https://github.com/AndreyCokol/ChemSim/actions/runs/41617331272). The values are a first CI-run trend baseline, not portable performance claims: the CPU model is unavailable, runner contention is uncontrolled, and a single CI environment is insufficient for comparative conclusions. Re-run on a pinned local/CI hardware profile and collect repeated independent sessions before using these values to select optimizations or compare solver families.


### TOL-04 execution — parallel competing first-order pathways

Added `ToleranceConvergenceBenchmarkTests.ParallelFirstOrderPathways_ProfileErrorDecreasesAsTolerancesTighten` for A → B (k₁=0.7 s⁻¹) and A → C (k₂=0.3 s⁻¹), with initial (A,B,C)=(1,0,0) mol, V=1 m³ and terminal time 5 s. The closed-form reference is A=exp(-(k₁+k₂)t), B=k₁/(k₁+k₂)·(1-A), C=k₂/(k₁+k₂)·(1-A). The test compares all three terminal species amounts at rtol=1e-2, 1e-4 and 1e-6 (atol=1e-14 mol), requires at least a factor-of-two reduction in maximum absolute error at each tightening, and separately checks finite non-negative amounts and A+B+C conservation. This is terminal-state convergence evidence, not a full time-profile sweep.

Exact source/test commit `21c69c84e177312c5b334a3ced10de66bf97cce0` passed .NET 10 Restore, Build and all 35 tests in GitHub Actions run [41617703949](https://github.com/AndreyCokol/ChemSim/actions/runs/41617703949). No wall-clock gate or solver implementation change was introduced.


### TOL-05 execution — fractional-order analytic convergence

Added `ToleranceConvergenceBenchmarkTests.HalfOrderReaction_ProfileErrorDecreasesAsTolerancesTighten` for A → B with kinetic order 1/2, initial A=4 mol, V=2 m³, k=0.6 in the declared SI rate-constant contract, and terminal time 2 s. The closed form is \(\sqrt{A(t)}=\sqrt{A_0}-k\sqrt{V}t/2\), with B=A₀−A. The test compares maximum terminal species-amount error at rtol=1e-2, 1e-4 and 1e-6 (atol=1e-14 mol), requires at least a factor-of-two reduction at each tightening, and independently asserts finite non-negative amounts and A+B conservation. The 2 s horizon was calibrated after the initial 1 s fixture produced indistinguishable loose/baseline errors; the convergence gates were retained unchanged. No solver implementation was modified.

Exact source/test commit `32fa6797f58ce55c21d9072f04a016e95855c263` passed .NET 10 Restore, Build and all 36 tests in both push run [41619703969](https://github.com/AndreyCokol/ChemSim/actions/runs/41619703969) and PR run [41619711656](https://github.com/AndreyCokol/ChemSim/actions/runs/41619711656). The earlier exact-head run on `0ee1310ac45919b87bc032769f940280a962351c` correctly failed the initial convergence assertion; it is superseded by the calibrated fixture and is not acceptance evidence.
