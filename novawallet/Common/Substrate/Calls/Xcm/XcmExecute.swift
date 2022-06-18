import Foundation

extension Xcm {
    struct ExecuteCall: Encodable {
        let message: Xcm.Message
        let maxWeight: UInt64
    }
}
