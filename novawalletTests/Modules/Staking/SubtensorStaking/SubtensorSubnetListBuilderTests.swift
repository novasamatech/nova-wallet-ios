import BigInt
@testable import novawallet
import XCTest

final class SubtensorSubnetListBuilderTests: XCTestCase {
    private let locale = Locale(identifier: "en")

    func testFavouritesStayInPicksUnderEverySort() throws {
        let apex = makeEntry(netuid: 1, name: "Apex", taoReserve: 50_000_000_000_000)
        let chutes = makeEntry(netuid: 64, name: "Chutes", taoReserve: 210_000_000_000_000)
        let score = makeEntry(netuid: 36, name: "Score", taoReserve: 90_000_000_000_000)

        let builder = makeBuilder(
            entries: [apex, chutes, score],
            weekly: [
                apex.subnet.ref: try weeklyChange("0.05"),
                chutes.subnet.ref: try weeklyChange("0.2"),
                score.subnet.ref: .notListed
            ],
            favourites: [score.subnet.ref]
        )

        for sort in SubtensorSubnetSort.allCases {
            let list = builder.build(query: "", sort: sort, filters: SubtensorSubnetFilters())

            XCTAssertEqual(list.picks.map(\.subnet.netuid), [36], "\(sort)")
            XCTAssertEqual(Set(list.others.map(\.subnet.netuid)), [1, 64], "\(sort)")
        }
    }

    func testSevenDaySortPutsRowsWithDataFirstThenFailedFetchesThenNotListedRows() throws {
        let apex = makeEntry(netuid: 1, name: "Apex")
        let chutes = makeEntry(netuid: 64, name: "Chutes")
        let taoshi = makeEntry(netuid: 8, name: "Taoshi")
        let hone = makeEntry(netuid: 5, name: "Hone")

        let builder = makeBuilder(
            entries: [apex, chutes, taoshi, hone],
            weekly: [
                apex.subnet.ref: try weeklyChange("-0.032"),
                chutes.subnet.ref: try weeklyChange("0.164"),
                taoshi.subnet.ref: .unavailable,
                hone.subnet.ref: .notListed
            ]
        )

        let list = builder.build(query: "", sort: .sevenDayChange, filters: SubtensorSubnetFilters())

        XCTAssertEqual(list.others.map(\.subnet.netuid), [64, 1, 8, 5])
    }

    func testThinPoolFilterKeepsExactlyTwoThousandTaoAndHidesJustBelow() {
        let atThreshold = makeEntry(netuid: 1, name: "Apex", taoReserve: 2_000_000_000_000)
        let belowThreshold = makeEntry(netuid: 2, name: "Omron", taoReserve: 1_999_999_999_999)

        let list = makeBuilder(entries: [atThreshold, belowThreshold]).build(
            query: "",
            sort: .name,
            filters: SubtensorSubnetFilters(hideThinPools: true)
        )

        XCTAssertEqual(list.others.map(\.subnet.netuid), [1])
    }

    func testSearchByNumberMatchesOnlyThatNetuid() {
        let entries = [
            makeEntry(netuid: 6, name: "Alpha"),
            makeEntry(netuid: 64, name: "Chutes"),
            makeEntry(netuid: 164, name: "")
        ]

        let list = makeBuilder(entries: entries).build(query: " 64 ", sort: .name, filters: SubtensorSubnetFilters())

        XCTAssertEqual(list.others.map(\.subnet.netuid), [64])
    }

    func testUnmatchedQueryReportsTheTrimmedQueryAsTheEmptyState() {
        let list = makeBuilder(entries: [makeEntry(netuid: 64, name: "Chutes")]).build(
            query: "  xyz ",
            sort: .sevenDayChange,
            filters: SubtensorSubnetFilters()
        )

        XCTAssertEqual(list.count, 0)
        XCTAssertEqual(list.emptyKind, .query("xyz"))
    }

