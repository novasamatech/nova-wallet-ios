import Foundation
import RobinHood

enum AssetConversionFlowState {
    case assetHub(AssetHubFlowState)
    case hydraOmnipool(HydraOmnipoolFlowState)

    static func createHydraFeeService(
        for flowState: HydraOmnipoolFlowState,
        wallet: MetaAccountModel,
        userStorageFacade: StorageFacadeProtocol
    ) throws -> AssetConversionFeeServiceProtocol {
        guard let account = wallet.fetch(for: flowState.chain.accountRequest()) else {
            throw AssetConversionFeeServiceError.accountMissing
        }

        let extrinsicFactory = ExtrinsicServiceFactory(
            runtimeRegistry: flowState.runtimeProvider,
            engine: flowState.connection,
            operationManager: OperationManager(operationQueue: flowState.operationQueue),
            userStorageFacade: userStorageFacade
        ).createOperationFactory(
            account: account,
            chain: flowState.chain
        )

        let conversionOperationFactory = HydraOmnipoolQuoteFactory(flowState: flowState)

        let swapOperationFactory = HydraOmnipoolExtrinsicOperationFactory(
            chain: flowState.chain,
            swapService: flowState.setupSwapService(),
            runtimeProvider: flowState.runtimeProvider
        )

        return HydraOmnipoolFeeService(
            extrinsicFactory: extrinsicFactory,
            conversionOperationFactory: conversionOperationFactory,
            conversionExtrinsicFactory: swapOperationFactory,
            operationQueue: flowState.operationQueue
        )
    }

    static func createAssetHubFeeService(
        for flowState: AssetHubFlowState,
        chainRegistry: ChainRegistryProtocol,
        wallet: MetaAccountModel,
        userStorageFacade: StorageFacadeProtocol
    ) throws -> AssetConversionFeeServiceProtocol {
        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: flowState.runtimeProvider,
            engine: flowState.connection,
            operationManager: OperationManager(operationQueue: flowState.operationQueue),
            userStorageFacade: userStorageFacade
        )

        let conversionOperationFactory = AssetHubSwapOperationFactory(
            chain: flowState.chain,
            runtimeService: flowState.runtimeProvider,
            connection: flowState.connection,
            operationQueue: flowState.operationQueue
        )

        return AssetHubFeeService(
            wallet: wallet,
            extrinsicServiceFactory: extrinsicServiceFactory,
            conversionOperationFactory: conversionOperationFactory,
            chainRegistry: chainRegistry,
            operationQueue: flowState.operationQueue
        )
    }
}

protocol AssetConversionFlowFacadeProtocol {
    func setup(for chain: ChainModel) throws -> AssetConversionFlowState
}

enum AssetConversionFlowFacadeError: Error {
    case unsupportedChain(ChainModel.Id)
}

final class AssetConversionFlowFacade {
    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    var state: AssetConversionFlowState?

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
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
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        let newState = AssetConversionFlowState.assetHub(assetHub)
        state = newState

        return newState
    }
}

extension AssetConversionFlowFacade: AssetConversionFlowFacadeProtocol {
    func setup(for chain: ChainModel) throws -> AssetConversionFlowState {
        if chain.hasSwaps {
            return try setupAssetHub(for: chain)
        } else {
            throw AssetConversionFlowFacadeError.unsupportedChain(chain.chainId)
        }
    }
}
