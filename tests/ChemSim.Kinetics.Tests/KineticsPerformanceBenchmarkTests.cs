using System.Diagnostics;
using System.Runtime.InteropServices;
using ChemSim.Kinetics.Domain;
using ChemSim.Kinetics.Simulation;
using Xunit.Abstractions;

namespace ChemSim.Kinetics.Tests;

public sealed class KineticsPerformanceBenchmarkTests
{
    private const int WarmupRuns = 2;
    private const int MeasurementRuns = 9;
    private readonly ITestOutputHelper _output;

    public KineticsPerformanceBenchmarkTests(ITestOutputHelper output) => _output = output;

    [Fact]
    public void RepresentativeNonStiffCases_ReportPerformanceAndSolverWorkWithoutTimingGate()
    {
        _output.WriteLine(
            $"Environment: {RuntimeInformation.FrameworkDescription}; OS={RuntimeInformation.OSDescription}; " +
            $"OSArch={RuntimeInformation.OSArchitecture}; ProcessArch={RuntimeInformation.ProcessArchitecture}; " +
            $"LogicalProcessors={Environment.ProcessorCount}; RuntimeVersion={Environment.Version}; " +
            $"CPU={Environment.GetEnvironmentVariable("PROCESSOR_IDENTIFIER") ?? "not exposed by runtime"}");
        _output.WriteLine($"Protocol: Release; warmups={WarmupRuns}; measurements={MeasurementRuns}; " +
                          "allocated bytes measured on current thread; no wall-clock pass/fail threshold.");

        foreach (var benchmarkCase in CreateCases())
        {
            for (var i = 0; i < WarmupRuns; i++)
            {
                var warmup = new KineticsSimulator().Run(benchmarkCase.Request);
                Assert.True(warmup.IsSuccess, warmup.Diagnostics.Message);
            }

            var elapsedMilliseconds = new double[MeasurementRuns];
            var allocatedBytes = new long[MeasurementRuns];
            SimulationResult? lastResult = null;

            for (var i = 0; i < MeasurementRuns; i++)
            {
                GC.Collect();
                GC.WaitForPendingFinalizers();
                GC.Collect();

                var allocatedBefore = GC.GetAllocatedBytesForCurrentThread();
                var started = Stopwatch.GetTimestamp();
                var result = new KineticsSimulator().Run(benchmarkCase.Request);
                elapsedMilliseconds[i] = Stopwatch.GetElapsedTime(started).TotalMilliseconds;
                allocatedBytes[i] = GC.GetAllocatedBytesForCurrentThread() - allocatedBefore;

                Assert.True(result.IsSuccess, result.Diagnostics.Message);
                lastResult = result;
            }

            Array.Sort(elapsedMilliseconds);
            Array.Sort(allocatedBytes);
            var medianMilliseconds = Median(elapsedMilliseconds);
            var medianAllocatedBytes = Median(allocatedBytes);
            var minimumMilliseconds = elapsedMilliseconds[0];
            var maximumMilliseconds = elapsedMilliseconds[^1];
            var diagnostics = lastResult!.Diagnostics;

            _output.WriteLine(
                $"{benchmarkCase.Name}: median={medianMilliseconds:F4} ms; " +
                $"range=[{minimumMilliseconds:F4}, {maximumMilliseconds:F4}] ms; " +
                $"medianAllocated={medianAllocatedBytes} B; " +
                $"accepted={diagnostics.AcceptedSteps}; rejected={diagnostics.RejectedSteps}; " +
                $"rhs={diagnostics.RightHandSideEvaluations}; status={lastResult.Status}");
        }
    }

