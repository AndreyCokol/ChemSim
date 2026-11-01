# A5 Review: Godot UX, Visualization & Integration

> Status: **RESEARCH REVIEW / PROPOSAL — NOT APPROVED**
> Owner: Agent A5
> Base reviewed: `main` at `c5eb6b6e8ecb7d0679a9eb54d91b79c477cca7f7`
> Review date: 2026-11-02
> Scope: Godot 4.x presentation, application-facing contracts, visualization, persistence UX, offline/Windows integration.
>
> This document is an A5-owned review artifact. It does not approve the OpenSpec change, define final shared DTOs, or authorize implementation. No chemistry, parser, equilibrium, or solver behavior is implemented here.

## 1. Executive summary

A5's responsibility is to present the domain and simulation capabilities owned by A1–A4 without recreating their models in Godot. The UI should be a compact scientific workspace: a visual experiment field, structured editors, a calculation/status panel, a shared timeline, graph views, and an offline encyclopedia.

The current repository has a useful separation of Presentation, Application, Domain, Chemistry Services, Simulation Kernel, and Data/Infrastructure. The most important integration rule is therefore:

**Godot sends user intents to an application boundary; it never calls A1–A4 calculation internals directly.**

The review identifies one material product/specification conflict that must be resolved before implementation:

- Current `config.yaml`, `design.md`, and A4 prompt describe temperature-dependent kinetics / Arrhenius behavior.
- The newer owner instruction supplied to A4 for the current work round states that the MVP is isothermal, with constant temperature.
- A5 treats the newer explicit MVP decision as the working assumption, but does not rewrite the shared spec. The owner/integrator must reconcile the documents and define whether Arrhenius is deferred or only evaluated at a fixed experiment temperature.

The current OpenSpec change remains draft. `tasks.md` leaves agent research, contract integration, benchmark validation, and owner approval incomplete; implementation is explicitly blocked.

## 2. Reviewed repository artifacts

Reviewed on `main`:

- `openspec/config.yaml`
- `openspec/SETUP.md`
- `openspec/agents/README.md`
- `openspec/agents/prompts/agent-01-chemistry-data-domain.md`
- `openspec/agents/prompts/agent-02-equation-parser-balancer.md`
- `openspec/agents/prompts/agent-03-aqueous-chemistry-equilibrium.md`
- `openspec/agents/prompts/agent-04-kinetics-numerical-solver.md`
- `openspec/agents/prompts/agent-05-godot-ux-integration.md`
- `openspec/changes/define-chemsim-mvp/proposal.md`
- `openspec/changes/define-chemsim-mvp/design.md`
- `openspec/changes/define-chemsim-mvp/questions.md`
- `openspec/changes/define-chemsim-mvp/tasks.md`
- `openspec/specs/chemistry-domain/spec.md`
- `openspec/specs/experiment-workspace/spec.md`
- `openspec/specs/persistence-and-distribution/spec.md`
- `openspec/specs/simulation/spec.md`

All four current specs identify themselves as DRAFT. No separate benchmark-matrix artifact was present in the repository tree at the reviewed base commit. The existing task list explicitly calls for a benchmark matrix to be created.

## 3. Product and architecture constraints for A5

### 3.1 Product constraints

- Godot 4.x; Windows 10/11 x64; Russian UI; offline-first.
- MVP chemical media: aqueous solutions and gases, only within explicitly supported models.
- Main interaction is panels, forms, tables, and graphs; drag-and-drop is not required.
- User enters substance, amount, and a visual placement coordinate.
- Visual coordinates are not physical coordinates and must not affect chemistry, numerical integration, or simulation identity.
- Text equation entry and structured reaction editing are both required; balancing is an explicit separate user action.
- Missing mandatory model inputs block only the calculation that needs them; incomplete experiments and user-defined/hypothetical substances may still be saved.
- Mandatory graph families: concentration–time, rate–time, temperature–time.
- Controls include start, pause, single solver step, playback speed, and history navigation/rewind.
- Encyclopedia is local and includes source/provenance and hazard-data completeness.
- No mandatory network backend or online lookup.

