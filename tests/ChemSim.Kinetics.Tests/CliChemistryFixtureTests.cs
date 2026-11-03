using System.Text.Json;
using System.Text.Json.Nodes;
using ChemSim.Kinetics.Cli;

namespace ChemSim.Kinetics.Tests;

/// <summary>
/// A2-parseable stoichiometry, but intentionally hypothetical k; this file
/// does NOT call A2's Godot parser or assert physical gas kinetics.
/// </summary>
public sealed class CliChemistryFixtureTests
{
    private const string A = "hypothetical:N2O4:g";
    private const string B = "hypothetical:NO2:g";
    private const string RequestId = "2c08b3c5-12cd-4a30-b4bf-f604975c372f";

    private static string FixtureText() => File.ReadAllText(Path.Combine(
        AppContext.BaseDirectory, "Fixtures", "a4-n2o4-no2-hypothetical-request.json"));

    [Fact]
    public void ChemicallyBalancedGasFormula_SyntheticKinetics_MatchesAnalyticProfileAndElementTotals()
    {
        Check(FixtureText(), root =>
        {
            Assert.Equal("0.1", root.GetProperty("contract_version").GetString());
            Assert.Equal("simulation_result", root.GetProperty("kind").GetString());
            Assert.Equal(RequestId, root.GetProperty("request_message_id").GetString());
            Assert.Equal("completed", root.GetProperty("outcome").GetString());
            Assert.Empty(root.GetProperty("errors").EnumerateArray());

            var payload = root.GetProperty("payload");
            var reliability = payload.GetProperty("reliability");
            Assert.Equal("hypothetical", reliability.GetProperty("data_quality").GetString());
            Assert.Equal("not_assessed", reliability.GetProperty("model_applicability").GetString());
            Assert.Equal("complete_for_declared_scope", reliability.GetProperty("completeness").GetString());
            Assert.Equal(1d, payload.GetProperty("last_valid_time_s").GetDouble());
            var samples = payload.GetProperty("samples");
            Assert.Equal(3, samples.GetArrayLength());

            for (var i = 0; i < samples.GetArrayLength(); i++)
            {
                var sample = samples[i];
                var time = sample.GetProperty("time_s").GetDouble();
                var values = sample.GetProperty("amounts_mol");
                var n2o4 = values.GetProperty(A).GetDouble();
                var no2 = values.GetProperty(B).GetDouble();

                Assert.Equal(i * 0.5d, time);
                Assert.Equal(2, values.EnumerateObject().Count());
                Assert.True(double.IsFinite(n2o4) && n2o4 >= 0d);
                Assert.True(double.IsFinite(no2) && no2 >= 0d);
                Assert.InRange(Math.Abs(n2o4 - Math.Exp(-0.1d * time)), 0d, 5e-8);
                Assert.InRange(Math.Abs(no2 - 2d * (1d - Math.Exp(-0.1d * time))), 0d, 1e-7);
                // N2O4 has 2 N and 4 O atoms; NO2 has 1 N and 2 O.
                Assert.InRange(Math.Abs(2d * n2o4 + no2 - 2d), 0d, 1e-9);
                Assert.InRange(Math.Abs(4d * n2o4 + 2d * no2 - 4d), 0d, 2e-9);
            }
        });
    }

    [Fact]
    public void AtomImbalanceAgainstSuppliedNAndOLaws_IsBlockedBeforeSolver()
    {
        var root = JsonNode.Parse(FixtureText())!;
        // N2O4 -> NO2 is not balanced: source N/O-derived laws reject it.
        root["payload"]!["reactions"]![0]!["stoichiometry"]![1]!["coefficient"] = 1;
        CheckBlocked(root.ToJsonString());
    }

    [Fact]
    public void MissingIndependentKineticOrders_IsNotInferredFromStoichiometry()
    {
        var root = JsonNode.Parse(FixtureText())!;
        root["payload"]!["reactions"]![0]!.AsObject().Remove("kinetic_orders");
        CheckBlocked(root.ToJsonString());
    }

    [Fact]
    public void WrongSpeciesRevision_IsNotSilentlyResolved()
    {
        var root = JsonNode.Parse(FixtureText())!;
        root["payload"]!["reactions"]![0]!["stoichiometry"]![1]!["species_ref"]!["record_revision"] = 2;
        CheckBlocked(root.ToJsonString());
    }

    [Fact]
    public void ReversibleArrow_CannotBecomeIrreversibleKinetics()
    {
        var root = JsonNode.Parse(FixtureText())!;
        root["payload"]!["reactions"]![0]!["arrow_type"] = "equilibrium";
        CheckBlocked(root.ToJsonString());
    }

    private static void CheckBlocked(string input)
    {
        Check(input, root =>
        {
            Assert.Equal(RequestId, root.GetProperty("request_message_id").GetString());
            Assert.Equal("blocked", root.GetProperty("outcome").GetString());
            var payload = root.GetProperty("payload");
            Assert.Empty(payload.GetProperty("samples").EnumerateArray());
            Assert.Equal("absent", payload.GetProperty("reliability").GetProperty("completeness").GetString());
            Assert.Equal("hypothetical", payload.GetProperty("reliability").GetProperty("data_quality").GetString());
            Assert.Equal("KINETICS_INVALID_INPUT",
                root.GetProperty("errors")[0].GetProperty("code").GetString());
        });
    }

    private static void Check(string input, Action<JsonElement> check)
    {
        var folder = Path.Combine(Path.GetTempPath(), "a4-n2o4-cli-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(folder);
        try
        {
            var request = Path.Combine(folder, "request.json");
            var response = Path.Combine(folder, "response.json");
            File.WriteAllText(request, input);
            using var stderr = new StringWriter();
            var exit = CliRunner.Execute(["--request", request, "--response", response], stderr);
            Assert.Equal(0, exit);
            Assert.True(File.Exists(response), stderr.ToString());
            using var document = JsonDocument.Parse(File.ReadAllText(response));
            check(document.RootElement);
        }
        finally
        {
            Directory.Delete(folder, recursive: true);
        }
    }
}
