# A4 kinetic parameter dimensional conversion — integrator proposal

**Owner:** Agent A4 — Kinetics & Numerical Solver. **Task:** A4-CONTRACT-MVP (P1). **Date:** 2026-11-03.  
**Status:** research/specification-only input to A1/A2/integrator; **NOT** approved Unit Registry, RateLaw/KineticParameterSet DTO, runtime adapter or release criterion.  
**Branch/PR:** `feature/a4-kinetics-core`, [Draft PR #6](https://github.com/AndreyCokol/ChemSim/pull/6); tracked in [Issue #12](https://github.com/AndreyCokol/ChemSim/issues/12).  
**Inputs:** current [A4 input contract](a4-kinetics-input-contract.md), [integration readiness audit](a4-mvp-integration-readiness.md), A4 `RateConstant` and `ReactionDefinition` code, [A1 chemistry-data contract](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/reviews/round-1/agent-a1-contracts.md), [A2 contract](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/reviews/round-1/agent-a2-contract-proposal.md), [INT register](https://github.com/AndreyCokol/ChemSim/blob/openspec/review-round-1/openspec/reviews/round-1/integrator-decision-register.md) (INT-10/12/13/40/41).

## 1. Verified A4 implementation versus upstream contract

The **implemented** `ChemSim.Kinetics.Domain.RateConstant` stores only `Value` (positive finite `double`) and `ConcentrationExponent` (finite `double`); `ValidateForTotalOrder(m)` checks `ConcentrationExponent ≈ 1−m` with absolute exponent tolerance `1e-10`. It does **not** know the source unit ID, kinetic model/revision, experiment temperature, reference T, Ea, source/provenance or applicability. The `ReactionDefinition` separately owns the signed stoichiometry dictionary, explicit kinetic-order dictionary and total order `m = Σᵢ αᵢ` (finite, αᵢ ≥ 0). There must be no automatic `stoichiometry → α` inference.

For this initial **irreversible, closed, isothermal and constant-volume** model:

- `nᵢ` = amount [mol]; `V` [m³]; `cᵢ = nᵢ/V` [mol·m⁻³].
- `r = k ∏ᵢ cᵢ^(αᵢ)` is a **volumetric** reaction rate [mol·m⁻³·s⁻¹], and `dnᵢ/dt = νᵢ V r` [mol·s⁻¹].
- `m = Σᵢ αᵢ` and `[k] = (mol·m⁻³)^(1−m)·s⁻¹`; the numeric `k` passed to A4 must be in this *canonical* basis.
- `K`, `Ka`, `Ksp`, `Kp` are equilibrium quantities, **never** valid substitutes for kinetic `k`. An equilibrium arrow alone does not specify a time law.

An upstream value's units and basis **must** be supplied explicitly and validated before creating the A4 record. The A4 exponent check alone does **not** verify that a source value in, for example, `L·mol⁻¹·s⁻¹` has actually been rescaled to `m³·mol⁻¹·s⁻¹`.

## 2. Dimensional conversion formula (candidate for approved Unit Registry)

For a volumetric power law **expressed entirely in one source concentration scale** `C_src` and one source time scale `t_src`, let:

- `F_C` = number of `mol·m⁻³` per **one numeric source concentration unit** (e.g. `mol/L → F_C=1000`).
- `F_t` = seconds per **one source time unit** (e.g. hour `→ F_t=3600`).
- `k_src` is numerically represented in `(C_src)^(1−m) / t_src`, with `r_src` in `C_src / t_src`.

Then `r_SI = (F_C/F_t) r_src` and `c_src = c_SI/F_C`. Therefore:

```text
k_SI = k_src × F_C^(1 − m) / F_t
[k_SI] = (mol·m^-3)^(1 − m)·s^-1
```

This is a **numerical conversion of the same declared rate law**, not a conversion of an arbitrary kinetic law or equilibrium constant. The upstream unit registry must know the *concentration and time dimensional bases*, not merely compare a unit string. Explicit rate-law and reaction revision matching is mandatory.

If a source law explicitly uses **different concentration units for different species**, or an independently specified rate-output unit, first require an approved typed rule. With `F_R` = canonical concentration per source **rate numerator unit**, and `F_i` = canonical concentration per source concentration unit of species `i`, the corresponding general conversion is:

```text
k_SI = k_src × (F_R / F_t) × ∏ᵢ F_i^(−αᵢ)
```

The simpler `F_C^(1−m)` rule applies **only** when `F_R=F_i=F_C`. If any rate-basis, concentration-basis or species-unit mapping is absent, **BLOCK**; do not guess a conversion or take a numeric value as already canonical.

### Independently checkable illustrative conversion vectors

These examples validate only **dimensional arithmetic**, not a measured reaction parameter or an approved chemical fixture. Invented numeric k values here are mathematical test inputs, not scientific reference constants.

| ID | m | Source numeric k with explicitly declared source units | Formula | Canonical numeric k |
| --- | ---: | --- | --- | --- |
| UC-K-00 | 0 | `0.002 (mol/L)/hour` | `0.002 × 1000 / 3600` | `0.000555555555556 (mol/m³)/s` |
| UC-K-01 | 1 | `0.2 /hour` | `0.2 / 3600` | `0.0000555555555556 /s` |
| UC-K-02 | 2 | `3 L/(mol·s)` | `3 / 1000` | `0.00300000000000 m³/(mol·s)` |
| UC-K-03 | 0.5 | `0.5 (mol/L)^0.5/s` | `0.5 × sqrt(1000)` | `15.8113883008 (mol/m³)^0.5/s` |

**Sanity checks:** first order has exponent 0, so changing concentration units cannot change k; second order has exponent −1 so `L/(mol·s)` converts to `m³/(mol·s)` with a factor `10^-3`; zero order scales with concentration. Fractional order requires a power conversion, **not** a blanket ×1000 or ÷1000.

**Numerical conversion constraints:** require finite strictly positive k, finite nonnegative total order and finite positive unit factors; use overflow-aware conversion (e.g. logarithmic scaling or checked powers) rather than intermediate overflowing or underflowing multiplications. Reject non-finite, non-positive or unrepresentable canonical k and report a typed failure rather than clamp or silently round to zero. The current A4 API rejects `k=0`; an inactive reaction should be handled via a separately approved model/policy, not silently converted to an arbitrary small positive k.

## 3. Candidate minimum upstream kinetic parameter fields — no DTO freeze

The integrator should resolve the following **logical data**, independently of eventual serialization language/schema:

| Required conceptual field | Reason and policy | Responsible owner |
| --- | --- | --- |
| Stable `reaction_ref` + revision and canonical `species_ref` IDs (including kinetic-only catalyst species) | Stable names cannot be inferred from source-text offsets or display formula; IDs used consistently across stoichiometry, kinetic orders and initial amounts. | A1/A2/integrator |
| `rate_law_ref` + revision, law kind `volumetric_power_law`, rate basis, concentration basis | Distinguishes this supported A4 model from amount/time, surface, pressure, activity or empirical rate laws. | A4 proposal; integrator approves |
| Explicit `orders[species_ref]` and signed `stoichiometry[species_ref]` | Independent inputs; αᵢ ≥ 0, νᵢ nonzero integer and species membership enforced; no automatic kinetic-order inference. | A4 (orders) + A2 (stoichiometry) |
| `kinetic_k_value`, `unit_id`, time/concentration scale definitions | Determine `m`, `1−m`, complete dimension vector, scale conversion, and positive finite canonical k. | A1 Unit Registry + A4 validation |
| Parameter `temperature_reference_K`, `applicability` (T/P/medium/phase), kinetic model revision, provenance/uncertainty/quality | Current A4 does **not** perform Arrhenius conversion and has no T field in `SimulationRequest`; upstream must certify supplied k valid at the declared **fixed** experiment T. Missing required metadata or unsupported temperature behavior blocks. | A1 data metadata + integrator, A4 contract |
| `initial_amount[species_ref]` + amount unit, `volume` + volume unit, start/end/output time units | Convert to mol, m³, s; require exactly one initial amount per network species and finite positive volume. | A1 registry + integrator adapter |
| `parameter_kind = kinetic_rate_constant`, source status and declared model type | Distinguish `missing`/`unknown`/`not_reported` from numeric zero and thermodynamic K; disallow implicit source default. | Integrator + A1/A4 |

This is **not** a claim these fields already exist. Existing A4 `RateConstant` and `SimulationRequest` do **not** implement this typed metadata. Shared `UnitId`, null/status enum and versioned `RateLaw/KineticParameterSet` remain INT-10/12/13/14/40/41 decisions.

## 4. Fail-closed admission and rejection matrix (proposed P1 validation cases)

| Test ID | Input / mismatch | Required behavior before or at A4 boundary |
| --- | --- | --- |
| UC-NEG-01 | Balanced `2A → B`; A2 stoichiometry −2/+1 but kinetic order not declared | **BLOCK**; never assume `α_A=2`; separate valid test may explicitly declare `α_A=1`, giving `[k]=s^-1`. |
| UC-NEG-02 | `m=2`, `k` tagged `s^-1` | **BLOCK** dimensional mismatch; do not rely on `RateConstant.ConcentrationExponent` as a unit parser. |
| UC-NEG-03 | `m=2`, numeric `3` in `L/(mol·s)` passed to A4 without factor 0.001 | **BLOCK** unless declared unit conversion yields `0.003 m³/(mol·s)`. |
| UC-NEG-04 | Rate law in `mol/s`, surface `mol/(m²·s)`, molality, pressure, or activity scale | **BLOCK** as different/unsupported rate/concentration basis; cannot generalize using the `F_C` shortcut. |
| UC-NEG-05 | Unknown/zero volume, unspecified time units, absent `k`, missing species initial amount, unknown species reference | **BLOCK** with attributed missing/invalid field; do not use zeros/defaults. |
| UC-NEG-06 | Thermodynamic `K` supplied where `kinetic_k` is required | **BLOCK temporal kinetics**; an approved separate A3 equilibrium solve may be possible. |
| UC-NEG-07 | k valid at reference T but run at a different T; missing `Ea` or no validated `k(T)` law | **BLOCK** if k at the requested fixed T cannot be justified; never extrapolate, invent Ea or silently use k_ref. |
| UC-NEG-08 | `k_SI` overflows to infinity or underflows to zero after unit scaling | **BLOCK** with numerical range error; do not clamp or fabricate a representable parameter. |
| UC-NEG-09 | Source `term_id` is parse-local, duplicate terms are unresolved or same species occurs on both sides without agreed policy | **BLOCK** stable identity/revision mapping; do not silently merge or cancel before integrator decision. |
| UC-NEG-10 | A4 `Success` but no A1-validated elemental/charge invariant vectors | **DO NOT** label as chemically conserved/verified; distinguish numerical completion from scientific admission. |
| UC-NEG-11 | A4 returns valid-prefix samples and non-success status (budget/cancellation/accuracy failure) | **PARTIAL/FAILED**, preserve diagnostics and timestamps; do not render as a complete graph. |

### Checks on approvals and ownership

- **A1** confirms concentration/time `UnitId`, conversion factors, dimensional basis, parameter provenance/quality and applicability. The formulas above do not define an authoritative global registry.
- **A2** confirms stable reaction/species identities, duplicate/same-species-on-both-sides policy, and signed stoichiometry mapping from parser-positive coefficients; A4 must not implement a competing parser.
- **A3** confirms `K` versus `k` separation; no universal reversible `k_f/k_r=K` relationship.
- **Integrator/owner** approves shared schema/version, missing-field/ErrorEnvelope taxonomy, runtime bridge, and whether this narrow irreversible slice is a testable MVP mode.
- **A4** can implement adapter-side checks and tests **only after** the original OpenSpec owner-approval gate is satisfied. Shared contract proposals and this note are not an approval.

## 5. Definition of done for this A4 research subtask

- A4 source semantics and dimensional exponents cross-checked against actual `RateConstant` and `ReactionDefinition` code.
- One derived formula for single concentration unit and one for mixed unit scales, with at least four independent numeric conversion vectors and failure cases.
- Explicit ownership/acceptance matrix and a review request to A1/A2/integrator without changing anyone else's source, DTO, or OpenSpec baseline.
- Documentation-only commit in A4 feature branch; verify exact-head .NET 10 CI; record in Issue #12 and PR #6.

**Further status:** source→A4 unit adapter and versioned `RateLaw/KineticParameterSet` remain **BLOCKED implementation**, regardless of completion of this specification subtask. No numeric sample k in this document is presented as an experimental parameter.
