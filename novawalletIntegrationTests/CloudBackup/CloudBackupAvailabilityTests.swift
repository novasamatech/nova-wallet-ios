import XCTest
@testable import novawallet
import Operation_iOS

final class CloudBackupAvailabilityTests: XCTestCase {
    func testCloudBackupAvailable() {
        let service = ICloudBackupServiceFactory().createAvailabilityService()
        service.setup()

        switch service.stateObserver.state {
        case .available:
            break
        case .notDetermined:
            XCTFail("ICloud not determined")
        case .unavailable:
            XCTFail("ICloud unavailable")
        }
    }

    func testCloudWriting() {
        let operationQueue = OperationQueue()
        let serviceFactory = ICloudBackupServiceFactory()
        let operationFactory = serviceFactory.createOperationFactory()

        guard let baseUrl = serviceFactory.createFileManager().getBaseUrl() else {
            XCTFail("ICloud unavailable")
            return
        }

        let fileName = (UUID().uuidString as NSString).appendingPathExtension(for: .plainText)
        let fileUrl = baseUrl.appendingPathComponent(fileName, conformingTo: .plainText)

        Logger.shared.debug("Url: \(fileUrl)")

        let dataOperation = ClosureOperation<Data> {
            "Hello iCloud!".data(using: .utf8)!
        }

        let writingOperation = operationFactory.createWritingOperation(
            for: fileUrl,
            dataClosure: { try dataOperation.extractNoCancellableResultData() }
        )

        writingOperation.addDependency(dataOperation)

        operationQueue.addOperations([dataOperation, writingOperation], waitUntilFinished: true)

        do {
            try writingOperation.extractNoCancellableResultData()
        } catch {
            XCTFail("Cloud writing failed: \(error)")
        }
    }
}
