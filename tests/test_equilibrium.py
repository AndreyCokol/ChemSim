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
    _scaled_fraction,
    EquilibriumConvergenceError,
    SolverDiagnostics,
    _aqueous_result,
)


class AqueousResultValidationTests(unittest.TestCase):
    def test_rejects_positive_infinite_and_nan_residuals(self):
        for residual in (float("inf"), float("-inf"), float("nan")):
            diagnostics = SolverDiagnostics(0, residual, 0.0, 0.0, "test", "mol/L")
            with self.subTest(residual=residual):
                with self.assertRaises(EquilibriumConvergenceError):
                    _aqueous_result({"H+": 1.0e-7}, 7.0, diagnostics)

    def test_rejects_negative_balance_residual_diagnostics(self):
        for component, charge in ((-1.0, 0.0), (0.0, -1.0)):
            diagnostics = SolverDiagnostics(
                0, 0.0, component, charge, "test", "mol/L"
            )
            with self.subTest(component=component, charge=charge):
                with self.assertRaises(EquilibriumConvergenceError):
                    _aqueous_result({"H+": 1.0e-7}, 7.0, diagnostics)

    def test_rejects_negative_iteration_count(self):
        diagnostics = SolverDiagnostics(-1, 0.0, 0.0, 0.0, "test", "mol/L")
        with self.assertRaises(EquilibriumConvergenceError):
            _aqueous_result({"H+": 1.0e-7}, 7.0, diagnostics)


    def test_aqueous_result_species_map_cannot_be_mutated_after_validation(self):
        diagnostics = SolverDiagnostics(0, 0.0, 0.0, 0.0, "test", "mol/L")
        result = _aqueous_result({"H+": 1.0e-7}, 7.0, diagnostics)
        with self.assertRaises(TypeError):
            result.species_mol_l["H+"] = -1.0
        self.assertEqual(result.species_mol_l["H+"], 1.0e-7)

    def test_rejects_non_numeric_and_boolean_species_outputs(self):
        diagnostics = SolverDiagnostics(0, 0.0, 0.0, 0.0, "test", "mol/L")
        for species in ({"H+": True}, {"H+": "1e-7"}, {"H+": float("nan")}, {"": 1.0}):
            with self.subTest(species=species):
                with self.assertRaises(EquilibriumConvergenceError):
                    _aqueous_result(species, 7.0, diagnostics)

    def test_rejects_invalid_diagnostic_types_and_metadata(self):
        cases = (
            SolverDiagnostics(True, 0.0, 0.0, 0.0, "test", "mol/L"),
            SolverDiagnostics(0, 0.0, 0.0, 0.0, "", "mol/L"),
            SolverDiagnostics(0, 0.0, 0.0, 0.0, "test", ""),
        )
        for diagnostics in cases:
            with self.subTest(diagnostics=diagnostics):
                with self.assertRaises(EquilibriumConvergenceError):
                    _aqueous_result({"H+": 1.0e-7}, 7.0, diagnostics)

    def test_public_aqueous_inputs_reject_boolean_and_non_numeric_values(self):
        invalid_calls = (
            lambda value: solve_weak_acid(value, 1.0e-5, 1.0e-14),
            lambda value: solve_strong_neutralization(value, 0.0, 1.0e-14),
            lambda value: solve_agcl_solubility(value, 1.0e-14),
            lambda value: solve_ammonia_buffer(value, 0.0, 1.0e-9, 1.0e-14),
        )
        for call in invalid_calls:
            for value in (True, "0.01"):
                with self.subTest(call=call, value=value):
                    with self.assertRaises(EquilibriumInputError):
                        call(value)


