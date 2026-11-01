"""Small, dependency-free equilibrium reference solver for ChemSim A3.

Scope:
- Ideal-dilute aqueous fixtures: weak monoprotic acid, strong acid/base,
  AgCl solubility, NH3/NH4+ buffer, and AgCl precipitation.
- Ideal-gas, fixed-volume equilibrium fixtures: 2 NO2 <=> N2O4 and
  H2 + I2 <=> 2 HI.

This is deliberately a fixture-oriented MVP, not a universal speciation engine.
All equilibrium constants are dimensionless thermodynamic constants on the
explicit standard states documented by each input. Activity coefficients are
fixed to one; callers must not use this module outside that approximation.
"""

from __future__ import annotations

from dataclasses import dataclass
from math import isfinite, isnan, log, log10, nextafter, sqrt
from typing import Callable


R = 8.31446261815324  # J mol-1 K-1
STANDARD_CONCENTRATION_MOL_L = 1.0
STANDARD_PRESSURE_PA = 100_000.0


class EquilibriumInputError(ValueError):
    """Input data are incomplete, nonphysical, or outside this solver's scope."""


class EquilibriumConvergenceError(RuntimeError):
    """A physically bracketed equilibrium root could not be converged."""


@dataclass(frozen=True)
class SolverDiagnostics:
    iterations: int
    residual: float
    component_balance_residual: float
    charge_balance_residual: float
    method: str
    balance_unit: str
    activity_model: str = "ideal_dilute_gamma_equals_1"


@dataclass(frozen=True)
class AqueousResult:
    species_mol_l: dict[str, float]
    pH: float
    diagnostics: SolverDiagnostics
    solid_mol_l: float = 0.0


@dataclass(frozen=True)
class GasResult:
    species_mol: dict[str, float]
    partial_pressures_pa: dict[str, float]
    total_pressure_pa: float
    extent_mol: float
    diagnostics: SolverDiagnostics


def _positive(name: str, value: float, *, allow_zero: bool = False) -> None:
    if not isfinite(value) or (value < 0 if allow_zero else value <= 0):
        qualifier = "non-negative" if allow_zero else "positive"
        raise EquilibriumInputError(f"{name} must be finite and {qualifier}")


def _bisect(
    fn: Callable[[float], float],
    low: float,
    high: float,
    *,
    x_tol: float = 1e-13,
    f_tol: float = 1e-12,
    max_iter: int = 250,
) -> tuple[float, int, float]:
    """Bisection with endpoint handling; fn must be monotone on [low, high]."""
    f_low = fn(low)
    f_high = fn(high)
    if isnan(f_low) or isnan(f_high):
        raise EquilibriumConvergenceError("NaN encountered at an equilibrium bracket endpoint")
    if abs(f_low) <= f_tol:
        return low, 0, f_low
    if abs(f_high) <= f_tol:
        return high, 0, f_high
    if (f_low > 0 and f_high > 0) or (f_low < 0 and f_high < 0):
        raise EquilibriumConvergenceError("Equilibrium root is not bracketed")

    for iteration in range(1, max_iter + 1):
        mid = 0.5 * (low + high)
        f_mid = fn(mid)
        if isnan(f_mid):
            raise EquilibriumConvergenceError("NaN encountered during equilibrium iteration")
        if abs(f_mid) <= f_tol or (high - low) <= x_tol * max(1.0, abs(mid)):
            return mid, iteration, f_mid
        if f_low * f_mid <= 0:
            high, f_high = mid, f_mid
        else:
            low, f_low = mid, f_mid
    raise EquilibriumConvergenceError(
        f"Bisection did not converge in {max_iter} iterations; residual={f_mid!r}"
    )


def _log_root_positive(
    fn: Callable[[float], float],
    *,
    low_log10: float = -30.0,
    high_log10: float = 2.0,
) -> tuple[float, int, float]:
    """Solve a scalar concentration equation in log10-space."""
    root, iterations, residual = _bisect(
        lambda y: fn(10.0**y), low_log10, high_log10, f_tol=1e-13
    )
    return 10.0**root, iterations, residual


