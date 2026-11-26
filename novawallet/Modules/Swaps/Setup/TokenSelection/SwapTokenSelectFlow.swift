import UIKit

final class SwapTokenSelectFlow {
    let state: SwapTokensFlowStateProtocol

    init(state: SwapTokensFlowStateProtocol) {
        self.state = state
    }
}

// MARK: SwapTokenSelectionFlowProtocol

extension SwapTokenSelectFlow: SwapTokenSelectionFlowProtocol {
    func showTokenSelection(
        from view: ControllerBackedProtocol?,
        side: SwapTokenSelectionSide,
        context: SwapTokenSelectionContext,
        completion: @escaping (SwapTokenSelectionResult) -> Void
    ) {
        guard let selectionView = SwapTokenSelectViewFactory.createView(
            state: state,
            side: side,
            context: context,
            completion: completion
        ) else {
            return
        }

        view?.controller.presentWithCardLayout(selectionView.controller, animated: true)
    }
}
