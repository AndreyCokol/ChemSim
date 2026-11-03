# A5 — Round-2 Contract Readiness Review

Дата: 2026-11-02  
Ветка: agent/a5-ux-integration-review  
Статус: **review finding / non-normative / not approved**  
Scope: оценка готовности материалов A1–A4 к подключению интерфейса. Не утверждает domain DTO или API.

## 1. Executive result

Текущие материалы позволяют зафиксировать UX ownership и ряд инвариантов, но **не готовы к реализации адаптеров и persistence**. Незакрыты нормативные семантики: identity, basis/units, errors, time/event ordering, result validity и version compatibility.

Статусы готовности:
- **UX invariant settled** — пользовательское поведение можно считать требованием, даже если DTO ещё не утверждён.
- **Mapping provisional** — направление отображения ясно, но нельзя кодировать adapter до фиксации полей/enum.
- **Contract blocker** — UI не может безопасно реализовать поведение без решения владельца контракта.

## 2. Cross-agent consistency matrix

| ID | Area | Current evidence | Finding | Readiness | Required closure |
|---|---|---|---|---|---|
| A5-R2-01 | Charge ownership | A1 early SubstanceRecord table lists formal_charge; A2 says FormulaAST owns net_charge; later A1 refinement agrees with A2 | Historical duplicate ownership remains in A1 text; consumers could read both as canonical | Contract blocker | Integrator records FormulaAST as sole composition/charge authority; A1 clarifies legacy field |
| A5-R2-02 | Phase ownership | A1 refinement + A2: phase is outside FormulaAST and contextual in SpeciesRef/ReactionTerm | Direction aligned; exact phase enum and unknown/not-applicable semantics remain open | Mapping provisional | A1/A2 define canonical phase enum and absence semantics |
| A5-R2-03 | Substance identity | A1 stable substance ID; INT-02 still asks stable Species ID vs composite key | UI can display distinct IDs, but cannot build durable references or deduplicate picker entries | Contract blocker | Integrator+A1+A2 choose SpeciesRef identity, alias and duplicate policy |
| A5-R2-04 | Property quality | A1 PropertyRecord value_status/DataQuality proposal; A5 ReliabilityVector separate | Conceptual split sound; final enums and precedence missing | Mapping provisional | A1 defines property-level states; A5/integrator define result aggregation without probability semantics |
| A5-R2-05 | Error diagnostics | A1/A2 propose local code lists; INT-15 requires common envelope | No normative envelope shape, severity enum, context refs or recoverability contract | Contract blocker | Integrator freezes envelope; subsystem owners map local codes into it |
| A5-R2-06 | Units | A1 typed unit/dimension; INT-13 shared registry; A4 k dimension depends on rate law | UI cannot safely format axes or validate conversion using ad hoc strings | Contract blocker | Integrator/A1/A4 define unit IDs, dimensions, affine conversions and rate basis |
| A5-R2-07 | Equilibrium basis | A3 conceptual basis distinctions; INT-04/05/06/07 unresolved | UI can show assumptions only after explicit model metadata; no generic K/pH label is safe yet | Contract blocker | A3 defines basis, standard-state IDs, activity model and pH convention |
| A5-R2-08 | Solver result | A4 review lists benchmark needs but not normative result contract | UI cannot distinguish termination, local/global error, residuals and sample validity from one status | Contract blocker | A4 publishes typed result/diagnostics contract and validity semantics |
| A5-R2-09 | Event timeline | A4 says exact-boundary event application; INT-17 asks same-time ordering | Timeline can display events but cannot claim canonical order until owner defines it | Contract blocker | A4/Application freezes deterministic ordering and acknowledgement semantics |
| A5-R2-10 | Replay identity | A4 lists inputs/events/versions/settings; INT-18 remains open | UX can distinguish rewind vs recompute; cannot validate replay equivalence or stale history yet | Contract blocker | A4/Application defines canonical snapshot, hash inputs and determinism guarantee |
| A5-R2-11 | Schema compatibility | A1 asks schema_version separate from revision/dataset version; INT-16 open | Safe read-only and migration behavior cannot be finalized without compatibility policy | Contract blocker | Integrator defines supported-version matrix, migration atomicity and unknown-future behavior |
| A5-R2-12 | Hazard display | A1 supplies detailed completeness and jurisdiction proposal | UI wording can be designed, but status scope and exact enum need acceptance | Mapping provisional | A1 freezes hazard completeness scope and source refs |
| A5-R2-13 | Experiment/presentation boundary | A1/A5 agree amount/state/layout are not Substance identity | Strong alignment; canonical experiment/replay/layout document boundaries remain open | UX invariant settled; serialization blocked | A5+integrator define document refs, revisions and content hash boundaries |
| A5-R2-14 | Graph sample semantics | A4 does not yet provide GraphSeries contract; A5 proposal requires typed sample validity | Gaps, event markers and synchronized cursor are UX requirements, but adapter cannot infer invalid/missing samples | Contract blocker | A4/Application define sample status, timestamp basis, series identity and revision refs |
| A5-R2-15 | Isothermal temperature | Owner-approved product requirement + integrator register + A4 review | Constant T(t) presentation is settled; source of T and display conversion still depend on conditions/unit contract | UX invariant settled | Consume canonical condition and Unit Registry; do not synthesize thermal dynamics |

