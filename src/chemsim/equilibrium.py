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
from math import exp, isfinite, isnan, log, log10, nextafter, sqrt
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
    reliability_status: str = "idealized_approximation"


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


def _ideal_gas_pressure(amount_mol: float, temperature_k: float, volume_m3: float) -> float:
    """Compute nRT/V without overflowing an avoidable intermediate product."""
    if amount_mol == 0.0:
        return 0.0
    log_pressure = log(amount_mol) + log(R) + log(temperature_k) - log(volume_m3)
    # A positive amount has a strictly positive ideal-gas pressure. Returning
    # 0.0 after exp() underflows would silently turn a present species into an
    # absent one in the public result, so fail explicitly at the float boundary.
    if log_pressure < log(nextafter(0.0, 1.0)):
        raise EquilibriumConvergenceError(
            "Positive gas partial pressure is below float range"
        )
    try:
        pressure = exp(log_pressure)
    except OverflowError:
        return float("inf")
    if pressure == 0.0:
        raise EquilibriumConvergenceError(
            "Positive gas partial pressure underflowed to zero"
        )
    return pressure


def _aqueous_result(
    species_mol_l: dict[str, float],
    pH: float,
    diagnostics: SolverDiagnostics,
    solid_mol_l: float = 0.0,
) -> AqueousResult:
    if (
        any(not isfinite(value) or value < 0.0 for value in species_mol_l.values())
        or not isfinite(pH)
        or not isfinite(solid_mol_l)
        or solid_mol_l < 0.0
        # Negative infinity is the intentional log-saturation sentinel for
        # an absent dissolved ion in an inactive-solid state. NaN and positive
        # infinity are never valid converged aqueous residuals.
        or (not isfinite(diagnostics.residual) and diagnostics.residual != -float("inf"))
        or not isfinite(diagnostics.component_balance_residual)
        or not isfinite(diagnostics.charge_balance_residual)
    ):
        raise EquilibriumConvergenceError(
            "Aqueous equilibrium produced non-finite or nonphysical result values"
        )
    return AqueousResult(species_mol_l, pH, diagnostics, solid_mol_l)


def _positive(name: str, value: float, *, allow_zero: bool = False) -> None:
    if not isfinite(value) or (value < 0 if allow_zero else value <= 0):
        qualifier = "non-negative" if allow_zero else "positive"
        raise EquilibriumInputError(f"{name} must be finite and {qualifier}")