class ScaledFractionRobustnessTests(unittest.TestCase):
    def test_ratio_underflow_does_not_erase_representable_scaled_fraction(self):
        smallest = math.ulp(0.0)
        result = _scaled_fraction(1.0e308, smallest, 1.0e308)
        self.assertEqual(result, smallest)


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
    def test_zero_inventory_precipitation_limit_has_finite_physical_result(self):
        result = solve_agcl_precipitation(0.0, 0.0, 0.0, 0.0, 1.8e-10, 1.0e-14)
        self.assertTrue(all(math.isfinite(value) for value in result.species_mol_l.values()))
        self.assertEqual(result.solid_mol_l, 0.0)
        self.assertTrue(math.isfinite(result.pH))
        self.assertEqual(result.diagnostics.residual, float("-inf"))

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

    def test_strong_acid_trace_concentration_is_not_lost_to_absolute_residual_tolerance(self):
        result = solve_strong_neutralization(1.0e-100, 0.0, 1.0e-200)
        expected_h = 0.5 * (1.0 + math.sqrt(5.0)) * 1.0e-100
        self.assertAlmostEqual(result.species_mol_l["H+"], expected_h, delta=expected_h * 1e-10)
        self.assertAlmostEqual(result.pH, -math.log10(expected_h), places=9)

    def test_positive_root_bracket_expands_for_large_concentrations(self):
        result = solve_strong_neutralization(1.0e100, 0.0, 1.0e-14)
        self.assertAlmostEqual(result.species_mol_l["H+"], 1.0e100, delta=1.0e90)
        self.assertAlmostEqual(result.pH, -100.0, delta=1e-10)

    def test_strong_base_trace_concentration_is_not_lost_to_absolute_residual_tolerance(self):
        result = solve_strong_neutralization(0.0, 1.0e-100, 1.0e-200)
        expected_oh = 0.5 * (1.0 + math.sqrt(5.0)) * 1.0e-100
        expected_h = 1.0e-200 / expected_oh
        self.assertAlmostEqual(result.species_mol_l["OH-"], expected_oh, delta=expected_oh * 1e-10)
        self.assertAlmostEqual(result.species_mol_l["H+"], expected_h, delta=expected_h * 1e-10)
        self.assertAlmostEqual(result.pH, -math.log10(expected_h), places=9)
        self.assertLess(result.diagnostics.charge_balance_residual, 1.0e-110)

    def test_weak_acid_species_fraction_avoids_overflowing_total_times_ka(self):
        result = solve_weak_acid(1.0e300, 1.0e300, 1.0e-14)
        self.assertTrue(math.isfinite(result.species_mol_l["A-"]))
        self.assertTrue(math.isfinite(result.species_mol_l["HA"]))
        self.assertAlmostEqual(
            result.species_mol_l["HA"] + result.species_mol_l["A-"],
            1.0e300,
            delta=1.0e287,
        )
        self.assertAlmostEqual(
            result.species_mol_l["H+"],
            result.species_mol_l["A-"] + result.species_mol_l["OH-"],
            delta=result.species_mol_l["H+"] * 1.0e-10,
        )

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

    def test_agcl_precipitation_resolves_low_solubility_relative_to_feed(self):
        ksp = 1.0e-24
        result = solve_agcl_precipitation(
            1.0e-2, 1.0e-2, 1.0e-2, 1.0e-2, ksp, 1.0e-14
        )
        expected_solubility = math.sqrt(ksp)
        self.assertAlmostEqual(
            result.species_mol_l["Ag+"], expected_solubility,
            delta=expected_solubility * 1.0e-10,
        )
        self.assertAlmostEqual(
            result.species_mol_l["Cl-"], expected_solubility,
            delta=expected_solubility * 1.0e-10,
        )
        self.assertAlmostEqual(
            result.species_mol_l["Ag+"] * result.species_mol_l["Cl-"],
            ksp, delta=ksp * 1.0e-10,
        )

    def test_agcl_precipitation_resolves_trace_limiting_ion_with_excess_counterion(self):
        ksp = 1.0e-24
        silver, chloride = 1.0e-2, 9.0e-3
        excess = silver - chloride
        expected_cl = 2.0 * ksp / (excess + math.sqrt(excess * excess + 4.0 * ksp))
        result = solve_agcl_precipitation(
            silver, chloride, chloride, silver, ksp, 1.0e-14
        )
        self.assertAlmostEqual(
            result.species_mol_l["Cl-"], expected_cl,
            delta=expected_cl * 1.0e-10,
        )
        self.assertAlmostEqual(
            result.species_mol_l["Ag+"] * result.species_mol_l["Cl-"],
            ksp, delta=ksp * 1.0e-10,
        )

    def test_agcl_precipitation_handles_near_stoichiometric_feeds_and_small_positive_excess(self):
        ksp = 1.0e-24
        chloride = 1.0e-2
        # Both excesses are representable at this feed scale. The first is
        # comparable to the dissolved root; the second is much smaller.
        for excess in (1.0e-12, 1.0e-16):
            with self.subTest(excess=excess):
                silver = chloride + excess
                actual_excess = silver - chloride
                expected_cl = (
                    2.0 * ksp
                    / (actual_excess + math.sqrt(actual_excess * actual_excess + 4.0 * ksp))
                )
                result = solve_agcl_precipitation(
                    silver, chloride, chloride, silver, ksp, 1.0e-14
                )
                ag = result.species_mol_l["Ag+"]
                cl = result.species_mol_l["Cl-"]
                self.assertAlmostEqual(cl, expected_cl, delta=expected_cl * 1.0e-10)
                self.assertAlmostEqual(ag, actual_excess + expected_cl, delta=expected_cl * 1.0e-10)
                self.assertAlmostEqual(ag * cl, ksp, delta=ksp * 1.0e-10)
                self.assertAlmostEqual(
                    cl + result.solid_mol_l, chloride, delta=math.ulp(chloride) * 2.0
                )
                self.assertAlmostEqual(
                    ag + result.solid_mol_l, silver, delta=math.ulp(silver) * 2.0
                )
                self.assertLess(result.diagnostics.charge_balance_residual, 1.0e-15)

    def test_agcl_precipitation_rejects_unrepresentable_positive_dissolved_root(self):
        smallest_positive = math.ulp(0.0)
        with self.assertRaises(EquilibriumConvergenceError):
            solve_agcl_precipitation(
                1.0e308,
                smallest_positive,
                smallest_positive,
                1.0e308,
                smallest_positive,
                1.0e-14,
            )

    def test_agcl_precipitation_handles_large_finite_feeds_and_ksp(self):
        feed = 1.0e308
        ksp = 1.0e308
        expected = math.sqrt(ksp)
        result = solve_agcl_precipitation(
            feed, feed, feed, feed, ksp, 1.0e-14
        )
        self.assertAlmostEqual(
            result.species_mol_l["Ag+"], expected, delta=expected * 1.0e-10
        )
        self.assertAlmostEqual(
            result.species_mol_l["Cl-"], expected, delta=expected * 1.0e-10
        )
        self.assertAlmostEqual(
            result.species_mol_l["Ag+"] * result.species_mol_l["Cl-"],
            ksp,
            delta=ksp * 1.0e-10,
        )
        self.assertLess(result.diagnostics.charge_balance_residual, 1.0e-15)

    def test_agcl_precipitation_at_exact_saturation_does_not_create_solid(self):
        result = solve_agcl_precipitation(
            1.0, 1.0, 1.0, 1.0, 1.0, 1.0e-14
        )
        self.assertEqual(result.solid_mol_l, 0.0)
        self.assertEqual(result.species_mol_l["Ag+"], 1.0)
        self.assertEqual(result.species_mol_l["Cl-"], 1.0)
        self.assertAlmostEqual(result.diagnostics.residual, 0.0, delta=1.0e-15)
        self.assertEqual(result.diagnostics.charge_balance_residual, 0.0)

    def test_precipitation_is_inactive_when_undersaturated(self):
        result = solve_agcl_precipitation(
            1e-6, 1e-6, 1e-6, 1e-6, 10 ** -9.748, 1e-14
        )
        self.assertEqual(result.solid_mol_l, 0.0)


    def test_accepted_feed_mismatch_remains_visible_in_charge_diagnostic(self):
        mismatch = 2.0 ** -35
        result = solve_agcl_precipitation(
            1.0, 1.0, 1.0, 1.0 + mismatch, 10.0, 1.0e-14
        )
        self.assertEqual(result.solid_mol_l, 0.0)
        self.assertAlmostEqual(
            result.diagnostics.charge_balance_residual,
            mismatch,
            delta=1.0e-15,
        )

    def test_active_precipitation_preserves_accepted_feed_charge_mismatch(self):
        mismatch = 2.0 ** -35
        result = solve_agcl_precipitation(
            1.0, 1.0, 1.0, 1.0 + mismatch, 0.01, 1.0e-14
        )
        self.assertGreater(result.solid_mol_l, 0.0)
        self.assertAlmostEqual(
            result.diagnostics.charge_balance_residual,
            mismatch,
            delta=1.0e-15,
        )

    def test_agcl_precipitation_does_not_create_solid_for_single_salt_feeds(self):
        # AgNO3-only and NaCl-only feeds are individually neutral, but cannot
        # produce AgCl(s) because one required counter-ion is absent.
        cases = (
            ("AgNO3 only", 1.0e-2, 0.0, 0.0, 1.0e-2, "Ag+", "NO3-"),
            ("NaCl only", 0.0, 1.0e-2, 1.0e-2, 0.0, "Cl-", "Na+"),
        )
        for label, silver, chloride, sodium, nitrate, dissolved, spectator in cases:
            with self.subTest(feed=label):
                result = solve_agcl_precipitation(
                    silver, chloride, sodium, nitrate, 1.0e-12, 1.0e-14
                )
                self.assertEqual(result.solid_mol_l, 0.0)
                # A missing counter-ion makes log(Q/Ksp) exactly -inf; this is
                # a valid inactive-solid sentinel, not a failed solver residual.
                self.assertEqual(result.diagnostics.residual, -math.inf)
                self.assertEqual(result.species_mol_l["Ag+"], silver)
                self.assertEqual(result.species_mol_l["Cl-"], chloride)
                self.assertEqual(result.species_mol_l["Na+"], sodium)
                self.assertEqual(result.species_mol_l["NO3-"], nitrate)
                self.assertEqual(result.diagnostics.component_balance_residual, 0.0)
                self.assertLess(result.diagnostics.charge_balance_residual, 1.0e-15)
                self.assertEqual(result.species_mol_l[dissolved], result.species_mol_l[spectator])

    def test_rejects_relative_feed_mismatch_for_trace_totals(self):
        with self.assertRaises(EquilibriumInputError):
            solve_agcl_precipitation(1.0e-12, 1.0e-12, 1.0e-12, 0.0, 1.0e-10, 1.0e-14)

    def test_rejects_feed_mismatch_below_previous_absolute_scale_floor(self):
        with self.assertRaises(EquilibriumInputError):
            solve_agcl_precipitation(1.0e-50, 1.0e-50, 1.0e-50, 0.0, 1.0e-100, 1.0e-14)

    def test_rejects_inconsistent_spectator_totals(self):
        with self.assertRaises(EquilibriumInputError):
            solve_agcl_precipitation(0.01, 0.01, 0.02, 0.01, 1e-10, 1e-14)


    def test_strong_neutralization_charge_diagnostic_preserves_large_feed_difference(self):
        hcl = 1.0e308
        naoh = math.nextafter(hcl, math.inf)
        result = solve_strong_neutralization(hcl, naoh, 1.0e-14)
        expected_net = naoh - hcl
        self.assertLess(
            result.diagnostics.charge_balance_residual,
            abs(expected_net) * 1.0e-13,
        )

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

    def test_weak_acid_minor_undissociated_species_survives_large_total(self):
        result = solve_weak_acid(1.0e100, 1.0e308, 1.0e-14)
        self.assertGreater(result.species_mol_l["HA"], 0.0)
        self.assertAlmostEqual(result.species_mol_l["HA"], 1.0e-108, delta=1.0e-108 * 1.0e-8)

    def test_ammonia_buffer_minor_nh3_survives_large_total(self):
        result = solve_ammonia_buffer(1.0e308, 1.0e308, 1.0e-308, 1.0e-14)
        self.assertGreater(result.species_mol_l["NH3"], 0.0)
        self.assertAlmostEqual(result.species_mol_l["NH3"], 1.0, delta=1.0e-8)
        self.assertLess(result.diagnostics.charge_balance_residual, 1.0e-15)

    def test_ammonia_mass_balance_diagnostic_does_not_overflow_near_float_max(self):
        total = float.fromhex("0x1.fffffffffffffp+1023")
        # For an NH4Cl-only feed, this Ka gives a small but representable
        # NH3 fraction while NH4+ rounds close to the full nitrogen inventory.
        ratio = 4.388057732427192e-5
        ka_nh4 = ratio * ratio * total
        result = solve_ammonia_buffer(total, total, ka_nh4, 1.0e-14)

        self.assertTrue(math.isfinite(result.species_mol_l["NH3"]))
        self.assertTrue(math.isfinite(result.species_mol_l["NH4+"]))
        self.assertTrue(math.isfinite(result.diagnostics.component_balance_residual))
        self.assertLess(result.diagnostics.component_balance_residual, total * 1.0e-13)
        self.assertTrue(math.isfinite(result.diagnostics.charge_balance_residual))

    def test_ammonium_only_solution_is_acidic(self):
        result = solve_ammonia_buffer(0.01000, 0.01000, 10 ** -9.245, 1.0e-14)
        self.assertLess(result.pH, 7.0)
        self.assertGreater(result.species_mol_l["NH4+"], result.species_mol_l["NH3"])



