# ChemSim

Offline-first chemistry learning application built with Godot 4.x for Windows 10/11.

## Current state

This branch contains the first presentation-only Godot scaffold:
- Russian-language experiment workspace.
- Empty composition and reaction panels.
- Visual-only grid field; no physical simulation.
- Graph placeholders for concentration, rate, and temperature.
- Isothermal-model indication.
- Conditions and diagnostics placeholders.
- Chemistry and simulation actions disabled until domain contracts and services are approved and implemented.

No parser, balancing, equilibrium, kinetics, solver, persistence, or chemistry DTO implementation is included.

## Run

1. Install Godot 4.3 or newer.
2. Import this directory using the Godot Project Manager.
3. Run the project.

## Architecture boundary

Visual colors and coordinates must never affect chemistry, solver inputs, simulation identity, or replay hashes. Temperature is presented as constant because the MVP is isothermal. This scaffold does not claim that the OpenSpec baseline or A1–A4 contracts are frozen.
