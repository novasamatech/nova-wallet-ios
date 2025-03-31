import Foundation
import BigInt
import Operation_iOS
import SoraFoundation

final class RampAssetOperationPresenter: AssetsSearchPresenter, RampFlowManaging {
    var rampWireframe: RampAssetOperationWireframeProtocol? {
        wireframe as? RampAssetOperationWireframeProtocol
    }

    let selectedAccount: MetaAccountModel
    let rampProvider: RampProviderProtocol
    let rampType: RampActionType

    init(
        interactor: AssetsSearchInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        selectedAccount: MetaAccountModel,
        rampProvider: RampProviderProtocol,
        rampType: RampActionType,
        wireframe: RampAssetOperationWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.rampProvider = rampProvider
        self.rampType = rampType

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
                rampWireframe?.showSelectNetwork(
                    from: view,
                    multichainToken: multichainToken,
                    selectedAccount: selectedAccount,
                    rampProvider: rampProvider,
                    rampType: rampType
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

        let rampActions = rampProvider.buildRampActions(
            for: chainAsset,
            accountId: accountId
        )

        let checkResult = TokenOperation.checkRampOperationsAvailable(
            for: rampActions,
            rampType: rampType,
            walletType: selectedAccount.type,
            chainAsset: chainAsset
        )

        switch checkResult {
        case let .common(commonCheckResult):
            rampWireframe?.presentOperationCompletion(
                on: view,
                by: commonCheckResult,
                successRouteClosure: { [weak self] in
                    guard let self else { return }

                    startRampFlow(
                        from: view,
                        actions: rampActions,
                        rampType: rampType,
                        wireframe: rampWireframe,
                        chainAsset: chainAsset,
                        locale: selectedLocale
                    )
                }
            )
        case .noRampOptions:
            break
        }
    }
}

extension RampAssetOperationPresenter: RampDelegate {
    func rampDidComplete(action: RampActionType) {
        rampWireframe?.presentRampDidComplete(
            view: view,
            action: action,
            locale: selectedLocale
        )
    }
}
