import XCTest
@testable import novawallet
import SubstrateSdk

final class SubtensorEarnConfigTests: XCTestCase {
    let goldenJson = """
    {
      "version": 1,
      "entry": { "enabled": true, "newBadgeUntil": "2026-12-31" },
      "headlineMaxAnnualRate": "0.40",
      "preferredRootValidator": "141BZJmvZSXy3uiKoHmP1ZvUaq4b3ratkC5DE6GuU4K7je4W",
      "logoBaseUrl": "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/bittensor/",
      "subnets": {
        "64": {
          "registeredAt": 4531295,
          "preferredValidator": "5F4tQyWrhfGVcNhoqeiNsR6KjD4wMZ2kfhLj4oHYuyHbZAc3",
          "coingeckoId": "chutes",
          "logo": "sn64-4531295.png"
        }
      }
    }
    """

    let validatorAccountIdHex = "0x84d83d08ca89f8e60424ffa286f165c16dd8752e4faa4d8977221e6720678d28"
    let logoBaseUrl = "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/bittensor/"

    func testGoldenDecodesAndDropsOnlyTheRootValidatorWithForeignAddressPrefix() throws {
        let config = try decodeGolden()
        let validatorAccountId = try Data(hexString: validatorAccountIdHex)

        let expected = SubtensorEarnConfig(
            version: 1,
            entry: .init(enabled: true, newBadgeUntil: Date(timeIntervalSince1970: 1_798_675_200)),
            headlineMaxAnnualRate: Decimal(string: "0.4"),
            preferredRootValidator: nil,
            logoBaseUrl: URL(string: logoBaseUrl),
            subnets: [
                64: .init(
                    registeredAt: 4_531_295,
                    preferredValidator: validatorAccountId,
                    coingeckoId: "chutes",
                    logo: "sn64-4531295.png"
                )
            ],
            invalidEntries: ["preferredRootValidator"]
        )

        XCTAssertEqual(config, expected)
    }

    func testSubnetEntryResolvesWhenRegistrationMatchesChain() throws {
        let config = try decodeGolden()

        let entry = config.subnetEntry(for: SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295))

        XCTAssertEqual(entry?.coingeckoId, "chutes")
    }

    func testSubnetEntryIsNilWhenNetuidWasReRegistered() throws {
        let config = try decodeGolden()

        let entry = config.subnetEntry(for: SubtensorSubnetRef(netuid: 64, registeredAt: 9_100_000))

        XCTAssertNil(entry)
    }

    private func decodeGolden() throws -> SubtensorEarnConfig {
        try JSONDecoder().decode(SubtensorEarnConfig.self, from: Data(goldenJson.utf8))
    }
}
