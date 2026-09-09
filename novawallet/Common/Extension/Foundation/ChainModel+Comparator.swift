import Foundation

enum ChainModelCompator {
    static func priorityAndTestnetComparator(chain1: ChainModel, chain2: ChainModel) -> ComparisonResult {
        let priority1 = chainPriority(for: chain1)
        let priority2 = chainPriority(for: chain2)

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

    static func chainPriority(for chain: ChainModel) -> UInt8 {
        chain.displayPriority ?? .max
    }
}

extension Array where Element == ChainModel {
    func sortedUsingDefaultComparator() -> [ChainModel] {
        sorted { ChainModelCompator.defaultComparator(chain1: $0, chain2: $1) }
    }
}
