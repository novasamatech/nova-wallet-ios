import Foundation

enum SubtensorStrategyKind: String, Equatable, CaseIterable {
    case steady
    case balanced
    case higherUpside
}

struct SubtensorStrategyOffer: Equatable {
    let kind: SubtensorStrategyKind
    let rootNetworkRate: SubtensorRate?
    let isAvailable: Bool
}

enum SubtensorPickCandidate: Equatable {
    case pair(SubtensorRecommendedPair)
    case fallbackRoot(SubtensorValidatorDirectoryItem)
}

struct SubtensorPickCandidates: Equatable {
    let kind: SubtensorStrategyKind
    let candidates: [SubtensorPickCandidate]
    let generationId: String?
}
