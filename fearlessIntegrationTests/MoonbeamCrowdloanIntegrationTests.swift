import XCTest
@testable import fearless

class MoonbeamCrowdloanIntegrationTests: XCTestCase {

    func testCheckHealth() {
        let address = "16amk3UDpgP9qgs5bBeCUnLZgtsqXHTrGMk1WHBZDprbJCK5"
        let operationManager = OperationManagerFacade.sharedManager
        let service = MoonbeamBonusService(address: address, operationManager: operationManager)

        let healthOperation = service.createCheckHealthOperation()
        let healthExpectation = XCTestExpectation(description: "Check GET /health returns 200 OK")

        healthOperation.completionBlock = {
            do {
                _ = try healthOperation.extractNoCancellableResultData()
                healthExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        operationManager.enqueue(operations: [healthOperation], in: .transient)

        wait(for: [healthExpectation], timeout: 3)
    }

    func testCheckRemark() {
        let address = "16amk3UDpgP9qgs5bBeCUnLZgtsqXHTrGMk1WHBZDprbJCK5"
        let operationManager = OperationManagerFacade.sharedManager
        let service = MoonbeamBonusService(address: address, operationManager: operationManager)

        let remarkOperation = service.createCheckRemarkOperation()
        let remarkExpectation = XCTestExpectation(description: "Check GET /check-remark/ returns 200 OK")

        remarkOperation.completionBlock = {
            do {
                _ = try remarkOperation.extractNoCancellableResultData()
                remarkExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        operationManager.enqueue(operations: [remarkOperation], in: .transient)

        wait(for: [remarkExpectation], timeout: 3)
    }
}
