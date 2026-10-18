@testable import novawallet
import XCTest

final class SubtensorSubnetIconViewModelFactoryTests: XCTestCase {
    private let genericMark = UIImage()

    func testNovaUtilsLogoOfTheSubnetLoadsOverTheGenericMark() throws {
        let icon = SubtensorSubnetIconViewModelFactory(genericMark: genericMark).icon(
            for: makeCatalogueSubnet(netuid: 64, name: "Chutes", symbol: "ش"),
            logos: try makeLogos()
        )

        let remoteIcon = try XCTUnwrap(icon as? RemoteImageViewModel)

        XCTAssertEqual(remoteIcon.url.absoluteString, SubtensorFlowChainWorld.chutesLogo)
        XCTAssertTrue(remoteIcon.fallbackImage === genericMark)
    }

    func testSubnetWithoutALogoShowsTheGenericMark() throws {
        let icon = SubtensorSubnetIconViewModelFactory(genericMark: genericMark).icon(
            for: makeCatalogueSubnet(netuid: 4, name: "Targon", symbol: "δ"),
            logos: try makeLogos()
        )

        let staticIcon = try XCTUnwrap(icon as? StaticImageViewModel)

        XCTAssertTrue(staticIcon.image === genericMark)
    }

    func testUnavailableLogosShowTheGenericMark() throws {
        let icon = SubtensorSubnetIconViewModelFactory(genericMark: genericMark).icon(
            for: makeCatalogueSubnet(netuid: 64, name: "Chutes", symbol: "ش"),
            logos: nil
        )

        let staticIcon = try XCTUnwrap(icon as? StaticImageViewModel)

        XCTAssertTrue(staticIcon.image === genericMark)
    }

    private func makeLogos() throws -> SubtensorSubnetLogos {
        try JSONDecoder().decode(SubtensorSubnetLogos.self, from: Data(SubtensorFlowChainWorld.subnetLogosJSON.utf8))
    }

    private func makeCatalogueSubnet(netuid: UInt16, name: String, symbol: String) -> SubtensorCatalogueSubnet {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        return SubtensorCatalogueSubnet(
            netuid: netuid,
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
