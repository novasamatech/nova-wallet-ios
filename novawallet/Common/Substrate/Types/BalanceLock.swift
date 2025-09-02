import Foundation
import BigInt
import SubstrateSdk
import Foundation_iOS

struct BalanceLock: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case amount
    }

    @BytesCodable var identifier: Data
    @StringCodable var amount: BigUInt

    var displayId: String? {
        String(
            data: identifier,
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespaces)
    }
}

typealias BalanceLocks = [BalanceLock]
