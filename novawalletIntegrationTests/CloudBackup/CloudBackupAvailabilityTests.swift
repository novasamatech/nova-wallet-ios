import XCTest
@testable import novawallet
import RobinHood

final class CloudBackupAvailabilityTests: XCTestCase {
    func testCloudBackupAvailable() {
        let operationQueue = OperationQueue()
        let service = ICloudBackupServiceFactory(operationQueue: operationQueue).createAvailabilityService()
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
    
    func testEnoughStorage() {
        let factory = ICloudBackupServiceFactory(operationQueue: OperationQueue())
        
        guard let baseUrl = factory.createFileManager().getBaseUrl() else {
            XCTFail("ICloud unavailable")
            return
        }
        
        let manager = factory.createStorageManager(for: baseUrl)
        
        let expectation = XCTestExpectation()
        var checkError: CloudBackupUploadError?
        
        manager.checkStorage(
            of: 1 * 1024,
            timeoutInterval: 10,
            runningIn: .main
        ) { result in
            switch result {
            case .success:
                break
            case let .failure(error):
                checkError = error
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 120)
        
        if let checkError {
            XCTFail("\(checkError)")
        }
    }
    
    func testCloudWriting() {
        let operationQueue = OperationQueue()
        let serviceFactory = ICloudBackupServiceFactory(operationQueue: operationQueue)
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
