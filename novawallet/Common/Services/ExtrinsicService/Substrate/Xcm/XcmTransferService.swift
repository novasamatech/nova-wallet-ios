import Foundation
import BigInt
import Operation_iOS
import SubstrateSdk

enum XcmTransferServiceError: Error {
    case reserveFeeNotAvailable
    case noXcmPalletFound([String])
    case noArgumentFound(String)
    case deliveryFeeNotAvailable
}

final class XcmTransferService {
    static let weightPerSecond = BigUInt(1_000_000_000_000)

    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let senderResolutionFacade: ExtrinsicSenderResolutionFacadeProtocol
    let operationQueue: OperationQueue
    let metadataHashOperationFactory: MetadataHashOperationFactoryProtocol

    private(set) lazy var xcmFactory = XcmTransferFactory()
    private(set) lazy var xcmPalletQueryFactory = XcmPalletMetadataQueryFactory()
    private(set) lazy var xTokensQueryFactory = XTokensMetadataQueryFactory()

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        senderResolutionFacade: ExtrinsicSenderResolutionFacadeProtocol,
        metadataHashOperationFactory: MetadataHashOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.senderResolutionFacade = senderResolutionFacade
        self.metadataHashOperationFactory = metadataHashOperationFactory
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
        chainAccount: ChainAccountResponse
    ) throws -> ExtrinsicOperationFactoryProtocol {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let senderResolvingFactory = senderResolutionFacade.createResolutionFactory(
            for: chainAccount,
            chainModel: chain
        )

        let feeEstimatingWrapperFactory = ExtrinsicFeeEstimatingWrapperFactory(
            account: chainAccount,
            chain: chain,
            runtimeService: runtimeProvider,
            connection: connection,
            operationQueue: operationQueue
        )

        let feeEstimationRegistry = ExtrinsicFeeEstimationRegistry(
            chain: chain,
            estimatingWrapperFactory: feeEstimatingWrapperFactory
        )

        let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId)

        return ExtrinsicOperationFactory(
            chain: chain,
            runtimeRegistry: runtimeProvider,
            customExtensions: signedExtensionFactory.createExtensions(),
            engine: connection,
            feeEstimationRegistry: feeEstimationRegistry,
            metadataHashOperationFactory: metadataHashOperationFactory,
            senderResolvingFactory: senderResolvingFactory,
            blockHashOperationFactory: BlockHashOperationFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}
