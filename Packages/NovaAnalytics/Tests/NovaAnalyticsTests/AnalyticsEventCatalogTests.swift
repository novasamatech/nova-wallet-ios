import XCTest
@testable import NovaAnalytics

final class AnalyticsEventCatalogTests: XCTestCase {
    private struct Row {
        let event: AnalyticsEvent
        let expectedJSON: String
        let line: UInt
    }

    private let identifier = "row-1"
    private let timestamp = Date(timeIntervalSince1970: 1_788_343_200.123)

    private let dot = AnalyticsContentValue.assetSymbol("DOT")!
    private let usdt = AnalyticsContentValue.assetSymbol("USDT")!
    private let polkadot = AnalyticsContentValue.networkName("Polkadot")!
    private let assetHub = AnalyticsContentValue.networkName("Polkadot Asset Hub")!
    private let hydration = AnalyticsContentValue.networkName("Hydration")!
    private let mythos = AnalyticsContentValue.networkName("Mythos")!
    private let exampleHost = AnalyticsContentValue.dappHost(URL(string: "https://app.example.org/swap?from=alice")!)!
    private let polkadotChain = AnalyticsContentValue.caip2Chain("polkadot:91b171bb158e2d3848fa23a9f1c25182")!
    private let ethereumChain = AnalyticsContentValue.caip2Chain("eip155:1")!
    private let signPayload = AnalyticsContentValue.signingMethod("polkadot_signPayload")!
    private let sendTransaction = AnalyticsContentValue.signingMethod("eth_sendTransaction")!
    private let mercuryo = AnalyticsContentValue.providerId("mercuryo")!
    private let ahmBanner = AnalyticsContentValue.bannerId("ahm-2026")!