def solve_weak_acid(
    total_acid_mol_l: float,
    ka: float,
    kw: float,
) -> AqueousResult:
    """Solve HA <=> H+ + A- including water autoionization.

    ka and kw are dimensionless on the 1 mol/L concentration standard state.
    """
    _positive("total_acid_mol_l", total_acid_mol_l)
    _positive("ka", ka)
    _positive("kw", kw)

    def charge_residual(h: float) -> float:
        a_minus = total_acid_mol_l * ka / (ka + h)
        oh = kw / h
        return h - a_minus - oh

    h, iterations, residual = _log_root_positive(charge_residual)
    a_minus = total_acid_mol_l * ka / (ka + h)
    ha = total_acid_mol_l - a_minus
    oh = kw / h
    mass_error = abs((ha + a_minus) - total_acid_mol_l)
    charge_error = abs(h - a_minus - oh)
    return AqueousResult(
        {"HA": ha, "A-": a_minus, "H+": h, "OH-": oh},
        -log10(h / STANDARD_CONCENTRATION_MOL_L),
        SolverDiagnostics(iterations, residual, mass_error, charge_error, "log-space bisection", "mol/L"),
    )


def solve_strong_neutralization(
    hcl_mol_l: float,
    naoh_mol_l: float,
    kw: float,
) -> AqueousResult:
    """Solve fully dissociated HCl/NaOH with spectator Na+ and Cl-."""
    _positive("hcl_mol_l", hcl_mol_l, allow_zero=True)
    _positive("naoh_mol_l", naoh_mol_l, allow_zero=True)
    _positive("kw", kw)
    if hcl_mol_l == 0 and naoh_mol_l == 0:
        raise EquilibriumInputError("At least one strong electrolyte must be present")

    net_acid = hcl_mol_l - naoh_mol_l

    def residual(h: float) -> float:
        return h - kw / h - net_acid

    h, iterations, f_residual = _log_root_positive(residual)
    oh = kw / h
    charge = h + naoh_mol_l - oh - hcl_mol_l
    return AqueousResult(
        {"H+": h, "OH-": oh, "Na+": naoh_mol_l, "Cl-": hcl_mol_l},
        -log10(h),
        SolverDiagnostics(iterations, f_residual, 0.0, abs(charge), "log-space bisection", "mol/L"),
    )


def solve_agcl_solubility(ksp: float, kw: float) -> AqueousResult:
    """Solubility of AgCl in pure water with excess AgCl(s) reservoir.

    Returns dissolved solubility and pH. The mass of remaining solid is
    intentionally not returned because no initial solid inventory is supplied.
    """
    _positive("ksp", ksp)
    _positive("kw", kw)
    s = STANDARD_CONCENTRATION_MOL_L * sqrt(ksp)
    h = sqrt(kw)
    oh = kw / h
    return AqueousResult(
        {"Ag+": s, "Cl-": s, "H+": h, "OH-": oh},
        -log10(h),
        SolverDiagnostics(
            0, 0.0, 0.0, abs((s + h) - (s + oh)), "closed-form ideal solubility", "mol/L"
        ),
    )


def solve_ammonia_buffer(
    total_nitrogen_mol_l: float,
    chloride_mol_l: float,
    ka_nh4: float,
    kw: float,
) -> AqueousResult:
    """Solve NH4+ <=> NH3 + H+ with nitrogen/chloride balances and water."""
    _positive("total_nitrogen_mol_l", total_nitrogen_mol_l)
    _positive("chloride_mol_l", chloride_mol_l, allow_zero=True)
    _positive("ka_nh4", ka_nh4)
    _positive("kw", kw)
    if chloride_mol_l > total_nitrogen_mol_l:
        raise EquilibriumInputError("Chloride total cannot exceed total nitrogen for this NH4Cl fixture")

    def charge_residual(h: float) -> float:
        nh4 = total_nitrogen_mol_l * h / (h + ka_nh4)
        oh = kw / h
        return nh4 + h - chloride_mol_l - oh

    h, iterations, residual = _log_root_positive(charge_residual)
    nh4 = total_nitrogen_mol_l * h / (h + ka_nh4)
    nh3 = total_nitrogen_mol_l - nh4
    oh = kw / h
    mass_error = abs(nh3 + nh4 - total_nitrogen_mol_l)
    charge_error = abs(nh4 + h - chloride_mol_l - oh)
    return AqueousResult(
        {"NH3": nh3, "NH4+": nh4, "H+": h, "OH-": oh, "Cl-": chloride_mol_l},
        -log10(h),
        SolverDiagnostics(iterations, residual, mass_error, charge_error, "log-space bisection", "mol/L"),
    )


