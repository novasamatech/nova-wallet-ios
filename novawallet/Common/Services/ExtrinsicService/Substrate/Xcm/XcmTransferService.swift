import Foundation
import BigInt
import RobinHood
import SubstrateSdk

enum XcmTransferServiceError: Error {
    case reserveFeeNotAvailable
    case noXcmPalletFound
    case noArgumentFound(String)
}

final class XcmTransferService {
    static let weightPerSecond = BigUInt(1_000_000_000_000)

    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    private(set) lazy var xcmFactory = XcmTransferFactory()
    private(set) lazy var metadataQueryFactory = XcmPalletMetadataQueryFactory()

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }

    func createModuleResolutionWrapper(
        for transferType: XcmAssetTransfer.TransferType,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String> {
        switch transferType {
        case .xtokens:
            return CompoundOperationWrapper.createWithResult("XTokens")
        case .xcmpallet, .teleport:
            return metadataQueryFactory.createModuleNameResolutionWrapper(for: runtimeProvider)
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

        let accountId: AccountId
        let cryptoType: MultiassetCryptoType
        let signaturePayloadFormat: ExtrinsicSignaturePayloadFormat

        if let chainAccount = chainAccount {
            accountId = chainAccount.accountId
            cryptoType = chainAccount.cryptoType
            signaturePayloadFormat = chainAccount.type.signaturePayloadFormat
        } else {
            // account doesn't exists but we still might want to calculate fee
            accountId = AccountId.zeroAccountId(of: chain.accountIdSize)
            cryptoType = chain.isEthereumBased ? .ethereumEcdsa : .sr25519
            signaturePayloadFormat = .regular
        }

        return ExtrinsicOperationFactory(
            accountId: accountId,
            chain: chain,
            cryptoType: cryptoType,
            signaturePayloadFormat: signaturePayloadFormat,
            runtimeRegistry: runtimeProvider,
            customExtensions: DefaultExtrinsicExtension.extensions,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}
