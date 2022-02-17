import XCTest
@testable import novawallet
import RobinHood

class UniquesIntegrationTests: XCTestCase {
    func testAccountKeyFetch() {
        // given
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = "48239ef607d7928874027a43a67689209727dfb3d3dc5e5b03a39bdc2eda771a"
        let accountAddress = "Hn7GWG6eevwpYCJhG2SAWXo2H2PoMiMk4uPPS5pVtcE8Miz"

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            XCTFail("Can't find connection for \(chainId)")
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            XCTFail("Can't find runtime provider for \(chainId)")
            return
        }

        guard let accountId = try? accountAddress.toAccountId() else {
            XCTFail("Can't create account id")
            return
        }

        let operationQueue = OperationQueue()
        let operationManager = OperationManager(operationQueue: operationQueue)

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let fetchWraper = UniquesOperationFactory().createAccountKeysWrapper(
            for: accountId,
            connection: connection,
            operationManager: operationManager
        ) {
            try codingFactoryOperation.extractNoCancellableResultData()
        }

        fetchWraper.addDependency(operations: [codingFactoryOperation])

        let operations = [codingFactoryOperation] + fetchWraper.allOperations

        operationQueue.addOperations(operations, waitUntilFinished: true)

        do {
            let accountKeys = try fetchWraper.targetOperation.extractNoCancellableResultData()
            XCTAssertTrue(!accountKeys.isEmpty)
        } catch {
            XCTFail("Expected error \(error)")
        }
    }
}
