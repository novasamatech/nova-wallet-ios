import UIKit
import SoraUI

final class AssetsSelectionWireframe: AssetsSearchWireframeProtocol {
    private let operation: TokenOperation
    private let selectedAccount: MetaAccountModel

    init(
        operation: TokenOperation,
        selectedAccount: MetaAccountModel
    ) {
        self.operation = operation
        self.selectedAccount = selectedAccount
    }

    func finish(
        selection: ChainAsset,
        view: AssetsSearchViewProtocol?
    ) {
        switch operation {
        case .send:
            if TokenOperation.checkTransferOperationAvailable() == true {
                showSendTokens(from: view, chainAsset: selection)
            }
        case .receive:
            let checkResult = TokenOperation.checkReceiveOperationAvailable(walletType: selectedAccount.type,
                                                                            chainAsset: selection)
            handle(checkResult: checkResult) {
                if let metaChainAccountResponse = selectedAccount.fetchMetaChainAccount(for: selection.chain.accountRequest()) {
                    showReceiveTokens(
                        from: view,
                        chainAsset: selection,
                        metaChainAccountResponse: metaChainAccountResponse
                    )
                }
            }
        case .buy:
            let checkResult = TokenOperation.checkReceiveOperationAvailable(walletType: selectedAccount.type,
                                                                            chainAsset: selection)
            
            switch checkResult {
            case .common(let commonCheckResult):
                handle(checkResult: checkResult) {
                    if let metaChainAccountResponse = selectedAccount.fetchMetaChainAccount(for: selection.chain.accountRequest()) {
                        show
                    }
                }
                
                if let metaChainAccountResponse = selectedAccount.fetchMetaChainAccount(for: selection.chain.accountRequest()) {
                    showReceiveTokens(
                        from: view,
                        chainAsset: selection,
                        metaChainAccountResponse: metaChainAccountResponse
                    )
                }
            case .ledgerNotSupported:
                showNoLedgerSupport(from: view, tokenName: selection.asset.symbol)
            case .noSigning:
                showNoKeys(from: view)
            case .noBuyOptions:
                break
            }
        }
    }
    
    func handle(checkResult: OperationCheckCommonResult, availableClosure: () -> Void) {
        switch checkResult {
        case .available:
            availableClosure()
        case .ledgerNotSupported:
            showNoLedgerSupport(from: view, tokenName: selection.asset.symbol)
        case .noSigning:
            showNoKeys(from: view)
        }
    }

    func cancel(from view: AssetsSearchViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }

    func showSendTokens(from view: AssetsSearchViewProtocol?, chainAsset: ChainAsset) {
        guard let transferSetupView = TransferSetupViewFactory.createView(
            from: chainAsset,
            recepient: nil
        ) else {
            return
        }
        view?.controller.navigationController?.pushViewController(transferSetupView.controller, animated: true)
    }

    func showReceiveTokens(
        from view: AssetsSearchViewProtocol?,
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    ) {
        guard let receiveTokensView = AssetReceiveViewFactory.createView(
            chainAsset: chainAsset,
            metaChainAccountResponse: metaChainAccountResponse
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(receiveTokensView.controller, animated: true)
    }

    func showNoLedgerSupport(from view: AssetsSearchViewProtocol?, tokenName: String) {
        guard let confirmationView = LedgerMessageSheetViewFactory.createLedgerNotSupportTokenView(
            for: tokenName,
            cancelClosure: nil
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        view?.controller.present(confirmationView.controller, animated: true)
    }

    func showNoKeys(from view: AssetsSearchViewProtocol?) {
        guard let confirmationView = MessageSheetViewFactory.createNoSigningView(with: {}) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        view?.controller.present(confirmationView.controller, animated: true)
    }

    func showPurchaseProviders(
        from view: AssetsSearchViewProtocol?,
        actions: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate
    ) {
        guard let pickerView = ModalPickerFactory.createPickerForList(
            actions,
            delegate: delegate,
            context: nil
        ) else {
            return
        }
        guard let navigationController = view?.controller.navigationController else {
            return
        }
        navigationController.present(pickerView, animated: true)
    }
    
    func showPurchaseTokens(
        from view: AssetsSearchViewProtocol?,
        action: PurchaseAction,
        delegate: PurchaseDelegate
    ) {
        guard let purchaseView = PurchaseViewFactory.createView(
            for: action,
            delegate: delegate
        ) else {
            return
        }
        purchaseView.controller.modalPresentationStyle = .fullScreen
        view?.controller.present(purchaseView.controller, animated: true)
    }
    
    func presentSuccessAlert(from view: AssetDetailsViewProtocol?, message: String) {
        let alertController = ModalAlertFactory.createMultilineSuccessAlert(message)
        view?.controller.present(alertController, animated: true)
    }

}

extension AssetsSelectionWireframe: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        showPurchaseTokens(
            from: view,
            action: purchaseActions[index],
            delegate: self
        )
    }
}

extension AssetsSelectionWireframe: PurchaseDelegate {
    func purchaseDidComplete() {
        let languages = selectedLocale.rLanguages
        let message = R.string.localizable
            .buyCompleted(preferredLanguages: languages)
        presentSuccessAlert(from: view, message: message)
    }
}
