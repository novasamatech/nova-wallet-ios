import Foundation
@testable import novawallet
import RobinHood

final class MockCloudBackupOperationFactory {
    @Atomic
    private var data: Data?
    
    init(data: Data? = nil) {
        self._data = Atomic(defaultValue: data)
    }
}

extension MockCloudBackupOperationFactory: CloudBackupOperationFactoryProtocol {
    func createReadingOperation(for url: URL) -> BaseOperation<Data?> {
        ClosureOperation {
            self.data
        }
    }
    
    func createWritingOperation(
        for url: URL,
        dataClosure: @escaping () throws -> Data
    ) -> BaseOperation<Void> {
        ClosureOperation {
            self.data = try? dataClosure()
        }
    }
    
    func createDeletionOperation(for url: URL) -> BaseOperation<Void> {
        ClosureOperation {
            self.data = nil
        }
    }
}
