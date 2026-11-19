import Foundation
import NovaAnalytics

enum SwapSetupPlacement {
    case swapsTab
    case flow
}

struct SwapPriceChartViewModel: Equatable {
    let isExpanded: Bool
    let isExpandable: Bool
}

struct SwapPriceChartContext {
    var followedChainAsset: ChainAsset?
    var isExpanded = false
    var state: AssetPriceChartState?
    var hasPendingFailure = false

    var isFailed: Bool {
        if case .unavailable(.failed) = state {
            true
        } else {
            false
        }
    }
}

enum SwapPriceChartFollowRule {
    static func followedChainAsset(pay: ChainAsset?, receive: ChainAsset?) -> ChainAsset? {
        if let receive {
            return receive
        }

        guard let pay, !isStablecoin(pay) else {
            return nil
        }

        return pay
    }

    private static func isStablecoin(_ chainAsset: ChainAsset) -> Bool {
        AssetCategoryClassifier.isStablecoin(chainAsset.asset.symbol)
    }
}

final class SwapPriceChartSession {
    static let shared = SwapPriceChartSession()

    var selectedPeriod: PriceHistoryPeriod = .week
}
