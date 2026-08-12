import XCTest
@testable import novawallet
import Operation_iOS
import BigInt
import Cuckoo

final class AssetExchangeCommissionBeneficiaryProviderTests: XCTestCase {
    func testChargesOnlyWhenBalanceExceedsExistentialDeposit() throws {
        XCTAssertTrue(try fetchState(balance: 101, existentialDeposit: 100).canReceive)
        XCTAssertFalse(try fetchState(balance: 100, existentialDeposit: 100).canReceive)
        XCTAssertFalse(try fetchState(balance: 99, existentialDeposit: 100).canReceive)
        XCTAssertFalse(try fetchState(balance: 0, existentialDeposit: 100).canReceive)
    }

    func testStateCarriesRawAmounts() throws {
        let state = try fetchState(balance: 555, existentialDeposit: 100)

        XCTAssertEqual(state.balance, 555)
        XCTAssertEqual(state.existentialDeposit, 100)
    }

    func testSecondFetchForSameAssetUsesCache() throws {
        let chain = CommissionTestFixtures.chain
        let asset = try XCTUnwrap(chain.assets.first { $0.assetId == 1 })
        let chainAsset = ChainAsset(chain: chain, asset: asset)

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
            let wrapper = provider.fetchStateWrapper(for: chainAsset)
            OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
            _ = try wrapper.targetOperation.extractNoCancellableResultData()
        }

        verify(balanceFactory, times(1)).queryBalance(for: any(), chainAsset: any())
    }

    func testFailureIsNotCached() throws {
        let chain = CommissionTestFixtures.chain
        let asset = try XCTUnwrap(chain.assets.first { $0.assetId == 1 })
        let chainAsset = ChainAsset(chain: chain, asset: asset)

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
            let wrapper = provider.fetchStateWrapper(for: chainAsset)
            OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
            XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData())
        }

        verify(balanceFactory, times(2)).queryBalance(for: any(), chainAsset: any())
    }
}

private extension AssetExchangeCommissionBeneficiaryProviderTests {
    func fetchState(
        balance: Balance,
        existentialDeposit: Balance
    ) throws -> CommissionBeneficiaryState {
        let chain = CommissionTestFixtures.chain
        let asset = try XCTUnwrap(chain.assets.first { $0.assetId == 1 })
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let provider = CommissionTestFixtures.makeBeneficiaryProvider(
            balance: balance,
            existentialDeposit: existentialDeposit,
            chain: chain
        )

        let wrapper = provider.fetchStateWrapper(for: chainAsset)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
