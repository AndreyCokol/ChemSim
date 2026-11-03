# Integrator decision closure / owner handoff — 2026-11-03

**Delegation:** Product owner authorized acting as Chief Integrator for this task.  
**Status:** cross-module *design choices made by integrator*; not owner-approved OpenSpec baseline, not tested final wire API, not code implementation authorization. Branch `openspec/review-round-1`, Draft PR #1. Tracking: issue #14.

## Deliverables and authority

1. [Cross-agent contract v0.1](../../contracts/mvp-cross-agent-contract-v0.1.md): identity, ownership, typed quantities, missing values, errors, reliability, thermo and kinetics boundaries, event/replay policy.
2. [Interchange JSON Schema v0.1](../../contracts/interchange-envelope-v0.1.schema.json): machine-readable envelope and common building blocks; it does not replace yet-to-be-reviewed A1–A4 domain schemas.
3. [Offline bridge and acceptance plan](../../contracts/mvp-bridge-and-acceptance-v0.1.md): candidate file-based local CLI to keep Godot GDScript and A4 .NET 10 separate; 12 positive/negative E2E checks and Windows release gates.
4. This closure and handoff checklist. **No scientific constants, numerical expected values, source licenses, producer adapters or Windows binaries were created.**

## INT-01…48 disposition

Disposition meanings:
- **DECIDED-CANDIDATE** = integrator has picked exact *proposed shared behavior*; remains pending product-owner signoff, producer mapping tests, or both.
- **PRODUCER-REVIEW** = proposal constrained by shared rules, but producer owns the final model and acceptance proof.
- **OWNER-GATE** = requires explicit product-owner policy/legal/approval decision.
- **DATA/TEST-BLOCKED** = scientific data, license or executable evidence not yet present.
- **DEFERRED** = legitimate later design item; not asserted to be part of first executable integration smoke.

| INT | Disposition | Integrator outcome / closure condition |
|---|---|---|
| 01 | DECIDED-CANDIDATE | Separate SubstanceRecord/FormulaAST/SpeciesRef/ExperimentComponent ownership; A1/A2 mapping tests |
| 02 | DECIDED-CANDIDATE | Stable opaque Species ID with immutable formula+phase semantic identity, revisions and explicit alias mapping |
| 03 | DECIDED-CANDIDATE | FormulaAST is sole serialized charge truth, A1 `formal_charge` if shown must be derived; A1 table correction required |
| 04 | PRODUCER-REVIEW | A3 thermodynamic basis/standard-state typed; only two explicitly qualified ideal MVP bases candidate |
| 05 | DECIDED-CANDIDATE | Ideal gas with dimensionless p/p° and p°=1 bar; applicability and numerical fixtures still A3/data |
| 06 | PRODUCER-REVIEW | A3 `ideal_dilute`, gamma=1 only within model-specific domain; no generic activity model promise |
| 07 | DECIDED-CANDIDATE | pH concentration approximation distinct from thermodynamic activity pH |
| 08 | PRODUCER-REVIEW | A3 must enforce material/charge balances and solid inventory/reservoir + complementarity |
| 09 | PRODUCER-REVIEW | Typed K(T), provenance and T validity; no implicit extrapolation |
| 10 | PRODUCER-REVIEW | Rate law/order/k + dimensional provenance by A4/A1; adapter fails closed |
| 11 | PRODUCER-REVIEW | Reversible kinetics prohibited in A4 current slice; future forward/reverse laws explicitly verified against K |
| 12 | DECIDED-CANDIDATE | Reaction terms positive integers; A4 maps negative reactants / positive products; orders separate |
| 13 | DECIDED-CANDIDATE | Minimal typed common Unit Registry; registry-mediated conversion and dimensional kinetic k |
| 14 | DECIDED-CANDIDATE | Availability tagged; missing/not_assessed/not_applicable/withheld distinct from measured zero |
| 15 | DECIDED-CANDIDATE | Namespaced ErrorEnvelope, severity, recovery, source references, UTF-8 spans |
| 16 | DECIDED-CANDIDATE | Shape vs revision vs dataset/model/contract versions; fail closed on unknown major version |
| 17 | DECIDED-CANDIDATE | Half-open flow intervals; events by explicit unique sequence at same t, post-event checkpoint; A4 tests still needed |
| 18 | DECIDED-CANDIDATE | Replay inputs exclude presentation; canonical serialization/hash requires cross-runtime vectors before use |
| 19 | DECIDED-CANDIDATE | Requested end vs valid-prefix vs last valid time; A4 failure never displayed as completed |
| 20 | DECIDED-CANDIDATE | Five-axis ReliabilityVector, no fabricated accuracy percent |
| 21 | PRODUCER-REVIEW | A4 must reject nonphysical stages; no unconditional clipping, proof via invariants |
| 22 | DATA/TEST-BLOCKED | Benchmark-specific units/scales/tolerances: requires independent scientific fixtures |
| 23 | OWNER-GATE | Distribution/license purpose and field-level allowlist not approved |
| 24 | DECIDED-CANDIDATE | Hazard completeness and freshness separate; absence never means safe |
| 25 | DECIDED-CANDIDATE | UI draft v1 separated from future canonical experiment and replay metadata; migration tests later |
| 26 | DATA/TEST-BLOCKED | Numeric benchmark fixtures need independent derivations, source, uncertainty and license |
| 27 | DEFERRED | Russian UI vocabulary A5/product-owner review; status categories already typed |
| 28 | OWNER-GATE | Candidate canonical caret charges + limited H+/OH-/Ag+ aliases; grammar owner must explicitly accept |
| 29 | OWNER-GATE | Candidate canonical `->`/`<->`, Unicode only tested aliases; owner must explicitly accept |
| 30 | DECIDED-CANDIDATE | Keep duplicate source terms/spans; optional canonical aggregation exact species/side |
| 31 | DECIDED-CANDIDATE | Allow identical species both sides only under explicitly supported downstream model |
| 32 | DECIDED-CANDIDATE | Phase `unspecified` permitted in drafts; phase-dependent computations block |
| 33 | DECIDED-CANDIDATE | BalanceResult immutable and separate, accepted changes new Reaction revision |
| 34 | DECIDED-CANDIDATE | Typed pH method/value/basis/model; no unqualified concentration pH |
| 35 | PRODUCER-REVIEW | A3 activity validity domain per model; no universal ionic-strength bound |
| 36 | PRODUCER-REVIEW | A3 solid complementarity + inventory, phase amount status distinct from zero |
| 37 | PRODUCER-REVIEW | `ln(Q/K)` when defined; zero-boundary typed semantics; no `-Infinity` JSON |
| 38 | DECIDED-CANDIDATE | p°=100000 Pa, dimensionless gas partial-pressure K quotient |
| 39 | DECIDED-CANDIDATE | `out_of_domain` separate from `blocked`, avoid silent extrapolation |
| 40 | DECIDED-CANDIDATE | A4 volumetric power-law basis: k dimensions depend on total kinetic order |
| 41 | DECIDED-CANDIDATE | Kinetic orders explicit and never inferred from stoichiometry |
| 42 | PRODUCER-REVIEW | Arrhenius only with validated k_ref/T_ref/Ea/domain, no implicit k(T) |
| 43 | PRODUCER-REVIEW | Reversible kinetics gated; never universal kf/kr=K |
| 44 | PRODUCER-REVIEW | A4 positivity/conservation policy benchmark validation needed |
| 45 | DECIDED-CANDIDATE | Events at exact t once, then checkpoint; flow boundary half-open |
| 46 | PRODUCER-REVIEW | Stiff/nonstiff solver selection from benchmark only |
| 47 | DECIDED-CANDIDATE | T(t) is isothermal in supported executed runs only |
| 48 | DECIDED-CANDIDATE | Replay guarantee only tolerance-based for fixed model/runtime, no cross-platform bitwise claim |

