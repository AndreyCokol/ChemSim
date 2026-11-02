using System.Collections.ObjectModel;

namespace ChemSim.Kinetics.Domain;

/// <summary>
/// A linear conserved quantity over species amounts. Coefficients are supplied
/// by the chemistry-domain layer (for example, atom counts per species).
/// </summary>
public sealed class ConservationLaw
{
    public string Id { get; }
    public IReadOnlyDictionary<string, double> Coefficients { get; }
    public double CoefficientMagnitudeSum { get; }

    public ConservationLaw(string id, IReadOnlyDictionary<string, double> coefficients)
    {
        if (string.IsNullOrWhiteSpace(id))
            throw new ArgumentException("Conservation-law id is required.", nameof(id));
        ArgumentNullException.ThrowIfNull(coefficients);
        if (coefficients.Count == 0)
            throw new ArgumentException("A conservation law must reference at least one species.", nameof(coefficients));

        var copy = new Dictionary<string, double>(StringComparer.Ordinal);
        var magnitudeSum = 0d;
        foreach (var (speciesId, coefficient) in coefficients)
        {
            if (string.IsNullOrWhiteSpace(speciesId))
                throw new ArgumentException("Species ids in a conservation law cannot be empty.", nameof(coefficients));
            if (!double.IsFinite(coefficient) || coefficient == 0d)
                throw new ArgumentOutOfRangeException(nameof(coefficients), "Conservation coefficients must be finite and non-zero.");
            copy.Add(speciesId, coefficient);

            magnitudeSum += Math.Abs(coefficient);
            if (!double.IsFinite(magnitudeSum))
                throw new ArgumentOutOfRangeException(nameof(coefficients), "The sum of conservation coefficient magnitudes must be finite.");
        }

        Id = id;
        Coefficients = new ReadOnlyDictionary<string, double>(copy);
        CoefficientMagnitudeSum = magnitudeSum;
    }

    public double Evaluate(IReadOnlyList<string> speciesIds, IReadOnlyList<double> amountsMol)
    {
        if (speciesIds.Count != amountsMol.Count)
            throw new ArgumentException("Species and amount vectors must have equal lengths.");

        double total = 0d;
        for (var i = 0; i < speciesIds.Count; i++)
        {
            if (!Coefficients.TryGetValue(speciesIds[i], out var coefficient))
                continue;

            var term = coefficient * amountsMol[i];
            if (!double.IsFinite(term))
                throw new ArithmeticException($"Conservation law '{Id}' produced a non-finite term for species '{speciesIds[i]}'.");

            total += term;
            if (!double.IsFinite(total))
                throw new ArithmeticException($"Conservation law '{Id}' produced a non-finite total.");
        }

        return total;
    }
}
