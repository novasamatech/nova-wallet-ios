import Foundation
import BigInt
import Operation_iOS
import SoraFoundation

final class SellAssetOperationPresenter: AssetsSearchPresenter, OffRampFlowManaging {
    var buyAssetWireframe: BuyAssetOperationWireframeProtocol? {
        wireframe as? BuyAssetOperationWireframeProtocol
    }

    let selectedAccount: MetaAccountModel
    let rampProvider: RampProviderProtocol
    private var purchaseActions: [RampAction] = []

    init(
        interactor: AssetsSearchInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        selectedAccount: MetaAccountModel,
        rampProvider: RampProviderProtocol,
        wireframe: BuyAssetOperationWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.rampProvider = rampProvider

        super.init(
            delegate: nil,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )
    }

    override func selectGroup(with symbol: AssetModel.Symbol) {
        processGroupSelectionWithCheck(
            symbol,
            onSingleInstance: { chainAsset in
                processAssetSelected(chainAsset)
            },
            onMultipleInstances: { multichainToken in
                buyAssetWireframe?.showSelectNetwork(
                    from: view,
                    multichainToken: multichainToken,
                    selectedAccount: selectedAccount,
                    rampProvider: rampProvider
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

        purchaseActions = rampProvider.buildOnRampActions(
            for: chainAsset,
            accountId: accountId
        )

        let checkResult = TokenOperation.checkBuyOperationAvailable(
            rampActions: purchaseActions,
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
                    self.startOffRampFlow(
                        from: self.view,
                        actions: self.purchaseActions,
                        wireframe: self.buyAssetWireframe,
                        assetSymbol: chainAsset.asset.symbol,
                        locale: selectedLocale
                    )
                }
            )
        case .noRampOptions:
            break
        }
    }
}

extension SellAssetOperationPresenter: RampDelegate {
    func rampDidComplete() {
        buyAssetWireframe?.presentOffRampDidComplete(view: view, locale: selectedLocale)
    }
}
