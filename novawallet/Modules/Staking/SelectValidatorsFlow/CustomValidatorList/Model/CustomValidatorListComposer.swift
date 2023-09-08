import Foundation

class CustomValidatorListComposer {
    let filter: CustomValidatorListFilter

    init(
        filter: CustomValidatorListFilter
    ) {
        self.filter = filter
    }
}

extension CustomValidatorListComposer: RecommendationsComposing {
    typealias RecommendableType = SelectedValidatorInfo

    func compose(
        from recommendables: [RecommendableType],
        preferrences: [RecommendableType]
    ) -> [RecommendableType] {
        let preferredAddresses = Set(preferrences.map(\.address))
        var filtered = preferrences + recommendables.filter { !preferredAddresses.contains($0.address) }

        if !filter.allowsNoIdentity {
            filtered = filtered.filter {
                $0.hasIdentity
            }
        }

        if !filter.allowsOversubscribed {
            filtered = filtered.filter {
                !$0.oversubscribed
            }
        }

        if !filter.allowsSlashed {
            filtered = filtered.filter {
                !$0.hasSlashes
            }
        }

        let sorted: [RecommendableType]

        switch filter.sortedBy {
        case .estimatedReward:
            sorted = filtered.sorted(by: { $0.stakeReturn >= $1.stakeReturn })
        case .totalStake:
            sorted = filtered.sorted(by: { $0.totalStake >= $1.totalStake })
        case .ownStake:
            sorted = filtered.sorted(by: { $0.ownStake >= $1.ownStake })
        }

        guard case let .limited(clusterSizeLimit) = filter.allowsClusters else { return sorted }

        return processClusters(
            items: sorted,
            clusterSizeLimit: clusterSizeLimit,
            resultSize: sorted.count
        )
    }
}
