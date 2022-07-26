import Foundation

enum ChainModelCompator {
    static func priorityAndTestnetComparator(chain1: ChainModel, chain2: ChainModel) -> ComparisonResult {
        let priority1 = chainPriority(for: chain1.chainId)
        let priority2 = chainPriority(for: chain2.chainId)

        if priority1 != priority2 {
            return priority1 < priority2 ? .orderedAscending : .orderedDescending
        } else if chain1.isTestnet != chain2.isTestnet {
            return chain1.isTestnet.intValue < chain2.isTestnet.intValue ? .orderedAscending : .orderedDescending
        }

        return .orderedSame
    }

    static func defaultComparator(chain1: ChainModel, chain2: ChainModel) -> Bool {
        let priorityAndTestResult = priorityAndTestnetComparator(chain1: chain1, chain2: chain2)

        if priorityAndTestResult != .orderedSame {
            return priorityAndTestResult == .orderedAscending
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
