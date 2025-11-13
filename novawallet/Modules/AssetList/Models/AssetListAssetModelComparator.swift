import Foundation

enum AssetListAssetModelComparator {
    static func by<T>(
        _ keyPath: KeyPath<T, Decimal?>,
        _ lhs: T,
        _ rhs: T
    ) -> Bool? {
        compare(lhs: lhs, rhs: rhs, by: keyPath, zeroValue: 0)
    }

    static func compare<T, V: Comparable>(
        lhs: T,
        rhs: T,
        by keypath: KeyPath<T, V?>,
        zeroValue: V
    ) -> Bool? {
        let lhsValue = lhs[keyPath: keypath] ?? zeroValue
        let rhsValue = rhs[keyPath: keypath] ?? zeroValue

        if lhsValue > zeroValue, rhsValue > zeroValue {
            return lhsValue > rhsValue
        } else if lhsValue > zeroValue {
            return true
        } else if rhsValue > zeroValue {
            return false
        } else {
            return nil
        }
    }

    static func byChain(
        lhs: AssetListAssetModel,
        rhs: AssetListAssetModel
    ) -> Bool {
        let lhsPriority = priority(for: lhs.chainAssetModel)
        let rhsPriority = priority(for: rhs.chainAssetModel)

        return if lhsPriority != rhsPriority {
            lhsPriority < rhsPriority
        } else {
            lhs.chainAssetModel.chain.name.lexicographicallyPrecedes(
                rhs.chainAssetModel.chain.name
            )
        }
    }

    private static func priority(for chainAsset: ChainAsset) -> UInt16 {
        guard !chainAsset.chain.isTestnet else {
            return .max
        }
        guard chainAsset.isUtilityAsset else {
            return .max - 1
        }
        guard let displayPriority = chainAsset.chain.displayPriority else {
            return .max - 2
        }

        return displayPriority
    }
}
