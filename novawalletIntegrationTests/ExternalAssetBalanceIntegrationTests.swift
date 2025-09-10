import XCTest
@testable import novawallet

final class ExternalAssetBalanceIntegrationTests: XCTestCase {
    func testPolkadot() throws {
        let accountId = try "1ChFWeNRLarAPRCTM3bfJmncJbSAbSS9yqjueWz7jX7iTVZ".toAccountId()
        let chainAssetId = ChainAssetId(
            chainId: KnowChainId.polkadot,
            assetId: AssetModel.utilityAssetId
        )

        let balances = try performFetch(
            for: chainAssetId,
            accountId: accountId,
            expectingTypes: [.nominationPools, .crowdloan]
        )

        Logger.shared.info("Balances: \(balances)")
    }

    private func performFetch(
        for chainAssetId: ChainAssetId,
        accountId: AccountId,
        expectingTypes: Set<ExternalAssetBalance.BalanceType>
    ) throws -> [ExternalAssetBalance] {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard
            let chain = chainRegistry.getChain(for: chainAssetId.chainId),
            let asset = chain.asset(for: chainAssetId.assetId) else {
            throw ChainRegistryError.noChain(chainAssetId.chainId)
        }

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let subscriptionFactory = ExternalBalanceLocalSubscriptionFacade.createDefaultFactory(
            for: storageFacade,
            chainRegistry: chainRegistry
        )

        guard let provider = subscriptionFactory.getExternalAssetBalanceProvider(for: accountId, chainAsset: chainAsset) else {
            throw CommonError.dataCorruption
        }

        var balances = [ExternalAssetBalance]()

        let expectation = XCTestExpectation()

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: { changes in
                balances = balances.applying(changes: changes)

                let types = Set(balances.map(\.type))

                if types.intersection(expectingTypes) == expectingTypes {
                    expectation.fulfill()
                }
            }, failing: { error in
                Logger.shared.error("Unexpected error: \(error)")
            },
            options: .init()
        )

        wait(for: [expectation], timeout: 600)

        provider.removeObserver(self)

        return balances
    }
}