class AcidBaseLimitingRegimeTests(unittest.TestCase):
    def test_weak_acid_approaches_water_limit_when_analytical_total_is_trace(self):
        for total in (1.0e-12, 1.0e-50, 1.0e-200):
            with self.subTest(total=total):
                result = solve_weak_acid(total, 1.0e-5, 1.0e-14)
                self.assertTrue(math.isfinite(result.pH))
                self.assertAlmostEqual(result.pH, 7.0, delta=1.0e-5)
                self.assertGreaterEqual(result.species_mol_l["HA"], 0.0)
                self.assertGreaterEqual(result.species_mol_l["A-"], 0.0)
                self.assertAlmostEqual(
                    math.fsum((result.species_mol_l["HA"], result.species_mol_l["A-"])),
                    total,
                    delta=max(math.ulp(total) * 4.0, total * 1.0e-10),
                )

    def test_strong_neutralization_remains_stable_near_equivalence_at_trace_scale(self):
        acid = 1.0e-12
        for base in (0.0, acid, math.nextafter(acid, 0.0), math.nextafter(acid, math.inf)):
            with self.subTest(base=base):
                result = solve_strong_neutralization(acid, base, 1.0e-14)
                self.assertTrue(math.isfinite(result.pH))
                self.assertTrue(all(math.isfinite(v) and v >= 0.0 for v in result.species_mol_l.values()))
                self.assertLessEqual(result.diagnostics.charge_balance_residual, 1.0e-14)

    def test_ammonia_buffer_is_stable_when_total_inventory_is_below_water_ionization(self):
        result = solve_ammonia_buffer(1.0e-200, 1.0e-200, 1.0e-9, 1.0e-14)
        self.assertTrue(math.isfinite(result.pH))
        self.assertAlmostEqual(result.pH, 7.0, delta=1.0e-8)
        self.assertGreaterEqual(result.species_mol_l["NH3"], 0.0)
        self.assertGreaterEqual(result.species_mol_l["NH4+"], 0.0)
        self.assertAlmostEqual(
            math.fsum((result.species_mol_l["NH3"], result.species_mol_l["NH4+"])),
            1.0e-200,
            delta=math.ulp(1.0e-200) * 4.0,
        )

    def test_ammonia_buffer_speciation_remains_stable_for_huge_finite_inventory(self):
        total = 1.0e6
        result = solve_ammonia_buffer(total, total * 0.5, 1.0e-9, 1.0e-14)
        species = result.species_mol_l
        self.assertTrue(math.isfinite(result.pH))
        self.assertGreater(species["NH3"], 0.0)
        self.assertGreater(species["NH4+"], 0.0)
        self.assertAlmostEqual(
            math.fsum((species["NH3"], species["NH4+"])),
            total,
            delta=total * 1.0e-12,
        )


