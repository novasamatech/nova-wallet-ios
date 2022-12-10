import Foundation
import SoraFoundation

struct TokensManageAddViewFactory {
    static func createView(for chain: ChainModel) -> TokensManageAddViewProtocol? {
        guard let interactor = createInteractor(for: chain) else {
            return nil
        }

        let wireframe = TokensManageAddWireframe()

        let presenter = TokensManageAddPresenter(interactor: interactor, wireframe: wireframe)

        let view = TokensManageAddViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

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