    private func serialize(_ event: AnalyticsEvent) throws -> String {
        let row = AnalyticsPendingEvent(
            identifier: identifier,
            sequence: 1,
            name: event.name.rawValue,
            timestamp: timestamp,
            payload: try AnalyticsCoding.encoder.encode(event.wireProperties),
            consentEpoch: 1
        )

        let remote = try AnalyticsWirePayloadPolicy.vet(row)

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
                expectedJSON: #"{"id":"row-1","name":"app_opened","props":{"is_first_launch":false},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sessionStarted(),
                expectedJSON: #"{"id":"row-1","name":"session_started","props":{},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sessionEnded(duration: 42),
                expectedJSON: #"{"id":"row-1","name":"session_ended","props":{"duration_bucket":"30s_to_60s"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var onboardingRows: [Row] {
        [
            Row(
                event: .onboardingStarted(source: .freshInstall),
                expectedJSON: #"{"id":"row-1","name":"onboarding_started","props":{"source":"fresh_install"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .walletImportMethodSelected(method: .importMnemonic),
                expectedJSON: #"{"id":"row-1","name":"wallet_import_method_selected","props":{"method":"import_mnemonic"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .walletCreationStarted(),
                expectedJSON: #"{"id":"row-1","name":"wallet_creation_started","props":{},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .walletCreationCompleted(method: .create, duration: nil),
                expectedJSON: #"{"id":"row-1","name":"wallet_creation_completed","props":{"method":"create"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .walletCreationAbandoned(lastStep: .confirmMnemonic),
                expectedJSON: #"{"id":"row-1","name":"wallet_creation_abandoned","props":{"last_step":"confirm_mnemonic"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var navigationRows: [Row] {
        [
            Row(
                event: .featureOpened(.staking),
                expectedJSON: #"{"id":"row-1","name":"feature_opened","props":{"feature_id":"staking"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .tabSwitched(tab: .staking),
                expectedJSON: #"{"id":"row-1","name":"tab_switched","props":{"tab":"staking"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .novaCardOpened(),
                expectedJSON: #"{"id":"row-1","name":"nova_card_opened","props":{},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .nftSectionOpened(count: NftCountBucket(count: 3)),
                expectedJSON: #"{"id":"row-1","name":"nft_section_opened","props":{"nft_count_bucket":"1_to_10"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .bannerClicked(id: ahmBanner, screen: .assets),
                expectedJSON: #"{"id":"row-1","name":"banner_clicked","props":{"banner_id":"ahm-2026","screen":"assets"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var swapRows: [Row] {
        [
            Row(
                event: .swapScreenOpened(source: .assetDetails),
                expectedJSON: #"{"id":"row-1","name":"swap_screen_opened","props":{"source":"asset_details"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .swapInitiated(
                    source: .mainScreen,
                    assetIn: dot,
                    assetOut: usdt,
                    networkIn: polkadot,
                    networkOut: assetHub,
                    amount: 100,
                    price: 5
                )!,
                expectedJSON: #"{"id":"row-1","name":"swap_initiated","props":{"amount_bucket":"100_to_1k","asset_in":"DOT","asset_in_category":"native_token","asset_out":"USDT","asset_out_category":"stablecoin","network_in":"Polkadot","network_out":"Polkadot Asset Hub","source":"main_screen"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .swapConfirmed(
                    assetIn: dot,
                    assetOut: usdt,
                    networkIn: polkadot,
                    networkOut: assetHub,
                    amount: 100,
                    price: 5,
                    slippage: 0.5
                )!,
                expectedJSON: #"{"id":"row-1","name":"swap_confirmed","props":{"amount_bucket":"100_to_1k","asset_in":"DOT","asset_out":"USDT","network_in":"Polkadot","network_out":"Polkadot Asset Hub","slippage_bucket":"low"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .swapCompleted(
                    assetIn: dot,
                    assetOut: usdt,
                    networkIn: polkadot,
                    networkOut: assetHub,
                    amount: 100,
                    price: 5,
                    duration: 20
                )!,
                expectedJSON: #"{"id":"row-1","name":"swap_completed","props":{"amount_bucket":"100_to_1k","asset_in":"DOT","asset_out":"USDT","duration_bucket":"15s_to_30s","network_in":"Polkadot","network_out":"Polkadot Asset Hub"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .swapFailed(reason: .executionReverted),
                expectedJSON: #"{"id":"row-1","name":"swap_failed","props":{"reason":"execution_reverted"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .swapAbandoned(stage: .setup),
                expectedJSON: #"{"id":"row-1","name":"swap_abandoned","props":{"stage":"setup"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var stakingRows: [Row] {
        [
            Row(
                event: .stakingFlowOpened(network: polkadot, source: .dashboard),
                expectedJSON: #"{"id":"row-1","name":"staking_flow_opened","props":{"network":"Polkadot","source":"dashboard"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .stakingTypeSelected(type: .pool, network: polkadot),
                expectedJSON: #"{"id":"row-1","name":"staking_type_selected","props":{"network":"Polkadot","staking_type":"pool"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .stakingInitiated(type: .direct, network: polkadot, amount: 10, rate: 5),
                expectedJSON: #"{"id":"row-1","name":"staking_initiated","props":{"amount_bucket":"10_to_100","network":"Polkadot","staking_type":"direct"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .stakingConfirmed(type: .direct, network: polkadot, amount: 10, rate: 5),
                expectedJSON: #"{"id":"row-1","name":"staking_confirmed","props":{"amount_bucket":"10_to_100","network":"Polkadot","staking_type":"direct"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .stakingCompleted(type: .mythos, network: mythos, amount: 10, rate: nil),
                expectedJSON: #"{"id":"row-1","name":"staking_completed","props":{"amount_bucket":"under_1","network":"Mythos","staking_type":"mythos"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .stakingFailed(type: .direct, network: polkadot, reason: .networkError),
                expectedJSON: #"{"id":"row-1","name":"staking_failed","props":{"network":"Polkadot","reason":"network_error","staking_type":"direct"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .stakingAbandoned(stage: .typeSelection),
                expectedJSON: #"{"id":"row-1","name":"staking_abandoned","props":{"stage":"type_selection"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .unstakeInitiated(type: .pool, network: polkadot, amount: 10, rate: 5),
                expectedJSON: #"{"id":"row-1","name":"unstake_initiated","props":{"amount_bucket":"10_to_100","network":"Polkadot","staking_type":"pool"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .unstakeCompleted(type: .pool, network: polkadot, amount: 10, rate: 5),
                expectedJSON: #"{"id":"row-1","name":"unstake_completed","props":{"amount_bucket":"10_to_100","network":"Polkadot","staking_type":"pool"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .unstakeFailed(type: .unsupported, network: polkadot, reason: .userCancelled),
                expectedJSON: #"{"id":"row-1","name":"unstake_failed","props":{"network":"Polkadot","reason":"user_cancelled","staking_type":"unsupported"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var sendRows: [Row] {
        [
            Row(
                event: .sendInitiated(
                    asset: dot,
                    network: polkadot,
                    destinationNetwork: nil,
                    amount: 10,
                    rate: 5,
                    isCrossChain: false
                ),
                expectedJSON: #"{"id":"row-1","name":"send_initiated","props":{"amount_bucket":"10_to_100","asset":"DOT","asset_category":"native_token","is_cross_chain":false,"network":"Polkadot"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sendCompleted(
                    asset: dot,
                    network: polkadot,
                    destinationNetwork: nil,
                    amount: 10,
                    rate: 5
                ),
                expectedJSON: #"{"id":"row-1","name":"send_completed","props":{"amount_bucket":"10_to_100","asset":"DOT","network":"Polkadot"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sendCompleted(
                    asset: usdt,
                    network: assetHub,
                    destinationNetwork: hydration,
                    amount: 10,
                    rate: 1
                ),
                expectedJSON: #"{"id":"row-1","name":"send_completed","props":{"amount_bucket":"10_to_100","asset":"USDT","destination_network":"Hydration","network":"Polkadot Asset Hub"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sendFailed(
                    asset: dot,
                    network: polkadot,
                    destinationNetwork: hydration,
                    reason: .unknown
                ),
                expectedJSON: #"{"id":"row-1","name":"send_failed","props":{"asset":"DOT","destination_network":"Hydration","network":"Polkadot","reason":"unknown"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var dappRows: [Row] {
        [
            Row(
                event: .dappOpened(host: exampleHost, source: .catalog, isKnown: true),
                expectedJSON: #"{"id":"row-1","name":"dapp_opened","props":{"dapp_host":"app.example.org","is_known_dapp":true,"source":"catalog"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .signRequestShown(
                    source: .dappBrowser,
                    method: signPayload,
                    chain: polkadotChain
                ),
                expectedJSON: #"{"id":"row-1","name":"sign_request_shown","props":{"chain":"polkadot:91b171bb158e2d3848fa23a9f1c25182","method":"polkadot_signPayload","source":"dapp_browser"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .signApproved(
                    source: .dappBrowser,
                    method: signPayload,
                    chain: polkadotChain
                ),
                expectedJSON: #"{"id":"row-1","name":"sign_approved","props":{"chain":"polkadot:91b171bb158e2d3848fa23a9f1c25182","method":"polkadot_signPayload","source":"dapp_browser"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .signRejected(
                    source: .walletConnect,
                    method: sendTransaction,
                    chain: ethereumChain
                ),
                expectedJSON: #"{"id":"row-1","name":"sign_rejected","props":{"chain":"eip155:1","method":"eth_sendTransaction","source":"walletconnect"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .signFailed(
                    source: .walletConnect,
                    method: sendTransaction,
                    chain: ethereumChain,
                    reason: .unsupportedRequest
                ),
                expectedJSON: #"{"id":"row-1","name":"sign_failed","props":{"chain":"eip155:1","method":"eth_sendTransaction","reason":"unsupported_request","source":"walletconnect"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .governanceVoteCast(
                    direction: .aye,
                    network: polkadot,
                    amount: 10,
                    rate: 5,
                    conviction: .locked3x
                ),
                expectedJSON: #"{"id":"row-1","name":"governance_vote_cast","props":{"amount_bucket":"10_to_100","conviction_level":"3x","network":"Polkadot","vote_direction":"aye"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            )
        ]
    }

