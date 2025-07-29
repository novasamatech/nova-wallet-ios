import Foundation
import BigInt
import Operation_iOS
import Foundation_iOS

final class RampAssetOperationPresenter: AssetsSearchPresenter {
    weak var rampFlowStartingDelegate: RampFlowStartingDelegate?

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

        rampWireframe?.checkingSupport(
            of: .ramp(
                type: rampType,
                chainAsset: chainAsset,
                all: rampActions
            ),
            for: selectedAccount,
            sheetPresentingView: view
        ) { [weak self] in
            guard let self else { return }

            rampFlowStartingDelegate?.didPickRampParams(
                actions: rampActions,
                rampType: rampType,
                chainAsset: chainAsset
            )
        }
    }
}
