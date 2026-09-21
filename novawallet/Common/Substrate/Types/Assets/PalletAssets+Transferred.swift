import Foundation
import SubstrateSdk

extension PalletAssets {
    static func transferredPath(for moduleName: String?) -> EventCodingPath {
        EventCodingPath(moduleName: moduleName ?? PalletAssets.name, eventName: "Transferred")
    }

    struct TransferredEvent: Decodable {
        let assetId: JSON
        let sender: AccountId
        let receiver: AccountId
        let amount: Balance

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            assetId = try unkeyedContainer.decode(JSON.self)
            sender = try unkeyedContainer.decode(AccountIdCodingWrapper.self).wrappedValue
            receiver = try unkeyedContainer.decode(AccountIdCodingWrapper.self).wrappedValue
            amount = try unkeyedContainer.decode(StringScaleMapper<Balance>.self).value
        }
    }
}
