import math
import unittest

from chemsim.equilibrium import (
    EquilibriumInputError,
    solve_agcl_precipitation,
    solve_agcl_solubility,
    solve_ammonia_buffer,
    solve_h2_i2_hi,
    solve_no2_dimerization,
    solve_strong_neutralization,
    solve_weak_acid,
    _bisect,
    EquilibriumConvergenceError,
)


class BisectionRobustnessTests(unittest.TestCase):
    def test_handles_infinite_endpoint_residual(self):
        root, iterations, residual = _bisect(
            lambda x: float("inf") if x == 0.0 else (1.0 / x) - 1.0,
            0.0,
            2.0,
        )
        self.assertAlmostEqual(root, 1.0, places=12)
        self.assertGreater(iterations, 0)
        self.assertAlmostEqual(residual, 0.0, places=12)

    def test_midpoint_does_not_overflow_for_large_same_sign_bounds(self):
        root, iterations, residual = _bisect(
            lambda x: x - 1.2e308,
            1.0e308,
            1.7e308,
            x_tol=1e-14,
            f_tol=1e-290,
        )
        self.assertAlmostEqual(root / 1.0e308, 1.2, places=12)
        self.assertGreater(iterations, 0)
        self.assertTrue(math.isfinite(residual))

    def test_subnormal_interval_never_steps_outside_bracket(self):
        low = math.ulp(0.0)
        high = 2.0 * low
        root, iterations, residual = _bisect(
            lambda x: -1.0 if x <= low else 1.0,
            low,
            high,
            f_tol=0.0,
        )
        self.assertGreaterEqual(root, low)
        self.assertLessEqual(root, high)
        self.assertGreater(iterations, 0)
        self.assertTrue(math.isfinite(residual))

    def test_rejects_non_finite_or_reversed_bounds(self):
        with self.assertRaises(EquilibriumInputError):
            _bisect(lambda x: x, 0.0, float("inf"))
        with self.assertRaises(EquilibriumInputError):
            _bisect(lambda x: x, 2.0, 1.0)

    def test_rejects_invalid_tolerances_and_iteration_limit(self):
        with self.assertRaises(EquilibriumInputError):
            _bisect(lambda x: x, -1.0, 1.0, x_tol=0.0)
        with self.assertRaises(EquilibriumInputError):
            _bisect(lambda x: x, -1.0, 1.0, f_tol=-1.0)
        with self.assertRaises(EquilibriumInputError):
            _bisect(lambda x: x, -1.0, 1.0, max_iter=0)

    def test_rejects_unbracketed_root(self):
        with self.assertRaises(EquilibriumConvergenceError):
            _bisect(lambda x: x * x + 1.0, -1.0, 1.0)

    def test_does_not_report_convergence_on_infinite_interior_residual(self):
        def discontinuous_residual(x):
            if x == 0.0:
                return -1.0
            if x == 1.0:
                return 1.0
            return float("inf")

        with self.assertRaises(EquilibriumConvergenceError):
            _bisect(discontinuous_residual, 0.0, 1.0)


