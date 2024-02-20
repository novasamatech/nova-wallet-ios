import Foundation

extension String {
    func contains(substring: String) -> Bool {
        range(of: substring) != nil
    }
}
