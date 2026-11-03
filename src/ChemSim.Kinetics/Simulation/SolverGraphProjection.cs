using System.Text.Json.Serialization;

namespace ChemSim.Kinetics.Simulation;

/// <summary>
/// Explicit reference supplied by the integrator; A4 never invents canonical
/// experiment/species identities or revisions.
/// </summary>
public sealed record GraphReference(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("record_revision")] int RecordRevision);

/// <summary>
/// A5 GraphSeries sample: only valid observations have numeric values.
/// An uncomputed end-of-request marker is explicitly missing, never zero.
/// </summary>
public sealed record ConcentrationGraphSample(
    [property: JsonPropertyName("time_s")] double TimeSeconds,
    [property: JsonPropertyName("value_status")] string ValueStatus,
    [property: JsonPropertyName("value")]
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] double? Value = null);

/// <summary>
/// Shape-compatible with the existing v0.1 GraphSeries quantity=concentration
/// consumer. This is an opt-in in-process projection, not a new wire contract.
/// </summary>
public sealed record ConcentrationGraphSeries(
    [property: JsonPropertyName("series_id")] string SeriesId,
    [property: JsonPropertyName("result_ref")] GraphReference ResultRef,
    [property: JsonPropertyName("quantity_key")] string QuantityKey,
    [property: JsonPropertyName("species_ref")] GraphReference SpeciesRef,
    [property: JsonPropertyName("unit_id")] string UnitId,
    [property: JsonPropertyName("samples")] IReadOnlyList<ConcentrationGraphSample> Samples);

/// <summary>
/// Projects an A4 closed, constant-volume numerical result into one A5-compatible
/// concentration series per species. Identity and series IDs MUST come from the
/// approved integration adapter. Nothing is added to the CLI response until
/// integrator/A5 approve the result-to-GraphSeries binding.
/// </summary>
public static class SolverGraphProjection
{
    public static IReadOnlyList<ConcentrationGraphSeries> ProjectConcentrations(
        SimulationRequest request,
        SimulationResult result,
        GraphReference resultReference,
        IReadOnlyDictionary<string, GraphReference> speciesReferences,
        IReadOnlyDictionary<string, string> seriesIds)
    {
        ArgumentNullException.ThrowIfNull(request);
        ArgumentNullException.ThrowIfNull(result);
        ArgumentNullException.ThrowIfNull(resultReference);
        ArgumentNullException.ThrowIfNull(speciesReferences);
        ArgumentNullException.ThrowIfNull(seriesIds);
        ValidateReference(resultReference, "result reference");

        // The fixed-volume, SI amount model is the ONLY currently supported
        // dimensional conversion. Do not extrapolate to flows or varying volume.
        request.Validate();
        var speciesIds = request.Network.SpeciesIds;
        if (speciesReferences.Count != speciesIds.Count || seriesIds.Count != speciesIds.Count)
            throw new ArgumentException("Graph metadata must cover every network species exactly.");

        var distinctSeriesIds = new HashSet<string>(StringComparer.Ordinal);
        foreach (var speciesId in speciesIds)
        {
            if (!speciesReferences.TryGetValue(speciesId, out var speciesReference) ||
                speciesReference is null ||
                !string.Equals(speciesReference.Id, speciesId, StringComparison.Ordinal))
                throw new ArgumentException("Missing or mismatched canonical species reference: " + speciesId);
            ValidateReference(speciesReference, "species reference");
            if (!seriesIds.TryGetValue(speciesId, out var seriesId) ||
                string.IsNullOrWhiteSpace(seriesId) ||
                !distinctSeriesIds.Add(seriesId))
                throw new ArgumentException("Graph series IDs must be explicit, nonempty and unique.");
        }

        if (result.Samples is null)
            throw new ArgumentException("Solver result samples cannot be null.", nameof(result));
        if (result.Samples.Count == 0)
        {
            if (result.Status == SimulationStatus.Success)
                throw new ArgumentException("Successful solver results must contain initial and final samples.");
            // An invalid request with zero published output has no graph.
            return Array.Empty<ConcentrationGraphSeries>();
        }

        var points = speciesIds.ToDictionary(
            id => id,
            _ => new List<ConcentrationGraphSample>(result.Samples.Count + 1),
            StringComparer.Ordinal);
        double lastTime = double.NegativeInfinity;

        foreach (var sample in result.Samples)
        {
            if (sample is null || sample.AmountsMol is null ||
                !double.IsFinite(sample.TimeSeconds) ||
                sample.TimeSeconds <= lastTime ||
                sample.TimeSeconds < request.StartTimeSeconds ||
                sample.TimeSeconds > request.EndTimeSeconds)
                throw new ArgumentException("Invalid or non-monotone solver sample timestamp.");
            if (sample.AmountsMol.Count != speciesIds.Count)
                throw new ArgumentException("Solver sample must contain exactly the network species set.");

            foreach (var speciesId in speciesIds)
            {
                if (!sample.AmountsMol.TryGetValue(speciesId, out var amountMol) ||
                    !double.IsFinite(amountMol) || amountMol < 0d)
                    throw new ArgumentException("Missing, non-finite or negative amount for " + speciesId);

                var concentration = amountMol / request.VolumeM3;
                if (!double.IsFinite(concentration) || concentration < 0d)
                    throw new ArgumentException("Non-finite concentration after mol/m3 conversion.");
                points[speciesId].Add(new ConcentrationGraphSample(sample.TimeSeconds, "valid", concentration));
            }

            lastTime = sample.TimeSeconds;
        }

        if (result.Samples[0].TimeSeconds != request.StartTimeSeconds)
            throw new ArgumentException("The published prefix does not start at the requested model time.");
        if (result.Status == SimulationStatus.Success && lastTime != request.EndTimeSeconds)
            throw new ArgumentException("Success cannot be projected without the requested final sample.");

        // The solver retains only checked output targets on numerical failure.
        // Show one typed MISSING marker at the requested end: A5 must not
        // connect a partial prefix to an invented final value.
        if (result.Status != SimulationStatus.Success && lastTime < request.EndTimeSeconds)
            foreach (var speciesId in speciesIds)
                points[speciesId].Add(new ConcentrationGraphSample(
                    request.EndTimeSeconds, "missing"));

        return Array.AsReadOnly(speciesIds.Select(id => new ConcentrationGraphSeries(
            seriesIds[id],
            resultReference,
            "concentration",
            speciesReferences[id],
            "mol/m3",
            Array.AsReadOnly(points[id].ToArray())
        )).ToArray());
    }

    private static void ValidateReference(GraphReference reference, string field)
    {
        if (string.IsNullOrWhiteSpace(reference.Id) || reference.RecordRevision <= 0)
            throw new ArgumentException("Invalid " + field + " ID or revision.");
    }
}