class AqueousBenchmarkTests(unittest.TestCase):
    def test_w01_acetic_acid(self):
        ka = 10 ** -4.756
        result = solve_weak_acid(0.01000, ka, 1.0e-14)
        self.assertAlmostEqual(result.species_mol_l["HA"] + result.species_mol_l["A-"], 0.01000, places=12)
        self.assertAlmostEqual(result.species_mol_l["H+"], result.species_mol_l["A-"] + result.species_mol_l["OH-"], places=11)
        self.assertAlmostEqual(result.pH, 3.387, delta=0.01)
        self.assertGreater(result.diagnostics.iterations, 0)
        self.assertEqual(result.diagnostics.reliability_status, "idealized_approximation")

    def test_w02_strong_neutralization(self):
        result = solve_strong_neutralization(0.01000, 0.01000, 1.0e-14)
        self.assertAlmostEqual(result.pH, 7.0, places=10)
        self.assertAlmostEqual(result.species_mol_l["Na+"], 0.01000)
        self.assertAlmostEqual(result.species_mol_l["Cl-"], 0.01000)
        self.assertLess(result.diagnostics.charge_balance_residual, 1e-12)

    def test_w03_agcl_solubility(self):
        result = solve_agcl_solubility(10 ** -9.748, 1.0e-14)
        self.assertAlmostEqual(result.species_mol_l["Ag+"], 1.335e-5, delta=2e-8)
        self.assertAlmostEqual(result.species_mol_l["Ag+"], result.species_mol_l["Cl-"], places=14)
        self.assertAlmostEqual(result.pH, 7.0, places=10)
        self.assertEqual(result.solid_mol_l, 0.0)  # no initial solid inventory is fabricated

    def test_w04_ammonia_buffer(self):
        result = solve_ammonia_buffer(0.02000, 0.01000, 10 ** -9.245, 1.0e-14)
        self.assertAlmostEqual(result.species_mol_l["NH3"] + result.species_mol_l["NH4+"], 0.02000, places=12)
        self.assertAlmostEqual(result.species_mol_l["Cl-"], 0.01000)
        self.assertAlmostEqual(result.pH, 9.245, delta=0.01)

    def test_w05_agcl_precipitation(self):
        ksp = 10 ** -9.748
        result = solve_agcl_precipitation(
            0.01000, 0.01000, 0.01000, 0.01000, ksp, 1.0e-14
        )
        self.assertAlmostEqual(result.species_mol_l["Ag+"], math.sqrt(ksp), delta=1e-10)
        self.assertAlmostEqual(result.species_mol_l["Cl-"], math.sqrt(ksp), delta=1e-10)
        self.assertAlmostEqual(result.solid_mol_l, 0.01000 - math.sqrt(ksp), delta=1e-10)
        self.assertLess(result.diagnostics.component_balance_residual, 1e-11)
        self.assertLess(result.diagnostics.charge_balance_residual, 1e-11)

    def test_precipitation_is_inactive_when_undersaturated(self):
        result = solve_agcl_precipitation(
            1e-6, 1e-6, 1e-6, 1e-6, 10 ** -9.748, 1e-14
        )
        self.assertEqual(result.solid_mol_l, 0.0)


    def test_rejects_relative_feed_mismatch_for_trace_totals(self):
        with self.assertRaises(EquilibriumInputError):
            solve_agcl_precipitation(1.0e-12, 1.0e-12, 1.0e-12, 0.0, 1.0e-10, 1.0e-14)

    def test_rejects_feed_mismatch_below_previous_absolute_scale_floor(self):
        with self.assertRaises(EquilibriumInputError):
            solve_agcl_precipitation(1.0e-50, 1.0e-50, 1.0e-50, 0.0, 1.0e-100, 1.0e-14)

    def test_rejects_inconsistent_spectator_totals(self):
        with self.assertRaises(EquilibriumInputError):
            solve_agcl_precipitation(0.01, 0.01, 0.02, 0.01, 1e-10, 1e-14)


    def test_strong_acid_only_and_strong_base_only(self):
        acid = solve_strong_neutralization(0.01000, 0.0, 1.0e-14)
        base = solve_strong_neutralization(0.0, 0.01000, 1.0e-14)
        self.assertAlmostEqual(acid.pH, 2.0, places=9)
        self.assertAlmostEqual(base.pH, 12.0, places=9)
        self.assertLess(acid.diagnostics.charge_balance_residual, 1e-11)
        self.assertLess(base.diagnostics.charge_balance_residual, 1e-11)

    def test_rejects_empty_strong_electrolyte_fixture(self):
        with self.assertRaises(EquilibriumInputError):
            solve_strong_neutralization(0.0, 0.0, 1.0e-14)

    def test_ammonium_only_solution_is_acidic(self):
        result = solve_ammonia_buffer(0.01000, 0.01000, 10 ** -9.245, 1.0e-14)
        self.assertLess(result.pH, 7.0)
        self.assertGreater(result.species_mol_l["NH4+"], result.species_mol_l["NH3"])



