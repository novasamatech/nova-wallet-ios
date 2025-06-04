import Foundation
import SubstrateSdk

extension MoonbeamEvmPallet {
    struct Log: Decodable {
        @BytesCodable var address: AccountId
        let topics: [BytesCodable]
        @BytesCodable var data: Data
    }

    struct LogEvent: Decodable {
        let log: MoonbeamEvmPallet.Log

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            log = try unkeyedContainer.decode(Log.self)
        }
    }
}
