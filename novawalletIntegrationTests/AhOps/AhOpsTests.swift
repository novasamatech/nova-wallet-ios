import XCTest
@testable import novawallet

final class AhOpsTests: XCTestCase {
    func testContributionsOnPAH() throws {
        try performContributionFetchTest(for: KnowChainId.polkadotAssetHub)
    }

    func testContributionsOnKAH() throws {
        try performContributionFetchTest(for: KnowChainId.kusamaAssetHub)
    }
}

private extension AhOpsTests {
    func performContributionFetchTest(for chainId: ChainModel.Id) throws {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let operationQueue = OperationQueue()
        let logger = Logger.shared

        let operationFactory = AhOpsOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let fetchWrapper = operationFactory.fetchContributions(by: chainId)

        operationQueue.addOperations(fetchWrapper.allOperations, waitUntilFinished: true)

        let contributions = try fetchWrapper.targetOperation.extractNoCancellableResultData()

        let maxContributionAccount = try contributions
            .max { $0.value.amount < $1.value.amount }?
            .key
            .contributor
            .toAddress(using: .defaultSubstrateFormat)

        guard let maxContributionAccount else {
            logger.info("No contributions")
            return
        }

        let parachains = contributions.map(\.key.paraId).distinct()

        logger.info("Num of contributions: \(contributions.count)")
        logger.info("Num of parachains: \(parachains.count)")
        logger.info("Max contributor: \(maxContributionAccount)")
    }
}
