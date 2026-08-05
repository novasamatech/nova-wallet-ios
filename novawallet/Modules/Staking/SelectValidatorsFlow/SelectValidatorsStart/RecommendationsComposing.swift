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

extension Recommendable {
    var isLockEligible: Bool { !blocked && !oversubscribed }
}

extension Array where Element: Recommendable {
    func reservingSlots(for reserved: [Element], limit: Int) -> [Element] {
        var seen = Set<AccountAddress>()
        let cappedReserved = reserved
            .filter { seen.insert($0.address).inserted }
            .prefix(limit)

        let reservedAddresses = Set(cappedReserved.map(\.address))
        let communityLimit = limit - cappedReserved.count

        guard communityLimit > 0 else {
            return Array(cappedReserved)
        }

        let community = filter { !reservedAddresses.contains($0.address) }
            .prefix(communityLimit)

        return Array(community) + Array(cappedReserved)
    }
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

        return recommendationList.reservingSlots(
            for: preferrences.filter { $0.isLockEligible },
            limit: resultSize
        )
    }
}
