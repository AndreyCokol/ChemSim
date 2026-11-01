# ChemSim

Offline-first chemistry learning application built with Godot 4.x for Windows 10/11 x64.

## Current implementation

The current A5 branch contains an interactive presentation/application shell:

- Russian-language experiment workspace with composition, reaction draft, conditions, diagnostics and graph panels.
- Add/remove component drafts with raw name, formula, quantity, unit and phase fields. No chemistry parsing or validation is implied.
- Presentation-only visual markers can be placed and moved on the field. Coordinates never affect chemistry, physics, solver inputs or simulation identity.
- Versioned local UI draft save/load (chemsim_ui_draft, schema v1). It stores only unvalidated user-entered text and visual positions. It is not the final experiment/chemistry interchange format.
- Isothermal MVP indication; temperature is fixed in the UI.
- Graph mode selectors are present, but graph data is not fabricated.
- Calculation, balancing, playback, step and rewind remain disabled until A1–A4 services and their contracts are integrated.

## Run

1. Install Godot 4.3 or newer.
2. Import this directory using the Godot Project Manager.
3. Run the project.

## Validation

A GitHub Actions workflow runs a headless editor import and application startup check on pull requests and pushes.

## Architecture boundaries

- No parser, balancer, equilibrium, kinetic solver or chemistry DTO is implemented in this A5 UI slice.
- Raw input fields are not interpreted, converted or validated as chemistry.
- Visual field coordinates and colors are presentation-only.
- Temperature is constant because the MVP is isothermal.
- Draft persistence is explicitly separate from the future versioned experiment format; it does not claim to preserve solver results, event logs or replay history.
- No network connection is required for the implemented workspace.
