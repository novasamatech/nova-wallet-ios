import Foundation
import SoraFoundation
import SubstrateSdk

struct StakingProxyManagementViewFactory {
    static func createView(state: RelaychainStakingSharedStateProtocol) -> StakingProxyManagementViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeRegistry = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )
        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)

        let interactor = StakingProxyManagementInteractor(
            selectedAccount: selectedAccount,
            sharedState: state,
            identityOperationFactory: identityOperationFactory,
            connection: connection,
            runtimeProvider: runtimeRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = StakingProxyManagementWireframe(state: state)

        let presenter = StakingProxyManagementPresenter(
            chainAsset: chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = StakingProxyManagementViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
