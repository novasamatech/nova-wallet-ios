import Foundation
import SubstrateSdk
import Operation_iOS
import Foundation_iOS

struct ReferendumOnChainVotersViewFactory {
    static func createView(
        state: GovernanceSharedState,
        referendum: ReferendumLocal,
        type: ReferendumVotersType
    ) -> VotesViewProtocol? {
        guard
            let interactor = createInteractor(
                for: state,
                votersType: type,
                referendum: referendum
            ),
            let chain = state.settings.value?.chain
        else {
            return nil
        }

        let wireframe = ReferendumVotersWireframe()

        let localizationManager = LocalizationManager.shared

        let referendumDisplayStringFactory = ReferendumDisplayStringFactory()

        let presenter = ReferendumVotersPresenter(
            interactor: interactor,
            wireframe: wireframe,
            type: type,
            referendum: referendum,
            chain: chain,
            stringFactory: referendumDisplayStringFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = VotesViewController(
            presenter: presenter,
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: GovernanceSharedState,
        votersType: ReferendumVotersType,
        referendum: ReferendumLocal
    ) -> ReferendumVotersInteractor? {
        guard let chain = state.settings.value?.chain else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let referendumsOperationFactory = state.referendumsOperationFactory else {
            return nil
        }

        let operationQueue = OperationQueue()

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        let identityProxyFactory = IdentityProxyFactory(
            originChain: chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let delegationApi = chain.externalApis?.governanceDelegations()?.first

        let votersLocalWrapperFactory: ReferendumVotersLocalWrapperFactoryProtocol? = if let delegationApi {
            ReferendumVotersLocalWrapperFactory(
                chain: chain,
                operationFactory: SubqueryVotingOperationFactory(url: delegationApi.url),
                identityProxyFactory: identityProxyFactory,
                metadataOperationFactory: GovernanceDelegateMetadataFactory()
            )
        } else {
            nil
        }

        return ReferendumVotersInteractor(
            referendumIndex: referendum.index,
            chain: chain,
            votersType: votersType,
            referendumsOperationFactory: referendumsOperationFactory,
            votersLocalWrapperFactory: votersLocalWrapperFactory,
            identityProxyFactory: identityProxyFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )
    }
}
