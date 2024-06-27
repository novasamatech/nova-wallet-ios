import Foundation

enum LedgerSubstrateApp {
    case legacy
    case migration
    case generic

    init(
        ledgerWalletType: LedgerWalletType,
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol
    ) {
        switch ledgerWalletType {
        case .legacy:
            if chain.supportsGenericLedgerApp, codingFactory.supportsMetadataHash() {
                self = .migration
            } else {
                self = .legacy
            }
        case .generic:
            self = .generic
        }
    }
}
