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

    func testDelegationDetailsFetch() {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = KnowChainId.kusama
        let recentBlockNumber: BlockNumber = 1000
        let delegate: AccountAddress = "H1tAQMm3eizGcmpAhL9aA9gR844kZpQfkU7pkmMiLx9jSzE"

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let delegationApi = chain.externalApis?.governanceDelegations()?.first else {
            return
        }

        let statsOperationFactory = SubqueryDelegateStatsOperationFactory(url: delegationApi.url)

        // when

        let wrapper = statsOperationFactory.fetchDetailsWrapper(
            for: delegate,
            activityStartBlock: recentBlockNumber
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let delegate = try wrapper.targetOperation.extractNoCancellableResultData()
            XCTAssertNotNil(delegate)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchAccountCastingAndDelegatedVotesWhenOnlyCastingVotes() {
        performFetchAccountCastingAndDelegatedVotesTest(for: "H1tAQMm3eizGcmpAhL9aA9gR844kZpQfkU7pkmMiLx9jSzE")
    }

    func testFetchAccountCastingAndDelegatedVotesWhenOnlyDelegatedVotes() {
        performFetchAccountCastingAndDelegatedVotesTest(for: "FZsMKYHoQG1dAVhXBMyC7aYFYpASoBrrMYsAn1gJJUAueZX")
    }

    func testFetchAccountAllCastingVotes() {
        performFetchAccountDirectVotesActivityTest(
            for: "H1tAQMm3eizGcmpAhL9aA9gR844kZpQfkU7pkmMiLx9jSzE",
            block: nil
        )
    }

    func testFetchAccountBoundedCastingVotes() {
        performFetchAccountDirectVotesActivityTest(
            for: "H1tAQMm3eizGcmpAhL9aA9gR844kZpQfkU7pkmMiLx9jSzE",
            block: 1000
        )
    }

    func testFetchDelegations() {
        performFetchDelegationsTest(for: "H1tAQMm3eizGcmpAhL9aA9gR844kZpQfkU7pkmMiLx9jSzE")
    }

    private func performFetchAccountCastingAndDelegatedVotesTest(for address: AccountAddress) {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = KnowChainId.kusama

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let delegationApi = chain.externalApis?.governanceDelegations()?.first else {
            return
        }

        let statsOperationFactory = SubqueryVotingOperationFactory(url: delegationApi.url)

        // when

        let wrapper = statsOperationFactory.createAllVotesFetchOperation(for: address)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let voting = try wrapper.targetOperation.extractNoCancellableResultData()
            XCTAssertTrue(!voting.votes.isEmpty)
            XCTAssertEqual(address, voting.address)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func performFetchAccountDirectVotesActivityTest(for address: AccountAddress, block: BlockNumber?) {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = KnowChainId.kusama

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let delegationApi = chain.externalApis?.governanceDelegations()?.first else {
            return
        }

        let statsOperationFactory = SubqueryVotingOperationFactory(url: delegationApi.url)

        // when

        let wrapper = statsOperationFactory.createDirectVotesFetchOperation(for: address, from: block)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let votes = try wrapper.targetOperation.extractNoCancellableResultData()
            XCTAssertTrue(!votes.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func performFetchDelegationsTest(for address: AccountAddress) {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = KnowChainId.kusama

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let delegationApi = chain.externalApis?.governanceDelegations()?.first else {
            return
        }

        let operationFactory = SubqueryDelegationsOperationFactory(url: delegationApi.url)

        // when

        let wrapper = operationFactory.createDelegationsFetchWrapper(for: address)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let delegations = try wrapper.targetOperation.extractNoCancellableResultData()
            XCTAssertTrue(!delegations.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
