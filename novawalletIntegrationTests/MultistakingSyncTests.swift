import XCTest
@testable import novawallet
import RobinHood

final class MultistakingSyncTests: XCTestCase {

    func testAllStakableChainsSync() throws {
        let result = try performAllStakableOptionsSync(
            for: "1ChFWeNRLarAPRCTM3bfJmncJbSAbSS9yqjueWz7jX7iTVZ",
            ethereumAddress: "0x7aa98aeb3afacf10021539d5412c7ac6afe0fb00"
        )

        Logger.shared.info("Result: \(result)")
    }
    
    func testAllStakableChainsForPoolSync() throws {
        let result = try performAllStakableOptionsSync(
            for: "1SohJrC8gHwHeJT1nkSonEbMd6yrkJgw8PwGsXUrKw3YrEK",
            ethereumAddress: "0x7aa98aeb3afacf10021539d5412c7ac6afe0fb00"
        )

        Logger.shared.info("Result: \(result)")
    }

    private func performAllStakableOptionsSync(
        for substrateAddress: AccountAddress,
        ethereumAddress: AccountAddress?
    ) throws -> [Multistaking.DashboardItem] {
        // given

        let storageFacade = SubstrateStorageTestFacade()

        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        let substrateAccountId = try substrateAddress.toAccountId()
        let ethereumAccountId = try ethereumAddress?.toAccountId()

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let wallet = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "test",
            substrateAccountId: substrateAccountId,
            substrateCryptoType: 0,
            substratePublicKey: substrateAccountId,
            ethereumAddress: ethereumAccountId,
            ethereumPublicKey: ethereumAccountId,
            chainAccounts: [],
            type: .watchOnly
        )

        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: storageFacade)
        let providerFactory = MultistakingProviderFactory(
            repositoryFactory: repositoryFactory,
            operationQueue: operationQueue
        )

        let syncService = MultistakingSyncService(
            wallet: wallet,
            chainRegistry: chainRegistry,
            providerFactory: providerFactory,
            repositoryFactory: repositoryFactory,
            offchainOperationFactory: SubqueryMultistakingOperationFactory(url: ApplicationConfig.shared.multistakingURL)
        )

        // when

        let allStakableAssets = ChainsStore(chainRegistry: chainRegistry).getAllStakebleAssets()
        let expectedOptions = Set(allStakableAssets.flatMap({ $0.chain.getAllStakingChainAssetOptions().map { $0.option } }))

        let completionExpectation = XCTestExpectation()

        syncService.setup()

        syncService.subscribeSyncState(
            self,
            queue: nil
        ) { (_, state) in
            let allSynced = !state.isOffchainSyncing && state.isOnchainSyncing.values.allSatisfy({ !$0 })
            let allOptions = Set(state.isOnchainSyncing.keys)

            Logger.shared.info("State change: \(state)")

            if allOptions == expectedOptions, allSynced {
                completionExpectation.fulfill()
            }
        }

        wait(for: [completionExpectation], timeout: 6000)

        // then

        let dashboardRepository = repositoryFactory.createDashboardRepository(for: wallet.metaId)

        let fetchOperation = dashboardRepository.fetchAllOperation(with: RepositoryFetchOptions())

        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

        return try fetchOperation.extractNoCancellableResultData()
    }

}
