import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorSubnetDetailsViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")

    func testLoadedUnavailableParametersKeepNeutralRowsAndNoCatalogueReserves() {
        let model = makeFactory().createViewModel(for: makeState(), isUseEnabled: true, locale: locale)
        XCTAssertEqual(model.parameters.rows.map(\.title), ["Age", "Validators", "Pool size"])
        XCTAssertEqual(model.parameters.rows.map(\.value), ["—", "—", "—"])
        XCTAssertEqual(model.moreDetails.map(\.title), ["UID", "TAO in pool", "Alpha in pool", "Emission"])
        XCTAssertEqual(model.moreDetails.map(\.value), ["64", "—", "—", "—"])
        XCTAssertEqual(model.validator.rate, .hidden)
    }

    func testLoadingParametersKeepFixedNeutralHierarchy() {
        let model = makeFactory().createViewModel(for: makeState(isLoaded: false), isUseEnabled: true, locale: locale)
        XCTAssertEqual(model.parameters.rows.count, 3)
        XCTAssertTrue(model.parameters.rows.allSatisfy { $0.value == nil })
        XCTAssertEqual(model.moreDetails.count, 4)
    }

    func testReserveFiatUsesMatchingAlphaPriceAndIsolatesRtlSymbol() throws {
        let info = SubtensorSubnetParametersTests.subnet(netuid: 64, registeredAt: 4_531_295, tao: 2_000_000_000, alpha: 8_000_000_000)
        let parameters = SubtensorSubnetParameters(
            ref: makeSubnet().ref,
            blockHash: "hash",
            rows: [info],
            prices: [.init(netuid: 64, price: 500_000_000)],
            blockNumber: 4_532_000,
            permits: [true, false],
            emissionEnabled: true,
            blockTime: 12000
        )
        let state = makeState(parameters: parameters, price: PriceData(identifier: "tao", price: "10", dayChange: nil, currencyId: Currency.usd.id))
        let model = makeFactory().createViewModel(for: state, isUseEnabled: true, locale: locale)
        XCTAssertEqual(model.parameters.split, Decimal(string: "0.2"))
        XCTAssertEqual(model.moreDetails[1].detail, "$20")
        XCTAssertEqual(model.moreDetails[2].detail, "$40")
        XCTAssertTrue(try XCTUnwrap(model.moreDetails[2].value).hasPrefix("\u{2066}"))
        XCTAssertTrue(try XCTUnwrap(model.moreDetails[2].value).hasSuffix("\u{2069}"))
        let rtl = makeFactory().createViewModel(for: state, isUseEnabled: true, locale: Locale(identifier: "ar"))
        XCTAssertTrue(try XCTUnwrap(rtl.moreDetails[2].value).hasPrefix("\u{2066}"))
        XCTAssertEqual(model.parameters.rows[1].value, "1")
    }

    private func makeFactory() -> SubtensorSubnetDetailsViewModelFactory {
        SubtensorSubnetDetailsViewModelFactory(
            subnet: makeSubnet(),
            chainAsset: makeChainAsset(),
            currency: .usd,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )
    }

    private func makeState(isLoaded: Bool = true, parameters: SubtensorSubnetParameters? = nil, price: PriceData? = nil) -> SubtensorSubnetDetailsState {
        SubtensorSubnetDetailsState(
            isFiat: false,
            period: .week,
            history: .loading,
            parameters: parameters,
            isParametersLoaded: isLoaded,
            validator: .unselected,
            yields: nil,
            taoPrice: price,
            isFavorite: false,
            now: Date(timeIntervalSince1970: 1_790_000_000),
            chartEndDate: Date(timeIntervalSince1970: 1_790_000_000),
            chartSelection: nil
        )
    }

    private func makeSubnet() -> SubtensorCatalogueSubnet {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        return SubtensorCatalogueSubnet(
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
            taoPerAlpha: 73_800_000,
            metadataStamp: stamp,
            pricesStamp: stamp
        )
    }

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
}
