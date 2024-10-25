import Foundation
import BigInt
import Operation_iOS
import SoraFoundation

final class BuyAssetOperationPresenter: AssetOperationPresenter, PurchaseFlowManaging {
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

    override func selectGroup(with symbol: AssetModel.Symbol) {
        processWithCheck(
            symbol,
            onSingleInstance: { chainAsset in
                processAssetSelected(chainAsset)
            },
            onMultipleInstances: { multichainToken in
                buyAssetWireframe?.showSelectNetwork(
                    from: view,
                    multichainToken: multichainToken,
                    selectedAccount: selectedAccount,
                    purchaseProvider: purchaseProvider
                )
            }
        )
    }

    override func selectAsset(for chainAssetId: ChainAssetId) {
        guard let chainAsset = result?.state.chainAsset(for: chainAssetId) else {
            return
        }

        processAssetSelected(chainAsset)
    }

    private func processAssetSelected(_ chainAsset: ChainAsset) {
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
                    self.startPuchaseFlow(
                        from: self.view,
                        purchaseActions: self.purchaseActions,
                        wireframe: self.buyAssetWireframe,
                        locale: selectedLocale
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
        startPuchaseFlow(
            from: view,
            purchaseAction: purchaseActions[index],
            wireframe: buyAssetWireframe,
            locale: selectedLocale
        )
    }
}

extension BuyAssetOperationPresenter: PurchaseDelegate {
    func purchaseDidComplete() {
        buyAssetWireframe?.presentPurchaseDidComplete(view: view, locale: selectedLocale)
    }
}
