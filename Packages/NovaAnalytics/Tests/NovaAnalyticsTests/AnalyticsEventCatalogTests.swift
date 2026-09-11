import XCTest
@testable import NovaAnalytics

final class AnalyticsEventCatalogTests: XCTestCase {
    private struct Row {
        let event: AnalyticsEvent
        let wire: String
        let line: UInt

        init(_ event: AnalyticsEvent, _ wire: String, line: UInt = #line) {
            self.event = event
            self.wire = wire
            self.line = line
        }
    }

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

    private var catalog: [Row] {
        [
            Row(.appOpened(isFirstLaunch: false), #""name":"app_opened","props":{"is_first_launch":false}"#),
            Row(.sessionStarted(), #""name":"session_started","props":{}"#),
            Row(.sessionEnded(duration: 42), #""name":"session_ended","props":{"duration_bucket":"30s_to_60s"}"#),
            Row(.onboardingStarted(source: .freshInstall), #""name":"onboarding_started","props":{"source":"fresh_install"}"#),
            Row(.walletImportMethodSelected(method: .importMnemonic), #""name":"wallet_import_method_selected","props":{"method":"import_mnemonic"}"#),
            Row(.walletCreationStarted(), #""name":"wallet_creation_started","props":{}"#),
            Row(.walletCreationCompleted(method: .create, duration: nil), #""name":"wallet_creation_completed","props":{"method":"create"}"#),
            Row(.walletCreationAbandoned(lastStep: .confirmMnemonic), #""name":"wallet_creation_abandoned","props":{"last_step":"confirm_mnemonic"}"#),
            Row(.featureOpened(.staking), #""name":"feature_opened","props":{"feature_id":"staking"}"#),
            Row(.tabSwitched(tab: .staking), #""name":"tab_switched","props":{"tab":"staking"}"#),
            Row(.novaCardOpened(), #""name":"nova_card_opened","props":{}"#),
            Row(.nftSectionOpened(count: NftCountBucket(count: 3)), #""name":"nft_section_opened","props":{"nft_count_bucket":"1_to_10"}"#),
            Row(.bannerClicked(id: ahmBanner, screen: .assets), #""name":"banner_clicked","props":{"banner_id":"ahm-2026","screen":"assets"}"#),
            Row(.swapScreenOpened(source: .assetDetails), #""name":"swap_screen_opened","props":{"source":"asset_details"}"#),
            Row(
                .swapInitiated(source: .mainScreen, assetIn: dot, assetOut: usdt, networkIn: polkadot, networkOut: assetHub, amount: 100, price: 5)!,
                #""name":"swap_initiated","props":{"amount_bucket":"100_to_1k","asset_in":"DOT","asset_in_category":"native_token","asset_out":"USDT","asset_out_category":"stablecoin","network_in":"Polkadot","network_out":"Polkadot Asset Hub","source":"main_screen"}"#
            ),
            Row(
                .swapConfirmed(assetIn: dot, assetOut: usdt, networkIn: polkadot, networkOut: assetHub, amount: 100, price: 5, slippage: 0.5)!,
                #""name":"swap_confirmed","props":{"amount_bucket":"100_to_1k","asset_in":"DOT","asset_out":"USDT","network_in":"Polkadot","network_out":"Polkadot Asset Hub","slippage_bucket":"low"}"#
            ),
            Row(
                .swapCompleted(assetIn: dot, assetOut: usdt, networkIn: polkadot, networkOut: assetHub, amount: 100, price: 5, duration: 20)!,
                #""name":"swap_completed","props":{"amount_bucket":"100_to_1k","asset_in":"DOT","asset_out":"USDT","duration_bucket":"15s_to_30s","network_in":"Polkadot","network_out":"Polkadot Asset Hub"}"#
            ),
            Row(.swapFailed(reason: .executionReverted), #""name":"swap_failed","props":{"reason":"execution_reverted"}"#),
            Row(.swapAbandoned(stage: .setup), #""name":"swap_abandoned","props":{"stage":"setup"}"#),
            Row(.stakingFlowOpened(network: polkadot, source: .dashboard), #""name":"staking_flow_opened","props":{"network":"Polkadot","source":"dashboard"}"#),
            Row(.stakingTypeSelected(type: .pool, network: polkadot), #""name":"staking_type_selected","props":{"network":"Polkadot","staking_type":"pool"}"#),
            Row(.stakingInitiated(type: .direct, network: polkadot, amount: 10, rate: 5), #""name":"staking_initiated","props":{"amount_bucket":"10_to_100","network":"Polkadot","staking_type":"direct"}"#),
            Row(.stakingConfirmed(type: .direct, network: polkadot, amount: 10, rate: 5), #""name":"staking_confirmed","props":{"amount_bucket":"10_to_100","network":"Polkadot","staking_type":"direct"}"#),
            Row(.stakingCompleted(type: .mythos, network: mythos, amount: 10, rate: nil), #""name":"staking_completed","props":{"amount_bucket":"under_1","network":"Mythos","staking_type":"mythos"}"#),
            Row(.stakingFailed(type: .direct, network: polkadot, reason: .networkError), #""name":"staking_failed","props":{"network":"Polkadot","reason":"network_error","staking_type":"direct"}"#),
            Row(.stakingAbandoned(stage: .typeSelection), #""name":"staking_abandoned","props":{"stage":"type_selection"}"#),
            Row(.unstakeInitiated(type: .pool, network: polkadot, amount: 10, rate: 5), #""name":"unstake_initiated","props":{"amount_bucket":"10_to_100","network":"Polkadot","staking_type":"pool"}"#),
            Row(.unstakeCompleted(type: .pool, network: polkadot, amount: 10, rate: 5), #""name":"unstake_completed","props":{"amount_bucket":"10_to_100","network":"Polkadot","staking_type":"pool"}"#),
            Row(.unstakeFailed(type: .unsupported, network: polkadot, reason: .userCancelled), #""name":"unstake_failed","props":{"network":"Polkadot","reason":"user_cancelled","staking_type":"unsupported"}"#),
            Row(
                .sendInitiated(asset: dot, network: polkadot, destinationNetwork: nil, amount: 10, rate: 5, isCrossChain: false),
                #""name":"send_initiated","props":{"amount_bucket":"10_to_100","asset":"DOT","asset_category":"native_token","is_cross_chain":false,"network":"Polkadot"}"#
            ),
            Row(
                .sendCompleted(asset: dot, network: polkadot, destinationNetwork: nil, amount: 10, rate: 5),
                #""name":"send_completed","props":{"amount_bucket":"10_to_100","asset":"DOT","network":"Polkadot"}"#
            ),
            Row(
                .sendCompleted(asset: usdt, network: assetHub, destinationNetwork: hydration, amount: 10, rate: 1),
                #""name":"send_completed","props":{"amount_bucket":"10_to_100","asset":"USDT","destination_network":"Hydration","network":"Polkadot Asset Hub"}"#
            ),
            Row(
                .sendFailed(asset: dot, network: polkadot, destinationNetwork: hydration, reason: .unknown),
                #""name":"send_failed","props":{"asset":"DOT","destination_network":"Hydration","network":"Polkadot","reason":"unknown"}"#
            ),
            Row(.dappOpened(host: exampleHost, source: .catalog, isKnown: true), #""name":"dapp_opened","props":{"dapp_host":"app.example.org","is_known_dapp":true,"source":"catalog"}"#),
            Row(
                .signRequestShown(source: .dappBrowser, method: signPayload, chain: polkadotChain),
                #""name":"sign_request_shown","props":{"chain":"polkadot:91b171bb158e2d3848fa23a9f1c25182","method":"polkadot_signPayload","source":"dapp_browser"}"#
            ),
            Row(
                .signApproved(source: .dappBrowser, method: signPayload, chain: polkadotChain),
                #""name":"sign_approved","props":{"chain":"polkadot:91b171bb158e2d3848fa23a9f1c25182","method":"polkadot_signPayload","source":"dapp_browser"}"#
            ),
            Row(
                .signRejected(source: .walletConnect, method: sendTransaction, chain: ethereumChain),
                #""name":"sign_rejected","props":{"chain":"eip155:1","method":"eth_sendTransaction","source":"walletconnect"}"#
            ),
            Row(
                .signFailed(source: .walletConnect, method: sendTransaction, chain: ethereumChain, reason: .unsupportedRequest),
                #""name":"sign_failed","props":{"chain":"eip155:1","method":"eth_sendTransaction","reason":"unsupported_request","source":"walletconnect"}"#
            ),
            Row(
                .governanceVoteCast(direction: .aye, network: polkadot, amount: 10, rate: 5, conviction: .locked3x),
                #""name":"governance_vote_cast","props":{"amount_bucket":"10_to_100","conviction_level":"3x","network":"Polkadot","vote_direction":"aye"}"#
            ),
            Row(.buyInitiated(provider: mercuryo, asset: dot, network: polkadot), #""name":"buy_initiated","props":{"asset":"DOT","network":"Polkadot","provider":"mercuryo"}"#),
            Row(.buyCompleted(provider: mercuryo, asset: dot, network: polkadot), #""name":"buy_completed","props":{"asset":"DOT","network":"Polkadot","provider":"mercuryo"}"#),
            Row(.sellInitiated(provider: mercuryo, asset: dot, network: polkadot), #""name":"sell_initiated","props":{"asset":"DOT","network":"Polkadot","provider":"mercuryo"}"#),
            Row(.sellCompleted(provider: mercuryo, asset: dot, network: polkadot), #""name":"sell_completed","props":{"asset":"DOT","network":"Polkadot","provider":"mercuryo"}"#)
        ]
    }

    private func serialize(_ event: AnalyticsEvent) throws -> String {
        let row = AnalyticsPendingEvent(
            identifier: "row-1",
            sequence: 1,
            name: event.name.rawValue,
            timestamp: Date(timeIntervalSince1970: 1_788_343_200.123),
            payload: try AnalyticsCoding.encoder.encode(event.wireProperties),
            consentEpoch: 1
        )

        let remote = try AnalyticsWirePayloadPolicy.vet(row)

        return try XCTUnwrap(String(data: try AnalyticsCoding.encoder.encode(remote), encoding: .utf8))
    }

    func testCatalogSerializesToTheAgreedWireShape() throws {
        for row in catalog {
            XCTAssertEqual(
                try serialize(row.event),
                #"{"id":"row-1",\#(row.wire),"ts":"2026-09-02T10:00:00.123Z"}"#,
                line: row.line
            )
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
}
