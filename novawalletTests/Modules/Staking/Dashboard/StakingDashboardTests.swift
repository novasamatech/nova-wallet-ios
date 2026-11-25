import XCTest
@testable import novawallet
import Cuckoo
import Foundation_iOS
import NovaAnalytics

final class StakingDashboardTests: XCTestCase {
    func testOpenStakingForInactiveItemStartsStakingWithGivenSource() throws {
        // given
        let chainAsset = try makeStakingChainAsset()
        let network = try makeNetwork(for: chainAsset)
        let setup = makeSetup()
        let wallet = AccountGenerator.generateMetaAccount()

        setup.presenter.didReceive(wallet: wallet)
        setup.presenter.didReceive(result: makeResult(for: wallet, inactive: [chainAsset]))

        // when
        setup.presenter.openStaking(for: chainAsset.chainAssetId, source: .dappNotice)

        // then
        verify(setup.wireframe).showStartStaking(from: any(), chainAsset: equal(to: chainAsset))
        verify(setup.wireframe, never()).showStakingDetails(from: any(), option: any())

        XCTAssertEqual(
            setup.tracker.events,
            [.stakingFlowOpened(network: network, source: .dappNotice)]
        )
        XCTAssertEqual(setup.tracker.events.first?.wireSource, "dapp_notice")
    }

    func testPendingNavigationKeepsSourceUntilItemArrives() throws {
        // given
        let chainAsset = try makeStakingChainAsset()
        let network = try makeNetwork(for: chainAsset)
        let setup = makeSetup()
        let wallet = AccountGenerator.generateMetaAccount()

        setup.presenter.didReceive(wallet: wallet)

        // when
        setup.presenter.openStaking(for: chainAsset.chainAssetId, source: .dappSearchBanner)

        // then
        verify(setup.wireframe, never()).showStartStaking(from: any(), chainAsset: any())
        XCTAssertTrue(setup.tracker.events.isEmpty)

        // when
        setup.presenter.didReceive(result: makeResult(for: wallet, inactive: [chainAsset]))

        // then
        verify(setup.wireframe).showStartStaking(from: any(), chainAsset: equal(to: chainAsset))

        XCTAssertEqual(
            setup.tracker.events,
            [.stakingFlowOpened(network: network, source: .dappSearchBanner)]
        )
        XCTAssertEqual(setup.tracker.events.first?.wireSource, "dapp_search_banner")
    }

    func testOpenStakingForActiveItemShowsPositionsWithoutFlowOpenedEvent() throws {
        // given
        let chainAsset = try makeStakingChainAsset()
        let option = Multistaking.ChainAssetOption(chainAsset: chainAsset, type: .relaychain)
        let setup = makeSetup()
        let wallet = AccountGenerator.generateMetaAccount()

        setup.presenter.didReceive(wallet: wallet)
        setup.presenter.didReceive(result: makeResult(for: wallet, active: [option]))

        // when
        setup.presenter.openStaking(for: chainAsset.chainAssetId, source: .dappNotice)

        // then
        verify(setup.wireframe).showStakingDetails(from: any(), option: equal(to: option))
        verify(setup.wireframe, never()).showStartStaking(from: any(), chainAsset: any())
        XCTAssertTrue(setup.tracker.events.isEmpty)
    }

    func testDeepLinkSourceIsKept() throws {
        // given
        let chainAsset = try makeStakingChainAsset()
        let network = try makeNetwork(for: chainAsset)
        let setup = makeSetup()
        let wallet = AccountGenerator.generateMetaAccount()

        setup.presenter.didReceive(wallet: wallet)
        setup.presenter.didReceive(result: makeResult(for: wallet, inactive: [chainAsset]))

        // when
        setup.presenter.openStaking(for: chainAsset.chainAssetId, source: .deepLink)

        // then
        XCTAssertEqual(
            setup.tracker.events,
            [.stakingFlowOpened(network: network, source: .deepLink)]
        )
    }

    func testUnknownChainAssetShowsNothingAndIsDroppedByTimeout() throws {
        // given
        let knownChainAsset = try makeStakingChainAsset()
        let missingChainAsset = try makeStakingChainAsset()
        let pendingNavigationTimeout: TimeInterval = 0.05
        let setup = makeSetup(pendingNavigationTimeout: pendingNavigationTimeout)
        let wallet = AccountGenerator.generateMetaAccount()

        setup.presenter.didReceive(wallet: wallet)
        setup.presenter.didReceive(result: makeResult(for: wallet, inactive: [knownChainAsset]))

        // when
        setup.presenter.openStaking(for: missingChainAsset.chainAssetId, source: .dappNotice)

        // the timeout is scheduled on the main queue before this block and with an earlier deadline
        let timeoutExpectation = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4 * pendingNavigationTimeout) {
            timeoutExpectation.fulfill()
        }

