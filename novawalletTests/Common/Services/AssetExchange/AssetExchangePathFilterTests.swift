import XCTest
@testable import novawallet
import Cuckoo

final class AssetExchangePathFilterTests: XCTestCase {
    private let chain = CommissionTestFixtures.chain

    private var stableswapPool: AssetExchangePoolId {
        AssetExchangePoolId(chainId: chain.chainId, identifier: "stableswap-110")
    }

    private var omnipool: AssetExchangePoolId {
        AssetExchangePoolId(chainId: chain.chainId, identifier: "omnipool")
    }

    func testRejectsEdgeReenteringPredecessorPool() {
        // given
        let filter = createFilter()
        let addLiquidity = createEdge(from: 0, to: 1, poolId: stableswapPool)
        let withdraw = createEdge(from: 1, to: 2, poolId: stableswapPool)

        // when
        let shouldVisit = filter.shouldVisit(edge: withdraw, predecessor: addLiquidity)

        // then
        XCTAssertFalse(shouldVisit)
    }

    func testAllowsEdgeEnteringAnotherPool() {
        // given
        let filter = createFilter()
        let stableswap = createEdge(from: 0, to: 1, poolId: stableswapPool)
        let omnipoolSwap = createEdge(from: 1, to: 2, poolId: omnipool)

        // when
        let shouldVisit = filter.shouldVisit(edge: omnipoolSwap, predecessor: stableswap)

        // then
        XCTAssertTrue(shouldVisit)
    }

    func testAllowsEdgesWithoutPool() {
        // given
        let filter = createFilter()
        let first = createEdge(from: 0, to: 1, poolId: nil)
        let second = createEdge(from: 1, to: 2, poolId: nil)

        // when
        let shouldVisit = filter.shouldVisit(edge: second, predecessor: first)

        // then
        XCTAssertTrue(shouldVisit)
    }
}

private extension AssetExchangePathFilterTests {
    struct SufficientAssets: AssetExchangeSufficiencyProviding {
        func isSufficient(asset _: AssetModel) -> Bool { true }
    }

    struct AnyAssetPaysFee: AssetExchangeFeeSupporting {
        func canPayFee(inNonNative _: ChainAssetId) -> Bool { true }
    }

    struct ImmediateExecution: WalletDelayedExecVerifing {
        func executesCallWithDelay(_: MetaAccountModel, chain _: ChainModel) -> Bool { false }
    }

    func createFilter() -> AssetExchangePathFilter {
        AssetExchangePathFilter(
            selectedWallet: AccountGenerator.generateMetaAccount(),
            chainRegistry: MockChainRegistryProtocol().applyDefault(for: [chain]),
            sufficiencyProvider: SufficientAssets(),
            feeSupport: AnyAssetPaysFee(),
            delayedCallExecVerifier: ImmediateExecution()
        )
    }

    func createEdge(from: AssetModel.Id, to: AssetModel.Id, poolId: AssetExchangePoolId?) -> AnyAssetExchangeEdge {
        AnyAssetExchangeEdge(
            StubAssetExchangeEdge(
                origin: CommissionTestFixtures.asset(from),
                destination: CommissionTestFixtures.asset(to),
                type: .hydraSwap,
                chain: chain,
                poolId: poolId
            )
        )
    }
}
