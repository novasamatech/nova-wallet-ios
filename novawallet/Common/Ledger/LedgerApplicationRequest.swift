import Foundation

struct LedgerApplicationRequest {
    let cla: UInt8
    let instruction: UInt8
    let param1: UInt8
    let param2: UInt8
    let payload: Data

    func toBytes() -> Data {
        var message = Data([cla, instruction, param1, param2])

        if !payload.isEmpty {
            if payload.count < 256 {
                message.append(UInt8(payload.count))
            } else {
                message.append(0)
                message.append(contentsOf: UInt16(payload.count).bigEndianBytes)
            }

            message.append(contentsOf: payload)
        }

        return message
    }
}
