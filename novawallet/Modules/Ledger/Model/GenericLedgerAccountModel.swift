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
    let accountId: AccountId?
    let scheme: HardwareWalletAddressScheme

    var address: AccountAddress? {
        guard let accountId else {
            return nil
        }

        return try? accountId.toAddressForHWScheme(scheme)
    }
}

extension AccountId {
    func toAddressForHWScheme(_ scheme: HardwareWalletAddressScheme) throws -> AccountAddress {
        switch scheme {
        case .substrate:
            try toAddress(using: .defaultSubstrateFormat)
        case .evm:
            try toAddress(using: .ethereum)
        }
    }
}

extension Array where Element == HardwareWalletAddressModel {
    func sortedBySchemeOrder() -> [Element] {
        sorted { $0.scheme.order < $1.scheme.order }
    }
}

struct GenericLedgerAccountModel {
    let index: UInt32
    let addresses: [HardwareWalletAddressModel]

    var hasMissingEvmAddress: Bool {
        addresses.contains(where: { $0.scheme == .evm && $0.accountId == nil })
    }
}