    private static IReadOnlyList<BenchmarkCase> CreateCases() =>
    [
        new BenchmarkCase(
            "first-order-A-to-B",
            CreateRequest(
                ["A", "B"],
                [
                    new ReactionDefinition(
                        "A-to-B",
                        new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                        new Dictionary<string, double> { ["A"] = 1d },
                        new RateConstant(0.5d, 0d))
                ],
                new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
                [
                    new ConservationLaw("total", new Dictionary<string, double>
                    {
                        ["A"] = 1d, ["B"] = 1d
                    })
                ])),
        new BenchmarkCase(
            "first-order-output-interval-1s",
            CreateRequest(
                ["A", "B"],
                [
                    new ReactionDefinition(
                        "A-to-B",
                        new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                        new Dictionary<string, double> { ["A"] = 1d },
                        new RateConstant(0.5d, 0d))
                ],
                new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
                [
                    new ConservationLaw("total", new Dictionary<string, double>
                    {
                        ["A"] = 1d, ["B"] = 1d
                    })
                ],
                endTimeSeconds: 10d,
                outputIntervalSeconds: 1d)),
        new BenchmarkCase(
            "first-order-output-interval-0.125s",
            CreateRequest(
                ["A", "B"],
                [
                    new ReactionDefinition(
                        "A-to-B",
                        new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                        new Dictionary<string, double> { ["A"] = 1d },
                        new RateConstant(0.5d, 0d))
                ],
                new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d },
                [
                    new ConservationLaw("total", new Dictionary<string, double>
                    {
                        ["A"] = 1d, ["B"] = 1d
                    })
                ],
                endTimeSeconds: 10d,
                outputIntervalSeconds: 0.125d)),
        new BenchmarkCase(
            "second-order-2A-to-B",
            CreateRequest(
                ["A", "B"],
                [
                    new ReactionDefinition(
                        "2A-to-B",
                        new Dictionary<string, int> { ["A"] = -2, ["B"] = 1 },
                        new Dictionary<string, double> { ["A"] = 2d },
                        new RateConstant(0.1d, -1d))
                ],
                new Dictionary<string, double> { ["A"] = 2d, ["B"] = 0d },
                [
                    new ConservationLaw("A-fragment", new Dictionary<string, double>
                    {
                        ["A"] = 1d, ["B"] = 2d
                    })
                ])),
        new BenchmarkCase(
            "half-order-A-to-B-non-unit-volume",
            CreateRequest(
                ["A", "B"],
                [
                    new ReactionDefinition(
                        "half-order-A-to-B",
                        new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                        new Dictionary<string, double> { ["A"] = 0.5d },
                        new RateConstant(0.6d, 0.5d))
                ],
                new Dictionary<string, double> { ["A"] = 4d, ["B"] = 0d },
                [
                    new ConservationLaw("total", new Dictionary<string, double>
                    {
                        ["A"] = 1d, ["B"] = 1d
                    })
                ],
                volumeM3: 2d,
                endTimeSeconds: 2d)),
        new BenchmarkCase(
            "parallel-first-order-A-to-B-and-A-to-C",
            CreateRequest(
                ["A", "B", "C"],
                [
                    new ReactionDefinition(
                        "A-to-B",
                        new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                        new Dictionary<string, double> { ["A"] = 1d },
                        new RateConstant(0.7d, 0d)),
                    new ReactionDefinition(
                        "A-to-C",
                        new Dictionary<string, int> { ["A"] = -1, ["C"] = 1 },
                        new Dictionary<string, double> { ["A"] = 1d },
                        new RateConstant(0.3d, 0d))
                ],
                new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d, ["C"] = 0d },
                [
                    new ConservationLaw("total", new Dictionary<string, double>
                    {
                        ["A"] = 1d, ["B"] = 1d, ["C"] = 1d
                    })
                ])),
        new BenchmarkCase(
            "consecutive-first-order-A-to-B-to-C",
            CreateRequest(
                ["A", "B", "C"],
                [
                    new ReactionDefinition(
                        "A-to-B",
                        new Dictionary<string, int> { ["A"] = -1, ["B"] = 1 },
                        new Dictionary<string, double> { ["A"] = 1d },
                        new RateConstant(0.4d, 0d)),
                    new ReactionDefinition(
                        "B-to-C",
                        new Dictionary<string, int> { ["B"] = -1, ["C"] = 1 },
                        new Dictionary<string, double> { ["B"] = 1d },
                        new RateConstant(0.4d, 0d))
                ],
                new Dictionary<string, double> { ["A"] = 1d, ["B"] = 0d, ["C"] = 0d },
                [
                    new ConservationLaw("total", new Dictionary<string, double>
                    {
                        ["A"] = 1d, ["B"] = 1d, ["C"] = 1d
                    })
                ]))
    ];

    private static SimulationRequest CreateRequest(
        IReadOnlyList<string> species,
        IReadOnlyList<ReactionDefinition> reactions,
        IReadOnlyDictionary<string, double> initialAmounts,
        IReadOnlyList<ConservationLaw> conservationLaws,
        double volumeM3 = 1d,
        double endTimeSeconds = 10d,
        double? outputIntervalSeconds = null) =>
        new()
        {
            Network = new ReactionNetwork(species, reactions, conservationLaws),
            InitialAmountsMol = initialAmounts,
            VolumeM3 = volumeM3,
            StartTimeSeconds = 0d,
            EndTimeSeconds = endTimeSeconds,
            OutputIntervalSeconds = outputIntervalSeconds ?? endTimeSeconds,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-8d,
                AbsoluteToleranceMol = 1e-12d,
                InitialStepSeconds = 1e-3d,
                MinimumStepSeconds = 1e-12d,
                MaximumStepSeconds = endTimeSeconds
            }
        };

    private static long Median(IReadOnlyList<long> sortedValues) => sortedValues[sortedValues.Count / 2];

    private static double Median(IReadOnlyList<double> sortedValues) => sortedValues[sortedValues.Count / 2];

    private sealed record BenchmarkCase(string Name, SimulationRequest Request);
}
