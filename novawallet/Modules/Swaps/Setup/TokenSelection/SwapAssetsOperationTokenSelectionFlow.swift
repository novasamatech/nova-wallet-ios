import UIKit

final class SwapAssetsOperationTokenSelectionFlow {
    let state: SwapTokensFlowStateProtocol

    init(state: SwapTokensFlowStateProtocol) {
        self.state = state
    }
}

// MARK: Private

private extension SwapAssetsOperationTokenSelectionFlow {
    func createSelectionView(
        for side: SwapTokenSelectionSide,
        counterpart: ChainAsset?,
        completion: @escaping (SwapTokenSelectionResult) -> Void
    ) -> AssetsSearchViewProtocol? {
        let selectClosure: SwapAssetSelectionClosure = { chainAsset, _ in
            completion(.selected(chainAsset))
        }

        switch side {
        case .pay:
            return SwapAssetsOperationViewFactory.createSelectPayTokenViewWithState(
                state,
                selectionModel: .payForAsset(counterpart),
                selectClosure: selectClosure
            )
        case .receive:
            return SwapAssetsOperationViewFactory.createSelectReceiveTokenViewWithState(
                state,
                selectionModel: .receivePayingWith(counterpart),
                selectClosure: selectClosure
            )
        }
    }
}

// MARK: SwapTokenSelectionFlowProtocol

extension SwapAssetsOperationTokenSelectionFlow: SwapTokenSelectionFlowProtocol {
    func showTokenSelection(
        from view: ControllerBackedProtocol?,
        side: SwapTokenSelectionSide,
        counterpart: ChainAsset?,
        completion: @escaping (SwapTokenSelectionResult) -> Void
    ) {
        guard let selectTokenView = createSelectionView(
            for: side,
            counterpart: counterpart,
            completion: completion
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: selectTokenView.controller
        )

        view?.controller.presentWithCardLayout(navigationController, animated: true, completion: nil)
    }
}
