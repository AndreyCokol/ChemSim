using System.Text.Json;
using ChemSim.Kinetics.Cli;
using ChemSim.Kinetics.Domain;
using ChemSim.Kinetics.Simulation;

return CliRunner.Execute(args, Console.Error);

namespace ChemSim.Kinetics.Cli
{
    /// <summary>
    /// Bounded, synthetic-only A4 engine adapter. Its payload shape is a narrow
    /// implementation slice of the approved v0.1 envelope, not a shared DTO freeze.
    /// Chemical parsing, provenance admission, and Godot process ownership stay upstream.
    /// </summary>
    public static class CliRunner
    {
        private const int MaximumRequestBytes = 1_048_576;
        private const int MaximumResponseBytes = 4_194_304;
        private const int MaximumSpecies = 32;
        private const int MaximumReactions = 64;
        private const int MaximumSamples = 1024;
        private const int MaximumInternalSteps = 250_000;

        public static int Execute(string[] args, TextWriter stderr)
        {
            ArgumentNullException.ThrowIfNull(args);
            ArgumentNullException.ThrowIfNull(stderr);

            if (args.Length != 4 || args[0] != "--request" || args[2] != "--response")
            {
                stderr.WriteLine("Usage: chemsim-solver --request <absolute-json-file> --response <absolute-json-file>");
                return 2;
            }

            try
            {
                var requestPath = args[1];
                var responsePath = args[3];
                if (!Path.IsPathFullyQualified(requestPath) || !Path.IsPathFullyQualified(responsePath))
                    throw new AdmissionException("Request and response paths must be absolute.");

                var inputFullPath = Path.GetFullPath(requestPath);
                var outputFullPath = Path.GetFullPath(responsePath);
                var pathComparison = OperatingSystem.IsWindows()
                    ? StringComparison.OrdinalIgnoreCase
                    : StringComparison.Ordinal;
                if (string.Equals(inputFullPath, outputFullPath, pathComparison) ||
                    !string.Equals(Path.GetDirectoryName(inputFullPath),
                        Path.GetDirectoryName(outputFullPath), pathComparison) ||
                    !string.Equals(Path.GetExtension(inputFullPath), ".json", StringComparison.OrdinalIgnoreCase) ||
                    !string.Equals(Path.GetExtension(outputFullPath), ".json", StringComparison.OrdinalIgnoreCase))
                    throw new AdmissionException("Request and response must be different JSON files in the same directory.");

                if (File.Exists(outputFullPath))
                    throw new AdmissionException("Refusing to overwrite an existing response.");

                // Read through one handle with a hard byte cap. FileInfo.Length
                // followed by File.ReadAllBytes had a TOCTOU window: a growing
                // request could allocate more than the advertised 1 MiB limit.
                using var document = JsonDocument.Parse(ReadBoundedRequest(inputFullPath),
                    new JsonDocumentOptions { MaxDepth = 32, AllowTrailingCommas = false, CommentHandling = JsonCommentHandling.Disallow });
                var root = document.RootElement;
                var requestId = ValidateEnvelope(root);
                object response;
                try
                {
                    var parsed = ParseProblem(Required(root, "payload"));
                    using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(20));
                    var result = new KineticsSimulator().Run(parsed.Request, cancellation.Token);
                    response = MakeResult(requestId, parsed, result);
                }
                catch (Exception exception) when (exception is AdmissionException or ArgumentException or OverflowException)
                {
                    response = MakeBlocked(requestId, exception.Message);
                }

                WriteResponse(outputFullPath, response);
                return 0;
            }
            catch (Exception exception) when (exception is AdmissionException or IOException or UnauthorizedAccessException
                or JsonException or ArgumentException or NotSupportedException)
            {
                stderr.WriteLine("A4 CLI refused request: " + exception.Message);
                return 2;
            }
        }

