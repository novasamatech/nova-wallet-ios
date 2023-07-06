import Foundation
import BigInt
import RobinHood
import SoraFoundation

final class BuyAssetOperationPresenter: AssetsSearchPresenter {
    var buyAssetWireframe: BuyAssetOperationWireframeProtocol? {
        wireframe as? BuyAssetOperationWireframeProtocol
    }

    let selectedAccount: MetaAccountModel
    let purchaseProvider: PurchaseProviderProtocol
    private var purchaseActions: [PurchaseAction] = []

    init(
        interactor: AssetsSearchInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        selectedAccount: MetaAccountModel,
        purchaseProvider: PurchaseProviderProtocol,
        wireframe: BuyAssetOperationWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.purchaseProvider = purchaseProvider

        super.init(
            delegate: nil,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )
    }

    private func showPurchase() {
        if purchaseActions.count == 1 {
            buyAssetWireframe?.showPurchaseTokens(
                from: view,
                action: purchaseActions[0],
                delegate: self
            )
        } else {
            buyAssetWireframe?.showPurchaseProviders(
                from: view,
                actions: purchaseActions,
                delegate: self
            )
        }
    }

    override func selectAsset(for chainAssetId: ChainAssetId) {
        guard let chainAsset = result?.state.chainAsset(for: chainAssetId) else {
            return
        }
        guard let accountId = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        purchaseActions = purchaseProvider.buildPurchaseActions(for: chainAsset, accountId: accountId)

        let checkResult = TokenOperation.checkBuyOperationAvailable(
            purchaseActions: purchaseActions,
            walletType: selectedAccount.type,
            chainAsset: chainAsset
        )

        switch checkResult {
        case let .common(commonCheckResult):
            buyAssetWireframe?.presentOperationCompletion(
                on: view,
                by: commonCheckResult,
                successRouteClosure: { [weak self] in
                    self?.showPurchase()
                }
            )
        case .noBuyOptions:
            break
        }
    }
}

extension BuyAssetOperationPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        buyAssetWireframe?.showPurchaseTokens(
            from: view,
            action: purchaseActions[index],
            delegate: self
        )
    }
}

extension BuyAssetOperationPresenter: PurchaseDelegate {
    func purchaseDidComplete() {
        let languages = localizationManager?.selectedLocale.rLanguages
        let message = R.string.localizable
            .buyCompleted(preferredLanguages: languages)
        buyAssetWireframe?.presentSuccessAlert(from: view, message: message)
    }
}