def solve_agcl_precipitation(
    silver_total_mol_l: float,
    chloride_total_mol_l: float,
    sodium_total_mol_l: float,
    nitrate_total_mol_l: float,
    ksp: float,
    kw: float,
) -> AqueousResult:
    """Equilibrate Ag+/Cl- with at most one AgCl(s) phase.

    The supplied spectator totals must represent neutral AgNO3/NaCl feed:
    Ag_total == nitrate_total and Na_total == chloride_total. Initial solution
    is assumed to contain no AgCl(s). Complementarity is handled by checking
    initial saturation before solving for precipitation extent.
    """
    for name, value in (
        ("silver_total_mol_l", silver_total_mol_l),
        ("chloride_total_mol_l", chloride_total_mol_l),
        ("sodium_total_mol_l", sodium_total_mol_l),
        ("nitrate_total_mol_l", nitrate_total_mol_l),
    ):
        _positive(name, value, allow_zero=True)
    _positive("ksp", ksp)
    _positive("kw", kw)
    scale = max(1.0, silver_total_mol_l, chloride_total_mol_l)
    if abs(silver_total_mol_l - nitrate_total_mol_l) > 1e-10 * scale:
        raise EquilibriumInputError("AgNO3 feed must have equal Ag and nitrate totals")
    if abs(chloride_total_mol_l - sodium_total_mol_l) > 1e-10 * scale:
        raise EquilibriumInputError("NaCl feed must have equal Na and chloride totals")

    q_initial = silver_total_mol_l * chloride_total_mol_l
    if q_initial <= ksp:
        ag, cl, solid, iterations, residual = silver_total_mol_l, chloride_total_mol_l, 0.0, 0, q_initial - ksp
    else:
        upper = min(silver_total_mol_l, chloride_total_mol_l)

        def saturation(extent: float) -> float:
            ag_remaining = max(0.0, silver_total_mol_l - extent)
            cl_remaining = max(0.0, chloride_total_mol_l - extent)
            product = ag_remaining * cl_remaining
            if product == 0:
                return -float("inf")
            return log(product / ksp)

        solid, iterations, residual = _bisect(saturation, 0.0, upper, f_tol=1e-12)
        ag = max(0.0, silver_total_mol_l - solid)
        cl = max(0.0, chloride_total_mol_l - solid)

    h = sqrt(kw)
    oh = sqrt(kw)
    charge = ag + sodium_total_mol_l + h - cl - nitrate_total_mol_l - oh
    ag_balance = abs(ag + solid - silver_total_mol_l)
    cl_balance = abs(cl + solid - chloride_total_mol_l)
    return AqueousResult(
        {"Ag+": ag, "Cl-": cl, "Na+": sodium_total_mol_l,
         "NO3-": nitrate_total_mol_l, "H+": h, "OH-": oh},
        -log10(h),
        SolverDiagnostics(
            iterations, residual, max(ag_balance, cl_balance), abs(charge),
            "active-set + bisection" if solid > 0 else "inactive-solid check",
            "mol/L",
        ),
        solid_mol_l=solid,
    )


