import Foundation

enum CompoundComparator {
    static func compare(list: [() -> ComparisonResult]) -> Bool {
        for comparator in list {
            switch comparator() {
            case .orderedAscending:
                return true
            case .orderedDescending:
                return false
            case .orderedSame:
                break
            }
        }

        return true
    }

    static func compare<T: Comparable>(item1: T, item2: T, isAsc: Bool) -> ComparisonResult {
        if item1 < item2 {
            return isAsc ? .orderedAscending : .orderedDescending
        } else if item1 > item2 {
            return isAsc ? .orderedDescending : .orderedAscending
        } else {
            return .orderedSame
        }
    }
}
