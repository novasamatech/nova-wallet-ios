import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorPortfolioViewModelFactoryTests: XCTestCase {
    func testSubnetRowAndTotalValueTheHeldAlphaAtTheCataloguePriceOverTheChainPrice() {
        var state = SubtensorPortfolioState()
        state.positions = Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: Data(repeating: 7, count: 32),
                    netuid: 64,
                    stakeAlpha: 100_000_000_000,
                    hotkeyEmissionPerTempo: 0,
                    totalHotkeyAlpha: nil,
                    isRegistered: true
                )
            ],
            prices: [64: 75_100_000]
        )
        state.isCatalogueResolved = true
        state.catalogue = makeCatalogue(taoPerAlpha: 73_800_000)

        let viewModel = makeFactory().createViewModel(for: state, locale: Locale(identifier: "en"))

        guard case let .positions(header, rows) = viewModel.content else {
            XCTFail("Expected the positions layout, got \(viewModel.content)")
            return
        }

        XCTAssertEqual(header.total, "7.38 TAO")
        XCTAssertEqual(rows?.map(\.value), ["≈ 7.38 TAO"])
    }

    private func makeFactory() -> SubtensorPortfolioViewModelFactory {
        SubtensorPortfolioViewModelFactory(
            chainAsset: SubtensorFlowChainWorld.chainAsset(),
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )
    }

    private func makeCatalogue(taoPerAlpha: Balance) -> SubtensorSubnetCatalogue {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        return SubtensorSubnetCatalogue(subnets: [
            SubtensorCatalogueSubnet(
                netuid: 64,
                name: "Chutes",
                symbol: "ش",
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
                taoPerAlpha: taoPerAlpha,
                metadataStamp: stamp,
                pricesStamp: stamp
            )
        ])
    }
}
