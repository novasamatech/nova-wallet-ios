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

        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(result: .dApp(model: stakingDApp), dAppList: nil),
            .thirdPartyStaking
        )

        let stakingHostDApp = makeDApp(url: "https://staking.example.com", categories: ["defi"])

        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(result: .dApp(model: stakingHostDApp), dAppList: nil),
            .thirdPartyStaking
        )
    }

    func testNonStakingDAppResultIgnored() {
        let dexDApp = makeDApp(url: "https://app.hydration.net", categories: ["dex"])

        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(result: .dApp(model: dexDApp), dAppList: nil),
            DAppStakingSiteKind.none
        )
    }

    func testStakingUrlQueryDetected() {
        // host label detection works without a curated list
        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(
                result: .query(string: "staking.polkadot.cloud"),
                dAppList: nil
            ),
            .thirdPartyStaking
        )

        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(
                result: .query(string: "https://staking.polkadot.cloud/#/overview"),
                dAppList: nil
            ),
            .thirdPartyStaking
        )

        // a neutral host is matched through the curated staking category
        let dAppList = makeDAppList(
            dApps: [makeDApp(url: "https://omni.ls/app", categories: ["staking"])]
        )

        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(
                result: .query(string: "omni.ls"),
                dAppList: dAppList
            ),
            .thirdPartyStaking
        )

        // the www spelling of a curated host is the same site
        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(
                result: .query(string: "www.omni.ls"),
                dAppList: dAppList
            ),
            .thirdPartyStaking
        )

        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(
                result: .query(string: "https://www.omni.ls/app"),
                dAppList: dAppList
            ),
            .thirdPartyStaking
        )
    }

    func testNonStakingQueryResultsIgnored() {
        let dAppList = makeDAppList(
            dApps: [makeDApp(url: "https://omni.ls/app", categories: ["staking"])]
        )

        // free text falls back to a web search page, not a staking site
        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(
                result: .query(string: "staking"),
                dAppList: dAppList
            ),
            DAppStakingSiteKind.none
        )

        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(
                result: .query(string: "hydration.net"),
                dAppList: dAppList
            ),
            DAppStakingSiteKind.none
        )

        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(
                result: .query(string: "https://app.hydration.net/trade"),
                dAppList: dAppList
            ),
            DAppStakingSiteKind.none
        )
    }

    func testBittensorHostsDetected() {
        let hosts = [
            "taostats.io", "dash.taostats.io", "tao.app", "www.tao.app", "tensorwallet.ca",
            "mentatminds.com", "mentatlend.com", "taoswap.org", "taomarketcap.com", "backprop.finance",
            "tao.com", "tao.bot", "potatao.io", "taoyield.com", "bittensor.com", "bridge.bittensor.com",
            "delegate.tensorplex.ai", "TAOSTATS.IO"
        ]

        for host in hosts {
            XCTAssertTrue(DAppStakingDetection.isBittensorHost(host), host)
        }
    }

    func testNonBittensorHostsIgnored() {
        let hosts = [
            "taobao.com", "tensor.trade", "tensorflow.org", "web.subwallet.app",
            "staking.polkadot.cloud", "app.hydration.net", ""
        ]

        for host in hosts {
            XCTAssertFalse(DAppStakingDetection.isBittensorHost(host), host)
        }

        XCTAssertFalse(DAppStakingDetection.isBittensorHost(nil))
    }

    func testBittensorQueriesDetected() {
        let queries = ["tao", "TAO staking", "bittensor", "taostats", "dtao", "taostats.io"]

        for query in queries {
            XCTAssertTrue(DAppStakingDetection.isBittensorQuery(query), query)
        }
    }

    func testNonBittensorQueriesIgnored() {
        let queries = ["taobao", "tensor", "polkadot staking", "mistake", ""]

        for query in queries {
            XCTAssertFalse(DAppStakingDetection.isBittensorQuery(query), query)
        }

        XCTAssertFalse(DAppStakingDetection.isBittensorQuery(nil))
    }

    func testQueryKindPrefersBittensorOverStaking() {
        XCTAssertEqual(DAppStakingDetection.queryKind("TAO staking"), .bittensor)
        XCTAssertEqual(DAppStakingDetection.queryKind("tao"), .bittensor)
        XCTAssertEqual(DAppStakingDetection.queryKind("polkadot staking"), .staking)
        XCTAssertEqual(DAppStakingDetection.queryKind("hydration"), DAppStakingQueryKind.none)
        XCTAssertEqual(DAppStakingDetection.queryKind(""), DAppStakingQueryKind.none)
        XCTAssertEqual(DAppStakingDetection.queryKind(nil), DAppStakingQueryKind.none)
    }

    func testBittensorSiteKindDetected() {
        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(result: .query(string: "taostats.io"), dAppList: nil),
            .bittensor
        )

        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(
                result: .query(string: "https://dash.taostats.io/validators"),
                dAppList: nil
            ),
            .bittensor
        )

        let taoDApp = makeDApp(url: "https://www.tao.app", categories: ["defi"])

        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(result: .dApp(model: taoDApp), dAppList: nil),
            .bittensor
        )

        XCTAssertTrue(DAppStakingDetection.isBittensorSite(result: .query(string: "taoyield.com")))
        XCTAssertTrue(DAppStakingDetection.isBittensorSite(result: .dApp(model: taoDApp)))
    }

    func testBittensorSiteKindWinsOverThirdPartyStaking() {
        // the host label starts with "stak", so the staking rule would match too
        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(result: .query(string: "staking.taostats.io"), dAppList: nil),
            .bittensor
        )

        let stakingTaoDApp = makeDApp(url: "https://tao.app", categories: ["staking"])

        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(result: .dApp(model: stakingTaoDApp), dAppList: nil),
            .bittensor
        )

        // a typed address of a curated staking dApp on a TAO host
        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(
                result: .query(string: "tao.app"),
                dAppList: makeDAppList(dApps: [stakingTaoDApp])
            ),
            .bittensor
        )
    }

    func testFreeTextBittensorQueryIsNotSite() {
        // free text falls back to a web search page, so neither notice is shown
        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(result: .query(string: "tao"), dAppList: nil),
            DAppStakingSiteKind.none
        )

        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(result: .query(string: "TAO staking"), dAppList: nil),
            DAppStakingSiteKind.none
        )

        XCTAssertFalse(DAppStakingDetection.isBittensorSite(result: .query(string: "tao")))
    }

    func testNonBittensorSitesKeepExistingKind() {
        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(result: .query(string: "staking.polkadot.cloud"), dAppList: nil),
            .thirdPartyStaking
        )

        XCTAssertEqual(
            DAppStakingDetection.stakingSiteKind(result: .query(string: "taobao.com"), dAppList: nil),
            DAppStakingSiteKind.none
        )

        XCTAssertFalse(DAppStakingDetection.isBittensorSite(result: .query(string: "staking.polkadot.cloud")))

        let dexDApp = makeDApp(url: "https://app.hydration.net", categories: ["dex"])

        XCTAssertFalse(DAppStakingDetection.isBittensorSite(result: .dApp(model: dexDApp)))
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
