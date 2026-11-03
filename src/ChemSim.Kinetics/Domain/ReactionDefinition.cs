using System.Collections.ObjectModel;

namespace ChemSim.Kinetics.Domain;

/// <summary>
/// One irreversible reaction with an independently specified stoichiometry
/// and kinetic power law. Stoichiometric coefficients are integers; kinetic
/// orders are non-negative real numbers and are never inferred from stoichiometry.
/// </summary>
public sealed class ReactionDefinition
{
    public string Id { get; }
    public IReadOnlyDictionary<string, int> Stoichiometry { get; }
    public IReadOnlyDictionary<string, double> KineticOrders { get; }
    public RateConstant RateConstant { get; }
    public double TotalKineticOrder { get; }

    public ReactionDefinition(
        string id,
        IReadOnlyDictionary<string, int> stoichiometry,
        IReadOnlyDictionary<string, double> kineticOrders,
        RateConstant rateConstant)
    {
        if (string.IsNullOrWhiteSpace(id))
            throw new ArgumentException("Reaction id is required.", nameof(id));
        ArgumentNullException.ThrowIfNull(stoichiometry);
        ArgumentNullException.ThrowIfNull(kineticOrders);

        if (stoichiometry.Count == 0)
            throw new ArgumentException("A reaction must contain at least one stoichiometric term.", nameof(stoichiometry));

        var stoichCopy = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var (speciesId, coefficient) in stoichiometry)
        {
            if (string.IsNullOrWhiteSpace(speciesId))
                throw new ArgumentException("Species ids in stoichiometry cannot be empty.", nameof(stoichiometry));
            if (coefficient == 0)
                throw new ArgumentException($"Reaction '{id}': zero stoichiometric coefficients must be omitted.", nameof(stoichiometry));
            stoichCopy.Add(speciesId, coefficient);
        }

        if (!stoichCopy.Values.Any(value => value < 0) || !stoichCopy.Values.Any(value => value > 0))
            throw new ArgumentException(
                $"Reaction '{id}' must contain at least one reactant and one product in a closed-system reaction.",
                nameof(stoichiometry));

        var orderCopy = new Dictionary<string, double>(StringComparer.Ordinal);
        var totalOrder = 0d;
        foreach (var (speciesId, order) in kineticOrders)
        {
            if (string.IsNullOrWhiteSpace(speciesId))
                throw new ArgumentException("Species ids in kinetic orders cannot be empty.", nameof(kineticOrders));
            if (!double.IsFinite(order) || order < 0d)
                throw new ArgumentOutOfRangeException(nameof(kineticOrders), $"Reaction '{id}': kinetic orders must be finite and non-negative.");
            orderCopy.Add(speciesId, order);

            totalOrder += order;
            if (!double.IsFinite(totalOrder))
                throw new ArgumentOutOfRangeException(nameof(kineticOrders), $"Reaction '{id}': total kinetic order must be finite.");
        }

        rateConstant.ValidateForTotalOrder(totalOrder, id);

        Id = id;
        Stoichiometry = new ReadOnlyDictionary<string, int>(stoichCopy);
        KineticOrders = new ReadOnlyDictionary<string, double>(orderCopy);
        RateConstant = rateConstant;
        TotalKineticOrder = totalOrder;
    }
}
