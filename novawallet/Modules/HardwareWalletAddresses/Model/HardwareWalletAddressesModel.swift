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

extension AccountId {
    func toAddressForHWScheme(_ scheme: HardwareWalletAddressScheme) throws -> AccountAddress {
        switch scheme {
        case .substrate:
            try toAddress(
                using: .substrate(
                    SubstrateConstants.genericAddressPrefix,
                    legacyPrefix: nil
                )
            )
        case .evm:
            try toAddress(using: .ethereum)
        }
    }
}
