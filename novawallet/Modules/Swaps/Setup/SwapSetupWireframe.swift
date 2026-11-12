import UIKit
import Foundation
import Foundation_iOS
import UIKit_iOS

final class SwapSetupWireframe: SwapSetupWireframeProtocol {
    let state: SwapTokensFlowStateProtocol
    let tokenSelectionFlow: SwapTokenSelectionFlowProtocol
    let flowHandler: SwapExecutionFlowHandling

    var assetListObservable: AssetListModelObservable { state.assetListObservable }

    init(
        state: SwapTokensFlowStateProtocol,
        tokenSelectionFlow: SwapTokenSelectionFlowProtocol,
        flowHandler: SwapExecutionFlowHandling
    ) {
        self.state = state
        self.tokenSelectionFlow = tokenSelectionFlow
        self.flowHandler = flowHandler
    }

    func showPayTokenSelection(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset?,
        completionHandler: @escaping (ChainAsset) -> Void
    ) {
        tokenSelectionFlow.showTokenSelection(
            from: view,
            side: .pay,
            counterpart: chainAsset
        ) { result in
            switch result {
            case let .selected(selectedChainAsset):
                completionHandler(selectedChainAsset)
            }
        }
    }

    func showReceiveTokenSelection(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset?,
        completionHandler: @escaping (ChainAsset) -> Void
    ) {
        tokenSelectionFlow.showTokenSelection(
            from: view,
            side: .receive,
            counterpart: chainAsset
        ) { result in
            switch result {
            case let .selected(selectedChainAsset):
                completionHandler(selectedChainAsset)
            }
        }
    }

    func showSettings(
        from view: ControllerBackedProtocol?,
        percent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) {
        guard let settingsView = SwapSlippageViewFactory.createSettingsSheet(
            percent: percent,
            chainAsset: chainAsset,
            completionHandler: completionHandler
        ) else {
            return
        }

        view?.controller.present(settingsView.controller, animated: true)
    }

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        initState: SwapConfirmInitState
    ) {
        guard let confimView = SwapConfirmViewFactory.createView(
            initState: initState,
            flowState: state,
            flowHandler: flowHandler
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: confimView.controller)

        view?.controller.presentWithCardLayout(navigationController, animated: true)
    }

    func showRouteDetails(
        from view: ControllerBackedProtocol?,
        quote: AssetExchangeQuote,
        fee: AssetExchangeFee
    ) {
        guard
            let routeDetailsView = SwapRouteDetailsViewFactory.createView(
                for: quote,
                fee: fee,
                state: state
            ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: routeDetailsView.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func showFeeDetails(
        from view: ControllerBackedProtocol?,
        operations: [AssetExchangeMetaOperationProtocol],
        fee: AssetExchangeFee
    ) {
        guard
            let routeDetailsView = SwapFeeDetailsViewFactory.createView(
                for: operations,
                fee: fee,
                state: state
            ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: routeDetailsView.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func popTopControllers(
        from view: ControllerBackedProtocol?,
        completion: @escaping () -> Void
    ) {
        guard let controller = view?.controller else { return }

        if let presentedViewController = controller.presentedViewController {
            // In case we have many providers, selection screen is presented modally
            presentedViewController.dismiss(
                animated: true,
                completion: completion
            )
        } else {
            // In case we have single provider, ramp screen is pushed on navigation stack
            CATransaction.begin()
            CATransaction.setCompletionBlock { completion() }

            controller.navigationController?.popToViewController(
                controller,
                animated: true
            )

            CATransaction.commit()
        }
    }
}
