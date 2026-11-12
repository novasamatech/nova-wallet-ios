import Foundation

enum SwapTokenSelectionSide {
    case pay
    case receive
}

enum SwapTokenSelectionResult {
    case selected(ChainAsset)
}

protocol SwapTokenSelectionFlowProtocol: AnyObject {
    func showTokenSelection(
        from view: ControllerBackedProtocol?,
        side: SwapTokenSelectionSide,
        counterpart: ChainAsset?,
        completion: @escaping (SwapTokenSelectionResult) -> Void
    )
}