### 3.2 Layer boundary

Recommended call direction:

```text
Godot Presentation
       |
       v
Application Adapter / Use Cases
       |
       +--> Experiment & Timeline Controllers
       |
       +--> Validation / Diagnostic Aggregator
       |       +--> A1 Domain & Substance Data
       |       +--> A2 Parser / Balancer
       |       +--> A3 Equilibrium Services
       |       +--> A4 Simulation Kernel
       |
       +--> Persistence Service
       |
       +--> Graph Adapter --> Godot Graph Views
```

Rules:

1. Presentation owns interaction state and view state only.
2. Application owns orchestration, command validation, lifecycle, and persistence workflows.
3. A1 owns canonical substance identity, typed properties, units/provenance, and hazard records.
4. A2 owns parsing, AST, stoichiometry, and balancing.
5. A3 owns aqueous/gas equilibrium and its domain diagnostics.
6. A4 owns kinetics, integration, state history, event application, and numerical diagnostics.
7. A5 owns adapters and display contracts; it must not duplicate domain calculations.
8. A single failure in a graph view must not stop or corrupt the solver.
9. UI refresh rate and playback speed must not define solver step size.

## 4. Information architecture

### 4.1 Main workspace

The primary window should prioritize the active experiment:

- **Top bar:** experiment title, dirty/save status, current model mode, navigation to encyclopedia and graph workspace.
- **Central experiment field:** flat, grid-based, voxel-like arrangement of visual substance tokens/cards. Each token shows a short label/formula and quantity summary where space permits.
- **Calculation panel:** conditions, reaction readiness, validation summary, and action controls.
- **Timeline strip:** model time, play/pause, step, playback speed, rewind/history navigation, and event markers.
- **Status summary:** compact indicators for data quality, model validity, numerical status, completeness, and warnings.

Do not make the field a physical simulator. No collisions, diffusion, spatial gradients, fluid motion, or inferred reaction behavior from visual adjacency.

### 4.2 Secondary views

| View | Purpose | Key content |
|---|---|---|
| Substance Browser | Find local substances | Search by name, formula, synonym, stable ID; filters for phase and record type |
| Substance Details | Inspect one record | Formula, charge, phase, molar mass, properties, provenance, applicability, hazard completeness |
| Substance Editor | Add user/hypothetical record | Supported identity fields and typed property records; incomplete records may be saved |
| Reaction Editor | Define reaction | Text input or structured reactant/product editor; parse diagnostics; explicit Balance action |
| Conditions | Configure experiment | Temperature, volume, pressure where required, model selection, initial amounts/concentrations |
| Graph Workspace | Inspect output | Concentration, rate, temperature series; units, legends, cursor, gaps, provenance |
| History / Replay | Navigate previous states | History checkpoints, event sequence, replay origin, current model time and revision |
| Diagnostics | Explain readiness/failure | Blocking diagnostics first, then warnings and assumptions, each with field path and suggested action |
| Save / Load | Manage local documents | Format version, compatibility, integrity, recovery and migration feedback |

### 4.3 Responsive desktop behavior

- Wide layout: experiment field and calculation panel side by side; timeline spans the bottom.
- Medium layout: field remains primary; calculation panel can become a collapsible side pane.
- Narrow window: use switchable tabs/panes rather than shrinking scientific text and graph labels below readability.
- Window resizing must not discard unsaved editor content or change experiment state.
- Exact breakpoints, minimum window size, and DPI scaling values require a Godot prototype and Windows testing; do not guess them in the spec.

## 5. Core user journeys

### J1 — Create and prepare an experiment

1. Create a new experiment.
2. Search for a local substance or create a user-defined record.
3. Enter amount and unit explicitly.
4. Enter or select a visual coordinate; drag-and-drop remains optional.
5. Repeat for all initial components.
6. Configure conditions required by the chosen model.
7. Enter reaction text or build the reaction structurally.
8. Parse and show the structured reaction/diagnostics.
9. User explicitly invokes balancing; show proposed coefficients and require confirmation before replacing the current equation.
10. Run readiness validation and show blocking fields, warnings, assumptions, and data provenance.
11. Allow save even if the experiment is incomplete; disable only the calculation that cannot be supported.

