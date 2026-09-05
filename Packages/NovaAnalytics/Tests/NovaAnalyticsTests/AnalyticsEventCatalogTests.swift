import XCTest
@testable import NovaAnalytics

final class AnalyticsEventCatalogTests: XCTestCase {
    private struct Row {
        let event: AnalyticsEvent
        let expectedJSON: String
        let line: UInt
    }

    private let timestamp = "2026-09-02T10:00:00.123Z"

    private func serialize(_ event: AnalyticsEvent) throws -> String {
        let remote = AnalyticsEventRemote(
            name: event.name.rawValue,
            ts: timestamp,
            props: event.wireProperties
        )

        return String(data: try AnalyticsCoding.encoder.encode(remote), encoding: .utf8)!
    }

    private var catalog: [Row] {
        lifecycleRows + onboardingRows + navigationRows + swapRows
            + stakingRows + sendRows + dappRows + rampRows
    }

    private var lifecycleRows: [Row] {
        [
            Row(
                event: .appOpened(isFirstLaunch: false),
                expectedJSON: #"{"name":"app_opened","props":{"is_first_launch":false},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sessionStarted(),
                expectedJSON: #"{"name":"session_started","props":{},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sessionEnded(duration: 42),
                expectedJSON: #"{"name":"session_ended","props":{"duration_bucket":"30s_to_60s"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var onboardingRows: [Row] {
        [
            Row(
                event: .onboardingStarted(source: .freshInstall),
                expectedJSON: #"{"name":"onboarding_started","props":{"source":"fresh_install"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .walletImportMethodSelected(method: .importMnemonic),
                expectedJSON: #"{"name":"wallet_import_method_selected","props":{"method":"import_mnemonic"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .walletCreationStarted(),
                expectedJSON: #"{"name":"wallet_creation_started","props":{},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .walletCreationCompleted(method: .create, duration: nil),
                expectedJSON: #"{"name":"wallet_creation_completed","props":{"method":"create"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .walletCreationAbandoned(lastStep: .confirmMnemonic),
                expectedJSON: #"{"name":"wallet_creation_abandoned","props":{"last_step":"confirm_mnemonic"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var navigationRows: [Row] {
        [
            Row(
                event: .featureOpened(.staking),
                expectedJSON: #"{"name":"feature_opened","props":{"feature_id":"staking"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .tabSwitched(tab: .staking),
                expectedJSON: #"{"name":"tab_switched","props":{"tab":"staking"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .novaCardOpened(),
                expectedJSON: #"{"name":"nova_card_opened","props":{},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .nftSectionOpened(count: 3),
                expectedJSON: #"{"name":"nft_section_opened","props":{"nft_count":3},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .bannerClicked(id: .bannerId("ahm-2026"), screen: .assets),
                expectedJSON: #"{"name":"banner_clicked","props":{"banner_id":"ahm-2026","screen":"assets"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var swapRows: [Row] {
        [
            Row(
                event: .swapScreenOpened(source: .assetDetails),
                expectedJSON: #"{"name":"swap_screen_opened","props":{"source":"asset_details"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .swapInitiated(
                    source: .mainScreen,
                    assetIn: .assetSymbol("DOT"),
                    assetOut: .assetSymbol("USDT"),
                    networkIn: .networkName("Polkadot"),
                    networkOut: .networkName("Polkadot Asset Hub"),
                    amount: 100,
                    price: 5
                )!,
                expectedJSON: #"{"name":"swap_initiated","props":{"amount_bucket":"100_to_1k","asset_in":"DOT","asset_in_category":"native_token","asset_out":"USDT","asset_out_category":"stablecoin","network_in":"Polkadot","network_out":"Polkadot Asset Hub","source":"main_screen"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .swapConfirmed(
                    assetIn: .assetSymbol("DOT"),
                    assetOut: .assetSymbol("USDT"),
                    networkIn: .networkName("Polkadot"),
                    networkOut: .networkName("Polkadot Asset Hub"),
                    amount: 100,
                    price: 5,
                    slippage: 0.5
                )!,
                expectedJSON: #"{"name":"swap_confirmed","props":{"amount_bucket":"100_to_1k","asset_in":"DOT","asset_out":"USDT","network_in":"Polkadot","network_out":"Polkadot Asset Hub","slippage_bucket":"low"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .swapCompleted(
                    assetIn: .assetSymbol("DOT"),
                    assetOut: .assetSymbol("USDT"),
                    networkIn: .networkName("Polkadot"),
                    networkOut: .networkName("Polkadot Asset Hub"),
                    amount: 100,
                    price: 5,
                    duration: 20
                )!,
                expectedJSON: #"{"name":"swap_completed","props":{"amount_bucket":"100_to_1k","asset_in":"DOT","asset_out":"USDT","duration_bucket":"15s_to_30s","network_in":"Polkadot","network_out":"Polkadot Asset Hub"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .swapFailed(reason: .executionReverted),
                expectedJSON: #"{"name":"swap_failed","props":{"reason":"execution_reverted"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .swapAbandoned(stage: .setup),
                expectedJSON: #"{"name":"swap_abandoned","props":{"stage":"setup"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var stakingRows: [Row] {
        [
            Row(
                event: .stakingFlowOpened(network: .networkName("Polkadot"), source: .dashboard),
                expectedJSON: #"{"name":"staking_flow_opened","props":{"network":"Polkadot","source":"dashboard"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .stakingTypeSelected(type: .pool, network: .networkName("Polkadot")),
                expectedJSON: #"{"name":"staking_type_selected","props":{"network":"Polkadot","staking_type":"pool"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .stakingInitiated(type: .direct, network: .networkName("Polkadot"), amount: 10, rate: 5),
                expectedJSON: #"{"name":"staking_initiated","props":{"amount_bucket":"10_to_100","network":"Polkadot","staking_type":"direct"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .stakingConfirmed(type: .direct, network: .networkName("Polkadot"), amount: 10, rate: 5),
                expectedJSON: #"{"name":"staking_confirmed","props":{"amount_bucket":"10_to_100","network":"Polkadot","staking_type":"direct"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .stakingCompleted(type: .mythos, network: .networkName("Mythos"), amount: 10, rate: nil),
                expectedJSON: #"{"name":"staking_completed","props":{"amount_bucket":"under_1","network":"Mythos","staking_type":"mythos"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .stakingFailed(type: .direct, network: .networkName("Polkadot"), reason: .networkError),
                expectedJSON: #"{"name":"staking_failed","props":{"network":"Polkadot","reason":"network_error","staking_type":"direct"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .stakingAbandoned(stage: .typeSelection),
                expectedJSON: #"{"name":"staking_abandoned","props":{"stage":"type_selection"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .unstakeInitiated(type: .pool, network: .networkName("Polkadot"), amount: 10, rate: 5),
                expectedJSON: #"{"name":"unstake_initiated","props":{"amount_bucket":"10_to_100","network":"Polkadot","staking_type":"pool"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .unstakeCompleted(type: .pool, network: .networkName("Polkadot"), amount: 10, rate: 5),
                expectedJSON: #"{"name":"unstake_completed","props":{"amount_bucket":"10_to_100","network":"Polkadot","staking_type":"pool"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .unstakeFailed(type: .unsupported, network: .networkName("Polkadot"), reason: .userCancelled),
                expectedJSON: #"{"name":"unstake_failed","props":{"network":"Polkadot","reason":"user_cancelled","staking_type":"unsupported"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var sendRows: [Row] {
        [
            Row(
                event: .sendInitiated(
                    asset: .assetSymbol("DOT"),
                    network: .networkName("Polkadot"),
                    destinationNetwork: nil,
                    amount: 10,
                    rate: 5,
                    isCrossChain: false
                ),
                expectedJSON: #"{"name":"send_initiated","props":{"amount_bucket":"10_to_100","asset":"DOT","asset_category":"native_token","is_cross_chain":false,"network":"Polkadot"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sendCompleted(
                    asset: .assetSymbol("DOT"),
                    network: .networkName("Polkadot"),
                    destinationNetwork: nil,
                    amount: 10,
                    rate: 5
                ),
                expectedJSON: #"{"name":"send_completed","props":{"amount_bucket":"10_to_100","asset":"DOT","network":"Polkadot"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sendCompleted(
                    asset: .assetSymbol("USDT"),
                    network: .networkName("Polkadot Asset Hub"),
                    destinationNetwork: .networkName("Hydration"),
                    amount: 10,
                    rate: 1
                ),
                expectedJSON: #"{"name":"send_completed","props":{"amount_bucket":"10_to_100","asset":"USDT","destination_network":"Hydration","network":"Polkadot Asset Hub"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sendFailed(
                    asset: .assetSymbol("DOT"),
                    network: .networkName("Polkadot"),
                    destinationNetwork: .networkName("Hydration"),
                    reason: .unknown
                ),
                expectedJSON: #"{"name":"send_failed","props":{"asset":"DOT","destination_network":"Hydration","network":"Polkadot","reason":"unknown"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var dappRows: [Row] {
        [
            Row(
                event: .dappOpened(host: .dappHost("app.example.org"), source: .catalog, isKnown: true),
                expectedJSON: #"{"name":"dapp_opened","props":{"dapp_host":"app.example.org","is_known_dapp":true,"source":"catalog"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .signRequestShown(
                    source: .dappBrowser,
                    method: .signingMethod("polkadot_signPayload"),
                    chain: .caip2Chain("polkadot:91b171bb158e2d3848fa23a9f1c25182")
                ),
                expectedJSON: #"{"name":"sign_request_shown","props":{"chain":"polkadot:91b171bb158e2d3848fa23a9f1c25182","method":"polkadot_signPayload","source":"dapp_browser"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .signApproved(
                    source: .dappBrowser,
                    method: .signingMethod("polkadot_signPayload"),
                    chain: .caip2Chain("polkadot:91b171bb158e2d3848fa23a9f1c25182")
                ),
                expectedJSON: #"{"name":"sign_approved","props":{"chain":"polkadot:91b171bb158e2d3848fa23a9f1c25182","method":"polkadot_signPayload","source":"dapp_browser"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .signRejected(
                    source: .walletConnect,
                    method: .signingMethod("eth_sendTransaction"),
                    chain: .caip2Chain("eip155:1")
                ),
                expectedJSON: #"{"name":"sign_rejected","props":{"chain":"eip155:1","method":"eth_sendTransaction","source":"walletconnect"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .signFailed(
                    source: .walletConnect,
                    method: .signingMethod("eth_sendTransaction"),
                    chain: .caip2Chain("eip155:1"),
                    reason: .unsupportedRequest
                ),
                expectedJSON: #"{"name":"sign_failed","props":{"chain":"eip155:1","method":"eth_sendTransaction","reason":"unsupported_request","source":"walletconnect"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .governanceVoteCast(
                    direction: .aye,
                    network: .networkName("Polkadot"),
                    amount: 10,
                    rate: 5,
                    conviction: .locked3x
                ),
                expectedJSON: #"{"name":"governance_vote_cast","props":{"amount_bucket":"10_to_100","conviction_level":"3x","network":"Polkadot","vote_direction":"aye"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var rampRows: [Row] {
        [
            Row(
                event: .buyInitiated(
                    provider: .providerId("mercuryo"),
                    asset: .assetSymbol("DOT"),
                    network: .networkName("Polkadot")
                ),
                expectedJSON: #"{"name":"buy_initiated","props":{"asset":"DOT","network":"Polkadot","provider":"mercuryo"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .buyCompleted(
                    provider: .providerId("mercuryo"),
                    asset: .assetSymbol("DOT"),
                    network: .networkName("Polkadot")
                ),
                expectedJSON: #"{"name":"buy_completed","props":{"asset":"DOT","network":"Polkadot","provider":"mercuryo"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sellInitiated(
                    provider: .providerId("mercuryo"),
                    asset: .assetSymbol("DOT"),
                    network: .networkName("Polkadot")
                ),
                expectedJSON: #"{"name":"sell_initiated","props":{"asset":"DOT","network":"Polkadot","provider":"mercuryo"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sellCompleted(
                    provider: .providerId("mercuryo"),
                    asset: .assetSymbol("DOT"),
                    network: .networkName("Polkadot")
                ),
                expectedJSON: #"{"name":"sell_completed","props":{"asset":"DOT","network":"Polkadot","provider":"mercuryo"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    func testCatalogSerializesToTheAgreedWireShape() throws {
        for row in catalog {
            XCTAssertEqual(try serialize(row.event), row.expectedJSON, line: row.line)
        }
    }

    func testCatalogCoversEveryEventName() {
        let covered = Set(catalog.map(\.event.name))
        let missing = Set(AnalyticsEventName.allCases).subtracting(covered)

        XCTAssertTrue(
            missing.isEmpty,
            "catalog table is missing rows for: \(missing.map(\.rawValue).sorted().joined(separator: ", "))"
        )
    }

    func testEveryEmittedKeyIsDeclared() {
        let declared = Set(AnalyticsPropertyKey.allCases.map(\.rawValue))

        for row in catalog {
            for key in row.event.wireProperties.keys {
                XCTAssertTrue(declared.contains(key), "undeclared key \(key) in \(row.event.name.rawValue)")
            }
        }
    }

    func testPersistedPayloadIsByteStable() throws {
        for row in catalog {
            let first = try AnalyticsCoding.encoder.encode(row.event.wireProperties)
            let decoded = try AnalyticsCoding.decoder.decode(
                [String: AnalyticsPropertyValue].self,
                from: first
            )
            let second = try AnalyticsCoding.encoder.encode(decoded)

            XCTAssertEqual(first, second, "\(row.event.name.rawValue) is not byte-stable", line: row.line)
        }
    }

    func testSwapEventsAreSkippedWithoutAFiatRate() {
        XCTAssertNil(AnalyticsEvent.swapInitiated(
            source: .mainScreen,
            assetIn: .assetSymbol("DOT"),
            assetOut: .assetSymbol("USDT"),
            networkIn: .networkName("Polkadot"),
            networkOut: .networkName("Polkadot Asset Hub"),
            amount: 100,
            price: nil
        ))

        XCTAssertNil(AnalyticsEvent.swapConfirmed(
            assetIn: .assetSymbol("DOT"),
            assetOut: .assetSymbol("USDT"),
            networkIn: .networkName("Polkadot"),
            networkOut: .networkName("Polkadot Asset Hub"),
            amount: 100,
            price: nil,
            slippage: 0.5
        ))

        XCTAssertNil(AnalyticsEvent.swapCompleted(
            assetIn: .assetSymbol("DOT"),
            assetOut: .assetSymbol("USDT"),
            networkIn: .networkName("Polkadot"),
            networkOut: .networkName("Polkadot Asset Hub"),
            amount: 100,
            price: nil,
            duration: 20
        ))
    }
}
