@testable import novawallet
import XCTest

final class SubtensorSubnetNamingTests: XCTestCase {
    private let locale = Locale(identifier: "en")

    func testCatalogueNameAndSymbolAreTrimmed() {
        let apex = makeCatalogueSubnet(name: "  Apex\n", symbol: " α ")

        XCTAssertEqual(SubtensorSubnetNaming.titleWithSymbol(for: apex, locale: locale), "Apex α")
    }

    func testBlankCatalogueNameReadsSubnetNumber() {
        let unnamed = makeCatalogueSubnet(name: "   ", symbol: "ش")

        XCTAssertEqual(SubtensorSubnetNaming.title(for: unnamed, locale: locale), "Subnet 64")
    }

    func testSubnetMissingFromTheCatalogueReadsSubnetNumberWithoutChip() {
        let catalogue = SubtensorSubnetCatalogue(subnets: [makeCatalogueSubnet(name: "Chutes", symbol: "ش")])

        XCTAssertEqual(SubtensorSubnetNaming.titleWithSymbol(for: 5, in: catalogue, locale: locale), "Subnet 5")
        XCTAssertEqual(SubtensorSubnetNaming.titleWithSymbol(for: 5, in: nil, locale: locale), "Subnet 5")
    }

    private func makeCatalogueSubnet(name: String, symbol: String) -> SubtensorCatalogueSubnet {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        return SubtensorCatalogueSubnet(
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
    }
}