### J2 — Start, pause, step, and stop

1. User requests Start.
2. Application validates the current experiment revision.
3. If blocked, return structured diagnostics; do not create a running UI state.
4. If accepted, A4 owns the numerical progression.
5. Pause freezes model state and model time.
6. Step advances exactly one solver-defined step, not one rendered frame.
7. Playback speed changes how quickly model time is presented, not the numerical method or integration step.
8. Numerical failure leaves the last confirmed valid state visible and clearly marks the calculation as failed.

### J3 — Inspect graphs and synchronized time

1. Open graph workspace at any time.
2. Select available series; unavailable series explain why they cannot be shown.
3. Every axis displays a variable name, unit, and legend.
4. One shared timeline cursor drives all graph cursors and numeric readouts.
5. Rewind changes the selected history state and updates all views against the same history revision.
6. Gaps and invalid points remain visible as gaps; missing values are never plotted as zero.

### J4 — Inspect substance and hazard information

1. Search local encyclopedia.
2. Open substance details.
3. Show source and applicability for each property where available.
4. Distinguish confirmed/reference/calculated/estimated/user-provided/unknown values.
5. If hazard data are absent or incomplete, state that explicitly; never imply safety.
6. Show a persistent note that the encyclopedia does not replace an SDS or laboratory safety instructions.

### J5 — Save and reopen

1. Save experiment content and user-defined substances.
2. Persist visual layout separately from chemical content.
3. On load, validate format/schema version and document integrity before replacing the active workspace.
4. Unknown future schema: read-only/unsupported diagnostic; never overwrite automatically.
5. Failed migration or corrupted input: preserve original file and provide a recovery path.

## 6. UI lifecycle and state model

The UI lifecycle is not the solver's internal enum. A5 proposes the following presentation states:

| UI state | Meaning | Permitted user actions |
|---|---|---|
| empty | No experiment loaded | New, Open, Encyclopedia |
| editing | User is changing experiment content | Edit, Save, Validate, Open views |
| ready | Current revision passes readiness checks | Start, Save, Edit |
| blocked | Current revision has one or more blocking diagnostics | Inspect diagnostics, edit, save incomplete experiment |
| running | Solver is advancing | Pause, Stop/Cancel, inspect graphs |
| paused | Solver is stopped at a confirmed state | Resume, Step, Rewind, inspect, export |
| stepping | One solver step is in progress | Wait/cancel only if A4 supports safe cancellation |
| rewinding | History restore or deterministic replay is in progress | Cancel if safe; otherwise wait |
| completed | Requested simulation horizon reached | Inspect, Rewind, Save, replay |
| error | Operation failed; last confirmed state retained | Inspect, retry after correction, return to editing |

### 6.1 Transition rules

- `empty -> editing`: create or load a valid document.
- `editing -> ready`: validation succeeds for the selected calculation.
- `editing -> blocked`: validation returns blocking diagnostics.
- `ready -> running`: Start accepted by Application/A4.
- `running -> paused`: Pause acknowledged.
- `paused -> running`: Resume accepted.
- `paused -> stepping -> paused`: one solver step completes.
- `paused/completed -> rewinding -> paused`: history restore or replay completes.
- `running/stepping/rewinding -> error`: operation fails; last confirmed state remains authoritative.
- `error -> editing`: user changes inputs or explicitly resets/retries.
- `completed -> editing`: user edits a new experiment revision; old results become historical/stale.

The UI must not optimistically show a transition as completed before the Application/A4 event acknowledges it. If an operation is cancelled, the returned state must be either the previous confirmed state or another explicitly acknowledged consistent state.

### 6.2 Edit locks

- Chemical inputs and model conditions are immutable during active solver progression unless A4 defines an explicit event workflow.
- Visual layout changes may remain available during calculation only if they cannot mutate the chemical document or simulation hash.
- Graph selection, zoom, and window arrangement are presentation-only.
- Discrete chemical additions/removals must be scheduled as explicit model events, not disguised as visual edits.

## 7. Visual field semantics

