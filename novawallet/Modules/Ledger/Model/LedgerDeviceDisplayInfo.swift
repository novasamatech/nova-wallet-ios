import Foundation

struct LedgerDeviceDisplayInfo {
    let deviceName: String
    let deviceModel: LedgerDeviceModel
}

extension LedgerDeviceProtocol {
    var deviceInfo: LedgerDeviceDisplayInfo {
        LedgerDeviceDisplayInfo(deviceName: name, deviceModel: model)
    }
}