        private static byte[] ReadBoundedRequest(string path)
        {
            using var stream = new FileStream(path, FileMode.Open, FileAccess.Read,
                FileShare.Read, bufferSize: 8192, FileOptions.SequentialScan);
            if (stream.Length > MaximumRequestBytes)
                throw new AdmissionException("Request file exceeds the 1 MiB size limit.");

            using var content = new MemoryStream(
                capacity: (int)Math.Min(stream.Length, MaximumRequestBytes));
            var chunk = new byte[8192];
            while (true)
            {
                // Read one byte beyond the limit at most, even if the file
                // grows between Length inspection and the next stream.Read.
                var remaining = MaximumRequestBytes + 1 - (int)content.Length;
                if (remaining <= 0)
                    throw new AdmissionException("Request file exceeded the 1 MiB size limit.");
                var count = stream.Read(chunk, 0, Math.Min(chunk.Length, remaining));
                if (count == 0)
                    break;
                content.Write(chunk, 0, count);
                if (content.Length > MaximumRequestBytes)
                    throw new AdmissionException("Request file exceeded the 1 MiB size limit.");
            }
            return content.ToArray();
        }

        private static string ValidateEnvelope(JsonElement root)
        {
            Strict(root, "contract_version", "message_id", "kind", "payload", "errors");
            if (Text(root, "contract_version") != "0.1" || Text(root, "kind") != "simulation_request")
                throw new AdmissionException("Unsupported contract version or request kind.");
            var id = Text(root, "message_id");
            if (!Guid.TryParseExact(id, "D", out _))
                throw new AdmissionException("message_id must be a canonical UUID.");
            var errors = Required(root, "errors");
            if (errors.ValueKind != JsonValueKind.Array || errors.GetArrayLength() != 0)
                throw new AdmissionException("A simulation request must have an empty errors array.");
            return id;
        }

        private sealed record ParsedProblem(SimulationRequest Request, double TemperatureK, string[] SpeciesIds);

