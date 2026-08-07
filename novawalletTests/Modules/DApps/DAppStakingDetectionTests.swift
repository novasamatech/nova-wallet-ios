import XCTest
@testable import novawallet

final class DAppStakingDetectionTests: XCTestCase {
    func testStakingQueriesDetected() {
        XCTAssertTrue(DAppStakingDetection.isStakingQuery("staking"))
        XCTAssertTrue(DAppStakingDetection.isStakingQuery("dot Staking"))
        XCTAssertTrue(DAppStakingDetection.isStakingQuery("STAKE dot"))
        XCTAssertTrue(DAppStakingDetection.isStakingQuery("stake yapmak"))
        XCTAssertTrue(DAppStakingDetection.isStakingQuery("стейкинг"))
        XCTAssertTrue(DAppStakingDetection.isStakingQuery("стейкінг дот"))
        XCTAssertTrue(DAppStakingDetection.isStakingQuery("质押"))
        XCTAssertTrue(DAppStakingDetection.isStakingQuery("polkadot 質押"))
        XCTAssertTrue(DAppStakingDetection.isStakingQuery("ステーキング"))
        XCTAssertTrue(DAppStakingDetection.isStakingQuery("스테이킹"))
        XCTAssertTrue(DAppStakingDetection.isStakingQuery("staking.polkadot.cloud"))
    }

    func testNonStakingQueriesIgnored() {
        XCTAssertFalse(DAppStakingDetection.isStakingQuery(nil))
        XCTAssertFalse(DAppStakingDetection.isStakingQuery(""))
        XCTAssertFalse(DAppStakingDetection.isStakingQuery("mistake"))
        XCTAssertFalse(DAppStakingDetection.isStakingQuery("swap dot"))
        XCTAssertFalse(DAppStakingDetection.isStakingQuery("hydration"))

        // japanese "steak" must not trigger the japanese "staking" substring
        XCTAssertFalse(DAppStakingDetection.isStakingQuery("ステーキ"))
    }

    func testStakingDAppResultDetected() {
        let stakingDApp = makeDApp(url: "https://dashboard.example.com", categories: ["staking", "utilities"])

        XCTAssertTrue(
            DAppStakingDetection.isThirdPartyStakingSite(result: .dApp(model: stakingDApp), dAppList: nil)
        )

        let stakingHostDApp = makeDApp(url: "https://staking.example.com", categories: ["defi"])

        XCTAssertTrue(
            DAppStakingDetection.isThirdPartyStakingSite(result: .dApp(model: stakingHostDApp), dAppList: nil)
        )
    }

    func testNonStakingDAppResultIgnored() {
        let dexDApp = makeDApp(url: "https://app.hydration.net", categories: ["dex"])

        XCTAssertFalse(
            DAppStakingDetection.isThirdPartyStakingSite(result: .dApp(model: dexDApp), dAppList: nil)
        )
    }

    func testStakingUrlQueryDetected() {
        // host label detection works without a curated list
        XCTAssertTrue(
            DAppStakingDetection.isThirdPartyStakingSite(
                result: .query(string: "staking.polkadot.cloud"),
                dAppList: nil
            )
        )

        XCTAssertTrue(
            DAppStakingDetection.isThirdPartyStakingSite(
                result: .query(string: "https://staking.polkadot.cloud/#/overview"),
                dAppList: nil
            )
        )

        // a neutral host is matched through the curated staking category
        let dAppList = makeDAppList(
            dApps: [makeDApp(url: "https://omni.ls/app", categories: ["staking"])]
        )

        XCTAssertTrue(
            DAppStakingDetection.isThirdPartyStakingSite(
                result: .query(string: "omni.ls"),
                dAppList: dAppList
            )
        )

        // the www spelling of a curated host is the same site
        XCTAssertTrue(
            DAppStakingDetection.isThirdPartyStakingSite(
                result: .query(string: "www.omni.ls"),
                dAppList: dAppList
            )
        )

        XCTAssertTrue(
            DAppStakingDetection.isThirdPartyStakingSite(
                result: .query(string: "https://www.omni.ls/app"),
                dAppList: dAppList
            )
        )
    }

    func testNonStakingQueryResultsIgnored() {
        let dAppList = makeDAppList(
            dApps: [makeDApp(url: "https://omni.ls/app", categories: ["staking"])]
        )

        // free text falls back to a web search page, not a staking site
        XCTAssertFalse(
            DAppStakingDetection.isThirdPartyStakingSite(
                result: .query(string: "staking"),
                dAppList: dAppList
            )
        )

        XCTAssertFalse(
            DAppStakingDetection.isThirdPartyStakingSite(
                result: .query(string: "hydration.net"),
                dAppList: dAppList
            )
        )

        XCTAssertFalse(
            DAppStakingDetection.isThirdPartyStakingSite(
                result: .query(string: "https://app.hydration.net/trade"),
                dAppList: dAppList
            )
        )
    }
}

// MARK: Private

private extension DAppStakingDetectionTests {
    func makeDApp(url: String, categories: [String]) -> DApp {
        DApp(
            name: "DApp",
            url: URL(string: url)!,
            icon: nil,
            categories: categories,
            desktopOnly: nil
        )
    }

    func makeDAppList(dApps: [DApp]) -> DAppList {
        DAppList(popular: [], categories: [], dApps: dApps)
    }
}
