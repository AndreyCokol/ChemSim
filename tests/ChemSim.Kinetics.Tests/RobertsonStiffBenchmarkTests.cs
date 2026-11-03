using ChemSim.Kinetics.Domain;
using ChemSim.Kinetics.Simulation;

namespace ChemSim.Kinetics.Tests;

public sealed class RobertsonStiffBenchmarkTests
{
    private readonly Xunit.Abstractions.ITestOutputHelper _output;

    public RobertsonStiffBenchmarkTests(Xunit.Abstractions.ITestOutputHelper output) => _output = output;

    [Fact]
    public void RobertsonStiffSystem_ReportsExplicitSolverFeasibilityAgainstProvisionalReference()
    {
        // Terminal values at 1e6 s from the checked-in SciPy 1.17.0
        // Radau/BDF cross-check. This is provisional computational reference
        // data, not an authoritative published trajectory.
        const double referenceA = 0.002031483925;
        const double referenceB = 8.14227778e-9;
        const double referenceC = 0.9979685079327;
        const double referenceToleranceMol = 2e-7;

        var network = new ReactionNetwork(
            ["A", "B", "C"],
            [
                new ReactionDefinition(
                    "A-to-B",
                    new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                    new Dictionary<string, double> { ["A"] = 1d },
                    new RateConstant(0.04d, 0d)),
                new ReactionDefinition(
                    "B-plus-C-to-A-plus-C",
                    new Dictionary<string, int> { ["B"] = -1, ["A"] = 1 },
                    new Dictionary<string, double> { ["B"] = 1d, ["C"] = 1d },
                    new RateConstant(1e4d, -1d)),
                new ReactionDefinition(
                    "2B-to-B-plus-C",
                    new Dictionary<string, int> { ["B"] = -1, ["C"] = 1 },
                    new Dictionary<string, double> { ["B"] = 2d },
                    new RateConstant(3e7d, -1d))
            ],
            [
                new ConservationLaw("total", new Dictionary<string, double>
                {
                    ["A"] = 1d, ["B"] = 1d, ["C"] = 1d
                })
            ]);

        const int stepBudget = 50_000;
        var result = new KineticsSimulator().Run(new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double>
            {
                ["A"] = 1d, ["B"] = 0d, ["C"] = 0d
            },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = 1e6d,
            OutputIntervalSeconds = 1e6d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-7d,
                AbsoluteToleranceMol = 1e-12d,
                InitialStepSeconds = 1e-8d,
                MinimumStepSeconds = 1e-14d,
                MaximumStepSeconds = 1e5d,
                MaximumInternalSteps = stepBudget
            }
        });

        _output.WriteLine($"Robertson RK45: status={result.Status}; accepted={result.Diagnostics.AcceptedSteps}; rejected={result.Diagnostics.RejectedSteps}; rhs={result.Diagnostics.RightHandSideEvaluations}; message={result.Diagnostics.Message}");

        Assert.InRange(result.Diagnostics.AcceptedSteps, 0, stepBudget);
        Assert.InRange(result.Diagnostics.RejectedSteps, 0, stepBudget);
        Assert.True(result.Diagnostics.RightHandSideEvaluations >= 0);

        // A budget exhaustion is a valid diagnostic outcome for this explicit
        // method. Do not relax accuracy or silently turn it into a pass.
        Assert.True(
            result.Status is SimulationStatus.Success or SimulationStatus.MaximumStepsExceeded,
            $"Unexpected Robertson solver status {result.Status}: {result.Diagnostics.Message}");

        if (!result.IsSuccess)
        {
            Assert.Equal(SimulationStatus.MaximumStepsExceeded, result.Status);
            Assert.Equal(stepBudget, result.Diagnostics.AcceptedSteps + result.Diagnostics.RejectedSteps);
            Assert.True(
                result.Diagnostics.RightHandSideEvaluations > 0,
                "A budget-exhausted integration should report its RHS work.");
            return;
        }

        Assert.Equal(2, result.Samples.Count);
        var final = result.Samples[^1];
        Assert.Equal(1e6d, final.TimeSeconds);

        var a = final.AmountsMol["A"];
        var b = final.AmountsMol["B"];
        var c = final.AmountsMol["C"];
        Assert.InRange(a, 0d, 1d);
        Assert.InRange(b, 0d, 1d);
        Assert.InRange(c, 0d, 1d);
        Assert.InRange(Math.Abs(a - referenceA), 0d, referenceToleranceMol);
        Assert.InRange(Math.Abs(b - referenceB), 0d, referenceToleranceMol);
        Assert.InRange(Math.Abs(c - referenceC), 0d, referenceToleranceMol);
        Assert.InRange(Math.Abs(a + b + c - 1d), 0d, 5e-9d);
    }
}
