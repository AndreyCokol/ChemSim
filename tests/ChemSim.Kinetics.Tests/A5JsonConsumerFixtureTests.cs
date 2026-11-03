using System.Text.Json;
using ChemSim.Kinetics.Domain;
using ChemSim.Kinetics.Simulation;

namespace ChemSim.Kinetics.Tests;

/// <summary>
/// Generates honest A4 numerical output in A5's public GraphSeries shape.
/// Tests the producer in .NET; a separate CI job tests A5's unchanged
/// Godot GraphSeries validator using the generated JSON bytes.
/// </summary>
public sealed class A5JsonConsumerFixtureTests
{
    private const string N2O4 = "hypothetical:N2O4:g";
    private const string NO2 = "hypothetical:NO2:g";

    [Fact]
    public void ActualSolverProjection_CanBeSerializedForExternalA5Consumer()
    {
        var completedRequest = Request(maxSteps: 10_000);
        var complete = new KineticsSimulator().Run(completedRequest);
        Assert.Equal(SimulationStatus.Success, complete.Status);

        var fullSeries = Project(completedRequest, complete, "a4-cross-consumer-complete");
        Assert.Equal(2, fullSeries.Count);
        Assert.All(fullSeries, series =>
        {
            Assert.Equal("concentration", series.QuantityKey);
            Assert.Equal("mol/m3", series.UnitId);
            Assert.Equal(3, series.Samples.Count);
            Assert.All(series.Samples, s => Assert.Equal("valid", s.ValueStatus));
        });

        foreach (var series in fullSeries)
        {
            var a = series.SpeciesRef.Id == N2O4;
            for (var i = 0; i < series.Samples.Count; i++)
            {
                var t = series.Samples[i].TimeSeconds;
                var expected = a ? Math.Exp(-0.1d * t) : 2d * (1d - Math.Exp(-0.1d * t));
                Assert.InRange(Math.Abs(series.Samples[i].Value!.Value - expected), 0d, 1e-7d);
            }
        }

        var stoppedRequest = Request(maxSteps: 1);
        var stopped = new KineticsSimulator().Run(stoppedRequest);
        Assert.Equal(SimulationStatus.MaximumStepsExceeded, stopped.Status);
        var prefixSeries = Project(stoppedRequest, stopped, "a4-cross-consumer-step-limit");
        Assert.All(prefixSeries, series =>
        {
            Assert.Equal("missing", series.Samples[^1].ValueStatus);
            Assert.Null(series.Samples[^1].Value);
            Assert.Equal(1d, series.Samples[^1].TimeSeconds);
        });

        var completeJson = Serialize("completed", "complete_for_declared_scope", fullSeries);
        var partialJson = Serialize("step_limit", "partial", prefixSeries);

        using (var parsed = JsonDocument.Parse(completeJson))
        {
            Assert.Equal(2, parsed.RootElement.GetProperty("series").GetArrayLength());
            Assert.Equal("hypothetical",
                parsed.RootElement.GetProperty("data_quality").GetString());
        }
        using (var parsed = JsonDocument.Parse(partialJson))
        {
            foreach (var series in parsed.RootElement.GetProperty("series").EnumerateArray())
            {
                var last = series.GetProperty("samples")[series.GetProperty("samples").GetArrayLength() - 1];
                Assert.False(last.TryGetProperty("value", out _));
            }
        }

        // Test-only exporter: never creates a production wire envelope or
        // fabricates a result identity inside the runtime/CLI code.
        var directory = Environment.GetEnvironmentVariable("A4_GRAPH_FIXTURE_DIRECTORY");
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
            File.WriteAllText(Path.Combine(directory, "complete.json"), completeJson);
            File.WriteAllText(Path.Combine(directory, "partial.json"), partialJson);
        }
    }

    private static string Serialize(string outcome, string completeness,
        IReadOnlyList<ConcentrationGraphSeries> projected) =>
        JsonSerializer.Serialize(new
        {
            contract_version = "0.1",
            test_only = true,
            data_quality = "hypothetical",
            model_applicability = "not_assessed",
            outcome,
            completeness,
            series = projected
        });

    private static IReadOnlyList<ConcentrationGraphSeries> Project(
        SimulationRequest request, SimulationResult result, string runId)
    {
        var species = request.Network.SpeciesIds;
        var refs = species.ToDictionary(id => id,
            id => new GraphReference(id, 1), StringComparer.Ordinal);
        var ids = species.ToDictionary(id => id,
            id => runId + ":" + id, StringComparer.Ordinal);
        return SolverGraphProjection.ProjectConcentrations(
            request, result, new GraphReference(runId, 1), refs, ids);
    }

    private static SimulationRequest Request(int maxSteps)
    {
        var network = new ReactionNetwork(
            [N2O4, NO2],
            [new ReactionDefinition(
                "hypothetical:N2O4-to-2NO2",
                new Dictionary<string, int> { [N2O4] = -1, [NO2] = 2 },
                new Dictionary<string, double> { [N2O4] = 1d },
                new RateConstant(0.1d, 0d))],
            [
                new ConservationLaw("N",
                    new Dictionary<string, double> { [N2O4] = 2d, [NO2] = 1d }),
                new ConservationLaw("O",
                    new Dictionary<string, double> { [N2O4] = 4d, [NO2] = 2d })
            ]);

        return new SimulationRequest
        {
            Network = network,
            InitialAmountsMol = new Dictionary<string, double>
            {
                [N2O4] = 1d,
                [NO2] = 0d
            },
            VolumeM3 = 1d,
            StartTimeSeconds = 0d,
            EndTimeSeconds = 1d,
            OutputIntervalSeconds = 0.5d,
            Solver = new SolverOptions
            {
                RelativeTolerance = 1e-6d,
                AbsoluteToleranceMol = 1e-12d,
                InitialStepSeconds = 0.05d,
                MinimumStepSeconds = 1e-12d,
                MaximumStepSeconds = 0.1d,
                MaximumInternalSteps = maxSteps
            }
        };
    }
}
