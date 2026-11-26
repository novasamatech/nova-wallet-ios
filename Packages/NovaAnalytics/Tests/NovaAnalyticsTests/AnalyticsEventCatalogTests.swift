import XCTest
@testable import NovaAnalytics

final class AnalyticsEventCatalogTests: XCTestCase {
    func testSendCompletedProperties() throws {
        let event = AnalyticsEvent.sendCompleted(
            asset: try XCTUnwrap(AnalyticsContentValue.assetSymbol("DOT")),
            network: try XCTUnwrap(AnalyticsContentValue.networkName("Polkadot")),
            destinationNetwork: nil,
            amount: 10,
            rate: 5
        )

        let data = try AnalyticsCoding.encoder.encode(event.wireProperties)

        XCTAssertEqual(event.name.rawValue, "send_completed")
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            #"{"amount_bucket":"10_to_100","asset":"DOT","network":"Polkadot"}"#
        )
    }

    func testDAppStakingPromptShownOnNoticeCarriesHost() throws {
        let url = try XCTUnwrap(URL(string: "https://Dash.Taostats.io/validators?x=1"))

        let event = AnalyticsEvent.dappStakingPromptShown(
            placement: .notice,
            kind: .bittensor,
            host: try XCTUnwrap(AnalyticsContentValue.dappHost(url))
        )

        XCTAssertEqual(event.name.rawValue, "dapp_staking_prompt_shown")
        XCTAssertEqual(
            try wireJson(of: event),
            #"{"dapp_host":"dash.taostats.io","kind":"bittensor","placement":"notice"}"#
        )
    }

    func testDAppStakingPromptShownOnSearchBannerOmitsHost() throws {
        let event = AnalyticsEvent.dappStakingPromptShown(
            placement: .searchBanner,
            kind: .staking,
            host: nil
        )

        XCTAssertEqual(event.name.rawValue, "dapp_staking_prompt_shown")
        XCTAssertEqual(try wireJson(of: event), #"{"kind":"staking","placement":"search_banner"}"#)
    }

    func testDAppStakingPromptActionProperties() throws {
        let url = try XCTUnwrap(URL(string: "https://tao.app"))

        let continueEvent = AnalyticsEvent.dappStakingPromptAction(
            placement: .notice,
            kind: .staking,
            action: .continueToSite,
            host: try XCTUnwrap(AnalyticsContentValue.dappHost(url))
        )

        XCTAssertEqual(continueEvent.name.rawValue, "dapp_staking_prompt_action")
        XCTAssertEqual(
            try wireJson(of: continueEvent),
            #"{"action":"continue_to_site","dapp_host":"tao.app","kind":"staking","placement":"notice"}"#
        )

        let goToStakingEvent = AnalyticsEvent.dappStakingPromptAction(
            placement: .searchBanner,
            kind: .bittensor,
            action: .goToStaking,
            host: nil
        )

        XCTAssertEqual(goToStakingEvent.name.rawValue, "dapp_staking_prompt_action")
        XCTAssertEqual(
            try wireJson(of: goToStakingEvent),
            #"{"action":"go_to_staking","kind":"bittensor","placement":"search_banner"}"#
        )
    }

    func testDAppStakingPromptClosedValueSets() {
        XCTAssertEqual(DAppStakingPromptPlacement.allCases.map(\.rawValue), ["search_banner", "notice"])
        XCTAssertEqual(DAppStakingPromptKind.allCases.map(\.rawValue), ["bittensor", "staking"])
        XCTAssertEqual(DAppStakingPromptAction.allCases.map(\.rawValue), ["go_to_staking", "continue_to_site"])
    }

    func testStakingFlowOpenedFromDAppPrompts() throws {
        let network = try XCTUnwrap(AnalyticsContentValue.networkName("Bittensor"))

        XCTAssertEqual(
            try wireJson(of: .stakingFlowOpened(network: network, source: .dappSearchBanner)),
            #"{"network":"Bittensor","source":"dapp_search_banner"}"#
        )

        XCTAssertEqual(
            try wireJson(of: .stakingFlowOpened(network: network, source: .dappNotice)),
            #"{"network":"Bittensor","source":"dapp_notice"}"#
        )
    }
}

private extension AnalyticsEventCatalogTests {
    func wireJson(of event: AnalyticsEvent) throws -> String? {
        let data = try AnalyticsCoding.encoder.encode(event.wireProperties)

        return String(data: data, encoding: .utf8)
    }
}
