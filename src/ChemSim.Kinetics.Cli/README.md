# A4 standalone kinetics CLI: initial synthetic engineering slice

**Status:** implementation prototype, NOT a scientifically validated chemistry engine, final cross-agent DTO, integrated Godot feature, secure arbitrary-path runner or Windows release. Authorized for staged work by the [owner-approved OpenSpec v0.1](https://github.com/AndreyCokol/ChemSim/blob/main/openspec/changes/define-chemsim-mvp/APPROVAL.md), reviewed baseline 02b8b31706807279ee31a78772383e31f425f7d3.

## Command

The new ChemSim.Kinetics.Cli is a .NET 10 executable project that references the existing ChemSim.Kinetics RK45 library. Its application command arguments are:

    chemsim-solver --request <absolute-request.json> --response <absolute-response.json>

A checked-in fixture exists at tests/ChemSim.Kinetics.Tests/Fixtures/a4-synthetic-request.json. Its species A and B are mathematical placeholders, NOT valid A2 chemical formulas. A2 suggested N2O4(g) -> 2NO2(g) for a later chemistry-parseable integration smoke, with an explicitly synthetic rate constant. Neither represents real verified kinetics.

## Current narrow request and response

The request uses the v0.1 envelope (contract_version, message_id, kind simulation_request, payload, errors). The CLI deliberately handles only the closed-isothermal-irreversible and hypothetical data-quality case; it rejects unrecognized object fields and unsupported models.

The payload requires explicit species references and revisions, initial amounts in mol, signed integer stoichiometry, independent kinetic orders, irreversible volumetric power-law model, positive SI rate constant with derived base-dimension exponents, an explicitly matching fixed parameter/experiment temperature in K, volume in m3, time and step quantities in s, complete solver policy and an explicit conservation-law array. There is NO K-to-k inference, mol/L conversion, Arrhenius correction, scientific source validation, or implicit guess of missing metadata.

Rate-constant dimensions are mol^(1-total_order), m^(-3*(1-total_order)), s^-1. All numeric rate inputs must already be in the associated canonical SI basis, with unknown or mismatched units rejected. The input is hypothetical even when a synthetic conservation law is supplied: atom/charge provenance and molecular identity remain A1/A2-owned.

A valid request produces a correlated response with specific solver outcome, a time/amount sample prefix, requested end and last valid time, numerical work counters and independent reliability axes. A successful run is marked completed only after reaching the final endpoint. A failed run may have validated partial samples; a step limit remains step_limit even when completeness is partial. No extrapolated graph points, computed temperature/kinetic-rate series or replay are invented.

Malformed envelope/JSON, unsupported version or file failure returns nonzero exit status and may leave no response file. Valid envelope with ineligible model parameters returns a blocked response with no samples. The narrow payload shape is an A4 producer mapping proposal under the approved high-level v0.1 contract: it is NOT a new unreviewed global DTO freeze.

## Limits and remaining safety work

The code bounds input to 1 MiB, response to 4 MiB, species to 32, reactions to 64, output samples to 1024 and internal solver trials to 250,000. It requests cancellation after 20 seconds of solver execution. Request and response must be different absolute .json paths in the same directory; the response may not overwrite a preexisting file. The response is first flushed to a temporary sibling file, then moved without overwrite.

**Known limitation:** the CLI relies on the calling application to confine the paths to an approved sandbox. Windows symlink/reparse-point traversal, cancellation/kill races, process/stderr/exit policy and safe concurrent file lifecycle still need integrator/A5 decisions and tests. Do not treat it as hardened for arbitrary untrusted path arguments.

**Windows CI evidence (experimental, not release certification):** a self-contained win-x64 single-file CLI was published and launched on a GitHub-hosted Windows runner with a Unicode temporary path. Exact code/workflow head `f07ee703f79318ffb5b7142b56e136f2b7480914` passed [A4 CI #41659828591](https://github.com/AndreyCokol/ChemSim/actions/runs/41659828591), including analytical validation and experimental binary artifact `a4-windows-x64-cli-experimental`. This validates the A4 CLI Windows-runner smoke only. It does **not** prove installation or full Godot→A4→A5 offline operation on a clean Windows machine, complete A1/A2 admissibility, antivirus/permissions behavior, or a release-ready MVP.

## Ownership and acceptance

A4 owns the CLI host-to-numeric integration and local tests. The integrator owns the final wire schemas, resource and path/exit policy, and cross-agent acceptance. A1/A2 own chemistry admission, stable species identities, source composition/charge and provenance. A5 owns the nonblocking Godot child-process controller and graph/result presentation.

Run the solution's .NET tests and the GitHub Actions A4 .NET workflow. Tests cover analytic synthetic A->B, response correlation, invalid inputs, missing/incorrect units and orders, unsupported arrow, preserved step-budget partial status, file non-overwrite and sample bounds. The workflow additionally executes the compiled CLI as a real child process from the checked-in synthetic JSON fixture and checks the response.

This is only a stage toward A2→A4→A5 integration, not completion of the full aqueous/gas/open-system/replay MVP.
