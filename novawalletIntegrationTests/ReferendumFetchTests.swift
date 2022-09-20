import XCTest
@testable import novawallet
import SubstrateSdk
import RobinHood

class ReferendumFetchTests: XCTestCase {
    func testFetchAllOnchainReferendums() {
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

        let request = UnkeyedRemoteStorageRequest(storagePath: Governance.referendumInfo)

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[ReferendumIndexKey: ReferendumInfo]> = requestFactory.queryByPrefix(
            engine: connection,
            request: request,
            storagePath: request.storagePath,
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            at: nil
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        let operations = [codingFactoryOperation] + wrapper.allOperations
        operationQueue.addOperations(operations, waitUntilFinished: true)

        // then

        do {
            let referendums = try wrapper.targetOperation.extractNoCancellableResultData()
            Logger.shared.info("Referendums: \(referendums)")
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
