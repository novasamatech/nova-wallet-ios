import Foundation
import SubstrateSdk
import Operation_iOS

protocol AssetHubFlowStateProtocol {
    func setupReQuoteService() -> AssetHubReQuoteService

    func getReQuoteService() -> ObservableSyncServiceProtocol?

    func createFeeService(using chainRegistry: ChainRegistryProtocol) throws -> AssetConversionFeeServiceProtocol
    func createExtrinsicService() throws -> AssetConversionExtrinsicServiceProtocol
}

final class AssetHubFlowState {
    let wallet: MetaAccountModel
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let userStorageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue

    let mutex = NSLock()

    private var reQuoteService: AssetHubReQuoteService?

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        userStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.chain = chain
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.userStorageFacade = userStorageFacade
        self.operationQueue = operationQueue
    }
}

extension AssetHubFlowState: AssetHubFlowStateProtocol {
    func setupReQuoteService() -> AssetHubReQuoteService {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let reQuoteService = reQuoteService {
            return reQuoteService
        }

        let service = AssetHubReQuoteService(
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        reQuoteService = service
        service.setup()

        return service
    }

    func getReQuoteService() -> ObservableSyncServiceProtocol? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return reQuoteService
    }

    func createFeeService(using chainRegistry: ChainRegistryProtocol) throws -> AssetConversionFeeServiceProtocol {
        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue),
            userStorageFacade: userStorageFacade
        )

        let conversionOperationFactory = AssetHubSwapOperationFactory(
            chain: chain,
            runtimeService: runtimeProvider,
            connection: connection,
            operationQueue: operationQueue
        )

        return AssetHubFeeService(
            wallet: wallet,
            extrinsicServiceFactory: extrinsicServiceFactory,
            conversionOperationFactory: conversionOperationFactory,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
    }

    func createExtrinsicService() throws -> AssetConversionExtrinsicServiceProtocol {
        guard let account = wallet.fetch(for: chain.accountRequest()) else {
            throw ChainAccountFetchingError.accountNotExists
        }

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue),
            userStorageFacade: userStorageFacade
        )

        return AssetHubExtrinsicService(
            account: account,
            chain: chain,
            extrinsicServiceFactory: extrinsicServiceFactory,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )
    }
}
