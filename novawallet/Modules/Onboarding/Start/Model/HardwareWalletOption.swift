import Foundation

enum HardwareWalletOptions: UInt8, CaseIterable {
    case polkadotVault
    case genericLedger
    case ledger
    case paritySigner
}
