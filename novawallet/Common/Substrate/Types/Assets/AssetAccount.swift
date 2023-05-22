import Foundation
import BigInt
import SubstrateSdk

extension PalletAssets {
    enum AccountStatus: String, Decodable {
        case liquid = "Liquid"
        case frozen = "Frozen"
        case blocked = "Blocked"

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            guard let value = AccountStatus(rawValue: type) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unexpected account status"
                )
            }

            self = value
        }
    }

    struct AccountV1: Decodable {
        @StringCodable var balance: BigUInt
        let isFrozen: Bool
    }

    struct AccountV2: Decodable {
        @StringCodable var balance: BigUInt
        let status: AccountStatus
    }

    struct Account: Decodable {
        let balance: BigUInt
        let status: AccountStatus

        var isFrozen: Bool { !canSend }
        var isBlocked: Bool { !canSend && !canReceive }

        var canSend: Bool {
            switch status {
            case .liquid:
                return true
            case .frozen, .blocked:
                return false
            }
        }

        var canReceive: Bool {
            switch status {
            case .liquid, .frozen:
                return true
            case .blocked:
                return false
            }
        }

        init(from decoder: Decoder) throws {
            if let accountV2 = try? AccountV2(from: decoder) {
                balance = accountV2.balance
                status = accountV2.status
            } else {
                let accountV1 = try AccountV1(from: decoder)
                balance = accountV1.balance
                status = accountV1.isFrozen ? .frozen : .liquid
            }
        }
    }
}
