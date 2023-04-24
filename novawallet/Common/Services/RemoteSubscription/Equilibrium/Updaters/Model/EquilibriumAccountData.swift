import BigInt
import SubstrateSdk

enum EquilibriumAccountData: Decodable {
    case v0(lock: BigUInt?, balance: [EquilibriumRemoteBalance])

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type.lowercased() {
        case "v0":
            let version = try container.decode(V0.self)
            self = .v0(lock: version.lock, balance: version.balance)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected asset status"
            )
        }
    }
}

extension EquilibriumAccountData {
    struct V0: Decodable {
        @OptionStringCodable var lock: BigUInt?
        let balance: [EquilibriumRemoteBalance]
    }
}