        private static ParsedProblem ParseProblem(JsonElement payload)
        {
            Strict(payload, "model_kind", "data_quality", "species", "reactions",
                "conservation_laws", "volume", "temperature", "time_start", "time_end",
                "output_interval", "solver_policy");
            if (Text(payload, "model_kind") != "closed_isothermal_irreversible" ||
                Text(payload, "data_quality") != "hypothetical")
                throw new AdmissionException("The initial CLI supports explicitly hypothetical, closed isothermal irreversible simulations only.");

            var temperature = Quantity(Required(payload, "temperature"), "K");
            if (temperature <= 0d)
                throw new AdmissionException("Temperature must be positive Kelvin.");

            var species = new Dictionary<string, int>(StringComparer.Ordinal);
            var amounts = new Dictionary<string, double>(StringComparer.Ordinal);
            foreach (var item in Items(Required(payload, "species"), MaximumSpecies))
            {
                Strict(item, "species_ref", "initial_amount");
                var (id, revision) = Reference(Required(item, "species_ref"));
                if (!species.TryAdd(id, revision))
                    throw new AdmissionException("Duplicate species reference: " + id);
                amounts.Add(id, Quantity(Required(item, "initial_amount"), "mol"));
                if (amounts[id] < 0d)
                    throw new AdmissionException("Initial species amounts must be non-negative.");
            }

            var reactions = new List<ReactionDefinition>();
            var reactionIds = new HashSet<string>(StringComparer.Ordinal);
            foreach (var item in Items(Required(payload, "reactions"), MaximumReactions))
            {
                Strict(item, "reaction_ref", "arrow_type", "rate_law_id", "stoichiometry",
                    "kinetic_orders", "rate_constant", "parameter_temperature");
                var (reactionId, _) = Reference(Required(item, "reaction_ref"));
                if (!reactionIds.Add(reactionId))
                    throw new AdmissionException("Duplicate reaction reference: " + reactionId);
                if (Text(item, "arrow_type") != "forward" ||
                    Text(item, "rate_law_id") != "irreversible_volumetric_power_law")
                    throw new AdmissionException("Unsupported arrow or rate law in reaction " + reactionId);
                var declaredParameterT = Quantity(Required(item, "parameter_temperature"), "K");
                if (declaredParameterT != temperature)
                    throw new AdmissionException("Rate parameter temperature does not match experiment temperature.");

                var stoichiometry = new Dictionary<string, int>(StringComparer.Ordinal);
                foreach (var term in Items(Required(item, "stoichiometry"), MaximumSpecies * 2))
                {
                    Strict(term, "species_ref", "coefficient");
                    var id = MatchedReference(Required(term, "species_ref"), species);
                    if (!stoichiometry.TryAdd(id, Integer(term, "coefficient", allowNegative: true)))
                        throw new AdmissionException("Repeated stoichiometric species must be aggregated upstream.");
                    if (stoichiometry[id] == 0)
                        throw new AdmissionException("Zero stoichiometric coefficient is forbidden.");
                }

                var orders = new Dictionary<string, double>(StringComparer.Ordinal);
                foreach (var order in Items(Required(item, "kinetic_orders"), MaximumSpecies, allowEmpty: true))
                {
                    Strict(order, "species_ref", "order");
                    var id = MatchedReference(Required(order, "species_ref"), species);
                    if (!orders.TryAdd(id, Number(order, "order")))
                        throw new AdmissionException("Duplicate kinetic-order species.");
                    if (orders[id] < 0d)
                        throw new AdmissionException("Negative kinetic orders are not supported.");
                }

                var rate = Required(item, "rate_constant");
                Strict(rate, "value", "unit_id", "basis", "dimension_exponents");
                if (Text(rate, "unit_id") != "derived" ||
                    Text(rate, "basis") != "volumetric_power_law")
                    throw new AdmissionException("Unsupported kinetic rate constant basis.");
                var totalOrder = orders.Values.Sum();
                if (!double.IsFinite(totalOrder))
                    throw new AdmissionException("Total kinetic order is not finite.");
                var exponent = 1d - totalOrder;
                var dimensions = Required(rate, "dimension_exponents");
                Strict(dimensions, "mol", "m", "s");
                if (!Near(Number(dimensions, "mol"), exponent) ||
                    !Near(Number(dimensions, "m"), -3d * exponent) ||
                    !Near(Number(dimensions, "s"), -1d))
                    throw new AdmissionException("Kinetic k dimension exponents do not match explicit orders.");
                reactions.Add(new ReactionDefinition(reactionId, stoichiometry, orders,
                    new RateConstant(Number(rate, "value"), exponent)));
            }

            var laws = new List<ConservationLaw>();
            var lawIds = new HashSet<string>(StringComparer.Ordinal);
            foreach (var law in Items(Required(payload, "conservation_laws"), MaximumSpecies, allowEmpty: true))
            {
                Strict(law, "id", "coefficients");
                var id = Text(law, "id");
                if (!lawIds.Add(id))
                    throw new AdmissionException("Duplicate conservation law ID.");
                var coefficients = new Dictionary<string, double>(StringComparer.Ordinal);
                foreach (var term in Items(Required(law, "coefficients"), MaximumSpecies))
                {
                    Strict(term, "species_ref", "coefficient");
                    var speciesId = MatchedReference(Required(term, "species_ref"), species);
                    if (!coefficients.TryAdd(speciesId, Number(term, "coefficient")))
                        throw new AdmissionException("Duplicate conservation coefficient species.");
                }
                laws.Add(new ConservationLaw(id, coefficients));
            }

            var network = new ReactionNetwork(species.Keys, reactions, laws);
            var policy = Required(payload, "solver_policy");
            Strict(policy, "relative_tolerance", "absolute_tolerance", "initial_step",
                "minimum_step", "maximum_step", "maximum_internal_steps");
            var options = new SolverOptions
            {
                RelativeTolerance = Number(policy, "relative_tolerance"),
                AbsoluteToleranceMol = Quantity(Required(policy, "absolute_tolerance"), "mol"),
                InitialStepSeconds = Quantity(Required(policy, "initial_step"), "s"),
                MinimumStepSeconds = Quantity(Required(policy, "minimum_step"), "s"),
                MaximumStepSeconds = Quantity(Required(policy, "maximum_step"), "s"),
                MaximumInternalSteps = Integer(policy, "maximum_internal_steps")
            };
            if (options.MaximumInternalSteps > MaximumInternalSteps)
                throw new AdmissionException("Internal step budget exceeds CLI limit.");

            var start = Quantity(Required(payload, "time_start"), "s");
            var end = Quantity(Required(payload, "time_end"), "s");
            var interval = Quantity(Required(payload, "output_interval"), "s");
            if (end <= start || interval <= 0d || !double.IsFinite(end - start) ||
                (end - start) / interval > MaximumSamples - 1)
                throw new AdmissionException("Output sample count or requested simulation duration is unsupported.");

            var request = new SimulationRequest
            {
                Network = network,
                InitialAmountsMol = amounts,
                VolumeM3 = Quantity(Required(payload, "volume"), "m3"),
                StartTimeSeconds = start,
                EndTimeSeconds = end,
                OutputIntervalSeconds = interval,
                Solver = options
            };
            request.Validate();
            return new ParsedProblem(request, temperature, network.SpeciesIds.ToArray());
        }

