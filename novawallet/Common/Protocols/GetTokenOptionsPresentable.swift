import Foundation

protocol GetTokenOptionsPresentable: RampPresentable, AlertPresentable {
    var assetListObservable: AssetListModelObservable { get }
}

extension GetTokenOptionsPresentable {
    func showGetTokenOptions(
        from view: ControllerBackedProtocol?,
        purchaseHandler: RampFlowManaging & RampDelegate,
        destinationChainAsset: ChainAsset,
        locale: Locale
    ) {
        let completion: GetTokenOptionsCompletion = { [weak self, weak purchaseHandler] result in
            guard let self else {
                return
            }

            switch result {
            case let .crosschains(origins, xcmTransfers):
                showGetTokensByCrosschain(
                    from: view,
                    origins: origins,
                    destination: destinationChainAsset,
                    xcmTransfers: xcmTransfers
                )
            case let .receive(account):
                showGetTokensByReceive(
                    from: view,
                    chainAsset: destinationChainAsset,
                    metaChainAccountResponse: account
                )
            case let .buy(actions):
                purchaseHandler?.startRampFlow(
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
            assetModelObservable: assetListObservable,
            completion: completion
        ) else {
            return
        }

        view?.controller.present(bottomSheet.controller, animated: true)
    }
}

private extension GetTokenOptionsPresentable {
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
            assetListObservable: assetListObservable
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
}
