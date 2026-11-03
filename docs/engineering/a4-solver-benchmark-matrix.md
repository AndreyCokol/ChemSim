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

### STIFF-02 — Separated first-order time scales

Use A → B with (k_f=10^6\ s^{-1}) and B → C with (k_s=1\ s^{-1}), initial A=1 mol, B=C=0, volume 1 m³. The analytic solution is:

- (A(t)=e^{-k_ft})
- (B(t)=\frac{k_f}{k_f-k_s}(e^{-k_st}-e^{-k_ft}))
- (C(t)=1-A(t)-B(t))

This provides a stiff transient with an independent closed-form reference and exact total-amount invariant.

For both stiff cases, record whether RK45 succeeds within the configured step budget, how many steps/rejections/RHS evaluations it uses, and whether the requested accuracy is achieved. A budget exhaustion or excessive work is a valid finding about the explicit method's applicability; do not weaken correctness criteria to make it pass.

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

## Limitations

This matrix does not validate thermodynamic equilibrium, Arrhenius temperature dependence, reversible kinetics, gas equations of state, open-system forcing, discrete events, finite-rate mixing or Godot presentation. It does not claim that RK45 is appropriate for stiff chemical systems. Those capabilities require their own models, data contracts and validation evidence.
