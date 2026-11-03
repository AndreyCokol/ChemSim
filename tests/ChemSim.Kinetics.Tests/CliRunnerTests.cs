using System.Text.Json;
using ChemSim.Kinetics.Cli;

namespace ChemSim.Kinetics.Tests;

public sealed class CliRunnerTests
{
    // Explicitly hypothetical A->B is a numerical/transport fixture, not a
    // chemical equation or scientific rate-constant provenance claim.
    private const string ValidRequest = """
        {
          "contract_version":"0.1",
          "message_id":"a393bcc5-8ef0-4111-9cf8-a7f4a65fbfc6",
          "kind":"simulation_request",
          "errors":[],
          "payload":{
            "model_kind":"closed_isothermal_irreversible",
            "data_quality":"hypothetical",
            "species":[
              {"species_ref":{"id":"A","record_revision":1},"initial_amount":{"value":1,"unit_id":"mol"}},
              {"species_ref":{"id":"B","record_revision":1},"initial_amount":{"value":0,"unit_id":"mol"}}
            ],
            "reactions":[{
              "reaction_ref":{"id":"A-to-B","record_revision":1},
              "arrow_type":"forward",
              "rate_law_id":"irreversible_volumetric_power_law",
              "stoichiometry":[
                {"species_ref":{"id":"A","record_revision":1},"coefficient":-1},
                {"species_ref":{"id":"B","record_revision":1},"coefficient":1}
              ],
              "kinetic_orders":[
                {"species_ref":{"id":"A","record_revision":1},"order":1}
              ],
              "rate_constant":{"value":0.1,"unit_id":"derived",
                "basis":"volumetric_power_law",
                "dimension_exponents":{"mol":0,"m":0,"s":-1}},
              "parameter_temperature":{"value":298.15,"unit_id":"K"}
            }],
            "conservation_laws":[{
              "id":"synthetic-total",
              "coefficients":[
                {"species_ref":{"id":"A","record_revision":1},"coefficient":1},
                {"species_ref":{"id":"B","record_revision":1},"coefficient":1}
              ]
            }],
            "volume":{"value":1,"unit_id":"m3"},
            "temperature":{"value":298.15,"unit_id":"K"},
            "time_start":{"value":0,"unit_id":"s"},
            "time_end":{"value":1,"unit_id":"s"},
            "output_interval":{"value":0.5,"unit_id":"s"},
            "solver_policy":{
              "relative_tolerance":0.000001,
              "absolute_tolerance":{"value":1e-12,"unit_id":"mol"},
              "initial_step":{"value":0.05,"unit_id":"s"},
              "minimum_step":{"value":1e-12,"unit_id":"s"},
              "maximum_step":{"value":0.1,"unit_id":"s"},
              "maximum_internal_steps":10000
            }
          }
        }
        """;

    [Fact]
    public void ValidHypotheticalRequest_EmitsCorrelatedCompletedTimeSeries()
    {
        using var result = Run(ValidRequest);
        Assert.Equal(0, result.ExitCode);
        Assert.True(File.Exists(result.OutputPath), result.Stderr);
        using var json = JsonDocument.Parse(File.ReadAllText(result.OutputPath));
        var response = json.RootElement;

        Assert.Equal("0.1", response.GetProperty("contract_version").GetString());
        Assert.Equal("simulation_result", response.GetProperty("kind").GetString());
        Assert.Equal("a393bcc5-8ef0-4111-9cf8-a7f4a65fbfc6",
            response.GetProperty("request_message_id").GetString());
        Assert.Equal("completed", response.GetProperty("outcome").GetString());
        Assert.Equal(0, response.GetProperty("errors").GetArrayLength());

        var payload = response.GetProperty("payload");
        Assert.Equal("hypothetical", payload.GetProperty("reliability").GetProperty("data_quality").GetString());
        Assert.Equal("not_assessed", payload.GetProperty("reliability").GetProperty("model_applicability").GetString());
        Assert.Equal("complete_for_declared_scope", payload.GetProperty("reliability").GetProperty("completeness").GetString());
        var samples = payload.GetProperty("samples");
        Assert.Equal(3, samples.GetArrayLength());
        var last = samples[2];
        Assert.Equal(1d, last.GetProperty("time_s").GetDouble());
        var amounts = last.GetProperty("amounts_mol");
        var a = amounts.GetProperty("A").GetDouble();
        var b = amounts.GetProperty("B").GetDouble();
        Assert.InRange(Math.Abs(a - Math.Exp(-0.1d)), 0d, 5e-8);
        Assert.InRange(Math.Abs(a + b - 1d), 0d, 1e-9);
        Assert.Equal(1d, payload.GetProperty("last_valid_time_s").GetDouble());
    }

