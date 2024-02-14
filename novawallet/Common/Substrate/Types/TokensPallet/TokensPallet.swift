import Foundation
import SubstrateSdk
import BigInt

enum TokensPallet {
    static let moduleName = "Tokens"

    static var depositedEventPath: EventCodingPath {
        .init(moduleName: Self.moduleName, eventName: "Deposited")
    }

    struct DepositedEvent<C: Decodable>: Decodable {
        let currencyId: C
        let recepient: AccountId
        let amount: BigUInt

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            currencyId = try unkeyedContainer.decode(C.self)
            recepient = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
        }
    }
}
