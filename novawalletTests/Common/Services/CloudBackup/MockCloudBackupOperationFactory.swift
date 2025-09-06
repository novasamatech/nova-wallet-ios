import Foundation
@testable import novawallet
import Operation_iOS

final class MockCloudBackupOperationFactory {
    @Atomic
    private var data: Data?

    init(data: Data? = nil) {
        _data = Atomic(defaultValue: data)
    }
}

extension MockCloudBackupOperationFactory: CloudBackupOperationFactoryProtocol {
    func createReadingOperation(for _: URL) -> BaseOperation<Data?> {
        ClosureOperation {
            self.data
        }
    }

    func createWritingOperation(
        for _: URL,
        dataClosure: @escaping () throws -> Data
    ) -> BaseOperation<Void> {
        ClosureOperation {
            self.data = try dataClosure()
        }
    }

    func createDeletionOperation(for _: URL) -> BaseOperation<Void> {
        ClosureOperation {
            self.data = nil
        }
    }

    func createMoveOperation(from _: URL, destinationUrl _: URL) -> BaseOperation<Void> {
        BaseOperation.createWithResult(())
    }
}