    private var rampRows: [Row] {
        [
            Row(
                event: .buyInitiated(
                    provider: mercuryo,
                    asset: dot,
                    network: polkadot
                ),
                expectedJSON: #"{"id":"row-1","name":"buy_initiated","props":{"asset":"DOT","network":"Polkadot","provider":"mercuryo"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .buyCompleted(
                    provider: mercuryo,
                    asset: dot,
                    network: polkadot
                ),
                expectedJSON: #"{"id":"row-1","name":"buy_completed","props":{"asset":"DOT","network":"Polkadot","provider":"mercuryo"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sellInitiated(
                    provider: mercuryo,
                    asset: dot,
                    network: polkadot
                ),
                expectedJSON: #"{"id":"row-1","name":"sell_initiated","props":{"asset":"DOT","network":"Polkadot","provider":"mercuryo"},"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: #line
            ),
            Row(
                event: .sellCompleted(
                    provider: mercuryo,
                    asset: dot,
                    network: polkadot
                ),
                expectedJSON: #"{"id":"row-1","name":"sell_completed","props":{"asset":"DOT","network":"Polkadot","provider":"mercuryo"},"ts":"2026-09-02T10:00:00.123Z"}"#,
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
                [String: AnalyticsWireValue].self,
                from: first
            )
            let second = try AnalyticsCoding.encoder.encode(decoded)

            XCTAssertEqual(first, second, "\(row.event.name.rawValue) is not byte-stable", line: row.line)
        }
    }

    func testSwapEventsAreSkippedWithoutAFiatRate() {
        XCTAssertNil(AnalyticsEvent.swapInitiated(
            source: .mainScreen,
            assetIn: dot,
            assetOut: usdt,
            networkIn: polkadot,
            networkOut: assetHub,
            amount: 100,
            price: nil
        ))

        XCTAssertNil(AnalyticsEvent.swapConfirmed(
            assetIn: dot,
            assetOut: usdt,
            networkIn: polkadot,
            networkOut: assetHub,
            amount: 100,
            price: nil,
            slippage: 0.5
        ))

        XCTAssertNil(AnalyticsEvent.swapCompleted(
            assetIn: dot,
            assetOut: usdt,
            networkIn: polkadot,
            networkOut: assetHub,
            amount: 100,
            price: nil,
            duration: 20
        ))
    }
}
