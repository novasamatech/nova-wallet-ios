import Foundation

enum SwapTokenSelectionSide {
    case pay
    case receive
}

struct SwapTokenSelectionContext {
    let current: ChainAsset?
    let counterpart: ChainAsset?
}

enum SwapTokenSelectionResult {
    case selected(ChainAsset)
    case selectedClearingCounterpart(ChainAsset)
}

extension SwapTokenSelectionResult {
    var chainAsset: ChainAsset {
        switch self {
        case let .selected(chainAsset), let .selectedClearingCounterpart(chainAsset):
            chainAsset
        }
    }

    var clearsCounterpart: Bool {
        switch self {
        case .selected:
            false
        case .selectedClearingCounterpart:
            true
        }
    }
}

protocol SwapTokenSelectionFlowProtocol: AnyObject {
    func showTokenSelection(
        from view: ControllerBackedProtocol?,
        side: SwapTokenSelectionSide,
        context: SwapTokenSelectionContext,
        completion: @escaping (SwapTokenSelectionResult) -> Void
    )
}
