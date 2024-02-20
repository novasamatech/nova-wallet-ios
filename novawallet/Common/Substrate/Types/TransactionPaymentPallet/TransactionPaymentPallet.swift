import Foundation
import SubstrateSdk
import BigInt

enum TransactionPaymentPallet {
    static let moduleName = "TransactionPayment"

    static var feePaidPath: EventCodingPath {
        .init(moduleName: Self.moduleName, eventName: "TransactionFeePaid")
    }

    struct TransactionFeePaid: Decodable {
        let payee: AccountId
        let amount: BigUInt

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            payee = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
        }
    }
}