    [Theory]
    [InlineData("\"value\":0.1", "\"value\":0", "blocked")]
    [InlineData("\"mol\":0", "\"mol\":1", "blocked")]
    [InlineData("\"arrow_type\":\"forward\"", "\"arrow_type\":\"equilibrium\"", "blocked")]
    [InlineData("\"data_quality\":\"hypothetical\"", "\"data_quality\":\"verified\"", "blocked")]
    [InlineData("\"parameter_temperature\":{\"value\":298.15", "\"parameter_temperature\":{\"value\":300", "blocked")]
    [InlineData("\"unit_id\":\"m3\"", "\"unit_id\":\"L\"", "blocked")]
    [InlineData("\"order\":1", "\"order\":-1", "blocked")]
    [InlineData("\"record_revision\":1", "\"record_revision\":0", "blocked")]
    public void InvalidScientificAdmission_ReturnsBlockedWithoutSamples(
        string original, string changed, string expected)
    {
        var input = ValidRequest.Replace(original, changed, StringComparison.Ordinal);
        Assert.NotEqual(ValidRequest, input);
        using var result = Run(input);
        Assert.Equal(0, result.ExitCode);
        using var json = JsonDocument.Parse(File.ReadAllText(result.OutputPath));
        Assert.Equal(expected, json.RootElement.GetProperty("outcome").GetString());
        var payload = json.RootElement.GetProperty("payload");
        Assert.Equal(0, payload.GetProperty("samples").GetArrayLength());
        Assert.Equal("absent", payload.GetProperty("reliability").GetProperty("completeness").GetString());
        Assert.Equal("KINETICS_INVALID_INPUT",
            json.RootElement.GetProperty("errors")[0].GetProperty("code").GetString());
    }

    [Fact]
    public void StepBudgetFailure_PublishesOnlyValidatedPrefixAndRealCause()
    {
        var input = ValidRequest.Replace("\"maximum_internal_steps\":10000",
            "\"maximum_internal_steps\":1", StringComparison.Ordinal);
        using var result = Run(input);
        Assert.Equal(0, result.ExitCode);
        using var json = JsonDocument.Parse(File.ReadAllText(result.OutputPath));
        Assert.Equal("step_limit", json.RootElement.GetProperty("outcome").GetString());
        var payload = json.RootElement.GetProperty("payload");
        var samples = payload.GetProperty("samples");
        Assert.Single(samples.EnumerateArray());
        Assert.Equal(0d, samples[0].GetProperty("time_s").GetDouble());
        Assert.Equal("partial", payload.GetProperty("reliability").GetProperty("completeness").GetString());
        Assert.Equal(0d, payload.GetProperty("last_valid_time_s").GetDouble());
        Assert.Equal(1d, payload.GetProperty("requested_end_s").GetDouble());
    }

    [Fact]
    public void UnsupportedEnvelopeVersion_IsRefusedWithoutWritingResponse()
    {
        var input = ValidRequest.Replace("\"contract_version\":\"0.1\"",
            "\"contract_version\":\"2.0\"", StringComparison.Ordinal);
        using var result = Run(input);
        Assert.Equal(2, result.ExitCode);
        Assert.False(File.Exists(result.OutputPath));
    }

