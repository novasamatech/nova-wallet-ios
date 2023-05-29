import Foundation
import BigInt
import RobinHood
import SoraFoundation

final class AssetOperationPresenter {
    weak var view: AssetsSearchViewProtocol? {
        searchPresenter.view
    }

    let wireframe: AssetOperationWireframeProtocol
    let searchPresenter: AssetsSearchPresenter
    let operation: TokenOperation
    let selectedAccount: MetaAccountModel
    let purchaseActions: [PurchaseAction] = []

    init(
        operation: TokenOperation,
        selectedAccount: MetaAccountModel,
        searchPresenter: AssetsSearchPresenter,
        wireframe: AssetOperationWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.searchPresenter = searchPresenter
        self.selectedAccount = selectedAccount
        self.wireframe = wireframe
        self.operation = operation
        self.localizationManager = localizationManager
    }

    private func select(chainAsset: ChainAsset) {
        switch operation {
        case .send:
            if TokenOperation.checkTransferOperationAvailable() == true {
                wireframe.showSendTokens(from: view, chainAsset: chainAsset)
            }
        case .receive:
            let checkResult = TokenOperation.checkReceiveOperationAvailable(
                walletType: selectedAccount.type,
                chainAsset: chainAsset
            )
            switch checkResult {
            case let .common(operationCheckCommonResult):
                handle(checkResult: operationCheckCommonResult, chainAsset: chainAsset) {
                    if let metaChainAccountResponse = selectedAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()) {
                        wireframe.showReceiveTokens(
                            from: view,
                            chainAsset: chainAsset,
                            metaChainAccountResponse: metaChainAccountResponse
                        )
                    }
                }
            }
        case .buy:
            let checkResult = TokenOperation.checkBuyOperationAvailable(
                purchaseActions: purchaseActions,
                walletType: selectedAccount.type,
                chainAsset: chainAsset
            )

            switch checkResult {
            case let .common(commonCheckResult):
                handle(checkResult: commonCheckResult, chainAsset: chainAsset) {
                    if let metaChainAccountResponse = selectedAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()) {
                        showPurchase()
                    }
                }
            case .noBuyOptions:
                break
            }
        }
    }

    private func showPurchase() {
        guard !purchaseActions.isEmpty else {
            return
        }
        if purchaseActions.count == 1 {
            wireframe.showPurchaseTokens(
                from: view,
                action: purchaseActions[0],
                delegate: self
            )
        } else {
            wireframe.showPurchaseProviders(
                from: view,
                actions: purchaseActions,
                delegate: self
            )
        }
    }

    func handle(
        checkResult: OperationCheckCommonResult,
        chainAsset: ChainAsset,
        availableClosure: () -> Void
    ) {
        switch checkResult {
        case .available:
            availableClosure()
        case .ledgerNotSupported:
            wireframe.showNoLedgerSupport(
                from: view,
                tokenName: chainAsset.asset.symbol
            )
        case .noSigning:
            wireframe.showNoKeys(from: view)
        }
    }
}

extension AssetOperationPresenter: AssetsSearchPresenterProtocol {
    func setup() {
        searchPresenter.setup()
    }

    func selectAsset(for chainAssetId: ChainAssetId) {
        let chainId = chainAssetId.chainId
        let assetId = chainAssetId.assetId

        guard let chain = searchPresenter.allChains[chainId],
              let asset = chain.assets.first(where: { $0.assetId == assetId }) else {
            return
        }

        select(chainAsset: .init(chain: chain, asset: asset))
    }

    func updateSearch(query: String) {
        searchPresenter.updateSearch(query: query)
    }

    func cancel() {
        wireframe.close(view: view)
    }
}

extension AssetOperationPresenter: Localizable {
    func applyLocalization() {
        searchPresenter.applyLocalization()
    }
}

extension AssetOperationPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        wireframe.showPurchaseTokens(
            from: view,
            action: purchaseActions[index],
            delegate: self
        )
    }
}

extension AssetOperationPresenter: PurchaseDelegate {
    func purchaseDidComplete() {
        let languages = selectedLocale.rLanguages
        let message = R.string.localizable
            .buyCompleted(preferredLanguages: languages)
        wireframe.presentSuccessAlert(from: view, message: message)
    }
}
