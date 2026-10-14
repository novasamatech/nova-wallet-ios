import BigInt
@testable import novawallet
import XCTest

final class SubtensorSubnetViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")

    func testRowShowsTheCatalogueNameWithSymbolAndASingleTaoPrice() {
        let viewModel = makeFactory().createRowViewModel(
            for: makeItem(name: "Apex", symbol: "α", weekly: .notListed),
            isFavorite: false,
            subnetLogos: nil,
            locale: locale
        )

        XCTAssertEqual(viewModel.title, "Apex α")
        XCTAssertEqual(viewModel.price, "0.0738 TAO")
    }

    func testUnnamedSubnetReadsSubnetNumberWithItsSymbol() {
        let viewModel = makeFactory().createRowViewModel(
            for: makeItem(name: "  ", symbol: "α", weekly: .notListed),
            isFavorite: false,
            subnetLogos: nil,
            locale: locale
        )

        XCTAssertEqual(viewModel.title, "Subnet 64 α")
    }

    func testWeeklyChangeReadsTheSignedPercentWithThePeriodAndKeepsTheSparkline() throws {
        let summary = SubtensorWeeklyPriceSummary(
            change: try XCTUnwrap(Decimal(string: "0.164")),
            sparkline: [try XCTUnwrap(Decimal(string: "0.063")), try XCTUnwrap(Decimal(string: "0.0738"))]
        )

        let viewModel = makeFactory().createRowViewModel(
            for: makeItem(weekly: .available(summary)),
            isFavorite: false,
            subnetLogos: nil,
            locale: locale
        )

        guard case let .value(text, isRising, sparkline) = viewModel.change else {
            return XCTFail("Expected a weekly change")
        }

        XCTAssertEqual(text, "+16.4% 7d")
        XCTAssertTrue(isRising)
        XCTAssertEqual(sparkline, [0.063, 0.0738])
        XCTAssertNil(viewModel.subtitle)
    }

    func testSubnetWithoutPriceHistoryShowsTheNoHistoryCaptions() {
        let viewModel = makeFactory().createRowViewModel(
            for: makeItem(weekly: .notListed),
            isFavorite: false,
            subnetLogos: nil,
            locale: locale
        )

        guard case let .notListed(text) = viewModel.change else {
            return XCTFail("Expected the no history state")
        }

        XCTAssertEqual(text, "no price history yet")
        XCTAssertEqual(viewModel.subtitle, "on-chain ratio")
    }

    func testFailedWeeklyFetchShowsADashWithoutTheNoHistoryCaption() {
        let viewModel = makeFactory().createRowViewModel(
            for: makeItem(weekly: .unavailable),
            isFavorite: false,
            subnetLogos: nil,
            locale: locale
        )

        guard case let .unavailable(text) = viewModel.change else {
            return XCTFail("Expected the failed fetch state")
        }

        XCTAssertEqual(text, "—")
        XCTAssertNil(viewModel.subtitle)
    }

    func testFiltersSheetShowsTheCountWithTheCompactThinThresholdAndWaitsWhilePending() {
        let factory = makeFactory()
        let filters = SubtensorSubnetFilters(hideThinPools: true)

        let counted = factory.createFiltersViewModel(
            filters: filters,
            count: 10,
            locale: locale
        )

        let pending = factory.createFiltersViewModel(
            filters: filters,
            count: nil,
            locale: locale
        )

        XCTAssertEqual(counted.thinPoolsDetails, "below 2K TAO · price moves more")
        XCTAssertEqual(counted.actionTitle, "Show 10 subnets")
        XCTAssertFalse(counted.isLoading)
        XCTAssertEqual(pending.actionTitle, "Show subnets")
        XCTAssertTrue(pending.isLoading)
    }

    func testSortOptionsShowApyAsUnavailableAndCountExcludesLikes() {
        let factory = makeFactory()
        let sheet = factory.createSortSheetViewModel(selected: .poolDepth, locale: locale)
        XCTAssertEqual(sheet.options.map(\.title), ["Pool size", "Age", "APY", "7-day change", "Name"])
        XCTAssertEqual(sheet.options.map(\.isEnabled), [true, true, false, true, true])
        XCTAssertEqual(sheet.options[2].subtitle, "APY ordering is unavailable")
        let item = makeItem(weekly: nil)
        let model = factory.createListViewModel(for: .init(
            list: .init(picks: [item], others: [], emptyKind: nil), sort: .name, filters: .init(),
            subnetLogos: nil, stamp: nil, entriesError: nil
        ), locale: locale)
        XCTAssertEqual(model.caption, "0 of 128")
    }

    private func makeFactory() -> SubtensorSubnetViewModelFactory {
        let asset = AssetModel(
            assetId: AssetModel.utilityAssetId,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: nil,
            stakings: [.subtensor],
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return SubtensorSubnetViewModelFactory(chainAsset: ChainAsset(chain: chain, asset: asset))
    }

    private func makeItem(
        name: String = "Apex",
        symbol: String = "α",
        weekly: SubtensorPriceData<SubtensorWeeklyPriceSummary>?
    ) -> SubtensorSubnetListItem {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        let subnet = SubtensorCatalogueSubnet(
            netuid: 64,
            name: name,
            symbol: symbol,
            networkRegisteredAt: 4_531_295,
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
            taoReserve: 210_000_000_000_000,
            alphaReserve: 2_845_000_000_000_000,
            alphaOutstanding: 3_100_000_000_000_000,
            taoPerAlpha: 73_800_000,
            metadataStamp: stamp,
            pricesStamp: stamp
        )

        return SubtensorSubnetListItem(
            subnet: subnet,
            target: .root,
            weekly: weekly,
            ageBlocks: nil
        )
    }
}
