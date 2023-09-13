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

        let allIncludedAddresses = Set(recommendationList.map(\.address))
        let validPreferences = preferrences
            .filter { !allIncludedAddresses.contains($0.address) && !$0.oversubscribed && !$0.blocked }

        let finalSize = recommendationList.count + validPreferences.count

        let recommendationsWithPrefs: [RecommendableType]

        if finalSize > resultSize {
            let dropSize = finalSize - resultSize
            recommendationsWithPrefs = recommendationList.dropLast(dropSize) + validPreferences
        } else {
            recommendationsWithPrefs = recommendationList + validPreferences
        }

        // make sure we don't overload the result with prefs
        return Array(recommendationsWithPrefs.prefix(resultSize))
    }
}
