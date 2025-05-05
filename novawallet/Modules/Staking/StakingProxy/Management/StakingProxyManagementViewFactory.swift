import Foundation
import Foundation_iOS
import SubstrateSdk

struct StakingProxyManagementViewFactory {
    static func createView(state: RelaychainStakingSharedStateProtocol) -> StakingProxyManagementViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)
        let identityProxyFactory = IdentityProxyFactory(
            originChain: chainAsset.chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let interactor = StakingProxyManagementInteractor(
            selectedAccount: selectedAccount,
            sharedState: state,
            identityProxyFactory: identityProxyFactory,
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