def _gas_equilibrium(
    species_initial: dict[str, float],
    stoichiometry: dict[str, float],
    log_kp: float,
    temperature_k: float,
    volume_m3: float,
) -> GasResult:
    _positive("temperature_k", temperature_k)
    _positive("volume_m3", volume_m3)
    if not isfinite(log_kp):
        raise EquilibriumInputError("log_kp must be finite")
    for name, amount in species_initial.items():
        _positive(f"initial {name}", amount, allow_zero=True)

    negative = [v for v in stoichiometry.values() if v < 0]
    positive = [v for v in stoichiometry.values() if v > 0]
    if not negative or not positive:
        raise EquilibriumInputError("Reaction must contain reactants and products")
    lower = max(
        (-species_initial[name] / coefficient)
        for name, coefficient in stoichiometry.items() if coefficient > 0
    )
    upper = min(
        (species_initial[name] / -coefficient)
        for name, coefficient in stoichiometry.items() if coefficient < 0
    )
    if lower > upper or not isfinite(lower) or not isfinite(upper):
        raise EquilibriumInputError("Invalid reaction extent interval")

    def amounts(extent: float) -> dict[str, float]:
        return {
            name: species_initial[name] + stoichiometry[name] * extent
            for name in species_initial
        }

    def log_q(extent: float) -> float:
        ns = amounts(extent)
        total = sum(ns.values())
        if total <= 0:
            return -float("inf")
        # p_i / p° = n_i RT / (V p°)
        log_common = log(R * temperature_k / (volume_m3 * STANDARD_PRESSURE_PA))
        value = 0.0
        for name, coefficient in stoichiometry.items():
            n = ns[name]
            if n <= 0:
                if coefficient > 0:
                    return -float("inf")
                return float("inf")
            log_activity = log(n) + log_common
            value += coefficient * log_activity
        return value

    def residual(extent: float) -> float:
        return log_q(extent) - log_kp

    # Move one representable float into the feasible interval; a fixed epsilon
    # would incorrectly reject small but valid mole inventories.
    lo = nextafter(lower, upper)
    hi = nextafter(upper, lower)
    if lo > hi:
        raise EquilibriumInputError("No positive-composition interval for gas equilibrium")
    extent, iterations, f_residual = _bisect(residual, lo, hi, f_tol=1e-11)
    final = amounts(extent)
    total_moles = sum(final.values())
    partials = {
        name: amount * R * temperature_k / volume_m3
        for name, amount in final.items()
    }
    total_pressure = total_moles * R * temperature_k / volume_m3

    # Verify the extent update itself in amount space. Atom conservation is
    # guaranteed by the fixed benchmark stoichiometries, not by this generic helper.
    component_balance_residual = max(
        abs(final[name] - species_initial[name] - stoichiometry[name] * extent)
        for name in species_initial
    )
    min_amount = min(final.values())
    if min_amount < -1e-12:
        raise EquilibriumConvergenceError("Solver produced a negative gas amount")
    return GasResult(
        final,
        partials,
        total_pressure,
        extent,
        SolverDiagnostics(
            iterations, f_residual, component_balance_residual, 0.0,
            "extent + logQ bisection", "mol"
        ),
    )


def solve_no2_dimerization(
    no2_initial_mol: float,
    n2o4_initial_mol: float,
    temperature_k: float,
    volume_m3: float,
    kp: float,
) -> GasResult:
    """Solve 2 NO2(g) <=> N2O4(g), fixed T and V."""
    _positive("kp", kp)
    return _gas_equilibrium(
        {"NO2": no2_initial_mol, "N2O4": n2o4_initial_mol},
        {"NO2": -2.0, "N2O4": 1.0},
        log(kp),
        temperature_k,
        volume_m3,
    )


def solve_h2_i2_hi(
    h2_initial_mol: float,
    i2_initial_mol: float,
    hi_initial_mol: float,
    temperature_k: float,
    volume_m3: float,
    kp: float,
) -> GasResult:
    """Solve H2(g) + I2(g) <=> 2 HI(g), fixed T and V.

    I2 is explicitly gaseous; this function does not model I2(s) or phase change.
    """
    _positive("kp", kp)
    return _gas_equilibrium(
        {"H2": h2_initial_mol, "I2(g)": i2_initial_mol, "HI": hi_initial_mol},
        {"H2": -1.0, "I2(g)": -1.0, "HI": 2.0},
        log(kp),
        temperature_k,
        volume_m3,
    )
