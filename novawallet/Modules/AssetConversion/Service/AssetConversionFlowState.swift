import Foundation
import Operation_iOS

enum AssetConversionFlowState {
    case assetHub(AssetHubFlowState)
    case hydra(HydraFlowState)
}

protocol AssetConversionFlowFacadeProtocol {
    var generalSubscriptonFactory: GeneralStorageSubscriptionFactoryProtocol { get }

    func setup(for chain: ChainModel) throws -> AssetConversionFlowState
    func getReQuoteService(
        for assetIn: ChainAssetId,
        assetOut: ChainAssetId
    ) -> ObservableSyncServiceProtocol?

    func createFeeService(for chain: ChainModel) throws -> AssetConversionFeeServiceProtocol
    func createExtrinsicService(for chain: ChainModel) throws -> AssetConversionExtrinsicServiceProtocol
}

enum AssetConversionFlowFacadeError: Error {
    case unsupportedChain(ChainModel.Id)
}

final class AssetConversionFlowFacade {
    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let userStorageFacade: StorageFacadeProtocol
    let generalSubscriptonFactory: GeneralStorageSubscriptionFactoryProtocol

    var state: AssetConversionFlowState?

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        userStorageFacade: StorageFacadeProtocol,
        generalSubscriptonFactory: GeneralStorageSubscriptionFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.userStorageFacade = userStorageFacade
        self.generalSubscriptonFactory = generalSubscriptonFactory
        self.operationQueue = operationQueue
    }

    func setupAssetHub(for chain: ChainModel) throws -> AssetConversionFlowState {
        if
            let currentState = state,
            case let .assetHub(assetHub) = currentState,
            assetHub.chain.chainId == chain.chainId {
            return currentState
        }

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let assetHub = AssetHubFlowState(
            wallet: wallet,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            userStorageFacade: userStorageFacade,
            operationQueue: operationQueue
        )

        let newState = AssetConversionFlowState.assetHub(assetHub)
        state = newState

        return newState
    }

    func setupHydra(for chain: ChainModel) throws -> AssetConversionFlowState {
        if
            let currentState = state,
            case let .hydra(hydra) = currentState,
            hydra.chain.chainId == chain.chainId {
            return currentState
        }

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        guard let account = wallet.fetch(for: chain.accountRequest()) else {
            throw ChainAccountFetchingError.accountNotExists
        }

        let hydra = HydraFlowState(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            userStorageFacade: userStorageFacade,
            operationQueue: operationQueue
        )

        let newState = AssetConversionFlowState.hydra(hydra)
        state = newState

        return newState
    }
}

extension AssetConversionFlowFacade: AssetConversionFlowFacadeProtocol {
    func setup(for chain: ChainModel) throws -> AssetConversionFlowState {
        if chain.hasSwapHub {
            return try setupAssetHub(for: chain)
        } else if chain.hasSwapHydra {
            return try setupHydra(for: chain)
        } else {
            throw AssetConversionFlowFacadeError.unsupportedChain(chain.chainId)
        }
    }

    func getReQuoteService(
        for assetIn: ChainAssetId,
        assetOut: ChainAssetId
    ) -> ObservableSyncServiceProtocol? {
        switch state {
        case let .assetHub(assetHub):
            return assetHub.getReQuoteService()
        case let .hydra(hydra):
            return hydra.getReQuoteService(for: assetIn, assetOut: assetOut)
        case .none:
            return nil
        }
    }

    func createFeeService(for chain: ChainModel) throws -> AssetConversionFeeServiceProtocol {
        let state = try setup(for: chain)

        switch state {
        case let .assetHub(assetHub):
            return try assetHub.createFeeService(using: chainRegistry)
        case let .hydra(hydra):
            return try hydra.createFeeService()
        }
    }

    func createExtrinsicService(for chain: ChainModel) throws -> AssetConversionExtrinsicServiceProtocol {
        let state = try setup(for: chain)

        switch state {
        case let .assetHub(assetHub):
            return try assetHub.createExtrinsicService()
        case let .hydra(hydra):
            return try hydra.createExtrinsicService()
        }
    }
}
