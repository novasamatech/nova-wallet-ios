import Foundation
@testable import novawallet
import RobinHood

final class MockCloudBackupUploadFactory {
    let operationFactory: CloudBackupOperationFactoryProtocol
    
    init(operationFactory: CloudBackupOperationFactoryProtocol) {
        self.operationFactory = operationFactory
    }
}

extension MockCloudBackupUploadFactory: CloudBackupUploadFactoryProtocol {
    func createUploadWrapper(
        for fileUrl: URL,
        tempUrl: URL?,
        timeoutInterval: TimeInterval,
        dataClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        let operation = operationFactory.createWritingOperation(
            for: fileUrl,
            dataClosure: dataClosure
        )
        
        return CompoundOperationWrapper(targetOperation: operation)
    }
}