### 7.1 Visual object model — proposal only

A view-layer object may reference canonical domain identity but does not replace it:

- `visual_id`: stable identity of this displayed token.
- `substance_id`: canonical A1 identifier.
- `display_position`: UI-only coordinate.
- `display_color`: UI-only visual style.
- `selection_state`: selection/focus state.
- `display_markers`: user-defined, hypothetical, warning, or unsupported badges.

This is a presentation concept, not a proposed canonical A1 DTO.

### 7.2 Encoding

- Color may help distinguish substance tokens, but must not encode unsupported chemical facts.
- Selection is indicated by outline/focus treatment, not by changing substance identity color.
- User/hypothetical status uses a text/icon marker in addition to color.
- Warnings use icon + text/tooltip; never rely on color alone.
- Do not assign a unique semantic color to every element as if the field were a periodic table; tokens represent substances/mixtures, not necessarily elements.
- Color palette must remain legible under common color-vision deficiencies and high-contrast settings.

### 7.3 Invariance requirement

Moving, recoloring, selecting, resizing, or rearranging visual tokens must not change:

- chemical document content;
- chemical revision;
- solver initial state;
- simulation hash;
- model time;
- graph values;
- replay output.

An integration test must assert these invariants.

## 8. Graph presentation and adapter contract

The graph adapter translates A4/A3 result metadata into a presentation model. It does not calculate chemistry, invent missing points, or silently resample solver output.

### 8.1 Series metadata proposal

The following is a discussion checklist, not an approved DTO:

- series identity and experiment identity;
- variable kind and optional entity/reaction identity;
- display label;
- physical dimension and typed unit;
- x-axis unit (model time);
- ordered points;
- provenance and result quality;
- applicability/status metadata;
- model/chemical/history revision;
- completeness and missing-data reason;
- event references/markers where applicable.

Each point needs at minimum model time, value or explicit missing state, validity/quality, and optional event reference. A null/missing point is not zero.

### 8.2 Units and labels

- Concentration-time: use the actual concentration unit supplied by the domain/result contract (e.g. mol/L only when the series is molar concentration).
- Rate-time: do not hardcode one universal unit. Reaction rate may refer to species formation/consumption rate, reaction progress rate, or another defined quantity. A4 must specify variable semantics and dimensions.
- Temperature-time: display the source unit (K or °C) and an explicit label. Under the current isothermal MVP instruction, the expected plot is constant and must be labelled **Isothermal / constant temperature**; do not animate heating.
- Time axis must say model time and carry a typed time unit.
- Unit conversion is a view operation only when dimensionally valid and supported; original values/provenance remain available.

### 8.3 Gaps, interpolation, and scaling

- Missing or invalid samples create visible gaps; do not connect through them.
- Do not interpolate/resample unless A4 explicitly provides a permitted interpolation policy and provenance.
- Event markers must be distinguishable from ordinary solver samples.
- Logarithmic axes are allowed only for strictly positive valid values and must disclose the scale.
- Axis zoom/range is layout state, not chemical state.
- Graph export must include headers, units, model time, selected series, and missing-value representation.

### 8.4 Shared timeline cursor

A shared cursor concept should include:

- experiment identity;
- model time;
- history/replay revision;
- navigation origin (graph, timeline, history list).

All graph views and numeric panels must resolve against the same cursor/revision. Rewind must not rerun the solver merely to refresh UI if the requested state is already in stored history. Deterministic replay is an Application/A4 operation, not graph logic.

## 9. Reliability, assumptions, and diagnostics

### 9.1 Reliability vector

Present independent dimensions rather than a single score:

- data quality;
- model validity;
- numerical status;
- completeness;
- warnings;
- assumptions.

Do not average these into a green/red number. A result can be numerically converged while relying on approximate data or an out-of-domain model.

### 9.2 Diagnostic presentation

A blocking diagnostic should expose, where applicable:

- stable diagnostic code;
- severity and whether it blocks this operation;
- owning subsystem;
- exact field path/parameter;
- concise Russian message;
- explanation/context;
- expected and actual values with units;
- source reference;
- suggested corrective action.

