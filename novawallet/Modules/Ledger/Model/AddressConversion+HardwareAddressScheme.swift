import Foundation

extension AccountAddress {
    func toAccountIdUsingHardware(scheme: HardwareWalletAddressScheme) throws -> AccountId {
        switch scheme {
        case .substrate:
            try toSubstrateAccountId()
        case .evm:
            try toEthereumAccountId()
        }
    }
}
