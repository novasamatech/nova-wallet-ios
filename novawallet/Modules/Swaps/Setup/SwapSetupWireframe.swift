import Foundation
import Foundation_iOS
import UIKit_iOS

final class SwapSetupWireframe: SwapSetupWireframeProtocol {
    let state: SwapTokensFlowStateProtocol
    let swapCompletionClosure: SwapCompletionClosure?

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

    func showGetTokenOptions(
        form view: ControllerBackedProtocol?,
        purchaseHadler: RampFlowManaging & RampDelegate,
        destinationChainAsset: ChainAsset,
        locale: Locale
    ) {
        let completion: GetTokenOptionsCompletion = { [weak self, weak purchaseHadler] result in
            guard let self = self else {
                return
            }

            switch result {
            case let .crosschains(origins, xcmTransfers):
                self.showGetTokensByCrosschain(
                    from: view,
                    origins: origins,
                    destination: destinationChainAsset,
                    xcmTransfers: xcmTransfers
                )
            case let .receive(account):
                self.showGetTokensByReceive(
                    from: view,
                    chainAsset: destinationChainAsset,
                    metaChainAccountResponse: account
                )
            case let .buy(actions):
                purchaseHadler?.startRampFlow(
                    from: view,
                    actions: actions,
                    rampType: .onRamp,
                    wireframe: self,
                    chainAsset: destinationChainAsset,
                    locale: locale
                )
            }
        }

        guard let bottomSheet = GetTokenOptionsViewFactory.createView(
            from: destinationChainAsset,
            assetModelObservable: state.assetListObservable,
            completion: completion
        ) else {
            return
        }

        view?.controller.present(bottomSheet.controller, animated: true)
    }

    func showGetTokensByCrosschain(
        from view: ControllerBackedProtocol?,
        origins: [ChainAsset],
        destination: ChainAsset,
        xcmTransfers: XcmTransfers
    ) {
        guard let transferView = TransferSetupViewFactory.createCrosschainView(
            from: origins,
            to: destination,
            xcmTransfers: xcmTransfers,
            assetListObservable: state.assetListObservable,
            transferCompletion: nil
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: transferView.controller)

        view?.controller.presentWithCardLayout(navigationController, animated: true)
    }

    func showGetTokensByReceive(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    ) {
        guard let receiveTokensView = AssetReceiveViewFactory.createView(
            chainAsset: chainAsset,
            metaChainAccountResponse: metaChainAccountResponse
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: receiveTokensView.controller)

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
