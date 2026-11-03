using ChemSim.Kinetics.Domain;
using ChemSim.Kinetics.Simulation;

namespace ChemSim.Kinetics.Tests;

public sealed class KineticsSimulatorTests
{
    [Fact]
    public void FirstOrderReaction_MatchesAnalyticalSolution_AndConservesAmount()
    {
        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(0.5d, 0d))
            ],
            [
                new ConservationLaw("A-fragment", new Dictionary<string, double> { ["A"] = 1d, ["B"] = 1d })
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = 5d,
            OutputIntervalSeconds = 0.25d,
            Solver = new SolverOptions { RelativeTolerance = 1e-8, AbsoluteToleranceMol = 1e-11 }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        var final = result.Samples[^1].AmountsMol;
        var expectedA = Math.Exp(-0.5d * 5d);

        Assert.InRange(Math.Abs(final["A"] - expectedA), 0d, 2e-8);
        Assert.InRange(Math.Abs(final["A"] + final["B"] - 1d), 0d, 2e-10);
        Assert.True(result.Diagnostics.AcceptedSteps > 0);
    }

    [Fact]
    public void SecondOrderReaction_UsesKineticOrderNotStoichiometricCoefficient()
    {
        const double initialA = 2d;
        const double volume = 1d;
        const double k = 0.1d;
        const double endTime = 3d;

        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "2A-to-B",
                    new Dictionary<string, int> { ["A"] = -2, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 2d },
                    new RateConstant(k, -1d))
            ],
            [
                new ConservationLaw("A-fragment", new Dictionary<string, double> { ["A"] = 1d, ["B"] = 2d })
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = initialA, ["B"] = 0d },
            VolumeM3 = volume,
            StartTimeSeconds = 0d,
            EndTimeSeconds = endTime,
            OutputIntervalSeconds = 0.1d,
            Solver = new SolverOptions { RelativeTolerance = 1e-8, AbsoluteToleranceMol = 1e-11 }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        var final = result.Samples[^1].AmountsMol;
        var expectedA = initialA / (1d + 2d * k * initialA / volume * endTime);

        Assert.InRange(Math.Abs(final["A"] - expectedA), 0d, 2e-8);
        Assert.InRange(Math.Abs(final["A"] + 2d * final["B"] - initialA), 0d, 2e-10);
    }

    [Fact]
    public void UnbalancedConservationLaw_IsRejectedWhenNetworkIsBuilt()
    {
        Assert.Throws<ArgumentException>(() => new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(1d, 0d))
            ],
            [
                new ConservationLaw("bad-law", new Dictionary<string, double> { ["A"] = 1d, ["B"] = 2d })
            ]));
    }

    [Fact]
    public void InvalidRateConstantUnits_AreRejected()
    {
        Assert.Throws<ArgumentException>(() => new ReactionDefinition(
            "bad-units",
            new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
            new Dictionary<string, double> { ["A"] = 2d },
            new RateConstant(1d, 0d)));
    }

    [Fact]
    public void NegativeKineticOrder_IsRejected()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => new ReactionDefinition(
            "negative-order",
            new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
            new Dictionary<string, double> { ["A"] = -1d },
            new RateConstant(1d, 2d)));
    }

    [Fact]
    public void MissingInitialSpecies_IsRejectedBeforeIntegration()
    {
        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(1d, 0d))
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = 1d },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = 1d,
            OutputIntervalSeconds = 0.1d
        });

        Assert.Equal(SimulationStatus.InvalidInput, result.Status);
    }

    [Fact]
    public void Integrator_DoesNotTruncateIntervalAtLargeAbsoluteTime()
    {
        const double startTime = 1_000_000_000_000d;
        const double endTime = startTime + 0.01d;
        var duration = endTime - startTime;

        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(1d, 0d))
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
            VolumeM3 = 1d,
            StartTimeSeconds = startTime,
            EndTimeSeconds = endTime,
            OutputIntervalSeconds = 0.02d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-10,
                AbsoluteToleranceMol = 1e-12,
                InitialStepSeconds = 0.001d,
                MinimumStepSeconds = 1e-8,
                MaximumStepSeconds = 0.001d
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        Assert.Equal(endTime, result.Samples[^1].TimeSeconds);
        Assert.InRange(Math.Abs(result.Samples[^1].AmountsMol["A"] - Math.Exp(-duration)), 0d, 2e-9);
        Assert.True(result.Diagnostics.AcceptedSteps > 1);
    }

    [Fact]
    public void Integrator_AllowsFinalIntervalShorterThanMinimumStep()
    {
        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(1d, 0d))
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = 0.005d,
            OutputIntervalSeconds = 0.01d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-8,
                AbsoluteToleranceMol = 1e-11,
                InitialStepSeconds = 0.01d,
                MinimumStepSeconds = 0.01d,
                MaximumStepSeconds = 0.01d
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        Assert.Equal(0.005d, result.Samples[^1].TimeSeconds);
        Assert.InRange(Math.Abs(result.Samples[^1].AmountsMol["A"] - Math.Exp(-0.005d)), 0d, 2e-8);
    }

    [Fact]
    public void OutputInterval_ThatCannotAdvanceLargeTimestamp_IsRejected()
    {
        const double startTime = 1_000_000_000_000d;
        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(1d, 0d))
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
            VolumeM3 = 1d,
            StartTimeSeconds = startTime,
            EndTimeSeconds = startTime + 0.01d,
            OutputIntervalSeconds = 1e-6d
        });

        Assert.Equal(SimulationStatus.InvalidInput, result.Status);
    }


    [Fact]
    public void OutputInterval_ReachingDoubleMaxValue_UsesFiniteInwardUlp()
    {
        var startTime = Math.BitDecrement(double.MaxValue);
        var endTime = double.MaxValue;
        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(1d, 0d))
            ]);
        var request = new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
            VolumeM3 = 1d,
            StartTimeSeconds = startTime,
            EndTimeSeconds = endTime,
            OutputIntervalSeconds = endTime - startTime
        };

        var exception = Record.Exception(request.Validate);
        Assert.Null(exception);
    }

    [Fact]
    public void OutputInterval_ThatStopsAdvancingAfterUlpBoundary_IsRejectedUpFront()
    {
        const double startTime = 9_007_199_254_740_990d; // 2^53 - 2
        const double endTime = 9_007_199_254_740_996d;   // 2^53 + 4
        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(1d, 0d))
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
            VolumeM3 = 1d,
            StartTimeSeconds = startTime,
            EndTimeSeconds = endTime,
            OutputIntervalSeconds = 1d
        });

        Assert.Equal(SimulationStatus.InvalidInput, result.Status);
        Assert.Empty(result.Samples);
    }

    [Fact]
    public void PreCancelledRequest_ReturnsCancelledWithoutAdvancingState()
    {
        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(1d, 0d))
            ]);
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = 1d,
            OutputIntervalSeconds = 0.1d
        }, cancellation.Token);

        Assert.Equal(SimulationStatus.Cancelled, result.Status);
        Assert.Single(result.Samples);
        Assert.Equal(1d, result.Samples[0].AmountsMol["A"]);
        Assert.Equal(0d, result.Samples[0].AmountsMol["B"]);
    }

    [Fact]
    public void NonFiniteReactionRate_ReturnsNumericalFailureWithoutPublishingInvalidSample()
    {
        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(double.MaxValue, 0d))
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = 2d, ["B"] = 0d },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = 1d,
            OutputIntervalSeconds = 0.1d
        });

        Assert.Equal(SimulationStatus.NumericalFailure, result.Status);
        Assert.Equal(1, result.Diagnostics.RightHandSideEvaluations);
        Assert.Contains("non-finite extent rate", result.Diagnostics.Message);
        Assert.Single(result.Samples);
        Assert.Equal(2d, result.Samples[0].AmountsMol["A"]);
        Assert.Equal(0d, result.Samples[0].AmountsMol["B"]);
    }


    [Fact]
    public void TotalKineticOrder_OverflowIsRejected()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => new ReactionDefinition(
            "overflow-order",
            new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
            new Dictionary<string, double> { ["A"] = 1e308, ["B"] = 1e308 },
            new RateConstant(1d, -1e308)));
    }

    [Fact]
    public void ConservationLaw_OverflowDuringNetworkValidationIsRejected()
    {
        var reaction = new ReactionDefinition(
            "large-stoichiometry",
            new Dictionary<string, int> { ["A"] = -2, ["B"] = 2 },
            new Dictionary<string, double> { ["A"] = 1d },
            new RateConstant(1d, 0d));
        var law = new ConservationLaw(
            "large-coefficient",
            new Dictionary<string, double> { ["A"] = double.MaxValue });

        Assert.Throws<ArgumentException>(() => new ReactionNetwork(["A", "B"], [reaction], [law]));
    }

    [Fact]
    public void ConservationEvaluation_OverflowReturnsNumericalFailure()
    {
        var reaction = new ReactionDefinition(
            "A-to-B",
            new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
            new Dictionary<string, double> { ["A"] = 1d },
            new RateConstant(1e-300, 0d));
        var law = new ConservationLaw(
            "large-total",
            new Dictionary<string, double> { ["A"] = 8e307, ["B"] = 8e307 });
        var network = new ReactionNetwork(["A", "B"], [reaction], [law]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = 2d, ["B"] = 2d },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = 0.01d,
            OutputIntervalSeconds = 0.01d
        });

        Assert.Equal(SimulationStatus.NumericalFailure, result.Status);
        Assert.Contains("non-finite total", result.Diagnostics.Message);
        Assert.Single(result.Samples);
    }


    [Theory]
    [InlineData(double.NaN)]
    [InlineData(double.PositiveInfinity)]
    [InlineData(-1d)]
    public void RateConstant_RejectsInvalidTotalOrder(double totalOrder)
    {
        var rateConstant = new RateConstant(1d, 0d);
        Assert.Throws<ArgumentOutOfRangeException>(() =>
            rateConstant.ValidateForTotalOrder(totalOrder, "invalid-total-order"));
    }

    [Fact]
    public void ConservationValidation_IsInvariantToCoefficientScale()
    {
        var reaction = new ReactionDefinition(
            "A-to-B",
            new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
            new Dictionary<string, double> { ["A"] = 1d },
            new RateConstant(1d, 0d));

        // Multiplying a conservation vector by a non-zero scalar must not
        // turn a materially invalid invariant into an accepted one.
        var tinyButInvalidLaw = new ConservationLaw(
            "scaled-invalid-law",
            new Dictionary<string, double> { ["A"] = 1e-15, ["B"] = 2e-15 });

        Assert.Throws<ArgumentException>(() =>
            new ReactionNetwork(["A", "B"], [reaction], [tinyButInvalidLaw]));

        var validLaw = new ConservationLaw(
            "scaled-valid-law",
            new Dictionary<string, double> { ["A"] = 1e-15, ["B"] = 1e-15 });

        var network = new ReactionNetwork(["A", "B"], [reaction], [validLaw]);
        Assert.Single(network.ConservationLaws);
    }


    [Fact]
    public void FractionalOrder_ExtentRateDoesNotUnderflowThroughIntermediateConcentration()
    {
        const double initialA = 1e-300;
        const double volume = 1e100;
        const double rateConstant = 1e-200;

        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "fractional-A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 0.5d },
                    new RateConstant(rateConstant, 0.5d))
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = initialA, ["B"] = 0d },
            VolumeM3 = volume,
            StartTimeSeconds = 0d,
            EndTimeSeconds = 0.1d,
            OutputIntervalSeconds = 0.1d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-8,
                AbsoluteToleranceMol = 1e-315,
                InitialStepSeconds = 0.01d,
                MinimumStepSeconds = 1e-8,
                MaximumStepSeconds = 0.01d
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        var finalA = result.Samples[^1].AmountsMol["A"];
        Assert.InRange(finalA / initialA, 0.89d, 0.92d);
        Assert.True(result.Samples[^1].AmountsMol["B"] > 0d);
    }
    [Fact]
    public void ConsecutiveFirstOrderNetwork_MatchesAnalyticalProfileAndConservesAmount()
    {
        const double k = 0.4d;
        const double endTime = 5d;
        var network = new ReactionNetwork(
            ["A", "B", "C"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(k, 0d)),
                new ReactionDefinition(
                    "B-to-C",
                    new Dictionary<string, int> { ["B"] = -1, ["C"] = 1 },
                    new Dictionary<string, double> { ["B"] = 1d },
                    new RateConstant(k, 0d))
            ],
            [
                new ConservationLaw("total", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 1d, ["C"] = 1d
                })
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double>
            {
                ["A"] = 1d, ["B"] = 0d, ["C"] = 0d
            },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = endTime,
            OutputIntervalSeconds = 0.1d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-9,
                AbsoluteToleranceMol = 1e-12
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        foreach (var sample in result.Samples)
        {
            var expectedA = Math.Exp(-k * sample.TimeSeconds);
            var expectedB = k * sample.TimeSeconds * expectedA;
            var expectedC = 1d - expectedA - expectedB;

            Assert.InRange(Math.Abs(sample.AmountsMol["A"] - expectedA), 0d, 3e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol["B"] - expectedB), 0d, 3e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol["C"] - expectedC), 0d, 3e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol.Values.Sum() - 1d), 0d, 2e-10);
            Assert.All(sample.AmountsMol.Values, amount => Assert.True(amount >= 0d));
        }
    }

    [Fact]
    public void ParallelFirstOrderPathways_MatchAnalyticalProfileAndBranchingRatio()
    {
        const double k1 = 0.7d;
        const double k2 = 0.3d;
        const double totalRate = k1 + k2;
        const double endTime = 4d;
        var network = new ReactionNetwork(
            ["A", "B", "C"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(k1, 0d)),
                new ReactionDefinition(
                    "A-to-C",
                    new Dictionary<string, int> { ["A"] = -1, ["C"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(k2, 0d))
            ],
            [
                new ConservationLaw("total", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 1d, ["C"] = 1d
                })
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double>
            {
                ["A"] = 1d, ["B"] = 0d, ["C"] = 0d
            },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = endTime,
            OutputIntervalSeconds = 0.1d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-9,
                AbsoluteToleranceMol = 1e-12
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        foreach (var sample in result.Samples)
        {
            var expectedA = Math.Exp(-totalRate * sample.TimeSeconds);
            var converted = 1d - expectedA;
            var expectedB = k1 / totalRate * converted;
            var expectedC = k2 / totalRate * converted;

            Assert.InRange(Math.Abs(sample.AmountsMol["A"] - expectedA), 0d, 3e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol["B"] - expectedB), 0d, 3e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol["C"] - expectedC), 0d, 3e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol.Values.Sum() - 1d), 0d, 2e-10);
            Assert.All(sample.AmountsMol.Values, amount => Assert.True(amount >= 0d));
        }

        var final = result.Samples[^1].AmountsMol;
        Assert.InRange(Math.Abs(final["B"] / (final["B"] + final["C"]) - k1 / totalRate), 0d, 3e-9);
    }

    [Fact]
    public void ZeroOrderReaction_MatchesAnalyticalProfileAndVolumeScalingBeforeDepletion()
    {
        const double initialA = 1d;
        const double volume = 2d;
        const double volumetricRate = 0.05d;
        const double extentRate = volumetricRate * volume;
        const double endTime = 8d; // Depletion would occur at 10 s.

        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "zero-order-A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double>(),
                    new RateConstant(volumetricRate, 1d))
            ],
            [
                new ConservationLaw("total", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 1d
                })
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double>
            {
                ["A"] = initialA, ["B"] = 0d
            },
            VolumeM3 = volume,
            StartTimeSeconds = 0d,
            EndTimeSeconds = endTime,
            OutputIntervalSeconds = 0.25d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-9,
                AbsoluteToleranceMol = 1e-12
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        foreach (var sample in result.Samples)
        {
            var expectedA = initialA - extentRate * sample.TimeSeconds;
            var expectedB = extentRate * sample.TimeSeconds;

            Assert.InRange(Math.Abs(sample.AmountsMol["A"] - expectedA), 0d, 2e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol["B"] - expectedB), 0d, 2e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol.Values.Sum() - initialA), 0d, 2e-10);
            Assert.All(sample.AmountsMol.Values, amount => Assert.True(amount >= 0d));
        }
    }

    [Fact]
    public void FractionalOrderHalfReaction_MatchesAnalyticalProfileAtNonUnitVolume()
    {
        const double initialA = 1d;
        const double volume = 4d;
        const double rateConstant = 0.05d;
        const double endTime = 4d;
        var concentrationScale = Math.Sqrt(volume);

        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "half-order-A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 0.5d },
                    new RateConstant(rateConstant, 0.5d))
            ],
            [
                new ConservationLaw("total", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 1d
                })
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double>
            {
                ["A"] = initialA, ["B"] = 0d
            },
            VolumeM3 = volume,
            StartTimeSeconds = 0d,
            EndTimeSeconds = endTime,
            OutputIntervalSeconds = 0.1d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-9,
                AbsoluteToleranceMol = 1e-12
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        foreach (var sample in result.Samples)
        {
            var expectedRootA = Math.Sqrt(initialA) - rateConstant * concentrationScale * sample.TimeSeconds / 2d;
            var expectedA = expectedRootA * expectedRootA;
            var expectedB = initialA - expectedA;

            Assert.InRange(Math.Abs(sample.AmountsMol["A"] - expectedA), 0d, 3e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol["B"] - expectedB), 0d, 3e-9);
            Assert.InRange(Math.Abs(sample.AmountsMol.Values.Sum() - initialA), 0d, 2e-10);
            Assert.All(sample.AmountsMol.Values, amount => Assert.True(amount >= 0d));
        }
    }
    [Fact]
    public void OutputSamplingInterval_DoesNotResetAdaptiveStepController()
    {
        const double rateConstant = 0.2d;
        const double endTime = 10d;

        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(rateConstant, 0d))
            ],
            [
                new ConservationLaw("total", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 1d
                })
            ]);

        SimulationResult Run(double outputInterval) => new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = endTime,
            OutputIntervalSeconds = outputInterval,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-8,
                AbsoluteToleranceMol = 1e-11,
                InitialStepSeconds = 1e-3,
                MinimumStepSeconds = 1e-12,
                MaximumStepSeconds = 1d
            }
        });

        var coarse = Run(1d);
        var fine = Run(0.125d);

        Assert.True(coarse.IsSuccess, coarse.Diagnostics.Message);
        Assert.True(fine.IsSuccess, fine.Diagnostics.Message);
        Assert.Equal(11, coarse.Samples.Count);
        Assert.Equal(81, fine.Samples.Count);

        // Both schedules represent the same trajectory at their shared output times.
        for (var i = 0; i < coarse.Samples.Count; i++)
        {
            var coarseSample = coarse.Samples[i];
            var fineSample = fine.Samples[i * 8];
            Assert.Equal(coarseSample.TimeSeconds, fineSample.TimeSeconds);
            Assert.InRange(Math.Abs(coarseSample.AmountsMol["A"] - fineSample.AmountsMol["A"]), 0d, 2e-8);
            Assert.InRange(Math.Abs(coarseSample.AmountsMol["A"] - Math.Exp(-rateConstant * coarseSample.TimeSeconds)), 0d, 2e-8);
        }

        // Fine sampling necessarily adds at least one accepted step per segment,
        // but it must not pay a fresh controller warm-up sequence at every boundary.
        Assert.True(
            fine.Diagnostics.AcceptedSteps <= coarse.Diagnostics.AcceptedSteps + fine.Samples.Count - 1 + 8,
            $"Fine sampling used {fine.Diagnostics.AcceptedSteps} accepted steps versus {coarse.Diagnostics.AcceptedSteps} for coarse sampling.");
        Assert.True(
            fine.Diagnostics.RightHandSideEvaluations <= coarse.Diagnostics.RightHandSideEvaluations +
            (fine.Samples.Count - 1) * 7 + 56,
            "Fine sampling incurred repeated RHS warm-up work beyond its additional output segments.");
    }

    [Fact]
    public void MaximumInternalSteps_IsSharedAcrossOutputIntervals()
    {
        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(0.1d, 0d))
            ],
            [
                new ConservationLaw("total", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 1d
                })
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = 0.2d,
            OutputIntervalSeconds = 0.1d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-6,
                AbsoluteToleranceMol = 1e-12,
                InitialStepSeconds = 0.1d,
                MinimumStepSeconds = 1e-12,
                MaximumStepSeconds = 0.1d,
                MaximumInternalSteps = 1
            }
        });

        Assert.Equal(SimulationStatus.MaximumStepsExceeded, result.Status);
        Assert.Equal(1, result.Diagnostics.AcceptedSteps + result.Diagnostics.RejectedSteps);
        Assert.Equal(1, result.Diagnostics.AcceptedSteps);
        Assert.Equal(0, result.Diagnostics.RejectedSteps);

        // The first output interval completed and is published. The second one
        // cannot start because the single simulation-wide step budget is spent.
        Assert.Equal(2, result.Samples.Count);
        Assert.Equal(0d, result.Samples[0].TimeSeconds);
        Assert.Equal(0.1d, result.Samples[1].TimeSeconds);
        Assert.InRange(Math.Abs(result.Samples[1].AmountsMol["A"] - Math.Exp(-0.01d)), 0d, 2e-8);
        Assert.InRange(Math.Abs(result.Samples[1].AmountsMol.Values.Sum() - 1d), 0d, 2e-10);
    }

    [Fact]
    public void MaximumInternalSteps_CountsRejectedTrialsAgainstGlobalBudget()
    {
        var network = new ReactionNetwork(
            ["A", "B"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(10d, 0d))
            ],
            [
                new ConservationLaw("total", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 1d
                })
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = 0.1d,
            OutputIntervalSeconds = 0.1d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-14,
                AbsoluteToleranceMol = 1e-15,
                InitialStepSeconds = 0.1d,
                MinimumStepSeconds = 1e-12,
                MaximumStepSeconds = 0.1d,
                MaximumInternalSteps = 1
            }
        });

        Assert.Equal(SimulationStatus.MaximumStepsExceeded, result.Status);
        Assert.Equal(0, result.Diagnostics.AcceptedSteps);
        Assert.Equal(1, result.Diagnostics.RejectedSteps);
        Assert.Equal(1, result.Diagnostics.AcceptedSteps + result.Diagnostics.RejectedSteps);
        Assert.Equal(7, result.Diagnostics.RightHandSideEvaluations);
        Assert.Single(result.Samples);
        Assert.Equal(0d, result.Samples[0].TimeSeconds);
        Assert.Equal(1d, result.Samples[0].AmountsMol["A"]);
        Assert.Equal(0d, result.Samples[0].AmountsMol["B"]);
    }

}

    [Fact]
    public void ReactionNetwork_RejectsUnknownSpeciesReferencedOnlyByKineticOrder()
    {
        var reaction = new ReactionDefinition(
            "A-to-B-with-unknown-catalyst",
            new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
            new Dictionary<string, double> { ["A"] = 1d, ["X"] = 1d },
            new RateConstant(1d, -1d));

        var exception = Assert.Throws<ArgumentException>(() =>
            new ReactionNetwork(["A", "B"], [reaction]));

        Assert.Contains("unknown species 'X'", exception.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void DeclaredCatalystMayAffectKineticRateWithoutStoichiometricTerm()
    {
        const double rateConstant = 0.25d;
        const double catalystAmount = 2d;
        const double endTime = 3d;

        var network = new ReactionNetwork(
            ["A", "B", "Cat"],
            [
                new ReactionDefinition(
                    "A-to-B-catalysed",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d, ["Cat"] = 1d },
                    new RateConstant(rateConstant, -1d))
            ],
            [
                new ConservationLaw("A-fragment", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 1d
                })
            ]);

        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double>
            {
                ["A"] = 1d, ["B"] = 0d, ["Cat"] = catalystAmount
            },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = endTime,
            OutputIntervalSeconds = 0.1d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-9,
                AbsoluteToleranceMol = 1e-12
            }
        });

        Assert.True(result.IsSuccess, result.Diagnostics.Message);
        var expectedA = Math.Exp(-rateConstant * catalystAmount * endTime);
        var final = result.Samples[^1].AmountsMol;
        Assert.InRange(Math.Abs(final["A"] - expectedA), 0d, 3e-9);
        Assert.InRange(Math.Abs(final["A"] + final["B"] - 1d), 0d, 2e-10);
        Assert.Equal(catalystAmount, final["Cat"]);
    }
