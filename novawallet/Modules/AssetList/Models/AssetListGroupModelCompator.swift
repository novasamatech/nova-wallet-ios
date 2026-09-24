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

    static func byDefaultRank(
        _ rank: [ChainAssetId: Int],
        _ lhs: AssetListAssetGroupModel,
        _ rhs: AssetListAssetGroupModel
    ) -> Bool? {
        let lhsRank = defaultRank(for: lhs.multichainToken, in: rank)
        let rhsRank = defaultRank(for: rhs.multichainToken, in: rank)

        switch (lhsRank, rhsRank) {
        case let (lhsRank?, rhsRank?):
            return lhsRank != rhsRank ? lhsRank < rhsRank : nil
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return nil
        }
    }

    private static func defaultRank(for token: MultichainToken, in rank: [ChainAssetId: Int]) -> Int? {
        token.instances.compactMap { rank[$0.chainAssetId] }.min()
    }

    private static func priority(for token: MultichainToken) -> UInt8 {
        let matchesChain: (ChainModel.Id) -> Bool = { knownChainId in
            token.instances.contains { $0.chainAssetId.chainId == knownChainId && $0.utility }
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
