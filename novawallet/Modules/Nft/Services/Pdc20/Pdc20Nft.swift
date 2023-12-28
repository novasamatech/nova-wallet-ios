import Foundation
import BigInt
import SubstrateSdk

struct Pdc20NftResponse: Codable {
    let userTokenBalances: [Pdc20NftRemoteModel]
    let listings: [Pdc20NftRemoteListing]
}

struct Pdc20NftRemoteAddress: Codable {
    let address: String
}

struct Pdc20NftRemoteModel: Codable {
    struct Token: Codable {
        enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case logo
            case ticker
            case totalSupply
            case network
        }

        let identifier: String
        let logo: String?
        let ticker: String?
        @OptionStringCodable var totalSupply: BigUInt?
        let network: String
    }

    @StringCodable var balance: BigUInt
    let address: Pdc20NftRemoteAddress
    let token: Token
}

struct Pdc20NftRemoteListing: Codable {
    struct Token: Codable {
        enum CodingKeys: String, CodingKey {
            case identifier = "id"
        }

        let identifier: String
    }

    let from: Pdc20NftRemoteAddress
    let token: Token
    @StringCodable var amount: BigUInt
    let value: String
}
