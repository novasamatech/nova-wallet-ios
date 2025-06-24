import Foundation

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
