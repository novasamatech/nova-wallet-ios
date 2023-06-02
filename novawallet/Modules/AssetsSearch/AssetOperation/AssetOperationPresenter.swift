import Foundation
import BigInt
import RobinHood
import SoraFoundation

final class AssetOperationPresenter {
    weak var view: AssetOperationViewProtocol? {
        searchPresenter.view
    }

    let wireframe: AssetOperationWireframeProtocol
    let searchPresenter: AssetsSearchPresenter
    let operation: TokenOperation
    let selectedAccount: MetaAccountModel
    let purchaseProvider: PurchaseProviderProtocol
    private var purchaseActions: [PurchaseAction] = []

    init(
        operation: TokenOperation,
        selectedAccount: MetaAccountModel,
        searchPresenter: AssetsSearchPresenter,
        wireframe: AssetOperationWireframeProtocol,
        localizationManager _: LocalizationManagerProtocol,
        purchaseProvider: PurchaseProviderProtocol
    ) {
        self.searchPresenter = searchPresenter
        self.selectedAccount = selectedAccount
        self.wireframe = wireframe
        self.operation = operation
        self.purchaseProvider = purchaseProvider
        searchPresenter.chainAssetsFilter = Self.filterAsset(
            for: operation,
            selectedAccount: selectedAccount,
            purchaseProvider: purchaseProvider
        )
    }

    private static func filterAsset(
        for operation: TokenOperation,
        selectedAccount: MetaAccountModel,
        purchaseProvider: PurchaseProviderProtocol
    ) -> ChainAssetsFilter? {
        switch operation {
        case .send, .receive:
            return nil
        case .buy:
            return { chainAsset in
                guard let accountId = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                    return false
                }
                let purchaseActions = purchaseProvider.buildPurchaseActions(
                    for: chainAsset,
                    accountId: accountId
                )
                return !purchaseActions.isEmpty
            }
        }
    }

    private func select(chainAsset: ChainAsset) {
        switch operation {
        case .send:
            if TokenOperation.checkTransferOperationAvailable() {
                wireframe.showSendTokens(from: view, chainAsset: chainAsset)
            }
        case .receive:
            let checkResult = TokenOperation.checkReceiveOperationAvailable(
                walletType: selectedAccount.type,
                chainAsset: chainAsset
            )
            handle(receiveCheckResult: checkResult, chainAsset: chainAsset)
        case .buy:
            if let accountId = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId {
                showPurchase(chainAsset: chainAsset, accountId: accountId)
            }
        }
    }

    private func handle(receiveCheckResult: ReceiveAvailableCheckResult, chainAsset: ChainAsset) {
        switch receiveCheckResult {
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
    }

    private func showPurchase(chainAsset: ChainAsset, accountId: AccountId) {
        purchaseActions = purchaseProvider.buildPurchaseActions(for: chainAsset, accountId: accountId)
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
        chainAsset _: ChainAsset,
        availableClosure: () -> Void
    ) {
        guard let view = view else {
            return
        }
        switch checkResult {
        case .available:
            availableClosure()
        case .ledgerNotSupported:
            wireframe.presentSignerNotSupportedView(
                from: view,
                type: .ledger,
                completion: {}
            )
        case .noSigning:
            wireframe.presentNoSigningView(from: view, completion: {})
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
