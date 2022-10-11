import XCTest
@testable import novawallet
import SubstrateSdk
import RobinHood

class Gov2OperationFactoryTests: XCTestCase {
    let chainId = "a2ee5a1f55a23dccd0c35e36512f9009e6e50a5654e8e5e469445d0748632aa8"

    var chainRegistry: ChainRegistryProtocol!
    var connection: JSONRPCEngine!
    var runtimeProvider: RuntimeProviderProtocol!
    var operationQueue: OperationQueue!
    var requestFactory: StorageRequestFactoryProtocol!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let storageFacade = SubstrateStorageTestFacade()

        chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        self.connection = connection

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        self.runtimeProvider = runtimeProvider

        let operationQueue = OperationQueue()
        self.operationQueue = operationQueue

        self.requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }

    func testLocalReferendumsFetch() {
        do {
            let referendums = try fetchAllReferendums(for: chainRegistry)
            Logger.shared.info("Referendums: \(referendums)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchLocalVotes() throws {
        // given
        let accountId = try "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY".toAccountId()

        // when

        let operationFactory = Gov2OperationFactory(requestFactory: requestFactory)

        let wrapper = operationFactory.fetchAccountVotesWrapper(
            for: accountId,
            from: connection,
            runtimeProvider: runtimeProvider
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let votes = try wrapper.targetOperation.extractNoCancellableResultData()
            Logger.shared.info("Votes: \(votes)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testVotersFetch() throws {
        // given

        let referendumIndex: Referenda.ReferendumIndex = 0

        // when

        let operationFactory = Gov2OperationFactory(requestFactory: requestFactory)

        let wrapper = operationFactory.fetchVotersWrapper(
            for: referendumIndex,
            from: connection,
            runtimeProvider: runtimeProvider
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let votes = try wrapper.targetOperation.extractNoCancellableResultData()
            Logger.shared.info("Voters: \(votes)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testActionDetails() {
        do {
            let referendums = try fetchAllReferendums(for: chainRegistry)

            let operationFactory = Gov2ActionOperationFactory(
                requestFactory: requestFactory,
                operationQueue: operationQueue
            )

            let wrappers = referendums.map { referendum in
                operationFactory.fetchActionWrapper(
                    for: referendum,
                    connection: connection,
                    runtimeProvider: runtimeProvider
                )
            }

            let operations = wrappers.flatMap { $0.allOperations }

            operationQueue.addOperations(operations, waitUntilFinished: true)

            let details = try wrappers.map { try $0.targetOperation.extractNoCancellableResultData() }

            Logger.shared.info("Did receive details: \(details)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: Private

    private func fetchAllReferendums(for chainRegistry: ChainRegistryProtocol) throws -> [ReferendumLocal] {
        let operationQueue = OperationQueue()

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let operationFactory = Gov2OperationFactory(requestFactory: requestFactory)

        let wrapper = operationFactory.fetchAllReferendumsWrapper(
            from: connection,
            runtimeProvider: runtimeProvider
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