## 3. Specific inconsistencies

### 3.1 Formula charge must have one authority

The A1 contract proposal contains an early formal_charge row in SubstanceRecord. A2 states that FormulaAST owns composition and signed net charge. A1's later cross-agent refinement agrees with A2.

A5 recommendation:
- canonical charge is owned by FormulaAST;
- SubstanceRecord may reference FormulaAST and show its charge, but must not serialize a competing independent charge value;
- SpeciesRef/ReactionTerm adds phase context, not another charge;
- conflicting imported charge is a validation error, not a precedence rule.

### 3.2 Phase and formula identity

A1 and A2 align that phase is not part of FormulaAST identity. UI must display formula and phase as separate semantic elements. No phase enum or unknown-state contract is frozen. Do not encode phase as a free-form string in UI state.

### 3.3 A1 PropertyRecord status vs A5 result reliability

A1 DataQuality describes an individual property assertion. A5 ReliabilityVector describes the result produced using some subset of input assertions and a particular model/solver execution.

Do not use a direct enum cast or one shared status:
- property quality remains attached to property/source;
- result reliability refers to actually consumed inputs and model execution;
- an input not used by the selected calculation must not automatically downgrade the result;
- aggregation of several inputs must be explicit and explainable.

### 3.4 Numerical validity vs scientific applicability

A3 equilibrium residual and A4 solver convergence answer numerical questions. They do not prove model validity for supplied conditions. UI must keep separate:
- numerical termination/convergence;
- conservation/invariant residuals;
- input data quality;
- model applicability and assumptions;
- result completeness.

No green overall "correct" status may be inferred from convergence alone.

## 4. Presentation adapter preconditions

| Adapter | Minimum normative input |
|---|---|
| Substance/Species picker | stable IDs, identity/revision refs, phase enum, FormulaAST display contract |
| Property details | value status, unit/dimension, basis, conditions, uncertainty status, provenance/license |
| Reaction editor | AST identity, term coefficient, phase, parser diagnostic span semantics, balance result status |
| Equilibrium result | basis, standard state, model assumptions, typed quantities, residuals, applicability |
| Kinetics result | rate quantity kind, rate-law identity, typed unit, sample validity, solver termination |
| Diagnostics | shared envelope, severity, message key, field/source refs, recoverability |
| Graph adapter | stable series identity, typed quantity/unit, model-time, sample validity/gaps, revision |
| Timeline | canonical event ordering, event identity, acknowledgement and checkpoint semantics |
| Replay/history | canonical input snapshot, data/model versions, solver settings, hash and determinism guarantee |
| Save/load | schema compatibility, document boundaries, migration policy, unknown-version behavior |

## 5. Round-2 closure requests

### Integrator
1. Resolve INT-01 through INT-03 in one canonical identity decision.
2. Publish normative ErrorEnvelope, Unit Registry and schema-version policies for INT-13–16.
3. Mark decisions accepted, rejected or deferred; do not leave the register as an unqualified proposal.
4. Publish one source of truth for event/replay semantics and cross-document revisions.

### A1
1. Remove or clarify the early independent formal_charge field in SubstanceRecord.
2. Confirm phase ownership and phase-unknown semantics with A2.
3. Freeze PropertyRecord value status, uncertainty status and hazard completeness enums.
4. Clarify whether user-defined records can be saved with unresolved phase/charge and which model operations are blocked.

### A2
1. Confirm FormulaAST owns element composition and net charge; SpeciesRef owns contextual phase.
2. Freeze SpeciesRef stable identity/alias semantics with A1 and integrator.
3. Publish parser diagnostic span coordinate system (byte, Unicode scalar, UTF-16 code unit, or token index) so Godot highlighting is deterministic.
4. Clarify whether parse success without phase is allowed and how phase-dependent model validation reports it.

### A3
1. Freeze equilibrium basis and standard-state identifiers.
2. Specify machine-readable pH convention and activity-model applicability.
3. Publish result validity and residual fields; define which residuals are dimensionless and their normalization.

### A4
1. Publish typed rate quantity taxonomy and k unit/basis derivation contract.
2. Define SolverResult termination, error estimate, invariant residual and sample validity.
3. Define same-timestamp event ordering, event acknowledgement and checkpoint semantics.
4. State replay determinism level: bitwise, deterministic on same platform/runtime, or tolerance-bounded; specify comparison method.
5. Define GraphSeries sample gap and timestamp semantics.

## 6. A5 decision: what can proceed now

Can proceed as specification:
- screen map and user journeys;
- distinction of catalog substance, reaction species and experiment instance;
- display principles for unknown/missing/zero;
- isothermal constant-temperature graph behavior;
- independent presentation of model applicability and numerical status;
- visual layout invariance and separate save/replay/layout concepts;
- acceptance scenarios for these invariants.

Must remain blocked:
- concrete serialization/DTO adapters;
- graph unit formatting and conversions;
- parser source-span highlighting implementation;
- error-to-action wiring;
- replay equivalence claims and event ordering guarantees;
- schema migration implementation;
- numerical status aggregation into a final result label.

## 7. Approval boundary

This review is an A5 readiness assessment, not an integrator decision. It does not amend A1–A4 contracts, freeze the decision register, approve OpenSpec baseline or authorize implementation.

**Implementation gate remains closed pending explicit owner approval.**
