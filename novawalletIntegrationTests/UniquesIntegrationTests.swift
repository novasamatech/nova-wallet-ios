import XCTest
@testable import novawallet
import RobinHood

class UniquesIntegrationTests: XCTestCase {
    func testAccountKeyFetch() {
        // given
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = "48239ef607d7928874027a43a67689209727dfb3d3dc5e5b03a39bdc2eda771a"
        let accountAddress = "HeHyyTFvRM851MZ5LE4FWH5cCAkP4oVmA2aeeMG1wMatwT7"

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

    func testClassAndInstanceMetadataFetch() {
        // given
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = "48239ef607d7928874027a43a67689209727dfb3d3dc5e5b03a39bdc2eda771a"
        let accountAddress = "HeHyyTFvRM851MZ5LE4FWH5cCAkP4oVmA2aeeMG1wMatwT7"

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

        let uniqiuesFactory = UniquesOperationFactory()

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let fetchKeysWraper = uniqiuesFactory.createAccountKeysWrapper(
            for: accountId,
            connection: connection,
            operationManager: operationManager
        ) {
            try codingFactoryOperation.extractNoCancellableResultData()
        }

        fetchKeysWraper.addDependency(operations: [codingFactoryOperation])

        let fetchClassMetadataWrapper = uniqiuesFactory.createClassMetadataWrapper(
            for: {
                try fetchKeysWraper.targetOperation.extractNoCancellableResultData().map { $0.classId }
            },
            connection: connection,
            operationManager: operationManager,
            codingFactoryClosure: {
                try codingFactoryOperation.extractNoCancellableResultData()
            })

        let fetchInstanceMetadataWrapper = uniqiuesFactory.createInstanceMetadataWrapper(
            for: {
                try fetchKeysWraper.targetOperation.extractNoCancellableResultData().map { $0.classId }
            },
            instanceIdsClosure: {
                try fetchKeysWraper.targetOperation.extractNoCancellableResultData().map { $0.instanceId }
            },
            connection: connection,
            operationManager: operationManager,
            codingFactoryClosure: {
                try codingFactoryOperation.extractNoCancellableResultData()
            })

        fetchClassMetadataWrapper.addDependency(wrapper: fetchKeysWraper)
        fetchInstanceMetadataWrapper.addDependency(wrapper: fetchKeysWraper)

        let operations = [codingFactoryOperation] + fetchKeysWraper.allOperations +
        fetchClassMetadataWrapper.allOperations + fetchInstanceMetadataWrapper.allOperations

        operationQueue.addOperations(operations, waitUntilFinished: true)

        let logger = Logger.shared

        do {
            let accountKeys = try fetchKeysWraper.targetOperation.extractNoCancellableResultData()
            XCTAssertTrue(!accountKeys.isEmpty)

            let classMetadataDict = try fetchClassMetadataWrapper.targetOperation
                .extractNoCancellableResultData()

            classMetadataDict.forEach { (key, value) in
                logger.info(
                    "Metadata for class \(key): \(String(data: value.data, encoding: .utf8)!)"
                )
            }

            let instanceMetadataDic = try fetchInstanceMetadataWrapper.targetOperation
                .extractNoCancellableResultData()

            instanceMetadataDic.forEach { (key, value) in
                logger.info(
                    "Metadata for instance \(key): \(String(data: value.data, encoding: .utf8)!)"
                )
            }
        } catch {
            XCTFail("Expected error \(error)")
        }
    }
}
