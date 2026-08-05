import Foundation

protocol Recommendable {
    var address: AccountAddress { get }
    var identity: AccountIdentity? { get }
    var stakeReturn: Decimal { get }
    var totalStake: Decimal { get }
    var ownStake: Decimal { get }
    var hasIdentity: Bool { get }
    var oversubscribed: Bool { get }
    var hasSlashes: Bool { get }
    var blocked: Bool { get }
}

protocol RecommendationsComposing {
    associatedtype RecommendableType: Recommendable

    func compose(
        from recommendables: [RecommendableType],
        preferrences: [RecommendableType]
    ) -> [RecommendableType]

    func processClusters(
        items: [RecommendableType],
        clusterSizeLimit: Int,
        resultSize: Int?
    ) -> [RecommendableType]
}

extension RecommendationsComposing {
    func processClusters
    (
        items: [RecommendableType],
        clusterSizeLimit: Int,
        resultSize: Int?
    ) -> [RecommendableType] {
        let resultSize = resultSize ?? items.count
        var clusterCounters: [AccountAddress: Int] = [:]

        var recommended: [RecommendableType] = []

        for item in items {
            let clusterKey = item.identity?.parentAddress ?? item.address
            let clusterCounter = clusterCounters[clusterKey] ?? 0

            if clusterCounter < clusterSizeLimit {
                clusterCounters[clusterKey] = clusterCounter + 1
                recommended.append(item)
            }

            if recommended.count >= resultSize {
                break
            }
        }

        return recommended
    }
}

final class RecommendationsComposer {
    typealias RecommendableType = SelectedValidatorInfo

    let resultSize: Int
    let clusterSizeLimit: Int

    init(resultSize: Int, clusterSizeLimit: Int) {
        self.resultSize = resultSize
        self.clusterSizeLimit = clusterSizeLimit
    }

    private func composeWithoutIdentities(from validators: [RecommendableType]) -> [RecommendableType] {
        let recommendations = validators
            .filter { !$0.hasSlashes && !$0.oversubscribed && !$0.blocked }
            .sorted(by: { $0.stakeReturn >= $1.stakeReturn })
            .prefix(resultSize)
        return Array(recommendations)
    }

    private func composeWithIdentities(from validators: [RecommendableType]) -> [RecommendableType] {
        let filtered = validators
            .filter { $0.hasIdentity && !$0.hasSlashes && !$0.oversubscribed && !$0.blocked }
            .sorted(by: { $0.stakeReturn >= $1.stakeReturn })

        return processClusters(items: filtered, clusterSizeLimit: clusterSizeLimit, resultSize: resultSize)
    }
}

extension RecommendationsComposer: RecommendationsComposing {
    // Preferred validators occupy reserved slots inside resultSize, mirroring ValidatorSelectionSeeder:
    // community picks are dropped from the tail to make room, so a preference is never truncated away
    // even when it also ranks into the recommendation list.
    func compose(
        from recommendables: [RecommendableType],
        preferrences: [RecommendableType]
    ) -> [RecommendableType] {
        let recommendationList: [RecommendableType]

        if recommendables.contains(where: { $0.hasIdentity }) {
            recommendationList = composeWithIdentities(from: recommendables)
        } else {
            recommendationList = composeWithoutIdentities(from: recommendables)
        }

        let reserved = Array(
            preferrences
                .filter { !$0.oversubscribed && !$0.blocked }
                .prefix(resultSize)
        )

        let reservedAddresses = Set(reserved.map(\.address))
        let communityLimit = max(resultSize - reserved.count, 0)

        let community = recommendationList
            .filter { !reservedAddresses.contains($0.address) }
            .prefix(communityLimit)

        return Array(community) + reserved
    }
}
