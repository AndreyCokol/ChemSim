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

}
