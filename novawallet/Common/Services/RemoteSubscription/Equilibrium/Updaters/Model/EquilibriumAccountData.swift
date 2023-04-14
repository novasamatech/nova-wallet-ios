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
        let lock: BigUInt?
        let balance: [EquilibriumRemoteBalance]

        enum CodingKeys: CodingKey {
            case lock
            case balance
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            lock = try container.decodeIfPresent(StringScaleMapper<BigUInt>.self, forKey: .lock)?.value
            balance = try container.decode([EquilibriumRemoteBalance].self, forKey: .balance)
        }
    }
}
