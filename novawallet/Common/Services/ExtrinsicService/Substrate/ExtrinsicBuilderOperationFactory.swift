import Foundation
import SubstrateSdk
import RobinHood

protocol ExtrinsicBuilderOperationFactoryProtocol {
    func createWrapper(
        customClosure: @escaping ExtrinsicBuilderIndexedClosure,
        indexes: [Int],
        signingClosure: @escaping (Data) throws -> Data
    ) -> CompoundOperationWrapper<[Data]>

    func createDummySigner() throws -> DummySigner
}

final class ExtrinsicProxyOperationFactory: BaseExtrinsicOperationFactory {
    let proxy: ExtrinsicBuilderOperationFactoryProtocol

    init(
        proxy: ExtrinsicBuilderOperationFactoryProtocol,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol
    ) {
        self.proxy = proxy

        super.init(
            runtimeRegistry: runtimeRegistry,
            engine: engine,
            operationManager: operationManager
        )
    }

    override func createDummySigner() throws -> DummySigner {
        try proxy.createDummySigner()
    }

    override func createExtrinsicWrapper(
        customClosure: @escaping ExtrinsicBuilderIndexedClosure,
        indexes: [Int],
        signingClosure: @escaping (Data) throws -> Data
    ) -> CompoundOperationWrapper<[Data]> {
        proxy.createWrapper(
            customClosure: customClosure,
            indexes: indexes,
            signingClosure: signingClosure
        )
    }
}
