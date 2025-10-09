import XCTest
@testable import novawallet
import SubstrateSdk

final class Gov2DelegationTests: XCTestCase {
    func testDelegationListFetch() {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId: ChainModel.Id = KnowChainId.kusama
        let recentBlockNumber: BlockNumber = 1000
        let blockTime: BlockTime = 6000

        guard let operationFactory = setupDelegationListFactory(for: chainId, chainRegistry: chainRegistry) else {
            return
        }

        // when

        let wrapper = operationFactory.fetchDelegateListWrapper(
            for: .init(type: .block(blockNumber: recentBlockNumber, blockTime: blockTime))
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

    func testDelegationListByIdsFetch() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId: ChainModel.Id = KnowChainId.kusama
        let recentBlockNumber: BlockNumber = 1000
        let blockTime: BlockTime = 6000
        let delegates = [
            "FLKBjcL1hXtX7PHF5zrVwQTWQSKg7PCMQ5w6ZU7qvQGsvZR",
            "H1tAQMm3eizGcmpAhL9aA9gR844kZpQfkU7pkmMiLx9jSzE"
        ]

        guard
            let operationFactory = setupDelegationListFactory(for: chainId, chainRegistry: chainRegistry),
            let chain = chainRegistry.getChain(for: chainId) else {
            return
        }

        // when

        let delegateIds = Set(delegates.compactMap { try? $0.toAccountId(using: chain.chainFormat) })
        let wrapper = operationFactory.fetchDelegateListByIdsWrapper(
            from: Set(delegateIds),
            threshold: .init(type: .block(blockNumber: recentBlockNumber, blockTime: blockTime))
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let result = try wrapper.targetOperation.extractNoCancellableResultData()
            XCTAssertEqual(result.count, delegates.count)
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
        let blockTime: BlockTime = 6000
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
            threshold: .init(type: .block(blockNumber: recentBlockNumber, blockTime: blockTime))
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

    func testFetchReferendumVoters() {
        performFetchReferndumVotersTest(referendumId: 84)
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
        let blockTime: BlockTime = 6000

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let delegationApi = chain.externalApis?.governanceDelegations()?.first else {
            return
        }

        let statsOperationFactory = SubqueryVotingOperationFactory(url: delegationApi.url)

        let threshold: TimepointThreshold? = if let block {
            .init(type: .block(blockNumber: block, blockTime: blockTime))
        } else {
            nil
        }

        // when

        let wrapper = statsOperationFactory.createDirectVotesFetchOperation(
            for: address,
            from: threshold
        )

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

    private func setupDelegationListFactory(
        for chainId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol
    ) -> GovernanceDelegateListFactoryProtocol? {
        let chainId = KnowChainId.kusama

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let delegationApi = chain.externalApis?.governanceDelegations()?.first else {
            return nil
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

        let identityProxyFactory = IdentityProxyFactory(
            originChain: chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        return GovernanceDelegateListOperationFactory(
            chain: chain,
            statsOperationFactory: statsOperationFactory,
            metadataOperationFactory: metadataOperationFactory,
            identityProxyFactory: identityProxyFactory
        )
    }

    private func performFetchReferndumVotersTest(referendumId: ReferendumIdLocal) {
        // given
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = KnowChainId.kusama

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let delegationApi = chain.externalApis?.governanceDelegations()?.first else {
            return
        }

        let operationFactory = SubqueryVotingOperationFactory(url: delegationApi.url)

        // when

        let wrapper = operationFactory.createReferendumVotesFetchOperation(
            referendumId: referendumId,
            votersType: .ayes
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

        do {
            let voters = try wrapper.targetOperation.extractNoCancellableResultData()
            XCTAssertTrue(!voters.isEmpty)
            XCTAssertTrue(voters.contains { !$0.delegators.isEmpty })
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
