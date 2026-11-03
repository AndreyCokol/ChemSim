# A4 conservation-law supply and acceptance — A1/A2 → A4 proposal

**Task:** A4-CONSERVATION-SPEC-01 (P1 research checkpoint within A4-CONSERVATION-MVP). **Owner:** Agent A4 — Kinetics & Numerical Solver. **Date:** 2026-11-03.  
**Status:** source-verified design/acceptance proposal **only**. Not an approved OpenSpec baseline, cross-agent DTO, imported scientific dataset or permission to modify runtime code.  
**Tracking:** [Issue #12](https://github.com/AndreyCokol/ChemSim/issues/12), [A4 Draft PR #6](https://github.com/AndreyCokol/ChemSim/pull/6). Relevant integration candidates: [cross-agent contract v0.1](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/contracts/mvp-cross-agent-contract-v0.1.md), [integrator closure](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/reviews/round-1/integrator-closure-2026-11-03.md), [bridge acceptance plan](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/contracts/mvp-bridge-and-acceptance-v0.1.md). Those decisions are **INTEGRATOR-DECIDED candidates, PENDING OWNER approval** in Draft PR #1.

## 1. What current A4 actually checks

Source audited on `feature/a4-kinetics-core`:
- `src/ChemSim.Kinetics/Domain/ConservationLaw.cs`: public, user-supplied sparse linear coefficients `w_i` keyed by network species ID, an invariant `I = Σ_i w_i n_i`, `n_i` in mol. Coefficients must be finite, nonzero for entries present and map only to present species; vector evaluation checks length, IDs, finiteness, completeness for **referenced** weights and overflow. An omitted coefficient means **zero**, not an unknown property.
- `src/ChemSim.Kinetics/Domain/ReactionNetwork.cs`: `conservationLaws` is **optional** (omitting/null means empty). For every supplied law and every reaction `j`, network construction checks the weighted stoichiometric residual `Σ_i w_i ν_ij` against `1e-12 × Σ_i |w_i ν_ij|`; finite arithmetic required. Species/reactions ordered deterministically by stable strings. This does **not** validate molecular formulas or create element/charge vectors.
- `src/ChemSim.Kinetics/Simulation/KineticsSimulator.cs`: after each **fully integrated output segment** and before publishing its target sample, evaluates each supplied invariant against initial `I_0`. The current code uses
  `tolerance = 10 × (AbsoluteToleranceMol × Σ|w_i| + RelativeTolerance × max(|I_0|, |I_t|))`.
  Excessive drift -> `ConservationFailure` and the offending target is **not** published. An overflow inside `ConservationLaw.Evaluate` throws `ArithmeticException` and is mapped by the top-level Run handler to `NumericalFailure`, not necessarily to `ConservationFailure`; non-finite comparison arithmetic detected by `CheckConservation` returns `ConservationFailure`. Both are non-success.
- Existing tests include `UnbalancedConservationLaw_IsRejectedWhenNetworkIsBuilt`, `ConservationValidation_IsInvariantToCoefficientScale`, `ConservationLaw_OverflowDuringNetworkValidationIsRejected`, `ConservationEvaluation_OverflowReturnsNumericalFailure`, `ConservationEvaluation_RejectsMissingSpeciesReferencedByLaw`, and first-/consecutive-/parallel-reaction examples with explicitly supplied invariant(s). These tests verify **numerical linear-law handling only**.

**Major scientific coverage gap:** `SimulationStatus.Success` with `ConservationLaws.Count == 0` means no chemical conservation constraint was supplied/monitored. A4 cannot infer chemical element counts, charge, mass, validity of a molecular formula, source provenance or phase appropriateness from species-ID strings. Similarly, one arbitrary user-defined linear law is **not** evidence that *every* element and charge is conserved. An integration adapter may not promote `Success` into `chemically_verified` merely because RK45 succeeded.

## 2. Deriving complete candidate laws from upstream typed chemistry

For a **closed, no-event, constant-volume** kinetic experiment using the integrator v0.1 candidate:

1. **A2 → canonical, versioned formula:** For every stable `SpeciesRef` in the A4 network, A2's authoritative `FormulaAST` must have validated exact non-negative integer element counts `a_{e i}` and signed integer net charge `z_i`, with known formula/AST revision and supported composition semantics. Source of truth: A2 `FormulaAST`; A1 `SubstanceRecord.formal_charge`, if ever displayed, is a *derived* projection only. Phase belongs to `SpeciesRef`, not the formula. Unresolved formula, duplicate/stale ID, unknown composition, unsupported isotope/electron/complex semantics or silent aliases -> **fail closed for a chemically verified run**.
2. **A1/integrator → identity, scientific admission:** Resolve the same *canonical stable* `species_id` across formula, reaction, kinetic order map, and initial amount; retain composition/phase/revision/provenance and model applicability. A2 parser-local source-offset `term_id` is **not** a durable species ID. A1 must state the data admissibility and any chemically necessary phase/charge/mass rules. An isolated *synthetic engineering* fixture may run as `user_supplied`/`hypothetical` but is not a verified physical reaction.
3. **A2 → signed stoichiometry:** `ν_{ij} = − coefficient` for reactant term and `+ coefficient` for product term, with canonical aggregation by **exact species reference** under the integrator's approved policy, integer-overflow guard, explicit reaction revision. Test exact elemental and charge balance for every reaction: `Σ_i a_{e i}ν_{ij}=0` for every element `e`, and `Σ_i z_iν_{ij}=0`. Prefer exact integer/checked wide-integer arithmetic for this **chemical admission check**; the A4 double-based threshold is not a substitute for exact atom/charge balancing. Kinetic orders remain independent of `ν`.
4. **A4 numerical-law supply:** After all network species have been resolved and validated, construct *one sparse linear row per present element* using **nonzero** `a_{e i}` entries, plus a sparse charge row from nonzero `z_i` if charged species are present. Zero coefficients must be **omitted**, not inserted into `ConservationLaw` (its constructor rejects zeros). Reject incomplete element coverage; distinguish zero-for-known-element from **unknown** composition. All-neutral species yield a trivially zero charge vector and need a *validated trivial-neutral coverage record* upstream, **not** a zero-valued `ConservationLaw`.
5. **Numerical verification:** Supply these laws to `ReactionNetwork`; require network validation for each reaction; run with documented solver policy; monitor each published output sample. Preserve `ConservationFailure`, `NumericalFailure`, partial-sample semantics, and actual coverage of derived laws in **separate reliability metadata**, not a fabricated single solver boolean.

**Dimensions:** `I_e=Σ_i a_{e i} n_i` is **mol of atoms of element e** (atom count per formula is dimensionless); `I_q=Σ_i z_i n_i` is **mol of elementary-charge equivalents**. Neither equals charge in coulombs without an explicit Faraday constant and unit conversion. `I_q(t)=I_q(0)` means **charge conservation**, not electroneutrality: a closed initially charged system can retain a nonzero `I_q` and pass that invariant while remaining outside the applicability of an electroneutral aqueous model.

**Mass is a different assertion:** Atom-balanced stoichiometry implies mass conservation only under the selected consistent isotope/atomic-weight model. Mass-weighted coefficients `M_i` require authoritative, consistently derived molar masses with compatible isotopic basis and provenance; A4 has none. Do **not** add a mass law from display names, assume equal masses of arbitrary A/B species or call an atom-count law a measured mass check. If isotope/formula composition is unresolved, mark mass validation **not assessed**.

**Current-slice restriction:** conservation `I=const` only applies to this closed no-flow/no-event kinetic RHS. Future open systems require an audited source/sink/event budget `d(Σw_i n_i)/dt=Σw_i(F_in−F_out)` plus discrete `ΔI_event`; do not apply the closed invariant unchanged to open flows or pretend open-system conservation is already supported.

## 3. Exact analytical admission vectors (stoichiometry only, NOT kinetic measurements)

The following coefficients and expected zero/nonzero residuals follow from symbolic atom counts and integer arithmetic. No kinetic `k`, `Ea`, `K` or sourced real-world trajectory is asserted. They are candidate test vectors, not yet end-to-end executable fixtures.

| ID | Signed reaction coefficients ν (reactants negative) | Element/charge weighted dot products `w·ν` | Required admission |
| --- | --- | --- | --- |
| INV-01: water-forming stoichiometry | H₂: −2; O₂: −1; H₂O: +2 | H: `2×(−2)+2×(+2)=0`; O: `2×(−1)+1×(+2)=0`; all charges 0 | Complete H, O law rows. No nonzero charge law needed because all known species neutral. **No kinetic time curve claimed.** |
| INV-02: neutralization / phase check | Ag⁺(aq): −1; Cl⁻(aq): −1; AgCl(s): +1 | Ag: `−1+1=0`; Cl: `−1+1=0`; charge: `(+1)(−1)+(−1)(−1)+0=0` | Complete Ag, Cl and charge rows; phases explicit. This is **not** an A4 precipitation equilibrium or kinetic model. |
| INV-03: oxygen imbalance | H₂: −1; O₂: −1; H₂O: +1 | H: `−2+2=0`; O: `−2+1=−1` | **Reject chemically** upstream even if kinetic orders/rate constant are provided. |
| INV-04: missing electron / charge imbalance | Na⁺: −1; Na: +1 | Na: `−1+1=0`; charge: `(+1)(−1)+0=−1` | **Reject chemically**; absent electron/reservoir cannot be silently manufactured. |
| INV-05: charged initial inventory | Na⁺: 1 mol; Cl⁻: 0 mol; no claim of physical mixing model | `I_q(0)=+1` mol elementary-charge equivalents | The equality `I_q(t)=I_q(0)` **does not** prove electroneutrality or aqueous applicability. |
| INV-06: synthetic A→B | ν(A)=−1, ν(B)=+1, user-provided `w_A=w_B=1` | Synthetic total `−1+1=0` | May be an engineering invariant fixture only; **never** label element/charge or real chemistry verified without validated A1/A2 composition. |

## 4. Tolerance policy and failure semantics (source-level facts vs proposal)

**Existing network-admission check:** `|Σ w_i ν_{ij}| ≤ 10^−12 Σ|w_i ν_{ij}|`. This *floating-point numerical* check is scale-aware for positive nonzero magnitude and rejects identified non-finite arithmetic. It **must not** replace upstream exact integer elemental/charge balance. Extremely scaled double coefficients and cancellations can still be affected by IEEE-754 rounding; ordinary integer chemistry belongs upstream.

**Existing output-monitoring threshold:** `|I_t−I_0| ≤ 10×(atol_mol × Σ|w_i| + rtol × max(|I_0|, |I_t|))`. For element counts, the terms are mol of element; for charge counts, mol of elementary-charge equivalents. This is a **solver-local guard**, not automatically a scientifically approved atom/charge tolerance or an equilibrium residual. The `10` factor is hard-coded, the global `AbsoluteToleranceMol` is scalar per amount component, and `Σ|w|` depends on included network species; these limits must be documented and assessed against fixture-specific accepted error budgets.

**Required post-approval validation:** A1/A3/A4/integrator agree independently derived reference composition, units, scales, error metrics and tolerances for each accepted fixture; compare maximum per-element/charge drift over **all published samples**, not just final state. Separately test absolute and relative tolerances and integration-error convergence. Keep a numerical local-error estimate separate from chemical residual and independent analytical global trajectory error. No generic universal `1e-6` conservation epsilon; no rounding/negative clipping as a response to violated invariants. Scientific **provenance/licensing** of numerical benchmark values is independent from these symbolic stoichiometric examples (INT-26).

**Error/result mapping:** Network constructor may throw a validated argument exception for an inconsistent supplied law; this is an invalid-input/chemical-admission failure, not a converged trajectory. During `Run`, excessive drift or non-finite comparison => `ConservationFailure`; `ConservationLaw.Evaluate` arithmetic overflow => `NumericalFailure`. In either case A4 retains only the **previous validated output prefix**, not the offending segment. `SimulationResult` does **not** contain per-law residual magnitudes or coverage labels today. Any future shared `ErrorEnvelope` must carry the failure class without equating a numerical fail to bad provenance.

## 5. Proposed P1 tests/gates and owners (not yet implemented)

| Test ID | Scenario | Expected decision | Owner |
| --- | --- | --- | --- |
| INV-ACC-01 | Formula/charge, phase, IDs, revisions all resolved for network; exact per-reaction element/charge dot products are zero | Generate complete sparse laws including charged species; A4 receives them and numerical checks run | A1 (admission), A2 (AST/reaction), A4 (consumer), integrator (mapping) |
| INV-ACC-02 | One species has unknown composition or stale AST/ref even if a manually supplied `ConservationLaw` happens to pass | **Block chemically verified** run; may allow *explicitly synthetic/exploratory* model only under owner policy | A1/A2 + owner |
| INV-ACC-03 | Missing charged species in the charge row or missing element with a nonzero count | Reject incomplete invariant coverage; do not infer missing coefficient equals zero | A1/A2 + integrator |
| INV-ACC-04 | Exact H/O or charge imbalance (INV-03/04) with a numerically plausible rate law | Reject before solver; balancing and chemical validation are upstream | A2 + integrator |
| INV-ACC-05 | Valid full laws and first-order A4 synthetic fixture where final prefix is published | Monitor all specified laws; test residuals at every published sample and retain provenance/coverage status separately | A4 + A1/integrator |
| INV-ACC-06 | Integrator fails a conservation check at a target time | `ConservationFailure`, failed target omitted, last validated sample preserved; never show Completed | A4 + A5 |
| INV-ACC-07 | Conservation evaluation arithmetic overflows | `NumericalFailure`, diagnostics preserved; no invalid graph sample | A4 |
| INV-ACC-08 | `Success` with no supplied conservation laws or synthetic total-only law | Numerical completion only; `conservation_coverage=not_assessed` **conceptual label**, no scientific atom/charge pass | Integrator + A5 + A1 |
| INV-ACC-09 | Initially non-electroneutral composition while charge total remains numerically constant | Charge-conservation pass **separate** from model's electroneutrality gate | A3 + A1; A4 keeps closed numeric law |
| INV-ACC-10 | Open flow/discrete event requested by UI with constant-state invariants | Current closed A4 mode rejects unsupported model; no false global invariant guarantee | A4 + integrator/A5 |
| INV-ACC-11 | Two valid laws for chemically independent elements but very different component scales | Benchmark-specific units/relative/absolute drift thresholds; no single global chemical epsilon | A1/A3/A4 INT-22/26 |
| INV-ACC-12 | Invalid/scientifically unsupported kinetic parameter but correct atom/charge balance | Still block kinetic run; chemical balance is necessary, **not sufficient** for a scientifically admitted trajectory | A1 + A4 |

**Existing code evidence:** A4 tests exercise numeric law acceptance/rejection and sample-prefix behavior; they do **not** prove that A1's canonical `FormulaAST` produces complete chemistry-derived invariant rows. No cross-module integration test/real data acceptance is claimed by the present document.

## 6. Handoff request and done criteria

**A1:** confirm authoritative versioned composition/charge data per canonical `SpeciesRef` and when the chemistry domain can mark each count `present` versus `unknown`, including phase/isotope limits, source/provenance and permission to call a fixture chemically verified. Supply a documented, validated dense source matrix before converting to A4's sparse nonzero rows. Do not infer mass from unverified/display-only formulas.

**A2:** confirm exact integer stoichiometry aggregation/revision and `FormulaAST.net_charge` as sole source; publish species/term mapping and prove element/charge balance in exact arithmetic before constructing A4. The parse-local `term_id` is not a stable key. No parser changes requested from A4.

**A3:** distinguish charge conservation from the *independent* electroneutrality requirement where its aqueous equilibrium model demands it; never treat the A4 linear charge invariant as a pH/phase/equilibrium residual.

**Integrator/owner:** resolve how a future shared result carries the **set and provenance/coverage of supplied invariants** (verified atoms, charge, mass, synthetic/none), typed residual kind/units, applicability and tolerances, without conflating them with `SimulationStatus.Success`; approve INT-21/22/26 and the v0.1 contract plus OpenSpec baseline before authorizing adapter or test code. The current integrator decision is **candidate only**.

**A4:** after explicit approval, implement only assigned adapter-side validation/invariant tests, retain documented failure prefix and avoid changing A1/A2/A3/A5 code. For this research checkpoint: validate source assumptions, commit this document in A4 branch, check exact-head CI, update Issue #12 and PR #6, and request cross-agent review.

**Consequence:** even with green A4-only CI, the project is **not yet verified as an integrated, scientifically admitted MVP**.