def _scaled_fraction(total: float, numerator: float, other: float) -> float:
    """Return total * numerator / (numerator + other) without sum overflow."""
    if numerator >= other:
        fraction = 1.0 / (1.0 + other / numerator)
    else:
        ratio = numerator / other
        if ratio == 0.0:
            # The ratio can underflow even when total * numerator / other is
            # representable. Recover the scaled result in log space.
            return exp(log(total) + log(numerator) - log(other))
        fraction = ratio / (1.0 + ratio)
    return total * fraction


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
    if not isfinite(low) or not isfinite(high) or low > high:
        raise EquilibriumInputError("Bisection bounds must be finite and ordered")
    if not isfinite(x_tol) or x_tol <= 0 or not isfinite(f_tol) or f_tol < 0:
        raise EquilibriumInputError("Bisection tolerances must be finite and non-negative")
    if max_iter < 1:
        raise EquilibriumInputError("max_iter must be at least one")
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
        # Use a difference-based midpoint for same-sign bounds: halving
        # subnormal endpoints first can underflow to zero and leave the bracket.
        # Opposite-sign addition cannot overflow and avoids a large difference.
        if low < 0.0 < high:
            mid = 0.5 * (low + high)
        else:
            mid = low + 0.5 * (high - low)
        if mid <= low or mid >= high:
            # No representable float remains strictly inside this bracket.
            endpoint, endpoint_residual = (
                (low, f_low) if abs(f_low) <= abs(f_high) else (high, f_high)
            )
            if not isfinite(endpoint_residual):
                raise EquilibriumConvergenceError(
                    "Bisection reached floating-point resolution without a finite residual"
                )
            return endpoint, iteration, endpoint_residual
        f_mid = fn(mid)
        if isnan(f_mid):
            raise EquilibriumConvergenceError("NaN encountered during equilibrium iteration")
        interval_scale = max(abs(low), abs(high), 1e-300)
        if abs(f_mid) <= f_tol:
            return mid, iteration, f_mid
        if (high - low) <= x_tol * interval_scale:
            if not isfinite(f_mid):
                raise EquilibriumConvergenceError(
                    "Bisection interval converged without a finite residual"
                )
            return mid, iteration, f_mid
        # Compare signs directly instead of multiplying residuals: products can
        # overflow for large residuals and are undefined for inf * 0.
        if (f_low <= 0 <= f_mid) or (f_mid <= 0 <= f_low):
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
    """Solve a monotone positive-concentration equation in log10-space.

    Expand the initial bracket when valid finite inputs put the root outside
    the usual chemistry-scale interval. Bounds stop at representable positive
    float magnitudes rather than silently imposing a 1e-30..1e2 M domain.
    """
    # Include the smallest positive subnormal float, not merely 1e-323.
    min_log10 = log10(nextafter(0.0, 1.0))
    max_log10 = 308.0
    low = max(min_log10, low_log10)
    high = min(max_log10, high_log10)
    if low > high:
        if high_log10 < min_log10:
            raise EquilibriumConvergenceError("Positive concentration root is below float range")
        raise EquilibriumInputError("Log-root bounds must be finite and ordered")
    if low == high:
        candidate = 10.0**low
        candidate_residual = fn(candidate)
        if candidate_residual == 0.0:
            return candidate, 0, candidate_residual
        raise EquilibriumConvergenceError(
            "Positive concentration root cannot be represented within float range"
        )

    while True:
        f_low = fn(10.0**low)
        f_high = fn(10.0**high)
        if isnan(f_low) or isnan(f_high):
            raise EquilibriumConvergenceError("NaN encountered while bracketing concentration root")
        if f_low <= 0.0 <= f_high:
            break
        if f_low > 0.0:
            if low <= min_log10:
                raise EquilibriumConvergenceError("Positive concentration root is below float range")
            low = max(min_log10, low - 10.0)
        elif f_high < 0.0:
            if high >= max_log10:
                raise EquilibriumConvergenceError("Positive concentration root is above float range")
            high = min(max_log10, high + 10.0)
        else:
            raise EquilibriumConvergenceError("Could not bracket positive concentration root")

    # The residual has concentration units and may be arbitrarily small.
    # An absolute 1e-13 cutoff would accept a bracket endpoint for trace
    # solutions without locating the root. Convergence is therefore controlled
    # in log-concentration space by the relative x tolerance.
    root, iterations, residual = _bisect(
        lambda y: fn(10.0**y), low, high, x_tol=1e-15, f_tol=0.0
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
        a_minus = _scaled_fraction(total_acid_mol_l, ka, h)
        oh = kw / h
        return h - a_minus - oh

    h, iterations, residual = _log_root_positive(charge_residual)
    a_minus = _scaled_fraction(total_acid_mol_l, ka, h)
    ha = _scaled_fraction(total_acid_mol_l, h, ka)
    oh = kw / h
    # Compare against the complementary remainder instead of summing both
    # species: rounded finite concentrations can overflow when their total is
    # close to the largest representable float.
    mass_error = abs(ha - (total_acid_mol_l - a_minus))
    charge_error = abs(h - a_minus - oh)
    return _aqueous_result(
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
    # Pair the large spectator-ion inventories before adding the much
    # smaller free H+/OH- contribution; the left-associated form can erase it.
    charge = (naoh_mol_l - hcl_mol_l) + (h - oh)
    return _aqueous_result(
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
    return _aqueous_result(
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
        # Evaluate NH4+ - Cl- as (N_total - Cl_total) - NH3.
        # Directly forming NH4+ rounds it to N_total when NH3 is below one
        # ULP of a very large inventory, erasing the acid contribution.
        nh3 = _scaled_fraction(total_nitrogen_mol_l, ka_nh4, h)
        oh = kw / h
        return (total_nitrogen_mol_l - chloride_mol_l) - nh3 + h - oh

    h, iterations, residual = _log_root_positive(charge_residual)
    nh4 = _scaled_fraction(total_nitrogen_mol_l, h, ka_nh4)
    nh3 = _scaled_fraction(total_nitrogen_mol_l, ka_nh4, h)
    oh = kw / h
    # Avoid overflowing NH3 + NH4+ when the finite total is near float max.
    # Each species is bounded by the total, so compare one against the
    # complementary remainder instead of forming the potentially overflowing sum.
    mass_error = abs(nh3 - (total_nitrogen_mol_l - nh4))
    # Match the cancellation-safe algebra used by the root residual; direct
    # NH4+ + H+ - Cl- - OH- can erase trace acid/base charge beside a huge
    # common nitrogen/chloride inventory.
    charge_error = abs((total_nitrogen_mol_l - chloride_mol_l) - nh3 + h - oh)
    return _aqueous_result(
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
    feed_scale = max(
        abs(silver_total_mol_l), abs(chloride_total_mol_l),
        abs(sodium_total_mol_l), abs(nitrate_total_mol_l),
    )
    if feed_scale > 0.0:
        if abs(silver_total_mol_l - nitrate_total_mol_l) > 1e-10 * feed_scale:
            raise EquilibriumInputError("AgNO3 feed must have equal Ag and nitrate totals")
        if abs(chloride_total_mol_l - sodium_total_mol_l) > 1e-10 * feed_scale:
            raise EquilibriumInputError("NaCl feed must have equal Na and chloride totals")
    elif any(value != 0.0 for value in (
        silver_total_mol_l, chloride_total_mol_l, sodium_total_mol_l, nitrate_total_mol_l
    )):
        raise EquilibriumInputError("Feed totals are inconsistent")

    log_ksp = log(ksp)

    def log_saturation(ag_concentration: float, cl_concentration: float) -> float:
        if ag_concentration <= 0.0 or cl_concentration <= 0.0:
            return -float("inf")
        return log(ag_concentration) + log(cl_concentration) - log_ksp

    initial_log_saturation = log_saturation(silver_total_mol_l, chloride_total_mol_l)
    if initial_log_saturation <= 0.0:
        ag, cl, solid, iterations, residual = (
            silver_total_mol_l, chloride_total_mol_l, 0.0, 0, initial_log_saturation
        )
    else:
        # Solve for the remaining concentration of the limiting ion, not the
        # precipitation extent. When solubility is tiny relative to the feed,
        # subtracting an extent close to the limiting total loses significant
        # digits in the dissolved concentration and can stop bisection early.
        limiting_total = min(silver_total_mol_l, chloride_total_mol_l)
        excess_total = abs(silver_total_mol_l - chloride_total_mol_l)

        def saturation_of_limiting_remaining(limiting_remaining: float) -> float:
            return log_saturation(
                limiting_remaining, excess_total + limiting_remaining
            )

        limiting_remaining, iterations, residual = _log_root_positive(
            saturation_of_limiting_remaining,
            low_log10=log10(nextafter(0.0, 1.0)),
            high_log10=log10(limiting_total),
        )
        solid = limiting_total - limiting_remaining
        if silver_total_mol_l <= chloride_total_mol_l:
            ag = limiting_remaining
            cl = excess_total + limiting_remaining
        else:
            ag = excess_total + limiting_remaining
            cl = limiting_remaining

    h = sqrt(kw)
    oh = sqrt(kw)
    # Pair like-charge feed contributions before combining them. Summing
    # O(1e308) cations first can round away the much smaller H+/OH- terms
    # and report a false charge residual for an otherwise neutral solution.
    charge = (ag - cl) + (sodium_total_mol_l - nitrate_total_mol_l) + (h - oh)
    ag_balance = abs(ag + solid - silver_total_mol_l)
    cl_balance = abs(cl + solid - chloride_total_mol_l)
    return _aqueous_result(
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
    if not species_initial or set(species_initial) != set(stoichiometry):
        raise EquilibriumInputError("Initial amounts and stoichiometry must define the same non-empty species set")
    if any(not isfinite(value) or value == 0 for value in stoichiometry.values()):
        raise EquilibriumInputError("Stoichiometric coefficients must be finite and non-zero")
    if not isfinite(log_kp):
        raise EquilibriumInputError("log_kp must be finite")
    for name, amount in species_initial.items():
        _positive(f"initial {name}", amount, allow_zero=True)
    if not any(amount > 0.0 for amount in species_initial.values()):
        raise EquilibriumInputError("At least one initial species amount must be positive")

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
        # Work in log space so finite T/V inputs do not overflow in an
        # intermediate R*T or V*p° product.
        log_common = log(R) + log(temperature_k) - log(volume_m3) - log(STANDARD_PRESSURE_PA)
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
    partials = {
        name: _ideal_gas_pressure(amount, temperature_k, volume_m3)
        for name, amount in final.items()
    }
    # Summing partial pressures avoids overflowing an intermediate total-mole
    # sum when the final pressure itself is representable.
    total_pressure = sum(partials.values())

    if (
        any(not isfinite(amount) or amount < 0.0 for amount in final.values())
        or any(not isfinite(pressure) or pressure < 0.0 for pressure in partials.values())
        or not isfinite(total_pressure)
    ):
        raise EquilibriumConvergenceError(
            "Gas equilibrium produced non-finite amounts or pressures"
        )

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
