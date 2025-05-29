import Foundation

enum HardwareWalletAddressScheme: Equatable {
    case substrate
    case evm

    var order: Int {
        switch self {
        case .substrate:
            0
        case .evm:
            1
        }
    }
}

struct HardwareWalletAddressModel {
    let address: AccountAddress?
    let scheme: HardwareWalletAddressScheme
}

extension Array where Element == HardwareWalletAddressModel {
    func sortedBySchemeOrder() -> [Element] {
        sorted { $0.scheme.order < $1.scheme.order }
    }
}

struct GenericLedgerAccountModel {
    let index: UInt32
    let addresses: [HardwareWalletAddressModel]
}