class AqueousConservationAuditTests(unittest.TestCase):
    def assert_scaled_residual(self, residual, scale, *, relative=2.0e-10):
        self.assertTrue(math.isfinite(residual))
        self.assertLessEqual(residual, max(math.ulp(scale) * 8.0, abs(scale) * relative))

    def test_weak_acid_mass_and_charge_balances_across_trace_and_large_scales(self):
        for total in (1.0e-12, 1.0e-2, 1.0e100):
            with self.subTest(total=total):
                result = solve_weak_acid(total, 1.0e-5, 1.0e-14)
                species = result.species_mol_l
                mass_residual = abs(math.fsum((species["HA"], species["A-"])) - total)
                charge_residual = abs(math.fsum((species["H+"], -species["A-"], -species["OH-"])))
                self.assert_scaled_residual(mass_residual, total)
                self.assert_scaled_residual(charge_residual, max(total, species["H+"]))
                self.assert_scaled_residual(result.diagnostics.component_balance_residual, total)
                self.assert_scaled_residual(result.diagnostics.charge_balance_residual, max(total, species["H+"]))

    def test_strong_neutralization_charge_balance_for_acid_excess_base_excess_and_trace(self):
        cases = ((1.0e-12, 0.0), (0.01, 0.01), (0.0, 1.0e-12), (1.0e100, 1.0e100))
        for acid, base in cases:
            with self.subTest(acid=acid, base=base):
                result = solve_strong_neutralization(acid, base, 1.0e-14)
                species = result.species_mol_l
                charge_residual = abs(math.fsum((species["H+"], species["Na+"], -species["OH-"], -species["Cl-"])))
                self.assert_scaled_residual(charge_residual, max(acid, base, species["H+"], species["OH-"]))
                self.assert_scaled_residual(result.diagnostics.charge_balance_residual, max(acid, base, species["H+"], species["OH-"]))

    def test_ammonia_buffer_nitrogen_and_charge_balances_across_scales(self):
        for total in (1.0e-12, 1.0e-2, 1.0e100):
            chloride = total * 0.5
            with self.subTest(total=total):
                result = solve_ammonia_buffer(total, chloride, 10.0 ** -9.245, 1.0e-14)
                species = result.species_mol_l
                nitrogen_residual = abs(math.fsum((species["NH3"], species["NH4+"])) - total)
                charge_residual = abs(math.fsum((species["NH4+"], species["H+"], -species["OH-"], -species["Cl-"])))
                self.assert_scaled_residual(nitrogen_residual, total)
                self.assert_scaled_residual(charge_residual, max(total, species["H+"]))
                self.assert_scaled_residual(result.diagnostics.component_balance_residual, total)
                self.assert_scaled_residual(result.diagnostics.charge_balance_residual, max(total, species["H+"]))

    def test_agcl_solubility_charge_balance_without_fabricating_solid_inventory(self):
        result = solve_agcl_solubility(1.8e-10, 1.0e-14)
        species = result.species_mol_l
        charge_residual = abs(math.fsum((species["Ag+"], species["H+"], -species["Cl-"], -species["OH-"])))
        self.assert_scaled_residual(charge_residual, max(species.values()))
        self.assertEqual(result.solid_mol_l, 0.0)
        self.assertEqual(result.diagnostics.component_balance_residual, 0.0)

    def test_agcl_precipitation_silver_chloride_and_charge_balances(self):
        for feed in (1.0e-12, 1.0e-2, 1.0e100):
            with self.subTest(feed=feed):
                result = solve_agcl_precipitation(feed, feed, feed, feed, 1.0e-24, 1.0e-14)
                species = result.species_mol_l
                solid = result.solid_mol_l
                ag_residual = abs(math.fsum((species["Ag+"], solid)) - feed)
                cl_residual = abs(math.fsum((species["Cl-"], solid)) - feed)
                charge_residual = abs(math.fsum((species["Ag+"], species["Na+"], species["H+"], -species["Cl-"], -species["NO3-"], -species["OH-"])))
                self.assert_scaled_residual(ag_residual, feed)
                self.assert_scaled_residual(cl_residual, feed)
                self.assert_scaled_residual(charge_residual, feed)
                self.assert_scaled_residual(result.diagnostics.component_balance_residual, feed)
                self.assert_scaled_residual(result.diagnostics.charge_balance_residual, feed)


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

    def test_gas_result_species_and_pressure_maps_are_read_only(self):
        result = solve_no2_dimerization(0.01, 0.0, 298.15, 1.0e-3, 6.73)
        with self.assertRaises(TypeError):
            result.species_mol["NO2"] = -1.0
        with self.assertRaises(TypeError):
            result.partial_pressures_pa["NO2"] = float("nan")
        self.assertGreater(result.species_mol["NO2"], 0.0)
        self.assertGreater(result.partial_pressures_pa["NO2"], 0.0)

    def test_gas_element_conservation_for_both_benchmark_reactions(self):
        no2_initial = 1.0e-18
        dimer = solve_no2_dimerization(no2_initial, 0.0, 298.15, 1.0e-3, 6.73)
        self.assertAlmostEqual(
            math.fsum((dimer.species_mol["NO2"], 2.0 * dimer.species_mol["N2O4"])),
            no2_initial,
            delta=no2_initial * 1.0e-12,
        )
        hi_initial = 1.0e-18
        reverse = solve_h2_i2_hi(0.0, 0.0, hi_initial, 298.15, 1.0e-3, 690.2)
        h_atoms = math.fsum((reverse.species_mol["H2"], reverse.species_mol["HI"] * 0.5))
        i_atoms = math.fsum((reverse.species_mol["I2(g)"], reverse.species_mol["HI"] * 0.5))
        self.assertAlmostEqual(h_atoms, hi_initial * 0.5, delta=hi_initial * 1.0e-12)
        self.assertAlmostEqual(i_atoms, hi_initial * 0.5, delta=hi_initial * 1.0e-12)
        self.assertAlmostEqual(
            reverse.total_pressure_pa,
            math.fsum(reverse.partial_pressures_pa.values()),
            delta=reverse.total_pressure_pa * 1.0e-12,
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

    def test_rejects_positive_gas_partial_pressure_below_float_range(self):
        with self.assertRaises(EquilibriumConvergenceError):
            solve_h2_i2_hi(
                1.0e-100, 1.0e-100, 0.0, 1.0e-100, 1.0e300, 1.0
            )

    def test_rejects_finite_inputs_that_overflow_output_pressures(self):
        with self.assertRaises(EquilibriumConvergenceError):
            solve_h2_i2_hi(
                1.0e300, 1.0e300, 0.0, 298.15, 1.0e-300, 1.0
            )

    def test_rejects_zero_equilibrium_constant(self):
        with self.assertRaises(EquilibriumInputError):
            solve_no2_dimerization(0.01, 0.0, 298.15, 1e-3, 0.0)

    def test_rejects_gas_system_with_zero_total_inventory(self):
        with self.assertRaises(EquilibriumInputError):
            solve_no2_dimerization(0.0, 0.0, 298.15, 1e-3, 6.73)


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
