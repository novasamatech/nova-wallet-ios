import Foundation

extension ChainRegistryProtocol {
    func genericLedgerAvailable() -> Bool {
        guard let availableChainIds else {
            return false
        }

        return availableChainIds.contains {
            getChain(for: $0)?.supportsGenericLedgerApp ?? false
        }
    }
}
