import Foundation
@testable import fearless
import RobinHood

final class RuntimeCodingServiceStub {
    let factory : RuntimeCoderFactoryProtocol

    init(factory: RuntimeCoderFactoryProtocol) {
        self.factory = factory
    }
}

extension RuntimeCodingServiceStub: RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { self.factory }
    }
}

extension RuntimeCodingServiceStub {
    static func createWestendCodingFactory(
        specVersion: UInt32 = 48,
        txVersion: UInt32 = 4
    ) throws -> RuntimeCoderFactoryProtocol {
        let runtimeMetadataContainer = try RuntimeHelper.createRuntimeMetadata("westend-metadata")
        let typeCatalog = try RuntimeHelper.createTypeRegistryCatalog(
            from: "runtime-default",
            networkName: "runtime-westend",
            runtimeMetadataContainer: runtimeMetadataContainer
        )

        return RuntimeCoderFactory(
            catalog: typeCatalog,
            specVersion: specVersion,
            txVersion: txVersion,
            metadata: runtimeMetadataContainer.metadata
        )
    }

    static func createWestendService(
        specVersion: UInt32 = 48,
        txVersion: UInt32 = 4
    ) throws -> RuntimeCodingServiceProtocol {
        let factory = try createWestendCodingFactory(specVersion: specVersion, txVersion: txVersion)
        return RuntimeCodingServiceStub(factory: factory)
    }
}