        private static object MakeResult(string requestId, ParsedProblem parsed, SimulationResult result)
        {
            var outcome = result.Status switch
            {
                SimulationStatus.Success => "completed",
                SimulationStatus.InvalidInput => "blocked",
                SimulationStatus.MaximumStepsExceeded => "step_limit",
                SimulationStatus.ConservationFailure => "invariant_violation",
                SimulationStatus.Cancelled => "cancelled",
                _ => "numerical_failure"
            };
            var samples = result.Samples.Select(sample => new
            {
                time_s = Finite(sample.TimeSeconds),
                amounts_mol = sample.AmountsMol.ToDictionary(kv => kv.Key, kv => Finite(kv.Value),
                    StringComparer.Ordinal)
            }).ToArray();
            if (samples.Length > MaximumSamples)
                throw new AdmissionException("Solver produced more output samples than permitted.");

            var completed = result.Status == SimulationStatus.Success &&
                            samples.Length > 0 &&
                            samples[^1].time_s == parsed.Request.EndTimeSeconds;
            if (result.Status == SimulationStatus.Success && !completed)
                throw new AdmissionException("Numerical success did not reach the requested final timestamp.");

            var reliability = new
            {
                data_quality = "hypothetical",
                model_applicability = "not_assessed",
                numerical_status = completed ? "completed" : result.Status == SimulationStatus.Cancelled ? "cancelled" : "failed",
                completeness = completed ? "complete_for_declared_scope" :
                    samples.Length > 0 ? "partial" : "absent",
                warnings = Array.Empty<object>()
            };
            var errors = result.Status == SimulationStatus.Success
                ? Array.Empty<object>()
                : new object[] { Error("KINETICS_" + result.Status.ToString().ToUpperInvariant(),
                    result.Diagnostics.Message ?? "Solver stopped.") };
            return Envelope(requestId, outcome, new
            {
                requested_end_s = parsed.Request.EndTimeSeconds,
                last_valid_time_s = samples.Length > 0 ? (double?)samples[^1].time_s : null,
                last_valid_time_status = samples.Length > 0 ? "present" : "not_reported",
                temperature_k = parsed.TemperatureK,
                species_ids = parsed.SpeciesIds,
                termination = outcome,
                samples,
                diagnostics = new
                {
                    accepted_steps = result.Diagnostics.AcceptedSteps,
                    rejected_steps = result.Diagnostics.RejectedSteps,
                    rhs_evaluations = result.Diagnostics.RightHandSideEvaluations,
                    message = result.Diagnostics.Message
                },
                reliability
            }, errors);
        }

        private static object MakeBlocked(string requestId, string reason) =>
            Envelope(requestId, "blocked", new
            {
                termination = "blocked",
                samples = Array.Empty<object>(),
                last_valid_time_status = "not_reported",
                reliability = new
                {
                    data_quality = "hypothetical",
                    model_applicability = "not_assessed",
                    numerical_status = "not_run",
                    completeness = "absent",
                    warnings = Array.Empty<object>()
                }
            }, new object[] { Error("KINETICS_INVALID_INPUT", reason) });

        private static object Envelope(string requestId, string outcome, object payload, object[] errors) =>
            new
            {
                contract_version = "0.1",
                message_id = Guid.NewGuid().ToString("D"),
                request_message_id = requestId,
                kind = "simulation_result",
                outcome,
                payload,
                errors
            };

        private static object Error(string code, string message) => new
        {
            code,
            severity = "error",
            message_key = "kinetics.input_or_solver_failure",
            context = new { reason = message },
            recoverable = false,
            responsible_module = "A4"
        };

