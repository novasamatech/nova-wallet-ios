import Foundation
import Foundation_iOS

protocol SubtensorGetTaoRouting: RampPresentable, AlertPresentable {
    func showGetTao(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        rampHandler: RampFlowManaging & RampDelegate
    )
}

extension SubtensorGetTaoRouting {
    func showGetTao(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        rampHandler: RampFlowManaging & RampDelegate
    ) {
        let observable = AssetListModelObservable(state: .init(value: .init()))

        let completion: GetTokenOptionsCompletion = { [weak self, weak view] result in
            guard let self else {
                return
            }

            switch result {
            case let .crosschains(origins, xcmTransfers):
                showGetTaoByCrosschain(
                    from: view,
                    origins: origins,
                    destination: chainAsset,
                    xcmTransfers: xcmTransfers,
                    observable: observable
                )
            case let .receive(account):
                showGetTaoByReceive(from: view, chainAsset: chainAsset, account: account)
            case let .buy(actions):
                rampHandler.startRampFlow(
                    from: view,
                    actions: actions,
                    rampType: .onRamp,
                    wireframe: self,
                    chainAsset: chainAsset,
                    locale: LocalizationManager.shared.selectedLocale
                )
            }
        }

        guard let optionsView = GetTokenOptionsViewFactory.createView(
            from: chainAsset,
            assetModelObservable: observable,
            completion: completion
        ) else {
            return
        }

        view?.controller.present(optionsView.controller, animated: true)
    }
}

private extension SubtensorGetTaoRouting {
    func showGetTaoByCrosschain(
        from view: ControllerBackedProtocol?,
        origins: [ChainAsset],
        destination: ChainAsset,
        xcmTransfers: XcmTransfers,
        observable: AssetListModelObservable
    ) {
        guard let transferView = TransferSetupViewFactory.createCrosschainView(
            from: origins,
            to: destination,
            xcmTransfers: xcmTransfers,
            assetListObservable: observable
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: transferView.controller)

        view?.controller.presentWithCardLayout(navigationController, animated: true)
    }

    func showGetTaoByReceive(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        account: MetaChainAccountResponse
    ) {
        guard let receiveView = AssetReceiveViewFactory.createView(
            chainAsset: chainAsset,
            metaChainAccountResponse: account
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: receiveView.controller)

        view?.controller.presentWithCardLayout(navigationController, animated: true)
    }
}
