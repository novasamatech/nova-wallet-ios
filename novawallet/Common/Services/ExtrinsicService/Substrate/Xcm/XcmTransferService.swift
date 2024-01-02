import Foundation
import BigInt
import RobinHood
import SubstrateSdk

enum XcmTransferServiceError: Error {
    case reserveFeeNotAvailable
    case noXcmPalletFound([String])
    case noArgumentFound(String)
}

final class XcmTransferService {
    static let weightPerSecond = BigUInt(1_000_000_000_000)

    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let userStorageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue

    private(set) lazy var xcmFactory = XcmTransferFactory()
    private(set) lazy var xcmPalletQueryFactory = XcmPalletMetadataQueryFactory()
    private(set) lazy var xTokensQueryFactory = XTokensMetadataQueryFactory()

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        userStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.userStorageFacade = userStorageFacade
        self.operationQueue = operationQueue
    }

    func createModuleResolutionWrapper(
        for transferType: XcmAssetTransfer.TransferType,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String> {
        switch transferType {
        case .xtokens:
            return xTokensQueryFactory.createModuleNameResolutionWrapper(for: runtimeProvider)
        case .xcmpallet, .teleport:
            return xcmPalletQueryFactory.createModuleNameResolutionWrapper(for: runtimeProvider)
        case .unknown:
            return CompoundOperationWrapper.createWithError(XcmAssetTransfer.TransferTypeError.unknownType)
        }
    }

    func createExtrinsicOperationFactory(
        for chain: ChainModel,
        chainAccount: ChainAccountResponse?
    ) throws -> ExtrinsicOperationFactoryProtocol {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let senderResolvingFactory = ExtrinsicSenderResolutionFactory(
            chainAccount: chainAccount,
            chain: chain,
            userStorageFacade: userStorageFacade
        )

        return ExtrinsicOperationFactory(
            chain: chain,
            runtimeRegistry: runtimeProvider,
            customExtensions: DefaultExtrinsicExtension.extensions(),
            engine: connection,
            senderResolvingFactory: senderResolvingFactory,
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}
