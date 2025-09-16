import XCTest
@testable import novawallet
import SubstrateSdk
import Operation_iOS

class ConvictionVotesFetchTests: XCTestCase {
    func testConvictionVotesFetch() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = "ea5af80801ea4579cedd029eaaa74938f0ea8dcaf507c8af96f2813d27d071ca"
        let accountId = try "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY".toAccountId()
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

        let request = MapRemoteStorageRequest(storagePath: ConvictionVoting.votingFor) {
            BytesCodable(wrappedValue: accountId)
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[ConvictionVoting.VotingForKey: ConvictionVoting.Voting]> =
            requestFactory.queryByPrefix(
                engine: connection,
                request: request,
                storagePath: ConvictionVoting.votingFor,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() }
            )

        wrapper.addDependency(operations: [codingFactoryOperation])

        operationQueue.addOperations([codingFactoryOperation] + wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let voting = try wrapper.targetOperation.extractNoCancellableResultData()
            Logger.shared.info("Did receive voting: \(voting)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConvictionLocksFetch() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = "ea5af80801ea4579cedd029eaaa74938f0ea8dcaf507c8af96f2813d27d071ca"
        let accountId = try "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY".toAccountId()
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

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<[ConvictionVoting.ClassLock]>]> =
            requestFactory.queryItems(
                engine: connection,
                keyParams: {
                    [BytesCodable(wrappedValue: accountId)]
                },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: ConvictionVoting.trackLocksFor
            )

        wrapper.addDependency(operations: [codingFactoryOperation])

        operationQueue.addOperations([codingFactoryOperation] + wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let locks = try wrapper.targetOperation.extractNoCancellableResultData()

            Logger.shared.info("Did receive locks: \(locks)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
