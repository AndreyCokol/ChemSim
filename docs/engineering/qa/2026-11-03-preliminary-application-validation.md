# ChemSim — preliminary application validation and smoke QA (2026-11-03)

**Author/role:** A4 independent QA; user request: validate and preliminary-test runnable application.  
**Status:** **CONDITIONAL ENGINEERING SMOKE PASS, P1 NEGATIVE ACCEPTANCE FAILURE — NOT RELEASE READY**.  
**Not scientifically validated:** physically accurate N2O4/NO2 kinetic parameter, real equilibrium, arbitrary user experiments, safety or source licensing.

## Revisions audited

| Component | Source | Exact commit | Status |
| --- | --- | --- | --- |
| Main | `main` | `7f11ccfce3ca3b1eb725df10da0af6003f6a7cd0` | Owner-approved OpenSpec v0.1 baseline; **not merged executable app** |
| Integrated first playable slice | [Draft PR #17](https://github.com/AndreyCokol/ChemSim/pull/17), `integration/first-kinetics-smoke` | `96008906b0d0063b146a9882831e42ac2a863b1f` | Real synthetic Godot→.NET→Godot E2E; runnable Windows ZIP artifact |
| A4 latest | [Draft PR #6](https://github.com/AndreyCokol/ChemSim/pull/6) | `0eca3e0d552010d4dc135d7171d175401b8aea80` before QA-only files | A4 isolated numerical and CLI security tests passed |
| A5 isolated | [Draft PR #3](https://github.com/AndreyCokol/ChemSim/pull/3) | `90f24ea71923dbbd044e56fa8ade72ff55849e6a` | UI headless checks passed; direct raw JSON `GraphSeries.record_revision` bug independently reproduced |
| QA negative code | A4 test-only QA branch | `82b1b6d25a1226d795edd406c8ca2820cc5d2bff` | **Red on two genuine consumer defects**, source-of-truth [CI #41674585352](https://github.com/AndreyCokol/ChemSim/actions/runs/41674585352) |

## Positive runtime test evidence

Latest integrated [CI #41672258924](https://github.com/AndreyCokol/ChemSim/actions/runs/41672258924) is **completed/success**, same exact integration commit `96008906...`. Three jobs succeeded:

1. `linux-real-process-e2e`: .NET 10 A4 xUnit **64/64**, Linux self-contained solver publish, A2 actual parser/balance, A5 draft/graph/scenes validation and strict headless Godot A2→real external A4 process→A5. Actual test [`test_integration_smoke.gd`](https://github.com/AndreyCokol/ChemSim/blob/integration/first-kinetics-smoke/tests/test_integration_smoke.gd) checks 21 computed samples over 0–5 s at 0.25 s, expected hypothetical n(NO2)(5)=2(1-exp(-0.5)), N conservation, graph admission and present-only history playback/step/pause/speed/rewind/seek, invalidating stale results on user chemical edits. It does **not** assert full resimulation/physical rewind or arbitrary manual input.
2. `windows-selfcontained-publish`: .NET x64 self-contained CLI + native Windows subprocess (synthetic fixture) succeeded, **64/64** staged .NET tests.
3. `windows-standalone-package-smoke`: downloaded Godot exported exe + CLI, verified both files present and launched **exported Godot GUI executable with `--headless --quit-after 8`** using `Start-Process -Wait`; exit code zero. Created portable ZIP. **No Windows exported GUI clicking Run, cross-process Godot→A4, no clean offline Win10/11 machine test.**

**Windows ZIP artifact (not a user-endorsed scientific release):** [`ChemSim-synthetic-smoke-Windows-x64` ID 13248074105](https://github.com/AndreyCokol/ChemSim/actions/runs/41672258924/artifacts/13248074105), GitHub artifact size 64,796,782 bytes (compressed Actions artifact). Extract keeping `ChemSim.exe` and `chemsim-solver.exe` as siblings. Click the explicitly labeled synthetic demo `Учебный тест N₂O₄ → 2 NO₂`. Its k=0.1 s⁻¹ and kinetic order 1 are intentionally invented for software testing; the parser's stoichiometry `N2O4(g) -> 2NO2(g)` is atom/charge balanced, but **real NO2 kinetics are not proven**.

**Coverage drift:** staged integration PR #17 ran **64 A4 xUnit tests**, while latest isolated A4 PR #6 ran **102/102** at [CI #41672276758](https://github.com/AndreyCokol/ChemSim/actions/runs/41672276758). Do not infer that integration contains the newer A4 publication guard and safety regression set until source rebasing and independent exact-head CI.

## Independent negative application QA — real executable, real JSON

A4 added [`tests/a4_cross_agent/qa_integrated_smoke_negative.gd`](https://github.com/AndreyCokol/ChemSim/blob/feature/a4-kinetics-core/tests/a4_cross_agent/qa_integrated_smoke_negative.gd) and independent [CI workflow](https://github.com/AndreyCokol/ChemSim/blob/feature/a4-kinetics-core/.github/workflows/a4-integrated-qa.yml): checkout **immutable PR #17 SHA**, build its actual Linux A4 CLI, generate a request with actual A2 Godot parser, invoke real external A4 process, parse its real response JSON, and run *ten* corruption probes through unchanged A5 `ChemSimSmokeContract.validate_response`.

**QA #41674585352: FAILED (correctly flagged real defects).** The positive untampered request/response passed (`BASELINE_OK`); **8/10** corrupted responses were rejected. Two contradictory responses were **erroneously admitted as `ok:true, completed:true`**:
- **P1-QA-01**: `outcome=completed` and `numerical_status=completed` even though `reliability.completeness=partial`. This should be rejected before plotting.
- **P1-QA-02**: `outcome=completed` with `errors` containing a structured error object. This should be rejected rather than trusted as completed.

Exact failed log lines: `A4_QA_P1: A5 admitted completed falsely declared partial from real A4 result`; `A4_QA_P1: A5 admitted completed with an error envelope from real A4 result`. [P1 bug Issue #18](https://github.com/AndreyCokol/ChemSim/issues/18) tracks A5/integrator-owned fix and retest. The red QA is an intentional **test-fail on unsupported acceptance**, not a compilation failure; do not mark negative tests passed.

Other negative probes *passed rejection* for mismatched request ID, fabricated `verified` data quality, duplicate time, negative amount, broken N atom balance, claimed completed with missing end point, incorrect last valid time, and completed with failed numerical status. A bounded `step_limit` prefix remained correctly identifiable as incomplete.

## Additional warnings, test and release limitations

- **A5 standalone raw GraphSeries JSON revision bug:** A4 previous [CI #41668074731](https://github.com/AndreyCokol/ChemSim/actions/runs/41668074731) demonstrated Godot JSON parsing numeric `record_revision` as `TYPE_FLOAT` while A5 `graph_series_view.gd::_is_ref` expects `TYPE_INT`. In **this** integrated synthetic adapter, GDScript constructs a fresh typed integer result reference, so the one-demo E2E passes. General source-JSON `GraphSeries` interchange remains separately unapproved. The green normalization diagnostic is explicitly TEST-ONLY and not the production fix.
- **Unclean Godot test logs masked by green CI:** integrated Linux `test_draft_repository.gd` logs multiple `ERROR: Parse JSON failed` events (likely intentionally corrupted negative fixtures; require marker-context validation), and `test_main_draft_state.gd` logs `ERROR: Attempting to make child window exclusive, but the parent window already has another exclusive child`. The strict CI helper rejects `SCRIPT ERROR:` but not arbitrary `ERROR:`. This is a usability/test-harness investigation, not proof the program cannot start. The modal-window error should be independently addressed in A5's UI/test lifecycle.
- No real Windows 10/11 100% offline / Unicode directory / clean folder graphical button test yet. The Windows runner package smoke tests process startup but not Godot→CLI behavior. User trial on an isolated clean Windows VM and read-only/executable/file-collision/security checks remain needed.
- No source-backed A1 property admission, A3 chemical equilibrium models in running synthetic demo, real physical NO2 kinetics, user-defined chemical reaction simulation, open flows/events/replay integration, or verified redistribution rights. The chosen model is **hypothetical software smoke only**.
- Main branch still contains architecture approval but **not** the integrated app; executable test candidate is in Draft PR #17 and should not be described as merged/release-ready.

## Current gate decisions

| Gate | Result | Release interpretation |
| --- | --- | --- |
| Linux real-process vertical slice | **PASS** | One synthetic demo only |
| A2 syntactic/atomic balance for N2O4→NO2 | **PASS** | Chemistry parse, not measured kinetics |
| A4 isolated current numeric/CLI | **PASS** | 102 xUnit, not all staged |
| Staged A4 integration numeric/CLI | **PASS** | 64 xUnit and real subprocess |
| A5 headless UI/history presentation | **PASS** | Not manual GUI UX |
| Windows portable bundle + headless launch | **PASS** | Not offline clean OS or Windows Godot→CLI |
| A5 contradictory success/error response admission | **FAIL (P1)** | [Issue #18](https://github.com/AndreyCokol/ChemSim/issues/18), fix before broader release |
| Generic raw GraphSeries JSON interchange | **BLOCKED** | Strict revision type gate |
| Scientifically validated arbitrary reactions | **NOT READY** | Source/rights/model acceptance required |

**Recommended immediate P1 sequence:** (1) A5/integrator reject success if `errors` nonempty or completeness not `complete_for_declared_scope`, add regression and rerun negative QA; (2) integrate latest isolated A4 102-test baseline in PR #17 and rerun all CI; (3) fix general A5 JSON revision admission and select multi-species graph policy; (4) perform real **Windows portable exported Godot→CLI** run in Unicode/no-network/clean folder, with GUI steps and error capture; (5) run physical-science/provenance gate before presenting user-defined chemistry as verified.

**Source-only evidence caution:** These claims rely on exact GitHub Actions jobs/logs and audited branch code. Neither a local interactive Windows GUI test nor installation on a clean user's machine was performed in this session.
