import Foundation
import SubstrateSdk
import Operation_iOS

protocol ExtrinsicBuilderOperationFactoryProtocol {
    func createWrapper(
        customClosure: @escaping ExtrinsicBuilderIndexedClosure,
        indexes: [Int],
        signingClosure: @escaping (Data, ExtrinsicSigningContext) throws -> Data
    ) -> CompoundOperationWrapper<ExtrinsicsCreationResult>

    func createDummySigner(for cryptoType: MultiassetCryptoType) throws -> DummySigner
}

final class ExtrinsicProxyOperationFactory: BaseExtrinsicOperationFactory {
    let proxy: ExtrinsicBuilderOperationFactoryProtocol

    init(
        proxy: ExtrinsicBuilderOperationFactoryProtocol,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        usesStateCallForFee: Bool
    ) {
        self.proxy = proxy

        super.init(
            runtimeRegistry: runtimeRegistry,
            engine: engine,
            operationManager: operationManager,
            usesStateCallForFee: usesStateCallForFee
        )
    }

    override func createDummySigner(for cryptoType: MultiassetCryptoType) throws -> DummySigner {
        try proxy.createDummySigner(for: cryptoType)
    }

    override func createExtrinsicWrapper(
        customClosure: @escaping ExtrinsicBuilderIndexedClosure,
        indexes: [Int],
        signingClosure: @escaping (Data, ExtrinsicSigningContext) throws -> Data
    ) -> CompoundOperationWrapper<ExtrinsicsCreationResult> {
        proxy.createWrapper(
            customClosure: customClosure,
            indexes: indexes,
            signingClosure: signingClosure
        )
    }
}
