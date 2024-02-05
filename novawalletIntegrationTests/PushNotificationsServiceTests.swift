import XCTest
@testable import novawallet
import RobinHood

final class PushNotificationsServiceTests: XCTestCase {
    
    func testFetchingFromSource() throws {
        let source = PushNotificationsSettingsSource(uuid: "test-token")
        let wrapper = source.fetchOperation()
        let operationQueue = OperationQueue()
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        let result = try wrapper.targetOperation.extractNoCancellableResultData()
        Logger.shared.info("Result: \(result)")
    }
}
