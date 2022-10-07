import XCTest
@testable import novawallet
import SubstrateSdk
import RobinHood

class Gov2OperationFactoryTests: XCTestCase {
    func testLocalReferendumsFetch() {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = "ea5af80801ea4579cedd029eaaa74938f0ea8dcaf507c8af96f2813d27d071ca"
        let operationQueue = OperationQueue()

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            XCTFail("Can't get connection for chain id \(chainId)")
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            XCTFail("Can't get runtime provider for chain id \(chainId)")
            return
        }

        // when

        let operationFactory = Gov2OperationFactory(requestFactory: requestFactory)

        let wrapper = operationFactory.fetchAllReferendumsWrapper(
            from: connection,
            runtimeProvider: runtimeProvider
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let referendums = try wrapper.targetOperation.extractNoCancellableResultData()
            Logger.shared.info("Referendums: \(referendums)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchLocalVotes() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = "ea5af80801ea4579cedd029eaaa74938f0ea8dcaf507c8af96f2813d27d071ca"
        let accountId = try "5HpG9w8EBLe5XCrbczpwq5TSXvedjrBGCwqxK1iQ7qUsSWFc".toAccountId()
        let operationQueue = OperationQueue()

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            XCTFail("Can't get connection for chain id \(chainId)")
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            XCTFail("Can't get runtime provider for chain id \(chainId)")
            return
        }

        // when

        let operationFactory = Gov2OperationFactory(requestFactory: requestFactory)

        let wrapper = operationFactory.fetchAccountVotes(for: accountId, from: connection, runtimeProvider: runtimeProvider)

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let votes = try wrapper.targetOperation.extractNoCancellableResultData()
            Logger.shared.info("Votes: \(votes)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
