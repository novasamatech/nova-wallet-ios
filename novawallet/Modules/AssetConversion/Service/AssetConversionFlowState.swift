import Foundation
import RobinHood

enum AssetConversionFlowState {
    case assetHub(AssetHubFlowState)
    case hydraOmnipool(HydraOmnipoolFlowState)
}

protocol AssetConversionFlowFacadeProtocol {
    var generalSubscriptonFactory: GeneralStorageSubscriptionFactoryProtocol { get }

    func setup(for chain: ChainModel) throws -> AssetConversionFlowState

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
}

extension AssetConversionFlowFacade: AssetConversionFlowFacadeProtocol {
    func setup(for chain: ChainModel) throws -> AssetConversionFlowState {
        if chain.hasSwaps {
            return try setupAssetHub(for: chain)
        } else {
            throw AssetConversionFlowFacadeError.unsupportedChain(chain.chainId)
        }
    }

    func createFeeService(for chain: ChainModel) throws -> AssetConversionFeeServiceProtocol {
        let state = try setup(for: chain)

        switch state {
        case let .assetHub(assetHub):
            return try assetHub.createFeeService(using: chainRegistry)
        case let .hydraOmnipool(hydra):
            return try hydra.createFeeService()
        }
    }

    func createExtrinsicService(for chain: ChainModel) throws -> AssetConversionExtrinsicServiceProtocol {
        let state = try setup(for: chain)

        switch state {
        case let .assetHub(assetHub):
            return try assetHub.createExtrinsicService()
        case let .hydraOmnipool(hydra):
            return try hydra.createExtrinsicService()
        }
    }
}