The user should be able to navigate from a diagnostic to the corresponding editor field. Warnings must remain distinguishable from blockers.

### 9.3 Result classes

Potential display classifications to align with A3/A4 (not solver enums):

- valid;
- approximate;
- incomplete;
- unsupported;
- out_of_domain;
- numerical_failure;
- cancelled.

Do not collapse a numerical failure into a generic warning or display a failed state as a valid result.

## 10. Encyclopedia and hazard UX

Substance search should work offline and support name, formula, synonym, and stable ID. Search results should show enough context to distinguish similarly named records.

A detail view should separate:
- identity/formula/charge/phase;
- physical and thermodynamic properties;
- property units and provenance;
- applicability ranges/conditions;
- data quality or uncertainty;
- hazard classifications and precautionary information;
- missing/unverified hazard sections.

Required wording principle:

> «Нет подтверждённых данных об опасности» is not equivalent to «безопасно».

Where available, show source and date/version. Always state that the encyclopedia is informational and does not replace the current Safety Data Sheet (SDS), institutional procedures, or laboratory instructions.

## 11. Experiment, layout, and replay persistence

### 11.1 Logical document separation

Proposal for three logical persistence concerns:

1. **Experiment document:** canonical experiment inputs and user-owned chemical content. Domain schema belongs to A1/A2/A3/A4, not A5.
2. **UI layout document:** visual positions, panel/window geometry, selected graph series, graph axis ranges, view preferences.
3. **Replay manifest/history:** initial state reference, model/data versions, solver method and tolerances, conditions, ordered discrete events, flow schedules, checkpoints, and reproducibility metadata.

These may be stored in one physical container later, but their versioning and hash semantics must remain separate.

### 11.2 Revision separation

A useful revision model to discuss with the integrator:

- document revision;
- chemical/model-input revision;
- simulation/result revision;
- layout revision;
- history revision.

A layout-only change must not invalidate results. A chemical/model-input change must mark old results as stale rather than showing them as current. A graph viewport change must not create a new simulation revision.

### 11.3 Simulation identity

The simulation identity/hash should include all inputs that can affect a numerical result: canonical chemical initial state, conditions, model/data versions, solver settings/tolerances, ordered discrete events, flow schedules, and event ordering.

It must exclude UI-only state: display coordinates, colors, selection, window geometry, graph zoom, and panel arrangement.

The exact canonical serialization, floating-point normalization, hash algorithm, and compatibility rules remain open and must be agreed with A1/A4 and the integrator.

### 11.4 Replay

Two navigation strategies are distinct:

- **History navigation:** restore a previously confirmed stored state/checkpoint.
- **Deterministic replay:** rerun from the initial state with the same model/data versions, solver settings, and ordered event log.

Rewind is not reverse integration. Replay must expose when a required model/data version is unavailable or when deterministic equivalence cannot be guaranteed. The UI must not silently claim bitwise reproducibility if the solver contract only promises tolerance-bounded reproducibility.

### 11.5 Safe save/load

Recommended workflow:

1. Read and inspect format/schema version.
2. Validate document structure and integrity.
3. Preserve the original file; create backup where appropriate.
4. Migrate in memory only when a known migration exists.
5. Validate the migrated result.
6. Write atomically to a temporary file and replace only after success.
7. On unsupported future version or failed migration, open read-only if safe and never overwrite automatically.

## 12. Commands, events, and timeline integration

A5 recommends distinguishing user commands from acknowledged lifecycle events. This is a design direction, not a final shared API.

### Commands to discuss

- Start;
- Pause;
- Resume;
- Step;
- SetPlaybackSpeed;
- Seek/RestoreHistory;
- ReplayToTime;
- Stop;
- CancelOperation.

### Events to discuss

- CalculationStarted;
- CalculationPaused;
- CalculationResumed;
- StepCompleted;
- PlaybackSpeedChanged;
- StateRestored;
- ReplayCompleted;
- CalculationStopped;
- OperationCancelled;
- CalculationFailed.

Important semantic separation:

- solver step size is owned by A4;
- playback speed is presentation pacing;
- model time is the scientific time coordinate;
- wall-clock time is not model time.

