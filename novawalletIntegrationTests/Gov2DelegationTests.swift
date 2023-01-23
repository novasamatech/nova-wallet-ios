import XCTest
@testable import novawallet
import SubstrateSdk

final class Gov2DelegationTests: XCTestCase {

    func testDelegationListFetch() {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = KnowChainId.kusama
        let recentBlockNumber: BlockNumber = 1000

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let delegationApi = chain.externalApis?.governanceDelegations()?.first else {
            return
        }

        let statsOperationFactory = SubqueryDelegateStatsOperationFactory(url: delegationApi.url)
        let metadataOperationFactory = GovernanceDelegateMetadataFactory()

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        let delegationListFactory = GovernanceDelegateListOperationFactory(
            statsOperationFactory: statsOperationFactory,
            metadataOperationFactory: metadataOperationFactory,
            identityOperationFactory: identityOperationFactory
        )

        // when

        let wrapper = delegationListFactory.fetchDelegateListWrapper(
            for: recentBlockNumber,
            chain: chain,
            connection: connection,
            runtimeService: runtimeService
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let delegates = try wrapper.targetOperation.extractNoCancellableResultData()
            XCTAssertTrue(delegates.contains(where: { $0.metadata != nil }))
            XCTAssertTrue(delegates.contains(where: { $0.identity != nil }))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