        private static void WriteResponse(string outputPath, object response)
        {
            var bytes = JsonSerializer.SerializeToUtf8Bytes(response);
            if (bytes.Length > MaximumResponseBytes)
                throw new AdmissionException("Response exceeds the output size limit.");
            var temporaryPath = outputPath + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                using (var stream = new FileStream(temporaryPath, FileMode.CreateNew, FileAccess.Write,
                    FileShare.None))
                {
                    stream.Write(bytes);
                    stream.Flush(flushToDisk: true);
                }
                File.Move(temporaryPath, outputPath);
            }
            finally
            {
                if (File.Exists(temporaryPath))
                    File.Delete(temporaryPath);
            }
        }

        private static JsonElement Required(JsonElement obj, string field) =>
            obj.ValueKind == JsonValueKind.Object && obj.TryGetProperty(field, out var value)
                ? value
                : throw new AdmissionException("Missing required field: " + field);

        private static void Strict(JsonElement element, params string[] fields)
        {
            if (element.ValueKind != JsonValueKind.Object)
                throw new AdmissionException("Expected a JSON object.");
            var known = fields.ToHashSet(StringComparer.Ordinal);
            var seen = new HashSet<string>(StringComparer.Ordinal);
            foreach (var entry in element.EnumerateObject())
                if (!known.Contains(entry.Name) || !seen.Add(entry.Name))
                    throw new AdmissionException("Unknown or repeated JSON field: " + entry.Name);
            if (fields.Any(field => !seen.Contains(field)))
                throw new AdmissionException("Missing required JSON object property.");
        }

        private static IEnumerable<JsonElement> Items(JsonElement array, int max, bool allowEmpty = false)
        {
            if (array.ValueKind != JsonValueKind.Array ||
                array.GetArrayLength() > max ||
                (!allowEmpty && array.GetArrayLength() == 0))
                throw new AdmissionException("JSON collection count is invalid or exceeds its limit.");
            return array.EnumerateArray();
        }

        private static string Text(JsonElement obj, string field)
        {
            var value = Required(obj, field);
            if (value.ValueKind != JsonValueKind.String)
                throw new AdmissionException("Expected string: " + field);
            var str = value.GetString()!;
            if (string.IsNullOrWhiteSpace(str) || str.Length > 128)
                throw new AdmissionException("Empty or oversized string: " + field);
            return str;
        }

        private static double Number(JsonElement obj, string field)
        {
            var value = Required(obj, field);
            if (value.ValueKind != JsonValueKind.Number ||
                !value.TryGetDouble(out var number) || !double.IsFinite(number))
                throw new AdmissionException("Expected finite numeric value: " + field);
            return number;
        }

        private static int Integer(JsonElement obj, string field, bool allowNegative = false)
        {
            var element = Required(obj, field);
            if (element.ValueKind != JsonValueKind.Number || !element.TryGetInt32(out var number) ||
                (!allowNegative && number <= 0))
                throw new AdmissionException("Invalid integer: " + field);
            return number;
        }

        private static double Quantity(JsonElement element, string unit)
        {
            Strict(element, "value", "unit_id");
            if (Text(element, "unit_id") != unit)
                throw new AdmissionException("Unsupported unit: expected " + unit);
            return Number(element, "value");
        }

        private static (string Id, int Revision) Reference(JsonElement element)
        {
            Strict(element, "id", "record_revision");
            return (Text(element, "id"), Integer(element, "record_revision"));
        }

        private static string MatchedReference(JsonElement element, Dictionary<string, int> species)
        {
            var (id, revision) = Reference(element);
            if (!species.TryGetValue(id, out var knownRevision) || knownRevision != revision)
                throw new AdmissionException("Unknown species identity or record revision.");
            return id;
        }

        private static bool Near(double value, double expected) =>
            double.IsFinite(value) && double.IsFinite(expected) &&
            Math.Abs(value - expected) <= 1e-10 * Math.Max(1d, Math.Abs(expected));

        private static double Finite(double value) =>
            double.IsFinite(value)
                ? value
                : throw new AdmissionException("Non-finite numerical result cannot be serialized.");

        private sealed class AdmissionException(string message) : Exception(message);
    }
}
