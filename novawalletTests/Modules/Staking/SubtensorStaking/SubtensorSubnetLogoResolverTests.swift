import XCTest
@testable import novawallet

final class SubtensorSubnetLogoResolverTests: XCTestCase {
    let logoBaseUrl = URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/bittensor/")!

    func testLogoResolvesUnderTheBaseUrlForTheRegisteredSubnet() {
        let resolver = SubtensorSubnetLogoResolver(config: makeConfig(logo: "sn64-4531295.png"))

        let url = resolver.url(for: SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295))

        XCTAssertEqual(
            url?.absoluteString,
            "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/bittensor/sn64-4531295.png"
        )
    }

    func testLogoIsNilForAReRegisteredNetuid() {
        let resolver = SubtensorSubnetLogoResolver(config: makeConfig(logo: "sn64-4531295.png"))

        XCTAssertNil(resolver.url(for: SubtensorSubnetRef(netuid: 64, registeredAt: 9_100_000)))
    }

    func testLogoOutsideTheBaseUrlIsNeverResolved() {
        let resolver = SubtensorSubnetLogoResolver(config: makeConfig(logo: "../../branding/logo.png"))

        XCTAssertNil(resolver.url(for: SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)))
    }

    private func makeConfig(logo: String) -> SubtensorEarnConfig {
        SubtensorEarnConfig(
            version: 1,
            entry: nil,
            headlineMaxAnnualRate: nil,
            preferredRootValidator: nil,
            logoBaseUrl: logoBaseUrl,
            subnets: [
                64: .init(registeredAt: 4_531_295, preferredValidator: nil, coingeckoId: nil, logo: logo)
            ],
            invalidEntries: []
        )
    }
}
