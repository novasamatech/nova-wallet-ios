import BigInt
@testable import novawallet
import XCTest

final class SubtensorSubnetViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")

    private func makeChainAsset() -> ChainAsset {
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

        return ChainAsset(chain: chain, asset: asset)
    }

    private func makeFactory() -> SubtensorSubnetViewModelFactory {
        SubtensorSubnetViewModelFactory(chainAsset: makeChainAsset())
    }

    private func makeDynamicInfo(
        netuid: UInt16,
        name: String,
        symbol: String = "α",
        alphaOutEmission: Balance = 1_000_000_000,
        alphaOut: Balance = 2_534_184_037_427_779
    ) -> SubtensorStakingPallet.DynamicInfo {
        SubtensorStakingPallet.DynamicInfo(
            netuid: netuid,
            ownerHotkey: Data(repeating: UInt8(netuid % 255), count: 32),
            ownerColdkey: Data(repeating: 0, count: 32),
            subnetName: Data(name.utf8),
            tokenSymbol: Data(symbol.utf8),
            tempo: 99,
            lastStep: 0,
            blocksSinceLastStep: 0,
            emission: 0,
            alphaIn: 0,
            alphaOut: alphaOut,
            taoIn: 0,
            alphaOutEmission: alphaOutEmission,
            alphaInEmission: 0,
            taoInEmission: 0,
            pendingAlphaEmission: 0,
            pendingRootEmission: 0,
            subnetVolume: 0,
            networkRegisteredAt: 0,
            subnetIdentity: nil,
            movingPrice: .null
        )
    }

    private func makeInfo(
        subnets: [SubtensorStakingPallet.DynamicInfo],
        prices: [UInt16: Balance]? = nil,
        subtokenEnabled: Set<UInt16>? = nil,
        ownerCut: UInt16 = SubtensorStakingPallet.defaultSubnetOwnerCut
    ) -> SubtensorSubnetsInfo {
        let netuids = subnets.map(\.netuid)

        return SubtensorSubnetsInfo(
            subnets: subnets,
            prices: prices ?? Dictionary(uniqueKeysWithValues: netuids.map { ($0, 7_683_255) }),
            subtokenEnabled: subtokenEnabled ?? Set(netuids),
            ownerCut: ownerCut
        )
    }

    private func createViewModels(
        info: SubtensorSubnetsInfo,
        query: String = ""
    ) -> [SubtensorSubnetSelectViewModel] {
        makeFactory().createViewModels(
            from: info,
            defaultTake: 11796,
            query: query,
            locale: locale
        )
    }

    func testRootRowIsPinnedFirst() {
        let info = makeInfo(subnets: [makeDynamicInfo(netuid: 1, name: "Apex")])

        let viewModels = createViewModels(info: info)

        XCTAssertEqual(viewModels.count, 2)
        XCTAssertEqual(viewModels.first?.target, .root)
        XCTAssertNil(viewModels.first?.apr)
    }

    func testSubtokenDisabledSubnetsAreExcluded() {
        let info = makeInfo(
            subnets: [
                makeDynamicInfo(netuid: 1, name: "Apex"),
                makeDynamicInfo(netuid: 2, name: "omron")
            ],
            subtokenEnabled: [1]
        )

        let viewModels = createViewModels(info: info)

        XCTAssertEqual(viewModels.map(\.target.netuid), [0, 1])
    }

    func testRootListedInSubnetsInfoIsNotDuplicated() {
        let info = makeInfo(
            subnets: [
                makeDynamicInfo(netuid: 0, name: "root", symbol: "Τ"),
                makeDynamicInfo(netuid: 1, name: "Apex")
            ]
        )

        let viewModels = createViewModels(info: info)

        XCTAssertEqual(viewModels.map(\.target.netuid), [0, 1])
        XCTAssertEqual(viewModels.first?.target, .root)
    }

    func testSearchByNameFiltersRows() {
        let info = makeInfo(
            subnets: [
                makeDynamicInfo(netuid: 1, name: "Apex"),
                makeDynamicInfo(netuid: 64, name: "Chutes")
            ]
        )

        let viewModels = createViewModels(info: info, query: "apex")

        XCTAssertEqual(viewModels.map(\.target.netuid), [1])
    }

    func testSearchByNetuidMatchesExactly() {
        let info = makeInfo(
            subnets: [
                makeDynamicInfo(netuid: 6, name: "Alpha"),
                makeDynamicInfo(netuid: 64, name: "Chutes")
            ]
        )

        let viewModels = createViewModels(info: info, query: "64")

        XCTAssertEqual(viewModels.map(\.target.netuid), [64])
    }

    func testRootRowMatchesRootQuery() {
        let info = makeInfo(subnets: [makeDynamicInfo(netuid: 1, name: "Apex")])

        let viewModels = createViewModels(info: info, query: "Root")

        XCTAssertEqual(viewModels.map(\.target.netuid), [0])
    }

    func testAprLabelComposesEstimatePrefixAndSymbolDetail() throws {
        let info = makeInfo(subnets: [makeDynamicInfo(netuid: 1, name: "Apex")])

        let viewModel = try XCTUnwrap(createViewModels(info: info).last)

        XCTAssertEqual(viewModel.apr, "~34.86%")
        XCTAssertEqual(viewModel.aprDetail, "estimated, in α")
    }

    func testAprUsesLiveOwnerCutInsteadOfRuntimeDefault() throws {
        let info = makeInfo(subnets: [makeDynamicInfo(netuid: 1, name: "Apex")], ownerCut: 0)

        let viewModel = try XCTUnwrap(createViewModels(info: info).last)

        XCTAssertEqual(viewModel.apr, "~42.51%")
    }

    func testZeroAlphaOutProducesNoApr() throws {
        let info = makeInfo(
            subnets: [makeDynamicInfo(netuid: 36, name: "Score", alphaOutEmission: 0, alphaOut: 0)]
        )

        let viewModel = try XCTUnwrap(createViewModels(info: info).last)

        XCTAssertNil(viewModel.apr)
        XCTAssertNil(viewModel.aprDetail)
    }

    func testMissingPriceDropsSubnetRow() {
        let info = makeInfo(
            subnets: [
                makeDynamicInfo(netuid: 1, name: "Apex"),
                makeDynamicInfo(netuid: 2, name: "omron")
            ],
            prices: [1: 7_683_255]
        )

        let viewModels = createViewModels(info: info)

        XCTAssertEqual(viewModels.map(\.target.netuid), [0, 1])
    }

    func testSubtitleJoinsSymbolAndNetuidTag() throws {
        let info = makeInfo(subnets: [makeDynamicInfo(netuid: 1, name: "Apex")])

        let viewModel = try XCTUnwrap(createViewModels(info: info).last)

        XCTAssertEqual(viewModel.subtitle, "α · SN1")
    }
}
