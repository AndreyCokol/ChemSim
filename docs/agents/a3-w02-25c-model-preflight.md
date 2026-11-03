# A3-16 — W02 25 °C synthetic model preflight and trust boundary

**Date:** 2026-11-03. **Owner:** Agent A3 / Issue #8 / Draft PR #4, agent/a3-equilibrium-implementation. **Priority:** P1.  
**Evidence:** source/tests commit 10df3471dec34ec493fc962ffddf357f7b58f04b; overflow-boundary fix 643ea7607d604994323ff9e150a15c8846089733. [Exact source-head CI #41664649865](https://github.com/AndreyCokol/ChemSim/actions/runs/41664649865): **success, 78 tests / OK**.

## Scope and explicit scientific limitation

The new **src/chemsim/w02_preflight.py** provides assess_w02_25c_model_candidate, a strictly **synthetic engineering compatibility assessment**, not an A1 source/catalog/rights admission, versioned integrator EquilibriumRequest DTO, application adapter, or numerical solver. It returns a frozen W02ModelAssessment with model_compatible, local reason codes, and immutable **reference_admitted=False** and **redistribution_approved=False**, regardless of model-match outcome. It never invokes W02 or passes a scalar Kw to the runtime. The four new unittest cases are *synthetic only*, with an arbitrary 1.2345e-14 test constant, NOT an admitted reference value or independent chemical experiment.

The approved OpenSpec v0.1 architecture authorizes scoped implementation, but not the admission of source data, third-party rights, assumption of model applicability, or Godot integration. A3-07 remains open.

## Exact validated model-only conditions

The caller supplies explicit analytical HCl and NaOH **final already mixed** concentrations in mol/L, both finite/nonnegative and not simultaneously zero. No source-vessel or amount-based inputs and no implicit volume/mixing conversion are accepted.

The run temperature and the candidate property temperature must both be explicitly **298.15 K** and exactly equal. No default 25 °C, no free extrapolation to the proposed broader aqueous range, no unproven Kw(T) transformation, no automatic pressure correction. This narrow case represents a 25 °C educational model convention, not a validated T/P envelope.

The candidate property is required to carry finite positive **dimensionless Kw**, unit ID **1**, type **water_autoionization_kw**, reaction direction **water_to_hydrated_proton_and_hydroxide**, explicit **H+_aq_alias_for_H3O+_aq** shorthand, and a reference with an opaque stable reaction ID and positive integer revision that exactly matches a separately supplied expected ref. Comparing two caller-provided refs does **not authenticate** that A1/A2 issued either ref. The trusted integrator must resolve this separately.

The only supported chemistry approximation is **aqueous_ideal_dilute_activity_approximation**, aqueous phase and water medium, with c°=1 mol/L, gamma(H+)=gamma(OH−)=1 and unit water activity. These are *assumptions*, not measured gamma coefficients or an independent demonstration that a real solution lies in the applicable domain.

Candidate status must remain **origin=synthetic_test**, **quality=unverified**, **model_eligibility_status=candidate**, **uncertainty_status=not_reported** with no numeric uncertainty. Claimed curated/accepted/verified data are refused in this narrow synthetic helper, not elevated by asserted metadata. Nonempty constant ID/revision and source locator strings are required, but not authenticated; an apparently valid source or timestamp string is never evidence of real science/rights.

## Executed acceptance scenarios

The new **tests/test_w02_preflight.py** contains 4 tests, including positive synthetic/model-only assessment + a separate W02 scalar water-product calculation, and negative subcases for:

- Absent, boolean, negative, NaN, infinity, huge integer or both-zero feeds; unsupported input basis or run temperature.
- Missing, wrong or boolean reaction revision/ID, wrong water-ionization direction/notation, a kinetic k substituted for Kw.
- Zero, negative, bool, NaN, infinity or huge integer Kw; pKw or molal unit; IAPWS molal / PHREEQC activity basis silently substituted for concentration-normalized model.
- Missing/changed candidate temperature, nonunit gamma or c°, unsupported medium/phase, assumed source quality/eligibility, contradictory uncertainty, incomplete source locator.
- Huge Python integers beyond float range are explicitly rejected without OverflowError.

Unit tests establish local *structural/model* correctness only. This is **not** source admission or experimentally verified 25 °C pH.

## Trust and interoperability gates still OPEN (A3-07)

| Dependency | Owner | Required acceptance |
|---|---|---|
| Kw provenance, uncertainty, quality, model eligibility, precise T/medium/phase | A1 / scientific owner | Actual trusted source record admitted and review policy recorded; 0/7 reference benchmarks admitted so far |
| Offline distribution/derived-field reuse | A1 / rights owner | Authoritative field/channel permission; OpenStax first-edition licensing notices conflict, R=blocked_unknown_license |
| Canonical A2/A1 reaction and species identity | A1/A2/integrator | Authenticated parser/store, pinned ID/revision and explicit H3O+/hydrated H+ convention |
| Versioned v0.1 request/result and ErrorEnvelope | Integrator + A3 | Reviewed map from A1 property/Quantity/Availability, explicit reliability and source-dependent errors, tested contract |
| Actual UI/bridge/Windows offline run | A5 + integrator | Real consumer test, one equilibrium state not invented time series, ideal-concentration pH warning |

**Important:** local A3 field labels/reason codes are not public v0.1 wire enums. A model_compatible=true result is never license permission, A1 data admission, A5 display authorization, or an independent identity check. No live source values were copied into code and no third-party rights were inferred.
