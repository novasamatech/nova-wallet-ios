import XCTest
@testable import novawallet

final class Gov2DelegationTests: XCTestCase {

    func testDelegationListFetch() {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = KnowChainId.kusama
        let recentBlockNumber: BlockNumber = 1000

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let delegationApi = chain.externalApis?.governanceDelegations()?.first else {
            return
        }

        let statsOperationFactory = SubqueryDelegateStatsOperationFactory(url: delegationApi.url)
        let metadataOperationFactory = GovernanceDelegateMetadataFactory()
        let delegationListFactory = GovernanceDelegateListOperationFactory(
            chain: chain,
            statsOperationFactory: statsOperationFactory,
            metadataOperationFactory: metadataOperationFactory
        )

        // when

        let wrapper = delegationListFactory.fetchDelegateListWrapper(for: recentBlockNumber)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let delegates = try wrapper.targetOperation.extractNoCancellableResultData()
            XCTAssertTrue(delegates.contains(where: { $0.metadata != nil }))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
