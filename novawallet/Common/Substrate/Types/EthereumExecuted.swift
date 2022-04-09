import Foundation
import SubstrateSdk

struct EthereumExecuted {
    static let succeedField = "Succeed"

    let from: AccountId

    // swiftlint:disable:next identifier_name
    let to: AccountId

    let transactionHash: Data
    let isSuccess: Bool
}

extension EthereumExecuted: Decodable {
    init(from decoder: Decoder) throws {
        var arrayContainer = try decoder.unkeyedContainer()

        from = try arrayContainer.decode(BytesCodable.self).wrappedValue
        to = try arrayContainer.decode(BytesCodable.self).wrappedValue
        transactionHash = try arrayContainer.decode(BytesCodable.self).wrappedValue

        var exitReasonContainer = try arrayContainer.nestedUnkeyedContainer()
        let exitReasonValue = try exitReasonContainer.decode(String.self)
        isSuccess = exitReasonValue == Self.succeedField
    }
}
