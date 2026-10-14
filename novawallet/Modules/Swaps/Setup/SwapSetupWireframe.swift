import UIKit
import Foundation
import Foundation_iOS
import UIKit_iOS

final class SwapSetupWireframe: SwapSetupWireframeProtocol {
    let state: SwapTokensFlowStateProtocol
    let swapCompletionClosure: SwapCompletionClosure?

    var assetListObservable: AssetListModelObservable { state.assetListObservable }

    init(
        state: SwapTokensFlowStateProtocol,
        swapCompletionClosure: SwapCompletionClosure?
    ) {
        self.state = state
        self.swapCompletionClosure = swapCompletionClosure
    }

    func showPayTokenSelection(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset?,
        completionHandler: @escaping (ChainAsset) -> Void
    ) {
        guard let selectTokenView = SwapAssetsOperationViewFactory.createSelectPayTokenViewWithState(
            state,
            selectionModel: .payForAsset(chainAsset),
            selectClosure: { chainAsset, _ in
                completionHandler(chainAsset)
            }
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: selectTokenView.controller
        )

        view?.controller.presentWithCardLayout(navigationController, animated: true, completion: nil)
    }

    func showReceiveTokenSelection(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset?,
        completionHandler: @escaping (ChainAsset) -> Void
    ) {
        guard let selectTokenView = SwapAssetsOperationViewFactory.createSelectReceiveTokenViewWithState(
            state,
            selectionModel: .receivePayingWith(chainAsset),
            selectClosure: { chainAsset, _ in
                completionHandler(chainAsset)
            }
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: selectTokenView.controller
        )

        view?.controller.presentWithCardLayout(navigationController, animated: true, completion: nil)
    }

    func showSettings(
        from view: ControllerBackedProtocol?,
        percent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) {
        guard let settingsView = SwapSlippageViewFactory.createView(
            percent: percent,
            chainAsset: chainAsset,
            completionHandler: completionHandler
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            settingsView.controller,
            animated: true
        )
    }

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        initState: SwapConfirmInitState
    ) {
        guard let confimView = SwapConfirmViewFactory.createView(
            initState: initState,
            flowState: state,
            completionClosure: swapCompletionClosure
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confimView.controller,
            animated: true
        )
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