class GasBenchmarkTests(unittest.TestCase):
    def test_large_finite_inputs_do_not_overflow_intermediate_pressure_products(self):
        result = solve_h2_i2_hi(
            1.0e300, 1.0e300, 0.0, 1.0e300, 1.0e300, 1.0
        )
        self.assertTrue(math.isfinite(result.total_pressure_pa))
        self.assertTrue(all(math.isfinite(value) for value in result.partial_pressures_pa.values()))
        self.assertAlmostEqual(
            result.total_pressure_pa,
            sum(result.partial_pressures_pa.values()),
            delta=result.total_pressure_pa * 1e-12,
        )

    def test_g01_no2_dimerization(self):
        result = solve_no2_dimerization(0.010, 0.0, 298.15, 1.0e-3, 6.73)
        self.assertEqual(result.diagnostics.reliability_status, "idealized_approximation")
        self.assertGreater(result.species_mol["N2O4"], 0.0)
        self.assertGreater(result.species_mol["NO2"], 0.0)
        self.assertAlmostEqual(
            result.species_mol["NO2"] + 2 * result.species_mol["N2O4"],
            0.010,
            places=11,
        )
        p_no2 = result.partial_pressures_pa["NO2"] / 100_000.0
        p_n2o4 = result.partial_pressures_pa["N2O4"] / 100_000.0
        self.assertAlmostEqual(p_n2o4 / (p_no2 * p_no2), 6.73, delta=1e-7)

    def test_g02_h2_i2_hi(self):
        result = solve_h2_i2_hi(0.010, 0.010, 0.0, 298.15, 1.0e-3, 690.2)
        self.assertGreater(result.species_mol["HI"], 0.0)
        self.assertAlmostEqual(result.species_mol["H2"], result.species_mol["I2(g)"], places=11)
        p_hi = result.partial_pressures_pa["HI"] / 100_000.0
        p_h2 = result.partial_pressures_pa["H2"] / 100_000.0
        p_i2 = result.partial_pressures_pa["I2(g)"] / 100_000.0
        self.assertAlmostEqual((p_hi * p_hi) / (p_h2 * p_i2), 690.2, delta=1e-5)

    def test_rejects_finite_inputs_that_overflow_output_pressures(self):
        with self.assertRaises(EquilibriumConvergenceError):
            solve_h2_i2_hi(
                1.0e300, 1.0e300, 0.0, 298.15, 1.0e-300, 1.0
            )

    def test_rejects_zero_equilibrium_constant(self):
        with self.assertRaises(EquilibriumInputError):
            solve_no2_dimerization(0.01, 0.0, 298.15, 1e-3, 0.0)


    def test_g02_equilibrium_can_proceed_in_reverse(self):
        result = solve_h2_i2_hi(0.0, 0.0, 0.010, 298.15, 1.0e-3, 690.2)
        self.assertLess(result.extent_mol, 0.0)
        self.assertGreater(result.species_mol["H2"], 0.0)
        self.assertGreater(result.species_mol["I2(g)"], 0.0)
        self.assertGreater(result.species_mol["HI"], 0.0)
        self.assertAlmostEqual(
            result.species_mol["H2"] + 0.5 * result.species_mol["HI"],
            0.005,
            places=10,
        )


    def test_gas_solver_accepts_sub_femtomole_inventory(self):
        result = solve_no2_dimerization(1.0e-18, 0.0, 298.15, 1.0e-3, 6.73)
        self.assertGreater(result.species_mol["N2O4"], 0.0)
        self.assertGreater(result.species_mol["NO2"], 0.0)
        self.assertAlmostEqual(
            result.species_mol["NO2"] + 2.0 * result.species_mol["N2O4"],
            1.0e-18,
            delta=1.0e-30,
        )


if __name__ == "__main__":
    unittest.main()
