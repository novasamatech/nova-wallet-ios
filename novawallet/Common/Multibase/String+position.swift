import Foundation

extension String {
    func position(_ index: String.Index) -> Int {
        distance(from: startIndex, to: index)
    }
}
