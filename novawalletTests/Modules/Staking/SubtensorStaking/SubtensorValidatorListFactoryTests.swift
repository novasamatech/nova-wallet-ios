@testable import novawallet
import BigInt
import XCTest

final class SubtensorValidatorListFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private let asOf = Date(timeIntervalSince1970: 1_790_000_000)
    private let alphaPrice: Balance = 500_000_000
    private let defaultTake: UInt16 = 11796

    private let miner = Data(repeating: 1, count: 32)
    private let inactive = Data(repeating: 2, count: 32)
    private let topRated = Data(repeating: 4, count: 32)
    private let lowRated = Data(repeating: 5, count: 32)
    private let unrated = Data(repeating: 6, count: 32)

    private let taoDisplayInfo = AssetBalanceDisplayInfo(
        displayPrecision: 5,
        assetPrecision: 9,
        symbol: "TAO",
        symbolValueSeparator: " ",
        symbolPosition: .suffix,
        icon: nil
    )

    func testSubnetListShowsOnlyActivePermittedValidatorsWithApyOrderedByApy() throws {
        let viewModel = makeFactory().createListViewModel(
            for: makeInput(yields: makeYields(freshness: .fresh), sort: .apy, selectedHotkey: nil),
            locale: locale
        )

        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        XCTAssertEqual(viewModel.rows.map(\.hotkey), [topRated, lowRated])
        XCTAssertEqual(viewModel.rows.map(\.trailing), [.rate("49.40%"), .rate("14.88%")])
        XCTAssertEqual(viewModel.countTitle, strings.stakingSubtensorUiValidatorCountFormat(2))
        XCTAssertEqual(
            viewModel.rows.first?.subtitle,
            strings.stakingSubtensorUiValidatorRowSubtitleFormat("285.6K TAO", "18%")
        )
    }

    func testStaleYieldsHideRatesAndOrderByStake() {
        let yields = makeYields(freshness: .stale)

        let viewModel = makeFactory().createListViewModel(
            for: makeInput(yields: yields, sort: .apy, selectedHotkey: nil),
            locale: locale
        )

        XCTAssertEqual(SubtensorValidatorListFactory.sortOptions(isRoot: false, yields: yields), [.totalStaked, .name])
        XCTAssertEqual(viewModel.rows.map(\.hotkey), [unrated, lowRated, topRated])
        XCTAssertEqual(viewModel.rows.map(\.trailing), [.none, .none, .none])
    }

    func testEmptyFreshYieldPageKeepsActiveValidatorsOrderedByStake() {
        let emptyYields = SubtensorAlphaYields(
            netuid: 64,
            yields: [:],
            stamp: SubtensorBackendStamp(asOf: asOf, freshness: .fresh),
            isTruncated: false
        )

        let viewModel = makeFactory().createListViewModel(
            for: makeInput(yields: emptyYields, sort: .apy, selectedHotkey: nil),
            locale: locale
        )

        XCTAssertEqual(viewModel.rows.map(\.hotkey), [unrated, lowRated, topRated])
    }

    func testPreselectedValidatorWithoutApyStaysListedAfterAnotherPick() {
        let viewModel = makeFactory().createListViewModel(
            for: makeInput(
                yields: makeYields(freshness: .fresh),
                sort: .apy,
                selectedHotkey: topRated,
                preselectedHotkey: unrated
            ),
            locale: locale
        )

        XCTAssertEqual(viewModel.rows.map(\.hotkey), [topRated, lowRated, unrated])
        XCTAssertEqual(viewModel.rows.map(\.isSelected), [true, false, false])
    }

    func testSelectableCurrentChoiceIsPreselected() {
        let preselected = SubtensorValidatorListFactory.preselectedHotkey(
            lowRated,
            in: makeDirectory(),
            isRoot: false,
            maxTake: SubtensorClientGates.backendDefault.maxTake
        )

        XCTAssertEqual(preselected, lowRated)
    }

    func testDeviceBoundFailureHasNoRetry() {
        let viewModel = makeFactory().createErrorViewModel(for: BittensorApiError.unsupportedDevice, locale: locale)

        XCTAssertNil(viewModel.retryTitle)
        XCTAssertEqual(
            viewModel.details,
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValidatorFetchDeviceDetail()
        )
    }

    private func makeFactory() -> SubtensorValidatorListFactory {
        SubtensorValidatorListFactory(
            chainFormat: .substrate(SubstrateConstants.genericAddressPrefix),
            assetDisplayInfo: taoDisplayInfo
        )
    }

    private func makeInput(
        yields: SubtensorAlphaYields,
        sort: SubtensorValidatorSort,
        selectedHotkey: AccountId?,
        preselectedHotkey: AccountId? = nil
    ) -> SubtensorValidatorListInput {
        SubtensorValidatorListInput(
            directory: makeDirectory(),
            yields: yields,
            alphaPrice: alphaPrice,
            isRoot: false,
            maxTake: SubtensorClientGates.backendDefault.maxTake,
            sort: sort,
            query: "",
            selectedHotkey: selectedHotkey,
            preselectedHotkey: preselectedHotkey
        )
    }

    private func makeDirectory() -> SubtensorValidatorDirectory {
        SubtensorValidatorDirectory(
            subnet: SubtensorSubnetRef(netuid: 64, registeredAt: 1000),
            items: [
                makeItem(miner, name: "Miner", stake: 5000, hasPermit: false, isActive: true),
                makeItem(inactive, name: "Idle", stake: 900_000, hasPermit: true, isActive: false),
                makeItem(topRated, name: "tao.bot", stake: 571_200, hasPermit: true, isActive: true),
                makeItem(lowRated, name: "Arbos", stake: 700_000, hasPermit: true, isActive: true),
                makeItem(unrated, name: "Rizzo", stake: 800_000, hasPermit: true, isActive: true)
            ],
            listStamp: SubtensorBackendStamp(asOf: asOf, freshness: .fresh),
            isPartial: false,
            isEnrichmentTruncated: false,
            chainBlock: 100
        )
    }

    private func makeItem(
        _ hotkey: AccountId,
        name: String,
        stake: BigUInt,
        hasPermit: Bool,
        isActive: Bool
    ) -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: hotkey,
            netuid: 64,
            name: name,
            take: Decimal(defaultTake) / Decimal(SubtensorStakingPallet.perU16Denominator),
            reportedStake: BigRational(numerator: stake, denominator: 1),
            status: SubtensorValidatorChainStatus(
                uid: UInt16(hotkey[0]),
                hasPermit: hasPermit,
                blocksSinceUpdate: isActive ? 10 : 9000,
                isActive: isActive
            )
        )
    }

    private func makeYields(freshness: SubtensorBackendStamp.Freshness) -> SubtensorAlphaYields {
        let stamp = SubtensorBackendStamp(asOf: asOf, freshness: freshness)

        return SubtensorAlphaYields(
            netuid: 64,
            yields: [
                topRated: SubtensorReportedYield(reportedRate: "49.4", stamp: stamp),
                lowRated: SubtensorReportedYield(reportedRate: "14.8812", stamp: stamp),
                inactive: SubtensorReportedYield(reportedRate: "60", stamp: stamp),
                miner: SubtensorReportedYield(reportedRate: "70", stamp: stamp)
            ],
            stamp: stamp,
            isTruncated: false
        )
    }
}
