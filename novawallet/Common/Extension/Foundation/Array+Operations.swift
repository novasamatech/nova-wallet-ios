import Foundation

extension Array where Element: Hashable {
    func distinct() -> [Element] {
        Array(Set(self))
    }
}
