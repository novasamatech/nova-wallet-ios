import Foundation
import Foundation_iOS

final class RampOperationNetworkListPresenter: AssetOperationNetworkListPresenter {
    let selectedAccount: MetaAccountModel
    
    weak var delegate: RampFlowStartingDelegate?

    private let wireframe: RampAssetOperationWireframeProtocol
    private let rampProvider: RampProviderProtocol
    private let rampType: RampActionType

    init(
        interactor: AssetOperationNetworkListInteractorInputProtocol,
        wireframe: RampAssetOperationWireframeProtocol,
        rampProvider: RampProviderProtocol,
        rampType: RampActionType,
        multichainToken: MultichainToken,
        viewModelFactory: AssetOperationNetworkListViewModelFactory,
        selectedAccount: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.wireframe = wireframe
        self.rampProvider = rampProvider
        self.rampType = rampType

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
            wireframe.presentOperationCompletion(
                on: view,
                by: commonCheckResult,
                successRouteClosure: { [weak self] in
                    guard let self else { return }

                    delegate?.didPickRampParams(
                        actions: rampActions,
                        rampType: rampType,
                        chainAsset: chainAsset
                    )
                }
            )
        case .noRampOptions:
            break
        }
    }
}
