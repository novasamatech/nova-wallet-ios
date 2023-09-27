import Foundation
import BigInt
import RobinHood
import SoraFoundation

final class BuyAssetOperationPresenter: AssetsSearchPresenter & BuyPresentable {
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
                    guard let self = self else {
                        return
                    }
                    self.buyTokens(
                        from: self.view,
                        purchaseActions: self.purchaseActions,
                        wireframe: self.buyAssetWireframe
                    )
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
        buyAssetWireframe?.presentPurchaseDidComplete(view: view, locale: selectedLocale)
    }
}