A5 must not assume a particular A4 `SimulationState`, `StepResult`, or `EventLog` structure. These are explicit coordination items.

## 13. Discrete events, continuous flows, and mixing

### 13.1 Discrete events

Event editor should show substance, quantity/unit, event time, add/remove direction, and confirmation. Event ordering at equal model times must be deterministic and visible in history. An event must never be applied retroactively without an explicit replay/recalculation action.

### 13.2 Continuous flows

Flow editor should expose:
- substance;
- input/output direction;
- flow-rate value and typed unit;
- start/end model time;
- constant or piecewise-constant schedule;
- validation status and owner diagnostics.

A5 does not define the flow-rate dimensions or balance equations; A4 owns them. UI validates only through the shared domain/application contract.

### 13.3 Mixing

MVP presentation should expose instantaneous ideal mixing only if the relevant model is supported and its assumptions are explicit. Finite-time mixing remains disabled until A3/A4 provide a validated model, parameters, and benchmark evidence. The UI must not simulate visual swirling or imply spatial mixing physics.

## 14. Asset inventory and Godot styling

The repository root contains a substantial image asset set, including background, logo, main/title/selection panels, hero cards, buttons, sliders, switches, item states, icons, arrows, and grid textures.

A5 has verified the asset names in the Git tree, but this review has not yet measured source-image pixel dimensions, alpha bounds, texture borders, or nine-patch margins. Do not infer those from filenames or byte sizes.

Recommended next asset-audit step:
- retrieve actual image bytes through a supported binary-capable path or have the owner provide an asset archive;
- inventory pixel width/height, color mode, alpha bounds, and edge transparency;
- inspect repeated border patterns before choosing NinePatchRect/StyleBoxTexture;
- map button/icon semantics visually rather than from numbered filenames;
- keep originals immutable and store derived crops/scales separately.

Visual direction from the provided asset family: dark blue/graphite surfaces, fine technical grid, restrained cyan/teal accents, moderate glow, framed panels and buttons. Do not copy an existing screen literally or distort source textures. Exact colors, fonts, sizes, margins, and asset-to-control mappings remain pending pixel inspection and an in-engine prototype.

## 15. Offline and Windows delivery UX

MVP delivery target should be a portable Windows x64 package unless the owner selects another installer strategy.

Acceptance considerations:
- runs on Windows 10 and 11 x64;
- core experiment, encyclopedia, and supported calculations work with network disconnected;
- no runtime dependency on Godot Editor;
- no mandatory account, telemetry, or backend;
- handles Cyrillic and whitespace in user paths;
- stores user data outside the installation directory where appropriate;
- does not require administrator rights for normal portable use;
- reports missing/corrupt local resources clearly;
- supports repeat launch and long-running sessions;
- documents included datasets and third-party licenses;
- validates packaged resources and version metadata.

CSV and GitHub Releases ZIP remain optional in the current persistence spec; do not make either a prerequisite for scientific correctness.

## 16. Integration and acceptance test matrix

The following is an A5-proposed UI/integration matrix. It is not the missing scientific benchmark matrix and does not replace A1–A4 domain tests.

