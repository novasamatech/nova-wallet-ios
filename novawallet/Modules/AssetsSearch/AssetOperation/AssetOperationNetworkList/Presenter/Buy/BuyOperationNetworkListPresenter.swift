import Foundation

class BuyOperationNetworkListPresenter: AssetOperationNetworkListPresenter, PurchaseFlowManaging {
    let selectedAccount: MetaAccountModel
    let purchaseProvider: PurchaseProviderProtocol

    private let wireframe: BuyAssetOperationWireframeProtocol
    private var purchaseActions: [PurchaseAction] = []

    init(
        interactor: AssetOperationNetworkListInteractorInputProtocol,
        wireframe: BuyAssetOperationWireframeProtocol,
        multichainToken: MultichainToken,
        viewModelFactory: AssetOperationNetworkListViewModelFactory,
        selectedAccount: MetaAccountModel,
        purchaseProvider: PurchaseProviderProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.purchaseProvider = purchaseProvider
        self.wireframe = wireframe

        super.init(
            interactor: interactor,
            multichainToken: multichainToken,
            viewModelFactory: viewModelFactory
        )
    }

    override func provideTitle() {
        let title = R.string.localizable.buyOperationNetworkListTitle(
            multichainToken.symbol,
            preferredLanguages: selectedLocale.rLanguages
        )

        view?.updateHeader(with: title)
    }

    override func selectAsset(with chainAssetId: ChainAssetId) {
        guard let chainAsset = resultModel?.state.chainAsset(for: chainAssetId) else {
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
            wireframe.presentOperationCompletion(
                on: view,
                by: commonCheckResult,
                successRouteClosure: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.startPuchaseFlow(
                        from: self.view,
                        purchaseActions: self.purchaseActions,
                        wireframe: wireframe,
                        locale: selectedLocale
                    )
                }
            )
        case .noBuyOptions:
            break
        }
    }
}

// MARK: ModalPickerViewControllerDelegate

extension BuyOperationNetworkListPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        startPuchaseFlow(
            from: view,
            purchaseAction: purchaseActions[index],
            wireframe: wireframe,
            locale: selectedLocale
        )
    }
}

// MARK: PurchaseDelegate

extension BuyOperationNetworkListPresenter: PurchaseDelegate {
    func purchaseDidComplete() {
        wireframe.presentPurchaseDidComplete(view: view, locale: selectedLocale)
    }
}