    [Fact]
    public void InvalidEnvelopeId_IsRefusedWithoutWritingResponse()
    {
        var input = ValidRequest.Replace("a393bcc5-8ef0-4111-9cf8-a7f4a65fbfc6",
            "not-a-uuid", StringComparison.Ordinal);
        using var result = Run(input);
        Assert.Equal(2, result.ExitCode);
        Assert.False(File.Exists(result.OutputPath));
    }

    [Theory]
    [InlineData(1_048_576, true)]
    [InlineData(1_048_577, false)]
    [InlineData(1_048_576 + 8192, false)]
    public void InputByteLimit_IsEnforcedAtBoundary_WithoutWritingOversizedResponse(
        int requestedBytes, bool shouldAccept)
    {
        var sourceBytes = System.Text.Encoding.UTF8.GetByteCount(ValidRequest);
        Assert.True(sourceBytes < 1_048_576);

        // JSON permits trailing whitespace. Keep the scientific request and
        // its rate law unchanged, vary ONLY the exact encoded file length.
        var input = ValidRequest + new string(' ', requestedBytes - sourceBytes);
        Assert.Equal(requestedBytes, System.Text.Encoding.UTF8.GetByteCount(input));
        using var run = Run(input);
        Assert.Equal(shouldAccept ? 0 : 2, run.ExitCode);

        if (shouldAccept)
        {
            using var document = JsonDocument.Parse(File.ReadAllText(run.OutputPath));
            Assert.Equal("completed", document.RootElement.GetProperty("outcome").GetString());
        }
        else
        {
            Assert.False(File.Exists(run.OutputPath));
            Assert.Contains("size limit", run.Stderr, StringComparison.Ordinal);
        }
    }

    [Theory]
    [InlineData("")]
    [InlineData("{")]
    [InlineData("{\"contract_version\":\"0.1\",")]
    public void InvalidOrTruncatedJson_IsRejectedWithoutCreatingResponse(string input)
    {
        using var run = Run(input);
        Assert.Equal(2, run.ExitCode);
        Assert.False(File.Exists(run.OutputPath));
    }

    [Fact]
    public void ExistingResponseFile_IsNotOverwritten()
    {
        using var run = new Workspace(ValidRequest);
        File.WriteAllText(run.OutputPath, "EXISTING");
        using var stderr = new StringWriter();
        Assert.Equal(2, CliRunner.Execute(run.Arguments, stderr));
        Assert.Equal("EXISTING", File.ReadAllText(run.OutputPath));
    }

    [Fact]
    public void TooManyOutputSamples_AreRejectedBeforeNumericalWork()
    {
        var input = ValidRequest.Replace("\"output_interval\":{\"value\":0.5",
            "\"output_interval\":{\"value\":0.000001", StringComparison.Ordinal);
        using var result = Run(input);
        Assert.Equal(0, result.ExitCode);
        using var json = JsonDocument.Parse(File.ReadAllText(result.OutputPath));
        Assert.Equal("blocked", json.RootElement.GetProperty("outcome").GetString());
        Assert.Equal(0, json.RootElement.GetProperty("payload").GetProperty("samples").GetArrayLength());
    }

    private static Execution Run(string input)
    {
        var folder = new Workspace(input);
        using var stderr = new StringWriter();
        var exit = CliRunner.Execute(folder.Arguments, stderr);
        return new Execution(folder, exit, stderr.ToString());
    }

    private sealed class Execution(Workspace workspace, int exitCode, string stderr) : IDisposable
    {
        public int ExitCode => exitCode;
        public string Stderr => stderr;
        public string OutputPath => workspace.OutputPath;
        public void Dispose() => workspace.Dispose();
    }

    private sealed class Workspace : IDisposable
    {
        private readonly string _directory = Path.Combine(Path.GetTempPath(),
            "chemsim-a4-cli-tests-" + Guid.NewGuid().ToString("N"));
        public string OutputPath => Path.Combine(_directory, "response.json");
        public string[] Arguments => ["--request", Path.Combine(_directory, "request.json"),
            "--response", OutputPath];

        public Workspace(string input)
        {
            Directory.CreateDirectory(_directory);
            File.WriteAllText(Arguments[1], input);
        }

        public void Dispose() => Directory.Delete(_directory, recursive: true);
    }
}