| ID | Area | Test / expected behavior |
|---|---|---|
| UX-01 | Empty state | App opens without an experiment; New/Open/Encyclopedia are available |
| UX-02 | Substance search | Search by name, formula, synonym, and stable ID works offline |
| UX-03 | Incomplete substance | User/hypothetical record can be saved with explicit incomplete status |
| UX-04 | Units | UI displays source unit and rejects dimensionally invalid conversion |
| UX-05 | Reaction | Text and structured entry both show parser-owned diagnostics |
| UX-06 | Balance | Balance action is explicit; proposed coefficients require confirmation |
| UX-07 | Readiness | Missing mandatory field blocks the relevant calculation and links to field |
| UX-08 | Visual invariance | Moving/recoloring/selecting tokens leaves chemical state/hash/results unchanged |
| UX-09 | Lifecycle | Start/Pause/Resume/Step transitions wait for acknowledged application events |
| UX-10 | Playback | Playback speed changes display pacing only, not solver step/tolerance/result |
| UX-11 | History | Restore of a stored checkpoint updates model time and all views consistently |
| UX-12 | Replay | Replay uses the recorded ordered events and declared model/data versions |
| UX-13 | Graph units | Every axis and legend carries a valid unit and variable label |
| UX-14 | Graph gaps | Missing/invalid values create gaps, not zeros or misleading connecting lines |
| UX-15 | Graph synchronization | All graph cursors and numeric panels show the same model time/history revision |
| UX-16 | Stale results | Chemical revision change marks old results stale |
| UX-17 | Layout independence | Panel geometry/axis zoom changes do not affect simulation identity |
| UX-18 | Rate semantics | Rate series label and unit match the exact A4 variable definition |
| UX-19 | Isothermal display | Temperature series is explicitly constant/isothermal for the MVP |
| UX-20 | Diagnostics | Blocking errors, warnings, assumptions, source and field path are distinguishable |
| UX-21 | Hazard unknown | Missing hazard data is not displayed as “safe” |
| UX-22 | Save/load | Corrupt or unsupported file does not overwrite the original |
| UX-23 | Migration | Known migration is validated before atomic replacement |
| UX-24 | Offline | Main workflow and encyclopedia work with network disabled |
| UX-25 | Windows | Windows 10/11 x64 portable package launches without Godot Editor/admin rights |
| UX-26 | Locale | Cyrillic and whitespace paths round-trip correctly |
| UX-27 | DPI/layout | Text, focus, graph labels, and dialogs remain usable under tested scaling |
| UX-28 | Accessibility | Keyboard focus, non-color status cues, readable contrast, and text/table alternatives work |
| UX-29 | Fault isolation | A graph adapter/view failure does not corrupt solver state |
| UX-30 | Cancel/failure | Cancellation/failure leaves a consistent last-confirmed state |

### Scientific benchmark dependency

The repository task list calls for a separate benchmark matrix covering aqueous/gas equilibrium, pH, precipitation, kinetics, stiff/non-stiff integration, balances, flows, and rewind equivalence. A5's UX matrix cannot provide reference values or scientific tolerances. A1–A4 and the integrator must supply those data and cite sources.

## 17. Cross-agent contract questions

### A1 — Chemistry Data & Domain

1. What stable substance identifier and schema version should the encyclopedia/browser use?
2. How are missing, unknown, estimated, hypothetical, and user-supplied properties represented?
3. What is the canonical property unit/provenance payload?
4. What hazard-data completeness levels and source references are available?
5. Can incomplete substance records be persisted independently of calculation readiness?

### A2 — Equation Parser & Balancer

1. What is the stable parser result/AST identity used by the reaction editor?
2. How are parser diagnostics represented, including field/token spans?
3. How does the UI distinguish parsed, balanced, and user-confirmed reaction revisions?
4. What operation result indicates ambiguous or underdetermined balancing?

### A3 — Aqueous Chemistry & Equilibrium

1. Which model identifiers and applicability diagnostics should be shown in Conditions?
2. How are equilibrium-only results distinguished from time-dependent simulation results?
3. What fields explain ideal-solution/activity assumptions and gas-model limitations?
4. How are precipitation/phase changes and unsupported cases surfaced to graphs and diagnostics?

### A4 — Kinetics & Numerical Solver

1. What are the authoritative contracts for simulation state, step result, event log, history checkpoint, and solver diagnostics?
2. What exactly is a “rate” series: species formation/consumption rate, reaction progress rate, or another variable? What are its dimensions?
3. What is the definition of one solver step, and what can cancellation safely interrupt?
4. How are history restore and deterministic replay distinguished and acknowledged?
5. What reproducibility guarantee is provided: bitwise, deterministic on same build, or within numeric tolerance?
6. For isothermal MVP, is temperature fixed per experiment and are Arrhenius parameters deferred, or can (k(T)) be evaluated at one fixed temperature? The UI must not imply temperature changes over time.
7. What event ordering rule applies to multiple events at the same model time?
8. What metadata is returned for gaps, solver sample times, interpolation policy, and numerical validity?

