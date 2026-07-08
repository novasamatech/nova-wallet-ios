import XCTest
import BigInt
@testable import novawallet

final class StakingDashboardBuilderDemotionTests: XCTestCase {
    func testDemotedChainRoutesToMoreOptions() {
        // given
        let alephZeroChain = ChainModelGenerator.generateChain(
            defaultChainId: KnowChainId.alephZero,
            generatingAssets: 1,
            addressPrefix: 42,
            hasStaking: true
        )

        let asset = alephZeroChain.assets.first!
        let chainAsset = ChainAsset(chain: alephZeroChain, asset: asset)

        let expectation = XCTestExpectation(description: "result closure called")
        var resultModel: StakingDashboardModel?

        let callbackQueue = DispatchQueue(label: "test.callback")
        let builder = StakingDashboardBuilder(
            callbackQueue: callbackQueue,
            resultClosure: { result in
                resultModel = result.model
                expectation.fulfill()
            }
        )

        builder.applyAssets(models: [chainAsset])

        // when
        wait(for: [expectation], timeout: 5)
        let model = resultModel

        // then
        XCTAssertNotNil(model, "Model should be generated")

        let moreChainIds = Set(model?.more.map(\.chainAsset.chain.chainId) ?? [])
        let inactiveChainIds = Set(model?.inactive.map(\.chainAsset.chain.chainId) ?? [])

        XCTAssertTrue(
            moreChainIds.contains(KnowChainId.alephZero),
            "Aleph Zero should be in more options"
        )
        XCTAssertFalse(
            inactiveChainIds.contains(KnowChainId.alephZero),
            "Aleph Zero should NOT be in inactive section"
        )
    }

    func testNonDemotedChainRoutesToInactiveSection() {
        // given
        let polkadotChain = ChainModelGenerator.generateChain(
            defaultChainId: KnowChainId.polkadot,
            generatingAssets: 1,
            addressPrefix: 0,
            hasStaking: true
        )

        let asset = polkadotChain.assets.first!
        let chainAsset = ChainAsset(chain: polkadotChain, asset: asset)

        let expectation = XCTestExpectation(description: "result closure called")
        var resultModel: StakingDashboardModel?

        let callbackQueue = DispatchQueue(label: "test.callback")
        let builder = StakingDashboardBuilder(
            callbackQueue: callbackQueue,
            resultClosure: { result in
                resultModel = result.model
                expectation.fulfill()
            }
        )

        builder.applyAssets(models: [chainAsset])

        // when
        wait(for: [expectation], timeout: 5)
        let model = resultModel

        // then
        XCTAssertNotNil(model, "Model should be generated")

        let moreChainIds = Set(model?.more.map(\.chainAsset.chain.chainId) ?? [])
        let inactiveChainIds = Set(model?.inactive.map(\.chainAsset.chain.chainId) ?? [])

        XCTAssertTrue(
            inactiveChainIds.contains(KnowChainId.polkadot),
            "Polkadot should be in inactive section"
        )
        XCTAssertFalse(
            moreChainIds.contains(KnowChainId.polkadot),
            "Polkadot should NOT be in more options"
        )
    }

    func testDemotedChainWithActiveStakeStillAppearsInActive() {
        // given
        let alephZeroChain = ChainModelGenerator.generateChain(
            defaultChainId: KnowChainId.alephZero,
            generatingAssets: 1,
            addressPrefix: 42,
            hasStaking: true
        )

        let asset = alephZeroChain.assets.first!
        let chainAsset = ChainAsset(chain: alephZeroChain, asset: asset)

        let walletModel = AccountGenerator.generateMetaAccount()

        let dashboardItem = Multistaking.DashboardItem(
            stakingOption: .init(
                walletId: walletModel.metaId,
                option: .init(
                    chainAssetId: chainAsset.chainAssetId,
                    type: .relaychain
                )
            ),
            onchainState: .active,
            hasAssignedStake: true,
            stake: BigUInt(1_000_000_000_000),
            totalRewards: nil,
            maxApy: nil
        )

        let expectationWallet = XCTestExpectation(description: "wallet result closure called")
        let expectationAssets = XCTestExpectation(description: "assets result closure called")
        let expectationDashboard = XCTestExpectation(description: "dashboard result closure called")

        var callCount = 0
        var resultModel: StakingDashboardModel?

        let callbackQueue = DispatchQueue(label: "test.callback")
        let builder = StakingDashboardBuilder(
            callbackQueue: callbackQueue,
            resultClosure: { result in
                callCount += 1
                resultModel = result.model
                switch callCount {
                case 1:
                    expectationWallet.fulfill()
                case 2:
                    expectationAssets.fulfill()
                case 3:
                    expectationDashboard.fulfill()
                default:
                    break
                }
            }
        )

        builder.applyWallet(model: walletModel)
        wait(for: [expectationWallet], timeout: 5)

        builder.applyAssets(models: [chainAsset])
        wait(for: [expectationAssets], timeout: 5)

        builder.applyDashboardItem(changes: [.insert(newItem: dashboardItem)])
        wait(for: [expectationDashboard], timeout: 5)

        // when
        let model = resultModel

        // then
        XCTAssertNotNil(model, "Model should be generated")

        let activeChainIds = Set(model?.active.map(\.stakingOption.chainAsset.chain.chainId) ?? [])
        let moreChainIds = Set(model?.more.map(\.chainAsset.chain.chainId) ?? [])

        XCTAssertTrue(
            activeChainIds.contains(KnowChainId.alephZero),
            "Aleph Zero with active stake should be in active section"
        )
        XCTAssertFalse(
            moreChainIds.contains(KnowChainId.alephZero),
            "Aleph Zero with active stake should NOT be in more options"
        )
    }
}