        wait(for: [timeoutExpectation], timeout: 10.0)

        // the chain asset appears only after the timeout, when nothing must be opened anymore
        setup.presenter.didReceive(
            result: makeResult(for: wallet, inactive: [knownChainAsset, missingChainAsset])
        )

        // then
        verify(setup.wireframe, never()).showStartStaking(from: any(), chainAsset: any())
        verify(setup.wireframe, never()).showStakingDetails(from: any(), option: any())
        XCTAssertTrue(setup.tracker.events.isEmpty)
    }
}

// MARK: Private

private extension StakingDashboardTests {
    struct Setup {
        let presenter: StakingDashboardPresenter
        let view: MockStakingDashboardViewProtocol
        let wireframe: MockStakingDashboardWireframeProtocol
        let tracker: AnalyticsTrackerSpy
    }

    func makeSetup(pendingNavigationTimeout: TimeInterval = 10) -> Setup {
        let view = MockStakingDashboardViewProtocol()
        let wireframe = MockStakingDashboardWireframeProtocol()
        let tracker = AnalyticsTrackerSpy()

        let viewModelFactory = StakingDashboardViewModelFactory(
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub()),
            chainAssetViewModelFactory: ChainAssetViewModelFactory(),
            estimatedEarningsFormatter: NumberFormatter.percentBase.localizableResource()
        )

        let presenter = StakingDashboardPresenter(
            interactor: MockStakingDashboardInteractorInputProtocol(),
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            announcementViewModelFactory: AnnouncementViewModelFactory(),
            privacyStateManager: PrivacyStateManager.shared,
            localizationManager: LocalizationManager.shared,
            appearanceFacade: AppearanceFacade.shared,
            analyticsTracker: tracker,
            pendingNavigationTimeout: pendingNavigationTimeout,
            logger: Logger.shared
        )

        presenter.view = view

        stub(view) { stub in
            when(stub.didReceiveWallet(viewModel: any())).thenDoNothing()
            when(stub.didReceiveStakings(viewModel: any())).thenDoNothing()
            when(stub.didReceiveUpdate(viewModel: any())).thenDoNothing()
        }

        stub(wireframe) { stub in
            when(stub.showStartStaking(from: any(), chainAsset: any())).thenDoNothing()
            when(stub.showStakingDetails(from: any(), option: any())).thenDoNothing()
        }

        return Setup(presenter: presenter, view: view, wireframe: wireframe, tracker: tracker)
    }

    func makeStakingChainAsset() throws -> ChainAsset {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 42,
            hasStaking: true
        )

        return ChainAsset(chain: chain, asset: try XCTUnwrap(chain.utilityAsset()))
    }

    func makeNetwork(for chainAsset: ChainAsset) throws -> AnalyticsContentValue {
        try XCTUnwrap(chainAsset.chain.analyticsNetworkName)
    }

    func makeResult(
        for wallet: MetaAccountModel,
        active: [Multistaking.ChainAssetOption] = [],
        inactive: [ChainAsset] = []
    ) -> StakingDashboardBuilderResult {
        let activeItems = active.map { option in
            StakingDashboardItemModel.Concrete(
                stakingOption: option,
                dashboardItem: nil,
                accountId: nil,
                availableBalance: nil,
                price: nil,
                isOnchainSync: false,
                isOffchainSync: false
            )
        }

        let inactiveItems = inactive.map { chainAsset in
            StakingDashboardItemModel.Combined(
                chainAsset: chainAsset,
                maxApy: nil,
                accountId: nil,
                availableBalance: nil,
                price: nil,
                isOnchainSync: false,
                isOffchainSync: false
            )
        }

        return StakingDashboardBuilderResult(
            walletId: wallet.metaId,
            model: StakingDashboardModel(active: activeItems, inactive: inactiveItems),
            changeKind: .reload
        )
    }
}

private extension AnalyticsEvent {
    var wireSource: String? {
        guard case let .enumerated(value) = properties[.source] else {
            return nil
        }

        return value
    }
}
