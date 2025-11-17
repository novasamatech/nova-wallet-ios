import Foundation
import UIKit

class GiftTransferSetupWireframe {
    let assetListObservable: AssetListModelObservable
    let buyTokensClosure: BuyTokensClosure?
    let transferCompletion: TransferCompletionClosure?

    init(
        assetListStateObservable: AssetListModelObservable,
        buyTokensClosure: BuyTokensClosure?,
        transferCompletion: TransferCompletionClosure?
    ) {
        assetListObservable = assetListStateObservable
        self.buyTokensClosure = buyTokensClosure
        self.transferCompletion = transferCompletion
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
            assetListObservable: assetListObservable,
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
}

extension GiftTransferSetupWireframe: GiftTransferSetupWireframeProtocol {
    func showConfirmation(
        from view: (any GiftTransferSetupViewProtocol)?,
        chainAsset: ChainAsset,
        sendingAmount: OnChainTransferAmount<Decimal>
    ) {
        guard let confirmView = GiftTransferConfirmViewFactory.createView(
            from: chainAsset,
            amount: sendingAmount,
            transferCompletion: transferCompletion
        ) else { return }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }

    func showGetTokenOptions(
        from view: ControllerBackedProtocol?,
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
            assetModelObservable: assetListObservable,
            completion: completion
        ) else {
            return
        }

        view?.controller.present(bottomSheet.controller, animated: true)
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
