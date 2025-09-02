import Foundation
import Operation_iOS

final class OfflineRuntimeCodingService {
    private let snapshot: RuntimeSnapshot

    init(snapshot: RuntimeSnapshot) {
        self.snapshot = snapshot
    }
}

// MARK: - RuntimeCodingServiceProtocol

extension OfflineRuntimeCodingService: RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        let codingFactory = RuntimeCoderFactory(
            catalog: snapshot.typeRegistryCatalog,
            specVersion: snapshot.specVersion,
            txVersion: snapshot.txVersion,
            metadata: snapshot.metadata
        )

        return .createWithResult(codingFactory)
    }
}
