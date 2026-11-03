using ChemSim.Kinetics.Domain;
using ChemSim.Kinetics.Simulation;

namespace ChemSim.Kinetics.Tests;

public sealed class StiffBenchmarkTests
{
    [Fact]
    public void SeparatedFirstOrderTimeScales_MatchesAnalyticalProfileAndReportsWork()
    {
        const double fastRate = 1e6d;
        const double slowRate = 1d;

        var network = new ReactionNetwork(
            ["A", "B", "C"],
            [
                new ReactionDefinition(
                    "fast-A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(fastRate, 0d)),
                new ReactionDefinition(
                    "slow-B-to-C",
                    new Dictionary<string, int> { ["B"] = -1, ["C"] = 1 },
                    new Dictionary<string, double> { ["B"] = 1d },
                    new RateConstant(slowRate, 0d))
            ],
            [
                new ConservationLaw("total", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 1d, ["C"] = 1d
                })
            ]);

        SimulationResult Run(double endTime, double outputInterval) =>
            new KineticsSimulator().Run(new SimulationRequest
            {
                Network = network,
                InitialAmountsMol = new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 0d, ["C"] = 0d
                },
                VolumeM3 = 1d,
                StartTimeSeconds = 0d,
                EndTimeSeconds = endTime,
                OutputIntervalSeconds = outputInterval,
                Solver = new SolverOptions
                {
                    RelativeTolerance = 1e-7d,
                    AbsoluteToleranceMol = 1e-13d,
                    InitialStepSeconds = 1e-9d,
                    MinimumStepSeconds = 1e-14d,
                    MaximumStepSeconds = 0.1d,
                    MaximumInternalSteps = 100_000
                }
            });

        // Resolve the fast initial layer explicitly, then inspect the slow tail
        // on a practical horizon without requiring a uniform microsecond grid.
        var fastWindow = Run(endTime: 1e-5d, outputInterval: 1e-6d);
        var slowWindow = Run(endTime: 5d, outputInterval: 0.5d);

        Assert.True(fastWindow.IsSuccess, fastWindow.Diagnostics.Message);
        Assert.True(slowWindow.IsSuccess, slowWindow.Diagnostics.Message);
        Assert.Equal(11, fastWindow.Samples.Count);
        Assert.Equal(11, slowWindow.Samples.Count);

        AssertAnalyticalProfile(fastWindow.Samples, fastRate, slowRate, 5e-7d);
        AssertAnalyticalProfile(slowWindow.Samples, fastRate, slowRate, 5e-7d);

        Assert.True(fastWindow.Diagnostics.AcceptedSteps > 0);
        Assert.True(fastWindow.Diagnostics.RightHandSideEvaluations >= 7);
        Assert.True(slowWindow.Diagnostics.AcceptedSteps > 0);
        Assert.True(slowWindow.Diagnostics.RightHandSideEvaluations >= 7);
    }

    private static void AssertAnalyticalProfile(
        IReadOnlyList<StateSample> samples,
        double fastRate,
        double slowRate,
        double absoluteTolerance)
    {
        foreach (var sample in samples)
        {
            var time = sample.TimeSeconds;
            var expectedA = Math.Exp(-fastRate * time);
            var expectedB = fastRate / (fastRate - slowRate) *
                            (Math.Exp(-slowRate * time) - expectedA);
            var expectedC = 1d - expectedA - expectedB;

            var actualA = sample.AmountsMol["A"];
            var actualB = sample.AmountsMol["B"];
            var actualC = sample.AmountsMol["C"];

            Assert.InRange(actualA, 0d, 1d);
            Assert.InRange(actualB, 0d, 1d);
            Assert.InRange(actualC, 0d, 1d);
            Assert.InRange(Math.Abs(actualA - expectedA), 0d, absoluteTolerance);
            Assert.InRange(Math.Abs(actualB - expectedB), 0d, absoluteTolerance);
            Assert.InRange(Math.Abs(actualC - expectedC), 0d, absoluteTolerance);
            Assert.InRange(Math.Abs(actualA + actualB + actualC - 1d), 0d, 5e-10d);
        }
    }
}
