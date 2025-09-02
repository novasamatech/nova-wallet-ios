import Foundation
import Foundation_iOS

struct TokensManageAddViewFactory {
    static func createView(for chain: ChainModel) -> TokensManageAddViewProtocol? {
        guard let interactor = createInteractor(for: chain) else {
            return nil
        }

        let wireframe = TokensManageAddWireframe()

        let validationFactory = TokenAddValidationFactory(wireframe: wireframe)

        let presenter = TokensManageAddPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            validationFactory: validationFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = TokensManageAddViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        validationFactory.view = view

        return view
    }

    private static func createInteractor(for chain: ChainModel) -> TokensManageAddInteractor? {
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: chain.chainId) else {
            return nil
        }

        let chainRepository = ChainRepositoryFactory(storageFacade: SubstrateDataStorageFacade.shared)
        let repository = chainRepository.createRepository()

        return .init(
            chain: chain,
            connection: connection,
            queryFactory: EvmQueryContractMessageFactory(),
            priceIdParser: CoingeckoUrlParser(),
            priceOperationFactory: CoingeckoOperationFactory(),
            chainRepository: repository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
