import Foundation

enum ChainModelCompator {
    static func defaultComparator(chain1: ChainModel, chain2: ChainModel) -> Bool {
        let priority1 = chainPriority(for: chain1.chainId)
        let priority2 = chainPriority(for: chain2.chainId)

        if priority1 != priority2 {
            return priority1 < priority2
        } else if chain1.isTestnet != chain2.isTestnet {
            return (chain1.isTestnet ? 1 : 0) < (chain2.isTestnet ? 1 : 0)
        } else {
            return chain1.name.lexicographicallyPrecedes(chain2.name)
        }
    }

    private static func chainPriority(for chainId: ChainModel.Id) -> UInt8 {
        switch chainId {
        case KnowChainId.polkadot:
            return 0
        case KnowChainId.kusama:
            return 1
        default:
            return 2
        }
    }
}
