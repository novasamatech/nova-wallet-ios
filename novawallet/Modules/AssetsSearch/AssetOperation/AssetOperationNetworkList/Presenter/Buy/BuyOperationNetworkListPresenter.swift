import Foundation
import SoraFoundation

class BuyOperationNetworkListPresenter: AssetOperationNetworkListPresenter, OnRampFlowManaging {
    let selectedAccount: MetaAccountModel
    let rampProvider: RampProviderProtocol

    private let wireframe: BuyAssetOperationWireframeProtocol
    private var purchaseActions: [RampAction] = []

    init(
        interactor: AssetOperationNetworkListInteractorInputProtocol,
        wireframe: BuyAssetOperationWireframeProtocol,
        multichainToken: MultichainToken,
        viewModelFactory: AssetOperationNetworkListViewModelFactory,
        selectedAccount: MetaAccountModel,
        rampProvider: RampProviderProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.rampProvider = rampProvider
        self.wireframe = wireframe

        super.init(
            interactor: interactor,
            multichainToken: multichainToken,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
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

        purchaseActions = rampProvider.buildOnRampActions(for: chainAsset, accountId: accountId)

        let checkResult = TokenOperation.checkBuyOperationAvailable(
            rampActions: purchaseActions,
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
                    self.startOnRampFlow(
                        from: self.view,
                        actions: self.purchaseActions,
                        wireframe: wireframe,
                        assetSymbol: chainAsset.asset.symbol,
                        locale: selectedLocale
                    )
                }
            )
        case .noBuyOptions:
            break
        }
    }
}

// MARK: PurchaseDelegate

extension BuyOperationNetworkListPresenter: RampDelegate {
    func rampDidComplete() {
        wireframe.presentPurchaseDidComplete(view: view, locale: selectedLocale)
    }
}
