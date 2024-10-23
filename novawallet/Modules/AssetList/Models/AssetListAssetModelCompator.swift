import Foundation

enum AssetListAssetModelCompator {
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
}
