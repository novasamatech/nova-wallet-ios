import Foundation

enum AssetListGroupModelComparator {
    private static let tokenPriorityOrder = ["DOT", "KSM", "USDC", "USDT", "ETH", "HOLLAR", "TBTC", "HDX", "SOL"]

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
        let lhsTokenPriority = tokenPriorityIndex(for: lhs.multichainToken.symbol)
        let rhsTokenPriority = tokenPriorityIndex(for: rhs.multichainToken.symbol)

        if lhsTokenPriority != rhsTokenPriority {
            return lhsTokenPriority < rhsTokenPriority
        }

        let lhsPriority = priority(for: lhs.multichainToken)
        let rhsPriority = priority(for: rhs.multichainToken)

        return if lhsPriority != rhsPriority {
            lhsPriority < rhsPriority
        } else {
            lhs.multichainToken.symbol.lexicographicallyPrecedes(rhs.multichainToken.symbol)
        }
    }

    private static func normalizeForPriority(_ symbol: String) -> String {
        let uppercased = symbol.uppercased()
        if let range = uppercased.range(of: #"-(SNOWBRIDGE|WORMHOLE).*"#, options: [.regularExpression, .caseInsensitive]) {
            return String(uppercased[uppercased.startIndex ..< range.lowerBound])
        }
        return uppercased
    }

    private static func tokenPriorityIndex(for symbol: String) -> Int {
        let normalized = normalizeForPriority(symbol)
        if let index = tokenPriorityOrder.firstIndex(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
            return index
        }
        return Int.max
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