    func testSubnetReRegisteredOnChainSinceTheCatalogueIsNotListed() {
        let current = makeCatalogueSubnet(netuid: 1, name: "Apex", registeredAt: 100)
        let reRegistered = makeCatalogueSubnet(netuid: 2, name: "Omron", registeredAt: 200)

        let subnetsInfo = SubtensorSubnetsInfo(
            subnets: [makeDynamicInfo(netuid: 1, registeredAt: 100), makeDynamicInfo(netuid: 2, registeredAt: 999)],
            prices: [1: 7_683_255, 2: 7_683_255],
            subtokenEnabled: [1, 2],
            ownerCut: SubtensorStakingPallet.defaultSubnetOwnerCut
        )

        let entries = SubtensorSubnetListBuilder.entries(
            from: SubtensorSubnetCatalogue(subnets: [current, reRegistered]),
            subnetsInfo: subnetsInfo
        )

        XCTAssertEqual(entries.map(\.subnet.netuid), [1])
    }

    private func makeBuilder(
        entries: [SubtensorSubnetListEntry],
        weekly: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]? = nil,
        favourites: Set<SubtensorSubnetRef> = []
    ) -> SubtensorSubnetListBuilder {
        SubtensorSubnetListBuilder(
            entries: entries,
            weekly: weekly,
            ageBlocks: [:],
            favourites: favourites,
            locale: locale
        )
    }

    private func weeklyChange(_ change: String) throws -> SubtensorPriceData<SubtensorWeeklyPriceSummary> {
        .available(SubtensorWeeklyPriceSummary(change: try XCTUnwrap(Decimal(string: change)), sparkline: []))
    }

    private func makeEntry(
        netuid: UInt16,
        name: String,
        taoReserve: Balance = 210_000_000_000_000
    ) -> SubtensorSubnetListEntry {
        let subnet = makeCatalogueSubnet(
            netuid: netuid,
            name: name,
            registeredAt: 4_531_295,
            taoReserve: taoReserve
        )

        return SubtensorSubnetListEntry(
            subnet: subnet,
            target: .subnet(info: makeDynamicInfo(netuid: netuid, registeredAt: 4_531_295), price: subnet.taoPerAlpha)
        )
    }

    private func makeCatalogueSubnet(
        netuid: UInt16,
        name: String,
        registeredAt: UInt64,
        taoReserve: Balance = 210_000_000_000_000
    ) -> SubtensorCatalogueSubnet {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        return SubtensorCatalogueSubnet(
            netuid: netuid,
            name: name,
            symbol: "α",
            networkRegisteredAt: registeredAt,
            tempo: 360,
            ownerColdkey: "",
            ownerHotkey: "",
            links: SubtensorSubnetLinks(
                githubRepo: "",
                subnetContact: "",
                subnetUrl: "",
                subnetWebsite: "",
                discord: "",
                additional: ""
            ),
            taoReserve: taoReserve,
            alphaReserve: 2_845_000_000_000_000,
            alphaOutstanding: 3_100_000_000_000_000,
            taoPerAlpha: 73_800_000,
            metadataStamp: stamp,
            pricesStamp: stamp
        )
    }

    private func makeDynamicInfo(netuid: UInt16, registeredAt: UInt64) -> SubtensorStakingPallet.DynamicInfo {
        SubtensorStakingPallet.DynamicInfo(
            netuid: netuid,
            ownerHotkey: Data(repeating: UInt8(netuid % 255), count: 32),
            ownerColdkey: Data(repeating: 0, count: 32),
            subnetName: Data(),
            tokenSymbol: Data(),
            tempo: 360,
            lastStep: 0,
            blocksSinceLastStep: 0,
            emission: 0,
            alphaIn: 0,
            alphaOut: 0,
            taoIn: 0,
            alphaOutEmission: 0,
            alphaInEmission: 0,
            taoInEmission: 0,
            pendingAlphaEmission: 0,
            pendingRootEmission: 0,
            subnetVolume: 0,
            networkRegisteredAt: registeredAt,
            subnetIdentity: nil,
            movingPrice: .null
        )
    }
}