### Integrator / owner

1. Which shared DTOs are frozen for the first implementation round?
2. Who owns application-level command/event contracts?
3. What is the canonical simulation hash input and normalization algorithm?
4. Who creates and approves the scientific benchmark matrix?
5. Which review artifacts and owner approval mark the end of specification phase?

## 18. Conflicts, decisions, and risks

| ID | Finding | Evidence / consequence | Required action |
|---|---|---|---|
| C-01 | Isothermal MVP vs Arrhenius/time-varying temperature | Newer A4 owner instruction says constant T; current config/design/A4 prompt and simulation spec describe temperature-dependent rates | Owner/integrator reconcile config, design, A4 prompt, simulation spec and graph requirement before approval |
| C-02 | Temperature-time graph under isothermal MVP | Graph requirement remains mandatory while T is constant | Keep graph, label constant/isothermal, avoid heating animation; confirm acceptable display |
| C-03 | Rate variable semantics unspecified | A4 rate unit depends on whether rate is species rate, reaction progress rate, etc. | A4 defines variable IDs, dimensions, and labels |
| C-04 | Rewind semantics | Specs require history and deterministic replay; these are not reverse integration | A4/Application define checkpoint and replay contracts |
| C-05 | DTOs not yet frozen | Design lists required contract families but not final payload schemas | Integrator runs cross-agent contract review; A5 must not invent production DTOs |
| C-06 | Benchmark matrix missing | Tasks require it; no standalone matrix file exists in reviewed tree | A1–A4/integrator create source-backed reference cases and tolerances |
| C-07 | Asset metadata unmeasured | Git tree proves file names only; no verified pixel analysis in this review | Inspect binary assets before committing pixel dimensions/margins/stylebox values |
| C-08 | Finite mixing is conditional | Current simulation spec allows it only with validated model; newer A3/A4 working instruction disables it until validation | Keep control unavailable in MVP until explicit validation evidence and owner approval |
| C-09 | Replay compatibility | Historical model/data versions may be unavailable in a future offline package | Define compatibility policy and missing-version diagnostics |
| C-10 | Layout and chemical state | Current product decision says coordinates are visual only | Persist layout separately and test simulation-hash invariance |

## 19. A5 proposed work sequence

### Phase A — specification review (current)

- [x] Read shared OpenSpec, agent README, A1–A4 prompts, and A5 prompt.
- [x] Review current proposal, design, questions, tasks, and four specs.
- [x] Identify current DRAFT status and implementation gate.
- [x] Identify isothermal/Arrhenius discrepancy and missing benchmark artifact.
- [x] Draft A5-owned UX/integration review.
- [ ] Receive A1–A4 answers on shared contract questions.
- [ ] Reconcile owner decisions with shared OpenSpec baseline.

### Phase B — contract alignment (after agent responses)

- [ ] Freeze application-facing command/event contracts.
- [ ] Freeze GraphSeries/GraphPoint semantics and unit metadata.
- [ ] Freeze reliability/diagnostic presentation mapping.
- [ ] Freeze experiment/layout/replay persistence boundaries and revision/hash rules.
- [ ] Update only A5-owned OpenSpec specs after agreement.

### Phase C — approval and implementation gate

- [ ] Integrator resolves cross-agent conflicts and benchmark dependencies.
- [ ] Owner explicitly approves the OpenSpec baseline.
- [ ] Only after approval: implement Godot scenes, adapters, persistence, and integration tests in the authorized branch/scope.

## 20. Non-goals and implementation prohibition

This review does not authorize:
- Godot scene/script creation or application implementation;
- chemistry formulas or calculations in Presentation;
- parser/balancer implementation in A5;
- pH/equilibrium or kinetics solver implementation in A5;
- diffusion, collisions, fluid simulation, or spatial chemistry;
- dynamic heating visualization in an isothermal MVP;
- finite-time mixing without a validated model;
- mandatory network services;
- modifications to A1–A4 owned DTOs/specifications.

**Approval gate:** no implementation begins until the owner explicitly approves the OpenSpec baseline and the required scientific/technical validation tasks are completed.
