import XCTest
@testable import novawallet
import Operation_iOS
import BigInt
import Cuckoo

final class AssetExchangeCommissionBeneficiaryProviderTests: XCTestCase {
    func testChargesOnlyWhenBalanceReachesExistentialDeposit() throws {
        XCTAssertTrue(try fetchState(balance: 101, existentialDeposit: 100).canReceive)
        XCTAssertTrue(try fetchState(balance: 100, existentialDeposit: 100).canReceive)
        XCTAssertFalse(try fetchState(balance: 99, existentialDeposit: 100).canReceive)
        XCTAssertFalse(try fetchState(balance: 0, existentialDeposit: 100).canReceive)
    }

    func testSecondFetchForSameChainUsesCache() throws {
        let chain = CommissionTestFixtures.chain

        let balanceFactory = MockWalletRemoteQueryWrapperFactoryProtocol()
        stub(balanceFactory) { stub in
            stub.queryBalance(for: any(), chainAsset: any()).then { _, _ in
                .createWithResult(CommissionTestFixtures.assetBalance(free: 500, chain: chain))
            }
        }

        let provider = CommissionTestFixtures.makeBeneficiaryProvider(
            balanceFactory: balanceFactory,
            existentialDeposit: 100,
            chain: chain
        )

        for _ in 0 ..< 3 {
            let wrapper = provider.fetchStateWrapper(for: chain.chainId)
            OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
            _ = try wrapper.targetOperation.extractNoCancellableResultData()
        }

        verify(balanceFactory, times(1)).queryBalance(
            for: any(),
            chainAsset: ParameterMatcher { $0.asset.assetId == AssetModel.utilityAssetId }
        )
    }

    func testDifferentChainsAreCachedIndependently() throws {
        let chain1 = CommissionTestFixtures.chain
        let chain2 = ChainModelGenerator.generateChain(
            defaultChainId: KnowChainId.polkadotAssetHub,
            generatingAssets: 8,
            addressPrefix: 0
        )

        let balanceFactory = MockWalletRemoteQueryWrapperFactoryProtocol()
        stub(balanceFactory) { stub in
            stub.queryBalance(for: any(), chainAsset: any()).then { _, _ in
                .createWithResult(CommissionTestFixtures.assetBalance(free: 500, chain: chain1))
            }
        }

        let provider = CommissionTestFixtures.makeBeneficiaryProvider(
            balanceFactory: balanceFactory,
            existentialDeposit: 100,
            chain: chain1,
            additionalChains: [chain2]
        )

        for chain in [chain1, chain2] {
            let wrapper = provider.fetchStateWrapper(for: chain.chainId)
            OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
            _ = try wrapper.targetOperation.extractNoCancellableResultData()
        }

        verify(balanceFactory, times(2)).queryBalance(for: any(), chainAsset: any())
    }

    func testFailureIsNotCached() throws {
        let chain = CommissionTestFixtures.chain

        let balanceFactory = MockWalletRemoteQueryWrapperFactoryProtocol()
        stub(balanceFactory) { stub in
            stub.queryBalance(for: any(), chainAsset: any()).then { _, _ in
                .createWithError(CommonError.dataCorruption)
            }
        }

        let provider = CommissionTestFixtures.makeBeneficiaryProvider(
            balanceFactory: balanceFactory,
            existentialDeposit: 100,
            chain: chain
        )

        for _ in 0 ..< 2 {
            let wrapper = provider.fetchStateWrapper(for: chain.chainId)
            OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
            XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData())
        }

        verify(balanceFactory, times(2)).queryBalance(for: any(), chainAsset: any())
    }

    func testUnknownChainFailsReadiness() throws {
        let provider = CommissionTestFixtures.makeBeneficiaryProvider(
            balance: 500,
            existentialDeposit: 100,
            chain: CommissionTestFixtures.chain
        )

        let wrapper = provider.fetchStateWrapper(for: "unknown-chain-id")
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData()) { error in
            guard case let ChainRegistryError.noChain(chainId) = error else {
                XCTFail("Expected ChainRegistryError.noChain, got \(error)")
                return
            }

            XCTAssertEqual(chainId, "unknown-chain-id")
        }
    }

    func testChainWithoutUtilityAssetFailsReadiness() throws {
        let chain = ChainModelGenerator.generateChain(
            assets: [ChainModelGenerator.generateAssetWithId(1)],
            defaultChainId: KnowChainId.polkadotAssetHub,
            addressPrefix: 0
        )

        let provider = CommissionTestFixtures.makeBeneficiaryProvider(
            balance: 500,
            existentialDeposit: 100,
            chain: chain
        )

        let wrapper = provider.fetchStateWrapper(for: chain.chainId)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData()) { error in
            guard case let ChainModelFetchError.noAsset(assetId) = error else {
                XCTFail("Expected ChainModelFetchError.noAsset, got \(error)")
                return
            }

            XCTAssertEqual(assetId, AssetModel.utilityAssetId)
        }
    }
}

private extension AssetExchangeCommissionBeneficiaryProviderTests {
    func fetchState(
        balance: Balance,
        existentialDeposit: Balance
    ) throws -> CommissionBeneficiaryState {
        let chain = CommissionTestFixtures.chain

        let provider = CommissionTestFixtures.makeBeneficiaryProvider(
            balance: balance,
            existentialDeposit: existentialDeposit,
            chain: chain
        )

        let wrapper = provider.fetchStateWrapper(for: chain.chainId)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
