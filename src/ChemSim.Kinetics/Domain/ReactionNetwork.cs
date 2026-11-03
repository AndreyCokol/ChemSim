using System.Collections.ObjectModel;

namespace ChemSim.Kinetics.Domain;

/// <summary>
/// Immutable, deterministically ordered reaction network for the initial
/// species-amount based, closed, isothermal model.
/// </summary>
public sealed class ReactionNetwork
{
    public IReadOnlyList<string> SpeciesIds { get; }
    public IReadOnlyList<ReactionDefinition> Reactions { get; }
    public IReadOnlyList<ConservationLaw> ConservationLaws { get; }

    public ReactionNetwork(
        IEnumerable<string> speciesIds,
        IEnumerable<ReactionDefinition> reactions,
        IEnumerable<ConservationLaw>? conservationLaws = null)
    {
        ArgumentNullException.ThrowIfNull(speciesIds);
        ArgumentNullException.ThrowIfNull(reactions);

        var species = speciesIds.OrderBy(id => id, StringComparer.Ordinal).ToArray();
        if (species.Length == 0)
            throw new ArgumentException("A reaction network must contain at least one species.", nameof(speciesIds));
        if (species.Any(id => string.IsNullOrWhiteSpace(id)))
            throw new ArgumentException("Species ids cannot be empty.", nameof(speciesIds));
        if (species.Distinct(StringComparer.Ordinal).Count() != species.Length)
            throw new ArgumentException("Species ids must be unique.", nameof(speciesIds));

        var reactionInput = reactions.ToArray();
        if (reactionInput.Any(reaction => reaction is null))
            throw new ArgumentException("Reaction entries cannot be null.", nameof(reactions));

        var reactionArray = reactionInput.OrderBy(r => r.Id, StringComparer.Ordinal).ToArray();
        if (reactionArray.Length == 0)
            throw new ArgumentException("A reaction network must contain at least one reaction.", nameof(reactions));
        if (reactionArray.Select(r => r.Id).Distinct(StringComparer.Ordinal).Count() != reactionArray.Length)
            throw new ArgumentException("Reaction ids must be unique.", nameof(reactions));

        var speciesSet = species.ToHashSet(StringComparer.Ordinal);
        foreach (var reaction in reactionArray)
        {
            foreach (var speciesId in reaction.Stoichiometry.Keys.Concat(reaction.KineticOrders.Keys))
            {
                if (!speciesSet.Contains(speciesId))
                    throw new ArgumentException($"Reaction '{reaction.Id}' references unknown species '{speciesId}'.", nameof(reactions));
            }
        }

        var lawInput = (conservationLaws ?? Enumerable.Empty<ConservationLaw>()).ToArray();
        if (lawInput.Any(law => law is null))
            throw new ArgumentException("Conservation-law entries cannot be null.", nameof(conservationLaws));

        var laws = lawInput.OrderBy(law => law.Id, StringComparer.Ordinal).ToArray();
        if (laws.Select(law => law.Id).Distinct(StringComparer.Ordinal).Count() != laws.Length)
            throw new ArgumentException("Conservation-law ids must be unique.", nameof(conservationLaws));

        foreach (var law in laws)
        {
            foreach (var speciesId in law.Coefficients.Keys)
            {
                if (!speciesSet.Contains(speciesId))
                    throw new ArgumentException($"Conservation law '{law.Id}' references unknown species '{speciesId}'.", nameof(conservationLaws));
            }

            foreach (var reaction in reactionArray)
            {
                double residual = 0d;
                double magnitude = 0d;
                foreach (var (speciesId, coefficient) in reaction.Stoichiometry)
                {
                    if (!law.Coefficients.TryGetValue(speciesId, out var conservedCoefficient))
                        continue;
                    var term = conservedCoefficient * coefficient;
                    if (!double.IsFinite(term))
                        throw new ArgumentException(
                            $"Conservation law '{law.Id}' overflows while validating reaction '{reaction.Id}'.",
                            nameof(conservationLaws));

                    residual += term;
                    magnitude += Math.Abs(term);
                    if (!double.IsFinite(residual) || !double.IsFinite(magnitude))
                        throw new ArgumentException(
                            $"Conservation law '{law.Id}' has non-finite arithmetic while validating reaction '{reaction.Id}'.",
                            nameof(conservationLaws));
                }

                // A conservation vector is defined only up to non-zero scale.
                // Using max(1, magnitude) makes small but proportionally large
                // violations pass merely because the vector is expressed with
                // small coefficients. Compare against the actual term scale.
                var tolerance = 1e-12d * magnitude;
                if ((magnitude == 0d && residual != 0d) ||
                    (magnitude > 0d && Math.Abs(residual) > tolerance))
                {
                    throw new ArgumentException(
                        $"Reaction '{reaction.Id}' violates conservation law '{law.Id}' (residual {residual:G17}).",
                        nameof(conservationLaws));
                }
            }
        }

        SpeciesIds = Array.AsReadOnly(species);
        Reactions = Array.AsReadOnly(reactionArray);
        ConservationLaws = Array.AsReadOnly(laws);
    }
}
