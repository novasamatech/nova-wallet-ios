import XCTest
@testable import novawallet
import Cuckoo
import Foundation_iOS
import NovaAnalytics

final class DAppStakingNoticeTests: XCTestCase {
    func testBittensorNoticeOffersSiteAtOnceAndOpensBittensorStaking() throws {
        // given
        let host = try makeHost("https://dash.taostats.io/validators")
        let setup = try makeSetup(kind: .bittensor, host: host)

        // when
        setup.presenter.setup()
        setup.presenter.goToStaking()

        // then
        XCTAssertEqual(
            setup.viewModels.last?.message,
            localizedStrings.dappStakingNoticeBittensorMessage()
        )
        XCTAssertEqual(setup.viewModels.last?.isContinueRevealed, true)

        verify(setup.wireframe).redirectToBittensorStaking(
            from: any(),
            source: equal(to: StakingFlowSource.dappNotice)
        )
        verify(setup.wireframe, never()).redirectToStaking(from: any())
        verify(setup.wireframe, never()).complete(from: any())

        XCTAssertEqual(
            setup.tracker.events,
            [
                .dappStakingPromptShown(placement: .notice, kind: .bittensor, host: host),
                .dappStakingPromptAction(placement: .notice, kind: .bittensor, action: .goToStaking, host: host)
            ]
        )
    }

    func testStakingNoticeKeepsAdvancedStepAndOpensStakingTab() throws {
        // given
        let host = try makeHost("https://staking.polkadot.cloud")
        let setup = try makeSetup(kind: .thirdPartyStaking, host: host)

        // when
        setup.presenter.setup()
        setup.presenter.goToStaking()

        // then
        XCTAssertEqual(setup.viewModels.last?.message, localizedStrings.dappStakingNoticeMessage())
        XCTAssertEqual(setup.viewModels.last?.isContinueRevealed, false)

        verify(setup.wireframe).redirectToStaking(from: any())
        verify(setup.wireframe, never()).redirectToBittensorStaking(from: any(), source: any())

        XCTAssertEqual(
            setup.tracker.events,
            [
                .dappStakingPromptShown(placement: .notice, kind: .staking, host: host),
                .dappStakingPromptAction(placement: .notice, kind: .staking, action: .goToStaking, host: host)
            ]
        )
    }

    func testContinueToSiteCompletesWithoutOpeningStaking() throws {
        for (siteKind, promptKind) in [
            (DAppStakingSiteKind.bittensor, DAppStakingPromptKind.bittensor),
            (DAppStakingSiteKind.thirdPartyStaking, DAppStakingPromptKind.staking)
        ] {
            // given
            let host = try makeHost("https://tao.app")
            let setup = try makeSetup(kind: siteKind, host: host)

            // when
            setup.presenter.setup()
            setup.presenter.continueToSite()

            // then
            verify(setup.wireframe).complete(from: any())
            verify(setup.wireframe, never()).redirectToStaking(from: any())
            verify(setup.wireframe, never()).redirectToBittensorStaking(from: any(), source: any())

            XCTAssertEqual(
                setup.tracker.events,
                [
                    .dappStakingPromptShown(placement: .notice, kind: promptKind, host: host),
                    .dappStakingPromptAction(
                        placement: .notice,
                        kind: promptKind,
                        action: .continueToSite,
                        host: host
                    )
                ]
            )
        }
    }

    func testEventsHaveNoHostWhenItIsUnavailable() throws {
        // given
        let setup = try makeSetup(kind: .bittensor, host: nil)

        // when
        setup.presenter.setup()
        setup.presenter.continueToSite()

        // then
        XCTAssertEqual(
            setup.tracker.events,
            [
                .dappStakingPromptShown(placement: .notice, kind: .bittensor, host: nil),
                .dappStakingPromptAction(placement: .notice, kind: .bittensor, action: .continueToSite, host: nil)
            ]
        )
        XCTAssertTrue(setup.tracker.events.allSatisfy { $0.properties[.dappHost] == nil })
    }

    func testNoContextForSiteWithoutNotice() {
        XCTAssertNil(DAppStakingNoticeContext(kind: .none, host: nil))
    }

    func testBittensorMessageMatchesSpec() {
        XCTAssertEqual(
            R.string(preferredLanguages: ["en"]).localizable.dappStakingNoticeBittensorMessage(),
            "Third-party staking sites often become deprecated. Nova Wallet has built-in staking for Bittensor."
        )
    }
}

// MARK: Private

private extension DAppStakingNoticeTests {
    final class Setup {
        let presenter: DAppStakingNoticePresenter
        let view: MockDAppStakingNoticeViewProtocol
        let wireframe: MockDAppStakingNoticeWireframeProtocol
        let tracker: AnalyticsTrackerSpy
        var viewModels: [DAppStakingNoticeViewModel] = []

        init(context: DAppStakingNoticeContext) {
            let view = MockDAppStakingNoticeViewProtocol()
            let wireframe = MockDAppStakingNoticeWireframeProtocol()
            let tracker = AnalyticsTrackerSpy()

            self.view = view
            self.wireframe = wireframe
            self.tracker = tracker

            presenter = DAppStakingNoticePresenter(
                context: context,
                wireframe: wireframe,
                analyticsTracker: tracker,
                localizationManager: LocalizationManager.shared
            )

            presenter.view = view

            stub(view) { stub in
                when(stub.didReceive(viewModel: any())).then { [weak self] viewModel in
                    self?.viewModels.append(viewModel)
                }
            }

            stub(wireframe) { stub in
                when(stub.redirectToStaking(from: any())).thenDoNothing()
                when(stub.redirectToBittensorStaking(from: any(), source: any())).thenDoNothing()
                when(stub.complete(from: any())).thenDoNothing()
            }
        }
    }

    var localizedStrings: _R.string.localizable {
        R.string(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages).localizable
    }

    func makeHost(_ urlString: String) throws -> AnalyticsContentValue {
        let url = try XCTUnwrap(URL(string: urlString))

        return try XCTUnwrap(AnalyticsContentValue.dappHost(url))
    }

    func makeSetup(kind: DAppStakingSiteKind, host: AnalyticsContentValue?) throws -> Setup {
        let context = try XCTUnwrap(DAppStakingNoticeContext(kind: kind, host: host))

        return Setup(context: context)
    }
}