All 48 entries were examined; no row's classification asserts implemented or owner-approved status. In particular, **a DECIDED-CANDIDATE row is not DONE for implementation**.

## P0/P1 remaining gate checklist

| Order | Remaining action | Accountable party | Status |
|---|---|---|---|
| 1 | Review shared design and A1 `formal_charge` conflict; acknowledge Species ID, charge and phase ownership | A1 + A2 | NEEDS_REVIEW |
| 2 | A2 confirm charge aliases, source-byte-span conversion, duplicate terms and reaction revisions | A2 + owner for INT-28/29 | NEEDS_REVIEW / OWNER-GATE |
| 3 | A3 validate c°/p° choices against actual constants, pH, phase/solid inventory, finite results and exact unit kind | A3 + A1 | NEEDS_REVIEW; source-backed fixture BLOCKED |
| 4 | A4 map typed rate law + quantity/status to numeric API and typed result; implement CLI adapter only after approval | A4 + integrator | NEEDS_REVIEW / CODE BLOCKED |
| 5 | A5 validate errors, Result/GraphSeries, unknown/invalid/stale, draft migrations, UTF-8 spans and disabled unsupported controls | A5 | NEEDS_REVIEW / CODE BLOCKED |
| 6 | Review adapter transport (Windows x64 self-contained .NET10 CLI), failure/timeout/sandbox policy and packaging feasibility | Integrator + A4 + A5 | SPEC DONE CANDIDATE, RUNTIME NOT TESTED |
| 7 | Populate independent A1 data manifest and verify property/fixture distribution rights, scientific benchmarks/tolerances | A1 + A3/A4 + owner | BLOCKED |
| 8 | **Explicitly sign off** OpenSpec baseline SHA/version, agreed v0.1 decisions, any staged implementation exception and scope | Product owner | **NOT APPROVED** |
| 9 | After approval: code adapters, contract/negative tests, actual integrated Windows offline smoke and release decision | A1–A5 + integrator | NOT_STARTED / BLOCKED |

## Owner action required

Review [OpenSpec PR #1](https://github.com/AndreyCokol/ChemSim/pull/1), the two contract documents and this matrix. Record a **written explicit approval/rejection** identifying exact baseline commit SHA + contract version + allowed implementation scope. Merely making a branch, file, issue, PR or merging draft documentation is not enough. The integrator has *not* exercised or assumed the owner's authority to approve it.

**Recommendation:** owner may separately authorize a **synthetic, closed irreversible engineering smoke** after accepting this architecture (without scientific benchmark claims) while A1/A3 finish data admission. That is a staged engineering check, not a full feature-complete MVP or a unilateral scope change.
