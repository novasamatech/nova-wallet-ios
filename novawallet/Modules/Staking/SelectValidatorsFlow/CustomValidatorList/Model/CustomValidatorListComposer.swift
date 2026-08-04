import Foundation

class CustomValidatorListComposer {
    let filter: CustomValidatorListFilter

    init(
        filter: CustomValidatorListFilter
    ) {
        self.filter = filter
    }
}

private extension CustomValidatorListComposer {
    func applyingFilters(to validators: [SelectedValidatorInfo]) -> [SelectedValidatorInfo] {
        var filtered = validators

        if !filter.allowsNoIdentity {
            filtered = filtered.filter { $0.hasIdentity }
        }

        if !filter.allowsOversubscribed {
            filtered = filtered.filter { !$0.oversubscribed }
        }

        if !filter.allowsSlashed {
            filtered = filtered.filter { !$0.hasSlashes }
        }

        return filtered
    }

    func sorted(_ validators: [SelectedValidatorInfo]) -> [SelectedValidatorInfo] {
        switch filter.sortedBy {
        case .estimatedReward:
            return validators.sorted(by: { $0.stakeReturn >= $1.stakeReturn })
        case .totalStake:
            return validators.sorted(by: { $0.totalStake >= $1.totalStake })
        case .ownStake:
            return validators.sorted(by: { $0.ownStake >= $1.ownStake })
        }
    }

    func applyingClusters(to validators: [SelectedValidatorInfo]) -> [SelectedValidatorInfo] {
        guard case let .limited(clusterSizeLimit) = filter.allowsClusters else {
            return validators
        }

        return processClusters(
            items: validators,
            clusterSizeLimit: clusterSizeLimit,
            resultSize: validators.count
        )
    }
}

extension CustomValidatorListComposer: RecommendationsComposing {
    typealias RecommendableType = SelectedValidatorInfo

    // Preferred validators are pinned to the bottom and bypass the user's filters: they are
    // permanently selected, so hiding one would make the list disagree with the selection.
    func compose(
        from recommendables: [RecommendableType],
        preferrences: [RecommendableType]
    ) -> [RecommendableType] {
        let preferredAddresses = Set(preferrences.map(\.address))
        let community = recommendables.filter { !preferredAddresses.contains($0.address) }

        let processedCommunity = applyingClusters(to: sorted(applyingFilters(to: community)))

        return processedCommunity + sorted(preferrences)
    }
}
