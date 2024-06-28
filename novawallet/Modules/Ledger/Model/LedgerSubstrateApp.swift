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

    var isMigration: Bool {
        switch self {
        case .legacy, .generic:
            return false
        case .migration:
            return true
        }
    }

    func displayName(for chain: ChainModel?) -> String {
        switch self {
        case .legacy:
            return chain?.name ?? ""
        case .migration:
            return "Migration"
        case .generic:
            return "Generic"
        }
    }
}
