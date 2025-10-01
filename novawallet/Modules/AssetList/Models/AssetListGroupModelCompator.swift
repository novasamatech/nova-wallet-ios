import Foundation

enum AssetListGroupModelComparator {
    static func by<T>(
        _ keyPath: KeyPath<T, Decimal>,
        _ lhs: T,
        _ rhs: T
    ) -> Bool? {
        compare(lhs: lhs, rhs: rhs, by: keyPath, zeroValue: 0)
    }

    static func defaultComparator(
        lhs: AssetListAssetGroupModel,
        rhs: AssetListAssetGroupModel
    ) -> Bool {
        let lhsPriority = priority(for: lhs.multichainToken)
        let rhsPriority = priority(for: rhs.multichainToken)

        return if lhsPriority != rhsPriority {
            lhsPriority < rhsPriority
        } else {
            lhs.multichainToken.symbol.lexicographicallyPrecedes(rhs.multichainToken.symbol)
        }
    }

    private static func priority(for token: MultichainToken) -> UInt8 {
        let matchesChain: (ChainModel.Id) -> Bool = { knownChainId in
            token.instances.contains { $0.chainAssetId.chainId == knownChainId }
        }

        return if matchesChain(KnowChainId.polkadotAssetHub) {
            0
        } else if matchesChain(KnowChainId.kusamaAssetHub) {
            1
        } else if token.instances.allSatisfy({ $0.testnet }) {
            3
        } else {
            2
        }
    }

    static func compare<T, V: Comparable>(
        lhs: T,
        rhs: T,
        by keypath: KeyPath<T, V>,
        zeroValue: V
    ) -> Bool? {
        if lhs[keyPath: keypath] > zeroValue, rhs[keyPath: keypath] > zeroValue {
            return lhs[keyPath: keypath] > rhs[keyPath: keypath]
        } else if lhs[keyPath: keypath] > zeroValue {
            return true
        } else if rhs[keyPath: keypath] > zeroValue {
            return false
        } else {
            return nil
        }
    }
}
