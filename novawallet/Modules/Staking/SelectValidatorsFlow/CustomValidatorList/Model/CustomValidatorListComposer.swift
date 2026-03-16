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
        var communityFiltered = recommendables.filter { !preferredAddresses.contains($0.address) }
        var preferredFiltered = preferrences

        if !filter.allowsNoIdentity {
            communityFiltered = communityFiltered.filter { $0.hasIdentity }
            preferredFiltered = preferredFiltered.filter { $0.hasIdentity }
        }

        if !filter.allowsOversubscribed {
            communityFiltered = communityFiltered.filter { !$0.oversubscribed }
            preferredFiltered = preferredFiltered.filter { !$0.oversubscribed }
        }

        if !filter.allowsSlashed {
            communityFiltered = communityFiltered.filter { !$0.hasSlashes }
            preferredFiltered = preferredFiltered.filter { !$0.hasSlashes }
        }

        let sortedCommunity: [RecommendableType]

        switch filter.sortedBy {
        case .estimatedReward:
            sortedCommunity = communityFiltered.sorted(by: { $0.stakeReturn >= $1.stakeReturn })
        case .totalStake:
            sortedCommunity = communityFiltered.sorted(by: { $0.totalStake >= $1.totalStake })
        case .ownStake:
            sortedCommunity = communityFiltered.sorted(by: { $0.ownStake >= $1.ownStake })
        }

        let processed: [RecommendableType]

        if case let .limited(clusterSizeLimit) = filter.allowsClusters {
            processed = processClusters(
                items: sortedCommunity,
                clusterSizeLimit: clusterSizeLimit,
                resultSize: sortedCommunity.count
            )
        } else {
            processed = sortedCommunity
        }

        return processed + preferredFiltered
    }
}
