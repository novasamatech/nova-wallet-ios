@testable import novawallet
import XCTest

final class SubtensorSubnetIconViewModelFactoryTests: XCTestCase {
    private let genericMark = UIImage()
    private let logoBaseUrl = URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/bittensor/")!

    func testConfigLogoOfTheCatalogueRegistrationLoadsOverTheGenericMark() throws {
        let icon = SubtensorSubnetIconViewModelFactory(genericMark: genericMark).icon(
            for: makeCatalogueSubnet(registeredAt: 4_531_295),
            config: makeConfig()
        )

        let remoteIcon = try XCTUnwrap(icon as? RemoteImageViewModel)

        XCTAssertEqual(remoteIcon.url, logoBaseUrl.appendingPathComponent("sn64-4531295.png"))
        XCTAssertTrue(remoteIcon.fallbackImage === genericMark)
    }

    func testReRegisteredSubnetShowsTheGenericMark() throws {
        let icon = SubtensorSubnetIconViewModelFactory(genericMark: genericMark).icon(
            for: makeCatalogueSubnet(registeredAt: 9_100_000),
            config: makeConfig()
        )

        let staticIcon = try XCTUnwrap(icon as? StaticImageViewModel)

        XCTAssertTrue(staticIcon.image === genericMark)
    }

    private func makeConfig() -> SubtensorEarnConfig {
        SubtensorEarnConfig(
            version: 1,
            entry: nil,
            headlineMaxAnnualRate: nil,
            preferredRootValidator: nil,
            logoBaseUrl: logoBaseUrl,
            subnets: [
                64: .init(registeredAt: 4_531_295, preferredValidator: nil, coingeckoId: nil, logo: "sn64-4531295.png")
            ],
            invalidEntries: []
        )
    }

    private func makeCatalogueSubnet(registeredAt: UInt64) -> SubtensorCatalogueSubnet {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        return SubtensorCatalogueSubnet(
            netuid: 64,
            name: "Chutes",
            symbol: "ش",
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
            taoReserve: 210_000_000_000_000,
            alphaReserve: 2_845_000_000_000_000,
            alphaOutstanding: 3_100_000_000_000_000,
            taoPerAlpha: 73_800_000,
            metadataStamp: stamp,
            pricesStamp: stamp
        )
    }
}
