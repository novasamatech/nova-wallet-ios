import RobinHood
import SoraKeystore
import SubstrateSdk

protocol ExtrinsicServiceFactoryProtocol {
    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicExtension]
    ) -> ExtrinsicServiceProtocol

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicExtension]
    ) -> ExtrinsicOperationFactoryProtocol
}

extension ExtrinsicServiceFactoryProtocol {
    func createService(
        account: ChainAccountResponse,
        chain: ChainModel
    ) -> ExtrinsicServiceProtocol {
        createService(
            account: account,
            chain: chain,
            extensions: DefaultExtrinsicExtension.extensions()
        )
    }

    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        feeAssetConversionId: AssetConversionPallet.AssetId
    ) -> ExtrinsicServiceProtocol {
        createService(
            account: account,
            chain: chain,
            extensions: DefaultExtrinsicExtension.extensions(payingFeeIn: feeAssetConversionId)
        )
    }

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel
    ) -> ExtrinsicOperationFactoryProtocol {
        createOperationFactory(
            account: account,
            chain: chain,
            extensions: DefaultExtrinsicExtension.extensions()
        )
    }

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        feeAssetConversionId: AssetConversionPallet.AssetId
    ) -> ExtrinsicOperationFactoryProtocol {
        createOperationFactory(
            account: account,
            chain: chain,
            extensions: DefaultExtrinsicExtension.extensions(payingFeeIn: feeAssetConversionId)
        )
    }
}

final class ExtrinsicServiceFactory {
    private let runtimeRegistry: RuntimeCodingServiceProtocol
    private let engine: JSONRPCEngine
    private let operationManager: OperationManagerProtocol

    init(
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol
    ) {
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine
        self.operationManager = operationManager
    }
}

extension ExtrinsicServiceFactory: ExtrinsicServiceFactoryProtocol {
    func createService(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicExtension]
    ) -> ExtrinsicServiceProtocol {
        ExtrinsicService(
            accountId: account.accountId,
            chain: chain,
            cryptoType: account.cryptoType,
            walletType: account.type,
            runtimeRegistry: runtimeRegistry,
            extensions: extensions,
            engine: engine,
            operationManager: operationManager
        )
    }

    func createOperationFactory(
        account: ChainAccountResponse,
        chain: ChainModel,
        extensions: [ExtrinsicExtension]
    ) -> ExtrinsicOperationFactoryProtocol {
        ExtrinsicOperationFactory(
            accountId: account.accountId,
            chain: chain,
            cryptoType: account.cryptoType,
            signaturePayloadFormat: account.type.signaturePayloadFormat,
            runtimeRegistry: runtimeRegistry,
            customExtensions: extensions,
            engine: engine,
            operationManager: operationManager
        )
    }
}
